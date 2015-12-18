namespace :ckan do 

  namespace :wupws do

    task :update do 
      Rake.application.invoke_task("ckan:wupws:sites:check_resource_exists_and_upsert")
    end

    namespace :sites do

      WUPWS_SITE_LIST_URL = "http://www.wunderground.com/weatherstation/ListStations.asp?selectedState=#{ENV['FOCUS_CITY_STATE']}&selectedCountry=United+States"

      WUPWS_SITE_FIELDS = [
      	{:id => "id", :type => "text"}, 
        {:id => "neighborhood", :type => "text"}, 
        {:id => "station_type", :type => "text"},
        {:id => "country_iso3166", :type => "text"},
        {:id => "city", :type => "text"},
        {:id => "tz_short", :type => "text"},
        {:id => "lat", :type => "float"},
        {:id => "lon", :type => "float"},
        {:id => "zip", :type => "text"},
        {:id => "magic", :type => "text"},
        {:id => "wuiurl", :type => "text"},
        {:id => "last_scraped_at", :type => "timestamp"},
      ]

      desc "Create CKAN resource for sites (if it doesn't exist) and then upsert CKAN with site data"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_WUPWS_SITE_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {:resource => {
                :package_id => ENV['CKAN_WUPWS_DATASET_ID'],
                :name => ENV['CKAN_WUPWS_SITE_RESOURCE_NAME']
              },
              :primary_key => 'id',
              # :indexes => WUPWS_SITE_FIELDS.map{|x| x[:id]}.join(","),
              :fields => WUPWS_SITE_FIELDS,
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          # puts "Created a new resource named '#{ENV['CKAN_WUPWS_SITE_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
          # puts "Resource named '#{ENV['CKAN_WUPWS_SITE_RESOURCE_NAME']}' already existed"
        end
        # puts "Resource ID = #{resource_id}"
        # invoke upsert rake task
        Rake.application.invoke_task("ckan:wupws:sites:upsert[#{resource_id}]")
      end


      desc "Fetch and upsert data on sites"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?

        wupws_sites = []

        # puts "Getting list of all PWS sites in #{ENV['FOCUS_CITY_STATE']}"
        wupws_site_list_html = RestClient.get(WUPWS_SITE_LIST_URL)
        wupws_site_list_doc = Nokogiri::HTML(wupws_site_list_html)
        wupws_site_list = wupws_site_list_doc.xpath("//table[@id='pwsTable']/tbody/tr[td]")
        wupws_site_list.each do |site|
          site_data_array_from_html = site.children.map(&:text)
          site_data = {
            :id => site_data_array_from_html[0],
            :neighborhood => site_data_array_from_html[2],
            :city => site_data_array_from_html[4],
            :station_type => site_data_array_from_html[6] 
          }
          
          if site_data[:city].match(/#{ENV['FOCUS_CITY']}/)
            # puts "  Processing PWS ID #{site_data[:id]}"
            wupws_site_details_raw = RestClient.get("http://api.wunderground.com/api/#{ENV['WEATHER_UNDERGROUND_API_KEY']}/geolookup/q/pws:#{site_data[:id]}.json")
            wupws_site_details = JSON.parse(wupws_site_details_raw)

            if wupws_site_details["location"]
              # puts wupws_site_details["location"]
              site_data[:country_iso3166] = wupws_site_details["location"]["country_iso3166"]
              site_data[:city] = wupws_site_details["location"]["city"]
              site_data[:tz_short] = wupws_site_details["location"]["tz_short"]
              site_data[:lat] = wupws_site_details["location"]["lat"]
              site_data[:lon] = wupws_site_details["location"]["lon"]
              site_data[:zip] = wupws_site_details["location"]["zip"]
              site_data[:magic] = wupws_site_details["location"]["magic"]
              site_data[:wuiurl] = wupws_site_details["location"]["wuiurl"]
              site_data[:last_scraped_at] = Time.now.utc.iso8601
              wupws_sites << site_data
            end
            sleep 15
          else
            # do not save - we are only interested in focus city PWSs
          end

        end

        post_data = {:resource_id => args[:resource_id], :records => wupws_sites, :method => 'upsert'}.to_json
        upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        upsert_result = JSON.parse(upsert_raw)
        # puts "\nSites upserts complete"
      end
    end

	end

end
