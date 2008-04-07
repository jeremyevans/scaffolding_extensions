class CreateOfficers < ActiveRecord::Migration
  def self.up
    create_table :officers do |t|
      t.string :name
      t.integer :position_id
    end
  end

  def self.down
    drop_table :officers
  end
end
