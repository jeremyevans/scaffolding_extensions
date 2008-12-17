module ScaffoldingExtensions
  class << self
    private
      # Use whatever model directory Merb is using.
      def model_files
        @model_files ||= Dir["#{Merb.dir_for(:model)}/*.rb"]
      end
  end

  # Helper methods for Merb that override the defaults in Scaffolding Extensions
  module MerbControllerHelper
    private
      # Merb apparently requires that params that are desired to be lists have
      # the suffix '[]'
      def scaffold_param_list_suffix
        '[]'
      end
  end
  
  # Instance methods for Merb necessary for Scaffolding Extensions
  module MerbController
    private
      def scaffold_flash
        message
      end
      
      def scaffold_method_not_allowed
        render('', :status=>405)
      end
      
      def scaffold_redirect_to(url)
        redirect("#{request.protocol}://#{request.host}#{url}")
      end
      
      # Renders user provided template if it exists, otherwise renders a scaffold template.
      # If a layout is specified (either in the controller or as an render_option), use that layout,
      # otherwise uses the scaffolded layout.  If :inline is one of the render_options,
      # use the contents of it as the template without the layout.
      #
      # There may well be a much better way to do this via modifying the _template_roots, but
      # I didn't have much luck and decided to take the path I used with Camping,
      # rendering the templates directly.
      def scaffold_render_template(action, options = {}, render_options = {})
        suffix = options[:suffix]
        suffix_action = "#{action}#{suffix}".to_sym
        @scaffold_options ||= options
        @scaffold_suffix ||= suffix
        @scaffold_class ||= @scaffold_options[:class]
        begin
          render(suffix_action, render_options)
        rescue Merb::ControllerExceptions::TemplateNotFound
          if render_options.include?(:inline)
            headers['Content-Type'] = 'text/javascript' if @scaffold_javascript
            render(Erubis::Eruby.new(render_options[:inline]).result(binding), {:layout=>false}.merge(render_options))
          else
            html = Erubis::Eruby.new(File.read(scaffold_path(action))).result(binding)
            merb_layout = begin
              merb_layout = _get_layout
            rescue Merb::ControllerExceptions::TemplateNotFound
              merb_layout = false
            end
            if merb_layout
              render(html, render_options)
            else
              @content = html
              render(Erubis::Eruby.new(File.read(scaffold_path('layout'))).result(binding), render_options.merge(:layout=>false))
            end
          end
        end
      end
      
      def scaffold_request_action
        params[:action]
      end
      
      def scaffold_request_env
        request.env
      end
      
      # Merb overrides any given query params with the path params even if the
      # path params are nil.  Work around it by getting the query params
      # directly.
      def scaffold_request_id
        params[:id] || request.send(:query_params)[:id]
      end
      
      def scaffold_request_method
        request.method.to_s.upcase
      end
      
      def scaffold_request_param(v)
        params[v]
      end
      
      def scaffold_session
        session
      end
      
      def scaffold_url(action, options = {})
        url(options.merge(:controller=>controller_name, :action=>action))
      end
  end
  
  # Class methods for Merb necessary for Scaffolding Extensions
  module MetaMerbController
    private
      # Adds a before filter for checking nonidempotent requests use method POST
      def scaffold_setup_helper
        include ScaffoldingExtensions::Helper
        include ScaffoldingExtensions::MerbControllerHelper
        include ScaffoldingExtensions::PrototypeHelper
        include ScaffoldingExtensions::Controller
        include ScaffoldingExtensions::MerbController
        before :scaffold_check_nonidempotent_requests
      end
  end
end

# Add class methods necessary for Scaffolding Extensions
class Merb::Controller
  extend ScaffoldingExtensions::MetaController
  extend ScaffoldingExtensions::MetaMerbController
end
