require 'pp'

ScaffoldingExtensions::MODEL_SUPERCLASSES << DataMapper::Resource

  def get_key_array_safe(key)
    if key.is_a?(Array) then
      if key.length==1
        key.first
      else
        key
      end
    else
      key
    end
  end

  def get_ordering_options(ordopts)
    result = []
    ordering = ordopts.dup
    ordering = ordering.split(',') unless ordering.is_a?(Array)
    ordering.each do |ord|
      asc = :asc
      if ord.upcase =~ /DESC/
        asc = :desc
      end
      ord.gsub!(/[Dd][Ee][Ss][Cc]|[Aa][Ss][Cc]/,"")
      ord.strip!
      if ord =~ /(\w+)\.(\w+)/
        tablename = $1
        propertyname = $2
        #TODO handling of associated orderings
        #optionshash[:order] << DataMapper::Query::Direction.new(eval("#{tablename.downcase.gsub(/\b[a-z]/) { |a| a.upcase }.gsub(/\s/, "")
        #}.properties[:#{propertyname.downcase}]"),asc)
        result << eval(":#{propertyname}.#{asc.to_s}")
      elsif ord =~ /(\w+)/
        propertyname = $1
        result << eval(":#{propertyname}.#{asc.to_s}")
      else
        # TODO Warning message
      end
    end
    result
  end

# Instance methods added to DataMapper::Resource to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::DataMapper
  # Get value for given attribute
  def scaffold_attribute_value(field)
    self[field]
  end

  # the value of the primary key for this object
  def scaffold_id
    get_key_array_safe(self.key)
  end
end

# Class methods added to DataMapper::Resource to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::MetaDataMapper
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS

  # Add the associated object to the object's association
  def scaffold_add_associated_object(association, object, associated_object)
    ap = object.send(association)
    ap << associated_object unless ap.include?(associated_object)
    object.save
  end

  # Array of all association reflections for this model
  # only shows the associations that are scaffolding_enabled
  def scaffold_all_associations
    relationships.values.select { |v|
      v.send(:target_model).respond_to?(:scaffold_name)
    }
  end

  # The class that this model is associated with via the association
  def scaffold_associated_class(association)
    relationships[association].target_model
  end

  # The association reflection for this association
  def scaffold_association(association)
    relationships[association]
  end

  # The type of association, either :new for :one_to_many (as you can create new objects
  # associated with the current object), :edit for :many_to_many (since you
  # can edit the list of associated objects), or :one for :many_to_one.
  def scaffold_association_type(association)
    if relationships[association].class == DataMapper::Associations::OneToMany::Relationship
        :new
    elsif relationships[association].class == DataMapper::Associations::ManyToMany::Relationship
        :edit
    else
        :one
    end
  end

  # List of symbols for associations to display on the scaffolded edit page. Defaults to
  # all associations for which the scaffolding is enabled. Can be set with an instance variable.
  def scaffold_associations
    @scaffold_associations ||= relationships.keys.select { |v|
      relationships[v].send(:target_model).respond_to?(:scaffold_name)
    }
  end

  # Destroys the object
  def scaffold_destroy(object)
    object.destroy
  end

  # The error to raise, should match other errors raised by the underlying library.
  def scaffold_error_raised
    DataMapper::ObjectNotFoundError
  end

  # Returns the list of fields to display on the scaffolded forms. Defaults
  # to displaying all columns with the exception of the primary key column.
  # Also includes :many_to_one associations, replacing
  # the foriegn keys with the association itself.  Can be set with an instance variable.
  def scaffold_fields(action = :default)
    return @scaffold_fields if @scaffold_fields
    fields = (properties.map {|a| a.name}) - [scaffold_primary_key]
    scaffold_all_associations.each do |reflection|
      next unless reflection.class == DataMapper::Associations::ManyToOne::Relationship
      fields.delete(get_key_array_safe(reflection.send(:child_key)).name)
      fields.push(reflection.name)
    end
    @scaffold_fields = fields.sort_by{|f| f.to_s}
  end

  # The foreign key for the given reflection
  def scaffold_foreign_key(reflection)
    get_key_array_safe(reflection.child_key).name
  end

  # Retrieve a single model object given an id
  def scaffold_get_object(id)
    self.get(id) || (raise scaffold_error_raised)
  end

  # All objects that are currently associated with the given object. This method does not
  # check that the returned associated objects meet the associated class's scaffold_session_value
  # constraint, as it is assumed that all objects currently assocated with the given object
  # have already met the criteria.  If that is not the case, you should override this method.
  def scaffold_associated_objects(association, object, options)
    object.send(association,:order => get_ordering_options(scaffold_select_order_association(association)))
  end

  # Retrieve multiple objects given a hash of options
  def scaffold_get_objects(options)
    optionshash = {}
    data = self.all
    if options[:conditions]
      conditions = options[:conditions]
      if conditions && Array === conditions && conditions.length > 0
        if String === conditions[0]
          data = data.all(:conditions => conditions)
        else
          conditions.each do |cond|
            next if cond.nil?
            data = case cond
              when Hash, String then data.all(:conditions => [cond.gsub("NULL","?"),nil])
              when Array then 
                if cond.length==1
                  data.all(:conditions => [cond[0].gsub("NULL","?"),nil])
                else
                  data.all(:conditions => cond)
                end
              when Proc then data.all(&cond)
            end
          end
        end
      end
    end
    slice = nil
    if options[:limit]
      startpos = options[:offset] || 0
      endpos = options[:limit]
      slice = [startpos,endpos]
    end
    # TODO includes break SQL generation
    # optionshash[:links] = options[:include] if options[:include]
    # optionshash[:links] = [optionshash[:links]] unless optionshash[:links].is_a?(Array)
    optionshash[:order] = get_ordering_options(options[:order])
    if slice then
      q = data.all(optionshash).slice(*slice)
    else
      q = data.all(optionshash)
    end
    #p repository.adapter.send("select_statement",q.query)
    q.to_a
  end

  # Return the class, left foreign key, right foreign key, and join table for this habtm association
  def scaffold_habtm_reflection_options(association)
    habtm = relationships[association]
    [
      habtm.target_model,
      get_key_array_safe(habtm.through.child_key).name,
      get_key_array_safe(habtm.via.child_key).name,
      habtm.send(:through_model).storage_name
    ]
  end

  # Returns a hash of values to be used as url parameters on the link to create a new
  # :has_many associated object.  Defaults to setting the foreign key field to the
  # record's primary key.
  def scaffold_new_associated_object_values(association, record)
    {scaffold_foreign_key(scaffold_association(association))=>record.scaffold_id}
  end

  # The primary key for the given table
  def scaffold_primary_key
    get_key_array_safe(key).name
  end
  
  # Saves the object.
  def scaffold_save(action, object)
    object.save
  end
  
  # The column type for the given table column, or nil if it isn't a table column
  def scaffold_table_column_type(column)
    column = self.properties[column]
    if column then
      if column.type == DataMapper::Types::Text
        :text
      else
        column.type.to_s.split("::").last.downcase.intern
      end
    else
      nil
    end
  end

  # The name of the underlying table
  def scaffold_table_name
    storage_name
  end

  private
    # Updates associated records for a given reflection and from record to point to the
    # to record
    def scaffold_reflection_merge(reflection, from, to)
      if reflection.class == DataMapper::Associations::OneToMany::Relationship
        foreign_key = get_key_array_safe(reflection.target_key).name
        p reflection
        p reflection.target_model
        table = reflection.target_model
      elsif reflection.class == DataMapper::Associations::ManyToMany::Relationship
        foreign_key = get_key_array_safe(reflection.through.child_key).name
        p reflection
        table = reflection.send(:through_model)
        p table
      else
        return
      end
      table.all(foreign_key => from).update(foreign_key => to)
    end

    # Remove the associated object from object's association
    def scaffold_remove_associated_object(association, object, associated_object)
      object.send(association).delete(associated_object)
      object.save
    end

    # Set the object's attributes with the given attributes
    def scaffold_set_attributes(object, attributes)
      attributes.each do |k,v|
        v = nil if v.empty? and (scaffold_table_column_type(k) == :boolean or scaffold_table_column_type(k) == :integer)
        object.send("#{k}=", v)
      end 
    end 

end

def add_scaffolding_methods(classes)
  unless classes.is_a?(Array)
    classes = [classes]
  end
  classes.each do |cl|
    cl.class_eval <<-ECLASS
      SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS
      include ScaffoldingExtensions::Model
      include ScaffoldingExtensions::DataMapper
      extend ScaffoldingExtensions::MetaModel
      extend ScaffoldingExtensions::MetaDataMapper
      extend ScaffoldingExtensions::Overridable
    ECLASS
  end
end

