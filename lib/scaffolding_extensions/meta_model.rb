# Class methods shared by all models
#
# Many class methods can be overridden for particular use cases by setting other methods
# or instance variables.  For example, scaffold_fields is a method that takes an action,
# such as :new.  scaffold_fields(:new) will first check if scaffold_new_fields is a method, and
# will call it if so.  If not, it will check if @scaffold_new_fields is defined, and use it if
# so.  If not, will take the default course of action.
# 
# The first argument to the overridable method is used to search for the override method
# or instance variable.  If a override method is used, the remaining
# arguments to the overridable method will be passed to it.  Otherwise, the default method will
# be used.
#
# For example, scaffold_find_object(action, id, options) is an overridable method.
# That means if :delete is the action, it will first look for scaffold_delete_find_object, and if it
# exists it will call scaffold_delete_find_object(id, options).
#
# If a method can be overridden by an instance variable, it should have only one argument.
#
# The methods that are overridable by other methods are (without the "scaffold_" prefix): 
# add_associated_objects, associated_objects, association_find_object, association_find_objects,
# find_object, find_objects, new_associated_object_values, remove_associated_objects, save,
# unassociated_objects, and filter_attributes.
#
# The methods that are overridable by other methods or instance variables are (again, without the
# "scaffold_" prefix): associated_human_name, association_use_auto_complete, fields, include,
# select_order, attributes, include_association, and select_order_association.
#
# Most methods that find objects check options[:session][scaffold_session_value] as a
# security check if scaffold_session_value is set.
#
# There are some methods that are so similar that they are dynamically defined using
# define_method.  They are:
#
# - scaffold_association_list_class: The html class attribute of the association list
# - scaffold_habtm_with_ajax: Whether to use Ajax when scaffolding habtm associations for this model
# - scaffold_load_associations_with_ajax: Whether to use Ajax when loading associations on the edit page
# - scaffold_browse_records_per_page: The number of records to show on each page when using the browse scaffold
# - scaffold_convert_text_to_string: Whether to use input of type text instead of a text area for columns of type :text
# - scaffold_search_results_limit: The maximum number of results to show on the scaffolded search results page
#
# Each of these methods can be set with an instance variable.  If the instance variable is
# not set, it will use the default value from SCAFFOLD_OPTIONS.
module ScaffoldingExtensions::MetaModel
  # Sets the default options for all models, which can be overriden by class instance
  # variables (iv):
  # - :text_to_string: If true, by default, use input type text instead of textarea 
  #   for fields of type text (iv: @scaffold_convert_text_to_string)
  # - :table_classes: Set the default table classes for different scaffolded HTML tables
  #   (iv: @scaffold_table_classes)
  # - :column_type_options: Override the default options for a given column type
  #   (iv: @scaffold_column_type_options)
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
    :column_type_options=>{},
    :column_types=>{},
    :column_options=>{},
    :association_list_class=>''.freeze,
    :column_names=>{},
    :browse_limit=>10,
    :search_limit=>10,
    :habtm_ajax=>false,
    :load_associations_ajax=>false,
    :auto_complete=>{:enable=>false, :sql_name=>'LOWER(name)', :format_string=>:substring, 
      :search_operator=>'LIKE', :results_limit=>10, :phrase_modifier=>:downcase},
  }
  
  {:association_list_class=>:scaffold_association_list_class,
  :habtm_ajax=>:scaffold_habtm_with_ajax,
  :load_associations_ajax=>:scaffold_load_associations_with_ajax,
  :browse_limit=>:scaffold_browse_records_per_page,
  :text_to_string=>:scaffold_convert_text_to_string,
  :search_limit=>:scaffold_search_results_limit}.each do |default, iv|
    ivs = "@#{iv}"
    define_method(iv) do
      if instance_variables.include?(ivs)
        instance_variable_get(ivs)
      else
        instance_variable_set(ivs, SCAFFOLD_OPTIONS[default])
      end
    end
  end

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
  def scaffold_add_associated_objects(association, object, options, *associated_object_ids)
    unless associated_object_ids.empty?
      scaffold_transaction do
        associated_objects = associated_object_ids.collect do |associated_object_id|
          associated_object = scaffold_association_find_object(association, associated_object_id.to_i, :session=>options[:session])
          scaffold_add_associated_object(association, object, associated_object)
          associated_object
        end
        associated_object_ids.length == 1 ? associated_objects.first : associated_objects
      end
    end
  end

  # Return the human name for the given association, defaulting to humanizing the
  # association name
  def scaffold_associated_human_name(association)
    association.to_s.humanize
  end

  # The scaffold_name of the associated class.  Not overridable, as that allows for the
  # possibility of broken links.
  def scaffold_associated_name(association)
    scaffold_associated_class(association).scaffold_name
  end

  # All objects that are currently associated with the given object. This method does not
  # check that the returned associated objects meet the associated class's scaffold_session_value
  # constraint, as it is assumed that all objects currently assocated with the given object
  # have already met the criteria.  If that is not the case, you should override this method.
  def scaffold_associated_objects(association, object, options)
    object.send(association)
  end

  # Finds a given object in the associated class that has the matching id.
  def scaffold_association_find_object(association, id, options)
    scaffold_associated_class(association).scaffold_find_object(:associated, id, options)
  end
  
  # Find all objects of the associated class. Does not use any conditions of the association
  # (they are can't be used reliably, since they require an object to interpolate them), so
  # if there are special conditions on the association, you'll want to override this method.
  def scaffold_association_find_objects(association, options)
    klass = scaffold_associated_class(association)
    klass.scaffold_get_objects(:order=>scaffold_select_order_association(association), :include=>scaffold_include_association(association), :conditions=>klass.scaffold_session_conditions(options[:session]))
  end

  # Whether to use autocompleting for linked associations. Defaults to whether the
  # associated class uses auto completing.
  def scaffold_association_use_auto_complete(association)
    scaffold_associated_class(association).scaffold_use_auto_complete
  end

  # Defaults to associations specified by scaffold fields that are autocompleting. Can be set with an instance variable.
  def scaffold_auto_complete_associations
    @scaffold_auto_complete_associations ||= scaffold_fields(:edit).reject{|field| !(scaffold_association(field) && scaffold_association_use_auto_complete(field))}
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
        scaffold_associated_class(association).scaffold_auto_complete_find(phrase, :session=>session)
      end
    else
      find_options = { :limit => scaffold_auto_complete_results_limit,
          :conditions => [scaffold_auto_complete_conditions(phrase), scaffold_session_conditions(session)],
          :order => scaffold_select_order(:auto_complete),
          :include => scaffold_include(:auto_complete)}.merge(options)
      scaffold_get_objects(find_options)
    end
  end
  
  # Separate method for browsing objects, as it also needs to return whether or not there is another
  # page of objects.  Returns [another_page, objects], where another_page is true or false.
  def scaffold_browse_find_objects(options)
    get_options = {:order=>scaffold_select_order(:browse), :include=>scaffold_include(:browse), :conditions=>scaffold_session_conditions(options[:session])}
    if limit = scaffold_browse_records_per_page
      get_options[:offset] = (options[:page].to_i-1) * limit
      get_options[:limit] = limit = limit + 1
    end
    objects = scaffold_get_objects(get_options)
    if limit && objects.length == limit
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
    @scaffold_column_names ||= {}
    @scaffold_column_names[column_name] ||= if n = SCAFFOLD_OPTIONS[:column_names][column_name]
      n
    elsif scaffold_association(column_name)
      scaffold_associated_human_name(column_name)
    else
      column_name.to_s.humanize
    end 
  end

  # Returns any special options for a given attribute.  Can be set via the instance variable
  # @scaffold_column_options_hash, a hash with the column name as a symbol key and the html
  # options hash as the value.
  def scaffold_column_options(column_name)
    @scaffold_column_options_hash ||= {}
    @scaffold_column_options ||= {}
    @scaffold_column_options[column_name] ||= scaffold_merge_hashes(@scaffold_column_options_hash[column_name], SCAFFOLD_OPTIONS[:column_options][column_name], scaffold_column_type_options(scaffold_column_type(column_name)))
  end

  # Returns the column type for the given scaffolded column name.  Can be set via the instance
  # variable @scaffold_column_types, a hash with the column name as a symbol key and the html
  # type symbol as a value.  Associations have the :association type, and other types are looked
  # up via columns_hash[column_name].type.  If no type is provided, :string is used by default.
  def scaffold_column_type(column_name)
    @scaffold_column_types ||= {}
    @scaffold_column_types[column_name] ||= if type = SCAFFOLD_OPTIONS[:column_types][column_name]
      type
    elsif scaffold_association(column_name)
      :association
    elsif type = scaffold_table_column_type(column_name)
      (scaffold_convert_text_to_string && (type == :text)) ? :string : type
    else
      :string
    end
  end

  # The HTML options for a given column type, affecting all columns of that type.
  # Can be set with the @scaffold_column_type_options instance variable, which should
  # be a hash with the column type as a symbol key and the html options hash
  # as the value.
  def scaffold_column_type_options(type)
    @scaffold_column_type_options ||= {}
    @scaffold_column_type_options[type] ||= SCAFFOLD_OPTIONS[:column_type_options][type] || {}
  end

  # Returns the foreign key for the field if it is an association, or the field
  # as a string if it is not.
  def scaffold_field_id(field)
    if reflection = scaffold_association(field)
      scaffold_foreign_key(reflection)
    else
      field.to_s
    end
  end

  # Find the object of this model given by the id
  def scaffold_find_object(action, id, options)
    object = scaffold_get_object(id)
    raise scaffold_error_raised unless scaffold_session_value_matches?(object, options[:session])
    object
  end
  
  # Find all objects of this model
  def scaffold_find_objects(action, options)
    scaffold_get_objects(:order=>scaffold_select_order(action), :include=>scaffold_include(action), :conditions=>scaffold_session_conditions(options[:session]))
  end

  # Array of symbols for all habtm associations in this model's scaffold_associations.
  # Can be set with an instance variable.
  def scaffold_habtm_associations
    @scaffold_habtm_associations ||= scaffold_associations.reject{|association| scaffold_association_type(association) != :edit}
  end

  # The human name string for this model. Can be set with an instance variable.
  def scaffold_human_name
    @scaffold_human_name ||= scaffold_name.humanize
  end

  # Which associations to include when querying for multiple objects.
  # Can be set with an instance variable.
  def scaffold_include(action = :default)
    @scaffold_include
  end

  # The name string to use in urls, defaults to name.underscore.  Can be set with an 
  # instance variable.
  def scaffold_name
    @scaffold_name ||= name.underscore
  end

  # Merges the record with id from into the record with id to.  Updates all 
  # associated records for the record with id from to be assocatiated with
  # the record with id to instead, and then deletes the record with id from.
  #
  # Returns false if the ids given are the same or the scaffold_session_value
  # criteria is not met.
  def scaffold_merge_records(from, to, options)
    from, to = from.to_i, to.to_i
    return false if from == to
    from_object = scaffold_get_object(from)
    return false unless scaffold_session_value_matches?(from_object, options[:session])
    to_object = scaffold_get_object(to)
    return false unless scaffold_session_value_matches?(to_object, options[:session])
    scaffold_transaction do
      scaffold_all_associations.each{|reflection| scaffold_reflection_merge(reflection, from, to)}
      scaffold_destroy(from_object)
    end
    true
  end

  # Creates a new object, setting the attributes if given.
  def scaffold_new_object(attributes, options)
    object = new
    scaffold_set_attributes(object, scaffold_filter_attributes(:new, attributes || {}))
    object.send("#{scaffold_session_value}=", options[:session][scaffold_session_value]) if scaffold_session_value
    object
  end

  # Removes associated objects with the given ids from the given object's association.
  # Returns the associated object (if only one id was given), or an array of objects
  # (if multiple ids were given).
  def scaffold_remove_associated_objects(association, object, options, *associated_object_ids)
    unless associated_object_ids.empty?
      scaffold_transaction do
        associated_objects = associated_object_ids.collect do |associated_object_id|
          associated_object = scaffold_association_find_object(association, associated_object_id.to_i, :session=>options[:session])
          scaffold_remove_associated_object(association, object, associated_object)
          associated_object
        end
        associated_object_ids.length == 1 ? associated_objects.first : associated_objects
      end
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
    conditions = []
    search_model = options[:model] || {}
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
            conditions << scaffold_substring_condition(field, object.send(field))
          else
            conditions << scaffold_equal_condition(field, object.send(field))
          end
        form_params[:model][field] = search_model[field] if scaffold_search_pagination_enabled?
      end
    end
    
    scaffold_attributes(:search).each do |field|
      field = field.to_s
      if null && null.include?(field)
        conditions << scaffold_null_condition(field)
        form_params[:null] << field if scaffold_search_pagination_enabled?
      end
      if notnull && notnull.include?(field)
        conditions << scaffold_notnull_condition(field)
        form_params[:notnull] << field if scaffold_search_pagination_enabled?
      end
    end
    
    conditions << scaffold_session_conditions(options[:session])

    objects = scaffold_get_objects(:conditions=>conditions, :include=>scaffold_include(:search), :order=>scaffold_select_order(:search), :limit=>limit, :offset=>offset)
    if scaffold_search_pagination_enabled? && objects.length == scaffold_search_results_limit+1
      form_params[:next_page] = true
      objects.pop
    end
    [form_params, objects]
  end

  # List of human visible names and field name symbols to use for NULL/NOT NULL fields on the scaffolded search page.
  # Can be set with an instance variable.
  def scaffold_search_null_options
    @scaffold_search_null_options ||= scaffold_attributes(:search).reject{|f| scaffold_table_column_type(f).nil?}.collect{|f| [scaffold_column_name(f), f]}
  end
  
  # Returns a completely blank object suitable for searching, updated with the given attributes.
  def scaffold_search_object(attributes = {})
    object = new
    scaffold_attributes(:search).each{|field| object.send("#{field}=", nil) unless object.send(field) == nil}
    scaffold_set_attributes(object, attributes)
    object
  end
  
  # The SQL ORDER BY fragment string.  Can be set with an instance variable.
  def scaffold_select_order(action = :default)
    @scaffold_select_order
  end
  
  # The conditions array to use if scaffold_session_value is set, nil otherwise
  def scaffold_session_conditions(session)
    ["#{scaffold_table_name}.#{scaffold_session_value} = ?", session[scaffold_session_value]] if scaffold_session_value
  end

  # True if the given object meets the scaffold_session_value criteria
  def scaffold_session_value_matches?(object, session)
    !scaffold_session_value || object.send(scaffold_session_value) == session[scaffold_session_value]
  end

  # Whether to show associations links for the given association.  Generally true unless 
  # it is an :has_and_belongs_to_many association and scaffold_habtm_with_ajax is true.
  def scaffold_show_association_links?(association)
    !(scaffold_habtm_with_ajax && scaffold_association_type(association) == :edit)
  end

  # Returns the scaffolded table class for a given scaffold type. Can be set with
  # the instance variable @scaffold_table_classes, a hash with the type as the symbol key
  # and the value as the html class string.
  def scaffold_table_class(type)
    @scaffold_table_classes ||= {}
    @scaffold_table_classes[type] ||= SCAFFOLD_OPTIONS[:table_classes][type]
  end
  
  # Run the block inside a database transaction
  def scaffold_transaction(&block)
    transaction(&block)
  end
  
  # Returns all objects of the associated class not currently associated with this object.
  def scaffold_unassociated_objects(association, object, options)
    scaffold_associated_class(association).scaffold_get_objects(:conditions=>[scaffold_unassociated_condition(association, object), scaffold_associated_class(association).scaffold_session_conditions(options[:session])], :order=>scaffold_select_order_association(association), :include=>scaffold_include_association(association))
  end
  
  # Updates attributes for the given action, but does not save the record.
  def scaffold_update_attributes(object, attributes)
    scaffold_set_attributes(object, scaffold_filter_attributes(:edit, attributes))
  end

  # Whether this class should use an autocompleting text box instead of a select
  # box for choosing items.  Can be set with an instance variable.
  def scaffold_use_auto_complete
    @scaffold_use_auto_complete ||= scaffold_auto_complete_options[:enable]
  end

  private
    # scaffold_fields with associations replaced by foreign key fields
    def scaffold_attributes(action = :default)
      instance_variable_set("@scaffold_#{action}_attributes", scaffold_fields(action).collect{|field| scaffold_field_id(field).to_sym})
    end
    
    # The conditions to use for the scaffolded autocomplete find.
    def scaffold_auto_complete_conditions(phrase)
      [scaffold_auto_complete_conditions_phrase, (scaffold_auto_complete_search_format_string % phrase.send(scaffold_auto_complete_phrase_modifier))]
    end

    # The conditions phrase (the sql code with ? place holders) used in the
    # scaffolded autocomplete find.
    def scaffold_auto_complete_conditions_phrase
      scaffold_auto_complete_options[:conditions_phrase] ||= "#{scaffold_auto_complete_name_sql} #{scaffold_auto_complete_search_operator} ?"
    end

    # Search operator for matching scaffold_auto_complete_name_sql to format_string % phrase,
    # usally 'LIKE', but might be 'ILIKE' on some databases.
    def scaffold_auto_complete_search_operator
      scaffold_auto_complete_options[:search_operator]
    end

    # SQL fragment (usually column name) that is used when scaffold autocompleting is turned on.
    def scaffold_auto_complete_name_sql
      scaffold_auto_complete_options[:sql_name]
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
    # - :substring - Phase matches any substring of scaffold_auto_complete_name_sql
    # - :starting - Phrase matches the start of scaffold_auto_complete_name_sql
    # - :ending - Phrase matches the end of scaffold_auto_complete_name_sql
    # - :exact - Phrase matches scaffold_auto_complete_name_sql exactly
    def scaffold_auto_complete_search_format_string
      {:substring=>'%%%s%%', :starting=>'%s%%', :ending=>'%%%s', :exact=>'%s'}[scaffold_auto_complete_options[:format_string]] || scaffold_auto_complete_options[:format_string]
    end
    
    # Condition to ensure field equals value
    def scaffold_equal_condition(field, value)
      ["#{scaffold_table_name}.#{field} = ?", value]
    end

    # Filters the provided attributes to just the ones given by scaffold_attributes for
    # the given action.
    def scaffold_filter_attributes(action, attributes)
      allowed_attributes = scaffold_attributes(action).collect{|x| x.to_s}
      attributes.reject{|k,v| !allowed_attributes.include?(k.to_s.split('(')[0])}
    end
    
    # The associations to include when loading the association
    def scaffold_include_association(association)
      scaffold_associated_class(association).scaffold_include(:association)
    end

    # Merge all given hashes in order of preference, so earlier hashes are considered more important.
    # A nil value is treated the same as the empty hash.
    def scaffold_merge_hashes(*hashes)
      h = {}
      hashes.reverse.each{|hash| h.merge!(hash) if hash}
      h
    end

    # Condition to ensure field is not NULL
    def scaffold_notnull_condition(field)
      ["#{scaffold_table_name}.#{field} IS NOT NULL"]
    end
    
    # Condition to ensure field is NULL
    def scaffold_null_condition(field)
      ["#{scaffold_table_name}.#{field} IS NULL"]
    end

    # If search pagination is enabled (by default it is if 
    # scaffold_search_results_limit is not nil)
    def scaffold_search_pagination_enabled?
      !scaffold_search_results_limit.nil?
    end
    
    # The SQL ORDER BY fragment string when ordering the association.
    # Defaults to the scaffold_select_order for the associated class.
    def scaffold_select_order_association(association)
      scaffold_associated_class(association).scaffold_select_order(:association)
    end
    
    # Set the object's attributes with the given attributes
    def scaffold_set_attributes(object, attributes)
      attributes.each do |k,v|
        v = nil if v.empty? and scaffold_table_column_type(k) == :boolean
        object.send("#{k}=", v)
      end 
    end 

    # Condition to ensure value is a substring of field
    def scaffold_substring_condition(field, value)
      ["#{scaffold_table_name}.#{field} #{scaffold_auto_complete_search_operator} ?", "%#{value}%"]
    end
    
    # Condition to ensure that objects from the associated class are not currently associated with object
    def scaffold_unassociated_condition(association, object)
      klass, left_key, right_key, join_table = scaffold_habtm_reflection_options(association)
      ["#{klass.scaffold_table_name}.#{klass.scaffold_primary_key} NOT IN (SELECT #{join_table}.#{right_key} FROM #{join_table} WHERE #{join_table}.#{left_key} = ?)", object.scaffold_id]
    end
end
