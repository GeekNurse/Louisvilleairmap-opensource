module AppHelpers

  def get_ckan_resource_by_name(name)
    search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/resource_search?query=name:#{URI.encode(name)}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
    search_results = JSON.parse(search_raw)
    if search_results["result"]["results"] != []
      return search_results["result"]["results"].first
    else
      return {}
    end
  end

  def get_ckan_package_by_slug(slug)
    begin
      search_raw = RestClient.get("#{ENV['CKAN_HOST']}/api/3/action/package_show?id=#{URI.encode(slug)}",{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
      search_results = JSON.parse(search_raw)
      if search_results["success"] == true
        search_results["result"]["extras_hash"] = {}
        search_results["result"]["extras"].each {|hash| search_results["result"]["extras_hash"][hash["key"]] = hash["value"] }
        return search_results["result"]
      else
        return {}
      end
    rescue
      puts "RESCUE!"
      return {}
    end
  end

  def raw_resource_from_ckan(full_url)
    raw = RestClient.get(full_url,{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
    return raw
  end


  def sql_search_ckan(sql_query)
    results = []
    uri = "#{ENV['CKAN_HOST']}/api/3/action/datastore_search_sql?sql=#{URI.escape(sql_query)}"
    # puts uri
    raw = RestClient.get(uri,{"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
    response = JSON.parse(raw)
    if response["success"]
      response["result"]["records"].each do |row|
        results << transform_row(row)
      end
    end
    return results
  end

  def transform_row(row)
    row["computed_aqi"] = determine_aqi(row["parameter"],row["value"],row["unit"]) if !row["computed_aqi"] && (row["parameter"] && row["value"] && row["unit"])
    row["aqi_cat"] = aqi_to_category(row["computed_aqi"]) if row["computed_aqi"]
    row["unit"] = "%" if row["unit"] == "PERCENT"
    if (row["parameter"] == "TEMP" && row["unit"] == "C") or (row["parameter"] == "Temperature" && row["unit"] == "deg C")
      row["unit"] = "°F"
      row["value"] = celsius_to_fahrenheit(row["value"])
    end

    case row["parameter"].to_s.upcase
      when "TEMP"
        row["name"] = "Ambient temperature"
        row["more_info_url"] = "http://www.weather.gov/"
      when "WD"
        row["name"] = "Wind direction"
        row["more_info_url"] = "http://www.weather.gov/"
      when "WS"
        row["name"] = "Wind speed"
        row["more_info_url"] = "http://www.weather.gov/"
      when "TEMPERATURE"
        row["name"] = "Learn more"
        row["more_info_url"] = "http://www.weather.gov/"
      when "CO"
        row["name"] = "Carbon monoxide"
        row["more_info_url"] = "http://www.epa.gov/airquality/carbonmonoxide/"
      when "CO-8HR"
        row["name"] = "Carbon monoxide peak 8-hr average (midnight to midnight)"
        row["more_info_url"] = "http://www.epa.gov/airquality/carbonmonoxide/"
      when "NO2"
        row["name"] = "Nitrogen dioxide"
        row["more_info_url"] = "http://www.epa.gov/air/nitrogenoxides/"
      when "RHUM"
        row["name"] = "Relative humidity"
        row["more_info_url"] = "http://www.crh.noaa.gov/lmk/soo/docu/humidity.php"
      when "HUMIDITY"
        row["name"] = "Learn more"
        row["more_info_url"] = "http://www.crh.noaa.gov/lmk/soo/docu/humidity.php"
      when "DUST"
        row["name"] = "Learn more"
        row["more_info_url"] = "http://www.epa.gov/asthma/dustmites.html"
      when "NO2T"
        row["name"] = "Nitrogen dioxide, true measure"
        row["more_info_url"] = "http://www.epa.gov/airtrends/aqtrnd95/no2.html"
      when "OZONE-8HR"
        row["name"] = "Peak ozone 8-hr average (midnight to midnight)"
        row["more_info_url"] = "http://www.epa.gov/ozone/"
      when "OZONE-1HR"
        row["name"] = "Peak ozone 1-hr average (midnight to midnight)"
        row["more_info_url"] = "http://www.epa.gov/ozone/"
      when "OZONE"
        row["name"] = "Ozone"
        row["more_info_url"] = "http://www.epa.gov/ozone/"
      when "SO2"
        row["name"] = "Sulfur dioxide, conventional"
        row["more_info_url"] = "http://www.epa.gov/airquality/sulfurdioxide/"
      when "SO2T"
        row["name"] = "Sulfur dioxide, trace levels"
        row["more_info_url"] = "http://www.epa.gov/airquality/sulfurdioxide/"
      when "SO2-24HR"
        row["name"] = "Sulfur dioxide, 24-hr average (midnight to midnight)"
        row["more_info_url"] = "http://www.epa.gov/airquality/sulfurdioxide/"
      when "PM2.5"
        row["name"] = "Particulate matter < 2.5 micrometers"
        row["more_info_url"] = "http://www.health.ny.gov/environmental/indoors/air/pmq_a.htm"
      when "PM2.5-24HR"
        row["name"] = "Particulate matter < 2.5 micrometers 24-hr average (midnight to midnight)"
        row["more_info_url"] = "http://www.health.ny.gov/environmental/indoors/air/pmq_a.htm"
      when "PM10"
        row["name"] = "Particulate matter < 10 micrometers"
        row["more_info_url"] = "http://www.epa.gov/airtrends/aqtrnd95/pm10.html"
      when "PM10-24HR"
        row["name"] = "Particulate matter < 2.5 micrometers 24-hr average (midnight to midnight)"
        row["more_info_url"] = "http://www.epa.gov/airtrends/aqtrnd95/pm10.html"
    end

    # row["value"] = nil if row["value"].to_i < -1
    row["avg_value"] = nil if row["avg_value"].to_i < -1
    row["avg_aqi"] = nil if row["avg_aqi"].to_i < -1


    return row
  end

  def fetch_all_feeds(additional_http_params = "")
    page = 1
    all_feeds = []
    base_url = "#{$api_url}/v2/feeds.json?user=airqualityegg&mapped=true&content=summary&per_page=100#{additional_http_params}"
	puts base_url
    page_response = fetch_xively_url("#{base_url}&page=#{page}")
	puts page_response
    while page_response.code == 200 && page_response["results"].size > 0
      page_results = Xively::SearchResult.new(page_response.body).results
      all_feeds = all_feeds + page_results
      page += 1
      page_response = fetch_xively_url("#{base_url}&page=#{page}")
    end
    all_feeds = collect_map_markers(all_feeds)
  end

  def fetch_xively_url(url)
    Xively::Client.get(url, :headers => {'Content-Type' => 'application/json', 'X-ApiKey' => $api_key})
  end

  def collect_map_markers(feeds)
    MultiJson.dump(
      feeds = feeds.collect do |feed|
        attributes = feed.attributes
        attributes["datastreams"] = attributes["datastreams"].select do |d|
          tags = d.tags
          tags.match(/computed/) && (tags.match(/sensor_type=NO2\z/) || tags.match(/sensor_type=CO\z/) || tags.match(/sensor_type=Dust\z/) || tags.match(/sensor_type=Temperature\z/) || tags.match(/sensor_type=Humidity\z/) || tags.match(/sensor_type=VOC\z/) || tags.match(/sensor_type=O3\z/) )
        end
        attributes.delete_if {|_,v| v.blank?}
        attributes
      end
    )
  end

  def string_to_time(timestamp)
    Time.parse(timestamp).strftime("%d %b %Y %H:%M:%S")
    rescue
    ''
  end

  def celsius_to_fahrenheit(value)
    value.to_f * 9 / 5 + 32
  end

  def calculate_component_aqi(aqi_high,aqi_low,concentration_high, concentration_low, concentration)
    component_aqi = ((concentration-concentration_low)/(concentration_high-concentration_low))*(aqi_high-aqi_low)+aqi_low;
    return component_aqi.to_i
  end

  def calculate_aqi_from_CO(concentration)
    concentration = concentration.to_f
    if concentration >= 0 && concentration < 4.5
      aqi = calculate_component_aqi(50,0,4.4,0,concentration)
    elsif concentration >=4.5 && concentration<9.5
      aqi = calculate_component_aqi(100,51,9.4,4.5,concentration);
    elsif concentration>=9.5 && concentration<12.5
      aqi = calculate_component_aqi(150,101,12.4,9.5,concentration);
    elsif concentration>=12.5 && concentration<15.5
      aqi = calculate_component_aqi(200,151,15.4,12.5,concentration);
    elsif concentration>=15.5 && concentration<30.5
      aqi = calculate_component_aqi(300,201,30.4,15.5,concentration);
    elsif concentration>=30.5 && concentration<40.5
      aqi = calculate_component_aqi(400,301,40.4,30.5,concentration);
    elsif concentration>=40.5 && concentration<50.5
      aqi = calculate_component_aqi(500,401,50.4,40.5,concentration);
    else
      aqi = nil
    end
    return aqi
  end

  def calculate_aqi_from_PM25_24hr(concentration)
    concentration = concentration.to_f
    if concentration >= 0 && concentration < 12.1
      aqi = calculate_component_aqi(50,0,12,0,concentration)
    elsif concentration >=12.1 && concentration<35.5
      aqi = calculate_component_aqi(100,51,35.4,12.1,concentration);
    elsif concentration>=35.5 && concentration<55.5
      aqi = calculate_component_aqi(150,101,55.4,35.5,concentration);
    elsif concentration>=55.5 && concentration<150.5
      aqi = calculate_component_aqi(200,151,150.4,55.5,concentration);
    elsif concentration>=150.5 && concentration<250.5
      aqi = calculate_component_aqi(300,201,250.4,150.5,concentration);
    elsif concentration>=250.5 && concentration<350.5
      aqi = calculate_component_aqi(400,301,350.4,250.5,concentration);
    elsif concentration>=350.5 && concentration<500.5
      aqi = calculate_component_aqi(500,401,500.4,350.5,concentration);
    else
      aqi = nil
    end
    return aqi
  end

  def calculate_aqi_from_PM10_24hr(concentration)
    concentration = concentration.to_f
    if concentration >= 0 && concentration < 55
      aqi = calculate_component_aqi(50,0,54,0,concentration)
    elsif concentration >=55 && concentration<155
      aqi = calculate_component_aqi(100,51,154,55,concentration);
    elsif concentration>=155 && concentration<255
      aqi = calculate_component_aqi(150,101,254,155,concentration);
    elsif concentration>=255 && concentration<355
      aqi = calculate_component_aqi(200,151,354,255,concentration);
    elsif concentration>=355 && concentration<425
      aqi = calculate_component_aqi(300,201,424,355,concentration);
    elsif concentration>=425 && concentration<505
      aqi = calculate_component_aqi(400,301,504,425,concentration);
    elsif concentration>=505 && concentration<605
      aqi = calculate_component_aqi(500,401,604,505,concentration);
    else
      aqi = nil
    end
    return aqi
  end

  def calculate_aqi_from_SO2_1hr(concentration)
    concentration = concentration.to_i
    if concentration >= 0 && concentration < 36
      aqi = calculate_component_aqi(50,0,35,0,concentration)
    elsif concentration >=36 && concentration<76
      aqi = calculate_component_aqi(100,51,75,36,concentration);
    elsif concentration>=76 && concentration<186
      aqi = calculate_component_aqi(150,101,185,76,concentration);
    elsif concentration>=186 && concentration<304
      aqi = calculate_component_aqi(200,151,304,186,concentration);
    else
      aqi = nil # AQI values of 201 or greater are calculated with 24-hour SO2 concentrations
    end
    return aqi
  end

  def calculate_aqi_from_SO2_24hr(concentration)
    concentration = concentration.to_i
    if concentration >= 0 && concentration < 304
      aqi = nil # AQI values less than 201 are calculated with 1-hour SO2 concentrations
    elsif concentration>=304 && concentration<605
      aqi = calculate_component_aqi(300,201,604,305,concentration);
    elsif concentration>=605 && concentration<805
      aqi = calculate_component_aqi(400,301,804,605,concentration);
    elsif concentration>=805 && concentration<1004
      aqi = calculate_component_aqi(500,401,1004,805,concentration);
    else
      aqi = nil
    end
    return aqi
  end


  def calculate_aqi_from_O3_8hr(concentration)
    concentration = concentration.to_f
    if concentration >= 0 && concentration < 0.060
      aqi = calculate_component_aqi(50,0,0.059,0,concentration)
    elsif concentration >=0.060 && concentration<0.076
      aqi = calculate_component_aqi(100,51,0.075,0.060,concentration);
    elsif concentration>=0.076 && concentration<0.096
      aqi = calculate_component_aqi(150,101,0.095,0.076,concentration);
    elsif concentration>=0.096 && concentration<0.116
      aqi = calculate_component_aqi(200,151,0.115,0.096,concentration);
    elsif concentration>=0.116 && concentration<0.375
      aqi = calculate_component_aqi(300,201,0.374,0.116,concentration);
    elsif concentration>=0.375 && concentration<0.605
      aqi = nil # 8-hour ozone values do not define higher AQI values (>=301).  AQI values of 301 or greater are calculated with 1-hour ozone concentrations.
    else
      aqi = nil
    end
    return aqi
  end

  def calculate_aqi_from_O3_1hr(concentration)
    concentration = concentration.to_f
    if concentration >= 0.125 && concentration < 0.165
      aqi = calculate_component_aqi(150,101,0.164,0.125,concentration);
    elsif concentration>=0.165 && concentration<0.205
      aqi = calculate_component_aqi(200,151,0.204,0.165,concentration);
    elsif concentration>=0.205 && concentration<0.405
      aqi = calculate_component_aqi(300,201,0.404,0.205,concentration);
    elsif concentration>=0.405 && concentration<0.505
      aqi = calculate_component_aqi(400,301,0.504,0.405,concentration);
    elsif concentration>=0.505 && concentration<0.605
      aqi = calculate_component_aqi(500,401,0.604,0.505,concentration);
    else
      aqi = nil
    end
    return aqi
  end

    def calculate_aqi_from_NO2(concentration)
    concentration = concentration.to_f
    if concentration >= 0 && concentration < 0.054
      aqi = calculate_component_aqi(50,0,0.053,0,concentration)
    elsif concentration >=0.054 && concentration<0.101
      aqi = calculate_component_aqi(100,51,0.100,0.054,concentration);
    elsif concentration>=0.101 && concentration<0.361
      aqi = calculate_component_aqi(150,101,0.360,0.101,concentration);
    elsif concentration>=0.361 && concentration<0.650
      aqi = calculate_component_aqi(200,151,0.649,0.361,concentration);
    elsif concentration>=0.650 && concentration<1.250
      aqi = calculate_component_aqi(300,201,1.249,0.650,concentration);
    elsif concentration>=1.250 && concentration<1.650
      aqi = calculate_component_aqi(400,301,1.649,1.250,concentration);
    elsif concentration>=1.650 && concentration<2.049
      aqi = calculate_component_aqi(500,401,2.049,1.650,concentration);
    else
      aqi = nil
    end
    return aqi
  end


  def determine_aqi(parameter,value,unit)
    case parameter.upcase
    when "OZONE-8HR"
      value = value/1000.00 if unit.upcase == "PPB"
      return calculate_aqi_from_O3_8hr(value)
    when "OZONE-1HR"
      value = value/1000.00 if unit.upcase == "PPB"
      return calculate_aqi_from_O3_1hr(value)
    when "OZONE"
      value = value/1000.00 if unit.upcase == "PPB"
      return calculate_aqi_from_O3_8hr(value)
    when "PM10-24HR"
      return calculate_aqi_from_PM10_24hr(value)
    when "PM2.5-24HR"
      return calculate_aqi_from_PM25_24hr(value)
    when "PM2.5" # CAREFUL
      return calculate_aqi_from_PM25_24hr(value)
    when "CO"
      value = value/1000.00 if unit.upcase == "PPB"
      return calculate_aqi_from_CO(value)
    when "NO2"
      value = value/1000.00 if unit.upcase == "PPB"
      value = value.round(3)
      return calculate_aqi_from_NO2(value)
    when "DUST"
      vaule = value.round
      if value.between?(1,1500)
        aqi_range = [0,50]
      elsif value.between?(1501,1529)
        aqi_range = [50.5,50.5]
      elsif value.between?(1530,3000)
        aqi_range = [51,100]
      elsif value.between?(3001,3059)
        aqi_range = [100.5,100.5]
      elsif value.between?(3060,5837)
        aqi_range = [101,150]
      elsif value.between?(5838,5892)
        aqi_range = [150.5,150.5]
      elsif value.between?(5893,8670)
        aqi_range = [151,200]
      elsif value.between?(8671,8726)
        aqi_range = [200.5,200.5]
      elsif value.between?(8727,14336)
        aqi_range = [201,300]
      elsif value.between?(14337,14364)
        aqi_range = [300.5,300.5]
      elsif value >= 14365
        aqi_range = [301,500]
      else
        aqi_range = [0,0]
      end   
      return aqi_range.sum/2.00   
    else
      return nil
    end 
  end

  def aqi_to_category(aqi)
    aqi = aqi.to_i
    if aqi <= 0
      return {:name => "Out of range", :color => "#FFF", :font => "#000"}
    elsif aqi <= 50
      return {:name => "Good", :color => "#00E000", :font => "#000"}
    elsif aqi > 50 && aqi <= 100
      return {:name => "Moderate", :color => "#FFFF00", :font => "#000"}
    elsif aqi > 100 && aqi <= 150
      return {:name => "Unhealthy for Sensitive Groups", :color => "#FF7E00", :font => "#000"}
    elsif aqi > 150 && aqi <= 200
      return {:name => "Unhealthy", :color => "#FF0000", :font => "#000"}
    elsif aqi > 200 && aqi <= 300
      return {:name => "Very Unhealthy", :color => "#99004C", :font => "#FFF"}
    elsif aqi > 300 
      return {:name => "Hazardous", :color => "#4C0026", :font => "#FFF"}
    end
  end

  def category_number_to_category(category_number)
    category_number = category_number.to_s
    if category_number == "7"
      return {:name => "Unavailable", :color => "#FFF", :font => "#000"}
    elsif category_number == "1"
      return {:name => "Good", :color => "#00E000", :font => "#000"}
    elsif category_number == "2"
      return {:name => "Moderate", :color => "#FFFF00", :font => "#000"}
    elsif category_number == "3"
      return {:name => "Unhealthy for Sensitive Groups", :color => "#FF7E00", :font => "#000"}
    elsif category_number == "4"
      return {:name => "Unhealthy", :color => "#FF0000", :font => "#000"}
    elsif category_number == "5"
      return {:name => "Very Unhealthy", :color => "#99004C", :font => "#FFF"}
    elsif category_number == "6"
      return {:name => "Hazardous", :color => "#4C0026", :font => "#FFF"}
    end
  end

  def fetch_whole_socrata_dataset(endpoint, per_page = 1000, where_clause = nil, token = ENV['SOCRATA_APP_TOKEN'])
    all_results = []
    page = 0
    request_url = "#{endpoint}&$limit=#{per_page}&$offset=#{per_page*page}"
    request_url += "&$where=#{URI.encode(where_clause)}" if where_clause
    puts "Fetching all results from #{request_url}"
    page_results = JSON.parse(RestClient.get(request_url), {"X-App-Token" => token})
    until page_results.empty?
      all_results = all_results + page_results
      puts "Added #{page_results.size} results from page #{page+1} for a total of #{all_results.size}"
      page = page + 1
      request_url = "#{endpoint}&$limit=#{per_page}&$offset=#{per_page*(page)}"
      page_results = JSON.parse(RestClient.get(request_url), {"X-App-Token" => token})
    end
    puts "Collected a total of #{all_results.size} records"
    return all_results
  end

  def set_ckan_metadata!
    ENV["CKAN_DATASET_KEYS"].split(",").each do |key|
      META[key] = get_ckan_package_by_slug(ENV["CKAN_#{key.upcase}_DATASET_ID"])
      if ENV["CKAN_#{key.upcase}_SITE_RESOURCE_NAME"]
        META[key]["site_resource"] = get_ckan_resource_by_name(ENV["CKAN_#{key.upcase}_SITE_RESOURCE_NAME"])
        META[key]["site_resource_id"] = META[key]["site_resource"]["id"]
      end
      if ENV["CKAN_#{key.upcase}_DATA_RESOURCE_NAME"]
        META[key]["data_resource"] = get_ckan_resource_by_name(ENV["CKAN_#{key.upcase}_DATA_RESOURCE_NAME"])
        META[key]["data_resource_id"] = META[key]["data_resource"]["id"]
      end
    end

    ENV["CKAN_DATASET_KEYS_SITES_JOINABLE"].split(",").each do |dataset_key|
      fields = {}
      puts dataset_key
      META[dataset_key]["extras_hash"].select{|k,v| k.match("field_containing_site_")}.sort.each do |k,v|
        field_as = k.gsub("field_containing_site_","")
        field_key = v
        fields[field_as] = field_key
      end
      # puts fields.inspect
      sql = "SELECT '#{dataset_key}' AS site_type, "
      sql += fields.map { |as,key|
        if ["latitude","longitude"].include?(as)
          cast_as = "float"
        else 
          cast_as = "VARCHAR(255)"
        end
        "#{key}::#{cast_as} AS #{as}"
      }.join(", ")
      sql += " FROM \"#{META[dataset_key]["site_resource_id"]}\" #{dataset_key}"
      META[dataset_key]["site_join_sql"] = sql
    end
  end

  # def format_forcast_meter_html(forecasts_array)
  #   html = ""
  #   if forecasts_array.empty?
  #     html += "<p></p>"
  #   else
  #     forecasts_array.each do |forecast|
  #       html += "<img src='#{forecast["aq_img"]}' alt=''></img>"
  #     end
  #   end
  #   return html
  # end

  def format_forecasts_html(forecasts_array)
    html = ""
    if forecasts_array.empty?
      html += "<p>Sorry, no forecasts were available.</p>"
    else
      html += "<ul>"
      forecasts_array.each do |forecast|
        # html += "<li><strong style='padding: 3px; line-height: 30px; color:#{forecast["aqi_cat"][:font]};background-color:#{forecast["aqi_cat"][:color]};'>#{forecast["Category"]["Name"]} air quality from #{forecast["ParameterName"]}</strong>"
        html += "<li>#{forecast["Category"]["Name"]} air quality from #{forecast["ParameterName"]}"
        html += " (AQI of #{forecast["AQI"]})" if forecast["AQI"] > 0
        html += "</li>"
      end
      html += "</ul>"
    end
    return html
  end

  def format_forecasts_text(forecasts_array)
    text = ""
    if forecasts_array.empty?
      text += "   Sorry, no forecasts were available.\n"
    else
      forecasts_array.each do |forecast|
        text += "   - #{forecast["Category"]["Name"]} air quality from #{forecast["ParameterName"]}"
        text += " (AQI of #{forecast["AQI"]})" if forecast["AQI"] > 0
        text += "\n"
      end
    end
    return text
  end

  def format_observations_html(observations_array)
    html = "<ul>"
    observations_array.each do |observation|
      html += "<li><strong style='padding: 3px; line-height: 30px; color:#{observation["aqi_cat"][:font]};background-color:#{observation["aqi_cat"][:color]};'>#{observation["Category"]["Name"]} air quality from #{observation["ParameterName"]}</strong>"
      html += " (AQI of #{observation["AQI"]})" if observation["AQI"] > 0
      html += "</li>"
    end
    html += "</ul>"
    return html
  end

  def format_observations_text(observations_array)
    text = ""
    observations_array.each do |observation|
      text += "  - #{observation["Category"]["Name"]} air quality from #{observation["ParameterName"]}"
      text += " (AQI of #{observation["AQI"]})" if observation["AQI"] > 0
      text += "\n"
    end
    return text
  end

  def format_action_day_html(action_day_boolean)
    return action_day_boolean == true ? "<p><strong style='color: red;'>Today is an air quality action day.</strong> Read more about <a href='http://www.airnow.gov/index.cfm?action=airnow.actiondays'>what an action day is from the EPA.</a></p>" : ""
  end

  def format_action_day_text(action_day_boolean)
    return action_day_boolean == true ? "** Today is an air quality action day. ** The EPA has more information about what an action day is at http://www.airnow.gov/index.cfm?action=airnow.actiondays\n" : ""
  end

  def upload_data_to_ckan_resource(resource_id, data, method = "upsert")
    post_data = {
      :resource_id => resource_id,
      :records => data,
      :method => method.to_s
    }.to_json
    raw = RestClient.post("#{ENV['CKAN_HOST']}/api/3/action/datastore_upsert", post_data, {"X-CKAN-API-KEY" => ENV['CKAN_API_KEY']})
    result = JSON.parse(raw)
    return result
  end

  def random_fact_from_wordpress
    raw = JSON.parse(RestClient.get(ENV['WORDPRESS_BASE']+'/wp-json/pages/'+ENV['WORDPRESS_FACTS_PAGE_SLUG']))
    doc = Nokogiri::HTML(raw["content"])
    slides = doc.css("div.cycloneslider-slide-custom")
    slides_text = slides.map {|slide| slide.text.strip}
    slides_text.shuffle.first.force_encoding("ISO-8859-1")
  end

  require 'rss'

  def format_blog_text(content)
    new_content = content.gsub('<li>', '    - ')
    new_content = new_content.gsub('</p>', "\n")
    new_content = new_content.gsub(/<\/?[^>]*>/,"")
    new_content = new_content.scan(/.{1,80}(?:\s+|$)/)
    new_content = new_content.join("\n  ")

    return new_content
  end

  def is_recent_post(pub_date)
    now = Time.now()
    now = Date.new(now.year, now.month, now.day)
    pub_date = Date.new(pub_date.year, pub_date.month, pub_date.day)
    max_days_old = 7

    time_diff = (now - pub_date).floor

    if time_diff < max_days_old
      return "Check out our <a href='#latestBlogPost'>latest blog post!</a>"
    end
  end

  def get_latest_blogpost()
    rss = RSS::Parser.parse('http://instituteforhealthyairwaterandsoil.org/feed/', false)
    title = rss.items[0].title.gsub("’","'")
    pub_date = rss.items[0].pubDate
    formatted_date = pub_date.strftime("%m/%d/%Y")
    link = rss.items[0].link
    # content = rss.items[0].content_encoded
    content = rss.items[0].description.gsub("’","'")
    content_text = format_blog_text(content)

    recent = is_recent_post(pub_date)
    content_text = content_text
    return title, formatted_date, link, content, content_text, recent
  end

end
