namespace :ckan do 

  namespace :bikes do 

    task :update do 
      Rake.application.invoke_task("ckan:bikes:data:check_resource_exists_and_upsert")
    end

    namespace :data do

      BIKES_DATA_FIELDS = [
        {:id => "id", :type => "text"},
        {:id => "bike_id", :type => "text"},
        {:id => "datetime", :type => "timestamp"},
        {:id => "parameter", :type => "text"},
        {:id => "unit", :type => "text"},
        {:id => "value", :type => "float"},
        {:id => "lat", :type => "float"},
        {:id => "lon", :type => "float"},
        {:id => "computed_aqi", :type => "int"},
      ]

      desc "Create CKAN resource for data (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_BIKE_DATA_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first        
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_BIKE_DATASET_ID'],
                :name => ENV['CKAN_BIKE_DATA_RESOURCE_NAME']
              },
              :primary_key => 'id',
              :indexes => 'id,bike_id,datetime,parameter,unit,value,lat,lon,computed_aqi',
              :fields => BIKES_DATA_FIELDS,
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          puts "Created a new resource named '#{ENV['CKAN_BIKE_DATA_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          puts "Resource named '#{ENV['CKAN_BIKE_DATA_RESOURCE_NAME']}' already existed"
        end

        puts "Created or updated a new resource named '#{ENV['CKAN_BIKE_DATA_RESOURCE_NAME']}' (resource id = #{resource_id}"
        # invoke upsert rake tasks
        Rake.application.invoke_task("ckan:bikes:data:upsert[#{resource_id}]")
      end

      desc "Get relevant datastreams from each bike feed and store in CKAN"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?

        data = File.read("/Users/mark/Box\ Sync/Louisville\ Community\ Data/MiscFiles/From\ DurhamLabs/output-fromChrisL-07162014.csv")
        CSV.parse(data, :col_sep => ",") do |row|
          unless row[0].nil?
            monitoring_data = {
              :bike_id => row[0],
              :datetime => row[1],
              :lat => row[2],
              :lon => row[3],
              :parameter => row[4],
              :value => row[5].to_f,
              :unit => row[6]
            }
            monitoring_data[:computed_aqi] = determine_aqi(monitoring_data[:parameter], monitoring_data[:value], monitoring_data[:unit])
            monitoring_data[:id] = "#{monitoring_data[:bike_id]}|#{monitoring_data[:datetime]}|#{monitoring_data[:parameter]}"
            post_data = {:resource_id => args[:resource_id], :records => [monitoring_data], :method => 'upsert'}.to_json
            upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
            upsert_result = JSON.parse(upsert_raw)
          end
        end

        puts "\nBike data upserts complete"
      end
    end
    
  end

end