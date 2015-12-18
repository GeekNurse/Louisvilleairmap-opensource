namespace :ckan do 

  namespace :institute_messages do

    namespace :data do

      INSTITUTE_MESSAGES_DATA_FIELDS = [
      	{:id => "ctct_id", :type => "text"}, 
        {:id => "ctct_list_id", :type => "text"}, 
        {:id => "ctct_draft_saved_at", :type => "timestamp"},
        {:id => "message_type", :type => "text"},  # daily or alert
        {:id => "message_html", :type => "text"}, 
        {:id => "message_text", :type => "text"}, 
        {:id => "today_action_day", :type => "int"}, # 0 = no, 1 = yes
        {:id => "today_forecast_prevailing_aqi", :type => "int"}, 
        {:id => "today_forecast_prevailing_aqi_cat", :type => "text"}, 
        {:id => "today_forecast_prevailing_aqi_param", :type => "text"}, 
        {:id => "tomorrow_action_day", :type => "int"}, # 0 = no, 1 = yes
        {:id => "tomorrow_forecast_prevailing_aqi", :type => "int"}, 
        {:id => "tomorrow_forecast_prevailing_aqi_cat", :type => "text"}, 
        {:id => "tomorrow_forecast_prevailing_aqi_param", :type => "text"}, 
        {:id => "institute_total_eggs", :type => "int"},
        {:id => "institute_live_eggs", :type => "int"},
        {:id => "highest_observation_at", :type => "timestamp"}, 
        {:id => "highest_observation_aqi", :type => "int"}, 
        {:id => "highest_observation_aqi_cat", :type => "text"}, 
        {:id => "highest_observation_aqi_param", :type => "text"}
      ]

      desc "Create CKAN resource for sites (if it doesn't exist) and then upsert CKAN with site data"
      task :check_resource_exists do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_INSTITUTE_MESSAGES_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_INSTITUTE_MESSAGES_DATASET_ID'],
                :name => ENV['CKAN_INSTITUTE_MESSAGES_RESOURCE_NAME']
              },
              :primary_key => 'ctct_id',
              :fields => INSTITUTE_MESSAGES_DATA_FIELDS,
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          puts "Created a new resource named '#{ENV['CKAN_INSTITUTE_MESSAGES_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          puts "Resource named '#{ENV['CKAN_INSTITUTE_MESSAGES_RESOURCE_NAME']}' already existed"
        end
        puts "Resource ID = #{resource_id}"
      end

    end

	end

end