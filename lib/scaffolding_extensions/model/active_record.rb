module ScaffoldingExtensions
  # Defaults to @all_models, if not present, takes all model files, turns them into constants,
  # and checks if they are ancestors of ActiveRecord::Base.
  def self.all_models
    return @all_models if @all_models
    model_files.collect{|file|File.basename(file).sub(/\.rb\z/, '')}.collect{|m| m.camelize.constantize}.reject{|m| !m.ancestors.include?(::ActiveRecord::Base)}
  end
end

# Instance methods added to ActiveRecord::Base to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::ActiveRecord
  # Sets the default options for all models, which can be overriden by class instance
  # variables (iv):
  # - :text_to_string: If true, by default, use input type text instead of textarea 
  #   for fields of type text (iv: @scaffold_convert_text_to_string)
  # - :table_classes: Set the default table classes for different scaffolded HTML tables
  #   (iv: @scaffold_table_classes)
  # - :column_types: Override the default column type for a given attribute 
  #   (iv: @scaffold_column_types)
  # - :column_options: Override the default column options for a given attribute
  #   (iv: @scaffold_column_options_hash)
  # - :column_names: Override the visible names of columns for each attribute
  #   (iv: @scaffold_column_names)
  # - :association_list_class: Override the html class for the association list in the edit view
  #   (iv: @scaffold_association_list_class)
  # - :browse_limit: The default number of records per page to show in the
  #   browse scaffold. If nil, the search results will be displayed on one page instead
  #   of being paginated (iv: @scaffold_browse_records_per_page)
  # - :search_limit: The default limit on scaffolded search results.  If nil,
  #   the search results will be displayed on one page instead of being paginated
  #   (iv: @scaffold_search_results_limit)
  # - :habtm_ajax: Whether or not to use Ajax (instead of a separate page) for 
  #   modifying habtm associations (iv: @scaffold_habtm_with_ajax)
  # - :load_associations_ajax - Whether or not to use Ajax to load the display of
  #   associations on the edit page, useful if the default display is too slow
  #   (iv: @scaffold_load_associations_with_ajax)
  # - :auto_complete: Hash containing the default options to use for the scaffold
  #   autocompleter (iv: @scaffold_auto_complete_options)
  SCAFFOLD_OPTIONS = {:text_to_string=>false, 
    :table_classes=>{:form=>'formtable', :list=>'sortable', :show=>'sortable'},
    :column_types=>{},
    :column_options=>{},
    :association_list_class=>'',
    :column_names=>{},
    :browse_limit=>10,
    :search_limit=>10,
    :habtm_ajax=>false,
    :load_associations_ajax=>false,
    :auto_complete=>{:enable=>false, :sql_name=>'LOWER(name)', :format_string=>:substring, 
      :search_operator=>'LIKE', :results_limit=>10, :phrase_modifier=>:downcase},
  }
  # an array of strings describing problems with the object (empty if none)
  def scaffold_error_messages
    errors.full_messages
  end
  
  # the value of the primary key for this object
  def scaffold_id
    id
  end
  
  # The name given to the item that is used in various places in the scaffold.  For example,
  # it is used whenever the record is displayed in a select box.  Should be unique for each record,
  # but that is not required. Should be overridden by subclasses unless they have a unique attribute
  # named 'name'.
  def scaffold_name
    self[:name] || id.to_s
  end
  
  # scaffold_name prefixed with id, used for scaffold autocompleting
  def scaffold_name_with_id
    "#{id} - #{scaffold_name}"
  end
  
  # the value of the field if not an association, or the scaffold_name of the associated object
  def scaffold_value(field)
    if self.class.reflect_on_association(field)
      obj = send(field)
      obj.scaffold_name if obj
    else
      send(field)
    end
  end
end

# Class methods added to ActiveRecord::Base to allow it to work with Scaffolding Extensions.
#
# Many class methods can be overridden for particular use cases by setting other methods
# or instance variables.  For example, scaffold_fields is a method that takes an action,
# such as :new.  scaffold_fields(:new) will first check if scaffold_new_fields is a method, and
# will call it if so.  If not, it will check if @scaffold_new_fields is defined, and use it if
# so.  If not, will take the default course of action.
# 
# Methods that can be overridden by other methods will be notated:
#
#   Allows method override (argument)
#
# Methods that can be overridden by method or instance variable will be notated:
#
#   Allows method or instance variable override (argument)
#
# The argument is the name of the argument passed to the overridable method used to search for
# the override method or instance variable.  If a override method is used, the other
# arguments to the overridable method will be passed to it.
#
# For example, scaffold_find_object(id, action, options) is an overridable method,
# so its documentation states: "Allows method overrides (action)".  That means if
# :delete is the action, it will first look for scaffold_delete_find_object, and if it
# exists it will call scaffold_delete_find_object(id, options).
#
# If a method can be overridden by an instance variable, it shouldn't have any other arguments.
#
# Most methods that find objects check options[:session][scaffold_session_value] as a
# security check if scaffold_session_value is set.
module ScaffoldingExtensions::MetaActiveRecord
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::ActiveRecord::SCAFFOLD_OPTIONS
  
  # Control access to objects of this model via a session value.  For example
  # if set to :user_id, would only show objects with the same user_id as
  # session[:user_id], and would not allow access to any objects that didn't
  # have a matching user_id.
  attr_reader :scaffold_session_value
  
  # Override the typical table-based form display by overriding these wrappers.
  # Should return a proc that takes an html label and
  # widget and returns an html fragment.
  attr_reader :scaffold_field_wrapper
  
  # Override the typical table-based form display by overriding these wrappers.
  # Should return a proc that takes rows returned by
  # scaffold_field_wrapper and returns an html fragment.
  attr_reader :scaffold_form_wrapper
  
  # Add the objects specified by associated_object_ids to the given object
  # using the given association.  If the object to be associated with the given object is
  # already associated with it, skip it (don't try to associate it multiple times).
  # Returns the associated object (if only one id was given), or an array of objects
  # (if multiple ids were given).
  #
  # Allows method override (association)
  def scaffold_add_associated_objects(object, association, options, *associated_object_ids)
    if meth = scaffold_method_override(:add_associated_objects, association, object, options, *associated_object_ids)
      meth.call
    else
      unless associated_object_ids.empty?
        transaction do
          associated_objects = associated_object_ids.collect do |associated_object_id|
            associated_object = scaffold_association_find_object(associated_object_id.to_i, association, :session=>options[:session])
            association_proxy = object.send(association)
            next if association_proxy.include?(associated_object)
            association_proxy << associated_object 
            associated_object
          end
          associated_object_ids.length == 1 ? associated_objects.first : associated_objects
        end
      end
    end
  end
  
  # Return the human name for the given association, defaulting to humanizing the
  # association name
  #
  # Allows method or instance variable override (association)
  def scaffold_associated_human_name(association)
    if meth = scaffold_method_iv_override(:associated_human_name, association)
      meth.call
    else
      association.to_s.humanize
    end
  end
  
  # The scaffold_name of the associated class.  Not overridable, as that allows for the
  # possibility of broken links.
  def scaffold_associated_name(association)
    reflect_on_association(association).klass.scaffold_name
  end
  
  # All objects that are currently associated with the given object. This method does not
  # check that the returned associated objects meet the associated class's scaffold_session_value
  # constraint, as it is assumed that all objects currently assocated with the given object
  # have already met the criteria.  If that is not the case, you should override this method.
  #
  # Allows method override (association)
  def scaffold_associated_objects(object, association, options)
    if meth = scaffold_method_override(:associated_objects, association, object, options)
      meth.call
    else
      object.send(association)
    end
  end

  # Finds a given object in the associated class that has the matching id.
  # 
  # Allows method override (association)
  def scaffold_association_find_object(id, association, options)
    if meth = scaffold_method_override(:association_find_object, association, id, options)
      meth.call
    else
      klass = reflect_on_association(association).klass
      object = klass.find(id.to_i)
      raise ActiveRecord::RecordNotFound if klass.scaffold_session_value && object.send(klass.scaffold_session_value) != options[:session][klass.scaffold_session_value]
      object
    end
  end
  
  # Find all objects of the associated class. Does not use any conditions of the association
  # (they are can't be used reliably, since they require an object to interpolate them), so
  # if there are special conditions on the association, you'll want to override this method.
  #
  # Allows method override (association)
  def scaffold_association_find_objects(association, options)
    if meth = scaffold_method_override(:association_find_objects, association, options)
      meth.call
    else
      reflection = reflect_on_association(association)
      klass = reflection.klass
      if sess_val = klass.scaffold_session_value
        conditions = ["#{klass.table_name}.#{sess_val} = ?", options[:session][sess_val]]
      end
      klass.find(:all, :order=>scaffold_select_order_association(association), :include=>scaffold_include_association(association), :conditions=>conditions)
    end
  end
  
  # The html class attribute of the association list. Can be set with an instance variable.
  def scaffold_association_list_class
    @scaffold_association_list_class ||= SCAFFOLD_OPTIONS[:association_list_class].dup
  end
  
  # The type of association, either :new for :has_many (as you can create new objects
  # associated with the current object), :edit for :has_and_belongs_to_many (since you
  # can edit the list of associated objects), or :one for other associations.  I'm not
  # sure that :has_one is supported, as I don't use it.
  def scaffold_association_type(association)
    case reflect_on_association(association).macro
      when :has_many
        :new
      when :has_and_belongs_to_many
        :edit
      else
        :one
    end
  end
  
  # Whether to use autocompleting for linked associations. Defaults to whether the
  # associated class uses auto completing.
  #
  # Allows method or instance variable override (association)
  def scaffold_association_use_auto_complete(association)
    if meth = scaffold_method_iv_override(:association_use_auto_complete, association)
      meth.call
    else
      klass = reflect_on_association(association).klass
      klass.scaffold_use_auto_complete
    end
  end

  # List of symbols for associations to display on the scaffolded edit page. Defaults to
  # all associations that aren't :through or :polymorphic. Can be set with an instance variable.
  def scaffold_associations
    @scaffold_associations ||= reflect_on_all_associations.reject{|r| r.options.include?(:through) || r.options.include?(:polymorphic)}.collect{|r| r.name}.sort_by{|name| name.to_s}
  end

  # List of symbols of associations that require auto completing on the edit page (not the habtm page).
  # Defaults to associations specified by scaffold fields that are autocompleting. Can be set with an instance variable.
  def scaffold_auto_complete_associations
    @scaffold_auto_complete_associations ||= scaffold_fields(:edit).reject{|field| !(reflect_on_association(field) && scaffold_association_use_auto_complete(field))}
  end
  
  # Return all records that match the given phrase (usually a substring of
  # the most important column).  If options[:association] is present, delegate to the associated
  # class's scaffold_auto_complete_find.
  #
  # Allows method override (options.delete(:association))
  def scaffold_auto_complete_find(phrase, options = {})
    session = options.delete(:session)
    if association = options.delete(:association)
      if meth = scaffold_method_override(:auto_complete_find, association, phrase, options)
        meth.call
      else
        reflect_on_association(association).klass.scaffold_auto_complete_find(phrase, :session=>session)
      end
    else
      find_options = { :limit => scaffold_auto_complete_results_limit,
          :conditions => scaffold_auto_complete_conditions(phrase, (session[scaffold_session_value] if scaffold_session_value)), 
          :order => scaffold_select_order(:auto_complete),
          :include => scaffold_include(:auto_complete)}.merge(options)
      find(:all, find_options)
    end
  end
  
  # Separate method for browsing objects, as it also needs to return whether or not there is another
  # page of objects.  Returns [another_page, objects], where another_page is true or false.
  def scaffold_browse_find_objects(options)
    objects = find(:all, :order=>scaffold_select_order(:browse), :include=>scaffold_include(:browse), :conditions=>(["#{table_name}.#{scaffold_session_value} = ?", options[:session][scaffold_session_value]] if scaffold_session_value), :limit=>scaffold_browse_records_per_page+1, :offset=>((options[:page].to_i-1)*scaffold_browse_records_per_page))
    if objects.length == scaffold_browse_records_per_page+1
      objects.pop
      [true, objects]
    else
      [false, objects]
    end
  end
  
  # Returns the human name for a given attribute.  Can be set via the instance variable
  # @scaffold_column_names, a hash with the column name as a symbol key and the human name
  # string as the value.
  def scaffold_column_name(column_name)
    @scaffold_column_names ||= SCAFFOLD_OPTIONS[:column_names].dup
    @scaffold_column_names[column_name] ||= if reflect_on_association(column_name)
      scaffold_associated_human_name(column_name)
    else
      column_name.to_s.humanize
    end
  end
  
  # Returns any special options for a given attribute.  Can be set via the instance variable
  # @scaffold_column_options_hash, a hash with the column name as a symbol key and the html
  # options hash as the value.
  def scaffold_column_options(column_name)
    @scaffold_column_options_hash ||= SCAFFOLD_OPTIONS[:column_options].dup
    @scaffold_column_options_hash[column_name] || {}
  end
  
  # Returns the column type for the given scaffolded column name.  Can be set via the instance
  # variable @scaffold_column_types, a hash with the column name as a symbol key and the html
  # type symbol as a value.  Associations have the :association type, and other types are looked
  # up via columns_hash[column_name].type.  If no type is provided, :string is used by default.
  def scaffold_column_type(column_name)
    @scaffold_column_types ||= SCAFFOLD_OPTIONS[:column_types].dup
    if @scaffold_column_types[column_name]
      @scaffold_column_types[column_name]
    elsif reflect_on_association(column_name)
      :association
    elsif columns_hash.include?(column_name = column_name.to_s)
      type = columns_hash[column_name].type
      (scaffold_convert_text_to_string && (type == :text)) ? :string : type
    else
      :string
    end
  end
  
  # Destroys the object
  def scaffold_destroy(object)
    object.destroy
  end
  
  # Returns the foreign key for the field if it is an association, or the field
  # as a string if it is not.
  def scaffold_field_id(field)
    if reflection = reflect_on_association(field)
      reflection.primary_key_name
    else
      field.to_s
    end
  end
  
  # Returns the list of fields to display on the scaffolded forms. Defaults
  # to displaying all columns with the exception of primary key column, timestamp columns,
  # count columns, and inheritance columns.  Also includes belongs_to associations, replacing
  # the foriegn keys with the association itself.  Can be set with an instance variable.
  #
  # Allows method or instance variable override (action)
  def scaffold_fields(action = :default)
    if meth = scaffold_method_iv_override(:fields, action)
      meth.call
    else
      return @scaffold_fields if @scaffold_fields
      fields = columns.reject{|c| c.primary || c.name =~ /(\A(created|updated)_at|_count)\z/ || c.name == inheritance_column}.collect{|c| c.name}
      reflect_on_all_associations.each do |reflection|
        next if reflection.macro != :belongs_to || reflection.options.include?(:polymorphic)
        fields.delete(reflection.primary_key_name)
        fields.push(reflection.name.to_s)
      end
      @scaffold_fields = fields.sort.collect{|f| f.to_sym}
    end
  end
  
  # Find the object of this model given by the id
  #
  # Allows method override (action)
  def scaffold_find_object(id, action, options)
    if meth = scaffold_method_override(:find_object, action, id, options)
      meth.call
    else
      object = find(id.to_i)
      raise ActiveRecord::RecordNotFound if scaffold_session_value && object.send(scaffold_session_value) != options[:session][scaffold_session_value]
      object
    end
  end
  
  # Find all objects of this model
  #
  # Allows method override (action)
  def scaffold_find_objects(action, options)
    if meth = scaffold_method_override(:find_objects, action, options)
      meth.call
    else
      find(:all, :order=>scaffold_select_order(action), :include=>scaffold_include(action), :conditions=>(["#{table_name}.#{scaffold_session_value} = ?", options[:session][scaffold_session_value]] if scaffold_session_value))
    end
  end

  # Array of symbols for all habtm associations in this model's scaffold_associations.
  # Can be set with an instance variable.
  def scaffold_habtm_associations
    @scaffold_habtm_associations ||= scaffold_associations.reject{|a| reflect_on_association(a).macro != :has_and_belongs_to_many}
  end
  
  # Whether to use Ajax when scaffolding habtm associations for this model. Can be 
  # set with an instance variable.
  def scaffold_habtm_with_ajax
    @scaffold_habtm_with_ajax ||= SCAFFOLD_OPTIONS[:habtm_ajax]
  end
  
  # The human name string for this model. Can be set with an instance variable.
  def scaffold_human_name
    @scaffold_human_name ||= scaffold_name.humanize
  end

  # Which associations to include when querying for multiple objects.
  # Can be set with an instance variable.
  #
  # Allows method or instance variable override (action)
  def scaffold_include(action = :default)
    if meth = scaffold_method_iv_override(:include, action)
      meth.call
    else
      instance_variable_get("@scaffold_include")
    end
  end
  
  # Whether to use Ajax when loading associations on the edit page. Can be set
  # with an instance variable.
  def scaffold_load_associations_with_ajax
    @scaffold_load_associations_with_ajax ||= SCAFFOLD_OPTIONS[:load_associations_ajax]
  end

  # Merges the record with id from into the record with id to.  Updates all 
  # associated records for the record with id from to be assocatiated with
  # the record with id to instead, and then deletes the record with id from.
  #
  # Returns false if the ids given are the same or the scaffold_session_value
  # criteria is not met.
  def scaffold_merge_records(from, to)
    from, to = from.to_i, to.to_i
    return false if from == to
    [from, to].each{|i| return false if find(i).send(scaffold_session_value) != options[:session][scaffold_session_value]} if scaffold_session_value
    transaction do
      reflect_on_all_associations.each{|reflection| scaffold_reflection_merge(reflection, from, to)}
      destroy(from)
    end
    true
  end
  
  # The name string to use in urls, defaults to name.underscore.  Can be set with an 
  # instance variable.
  def scaffold_name
    @scaffold_name ||= name.underscore
  end
  
  # Returns a hash of values to be used as url parameters on the link to create a new
  # :has_many associated object.  Defaults to setting the foreign key field to the
  # record's primary key, and the STI type to this model's name, if :as is one of
  # the association's reflection's options.
  #
  # Allows method override (action)
  def scaffold_new_associated_object_values(record, association)
    if meth = scaffold_method_override(:new_associated_object_values, association, record)
      meth.call
    else
      reflection = reflect_on_association(association)
      vals = {reflection.primary_key_name=>record.id}
      vals["#{reflection.options[:as]}_type"] = name if reflection.options.include?(:as)
      vals
    end
  end
  
  # Creates a new object, setting the attributes if given.
  def scaffold_new_object(attributes, options)
    object = new(scaffold_filter_attributes('new', attributes || {}))
    object.send("#{scaffold_session_value}=", options[:session][scaffold_session_value]) if scaffold_session_value
    object
  end
  
  # Removes associated objects with the given ids from the given object's association.
  # Returns the associated object (if only one id was given), or an array of objects
  # (if multiple ids were given).
  #
  # Allows method override (association)
  def scaffold_remove_associated_objects(object, association, options, *associated_object_ids)
    if meth = scaffold_method_override(:remove_associated_objects, association, object, *associated_object_ids)
      meth.call
    else
      unless associated_object_ids.empty?
        transaction do
          associated_objects = associated_object_ids.collect do |associated_object_id|
            associated_object = scaffold_association_find_object(associated_object_id.to_i, association, :session=>options[:session])
            object.send(association).delete(associated_object)
            associated_object
          end
          associated_object_ids.length == 1 ? associated_objects.first : associated_objects
        end
      end
    end
  end
  
  # Saves the object.
  #
  # Allows method override (action)
  def scaffold_save(object, action)
    if meth = scaffold_method_override(:save, action, object)
      meth.call
    else
      object.save
    end
  end
  
  # Searches for objects that meet the criteria specified by options:
  # - :null: fields that must be must be NULL
  # - :notnull: matching fields must be NOT NULL
  # - :model: hash with field name strings as keys and strings as values.
  #   uses the value for each field to search.  Strings are searched based on
  #   substring, other values have to be an exact match.
  # - :page: To determine which offset to use
  #
  # Returns [form_params, objects], where form_params are a list of parameters
  # for the results form (for going to the next/previous page), and objects are
  # all of the objects that matched.
  def scaffold_search(options)
    conditions = [[]]
    search_model = options[:model]
    object = scaffold_search_object(search_model)
    null = options[:null]
    notnull = options[:notnull]
    form_params= {:model=>{}, :null=>[], :notnull=>[], :page=>options[:page]}
    
    limit, offset = nil, nil
    if scaffold_search_pagination_enabled?
      limit = scaffold_search_results_limit + 1
      offset = options[:page] > 1 ? (limit-1)*(options[:page] - 1) : nil
    end
    
    if search_model
      scaffold_attributes(:search).each do |field|
        fsym = field
        field = field.to_s
        next if (null && null.include?(field)) || \
            (notnull && notnull.include?(field)) || \
            search_model[field].nil? || search_model[field].empty?
        case scaffold_column_type(fsym)
          when :string, :text
            conditions[0] << "#{table_name}.#{field} #{scaffold_auto_complete_search_operator} ?"
            conditions << "%#{object.send(field)}%"
          else
            conditions[0] << "#{table_name}.#{field} = ?"
            conditions << object.send(field)
          end
        form_params[:model][field] = search_model[field] if scaffold_search_pagination_enabled?
      end
    end
    
    scaffold_attributes(:search).each do |field|
      field = field.to_s
      if null && null.include?(field)
        conditions[0] << "#{table_name}.#{field} IS NULL"
        form_params[:null] << field if scaffold_search_pagination_enabled?
      end
      if notnull && notnull.include?(field)
        conditions[0] << "#{table_name}.#{field} IS NOT NULL"
        form_params[:notnull] << field if scaffold_search_pagination_enabled?
      end
    end
    
    if scaffold_session_value
      conditions[0] << "#{table_name}.#{scaffold_session_value} = ?"
      conditions << options[:session][scaffold_session_value]
    end
    
    conditions[0] = conditions[0].join(' AND ')
    conditions = nil if conditions[0].length == 0
    
    objects = find(:all, :conditions=>conditions, :include=>scaffold_include(:search), :order=>scaffold_select_order(:search), :limit=>limit, :offset=>offset)
    if scaffold_search_pagination_enabled? && objects.length == scaffold_search_results_limit+1
      form_params[:next_page] = true
      objects.pop
    end
    [form_params, objects]
  end
  
  # List of human visible names and field name symbols to use for NULL/NOT NULL fields on the scaffolded search page.
  # Can be set with an instance variable.
  def scaffold_search_null_options
    @scaffold_search_null_options ||= scaffold_attributes(:search).reject{|f| !columns_hash[f.to_s]}.collect{|f| [scaffold_column_name(f), f]}
  end
  
  # Returns a completely blank object suitable for searching, updated with the given attributes.
  def scaffold_search_object(attributes = {})
    object = new
    scaffold_fields(:search).each{|field| object.send("#{field}=", nil)}
    object.attributes = attributes
    object
  end
  
  # The SQL ORDER BY fragment to use when querying for multiple objects.
  # Can be set with an instance variable.
  #
  # Allows method or instance variable override (action)
  def scaffold_select_order(action = :default)
    if meth = scaffold_method_iv_override(:select_order, action)
      meth.call
    else
      instance_variable_get("@scaffold_select_order")
    end
  end
  
  # Whether to show association links for the assocation, generally true unless
  # it is an :has_and_belongs_to_many association and scaffold_habtm_with_ajax is true.
  def scaffold_show_association_links?(association)
    !(scaffold_habtm_with_ajax && reflect_on_association(association).macro == :has_and_belongs_to_many)
  end
  
  # Returns the scaffolded table class for a given scaffold type. Can be set with
  # the instance variable @scaffold_table_classes, a hash with the type as the symbol key
  # and the value as the html class string.
  def scaffold_table_class(type)
    @scaffold_table_classes ||= SCAFFOLD_OPTIONS[:table_classes].dup
    @scaffold_table_classes[type]
  end
  
  # Returns all objects of the associated class not currently associated with this object.
  #
  # Allows method override (association)
  def scaffold_unassociated_objects(object, association, options)
    if meth = scaffold_method_override(:unassociated_objects, association, object, options)
      meth.call
    else
      reflection = reflect_on_association(association)
      klass = reflection.klass
      join_table = reflection.options[:join_table]
      conditions = ["#{klass.table_name}.#{klass.primary_key} NOT IN (SELECT #{join_table}.#{reflection.association_foreign_key} FROM #{join_table} WHERE #{join_table}.#{reflection.primary_key_name} = ?)", object.id]
      if sess_val = klass.scaffold_session_value
        conditions[0] << " AND (#{klass.table_name}.#{sess_val} = ?)"
        conditions << options[:session][sess_val]
      end
      klass.find(:all, :conditions=>conditions, :order=>scaffold_select_order_association(association), :include=>scaffold_include_association(association))
    end
  end
  
  # Updates attributes for the given action, but does not save the record.
  #
  # Allows method override (action)
  def scaffold_update_attributes(object, action, attributes)
    if meth = scaffold_method_override(:update_attributes, object, attributes)
      meth.call
    else
      object.attributes = scaffold_filter_attributes(action, attributes)
    end
  end
  
  # Whether this class should use an autocompleting text box instead of a select
  # box for choosing items.  Can be set with an instance variable.
  def scaffold_use_auto_complete
    @scaffold_use_auto_complete ||= scaffold_auto_complete_options[:enable]
  end

  private
    # scaffold_fields with associations replaced by foreign key fields
    #
    # Allows method or instance variable override (action)
    def scaffold_attributes(action = :default)
      if meth = scaffold_method_iv_override(:attributes, action)
        meth.call
      else
        instance_variable_set("@scaffold_#{action}_attributes", scaffold_fields(action).collect{|field| scaffold_field_id(field).to_sym})
      end
    end
    
    # The conditions to use for the scaffolded autocomplete find.
    def scaffold_auto_complete_conditions(phrase, session_value = nil)
      conditions = [scaffold_auto_complete_conditions_phrase, (scaffold_auto_complete_search_format_string % phrase.send(scaffold_auto_complete_phrase_modifier))]
      if scaffold_session_value && session_value
        conditions[0] += " AND #{table_name}.#{scaffold_session_value} = ?"
        conditions << session_value
      end
      conditions
    end
    
    # The conditions phrase (the sql code with ? place holders) used in the
    # scaffolded autocomplete find.
    def scaffold_auto_complete_conditions_phrase
      scaffold_auto_complete_options[:conditions_phrase] ||= "#{scaffold_name_sql} #{scaffold_auto_complete_search_operator} ?"
    end
    
    # A symbol for a string method to send to the submitted phrase.  Usually
    # :downcase to preform a case insensitive search, but may be :to_s for
    # a case sensitive search.
    def scaffold_auto_complete_phrase_modifier
      scaffold_auto_complete_options[:phrase_modifier]
    end
    
    # The number of results to return for the scaffolded autocomplete text box.
    def scaffold_auto_complete_results_limit
      scaffold_auto_complete_options[:results_limit]
    end
    
    # Format string used with the phrase to choose the type of search.  Can be
    # a user defined format string or one of these special symbols:
    # - :substring - Phase matches any substring of scaffold_name_sql
    # - :starting - Phrase matches the start of scaffold_name_sql
    # - :ending - Phrase matches the end of scaffold_name_sql
    # - :exact - Phrase matches scaffold_name_sql exactly
    def scaffold_auto_complete_search_format_string
      {:substring=>'%%%s%%', :starting=>'%s%%', :ending=>'%%%s', :exact=>'%s'}[scaffold_auto_complete_options[:format_string]] || scaffold_auto_complete_options[:format_string]
    end
    
    # Search operator for matching scaffold_name_sql to format_string % phrase,
    # usally 'LIKE', but might be 'ILIKE' on some databases.
    def scaffold_auto_complete_search_operator
      scaffold_auto_complete_options[:search_operator]
    end
    
    # If the auto complete options have been setup, return them.  Otherwise,
    # create the auto complete options using the defaults and the existing
    # class instance variable.  Can be set as an instance variable.
    def scaffold_auto_complete_options
      return @scaffold_auto_complete_options if @scaffold_auto_complete_options && @scaffold_auto_complete_options[:setup]
      @scaffold_auto_complete_options = @scaffold_auto_complete_options.nil? ? {} : {:enable=>true}.merge(@scaffold_auto_complete_options)
      @scaffold_auto_complete_options = SCAFFOLD_OPTIONS[:auto_complete].merge(@scaffold_auto_complete_options)
      @scaffold_auto_complete_options[:setup] = true
      @scaffold_auto_complete_options
    end
    
    # The number of records to show on each page when using the browse scaffold.
    # Can be set as an instance variable.
    def scaffold_browse_records_per_page
      @scaffold_browse_records_per_page ||= SCAFFOLD_OPTIONS[:browse_limit]
    end
    
    # Whether to use input of type text instead of a text area for columns of type :text.
    # Can be set as an instance variable.
    def scaffold_convert_text_to_string
      @scaffold_convert_text_to_string ||= SCAFFOLD_OPTIONS[:text_to_string]
    end
    
    # Filters the provided attributes to just the ones given by scaffold_attributes for
    # the given action.
    # 
    # Allows method or instance variable override (action)
    def scaffold_filter_attributes(action, attributes)
      if meth = scaffold_method_override(:filter_attributes, action, attributes)
        meth.call
      else
        allowed_attributes = scaffold_attributes(action).collect{|x| x.to_s}
        attributes.reject{|k,v| !allowed_attributes.include?(k.to_s.split('(')[0])}
      end
    end

    # The SQL ORDER BY fragment to use when querying for multiple objects
    #
    # Allows method or instance variable override (association)
    def scaffold_include_association(association)
      if meth = scaffold_method_iv_override(:include_association, association)
        meth.call
      else
        reflect_on_association(association).klass.scaffold_include(:association)
      end
    end
    
    # If a method exists matches scaffold_#{action}_#{m}, return a proc that calls it.
    # If not and the instance variable @scaffold_#{action}_#{m} is defined, return a
    # proc that gives that value.  Otherwise, return nil.
    def scaffold_method_iv_override(m, action)
      meth = "scaffold_#{action}_#{m}"
      if respond_to?(meth)
        Proc.new{send(meth)}
      elsif instance_variable_defined?(meth = "@#{meth}")
        Proc.new{instance_variable_get(meth)}
      end
    end
    
    # If a method exists matches scaffold_#{action}_#{m}, return a proc that calls it with
    # the other provided arguments, otherwise return nil.
    def scaffold_method_override(m, action, *args)
      meth = "scaffold_#{action}_#{m}"
      Proc.new{send(meth, *args)} if respond_to?(meth)
    end
    
    # SQL fragment (usually column name) that is used when scaffold autocompleting is turned on.
    def scaffold_name_sql
      scaffold_auto_complete_options[:sql_name]
    end
    
    # Updates associated records for a given reflection and from record to point to the
    # to record
    def scaffold_reflection_merge(reflection, from, to)
      foreign_key = reflection.primary_key_name
      sql = case reflection.macro
        when :has_one, :has_many
          return if reflection.options[:through]
          "UPDATE #{reflection.klass.table_name} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}#{" AND #{reflection.options[:as]}_type = #{quote_value(name.to_s)}" if reflection.options[:as]}"
        when :has_and_belongs_to_many
          "UPDATE #{reflection.options[:join_table]} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}" 
        else
          return
      end
      connection.update(sql)
    end
    
    # If search pagination is enabled (by default it is if 
    # scaffold_search_results_limit is not nil)
    def scaffold_search_pagination_enabled?
      !scaffold_search_results_limit.nil?
    end
    
    # The maximum number of results to show on the scaffolded search results page
    def scaffold_search_results_limit
      @scaffold_search_results_limit ||= SCAFFOLD_OPTIONS[:search_limit]
    end

    # The SQL ORDER BY fragment to use when querying for multiple objects
    #
    # Allows method or instance variable override (association)
    def scaffold_select_order_association(association)
      if meth = scaffold_method_iv_override(:select_order_association, association)
        meth.call
      else
        reflect_on_association(association).klass.scaffold_select_order(:association)
      end
    end
end

# Add the class methods and instance methods from Scaffolding Extensions
class ActiveRecord::Base
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::ActiveRecord::SCAFFOLD_OPTIONS
  include ScaffoldingExtensions::ActiveRecord
  extend ScaffoldingExtensions::MetaActiveRecord
end
