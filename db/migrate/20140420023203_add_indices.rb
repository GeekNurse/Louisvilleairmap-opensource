class AddIndices < ActiveRecord::Migration
  def up
    # epa_sites table
    add_index :epa_sites, :status
    add_index :epa_sites, [:aqs_id, :status]

    # epa_data table
    add_index :epa_data, [:aqs_id, :date]
    add_index :epa_data, [:aqs_id, :date, :time]
    add_index :epa_data, [:aqs_id, :parameter]
    add_index :epa_data, [:aqs_id, :parameter, :date]
    add_index :epa_data, [:aqs_id, :parameter, :date, :time]
  end

  def down
    # epa_sites table
    remove_index :epa_sites, :status
    remove_index :epa_sites, [:aqs_id, :status]

    # epa_data table
    remove_index :epa_data, [:aqs_id, :date]
    remove_index :epa_data, [:aqs_id, :date, :time]
    remove_index :epa_data, [:aqs_id, :parameter]
    remove_index :epa_data, [:aqs_id, :parameter, :date]
    remove_index :epa_data, [:aqs_id, :parameter, :date, :time]
  end
end
