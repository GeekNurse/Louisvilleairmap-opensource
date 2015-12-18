namespace :ckan do 

  namespace :nursinghome do

    task :update do 
      Rake.application.invoke_task("ckan:nursinghome:sites:check_resource_exists_and_upsert")
    end

    namespace :sites do

      NURSINGHOME_SITE_FIELDS = [
      	{:id => "federal_provider_number", :type => "text"}, 
        {:id => "provider_name", :type => "text"}, 
        {:id => "lat", :type => "float"},
        {:id => "lon", :type => "float"},
      	{:id => "provider_type", :type => "text"},
        {:id => "provider_county_name", :type => "text"},
        {:id => "provider_city", :type => "text"}, 
        {:id => "provider_phone_number", :type => "text"},  # special path
        {:id => "legal_business_name", :type => "text"}, 
        {:id => "ownership_type", :type => "text"}, 
        {:id => "provider_state", :type => "text"}, 
        {:id => "provider_address", :type => "text"},
        {:id => "provider_zip_code", :type => "text"},
        {:id => "number_of_fines", :type => "int"},
        {:id => "number_of_facility_reported_incidents", :type => "int"},
        {:id => "total_number_of_penalties", :type => "int"},
        {:id => "number_of_substantiated_complaints", :type => "int"},
        {:id => "number_of_certified_beds", :type => "int"},
        {:id => "number_of_residents_in_certified_beds", :type => "int"},
        {:id => "total_weighted_health_survey_score", :type => "float"},
        {:id => "overall_rating", :type => "int"},
        {:id => "rn_staffing_rating", :type => "int"},
        {:id => "qm_rating", :type => "int"},
        {:id => "staffing_rating", :type => "int"},
        {:id => "health_inspection_rating", :type => "int"},
        {:id => "processing_date", :type => "timestamp"}
      ]

      desc "Create CKAN resource for sites (if it doesn't exist) and then upsert CKAN with site data"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_NURSINGHOME_SITE_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_NURSINGHOME_DATASET_ID'],
                :name => ENV['CKAN_NURSINGHOME_SITE_RESOURCE_NAME']
              },
              :primary_key => 'federal_provider_number',
              :indexes => NURSINGHOME_SITE_FIELDS.map{|x| x[:id]}.join(","),
              :fields => NURSINGHOME_SITE_FIELDS,
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          puts "Created a new resource named '#{ENV['CKAN_NURSINGHOME_SITE_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          puts "Resource named '#{ENV['CKAN_NURSINGHOME_SITE_RESOURCE_NAME']}' already existed"
        end
        puts "Resource ID = #{resource_id}"
        # invoke upsert rake task
        Rake.application.invoke_task("ckan:nursinghome:sites:upsert[#{resource_id}]")
      end


      desc "Fetch and upsert data on sites"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
				socrata_endpoint = "http://data.medicare.gov/resource/hq9i-23gr.json?provider_state=#{ENV['FOCUS_CITY_STATE']}"
        nursing_homes = fetch_whole_socrata_dataset(socrata_endpoint)
        nursing_homes.each do |home|
          site_data = {}
					site_data["federal_provider_number"] = home["federal_provider_number"]
					site_data["provider_name"] = home["provider_name"]
					site_data["lat"] = home["location"]["latitude"] if home["location"]
					site_data["lon"] = home["location"]["longitude"] if home["location"]
					site_data["provider_type"] = home["provider_type"]
					site_data["provider_county_name"] = home["provider_county_name"]
					site_data["provider_city"] = home["provider_city"]
					site_data["provider_phone_number"] = home["provider_phone_number"]["phone_number"]
					site_data["legal_business_name"] = home["legal_business_name"]
					site_data["ownership_type"] = home["ownership_type"]
					site_data["provider_state"] = home["provider_state"]
					site_data["provider_address"] = home["provider_address"]
					site_data["provider_zip_code"] = home["provider_zip_code"]
					site_data["number_of_fines"] = home["number_of_fines"]
					site_data["number_of_facility_reported_incidents"] = home["number_of_facility_reported_incidents"]
					site_data["total_number_of_penalties"] = home["total_number_of_penalties"]
					site_data["number_of_substantiated_complaints"] = home["number_of_substantiated_complaints"]
					site_data["number_of_certified_beds"] = home["number_of_certified_beds"]
					site_data["number_of_residents_in_certified_beds"] = home["number_of_residents_in_certified_beds"]
					site_data["total_weighted_health_survey_score"] = home["total_weighted_health_survey_score"]
					site_data["overall_rating"] = home["overall_rating"]
					site_data["rn_staffing_rating"] = home["rn_staffing_rating"]
					site_data["qm_rating"] = home["qm_rating"]
					site_data["staffing_rating"] = home["staffing_rating"]
					site_data["health_inspection_rating"] = home["health_inspection_rating"]
					site_data["processing_date"] = home["processing_date"]
          post_data = {:resource_id => args[:resource_id], :records => [site_data], :method => 'upsert'}.to_json
          upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          upsert_result = JSON.parse(upsert_raw)
        end
        puts "\nSites upserts complete"
      end
    end

	end

end