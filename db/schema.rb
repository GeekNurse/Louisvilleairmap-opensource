# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140420023203) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "epa_data", force: true do |t|
    t.string   "aqs_id"
    t.date     "date"
    t.time     "time"
    t.string   "parameter"
    t.string   "unit"
    t.decimal  "value"
    t.string   "data_source"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "epa_data", ["aqs_id", "date", "time"], name: "index_epa_data_on_aqs_id_and_date_and_time", using: :btree
  add_index "epa_data", ["aqs_id", "date"], name: "index_epa_data_on_aqs_id_and_date", using: :btree
  add_index "epa_data", ["aqs_id", "parameter", "date", "time"], name: "index_epa_data_on_aqs_id_and_parameter_and_date_and_time", using: :btree
  add_index "epa_data", ["aqs_id", "parameter", "date"], name: "index_epa_data_on_aqs_id_and_parameter_and_date", using: :btree
  add_index "epa_data", ["aqs_id", "parameter"], name: "index_epa_data_on_aqs_id_and_parameter", using: :btree

  create_table "epa_sites", id: false, force: true do |t|
    t.string   "aqs_id"
    t.string   "parameter"
    t.integer  "site_code"
    t.string   "site_name"
    t.string   "status"
    t.string   "agency_id"
    t.string   "agency_name"
    t.string   "epa_region"
    t.decimal  "lat"
    t.decimal  "lon"
    t.integer  "elevation"
    t.string   "gmt_offset"
    t.string   "country_code"
    t.integer  "cmsa_code"
    t.string   "cmsa_name"
    t.integer  "msa_code"
    t.string   "msa_name"
    t.integer  "state_code",   limit: 2
    t.string   "state_name"
    t.string   "county_code"
    t.string   "county_name"
    t.string   "city_code"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "epa_sites", ["aqs_id", "status"], name: "index_epa_sites_on_aqs_id_and_status", using: :btree
  add_index "epa_sites", ["status"], name: "index_epa_sites_on_status", using: :btree

end
