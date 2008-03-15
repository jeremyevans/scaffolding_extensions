# Instance methods used by both ActiveRecord and Datamapper
module ScaffoldingExtensions::ARDM
  # the value of the primary key for this object
  def scaffold_id
    id  
  end 
end

# Class methods used by both ActiveRecord and DataMapper
module ScaffoldingExtensions::MetaARDM
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
    
    # Remove the associated object from object's association
    def scaffold_remove_associated_object(association, object, associated_object)
      object.send(association).delete(associated_object)
    end
end
