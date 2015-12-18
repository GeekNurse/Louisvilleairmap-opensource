class CreateEpaDatas < ActiveRecord::Migration
  def up
    create_table :epa_data do |t|
      # http://airnowapi.org/docs/HourlyDataFactSheet.pdf
      t.string :aqs_id#, :limit => 9
      t.date :date
      t.time :time
      t.string :parameter
      t.string :unit
      t.decimal :value
      t.string :data_source
      t.timestamps
    end
  end

  def down
    drop_table :epa_data
  end
end
