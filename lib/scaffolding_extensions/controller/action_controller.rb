module ScaffoldingExtensions
  class << self
    private
      # ActionController::Base is generally used with Rails, which holds model files
      # in app/models/
      def model_files
        @model_files ||= Dir["#{Rails.root}/app/models/*.rb"]
      end
  end

  # Helper methods for ActionController::Base that override the defaults in Scaffolding Extensions
  module ActionControllerHelper
    private
      # ActionController::Base allows easy access to the CSRF token via token_tag
      def scaffold_token_tag
        token_tag
      end

      # Mark the output as safe for raw display
      def scaffold_raw(s)
        raw(s)
      end
  end
  
  # Instance methods for ActionController::Base necessary for Scaffolding Extensions
  module ActionController
    private
      def scaffold_flash
        flash
      end
      
      def scaffold_method_not_allowed
        head(:method_not_allowed)
      end
      
      def scaffold_redirect_to(url)
        redirect_to(url)
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
        if render_options.include?(:inline)
          headers['Content-Type'] = 'text/javascript' if @scaffold_javascript
          return render(render_options.merge(:layout=>false))
        end
        begin
          render({:action=>suffix_action}.merge(render_options))
        rescue ActionView::MissingTemplate
          if render_options.include?(:layout) || _default_layout
            render({:file=>scaffold_path(action)}.merge(render_options))
          else
            options = _normalize_args({:file=>scaffold_path(action)}.merge(render_options))
            _normalize_options(options)
            _process_options(options)
            vc = view_context
            @content = vc.render(options)
            vc.instance_variables.each{|iv| instance_variable_set(iv, vc.instance_variable_get(iv))}
            render({:file=>scaffold_path("layout")})
          end
        end
      end
      
      def scaffold_request_action
        params[:action]
      end
      
      def scaffold_request_env
        request.env
      end
      
      def scaffold_request_id
        params[:id]
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
        url_for(options.merge(:action=>action, :only_path=>true))
      end
  end
  
  # Class methods for ActionController::Base necessary for Scaffolding Extensions
  module MetaActionController
    private
      # Adds a before filter for checking nonidempotent requests use method POST
      def scaffold_setup_helper
        helper ScaffoldingExtensions::Helper
        helper ScaffoldingExtensions::ActionControllerHelper
        include ScaffoldingExtensions::Controller
        include ScaffoldingExtensions::ActionController
        helper_method "scaffolded_method?", "scaffolded_nonidempotent_method?", :scaffold_url, :scaffold_flash, :scaffold_session
        before_filter :scaffold_check_nonidempotent_requests
      end
  end
end

# Add class methods necessary for Scaffolding Extensions
class ActionController::Base
  extend ScaffoldingExtensions::MetaController
  extend ScaffoldingExtensions::MetaActionController
end
