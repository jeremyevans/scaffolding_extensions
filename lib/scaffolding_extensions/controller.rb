module ScaffoldingExtensions
  # This holds instance methods that are shared between controllers.
  module Controller
    private
      # Respond "Method not allowed" if the action requested is nonidempotent and the method used isn't POST
      def scaffold_check_nonidempotent_requests
        scaffold_method_not_allowed if scaffolded_nonidempotent_method?(scaffold_request_action) && scaffold_request_method != 'POST'
      end
      
      # Force the given value into an array.  If the items is currently an array,
      # return it.  If the item is nil or false, return the empty array.  Otherwise,
      # return an array with the value as the only member.
      def scaffold_force_array(value)
        if value
          Array === value ? value : [value]
        else
          []
        end
      end
      
      # Returns path to the given scaffold template file
      def scaffold_path(template_name)
        File.join(self.class.scaffold_template_dir, "#{template_name}.rhtml")
      end
      
      # Redirect to the appropriate form for the scaffolded model
      #
      # You can override this method on multiple levels.  You can override a single
      # action for all models via scaffold_#{action}_redirect (e.g.
      # scaffold_edit_redirect or scaffold_new_redirect):
      #
      #   def scaffold_#{action}_redirect(suffix, notice)
      #     # suffix is the suffix for the model, e.g. '_blog'
      #     # notice is a string with content suitable for the flash
      #   end
      #
      # You can override a single action for a single model via
      # scaffold_#{action}#{suffix}_redirect (e.g. scaffold_edit_blog_redirect
      # or scaffold_new_post_redirect):
      #
      #   def scaffold_#{action}#{suffix}_redirect(notice)
      #     # notice is a string with content suitable for the flash
      #   end
      #
      # scaffold_#{action}#{suffix}_redirect has higher priority, and will be
      # use even if scaffold_#{action}_redirect is defined, so you can override
      # for the general case and override again for cases for specific models.
      def scaffold_redirect(action, suffix, notice=nil, oid=nil)
        action_suffix = "#{action}#{suffix}"
        meth = "scaffold_#{action_suffix}_redirect"
        return send(meth, notice) if respond_to?(meth, true)
        meth = "scaffold_#{action}_redirect"
        return send(meth, suffix, notice) if respond_to?(meth, true)
        scaffold_flash[:notice] = notice if notice
        scaffold_redirect_to(scaffold_url(action_suffix, oid ? {:id=>oid} : {}))
      end
      
      # Converts the value to an array, converts all values of the array to integers,
      # removes all 0 values, and returns the array.
      def scaffold_select_ids(value)
        scaffold_force_array(value).collect{|x| x.to_i}.delete_if{|x| x == 0}
      end
      
      # Return whether scaffolding defined the method, whether or not it was overwritten
      def scaffolded_method?(method_name)
        self.class.scaffolded_methods.include?(method_name)
      end
      
      # Return whether scaffolding defined the method, if the method is nonidempotent
      def scaffolded_nonidempotent_method?(method_name)
        self.class.scaffolded_nonidempotent_methods.include?(method_name)
      end
      
      # Return true if the item was requested with XMLHttpRequest, false otherwise
      def scaffold_xhr?
        scaffold_request_env['HTTP_X_REQUESTED_WITH'] =~ /XMLHttpRequest/i
      end
  end
end
