module ScaffoldingExtensions
  class << self
    private
      # Ramaze's default location for models is model/
      def model_files
        @model_files ||= Dir["model/*.rb"]
      end
  end

  # Instance methods for Ramaze::Controller related necessary for Scaffolding Extensions
  module RamazeController
    private
      def scaffold_flash
        flash
      end
      
      def scaffold_method_not_allowed
        respond('Method not allowed', 405)
      end
      
      def scaffold_redirect_to(url)
        redirect(url)
      end
      
      # Renders user provided template if it exists, otherwise renders a scaffold template.
      # If a layout is specified (either in the controller or as an render_option), use that layout,
      # otherwise uses the scaffolded layout.  If :inline is one of the render_options,
      # use the contents of it as the template without the layout.
      def scaffold_render_template(action, options = {}, render_options = {})
        suffix = options[:suffix]
        suffix_action = "#{action}#{suffix}"
        @scaffold_options ||= options
        @scaffold_suffix ||= suffix
        @scaffold_class ||= @scaffold_options[:class]
        unless ::Ramaze::Action.current.template
          if render_options.include?(:inline)
            response['Content-Type'] = 'text/javascript' if @scaffold_javascript
            render_options[:inline]
          else
            ::Ramaze::Action.current.template = scaffold_path(action)
          end
        end
      end
      
      def scaffold_request_action
        ::Ramaze::Action.current.name
      end
      
      def scaffold_request_env
        request.env
      end
      
      def scaffold_request_id
        request.params['id']
      end
      
      def scaffold_request_method
        request.env['REQUEST_METHOD']
      end
      
      def scaffold_request_param(v)
        request.params[v.to_s]
      end
      
      def scaffold_session
        session
      end
      
      # Treats the id option as special (appending it so the list of options),
      # which requires a lambda router.
      def scaffold_url(action, options = {})
        escaped_options = {}
        options.each{|k,v| escaped_options[u(k.to_s)] = u(v.to_s)}
        escaped_options['id'] ? Rs(action, escaped_options.delete('id'), escaped_options) : Rs(action, escaped_options)
      end
  end
  
  # Class methods for Ramaze::Controller related necessary for Scaffolding Extensions
  module MetaRamazeController
    DENY_LAYOUT_RE = %r{\A(scaffold_auto_complete_for|associations|add|remove)_}
    
    private
      # Denies the layout to names that match DENY_LAYOUT_RE (the Ajax methods)
      def scaffold_define_method(name, *args, &block)
        deny_layout(name) if DENY_LAYOUT_RE.match(name)
        scaffolded_methods.add(name)
        define_method(name, *args, &block)
      end
      
      # Adds a default scaffolded layout if none has been set.  Activates the Erubis
      # engine and the Aspect helper.  Adds a before_all filter for checking
      # nonidempotent requests use method POST.  Adds a lambda router so that you can use
      # Rails-style urls that end in integers as an 'id' parameter.
      def scaffold_setup_helper
        engine :Erubis
        include ScaffoldingExtensions::Controller
        include ScaffoldingExtensions::RamazeController
        include ScaffoldingExtensions::Helper
        include ScaffoldingExtensions::PrototypeHelper
        helper :aspect
        before_all{scaffold_check_nonidempotent_requests}
        m = mapping
        Ramaze::Route("#{m}-id_to_param") do |path, request|
          if match = %r{\A(#{m}/[^/]*)/(\d+)\z}.match(path.to_s)
            request.params['id'] = match[2]
            match[1]
          end
        end
        unless trait[:layout][:all]
          layout(:scaffold_layout) 
          define_method(:scaffold_layout){::Ramaze::Action.current.template = scaffold_path(:layout)}
        end
      end
  end
end

# Add class methods necessary for Scaffolding Extensions
class Ramaze::Controller
  extend ScaffoldingExtensions::MetaController
  extend ScaffoldingExtensions::MetaRamazeController
end
