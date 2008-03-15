ScaffoldingExtensions::MODEL_SUPERCLASSES << Sequel::Model

# Instance methods added to Sequel::Model to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::Sequel
  # Get value for given attribute
  def scaffold_attribute_value(field)
    values[field]
  end

  # the value of the primary key for this object
  def scaffold_id
    pk 
  end
end

# Class methods added to Sequel::Model to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::MetaSequel
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS
  
  # Add the associated object to the object's association
  def scaffold_add_associated_object(association, object, associated_object)
    object.send(association_add_method_name(association.to_s), associated_object)
  end

  # Array of all association reflections for this model
  def scaffold_all_associations
    all_association_reflections
  end
  
  # The class that this model is associated with via the association
  def scaffold_associated_class(association)
    associated_class(association_reflection(association))
  end
  
  # All objects that are currently associated with the given object. This method does not
  # check that the returned associated objects meet the associated class's scaffold_session_value
  # constraint, as it is assumed that all objects currently assocated with the given object
  # have already met the criteria.  If that is not the case, you should override this method.
  def scaffold_associated_objects(association, object, options)
    assoc = object.send(association)
    reflection = association_reflection(association)
    reflection[:cache] || reflection[:type] == :many_to_one ? assoc : assoc.all
  end
  
  # The association reflection for this association
  def scaffold_association(association)
    association_reflection(association)
  end

  # The type of association, either :new for :one_to_many (as you can create new objects
  # associated with the current object), :edit for :many_to_many (since you
  # can edit the list of associated objects), or :one for :many_to_one.
  def scaffold_association_type(association)
    case scaffold_association(association)[:type]
      when :one_to_many
        :new
      when :many_to_many
        :edit
      else
        :one
    end
  end
  
  # List of symbols for associations to display on the scaffolded edit page. Defaults to
  # all associations. Can be set with an instance variable.
  def scaffold_associations
    associations.sort_by{|name| name.to_s}
  end

  # Destroys the object
  def scaffold_destroy(object)
    object.destroy
  end

  # The error to raise, should match other errors raised by the underlying library.
  def scaffold_error_raised
    Sequel::Error
  end

  # Returns the list of fields to display on the scaffolded forms. Defaults
  # to displaying all columns with the exception of the primary key column.
  # Also includes :many_to_one associations, replacing
  # the foriegn keys with the association itself.  Can be set with an instance variable.
  def scaffold_fields(action = :default)
    return @scaffold_fields if @scaffold_fields
    fields = columns - [primary_key]
    all_association_reflections.each do |reflection|
      next unless reflection[:type] == :many_to_one
      fields.delete(reflection[:key].to_sym)
      fields.push(reflection[:name])
    end
    @scaffold_fields = fields.sort_by{|f| f.to_s}
  end
  
  # The foreign key for the given reflection
  def scaffold_foreign_key(reflection)
    reflection[:key]
  end
  
  # Retrieve a single model object given an id
  def scaffold_get_object(id)
    self[id.to_i] || (raise scaffold_error_raised)
  end

  # Retrieve multiple objects given a hash of options
  def scaffold_get_objects(options)
    records = dataset
    conditions = options[:conditions]
    if conditions && Array === conditions && conditions.length > 0
      if String === conditions[0]
        records = records.filter(*conditions)
      else
        conditions.each do |cond|
          next if cond.nil?
          records = case cond
            when Hash, String then records.filter(cond)
            when Array then records.filter(*cond)
            when Proc then records.filter(&cond)
          end
        end
      end
    end
    order = options[:order]
    order = [order] unless Array === order
    order.each do |o|
      next if o.nil?
      records = case o
        when Proc then records.order(&o)
        else records.order(o)
      end
    end
    records = records.limit(options[:limit], options[:offset]) if options[:limit]
    records.all
  end

  # Return the class, left foreign key, right foreign key, and join table for this habtm association
  def scaffold_habtm_reflection_options(association)
    reflection = scaffold_association(association)
    [reflection[:class], reflection[:left_key], reflection[:right_key], reflection[:join_table]]
  end

  # Sequel doesn't do eager loading yet, so this is always nil 
  def scaffold_include(action = :default)
    nil
  end

  # Returns a hash of values to be used as url parameters on the link to create a new
  # :has_many associated object.  Defaults to setting the foreign key field to the
  # record's primary key.
  def scaffold_new_associated_object_values(association, record)
    {scaffold_foreign_key(association_reflection(association))=>record.pk}
  end

  # The primary key for the given table
  def scaffold_primary_key
    primary_key
  end
  
  # Saves the object.
  def scaffold_save(action, object)
    object.save
  end
  
  # Sequel doesn't keep enough reflection information, so assume string unless
  # specified by @scaffold_column_types.
  def scaffold_table_column_type(column)
    # column is provided by the user, so we can't just .to_sym it
    @scaffold_column_types_strings ||= Hash.new do |h,k1| 
      @scaffold_column_types.each{|k2,v| h[k2] = v; h[k2.to_s] = v}
      h[k1] if h.include?(k1)
    end
    @scaffold_column_types_strings[column] || :string
  end

  # The name of the underlying table
  def scaffold_table_name
    table_name
  end

  # Sequel doesn't allow you to use transaction on a model (only on a database),
  # so add a transaction method that starts a transaction on the associated database.
  def transaction(&block)
    db.transaction(&block)
  end

  private
    # Sequel doesn't do eager loading yet
    def scaffold_include_association(association)
      nil
    end
    
    # Updates associated records for a given reflection and from record to point to the
    # to record
    def scaffold_reflection_merge(reflection, from, to)
      case reflection[:type]
        when :one_to_many
          foreign_key = reflection[:key]
          db << "UPDATE #{reflection[:class].table_name} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}"
        when :many_to_many
          foreign_key = reflection[:left_key]
          db << "UPDATE #{reflection[:join_table]} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}" 
      end
    end
    
    # Remove the associated object from object's association
    def scaffold_remove_associated_object(association, object, associated_object)
      object.send(association_remove_method_name(association.to_s), associated_object)
    end
end

# Add the class methods and instance methods from Scaffolding Extensions
class Sequel::Model
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS
  include ScaffoldingExtensions::Model
  include ScaffoldingExtensions::Sequel
  extend ScaffoldingExtensions::MetaModel
  extend ScaffoldingExtensions::MetaSequel
  extend ScaffoldingExtensions::Overridable
  class << self
    extend ScaffoldingExtensions::MetaOverridable
    scaffold_override_methods(:add_associated_objects, :associated_objects, :association_find_object, :association_find_objects, :find_object, :find_objects, :new_associated_object_values, :remove_associated_objects, :save, :unassociated_objects, :filter_attributes)
    scaffold_override_iv_methods(:associated_human_name, :association_use_auto_complete, :fields, :select_order, :attributes, :select_order_association)
  end
end
