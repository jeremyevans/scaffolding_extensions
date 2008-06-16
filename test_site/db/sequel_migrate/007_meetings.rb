class CreateMeetings < Sequel::Migration
  def up
    create_table :meetings do
      primary_key :id
      varchar :name, :size=>255
    end
  end

  def down
    drop_table :meetings
  end
end
