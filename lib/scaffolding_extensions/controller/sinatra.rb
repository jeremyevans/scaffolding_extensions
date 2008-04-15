begin
  require 'erubis'
  ERB = Erubis::Eruby
rescue
  require 'erb'
end
require 'cgi'

module ScaffoldingExtensions
  SCAFFOLD_ROOTS={}
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
      
      # Proc that redirects to given url
      def scaffold_redirect_to(url)
        env = @sinatra_event.request.env
        host = env['HTTP_HOST'] || "#{env['SERVER_NAME']}#{":#{env['SERVER_PORT']}" if env['SERVER_PORT'] && env['SERVER_PORT'].to_i != 80}"
        Proc.new{redirect("//#{host}#{url}")}
      end
      
      # In order to override the default templates, you need to set 
      # @scaffold_template_dir and then create a template file inside that
      # to override the template (make sure the default templates are also
      # in this folder). It doesn't support user modifiable layouts,
      # so you'll have to modify the layout.rhtml file in @scaffold_template_dir.
      #
      # This returns a proc that renders the necessary template using a plain
      # text renderer.
      def scaffold_render_template(action, options = {}, render_options = {})
        suffix = options[:suffix]
        suffix_action = "#{action}#{suffix}"
        @scaffold_options ||= options
        @scaffold_suffix ||= suffix
        @scaffold_class ||= @scaffold_options[:class]
        if render_options.include?(:inline)
          use_js = @scaffold_javascript
          text = ERB.new(render_options[:inline]).result(binding)
          Proc.new do
            headers('Content-Type'=>'text/javascript') if use_js
            render(:text, text, :layout=>false)
          end
        else
          @content = ERB.new(File.read(scaffold_path(File.exists?(scaffold_path(suffix_action)) ? suffix_action : action))).result(binding)
          text = ERB.new(File.read(scaffold_path('layout'))).result(binding)
          Proc.new{render(:text, text, :layout=>false)}
        end
      end
      
      def scaffold_request_action
        @scaffold_method
      end
      
      def scaffold_request_env
        @sinatra_event.request.env
      end
      
      def scaffold_request_id
        @sinatra_event.params[:id]
      end
      
      def scaffold_request_method
        @scaffold_request_method
      end
      
      def scaffold_request_param(v)
        sparams = @sinatra_event.params
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
        @sinatra_event.session
      end
      
      def scaffold_set_vars(meth, event)
        @scaffold_path = self.class.scaffold_root
        @scaffold_method = meth
        @sinatra_event = event
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
  
  # Class methods for Sinatra necessary for Scaffolding Extensions
  module MetaSinatraController
    include ScaffoldingExtensions::MetaController
    attr_accessor :scaffold_root

    private
      def scaffold_setup_helper
        include ScaffoldingExtensions::Controller
        include ScaffoldingExtensions::SinatraController
        include ScaffoldingExtensions::Helper
        include ScaffoldingExtensions::PrototypeHelper
        include ScaffoldingExtensions::SinatraHelper
      end
  end

  module TextRenderer
    def render_text(template, options = {})
      template
    end
  end
end

class Sinatra::EventContext
  include ScaffoldingExtensions::TextRenderer
end

class NilClass
  def from_param
    nil
  end
end

def scaffold(root, model, options = {})
  scaffold_setup(root).send(:scaffold, model, options)
end

def scaffold_all_models(root, options = {})
  scaffold_setup(root).send(:scaffold_all_models, options)
end

def scaffold_habtm(root, model, association)
  scaffold_setup(root).send(:scaffold_habtm, model, association)
end

def scaffold_setup(root)
  unless klass = ScaffoldingExtensions::SCAFFOLD_ROOTS[root]
    klass = ScaffoldingExtensions::SCAFFOLD_ROOTS[root] = Class.new
    klass.send(:extend, ScaffoldingExtensions::MetaSinatraController)
    klass.scaffold_root = root
    [:get, :post].each do |req_meth|
      send(req_meth, "#{klass.scaffold_root}/?:meth?/?:request_id?") do
        meth = params[:meth] ||= 'index'
        params[:id] ||= params[:request_id]
        @controller = klass.new
        raise(ArgumentError, 'Method Not Allowed') if req_meth == :get && @controller.send(:scaffolded_nonidempotent_method?, meth)
        @controller.send(:scaffold_set_vars, meth, self)
        instance_eval(&@controller.send(meth))
      end
    end
  end 
  klass
end
