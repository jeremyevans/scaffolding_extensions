require 'scaffolding_extensions/model/ardm'

ScaffoldingExtensions::MODEL_SUPERCLASSES << ::DataMapper::Base

# Instance methods added to DataMapper::Base to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::DataMapper
  # Get value for given attribute
  def scaffold_attribute_value(field)
    attributes[field]
  end
end

# Class methods added to DataMapper::Base to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::MetaDataMapper
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS

  # Add the associated object to the object's association
  def scaffold_add_associated_object(association, object, associated_object)
    association_proxy = object.send(association)
    next if association_proxy.include?(associated_object)
    association_proxy << associated_object
    object.save
  end
  
  # Array of all association reflections for this model
  def scaffold_all_associations
    database.schema[self].associations.to_a
  end
  
  # The class that this model is associated with via the association
  def scaffold_associated_class(association)
    case reflection = scaffold_association(association)
      when DataMapper::Associations::HasManyAssociation
        reflection.associated_constant
      else
        reflection.constant
    end
  end
  
  # The association reflection for this association
  def scaffold_association(association)
    database.schema[self].associations.each{|assoc| return assoc if assoc.name == association}
    nil
  end

  # The type of association, either :new for :has_many (as you can create new objects
  # associated with the current object), :edit for :has_and_belongs_to_many (since you
  # can edit the list of associated objects), or :one for other associations.  I'm not
  # sure that :has_one is supported, as I don't use it.
  def scaffold_association_type(association)
    case scaffold_association(association)
      when DataMapper::Associations::HasManyAssociation
        :new
      when DataMapper::Associations::HasAndBelongsToManyAssociation
        :edit
      else
        :one
    end
  end
  
  # List of symbols for associations to display on the scaffolded edit page. Defaults to
  # all associations that aren't :through or :polymorphic. Can be set with an instance variable.
  def scaffold_associations
    @scaffold_associations ||= scaffold_all_associations.collect{|assoc| assoc.name}.sort_by{|name| name.to_s}
  end

  # Destroys the object
  def scaffold_destroy(object)
    object.destroy!
  end
  
  # The error to raise, should match other errors raised by the underlying library.
  # I'm not sure that this is the correct error, but it is the most common error I've
  # received.
  def scaffold_error_raised
    ::DataObject::ReaderClosed
  end
  
  # Returns the list of fields to display on the scaffolded forms. Defaults
  # to displaying all columns with the exception of primary key column, timestamp columns,
  # count columns, and inheritance columns.  Also includes belongs_to associations, replacing
  # the foriegn keys with the association itself.  Can be set with an instance variable.
  def scaffold_fields(action = :default)
    return @scaffold_fields if @scaffold_fields
    schema = database.schema[self]
    key = schema.key.name
    fields = schema.columns.to_a.collect{|x| x.name}.reject{|x| x == key}
    schema.associations.each do |r| 
      next unless DataMapper::Associations::BelongsToAssociation === r 
      fields << r.name 
      fields.delete(r.foreign_key_name.to_sym)
    end
    @scaffold_fields = fields.sort_by{|x| x.to_s}
  end
  
  # The foreign key for the given reflection
  def scaffold_foreign_key(reflection)
    reflection.foreign_key_name
  end
  
  # Retrieve a single model object given an id
  def scaffold_get_object(id)
    self[id]
  end

  # Retrieve multiple objects given a hash of options
  def scaffold_get_objects(options)
    options.delete(:include)
    options[:conditions] = scaffold_merge_conditions(options[:conditions])
    all(options)
  end

  # Return the class, left foreign key, right foreign key, and join table for this habtm association
  def scaffold_habtm_reflection_options(association)
    reflection = scaffold_association(association)
    [reflection.constant, reflection.left_foreign_key, reflection.right_foreign_key, reflection.join_table]
  end

  # DataMapper doesn't use includes, so this is always nil
  def scaffold_include(action = :default)
    nil
  end

  # Returns a hash of values to be used as url parameters on the link to create a new
  # :has_many associated object.  Defaults to setting the foreign key field to the
  # record's primary key.
  def scaffold_new_associated_object_values(association, record)
    {scaffold_foreign_key(scaffold_association(association))=>record.id}
  end
  
  # The primary key for the given table
  def scaffold_primary_key
    database.schema[self].key.name
  end

  # Saves the object.
  def scaffold_save(action, object)
    object.save rescue false
  end

  # The column type for the given table column, or nil if it isn't a table column
  def scaffold_table_column_type(column)
    column = database.schema[self][column]
    column.type if column
  end

  # The name of the underlying table
  def scaffold_table_name
    database.schema[self].name
  end

  private
    # DataMapper doesn't need to include, so this is always nil
    def scaffold_include_association(association)
      nil
    end
    
    # Updates associated records for a given reflection and from record to point to the
    # to record
    def scaffold_reflection_merge(reflection, from, to)
      sql = case reflection
        when DataMapper::Associations::HasManyAssociation
          foreign_key = scaffold_foreign_key(reflection)
          "UPDATE #{reflection.associated_constant.scaffold_table_name} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}"
        when DataMapper::Associations::HasAndBelongsToManyAssociation
          foreign_key = reflection.left_foreign_key
          "UPDATE #{reflection.join_table} SET #{foreign_key} = #{to} WHERE #{foreign_key} = #{from}" 
        else
          return
      end
      database.execute(sql)
    end
end

# Add the class methods and instance methods from Scaffolding Extensions
class DataMapper::Base
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS
  include ScaffoldingExtensions::Model
  include ScaffoldingExtensions::ARDM
  include ScaffoldingExtensions::DataMapper
  extend ScaffoldingExtensions::MetaModel
  extend ScaffoldingExtensions::MetaARDM
  extend ScaffoldingExtensions::MetaDataMapper
  extend ScaffoldingExtensions::Overridable
  class << self
    extend ScaffoldingExtensions::MetaOverridable
    scaffold_override_methods(:add_associated_objects, :associated_objects, :association_find_object, :association_find_objects, :find_object, :find_objects, :new_associated_object_values, :remove_associated_objects, :save, :unassociated_objects, :filter_attributes)
    scaffold_override_iv_methods(:associated_human_name, :association_use_auto_complete, :fields, :select_order, :attributes, :select_order_association)
  end
end
