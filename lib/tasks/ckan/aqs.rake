namespace :ckan do 

  namespace :airnow do

    task :update do 
      Rake.application.invoke_task("ckan:airnow:data:check_resource_exists_and_upsert")
      Rake.application.invoke_task("ckan:airnow:sites:check_resource_exists_and_upsert")
    end

    namespace :sites do

      desc "Create CKAN resource for AQS monitoring sites (if it doesn't exist) and then upsert CKAN"
      task :check_resource_exists_and_upsert do |t|
        raise "CKAN credentials not set (see README)" unless ENV['CKAN_HOST'] && ENV['CKAN_API_KEY']
        # search for CKAN data set
        search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_AQS_SITE_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        search_results = JSON.parse(search_raw)
        # resource we want to use is the first match
        resource = search_results["result"]["results"].first
        # if there is no resource, create it
        if resource.nil?
          puts "#{ENV['CKAN_HOST']}/api/3/action/datastore_create"
          puts ENV['CKAN_API_KEY']
          puts ENV['CKAN_AQS_DATASET_ID']
          create_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_create",
            {
              :resource => {
                :package_id => ENV['CKAN_AQS_DATASET_ID']
              },
              :primary_key => 'aqs_id',
              :indexes => 'aqs_id,site_name,status,cmsa_name,msa_name,state_name,county_name',
              :fields => [
                {:id => "aqs_id", :type => "text"},
                {:id => "site_code", :type => "text"},
                {:id => "site_name", :type => "text"},
                {:id => "status", :type => "text"},
                {:id => "agency_id", :type => "text"},
                {:id => "agency_name", :type => "text"},
                {:id => "epa_region", :type => "text"},
                {:id => "lat", :type => "float"},
                {:id => "lon", :type => "float"},
                {:id => "elevation", :type => "text"},
                {:id => "gmt_offset", :type => "text"},
                {:id => "country_code", :type => "text"},
                {:id => "cmsa_code", :type => "text"},
                {:id => "cmsa_name", :type => "text"},
                {:id => "msa_code", :type => "text"},
                {:id => "msa_name", :type => "text"},
                {:id => "state_code", :type => "text"},
                {:id => "state_name", :type => "text"},
                {:id => "county_code", :type => "text"},
                {:id => "county_name", :type => "text"},
                {:id => "city_code", :type => "text"},
              ],
              :records => []
            }.to_json,
            {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
          create_results = JSON.parse(create_raw)
          resource_id = create_results["result"]["resource_id"]
          puts "Created a new resource named '#{ENV['CKAN_AQS_SITE_RESOURCE_NAME']}'"
        else
          resource_id = resource["id"]
        end
        puts "Resource ID = #{resource_id}"


        # invoke upsert rake task
        Rake.application.invoke_task("ckan:airnow:sites:upsert[#{resource_id}]")
      end


      desc "Open file that has monitoring site listings from FTP and import into CKAN"
      task :upsert, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "AirNow credentials not set (see README)" unless ENV['AIRNOW_USER'] && ENV['AIRNOW_PASS']

        sites = []

	manylabs_sites = ['552','554','555','556','557','558','562','567','568','569','570','571','572','573','574','576','577','548','582','584','585','586','558','563','553','564','583','565','566','569','563']
	manylabs_street = { '553'=> '2nd St & Market St', '564'=> '4th St & Chestnut St', '565'=> '4th St & Main St' }
  manylabs_activestatus = { '552'=> 'Inactive', '554'=> 'Inactive', '555'=> 'Inactive', '556'=> 'Inactive', '557'=> 'Inactive', '558'=> 'Active', '562'=> 'Inactive', '567'=> 'Inactive', '568'=> 'Inactive', '569'=> 'Active', '570'=> 'Inactive', '571'=> 'Inactive', '572'=> 'Inactive', '573'=> 'Inactive', '574'=> 'Inactive', '576'=> 'Inactive', '577'=> 'Inactive', '548'=> 'Inactive', '582'=> 'Inactive', '584'=> 'Inactive', '585'=> 'Inactive', '583'=> 'Active', '553'=> 'Inactive', '564'=> 'Inactive', '565'=> 'Inactive', '566'=> 'Inactive', '586'=> 'Inactive', '563'=> 'Inactive' }

	index = 0
	
	manylabs_sites.each do |site|
		index += 1

    puts "........"
    puts "this is the site .... #{site}"

		getSite = 
			JSON.parse(
				RestClient.get( 'https://www.manylabs.org/data/api/v0/datasets/' + site + '/' )
			)

		next if getSite['defaultLatitude'].nil?

		status_indicator = "Active"
    if manylabs_activestatus.has_key?( site )
      status_indicator = manylabs_activestatus[ site ]
    end

    site_name = "Louisville " + index.to_s
		if manylabs_street.has_key?( site )
			site_name = manylabs_street[ site ]
		end

		site_data = {
			:aqs_id => (getSite['id'] + 10000).to_s,
			:site_code => getSite['id'].to_s,
			:site_name => site_name,
      :status => status_indicator,
			#:agency_id => "TEST",
			:agency_name => 'ManyLabs',
			#:epa_region => "TEST",
			:lat => getSite['defaultLatitude'],
			:lon => getSite['defaultLongitude'],
			:elevation => "0.0",
			:gmt_offset => "-5.0",
			:country_code => "US",
			#:cmsa_code => "TEST",
			#:cmsa_name => "TEST",
			:msa_code => "31140",
			:msa_name => "Louisville, KY",
			:state_code => "21",
			:state_name => "KY",
			:county_code => "21111",
			:county_name => "JEFFERSON",
			#:city_code => "TEST",
		}

		puts site_data
		sites << site_data

		puts getSite['defaultLatitude']
	end

        #search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(ENV['CKAN_BIKE_DATA_RESOURCE_NAME'])}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
        #search_results = JSON.parse(search_raw)
	

        # connect to FTP and load the data into a variable
        ftp = Net::FTP.new('ftp.airnowapi.org')
        ftp.login(ENV['AIRNOW_USER'], ENV['AIRNOW_PASS'])
        ftp.passive = true
        puts "Opening file from FTP..."
        data = ftp.getbinaryfile('Locations/monitoring_site_locations.dat', nil, 1024)
        ftp.close

        puts "Parsing sites file and upserting rows..."
        CSV.parse(data, :col_sep => "|", :encoding => 'UTF-8') do |row|
	  if row[8].to_f > 35.819484 and row[8].to_f < 41.419560 and row[9].to_f > -89.027710 and row[9].to_f < -80.623169
		  site_data = {
		    :aqs_id => row[0],
		    :site_code => row[2],
		    :site_name => fix_encoding(row[3]),
		    :status => row[4],
		    :agency_id => row[5],
		    :agency_name => fix_encoding(row[6]),
		    :epa_region => row[7],
		    :lat => row[8],
		    :lon => row[9],
		    :elevation => row[10],
		    :gmt_offset => row[11],
		    :country_code => row[12],
		    :cmsa_code => row[13],
		    :cmsa_name => row[14],
		    :msa_code => row[15],
		    :msa_name => row[16],
		    :state_code => row[17],
		    :state_name => row[18],
		    :county_code => row[19],
		    :county_name => row[20],
		    :city_code => row[21],
		  }
		  sites << site_data
		end
        end

        puts "\nAdding #{sites.length} sites into database"
        post_data = {:resource_id => args[:resource_id], :records => sites, :method => 'upsert'}.to_json
	begin
		upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
	rescue => e
		puts e.response
	end

        upsert_result = JSON.parse(upsert_raw)
        puts "\nAdded #{sites.length} sites into database"

        puts "\nAQS Monitoring Sites data upserts complete"
      end
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
        Rake.application.invoke_task("ckan:airnow:data:upsert_daily[#{resource_id}]")
        Rake.application.invoke_task("ckan:airnow:data:upsert_hourly[#{resource_id}]")
      end

      desc "Open file that has daily monitoring data from FTP and import into CKAN"
      task :upsert_daily, :resource_id do |t, args|
        puts "Openning file that has daily monitoring data from FTP and import into CKAN"
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "AirNow credentials not set (see README)" unless ENV['AIRNOW_USER'] && ENV['AIRNOW_PASS']



		q_for_site = 'SELECT%20aqs_id%20FROM%20%22b1b1e239-f5e2-4bc0-9572-6056fac5257b%22%20WHERE%20lat%20%3E%2018.41923%20AND%20lat%20%3C%2064.8458%20AND%20lon%20%3E%20-158.113907%20AND%20lon%20%3C%20-52.7947;'
		puts q_for_site
		head = {'content-type'=> 'application/json', 'Authorization'=>  ENV['CKAN_API_KEY']}
		search_for_site = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/datastore_search_sql?sql=#{q_for_site}", head)
		results = JSON.parse( search_for_site )
		results = results["result"]
		results = results["records"]

		okones = []
		results.each do |row|
			okones << row["aqs_id"]
		end
		puts okones
		puts okones.length

        # connect to FTP and load the data into a variable
        puts "connect to FTP and load the data into a variable"
        ftp = Net::FTP.new('ftp.airnowapi.org')
        ftp.login(ENV['AIRNOW_USER'], ENV['AIRNOW_PASS'])
        ftp.passive = true # for Heroku
        puts "Opening file from FTP..."
        begin
          data = ftp.getbinaryfile("DailyData/#{TODAY}-peak.dat", nil, 1024)
          ftp.close

          puts "Parsing daily file and upserting rows..."
          entries = []
          CSV.parse(data, :col_sep => "|", :encoding => 'UTF-8') do |row|
		if okones.include?( row[1] )
		    dp = {
		      :aqs_id => row[1],
		      :date => Time.strptime(row[0],'%m/%d/%y').strftime("%Y-%m-%d"),
		      :time => nil,
		      :parameter => row[3],
		      :unit => row[4],
		      :value => row[5].to_f,
		      :computed_aqi => determine_aqi(row[3], row[5].to_f, row[4]),
		      :data_source => fix_encoding(row[7]),
		    }
		    dp[:datetime] = dp[:date]
		    dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:datetime]}|#{dp[:parameter]}"
		    entries << dp
		end
          end
          post_data = {:resource_id => args[:resource_id], :records => entries, :method => 'upsert'}.to_json
    	  upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
    	  upsert_result = JSON.parse(upsert_raw)
        rescue
          puts "ERROR: rescued from AQS daily file"
        end

        puts "\nAQS Monitoring daily data upserts complete"
      end

      desc "Open file that has hourly monitoring data from FTP and import into CKAN"
      task :upsert_hourly, :resource_id do |t, args|
        raise "CKAN resource ID not set" if args[:resource_id].nil?
        raise "AirNow credentials not set (see README)" unless ENV['AIRNOW_USER'] && ENV['AIRNOW_PASS']

		q_for_site = 'SELECT%20aqs_id%20FROM%20%22b1b1e239-f5e2-4bc0-9572-6056fac5257b%22%20WHERE%20lat%20%3E%2018.41923%20AND%20lat%20%3C%2064.8458%20AND%20lon%20%3E%20-158.113907%20AND%20lon%20%3C%20-52.7947;SELECT%20aqs_id%20FROM%20%22b1b1e239-f5e2-4bc0-9572-6056fac5257b%22%20WHERE%20lat%20%3E%2018.41923%20AND%20lat%20%3C%2064.8458%20AND%20lon%20%3E%20-158.113907%20AND%20lon%20%3C%20-52.7947;'

		head = {'content-type'=> 'application/json', 'Authorization'=>  ENV['CKAN_API_KEY']}
		search_for_site = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/datastore_search_sql?sql=#{q_for_site}", head)
		results = JSON.parse( search_for_site )
		results = results["result"]
		results = results["records"]

		okones = []

		results.each do |row|
			okones << row["aqs_id"]
		end
		puts okones
		puts okones.length

        monitoring_data = []

        # connect to FTP and load the data into a variable
        ftp = Net::FTP.new('ftp.airnowapi.org')
        ftp.login(ENV['AIRNOW_USER'], ENV['AIRNOW_PASS'])
        ftp.passive = true # for Heroku
		
        # [TODAY,YESTERDAY].each  do |day|
        [TODAY].each  do |day|
          HOURS.each do |hour|
            file = "HourlyData/#{day}#{hour}.dat"
            begin
              puts "Getting #{file}"
              data = ftp.getbinaryfile(file, nil, 1024)
              puts "Processing #{file}"

              CSV.parse(data, :col_sep => "|", :encoding => 'ISO8859-1') do |row|
			if okones.include?( row[2] )

				if ["NO2T","NO2","NO2Y","CO","CO-8HR","RHUM","TEMP","PM2.5","WS","WD","PM2.5-24HR","SO2-24HR","SO2","PM10","PM10-24HR","OZONE-8HR","OZONE-1HR","OZONE"].include?(row[5].upcase)
				  dp = {
				    :aqs_id => row[2],
				    :date => Time.strptime(row[0],'%m/%d/%y').strftime("%Y-%m-%d"),
				    :time => "#{row[1]}:00",
				    :parameter => row[5].upcase,
				    :unit => row[6],
				    :value => row[7].to_f,
				    :data_source => fix_encoding(row[8]),
				  }
				  dp[:datetime] = dp[:date] + " " + dp[:time]
				  dp[:id] = "#{dp[:aqs_id]}|#{dp[:date]}|#{dp[:time]}|#{dp[:parameter]}"
				  monitoring_data << dp
				end
			else
				puts "SKIPPED #{row[2]}"
			end
              end
            rescue => e
				puts "ERROR: #{e.message}"
            	puts "ERROR: #{file} -- #{e} / #{e.message}" unless e.message.scan(/No such file or directory/)
            end
          end
        end

      ftp.close

  		puts "uploading data to CKAN ...."
  		post_data = {:resource_id => args[:resource_id], :records => monitoring_data, :method => 'upsert'}.to_json
  		# puts post_data
  		upsert_raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
  		# puts upsert_raw
  		upsert_result = JSON.parse(upsert_raw)
  		puts upsert_result

      scriptendtime = Time.now
  		puts "ending script at #{scriptendtime} ..."
      # puts "\nAQS Monitoring hourly data upserts complete"

      end

    end

  end

end
