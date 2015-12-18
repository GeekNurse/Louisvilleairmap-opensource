namespace :ckan do 
namespace :usgs do
task :update do

	url = 'http://waterdata.usgs.gov/ky/nwis/current?county_cd=21111&index_pmcode_ALL=ALL&index_pmcode_STATION_NM=1&index_pmcode_DATETIME=2&group_key=NONE&sitefile_output_format=html_table&column_name=agency_cd&column_name=site_no&column_name=station_nm&sort_key_2=site_no&html_table_group_key=NONE&format=rdb&rdb_compression=value&list_of_search_criteria=county_cd%2Crealtime_parameter_selection'
	meas_today = RestClient.get( url )
	meas_today = meas_today.split( "#" )
	meas_today = meas_today[ meas_today.length - 1 ]

	meas_today = meas_today.split( "\n" )

	hs = meas_today[ 1 ].split( "\t" )
	print hs

	tosend = []

	for i in 3..(meas_today.length-1)
		thismeas = meas_today[ i ].split( "\t" )

		tm_ts = {}
		j=0
		thismeas.each { |col_v|
			col_v = col_v.to_f if hs[j] == 'result_va'

			tm_ts[ hs[j] ] = col_v

			j+=1
		}
		tm_ts['uniquekey'] = thismeas[1] +","+ thismeas[3] +","+ thismeas[4]
		tosend << tm_ts
	end

	print tosend

	resource_id = '22bfd267-505f-4414-b2d3-22507bdc6886'

	post_data = {:resource_id => resource_id, :records => tosend, :method => 'upsert'}.to_json
	upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
	upsert_result = JSON.parse(upsert_raw)

	puts upsert_result

=begin
	site_data[:country_iso3166] = wupws_site_details["location"]["country_iso3166"]
	site_data[:city] = wupws_site_details["location"]["city"]
	site_data[:tz_short] = wupws_site_details["location"]["tz_short"]
	site_data[:lat] = wupws_site_details["location"]["lat"]
	site_data[:lon] = wupws_site_details["location"]["lon"]
	site_data[:zip] = wupws_site_details["location"]["zip"]
	site_data[:magic] = wupws_site_details["location"]["magic"]
	site_data[:wuiurl] = wupws_site_details["location"]["wuiurl"]
	site_data[:last_scraped_at] = Time.now.utc.iso8601

		post_data = {:resource_id => args[:resource_id], :records => wupws_sites, :method => 'upsert'}.to_json
		upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
		upsert_result = JSON.parse(upsert_raw)
=end

end
end
end
