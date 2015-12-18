class CreateEpaSites < ActiveRecord::Migration
  def up
    create_table :epa_sites, :id => false, :primary_key => :aqs_id do |t|
      # http://airnowapi.org/docs/MonitoringSiteFactSheet.pdf
      t.string :aqs_id#, :limit => 9
      t.string :parameter
      t.integer :site_code, :limit => 4
      t.string :site_name#, :limit => 20
      t.string :status#, :limit => 8
      t.string :agency_id#, :limit => 4
      t.string :agency_name#, :limit => 60
      t.string :epa_region#, :limit => 2
      t.decimal :lat
      t.decimal :lon
      t.integer :elevation, :limit => 4
      t.string :gmt_offset#, :limit => 3
      t.string :country_code#, :limit => 2
      t.integer :cmsa_code, :limit => 4
      t.string :cmsa_name#, :limit => 50
      t.integer :msa_code, :limit => 4
      t.string :msa_name#, :limit => 50
      t.integer :state_code, :limit => 2
      t.string :state_name#, :limit => 2
      t.string :county_code#, :limit => 9
      t.string :county_name#, :limit => 25
      t.string :city_code#, :limit => 9
      t.timestamps
    end
  end

  def down
    drop_table :epa_sites
  end
end
