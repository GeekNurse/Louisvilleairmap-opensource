require 'geocoder'

namespace :ckan do 

  namespace :famallergy do

    task :update do 
      Rake.application.invoke_task("ckan:famallergy:sites:check_resource_exists_and_upsert")
      Rake.application.invoke_task("ckan:famallergy:data:check_resource_exists_and_upsert")
    end

    namespace :sites do

      FAMALLERGY_SITE_FIELDS = [
        {:id => "id", :type => "int"},
        {:id => "name", :type => "text"},
        {:id => "address", :type => "text"},
        {:id => "lat", :type => "float"},
        {:id => "lon", :type => "float"},
      ]

      FAMALLERGY_LOCATIONS = {
        "1" => {:name => "Central Kentucky", :address => "3292 Eagle View Lane, Lexington, KY 40509" },
        "2" => {:name => "Louisville Region", :address => "9800 Shelbyville Rd, Louisville, KY 40223" },
        "3" => {:name => "Northern Kentucky", :address => "5001 Houston Road, Florence, KY 41042" },
      }

      desc "Create CKAN resource for sites (if it doesn't exist) and then upsert CKAN with site data"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_FAMALLERGY_SITE_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_FAMALLERGY_DATASET_ID'],
                :name => ENV['CKAN_FAMALLERGY_SITE_RESOURCE_NAME']
              },
              :primary_key => 'id',
              :indexes => 'id,name,address,lat,lon',
              :fields => FAMALLERGY_SITE_FIELDS,
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          puts "Created a new resource named '#{ENV['CKAN_FAMALLERGY_DATA_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          puts "Resource named '#{ENV['CKAN_FAMALLERGY_DATA_RESOURCE_NAME']}' already existed"
        end
        puts "Resource ID = #{resource_id}"
        # invoke upsert rake task
        Rake.application.invoke_task("ckan:famallergy:sites:upsert[#{resource_id}]")
      end


      desc "Fetch and upsert data on sites"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?

        FAMALLERGY_LOCATIONS.each do |key,hash|
          site_data = hash.merge(:id => key)
          geocoder_results = Geocoder.search(hash[:address])
          geocoder_result = geocoder_results.first
          if geocoder_result
            site_data[:lat] = geocoder_result.data["geometry"]["location"]["lat"]
            site_data[:lon] = geocoder_result.data["geometry"]["location"]["lng"]
          end
          post_data = {:resource_id => args[:resource_id], :records => [site_data], :method => 'upsert'}.to_json
          upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          upsert_result = JSON.parse(upsert_raw)
        end
        puts "\nSites meta upserts complete"
      end
    end

    namespace :data do

      desc "Create CKAN resource for data (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_FAMALLERGY_DATA_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        create_resource_data = {
          :primary_key => 'id',
          :fields => [
            {:id => "id", :type => "text"},
            {:id => "site_id", :type => "int"},
            {:id => "datetime", :type => "timestamp"},
            {:id => "trees", :type => "text"},
            {:id => "weeds", :type => "text"},
            {:id => "grass", :type => "text"},
            {:id => "mold", :type => "text"},
          ],
          :records => []
        }
        if resource.nil? # if there is no resource, create it inside the right package
          # modify indexes here because we have added custom ones through pgsql 
          create_resource_data[:indexes] = 'id,datetime,trees,weeds,grass,mold'
          create_resource_data[:resource] = {:package_id => ENV['CKAN_FAMALLERGY_DATASET_ID'], :name => ENV['CKAN_FAMALLERGY_DATA_RESOURCE_NAME'] }
        else # update existing resource
          create_resource_data[:resource_id] = resource["id"]
        end
        create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create", create_resource_data.to_json,
          {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        create_results = JSON.parse(create_raw)
        resource_id = create_results["result"]["resource_id"]
        puts "Created or updated a new resource named '#{ENV['CKAN_FAMALLERGY_DATA_RESOURCE_NAME']}' (resource id = #{resource_id}"
        # invoke upsert rake tasks
        Rake.application.invoke_task("ckan:famallergy:data:upsert[#{resource_id}]")
      end

      desc "Get relevant data from each FAMALLERGY feed and store in CKAN"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?

        FAMALLERGY_LOCATIONS.each do |key,hash|
          data = JSON.parse(RestClient.get("http://www.familyallergy.com/res/ajax/pollen-count.php?location=#{key}"))
	  puts data
          monitoring_data = {
            :site_id => key.to_i,
            :trees => data["trees"],
            :weeds => data["weeds"],
            :grass => data["grass"],
            :mold => data["mold"],
            :datetime => Time.at(data["timestamp"].to_i).utc
          }
          monitoring_data[:id] = "#{monitoring_data[:site_id]}|#{monitoring_data[:datetime]}"
          post_data = {:resource_id => args[:resource_id], :records => [monitoring_data], :method => 'upsert'}.to_json
          upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          upsert_result = JSON.parse(upsert_raw)
        end
        puts "\nFAMALLERGY data upserts complete"
      end

    end

  end


end
