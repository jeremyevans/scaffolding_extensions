# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of Active Record to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 9) do

  create_table "employees", :force => true do |t|
    t.string  "name"
    t.boolean "active"
    t.integer "position_id"
    t.text    "comment"
    t.string  "password"
  end

  create_table "employees_groups", :id => false, :force => true do |t|
    t.integer "employee_id"
    t.integer "group_id"
  end

  create_table "groups", :force => true do |t|
    t.string "name"
  end

  create_table "groups_meetings", :id => false, :force => true do |t|
    t.integer "group_id"
    t.integer "meeting_id"
  end

  create_table "groups_officers", :id => false, :force => true do |t|
    t.integer "group_id"
    t.integer "officer_id"
  end

  create_table "meetings", :force => true do |t|
    t.string "name"
  end

  create_table "meetings_positions", :id => false, :force => true do |t|
    t.integer "meeting_id"
    t.integer "position_id"
  end

  create_table "officers", :force => true do |t|
    t.string  "name"
    t.integer "position_id"
  end

  create_table "positions", :force => true do |t|
    t.string "name"
  end

end
