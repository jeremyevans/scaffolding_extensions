begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end
require 'cgi'

module ScaffoldingExtensions
  class << self
    private
      # Camping doesn't have a default location for models, so assume none
      def model_files
        @model_files ||= []
      end
  end
  
  module CampingHelper
    private
      # Camping doesn't include u
      def u(s)
        CGI.escape(s.to_s)
      end
      
      # Camping doesn't include h
      def h(s)
        CGI.escapeHTML(s.to_s)
      end
  end

  # Instance methods for the Camping Controller related necessary for Scaffolding Extensions
  module CampingController
    private
      # Camping doesn't provide a suitable flash.  You can hack one together using
      # session if you really need it.
      def scaffold_flash
        {}
      end
      
      # Not the most elegent approach, as this just raises an ArgumentError.
      def scaffold_method_not_allowed
        raise ArgumentError, 'Method Not Allowed'
      end
      
      # Seems as though redirect doesn't include the protocol, which is pretty weird,
      # but it does work.
      def scaffold_redirect_to(url)
        redirect(url)
      end
      
      # In order to override the default templates, you need to set 
      # @scaffold_template_dir and then create a template file inside that
      # to override the template (make sure the default templates are also
      # in this folder). It doesn't support user modifiable layouts,
      # so you'll have to modify the layout.rhtml file in @scaffold_template_dir.
      def scaffold_render_template(action, options = {}, render_options = {})
        suffix = options[:suffix]
        suffix_action = "#{action}#{suffix}"
        @scaffold_options ||= options
        @scaffold_suffix ||= suffix
        @scaffold_class ||= @scaffold_options[:class]
        if render_options.include?(:inline)
          headers = {}
          headers['Content-Type'] = 'text/javascript' if @scaffold_javascript
          r(200, ERB.new(render_options[:inline]).result(binding), headers)
        else
          @content = ERB.new(File.read(scaffold_path(File.exists?(scaffold_path(suffix_action)) ? suffix_action : action))).result(binding)
          ERB.new(File.read(scaffold_path('layout'))).result(binding)
        end
      end
      
      def scaffold_request_action
        @scaffold_method
      end
      
      def scaffold_request_env
        @env
      end
      
      def scaffold_request_id
        @input[:id] || @scaffold_request_id
      end
      
      def scaffold_request_method
        @scaffold_request_method
      end
      
      def scaffold_request_param(v)
        @input[v]
      end
      
      # You need to enable Camping's session support for this to work, 
      # otherwise, this will always be the empty hash. The session data
      # is only used for access control, so if you aren't using 
      # scaffold_session_value, it shouldn't matter.
      def scaffold_session
        @state || {}
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
  
  # Class methods for the Camping Controller necessary for Scaffolding Extensions
  module MetaCampingController
    include ScaffoldingExtensions::MetaController
    private
      # Defines get and post methods for the controller that
      # set necessary variables and then call the correct scaffold method
      def scaffold_setup_helper
        include ScaffoldingExtensions::Controller
        include ScaffoldingExtensions::CampingController
        include ScaffoldingExtensions::Helper
        include ScaffoldingExtensions::PrototypeHelper
        include ScaffoldingExtensions::CampingHelper
        define_method(:get) do |path, meth, id|
          @scaffold_request_method = 'GET'
          @scaffold_path = path
          @scaffold_method = meth.empty? ? 'index' : meth
          @scaffold_request_id = id.empty? ? nil : id
          scaffold_method_not_allowed if scaffolded_nonidempotent_method?(meth)
          send(@scaffold_method)
        end
        define_method(:post) do |path, meth, id|
          @scaffold_request_method = 'POST'
          @scaffold_path = path
          @scaffold_method = meth.empty? ? 'index' : meth
          @scaffold_request_id = id.empty? ? nil : id
          send(@scaffold_method)
        end
      end
  end
end

# Create a route class, and automatically extend it with
# MetaCampingController so scaffold methods can be used directly
# inside of it.
def scaffold_R(root)
  r = Camping::Controllers::R("(#{root})/?([^/]*)/?([^/]*)")
  r.send(:extend, ScaffoldingExtensions::MetaCampingController)
  r
end
