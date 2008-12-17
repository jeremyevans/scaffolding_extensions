require 'erb'
require 'cgi'

module ScaffoldingExtensions
  class << self
    private
      # Sinatra doesn't have a default location for models, so assume none
      def model_files
        @model_files ||= []
      end
  end
  
  module SinatraHelper
    private
      def u(s)
        CGI.escape(s.to_s)
      end 
    
      def h(s)
        CGI.escapeHTML(s.to_s)
      end 
  end

  # Instance methods for the anonymous class that acts as a Controller for Sinatra
  module SinatraController
    private
      # Sinatra doesn't provide a suitable flash.  You can hack one together using
      # session if you really need it.
      def scaffold_flash
        {}
      end

      # Sinatra's ERB renderer doesn't like "-%>"
      def scaffold_fix_template(text)
        text.gsub('-%>', '%>')
      end
      
      def scaffold_redirect_to(url)
        env = request.env
        host = env['HTTP_HOST'] || "#{env['SERVER_NAME']}#{":#{env['SERVER_PORT']}" if env['SERVER_PORT'] && env['SERVER_PORT'].to_i != 80}"
        redirect("//#{host}#{url}")
      end
      
      # Render's the scaffolded template.  A user can override both the template and the layout.
      def scaffold_render_template(action, options = {}, render_options = {})
        suffix = options[:suffix]
        suffix_action = "#{action}#{suffix}"
        @scaffold_options ||= options
        @scaffold_suffix ||= suffix
        @scaffold_class ||= @scaffold_options[:class]
        if render_options.include?(:inline)
          use_js = @scaffold_javascript
          headers('Content-Type'=>'text/javascript') if use_js
          render(:erb, scaffold_fix_template(render_options[:inline]), :layout=>false)
        else
          template = resolve_template(:erb, suffix_action.to_sym, render_options, false) || scaffold_fix_template(File.read(scaffold_path(action)))
          layout = determine_layout(:erb, :layout, {}) || scaffold_fix_template(File.read(scaffold_path('layout'))).gsub('@content', 'yield')
          render(:erb, template, :layout=>layout)
        end
      end
      
      def scaffold_request_action
        @scaffold_method
      end
      
      def scaffold_request_env
        request.env
      end
      
      def scaffold_request_id
        params[:id]
      end
      
      def scaffold_request_method
        @scaffold_request_method
      end
      
      def scaffold_request_param(v)
        sparams = params
        unless param = sparams[v.to_sym]
          param = {}
          sparams.each do |k,value|
           if match = /#{v}\[([^\]]+)\]/.match(k.to_s)
              param[match[1]] = value
            end 
          end
          param = nil if param.empty?
        end
        param
      end
      
      # You need to enable Sinatra's session support for this to work, 
      # otherwise, this will always be the empty hash. The session data
      # is only used for access control, so if you aren't using 
      # scaffold_session_value, it shouldn't matter.
      def scaffold_session
        session
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

class Sinatra::EventContext
  SCAFFOLD_ROOTS = []
  extend ScaffoldingExtensions::MetaController

  def self.scaffold_setup_helper
  end

  def self.scaffold_action_setup(root)
    if SCAFFOLD_ROOTS.empty?
      include ScaffoldingExtensions::Controller
      include ScaffoldingExtensions::SinatraController
      include ScaffoldingExtensions::Helper
      include ScaffoldingExtensions::PrototypeHelper
      include ScaffoldingExtensions::SinatraHelper
    end
    unless SCAFFOLD_ROOTS.include?(root)
      SCAFFOLD_ROOTS << root
      [:get, :post].each do |req_meth|
        Object.send(req_meth, "#{root}/?:meth?/?:request_id?") do
          @scaffold_path = root
          @scaffold_method = meth = params[:meth] ||= 'index'
          params[:id] ||= params[:request_id]
          raise(ArgumentError, 'Method Not Allowed') if req_meth == :get && scaffolded_nonidempotent_method?(meth)
          raise(Sinatra::NotFound) unless scaffolded_method?(meth) 
          send(meth)
        end
      end
    end
    self
  end
end

def scaffold(root, model, options = {})
  Sinatra::EventContext.scaffold_action_setup(root).send(:scaffold, model, options)
end

def scaffold_all_models(root, options = {})
  Sinatra::EventContext.scaffold_action_setup(root).send(:scaffold_all_models, options)
end

def scaffold_habtm(root, model, association)
  Sinatra::EventContext.scaffold_action_setup(root).send(:scaffold_habtm, model, association)
end

