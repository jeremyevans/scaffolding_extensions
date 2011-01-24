require 'erb'
require 'rack'

module ScaffoldingExtensions
  class << self
    private
      # Sinatra doesn't have a default location for models, so assume none
      def model_files
        @model_files ||= []
      end
  end
  
  class RackController
    extend ScaffoldingExtensions::MetaController

    include ScaffoldingExtensions::Controller
    include ScaffoldingExtensions::Helper
    include Rack::Utils

    class Redirect < StandardError
    end

    alias u escape
    alias h escape_html

    def self.scaffold_setup_helper
    end

    def self.call(env)
      new.call(env)
    end

    attr_reader :request
    attr_reader :response
    attr_reader :params

    def call(env)
      s = 200
      h = {'Content-Type'=>'text/html'}
      b = ''
      @params = Hash.new{|hash, k| hash[k.to_s] if k.is_a?(Symbol)}
      params.merge!(parse_nested_query(env["QUERY_STRING"]))
      params.merge!(parse_nested_query(env["rack.input"].read)) if env["REQUEST_METHOD"] == 'POST'

      @scaffold_method = meth = if ['', '/'].include?(env["PATH_INFO"])
        'index'
      elsif captures = %r{\A/(\w+)(?:/(\w+))?\z}.match(env["PATH_INFO"])
        params['id'] ||= captures[2]
        captures[1]
      end

      if !['GET', 'POST'].include?(env["REQUEST_METHOD"]) || (env["REQUEST_METHOD"] == "GET" && scaffolded_nonidempotent_method?(meth)) 
        return [403, h, 'Method Not Allowed']
      end

      if scaffolded_method?(meth)
        @scaffold_path = env['SCRIPT_NAME']
        @request = env
        @response = h
        begin
          b = send(meth)
        rescue Redirect => e
          s = 302
          h['Location'] = e.message 
        end
      else
        s = 404
        b = 'Not Found'
      end

      [s, h, [b]]
    end

    private
      # Sinatra doesn't provide a suitable flash.  You can hack one together using
      # session if you really need it.
      def scaffold_flash
        {}
      end

      def scaffold_redirect_to(url)
        raise ScaffoldingExtensions::RackController::Redirect, url
      end
      
      # Render's the scaffolded template.  A user can override both the template and the layout.
      def scaffold_render_template(action, options = {}, render_options = {})
        suffix = options[:suffix]
        suffix_action = "#{action}#{suffix}"
        @scaffold_options ||= options
        @scaffold_suffix ||= suffix
        @scaffold_class ||= @scaffold_options[:class]
        if render_options.include?(:inline)
          response['Content-Type'] = 'text/javascript' if @scaffold_javascript
          ERB.new(render_options[:inline]).result(binding)
        else
          @content = ERB.new(File.read(scaffold_path(action))).result(binding)
          ERB.new(File.read(scaffold_path(:layout))).result(binding)
        end
      end

      def scaffold_request_action
        @scaffold_method
      end
      
      def scaffold_request_env
        request
      end
      
      def scaffold_request_id
        params[:id]
      end
      
      def scaffold_request_method
        request['REQUEST_METHOD']
      end
      
      def scaffold_request_param(v)
        params[v]
      end
      
      # You need to enable Sinatra's session support for this to work, 
      # otherwise, this will always be the empty hash. The session data
      # is only used for access control, so if you aren't using 
      # scaffold_session_value, it shouldn't matter.
      def scaffold_session
        {}
      end

      # Treats the id option as special, appending it to the path.
      # Uses the rest of the options as query string parameters.
      def scaffold_url(action, options = {})
        escaped_options = {}
        options.each{|k,v| escaped_options[u(k.to_s)] = u(v.to_s)}
        id = escaped_options.delete('id')
        id = id ? "/#{id}" : ''
        id << "?#{escaped_options.to_a.collect{|k,v| "#{k}=#{v}"}.join('&')}" unless escaped_options.empty?
        "#{@scaffold_path}/#{action}#{id}"
      end
  end
end
