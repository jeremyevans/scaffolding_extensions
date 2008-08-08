module ScaffoldingExtensions
  module Overridable
    def self.extended(klass)
      class << klass
        extend ScaffoldingExtensions::MetaOverridable
        scaffold_override_methods(:add_associated_objects, :associated_objects, :association_find_object, :association_find_objects, :find_object, :find_objects, :new_associated_object_values, :remove_associated_objects, :save, :unassociated_objects, :filter_attributes)
        scaffold_override_iv_methods(:associated_human_name, :association_use_auto_complete, :fields, :include, :select_order, :attributes, :include_association, :select_order_association) 
      end
    end

    private
      # If a method exists matches scaffold_#{action}_#{m}, return a proc that calls it.
      # If not and the instance variable @scaffold_#{action}_#{m} is defined, return a
      # proc that gives that value.  Otherwise, return nil.
      def scaffold_method_iv_override(m, action)
        return nil unless action
        meth = "scaffold_#{action}_#{m}"
        if respond_to?(meth, true)
          Proc.new{send(meth)}
        elsif instance_variables.include?(meth = "@#{meth}")
          Proc.new{instance_variable_get(meth)}
        end 
      end 
      
      # If a method exists matches scaffold_#{action}_#{m}, return a proc that calls it with
      # the other provided arguments, otherwise return nil.
      def scaffold_method_override(m, action, *args)
        return nil unless action
        meth = "scaffold_#{action}_#{m}"
        Proc.new{send(meth, *args)} if respond_to?(meth, true)
      end
  end

  module MetaOverridable
    private
      def scaffold_override_alias_method(meth)
        pub_meth = "scaffold_#{meth}".to_sym
        priv_meth = "_#{pub_meth}".to_sym
        @scaffold_aliased_methods ||= Set.new
        return false if @scaffold_aliased_methods.include?(pub_meth)
        alias_method(priv_meth, pub_meth)
        private(priv_meth)
        @scaffold_aliased_methods.add(pub_meth)
        [pub_meth, priv_meth]
      end

      def scaffold_override_iv_methods(*meths)
        meths.each do |meth|
          pub_meth, priv_meth = scaffold_override_alias_method(meth)
          return unless pub_meth && priv_meth
          define_method(pub_meth) do |arg|
            if m = scaffold_method_iv_override(meth, arg)
              m.call
            else
              send(priv_meth, arg)
            end
          end
        end
      end

      def scaffold_override_methods(*meths)
        meths.each do |meth|
          pub_meth, priv_meth = scaffold_override_alias_method(meth)
          return unless pub_meth && priv_meth
          define_method(pub_meth) do |*args|
            if m = scaffold_method_override(meth, *args)
              m.call
            else
              send(priv_meth, *args)
            end
          end
        end
      end
  end
end
