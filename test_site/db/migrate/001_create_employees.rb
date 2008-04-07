class CreateEmployees < ActiveRecord::Migration
  def self.up
    create_table :employees do |t|
      t.string :name
      t.boolean :active
      t.integer :position_id
      t.text :comment
      t.string :password
    end
  end

  def self.down
    drop_table :employees
  end
end
