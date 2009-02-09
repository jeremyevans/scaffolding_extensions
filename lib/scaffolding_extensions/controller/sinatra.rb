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
        redirect(url)
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
          response['Content-Type'] = 'text/javascript' if use_js
          render(:erb, scaffold_fix_template(render_options[:inline]), :layout=>false)
        else
          template = lookup_template(:erb, suffix_action.to_sym, render_options) rescue scaffold_fix_template(File.read(scaffold_path(action)))
          layout, _ = lookup_layout(:erb, render_options) || [scaffold_fix_template(File.read(scaffold_path('layout'))).gsub('@content', 'yield'), nil]
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
        params[v]
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

  module MetaSinatraController
    def scaffold_setup_helper
      include ScaffoldingExtensions::Controller
      include ScaffoldingExtensions::SinatraController
      include ScaffoldingExtensions::Helper
      include ScaffoldingExtensions::PrototypeHelper
      include ScaffoldingExtensions::SinatraHelper
      [:get, :post].each do |req_meth|
        sreq_meth = req_meth.to_s.upcase
        send(req_meth, %r{\A(?:/(\w+)(?:/(\w+))?)?\z}) do
          captures = params[:captures] || []
          @scaffold_path = request.env['SCRIPT_NAME']
          @scaffold_method = meth = captures[0] || 'index'
          @scaffold_request_method = sreq_meth
          params[:id] ||= captures[1]
          raise(ArgumentError, 'Method Not Allowed') if req_meth == :get && scaffolded_nonidempotent_method?(meth)
          raise(Sinatra::NotFound) unless scaffolded_method?(meth) 
          send(meth)
        end
      end
      self
    end
  end
end

class Sinatra::Base
  extend ScaffoldingExtensions::MetaController
  extend ScaffoldingExtensions::MetaSinatraController
end
