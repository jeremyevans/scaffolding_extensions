# Instance methods shared by all models
module ScaffoldingExtensions::Model
  # an array of strings describing problems with the object (empty if none)
  def scaffold_error_messages
    errors.full_messages
  end 

  # The name given to the item that is used in various places in the scaffold.  For example,
  # it is used whenever the record is displayed in a select box.  Should be unique for each record,
  # but that is not required. Should be overridden by subclasses unless they have a unique attribute
  # named 'name'.
  def scaffold_name
    scaffold_attribute_value(:name) || scaffold_id.to_s
  end

  # scaffold_name prefixed with id, used for scaffold autocompleting
  def scaffold_name_with_id
    "#{scaffold_id} - #{scaffold_name}"
  end

  # the value of the field if not an association, or the scaffold_name of the associated object
  def scaffold_value(field)
    if self.class.scaffold_association(field)
      obj = send(field) 
      obj.scaffold_name if obj
    else
      send(field)
    end
  end
end
