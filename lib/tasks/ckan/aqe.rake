namespace :ckan do 

  namespace :airqualityeggs do

    task :update do 
      Rake.application.invoke_task("ckan:airqualityeggs:sites:check_resource_exists_and_upsert")
      Rake.application.invoke_task("ckan:airqualityeggs:data:check_resource_exists_and_upsert")
    end

    namespace :sites do

      AQE_SITE_FIELDS = [
        {:id => "id", :type => "int"},
        {:id => "creator", :type => "text"},
        {:id => "description", :type => "text"},
        {:id => "feed", :type => "text"},
        {:id => "location_domain", :type => "text"},
        {:id => "location_ele", :type => "text"},
        {:id => "location_exposure", :type => "text"},
        {:id => "location_lat", :type => "float"},
        {:id => "location_lon", :type => "float"},
        {:id => "private", :type => "text"},
        {:id => "status", :type => "text"},
        {:id => "tags", :type => "text"},
        {:id => "title", :type => "text"},
        {:id => "updated", :type => "timestamp"},
        {:id => "created", :type => "timestamp"},
      ]

      desc "Create CKAN resource for Air Quality Eggs (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_AQE_SITE_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_AQE_DATASET_ID'],
                :name => ENV['CKAN_AQE_SITE_RESOURCE_NAME']
              },
              :primary_key => 'id',
              :indexes => 'id,title,description,status,updated,created',
              :fields => AQE_SITE_FIELDS,
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          # puts "Created a new resource named '#{ENV['CKAN_AQE_SITE_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          # puts "Resource named '#{ENV['CKAN_AQE_SITE_RESOURCE_NAME']}' already existed"
        end
        # puts "Resource ID = #{resource_id}"
        # invoke upsert rake task
        Rake.application.invoke_task("ckan:airqualityeggs:sites:upsert[#{resource_id}]")
      end


      desc "Fetch and upsert data on Air Quality Egg sites"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "Xively credentials not set (see README)" unless ENV['XIVELY_API_KEY'] && ENV['XIVELY_PRODUCT_ID']

        # puts "Fetching metadata of all eggs..."
        all_eggs = JSON.parse(fetch_all_feeds)
        # puts "Upserting egg site data..."
        allowed_fields = AQE_SITE_FIELDS.map{|f| f[:id]}
        all_eggs.each do |egg|
          egg.delete_if{|k,v| !allowed_fields.include?(k)} # delete rare metadata fields we don't want to store
          egg[:title] = fix_encoding(egg["title"])
          egg[:description] = fix_encoding(egg["description"])
          post_data = {:resource_id => args[:resource_id], :records => [egg], :method => 'upsert'}.to_json
          upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          upsert_result = JSON.parse(upsert_raw)
        end

        # puts "\nAQE sites meta upserts complete"
      end
    end

    namespace :data do

      desc "Create CKAN resource for data (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_AQE_DATA_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        create_resource_data = {
          :primary_key => 'id',
          :fields => [
            {:id => "id", :type => "text"},
            {:id => "feed_id", :type => "int"},
            {:id => "datetime", :type => "timestamp"},
            {:id => "parameter", :type => "text"},
            {:id => "unit", :type => "text"},
            {:id => "value", :type => "float"},
            {:id => "lat", :type => "float"},
            {:id => "lon", :type => "float"},
            {:id => "computed_aqi", :type => "int"},
          ],
          :records => []
        }
        if resource.nil? # if there is no resource, create it inside the right package
          # modify indexes here because we have added custom ones through pgsql 
          create_resource_data[:indexes] = 'id,feed_id,datetime,parameter,unit'
          create_resource_data[:resource] = {:package_id => ENV['CKAN_AQE_DATASET_ID'], :name => ENV['CKAN_AQE_DATA_RESOURCE_NAME'] }

        create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create", create_resource_data.to_json,
          {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        create_results = JSON.parse(create_raw)
        resource_id = create_results["result"]["resource_id"]
        # puts "Created or updated a new resource named '#{ENV['CKAN_AQE_DATA_RESOURCE_NAME']}' (resource id = #{resource_id}"


        else # update existing resource
          resource_id = resource["id"]
        end

        # invoke upsert rake tasks
        Rake.application.invoke_task("ckan:airqualityeggs:data:upsert[#{resource_id}]")
      end

      desc "Get relevant datastreams from each AQE feed and store in CKAN"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "Xively credentials not set (see README)" unless ENV['XIVELY_PRODUCT_ID'] && ENV['XIVELY_API_KEY']

        # puts "Fetching all eggs..."
        all_eggs = JSON.parse(fetch_all_feeds) # TODO - get list of eggs from CKAN, not Xively again
        all_eggs.each do |egg|
          feed_id = egg["id"]
          # puts "Upserting data for Xively feed #{feed_id}... "
          egg_history = Xively::Client.get("https://api.xively.com/v2/feeds/#{feed_id}.json?interval=3600&duration=2days&limit=1000", :headers => {"X-ApiKey" => $api_key}).parsed_response
          egg_history["datastreams"].to_a.select{|d| !d["tags"].nil? && d["tags"].to_s.match(/computed/)}.each do |datastream|
            datastream_records = []
            datastream_name = datastream["id"].split("_").first
            datastream["datapoints"].to_a.each do |datapoint|
              computed_aqi = determine_aqi(datastream_name, datapoint["value"].to_f, datastream["unit"]["label"])
              row = {:feed_id => feed_id, :datetime => datapoint["at"], :value => datapoint["value"].to_f, :unit => datastream["unit"]["label"], :parameter => datastream_name, :lat => egg["location_lat"], :lon => egg["location_lon"], :computed_aqi => computed_aqi}
              row[:id] = "#{row[:feed_id]}|#{row[:datetime]}|#{row[:parameter]}"
              datastream_records << row
            end
            # batch upload datastream_records 
            if datastream_records != []
              post_data = {:resource_id => args[:resource_id], :records => datastream_records, :method => 'upsert'}.to_json
              # puts post_data
              upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
              upsert_result = JSON.parse(upsert_raw)
              sleep 2
            end
          end
        end

        # puts "\nAQE data upserts complete"
      end

    end

  end


end
