module ScaffoldingExtensions
  # Contains class methods shared across controllers
  module MetaController
    attr_accessor :scaffolded_methods, :scaffolded_nonidempotent_methods, :scaffolded_auto_complete_associations
    
    # The location of the scaffold templates
    def scaffold_template_dir
      @scaffold_template_dir ||= TEMPLATE_DIR
    end
    
    private 
      # Creates a series of administrative forms for a given model klass. All actions
      # defined have the suffix "_#{klass.scaffold_name}".
      #
      # Takes the following options:
      #
      # - :except: symbol or array of method symbols not to define
      # - :only: symbol or array of method symbols to define instead of the default
      #
      # The following method symbols are used to control the methods that get
      # added by the scaffold function:
      #
      # - :browse: Browse all model objects, similar to a search for every record.
      # - :delete: Shows a select box with all objects (or an autocompleting text box), allowing the user to chose
      #   an object to delete
      # - :edit: Shows a select box with all objects (or an autocompleting text box), allowing the user to chose
      #   an object to edit.  When one is selected, shows a form for changing the fields.
      #   Also shows associations specified in the model's scaffold_associations,
      #   allowing you easy access to manage associated models and objects.
      # - :manage: Page that has links to all the other methods.
      # - :new: Form for creating new objects
      # - :merge: Brings up two fields (usually select fields), allowing the user to
      #   pick one to merge into the other.  Merging takes all objects associated with
      #   the object to be merged and replaces those associations with associations to
      #   the object is it being merged into, and then it deletes the object being merged.
      # - :search: Simple search form. The results page has links to show, edit,
      #   or destroy each object.
      # - :show: Shows a select box with all objects (or an autocompleting text box), allowing the user to chose
      #   an object, which then shows the attribute name and value for scaffolded fields.
      #   Also shows associations specified in the model's scaffold_associations.
      def scaffold(klass, options = {})
        scaffold_setup 
        singular_name = klass.scaffold_name
        singular_human_name = klass.scaffold_human_name
        plural_name = singular_name.pluralize
        plural_human_name = singular_human_name.pluralize
        suffix = "_#{singular_name}"
        add_methods = options[:only] ? Array(options[:only]) : scaffold_default_methods
        add_methods -= Array(options[:except])
        scaffold_options = {:singular_name=>singular_name, :plural_name=>plural_name, :singular_human_name=>singular_human_name, :plural_human_name=>plural_human_name, :class=>klass, :suffix=>suffix, :singular_lc_human_name=>singular_human_name.downcase, :plural_lc_human_name=>plural_human_name.downcase}

        scaffold_auto_complete_for(klass) if klass.scaffold_use_auto_complete
        klass.scaffold_auto_complete_associations.each{|association| scaffold_auto_complete_for(klass, association)}
        
        if add_methods.include?(:manage)
          scaffold_define_method("manage#{suffix}") do
            scaffold_render_template(:manage, scaffold_options)
          end
        end
        
        if add_methods.include?(:show) or add_methods.include?(:destroy) or add_methods.include?(:edit)
          scaffold_define_method("list#{suffix}") do
            @scaffold_objects ||= klass.scaffold_find_objects(@scaffold_action, :session=>scaffold_session) unless klass.scaffold_use_auto_complete
            scaffold_render_template(:list, scaffold_options)
          end
        end
        
        if add_methods.include?(:show)
          scaffold_define_method("show#{suffix}") do
            if scaffold_request_id
              @scaffold_object ||= klass.scaffold_find_object(:show, scaffold_request_id, :session=>scaffold_session)
              @scaffold_associations_readonly = true
              scaffold_render_template(:show, scaffold_options)
            else
              @scaffold_action = :show
              send("list#{suffix}")
            end
          end
        end
        
        if add_methods.include?(:delete)
          scaffold_define_method("delete#{suffix}") do
            @scaffold_action = :destroy
            send("list#{suffix}")
          end
          
          scaffold_define_nonidempotent_method("destroy#{suffix}") do
            @scaffold_object ||= klass.scaffold_find_object(:delete, scaffold_request_id, :session=>scaffold_session)
            klass.scaffold_destroy(@scaffold_object)
            scaffold_redirect('delete', suffix, "#{singular_human_name} was successfully destroyed")
          end
        end
        
        if add_methods.include?(:edit)
          klass.scaffold_habtm_associations.each{|association| scaffold_habtm(klass, association)}

          scaffold_define_method("edit#{suffix}") do
            if scaffold_request_id
              @scaffold_show_associations = true if scaffold_request_param(:associations) == 'show'
              @scaffold_object ||= klass.scaffold_find_object(:edit, scaffold_request_id, :session=>scaffold_session)
              scaffold_render_template(:edit, scaffold_options)
            else
              @scaffold_action = :edit
              send("list#{suffix}")
            end
          end
          
          scaffold_define_nonidempotent_method("update#{suffix}") do
            @scaffold_object ||= klass.scaffold_find_object(:edit, scaffold_request_id, :session=>scaffold_session)
            klass.scaffold_update_attributes(@scaffold_object, scaffold_request_param(singular_name))
            if klass.scaffold_save(:edit, @scaffold_object)
              scaffold_redirect(:edit, suffix, "#{singular_human_name} was successfully updated")
            else
              scaffold_render_template(:edit, scaffold_options)
            end
          end
          
          if klass.scaffold_load_associations_with_ajax
            scaffold_define_method("associations#{suffix}") do
              @scaffold_object ||= klass.scaffold_find_object(:edit, scaffold_request_id, :session=>scaffold_session)
              scaffold_render_template(:associations, scaffold_options, :inline=>"<%= scaffold_habtm_ajax_associations %>\n<%= scaffold_association_links %>\n")
            end
          end
        end
        
        if add_methods.include?(:new)
          scaffold_define_method("new#{suffix}") do
            @scaffold_object ||= klass.scaffold_new_object(scaffold_request_param(singular_name), :session=>scaffold_session)
            scaffold_render_template(:new, scaffold_options)
          end
          
          scaffold_define_nonidempotent_method("create#{suffix}") do
            @scaffold_object ||= klass.scaffold_new_object(scaffold_request_param(singular_name), :session=>scaffold_session)
            if klass.scaffold_save(:new, @scaffold_object)
              scaffold_redirect(:new, suffix, "#{singular_human_name} was successfully created")
            else
              scaffold_render_template(:new, scaffold_options)
            end
          end
        end
        
        if add_methods.include?(:search)
          scaffold_define_method("search#{suffix}") do
            @scaffold_object ||= klass.scaffold_search_object
            scaffold_render_template(:search, scaffold_options)
          end
          
          scaffold_define_method("results#{suffix}") do
            page = scaffold_request_param(:page).to_i > 1 ? scaffold_request_param(:page).to_i : 1
            page -= 1 if scaffold_request_param(:page_previous)
            page += 1 if scaffold_request_param(:page_next)
            @scaffold_search_results_form_params, @scaffold_objects = klass.scaffold_search(:model=>scaffold_request_param(singular_name), :notnull=>scaffold_force_array(scaffold_request_param(:notnull)), :null=>scaffold_force_array(scaffold_request_param(:null)), :page=>page, :session=>scaffold_session)
            @scaffold_listtable_type = :search
            scaffold_render_template(:listtable, scaffold_options)
          end
        end
      
        if add_methods.include?(:merge)
          scaffold_define_method("merge#{suffix}") do
            @scaffold_objects ||= klass.scaffold_find_objects(:merge, :session=>scaffold_session) unless klass.scaffold_use_auto_complete
            scaffold_render_template(:merge, scaffold_options)
          end
          
          scaffold_define_nonidempotent_method("merge_update#{suffix}") do
            notice = if klass.scaffold_merge_records(scaffold_request_param(:from), scaffold_request_param(:to), :session=>scaffold_session)
              "#{plural_human_name} were successfully merged"
            else
              "Error merging #{plural_human_name.downcase}"
            end
            scaffold_redirect(:merge, suffix, notice)
          end
        end
        
        if add_methods.include?(:browse)
          scaffold_define_method("browse#{suffix}") do
            @page ||= scaffold_request_param(:page).to_i > 1 ? scaffold_request_param(:page).to_i : 1
            @next_page, @scaffold_objects = klass.scaffold_browse_find_objects(:session=>scaffold_session, :page=>@page)
            @scaffold_listtable_type = :browse
            scaffold_render_template(:listtable, scaffold_options)
          end
        end
      end
      
      # Scaffolds all models with one command
      #
      # Takes the following options:
      # - :except: model class or array of model classes not to scaffold
      # - :only: only scaffold model classes included in this array
      # - model class: hash of options for the scaffold method for this model
      def scaffold_all_models(options={})
        scaffold_setup
        links = scaffold_all_models_parse_options(options).collect do |model, options|
          scaffold(model, options)
          ["manage_#{model.scaffold_name}", model.scaffold_human_name]
        end
        scaffold_define_method('index') do
          @links = links
          scaffold_render_template('index')
        end
      end
      
      # Parse the arguments for scaffold_all_models.  Seperated so that it can
      # also be used in testing.
      def scaffold_all_models_parse_options(options={})
        ScaffoldingExtensions.all_models(options).collect{|model| [model, options[model] || {}]}
      end
      
      # Create action for returning results from the scaffold autocompleter
      # for the given model.  If an association is given, allows autocompleting for
      # objects in an association.
      def scaffold_auto_complete_for(klass, association=nil)
        meth = "scaffold_auto_complete_for_#{klass.scaffold_name}"
        (self.scaffolded_auto_complete_associations[klass] ||= Set.new).add(association.to_s)
        allowed_associations = scaffolded_auto_complete_associations[klass]
        unless instance_methods.include?(meth)
          scaffold_define_method(meth) do
            association = scaffold_request_param(:association).to_s
            if scaffold_request_param(:association) && !allowed_associations.include?(association)
              scaffold_method_not_allowed
            else
              @items = klass.scaffold_auto_complete_find(scaffold_request_id.to_s, :association=>(association.to_sym if scaffold_request_param(:association)), :session=>scaffold_session)
              scaffold_render_template(meth, {}, :inline => "<%= scaffold_auto_complete_result(@items) %>")
            end
          end
        end
      end
      
      # The methods that should be added by the scaffolding function by default
      def scaffold_default_methods
        @scaffold_default_methods ||= DEFAULT_METHODS
      end
      
      # Define method and add method name to scaffolded_methods
      def scaffold_define_method(name, &block)
        scaffolded_methods.add(name)
        define_method(name, &block)
      end
      
      # Define method and add method name to scaffolded_methods and
      # scaffolded_nonidempotent_methods
      def scaffold_define_nonidempotent_method(name, &block)
        scaffolded_nonidempotent_methods.add(name)
        scaffold_define_method(name, &block)
      end
      
      # Scaffolds a habtm association for a class and an association using two select boxes, or
      # a select box for removing associations and an autocompleting text box for
      # adding associations.    
      def scaffold_habtm(klass, association)
        scaffold_setup
        sn = klass.scaffold_name
        scaffold_auto_complete_for(klass, association) if auto_complete = klass.scaffold_association_use_auto_complete(association)
        
        if klass.scaffold_habtm_with_ajax
          suffix = "_#{sn}"
          records_list = "#{sn}_associated_records_list"
          element_id = "#{sn}_#{association}_id"
          add_meth = "add_#{association}_to_#{sn}"
          scaffold_define_nonidempotent_method(add_meth) do
            @record = klass.scaffold_find_object(:habtm, scaffold_request_id, :session=>scaffold_session)
            @associated_record = klass.scaffold_add_associated_objects(association, @record, {:session=>scaffold_session}, scaffold_request_param(element_id))
            if scaffold_xhr?
              @klass = klass
              @association = association
              @records_list = records_list
              @auto_complete = auto_complete
              @element_id = element_id
              @scaffold_javascript = true
              scaffold_render_template(add_meth, {}, :inline=>'<%= scaffold_add_habtm_element %>')
            else
              scaffold_redirect_to(scaffold_url("edit#{suffix}", :id=>@record.scaffold_id))
            end
          end
          
          remove_meth = "remove_#{association}_from_#{sn}"
          scaffold_define_nonidempotent_method(remove_meth) do
            @record = klass.scaffold_find_object(:habtm, scaffold_request_id, :session=>scaffold_session)
            @associated_record = klass.scaffold_remove_associated_objects(association, @record, {:session=>scaffold_session}, scaffold_request_param(element_id))
            @auto_complete = auto_complete
            if scaffold_xhr?
              @remove_element_id = "#{sn}_#{@record.scaffold_id}_#{association}_#{@associated_record.scaffold_id}"
              @select_id = element_id
              @select_value = @associated_record.scaffold_id
              @select_text = @associated_record.scaffold_name
              @scaffold_javascript = true
              scaffold_render_template(remove_meth, {}, :inline=>'<%= scaffold_remove_existing_habtm_element %>')
            else
              scaffold_redirect_to(scaffold_url("edit#{suffix}", :id=>@record.scaffold_id))
            end
          end
        else
          suffix = "_#{sn}_#{association}"
          # aplch_name = association plural lower case human name
          scaffold_options={:aplch_name=>association.to_s.humanize.downcase, :singular_name=>sn, :association=>association, :class=>klass, :suffix=>suffix}
          # aslch_name = association singular lower case human name
          scaffold_options[:aslhc_name] = scaffold_options[:aplch_name].singularize
          
          scaffold_define_method("edit#{suffix}") do
            @scaffold_object = klass.scaffold_find_object(:habtm, scaffold_request_id, :session=>scaffold_session, :association=>association)
            @items_to_remove = klass.scaffold_associated_objects(association, @scaffold_object, :session=>scaffold_session)
            @items_to_add = klass.scaffold_unassociated_objects(association, @scaffold_object, :session=>scaffold_session) unless klass.scaffold_association_use_auto_complete(association)
            scaffold_render_template(:habtm, scaffold_options)
          end
          
          scaffold_define_nonidempotent_method("update#{suffix}") do
            @scaffold_object = klass.scaffold_find_object(:habtm, scaffold_request_id, :session=>scaffold_session, :association=>association)
            klass.scaffold_add_associated_objects(association, @scaffold_object, {:session=>scaffold_session}, *scaffold_select_ids(scaffold_request_param(:add)))
            klass.scaffold_remove_associated_objects(association, @scaffold_object, {:session=>scaffold_session}, *scaffold_select_ids(scaffold_request_param(:remove)))
            scaffold_redirect(:edit, suffix, "Updated #{@scaffold_object.scaffold_name}'s #{scaffold_options[:aplch_name]} successfully", @scaffold_object.scaffold_id)
          end
        end
      end
      
      # Setup resources used by both scaffold and scaffold_habtm.  Adds shared data structures that
      # should only be initialized once.
      def scaffold_setup
        return if @scaffolding_shared_resources_are_setup
        self.scaffolded_methods ||= Set.new
        self.scaffolded_nonidempotent_methods ||= Set.new
        self.scaffolded_auto_complete_associations ||= {}
        scaffold_setup_helper
        @scaffolding_shared_resources_are_setup = true
      end
  end
end
