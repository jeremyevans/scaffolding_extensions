ScaffoldingExtensions::MODEL_SUPERCLASSES << ::ActiveRecord::Base

# Instance methods added to ActiveRecord::Base to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::ActiveRecord
  # Get value for given attribute
  def scaffold_attribute_value(field)
    self[field]
  end

  # the value of the primary key for this object
  def scaffold_id
    id
  end
end

# Class methods added to ActiveRecord::Base to allow it to work with Scaffolding Extensions.
module ScaffoldingExtensions::MetaActiveRecord
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS
  
  # Add the associated object to the object's association
  def scaffold_add_associated_object(association, object, associated_object)
    association_proxy = object.send(association)
    next if association_proxy.include?(associated_object)
    association_proxy << associated_object
  end

  # Array of all association reflections for this model
  def scaffold_all_associations
    reflect_on_all_associations
  end
  
  # The class that this model is associated with via the association
  def scaffold_associated_class(association)
    scaffold_association(association).klass
  end
  
  # The association reflection for this association
  def scaffold_association(association)
    reflect_on_association(association)
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
  
  # List of symbols for associations to display on the scaffolded edit page. Defaults to
  # all associations that aren't :through or :polymorphic. Can be set with an instance variable.
  def scaffold_associations
    @scaffold_associations ||= scaffold_all_associations.reject{|r| r.options.include?(:through) || r.options.include?(:polymorphic)}.collect{|r| r.name}.sort_by{|name| name.to_s}
  end

  # Destroys the object
  def scaffold_destroy(object)
    object.destroy
  end

  # The error to raise, should match other errors raised by the underlying library.
  def scaffold_error_raised
    ::ActiveRecord::RecordNotFound
  end

  # Returns the list of fields to display on the scaffolded forms. Defaults
  # to displaying all columns with the exception of primary key column, timestamp columns,
  # count columns, and inheritance columns.  Also includes belongs_to associations, replacing
  # the foriegn keys with the association itself.  Can be set with an instance variable.
  def scaffold_fields(action = :default)
    return @scaffold_fields if @scaffold_fields
    fields = columns.reject{|c| c.primary || c.name =~ /(\A(created|updated)_at|_count)\z/ || c.name == inheritance_column}.collect{|c| c.name}
    scaffold_all_associations.each do |reflection|
      next if reflection.macro != :belongs_to || reflection.options.include?(:polymorphic)
      fields.delete(reflection.primary_key_name)
      fields.push(reflection.name.to_s)
    end
    @scaffold_fields = fields.sort.collect{|f| f.to_sym}
  end
  
  # The foreign key for the given reflection
  def scaffold_foreign_key(reflection)
    reflection.primary_key_name
  end
  
  # Retrieve a single model object given an id
  def scaffold_get_object(id)
    find(id.to_i)
  end

  # Retrieve multiple objects given a hash of options
  def scaffold_get_objects(options)
    options[:conditions] = scaffold_merge_conditions(options[:conditions])
    find(:all, options)
  end

  # Return the class, left foreign key, right foreign key, and join table for this habtm association
  def scaffold_habtm_reflection_options(association)
    reflection = reflect_on_association(association)
    [reflection.klass, reflection.primary_key_name, reflection.association_foreign_key, reflection.options[:join_table]]
  end

  # Returns a hash of values to be used as url parameters on the link to create a new
  # :has_many associated object.  Defaults to setting the foreign key field to the
  # record's primary key, and the STI type to this model's name, if :as is one of
  # the association's reflection's options.
  def scaffold_new_associated_object_values(association, record)
    reflection = reflect_on_association(association)
    vals = {reflection.primary_key_name=>record.id}
    vals["#{reflection.options[:as]}_type"] = name if reflection.options.include?(:as)
    vals
  end

  # The primary key for the given table
  def scaffold_primary_key
    primary_key
  end
  
  # Saves the object.
  def scaffold_save(action, object)
    object.save
  end
  
  # The column type for the given table column, or nil if it isn't a table column
  def scaffold_table_column_type(column)
    column = column.to_s
    column = columns_hash[column]
    column.type if column
  end

  # The name of the underlying table
  def scaffold_table_name
    table_name
  end

  private
    # Merge an array of conditions into a single condition array
    def scaffold_merge_conditions(conditions)
      new_conditions = [[]]
      if Array === conditions
        if conditions.length == 0 || (conditions.length == 1 && conditions[0].nil?)
          nil
        elsif Array === conditions[0]
          conditions.each do |cond|
            next unless cond
            new_conditions[0] << cond.shift
            cond.each{|c| new_conditions << c}
          end
          if new_conditions[0].length > 0
            new_conditions[0] = "(#{new_conditions[0].join(") AND (")})"
            new_conditions
          else
            nil
          end
        else
          conditions
        end
      else
        conditions
      end
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

    # Remove the associated object from object's association
    def scaffold_remove_associated_object(association, object, associated_object)
      object.send(association).delete(associated_object)
    end
end

# Add the class methods and instance methods from Scaffolding Extensions
class ActiveRecord::Base
  SCAFFOLD_OPTIONS = ::ScaffoldingExtensions::MetaModel::SCAFFOLD_OPTIONS
  include ScaffoldingExtensions::Model
  include ScaffoldingExtensions::ActiveRecord
  extend ScaffoldingExtensions::MetaModel
  extend ScaffoldingExtensions::MetaActiveRecord
  extend ScaffoldingExtensions::Overridable
end
