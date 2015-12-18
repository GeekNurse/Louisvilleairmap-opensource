namespace :ckan do 

  namespace :manylabs do

    task :update do 
      Rake.application.invoke_task("ckan:manylabs:data:check_resource_exists_and_upsert")
    end

    namespace :data do

      desc "Create CKAN resource for data (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
		puts "Accessing CKAN"
		scriptstarttime = Time.now
		puts "starting script at #{scriptstarttime} ..."
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_AQS_DATA_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first

        create_resource_data = {
          :primary_key => 'id',
          :fields => [
            {:id => "id", :type => "text"},
            {:id => "aqs_id", :type => "text"},
            {:id => "date", :type => "date"},
            {:id => "time", :type => "time"},
            {:id => "parameter", :type => "text"},
            {:id => "unit", :type => "text"},
            {:id => "value", :type => "float"},
            {:id => "data_source", :type => "text"},                
            {:id => "computed_aqi", :type => "int"},                
            {:id => "datetime", :type => "timestamp"},
          ],
          :records => []
        }

        if resource.nil? # if there is no resource, create it inside the right package
          puts "Resource doesn't exist"
          # modify indexes here because we have added custom ones through pgsql 
          create_resource_data[:indexes] = 'id,aqs_id,date,time,parameter,datetime',
          create_resource_data[:resource] = {:package_id => ENV['CKAN_AQS_DATASET_ID'], :name => ENV['CKAN_AQS_DATA_RESOURCE_NAME'] }
        else # update existing resource
	  puts "Resource exists"
          create_resource_data[:resource_id] = resource["id"]
        end
        begin
        create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create", create_resource_data.to_json,
          {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        create_results = JSON.parse(create_raw)
        resource_id = create_results["result"]["resource_id"]
        rescue
          resource_id = resource["id"]
        end
        puts "Created/updated a new resource named '#{ENV['CKAN_AQS_DATA_RESOURCE_NAME']}' (resource id = #{resource_id}"

        # invoke upsert rake tasks
        Rake.application.invoke_task("ckan:manylabs:data:upsert_data[#{resource_id}]")
      end

      desc "Get ManyLabs data and upsert into CKAN"
      task :upsert_data, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        
        monitoring_data = []

        puts "starting to get ManyLabs sensor data"
		manylabs_sites = ['552','553','554','555','556','557','558','562','563','564','565','566','567','568','569','570','571','572','573','574','576','577','548','582','583','584','585','586']
		manylabs_sites.each do |site|
			puts "getting manylab data for site #{site}"
			# index = 1
			getDP = []
			#LOOPS THROUGH THE PAGES - GET LAST DATAPOINTS
			# loop do
				begin
					nextpage = 
						JSON.parse(
							RestClient.get( 'https://www.manylabs.org/data/api/v0/datasets/' + site + '/rows/?order=newfirst' )
						)
				rescue => e
					break
				end

			getDP = nextpage['results']
			getDP.each do |dp_raw|
				data = dp_raw['data']
			
				dp = {
					:aqs_id => (10000 + site.to_i).to_s,
					:date => Time.at( data[0] ).strftime("%Y-%m-%d"),
					:time => Time.at( data[0] ).strftime("%H:%M:%S"),
					:parameter => "Temperature",
					:unit => "F",
					:value => data[1].to_f * 9/5 + 32,
					:data_source => "ManyLabs"
				}
				dp[:datetime] = dp[:date] + " " + dp[:time]
				dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:parameter]}"
				monitoring_data << dp

				dp = {
					:aqs_id => (10000 + site.to_i).to_s,
					:date => Time.at( data[0] ).strftime("%Y-%m-%d"),
					:time => Time.at( data[0] ).strftime("%H:%M:%S"),
					:parameter => "Humidity",
					:unit => "%",
					:value => data[2].to_f,
					:data_source => "ManyLabs"
				}
				dp[:datetime] = dp[:date] + " " + dp[:time]
				dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:parameter]}"
				monitoring_data << dp

				dp = {
					:aqs_id => (10000 + site.to_i).to_s,
					:date => Time.at( data[0] ).strftime("%Y-%m-%d"),
					:time => Time.at( data[0] ).strftime("%H:%M:%S"),
					:parameter => "Dust Count",
					:unit => "",
					:value => data[3].to_f,
					:data_source => "ManyLabs"
				}
				dp[:datetime] = dp[:date] + " " + dp[:time]
				dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:parameter]}"
				monitoring_data << dp

				dp = {
					:aqs_id => (10000 + site.to_i).to_s,
					:date => Time.at( data[0] ).strftime("%Y-%m-%d"),
					:time => Time.at( data[0] ).strftime("%H:%M:%S"),
					:parameter => "PM2.5",
					:unit => "",
					:value => data[5].to_f,
					:data_source => "ManyLabs"
				}
				dp[:datetime] = dp[:date] + " " + dp[:time]
				dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:parameter]}"
				monitoring_data << dp

				dp = {
					:aqs_id => (10000 + site.to_i).to_s,
					:date => Time.at( data[0] ).strftime("%Y-%m-%d"),
					:time => Time.at( data[0] ).strftime("%H:%M:%S"),
					:parameter => "CO",
					:unit => "ppm",
					:value => data[6].to_f,
					:data_source => "ManyLabs"
				}
				dp[:datetime] = dp[:date] + " " + dp[:time]
				dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:parameter]}"
				monitoring_data << dp
				# puts monitoring_data
			end
			puts "Finished getting all ManyLabs data for #{site}"
		end
		puts "HERE is the monitoring data ..."
		puts monitoring_data
		puts "uploading data to CKAN ...."
		post_data = {:resource_id => args[:resource_id], :records => monitoring_data, :method => 'upsert'}.to_json
		puts post_data
		upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
		upsert_result = JSON.parse(upsert_raw)
		puts upsert_result
        scriptendtime = Time.now
		puts "ending script at #{scriptendtime} ..."
        puts "\nManylabs data upserts complete"
      end

    end

  end

end
