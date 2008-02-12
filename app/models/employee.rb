class Employee < ActiveRecord::Base
  belongs_to :position
  has_and_belongs_to_many :groups
end
