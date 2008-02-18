# Instance methods used by both ActiveRecord and Datamapper
module ScaffoldingExtensions::ARDM
  # an array of strings describing problems with the object (empty if none)
  def scaffold_error_messages
    errors.full_messages
  end 

  # the value of the primary key for this object
  def scaffold_id
    id  
  end 
end

# Class methods used by both ActiveRecord and DataMapper
module ScaffoldingExtensions::MetaARDM
  # Find all objects of the associated class. Does not use any conditions of the association
  # (they are can't be used reliably, since they require an object to interpolate them), so
  # if there are special conditions on the association, you'll want to override this method.
  def scaffold_association_find_objects(association, options)
    klass = scaffold_associated_class(association)
    klass.scaffold_get_objects(:order=>scaffold_select_order_association(association), :include=>scaffold_include_association(association), :conditions=>klass.scaffold_session_conditions(options[:session]))
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
          :conditions => scaffold_auto_complete_conditions(phrase, (session[scaffold_session_value] if scaffold_session_value)),
          :order => scaffold_select_order(:auto_complete),
          :include => scaffold_include(:auto_complete)}.merge(options)
      scaffold_get_objects(find_options)
    end
  end

  # Separate method for browsing objects, as it also needs to return whether or not there is another
  # page of objects.  Returns [another_page, objects], where another_page is true or false.
  def scaffold_browse_find_objects(options)
    objects = scaffold_get_objects(:order=>scaffold_select_order(:browse), :include=>scaffold_include(:browse), :conditions=>scaffold_session_conditions(options[:session]), :limit=>scaffold_browse_records_per_page+1, :offset=>((options[:page].to_i-1)*scaffold_browse_records_per_page))
    if objects.length == scaffold_browse_records_per_page+1
      objects.pop
      [true, objects]
    else
      [false, objects]
    end 
  end 

  # Find all objects of this model
  def scaffold_find_objects(action, options)
    scaffold_get_objects(:order=>scaffold_select_order(action), :include=>scaffold_include(action), :conditions=>scaffold_session_conditions(options[:session]))
  end

  # Remove the associated object from object's association
  def scaffold_remove_associated_object(association, object, associated_object)
    object.send(association).delete(associated_object)
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
            conditions[0] << "#{scaffold_table_name}.#{field} #{scaffold_auto_complete_search_operator} ?"
            conditions << "%#{object.send(field)}%"
          else
            conditions[0] << "#{scaffold_table_name}.#{field} = ?"
            conditions << object.send(field)
          end
        form_params[:model][field] = search_model[field] if scaffold_search_pagination_enabled?
      end
    end
    
    scaffold_attributes(:search).each do |field|
      field = field.to_s
      if null && null.include?(field)
        conditions[0] << "#{scaffold_table_name}.#{field} IS NULL"
        form_params[:null] << field if scaffold_search_pagination_enabled?
      end
      if notnull && notnull.include?(field)
        conditions[0] << "#{scaffold_table_name}.#{field} IS NOT NULL"
        form_params[:notnull] << field if scaffold_search_pagination_enabled?
      end
    end

    if conds = scaffold_session_conditions(options[:session])
      conditions[0] << conds[0]
      conditions << conds[1]
    end

    conditions[0] = conditions[0].join(' AND ') 
    conditions = nil if conditions[0].length == 0

    objects = scaffold_get_objects(:conditions=>conditions, :include=>scaffold_include(:search), :order=>scaffold_select_order(:search), :limit=>limit, :offset=>offset)
    if scaffold_search_pagination_enabled? && objects.length == scaffold_search_results_limit+1
      form_params[:next_page] = true
      objects.pop
    end
    [form_params, objects]
  end

  # The conditions array to use if scaffold_session_value is set, nil otherwise
  def scaffold_session_conditions(session)
    ["#{scaffold_table_name}.#{scaffold_session_value} = ?", session[scaffold_session_value]] if scaffold_session_value
  end

  # Returns a completely blank object suitable for searching, updated with the given attributes.
  def scaffold_search_object(attributes = {})
    object = new
    scaffold_attributes(:search).each{|field| object.send("#{field}=", nil)}
    object.attributes = attributes
    object
  end
    
  # The SQL ORDER BY fragment to use when querying for multiple objects.
  # Can be set with an instance variable.
  def scaffold_select_order(action = :default)
    instance_variable_get("@scaffold_select_order")
  end

  # Run the block inside a database transaction
  def scaffold_transaction(&block)
    transaction(&block)
  end

  # Returns all objects of the associated class not currently associated with this object.
  def scaffold_unassociated_objects(association, object, options)
    klass, left_key, right_key, join_table = scaffold_habtm_reflection_options(association)
    conditions = ["#{klass.scaffold_table_name}.#{klass.scaffold_primary_key} NOT IN (SELECT #{join_table}.#{right_key} FROM #{join_table} WHERE #{join_table}.#{left_key} = ?)", object.id]
    if sess_val = klass.scaffold_session_value
      conditions[0] << " AND (#{klass.scaffold_table_name}.#{sess_val} = ?)"
      conditions << options[:session][sess_val]
    end
    klass.scaffold_get_objects(:conditions=>conditions, :order=>scaffold_select_order_association(association), :include=>scaffold_include_association(association))
  end

  # Updates attributes for the given action, but does not save the record.
  def scaffold_update_attributes(object, attributes)
    object.attributes = scaffold_filter_attributes(:edit, attributes)
  end

  private
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

    # SQL fragment (usually column name) that is used when scaffold autocompleting is turned on.
    def scaffold_name_sql
      scaffold_auto_complete_options[:sql_name]
    end

    # The SQL ORDER BY fragment to use when querying for multiple objects for the
    # association.
    def scaffold_select_order_association(association)
      scaffold_associated_class(association).scaffold_select_order(:association)
    end
end
