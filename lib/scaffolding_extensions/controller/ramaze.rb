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
        unless self.action.view
          if render_options.include?(:inline)
            response['Content-Type'] = 'text/javascript' if @scaffold_javascript
            render_options[:inline]
          else
            self.action.view = scaffold_path(action)
          end
        end
      end

      def scaffold_request_action
        action.name
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
        options[:id] ? r(action, options.delete(:id), options) : r(action, options)
      end
  end

  # Class methods for Ramaze::Controller related necessary for Scaffolding Extensions
  module MetaRamazeController

    private
    # Sets request.params['id'] if it was given as part of the request path.
    # Checks nonidempotent requests require POST.
    def scaffold_define_method(name, &block)
      scaffolded_methods.add(name)

      define_method(name) do |*args|
        scaffold_check_nonidempotent_requests
        request.params['id'] = args.shift if args.length > 0
        instance_eval(&block)
      end
    end

    # Adds a default scaffolded layout if none has been set.  Activates the Erubis
    # engine.  Includes the necessary scaffolding helper and controller methods.
    def scaffold_setup_helper
      engine :Erubis
      layout(:layout){|name, wish| !request.xhr? }
      
      # Instantiates the controller's App (necessary to have a valid
      # Ramaze::Controller.options, which is actually just a shortcut
      # to controller's App options)
      setup
      
      # Retrieves current controller options, and ensure the required ones
      # are properly initialized
      o = options
      o.roots ||= []
      o.views ||= []
      o.layouts ||= []
      
      # Adds scaffold_template_dir to the controller roots
      o.roots += [scaffold_template_dir] unless o.roots.include?(scaffold_template_dir)
      
      # The scaffolding_extensions templates are located directly in the
      # scaffold_template_dir, not in a view/ or layout/ subdirectory,
      # so adds '/' to the views et layout default search paths
      o.views << '/' unless o.views.include? '/'
      o.layouts << '/' unless o.layouts.include? '/'
      
      include ScaffoldingExtensions::Controller
      include ScaffoldingExtensions::RamazeController
      include ScaffoldingExtensions::Helper
      include ScaffoldingExtensions::PrototypeHelper
    end
  end
end

# Add class methods necessary for Scaffolding Extensions
class Ramaze::Controller
  extend ScaffoldingExtensions::MetaController
  extend ScaffoldingExtensions::MetaRamazeController
end

