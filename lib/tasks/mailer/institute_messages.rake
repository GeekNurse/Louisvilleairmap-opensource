namespace :mailer do 

  namespace :institute_messages do

    CONSTANT_CONTACT_API_KEY = ENV['CONSTANT_CONTACT_API_KEY']
    CONSTANT_CONTACT_SECRET = ENV['CONSTANT_CONTACT_SECRET']
    CONSTANT_CONTACT_TOKEN = ENV['CONSTANT_CONTACT_TOKEN']

    CKAN_INSTITUTE_MESSAGES_RESOURCE_ID = META["institute_messages"]["resources"].first["id"]
    PROD_CTCT_LIST_ID = ENV['CONSTANT_CONTACT_LIST_ID']
    DEMO_CTCT_LIST_ID = ENV['CONSTANT_CONTACT_DEMO_LIST_ID']
    CTCT_LIST_ID = PROD_CTCT_LIST_ID
    # CTCT_LIST_ID = DEMO_CTCT_LIST_ID

    EPA_HOW_YOU_CAN_HELP_HTML = <<-EOS
      <p><strong><a href='http://www.airnow.gov/index.cfm?action=resources.whatyoucando'>How You Can Help Keep the Air Cleaner (from the EPA)</a></strong>
       <br />Air pollution can affect your health and the environment.  There are actions every one of us can take to reduce air pollution and keep the air cleaner, and precautionary measures you can take to protect your health.</p>
      <ul>
        <li>Days when ozone is expected to be high:
          <ul>
            <li>Conserve electricity and set your air conditioner at a higher temperature.</li>
            <li>Choose a cleaner commute-share a ride to work or use public transportation. Bicycle or walk to errands when possible.</li>
            <li>Refuel cars and trucks after dusk.</li>
            <li>Combine errands and reduce trips.</li>
            <li>Limit engine idling.</li>
            <li>Use household, workshop,and garden chemicals in ways that keep evaporation to a minimum, or try to delay using them when poor air quality is forecast.</li>
          </ul>
        </li>
        <li>Days when particle pollution is expected to be high:
          <ul>
            <li>Reduce or eliminate fireplace and wood stove use.</li>
            <li>Avoid using gas-powered lawn and garden equipment.</li>
            <li>Avoid burning leaves, trash and other materials.</li>
          </ul>
        </li>
      </ul>
    EOS

    EPA_HOW_YOU_CAN_HELP_TEXT = <<-EOS
## How You Can Help Keep the Air Cleaner (from EPA at http://www.airnow.gov/index.cfm?action=resources.whatyoucando) ##

  Air pollution can affect your health and the environment. There are actions every one of us can take to reduce air pollution and keep the air cleaner, and precautionary measures you can take to protect your health.
  * Days when ozone is expected to be high:
    - Conserve electricity and set your air conditioner at a higher temperature.
    - Choose a cleaner commute-share a ride to work or use public transportation. Bicycle or walk to errands when possible.
    - Refuel cars and trucks after dusk.
    - Combine errands and reduce trips.
    - Limit engine idling.
    - Use household, workshop,and garden chemicals in ways that keep evaporation to a minimum, or try to delay using them when poor air quality is forecast.
  * Days when particle pollution is expected to be high:
    - Reduce or eliminate fireplace and wood stove use.
    - Avoid using gas-powered lawn and garden equipment.
    - Avoid burning leaves, trash and other materials.

EOS

    task :breaking do

      # Get latest observations and order them
      observations_url = "http://www.airnowapi.org/aq/observation/latLong/current/?format=application/json&latitude=#{ENV['FOCUS_CITY_LAT']}&longitude=#{ENV['FOCUS_CITY_LON']}&distance=25&API_KEY=#{ENV["AIRNOW_API_KEY"]}"
    	puts observations_url
      observations_data = JSON.parse(RestClient.get(observations_url))
      observations = observations_data.map do |result|
        result["aqi_cat"] = category_number_to_category(result["Category"]["Number"])
        result["observation_at"] = Time.parse("#{result["DateObserved"]} #{result["HourObserved"]}:00 #{result["LocalTimeZone"]}").utc
        result
      end

      exit if observations.empty?

      observations = observations.sort_by{|x| -x["AQI"]}

      # See if the highest observation is more severe than moderate (category number 2)
      highest_observation = observations.first
      if highest_observation["Category"]["Number"].to_i > 2
        # if there are observations more severe than moderate, check to see if we have sent an email within the past 4 hours

        #OLD:::
        #last_email_sent_sql = "SELECT EXTRACT(EPOCH FROM current_timestamp - ctct_draft_saved_at )/3600 as hours_since_last_email FROM \"#{CKAN_INSTITUTE_MESSAGES_RESOURCE_ID}\" ORDER BY ctct_draft_saved_at desc limit 1"
        #NEW:::
        last_email_sent_sql = "SELECT EXTRACT(EPOCH FROM current_timestamp - ctct_draft_saved_at )/3600 as hours_since_last_email FROM \"#{CKAN_INSTITUTE_MESSAGES_RESOURCE_ID}\" WHERE message_type = 'breaking' ORDER BY ctct_draft_saved_at desc limit 1"
        last_email_sent_result = sql_search_ckan(last_email_sent_sql)
        if last_email_sent_result.first["hours_since_last_email"] > 6
          # if the last email communication was more than four hours ago, send an alert about the latest observation

          message_introduction = "This is an air quality notification for #{ENV['FOCUS_CITY_NAME']} from the Institute for Healthy Air, Water, and Soil."
          message_html = <<-EOS
            <html>
            <head>
            <meta content="width=device-width" name="viewport">
            <!-- major credit goes to https://github.com/leemunroe/html-email-template for the HTML email template -->
            <title>Email from the Institute for Healthy Air, Water, and Soil</title>
            <style>
              *{margin:0;padding:0;font-family:"Helvetica Neue",Helvetica,Helvetica,Arial,sans-serif;font-size:100%;line-height:1.6}img{max-width:100%}body{-webkit-font-smoothing:antialiased;-webkit-text-size-adjust:none;width:100%!important;height:100%}a{color:#348eda}.btn-primary{text-decoration:none;color:#FFF;background-color:#348eda;border:solid #348eda;border-width:10px 20px;line-height:2;font-weight:700;margin-right:10px;text-align:center;cursor:pointer;display:inline-block;border-radius:25px}.btn-secondary{text-decoration:none;color:#FFF;background-color:#aaa;border:solid #aaa;border-width:10px 20px;line-height:2;font-weight:700;margin-right:10px;text-align:center;cursor:pointer;display:inline-block;border-radius:25px}.last{margin-bottom:0}.first{margin-top:0}.padding{padding:10px 0}table.body-wrap{width:100%;padding:20px}table.body-wrap .container{border:1px solid #f0f0f0}table.footer-wrap{width:100%;clear:both!important}.footer-wrap .container p{font-size:12px;color:#666}table.footer-wrap a{color:#999}h1,h2,h3{font-family:"Helvetica Neue",Helvetica,Arial,"Lucida Grande",sans-serif;color:#000;margin:40px 0 10px;line-height:1.2;font-weight:200}h1{font-size:36px}h2{font-size:28px}h3{font-size:22px}ol,p,ul{margin-bottom:10px;font-weight:400;font-size:14px}ol li,ul li{margin-left:5px;list-style-position:inside}.container{display:block!important;max-width:600px!important;margin:0 auto!important;clear:both!important}.body-wrap .container{padding:20px}.content{max-width:600px;margin:0 auto;display:block}.content table{width:100%}
              table[width="595"] {width: 300px !important;}
            </style>
            </head><body style="background-color: #F6F6F6;"><table class="body-wrap"><tr><td></td><td class="container" style="background-color: #FFFFFF"><div class="content"><table><tr><td>
              <p><Greeting /></p>
              <p>#{message_introduction}</p>
              <h1>Latest Observations</h1>
              #{format_observations_html(observations)}

              <div id="understanding">
                <h2>Understanding the AQI</h2>
                <p>
                  The purpose of the AQI is to help you understand what local air quality means to your health. To make it easier to understand, the AQI is divided into six categories: 
                </p>
                <table align="center" style="font-family=&quot;Verdana&quot;, sans-serif;">
                  <tr align="center" style="background:#e1ebf4;color:#005e9e">
                    <th>Air Quality Index (AQI) Values</th>
                    <th>Levels of Health Concern</th>
                    <th>Colors</th>
                  </tr>
                  <tr align="center" style="background:#e1ebf4;color:#005e9e">
                    <th>When the AQI is in this range:</th>
                    <th>..air quality conditions are:</th>
                    <th>...as symbolized by this color:</th>
                  </tr>
                  <tr align="center" style="color:#333;background:#00e400;">
                    <td>0-50</td>
                    <td>Good</td>
                    <td>Green</td>
                  </tr>
                  <tr align="center" style="color:#333;background:yellow;">
                    <td>51-100</td>
                    <td>Moderate</td>
                    <td>Yellow</td>
                  </tr>
                  <tr align="center" style="color:#333;background:#ff7e00;">
                    <td>101-150</td>
                    <td>Unhealthy for Sensitive Groups</td>
                    <td>Orange</td>
                  </tr>
                  <tr align="center" style="color:white;background:red;">
                    <td>151-200</td>
                    <td>Unhealthy</td>
                    <td>Red</td>
                  </tr>
                  <tr align="center" style="color:white;background:#99004c;">
                    <td>201-300</td>
                    <td>Very Unhealthy</td>
                    <td>Purple</td>
                  </tr>
                  <tr align="center" style="color:white;background:#7e0023;">
                    <td>301-500</td>
                    <td>Hazardous</td>
                    <td>Maroon</td>
                  </tr>
                </table>
                <p>
                  Each category corresponds to a different level of health concern. The six levels of health concern and what they mean are:
                </p>
                <ul>
                  <li>
                    "Good" AQI is 0 - 50. Air quality is considered satisfactory, and air pollution poses little or no risk.
                  </li>
                  <li>
                    "Moderate" AQI is 51 - 100. Air quality is acceptable; however, for some pollutants there may be a moderate health concern for a very small number of people. For example, people who are unusually sensitive to ozone may experience respiratory symptoms.
                  </li>
                  <li>
                    "Unhealthy for Sensitive Groups" AQI is 101 - 150. Although general public is not likely to be affected at this AQI range, people with lung disease, older adults and children are at a greater risk from exposure to ozone, whereas persons with heart and lung disease, older adults and children are at greater risk from the presence of particles in the air.
                  </li>
                  <li>
                    "Unhealthy" AQI is 151 - 200. Everyone may begin to experience some adverse health effects, and members of the sensitive groups may experience more serious effects.
                  </li>
                  <li>
                    "Very Unhealthy" AQI is 201 - 300. This would trigger a health alert signifying that everyone may experience more serious health effects.
                  </li>
                  <li>
                    "Hazardous" AQI greater than 300. This would trigger a health warnings of emergency conditions. The entire population is more likely to be affected.
                  </li>
                </ul>
              </div><!-- end #understanding -->

              <h1>Join our new community health program to solve Louisville's asthma problem</h1>
              <p>Join the <a href="http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws">AIR Louisville project</a>and help us get off the Asthma Capitals list. We want to distribute 1,100 sensors to people around Jefferson County with asthma. The sensors fit on top of asthma inhalers and track when and where a person uses the inhaler. We will use this data to help individuals manage their asthma and to help the city make smart decisions about how to clean up our air.
              <p>Visit <a href="http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws">airlouisville.com</a> or call 1-877-251-5451 to join the project and get a sensor.
              <p>Visit the Institute's blog to learn more about the <a href="http://instituteforhealthyairwaterandsoil.org/2015/02/new-community-project-uses-sensors-to-track-asthma-attacks/">program</a>
              <p>You can also <a href="http://instituteforhealthyairwaterandsoil.org/join/">subscribe</a> to air quality alerts from the Institute and see for yourself how the air quality in our community changes every day</p>
              <p>Explore the <a href="http://www.louisvilleairmap.com/#10/38.2285/-85.7610">Louisville Air Map</a> and see for yourself how our health and environment varies widely across our community and from day to day.</p>
              </br>
              <p> The Institute for Healthy Air, Water, and Soil
              <br /><a href="mailto:louisville@instituteforhealthyairwaterandsoil.org">louisville@instituteforhealthyairwaterandsoil.org</a>
              <br />Follow us on <a href="http://twitter.com/healthyaws">Twitter</a> and <a href="http://facebook.com/Instituteforhealthyairwaterandsoil">Facebook</a></p>
              <p><em>Together let's preserve our World's Sacred Air, Water, and Soil, so as tocreate the healthy communities that are essential for the survival of all of life!</em></p>
            </td></tr></table></div></td><td></td></tr></table></body></html>
          EOS
	#<a href="http://twitter.com/healthyaws">Twitter</a> 

          message_text = <<-EOS
      .

      <Greeting />

      #{message_introduction}

      ## Latest Observations ##
      #{format_observations_text(observations)}

      ## Join our new community health program to solve Louisville's asthma problem ##
      Join the AIR Louisville project at (http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws) and help us get off the Asthma Capitals list. We want to distribute 1,100 sensors to people around Jefferson County with asthma. The sensors fit on top of asthma inhalers and track when and where a person uses the inhaler. We will use this data to help individuals manage their asthma and to help the city make smart decisions about how to clean up our air.
      Visit (http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws">airlouisville.com) or call 1-877-251-5451 to join the project and get a sensor.
      Visit the Institute's blog to learn more about the program at http://instituteforhealthyairwaterandsoil.org/2015/02/new-community-project-uses-sensors-to-track-asthma-attacks/
      You can also subscribe to air quality alerts from the Institute and see for yourself how the air quality in our community changes every day by visiting http://instituteforhealthyairwaterandsoil.org/join/
      Explore the Louisville Air Map at (http://www.louisvilleairmap.com/#10/38.2285/-85.7610) and see for yourself how our health and environment varies widely across our community and from day to day.</p>

      The Institute for Healthy Air, Water, and Soil
      louisville@instituteforhealthyairwaterandsoil.org
      Follow us on <a href="http://twitter.com/healthyaws">Twitter</a> and Facebook (http://facebook.com/Instituteforhealthyairwaterandsoil)

      Together let's preserve our World's Sacred Air, Water, and Soil, so as to create the healthy communities that are essential for the survival of all of life!


      EOS

      	#<a href='http://twitter.com/healthyaws'>Twitter</a> 

          # puts message_text
          # puts message_html

          # Now that we've got the HTML and text versions of the email crafted, it's time to make API calls to Constant Contact
          time_sent = Time.now.utc.iso8601
          create_campaign_data = {
            "name" => "Breaking Air Quality Email - #{time_sent}",
            "subject" => "UNHEALTHY AIR QUALITY NOTIFICATION for #{ENV['FOCUS_CITY_NAME']} from the Institute for Healthy Air, Water, and Soil",
            "sent_to_contact_lists" => [{"id" => CTCT_LIST_ID}],
            "from_name" => "Institute for Healthy Air, Water, and Soil",
            "from_email" => "louisville@instituteforhealthyairwaterandsoil.org",
            "reply_to_email" => "louisville@instituteforhealthyairwaterandsoil.org",
            "is_permission_reminder_enabled" => false,
            "is_view_as_webpage_enabled" => false,
            "greeting_salutations" => "Hi",
            "greeting_name" => "FIRST_NAME",
            "greeting_string" => "Hi",
            "email_content" => message_html,
            "text_content" => message_text,
            "email_content_format" => "HTML",
            "style_sheet" => "",
            "message_footer" => {
              "organization_name" => "Institute for Healthy Air, Water, and Soil",
              "address_line_1" => "Waterfront Plaza, West Tower",
              "address_line_2" => "11th Floor 325 W. Main Street",
              "address_line_3" => "Suite 1110",
              "city" => "Louisville",
              "state" => "KY",
              "international_state" => "",
              "postal_code" => "40202",
              "country" => "US",
              "include_forward_email" => true,
              "forward_email_link_text" => "Click here to forward this message",
              "include_subscribe_link" => true,
              "subscribe_link_text" => "Subscribe!"
            }
          }

          create_campaign_response = RestClient.post("https://api.constantcontact.com/v2/emailmarketing/campaigns?api_key=#{ENV['CONSTANT_CONTACT_API_KEY']}", create_campaign_data.to_json, :content_type => :json, :accept => :json, 'Authorization' => "Bearer #{ENV['CONSTANT_CONTACT_ACCESS_TOKEN']}")
          if create_campaign_response.code == 201
            create_campaign_result = JSON.parse(create_campaign_response)
            campaign_id = create_campaign_result["id"]

            schedule_campaign_response = RestClient.post("https://api.constantcontact.com/v2/emailmarketing/campaigns/#{campaign_id}/schedules?api_key=#{ENV['CONSTANT_CONTACT_API_KEY']}", {}.to_json, :content_type => :json, :accept => :json, 'Authorization' => "Bearer #{ENV['CONSTANT_CONTACT_ACCESS_TOKEN']}")
            if schedule_campaign_response.code == 201

              data_to_record = {
                :ctct_id => campaign_id.to_s,
                :ctct_list_id => CTCT_LIST_ID.to_s,
                :ctct_draft_saved_at => time_sent,
                :message_type => "breaking",
                :message_html => create_campaign_data["email_content"],
                :message_text => create_campaign_data["text_content"],
                :highest_observation_at => highest_observation["observation_at"].iso8601,
                :highest_observation_aqi => highest_observation["AQI"],
                :highest_observation_aqi_cat => highest_observation["Category"]["Name"],
                :highest_observation_aqi_param => highest_observation["Category"]["Name"]
              }

              upload_data_to_ckan_resource(CKAN_INSTITUTE_MESSAGES_RESOURCE_ID, [data_to_record], 'upsert')
              # puts "Campaign scheduled and logged! It will go out in about 5 minutes"
            else
              raise StandardError, "Campaign ##{campaign_id} could not be scheduled"
            end

          else
            raise StandardError, "Campaign could not be created"
          end

        end


      end


    end

    task :daily do
      # First, let's get the forecast from AirNow APIs
      forecasts_url = "http://www.airnowapi.org/aq/forecast/latLong/?format=application/json&latitude=#{ENV['FOCUS_CITY_LAT']}&longitude=#{ENV['FOCUS_CITY_LON']}&distance=25&API_KEY=#{ENV["AIRNOW_API_KEY"]}"
      puts forecasts_url
      forecasts_data = JSON.parse(RestClient.get(forecasts_url))
      forecasts = forecasts_data.map do |result|
        result["aq_img"] = ""
        result["aqi_cat"] = category_number_to_category(result["Category"]["Number"])

        aqcategory = result["Category"]["Number"]
        aqcategory_integer = aqcategory.to_i
        if aqcategory_integer == 1
          result["aq_img"] = "http://dev.louisvilleairmap.com/assets/img/goodaq_icon.png"
        elsif aqcategory_integer == 2
          result["aq_img"] = "http://dev.louisvilleairmap.com/assets/img/moderateaq_icon.png"
        elsif aqcategory_integer == 3
          result["aq_img"] = "http://dev.louisvilleairmap.com/assets/img/unhealthyaq_icon.png"
        elsif aqcategory_integer == 4
          result["aq_img"] = "http://dev.louisvilleairmap.com/assets/img/unhealthyaq_icon.png"
        end

        if result["ParameterName"] == "O3"
          result["ParameterName"] = "ozone - Ozone makes you cough, irritates your throat and can trigger asthma attack"
        elsif result["ParameterName"] == "PM2.5"
          result["ParameterName"] = "fine particles - These tiny particles of pollution can travel down into your lungs and stick there, causing health problems for everyone, especially people with lung and heart disease."
        end
        result
      end

      # Create two arrays of forecasts (one for today and tomorrow) sorted descending by AQI
      todays_forecasts = forecasts.select{|x| x["DateForecast"].strip == Date.today.strftime("%Y-%m-%d")}.sort_by{|x| -x["AQI"]}
      tomorrows_forecasts = forecasts.select{|x| x["DateForecast"].strip == (Date.today+1).strftime("%Y-%m-%d")}.sort_by{|x| -x["AQI"]}
      todays_forecasts_first = forecasts.select{|x| x["DateForecast"].strip == Date.today.strftime("%Y-%m-%d")}.sort_by{|x| -x["AQI"]}.last
      tomorrows_forecasts_first = forecasts.select{|x| x["DateForecast"].strip == (Date.today+1).strftime("%Y-%m-%d")}.sort_by{|x| -x["AQI"]}.last

      # See if today or tomorrow are action days
      today_is_an_action_day = todays_forecasts.select{|x| x["ActionDay"] == true}.count > 1
      tomorrow_is_an_action_day = tomorrows_forecasts.select{|x| x["ActionDay"] == true}.count > 1

      # Count the number of AQEs that have been deployed by the Institute
      # egg_ids = META["aqe"]["extras_hash"]["Focus IDs"]
      # n_eggs = egg_ids.split(",").count
      # Count the number of AQEs in the area
      n_eggs = JSON.parse(fetch_all_feeds("&lat=38.1935&lon=-85.7121&distance=25&distance_units=kms")).count

      # Get latest blog post   
      blog_title, blog_date, blog_link, blog_content, blog_content_text, blog_is_recent_msg = get_latest_blogpost()  

      eggs_last_updated_sql = "SELECT site_table.id, (SELECT EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - data_table.datetime)) FROM \"7d618c44-1098-4348-9f57-8d32d4b159b6\" data_table WHERE data_table.feed_id = site_table. ID ORDER BY datetime DESC LIMIT 1  ) AS last_updated_seconds_ago FROM \"7c0608e3-fb4d-4fb3-928c-5351e5b9b122\" site_table WHERE site_table.id IN (#{META["aqe"]["extras_hash"]["Focus IDs"]})"
      eggs_last_updated_result = sql_search_ckan(eggs_last_updated_sql)
      eggs_last_updated_within_a_week = eggs_last_updated_result.select{|e| e["last_updated_seconds_ago"] != nil && e["last_updated_seconds_ago"] < 7*24*60*60}
      n_eggs_last_updated_within_a_week = eggs_last_updated_within_a_week.count
      egg_message = "The Institute is in the process of deploying Air Quality Eggs. To date, #{n_eggs} have been deployed and #{n_eggs_last_updated_within_a_week} tested. You can explore the data they collect alongside other community data at http://LouisvilleAirMap.com"

      message_introduction = "This is your daily air quality update for #{ENV['FOCUS_CITY_NAME']} from the Institute for Healthy Air, Water, and Soil."
      message_html = <<-EOS
        <html>
        <head>
        <meta content="width=device-width" name="viewport">
        <!-- major credit goes to https://github.com/leemunroe/html-email-template for the HTML email template -->
        <title>Email from the Institute for Healthy Air, Water, and Soil</title>
        <style>
          *{margin:0;padding:0;font-family:"Helvetica Neue",Helvetica,Helvetica,Arial,sans-serif;font-size:100%;line-height:1.6}img{max-width:100%}body{-webkit-font-smoothing:antialiased;-webkit-text-size-adjust:none;width:100%!important;height:100%}a{color:#348eda}.btn-primary{text-decoration:none;color:#FFF;background-color:#348eda;border:solid #348eda;border-width:10px 20px;line-height:2;font-weight:700;margin-right:10px;text-align:center;cursor:pointer;display:inline-block;border-radius:25px}.btn-secondary{text-decoration:none;color:#FFF;background-color:#aaa;border:solid #aaa;border-width:10px 20px;line-height:2;font-weight:700;margin-right:10px;text-align:center;cursor:pointer;display:inline-block;border-radius:25px}.last{margin-bottom:0}.first{margin-top:0}.padding{padding:10px 0}table.body-wrap{width:100%;padding:20px}table.body-wrap .container{border:1px solid #f0f0f0}table.footer-wrap{width:100%;clear:both!important}.footer-wrap .container p{font-size:12px;color:#666}table.footer-wrap a{color:#999}h1,h2,h3{font-family:"Helvetica Neue",Helvetica,Arial,"Lucida Grande",sans-serif;color:#000;margin:40px 0 10px;line-height:1.2;font-weight:200}h1{font-size:36px}h2{font-size:28px}h3{font-size:22px}ol,p,ul{margin-bottom:10px;font-weight:400;font-size:14px}ol li,ul li{margin-left:5px;list-style-position:inside}.container{display:block!important;max-width:600px!important;margin:0 auto!important;clear:both!important}.body-wrap .container{padding:20px}.content{max-width:600px;margin:0 auto;display:block}.content table{width:100%}
          table[width="595"] {width: 300px !important;}
        </style>
        </head><body style="background-color: #F6F6F6;"><table class="body-wrap"><tr><td></td><td class="container" style="background-color: #FFFFFF"><div class="content"><table><tr><td>
          <p><Greeting /></p>
          <p>
            #{message_introduction}
          </p>
          <h2>Today's Forecast</h2>
            <img src='#{todays_forecasts_first["aq_img"]}' alt=''></img>
            </br>
            #{format_forecasts_html(todays_forecasts)}

            <!-- #{format_action_day_html(today_is_an_action_day)}
            #{format_forecasts_html(todays_forecasts)} -->
            
        <br />
        <!-- <table><tr><td class="">
        </td></tr></table>
        #{format_action_day_html(tomorrow_is_an_action_day)} -->

        <p> On bad air days, higher levels of pollution can cause problems for everyone, but people in these groups should definetly plan to stay indoors:
          <ul>
            <li>Children, particularly toddlers and babies</li>
            <li>People over 65</li>
            <li>People with asthma, COPD, chronic bronchitis, or other breathing problems</li>
            <li>Runners, cyclists, or anyone who is active outdoors</li>
          </ul>

        <h3>Latest Blog Post: <a href="#{blog_link}">
        #{blog_title}
        </a></h3>
        <p>#{blog_date}</p>
        <p>#{blog_content}
          <br /><a href="#{blog_link}">(click here to read the full story)</a>
        </p>
            

        <div id="understanding">
            <h2>Understanding the AQI</h2>
            <p>
              The purpose of the AQI is to help you understand what local air quality means to your health. To make it easier to understand, the AQI is divided into six categories: 
            </p>
            <table align="center" style="font-family=&quot;Verdana&quot;, sans-serif;">
              <tr align="center" style="background:#e1ebf4;color:#005e9e">
                <th>Air Quality Index (AQI) Values</th>
                <th>Levels of Health Concern</th>
                <th>Colors</th>
              </tr>
              <tr align="center" style="background:#e1ebf4;color:#005e9e">
                <th>When the AQI is in this range:</th>
                <th>..air quality conditions are:</th>
                <th>...as symbolized by this color:</th>
              </tr>
              <tr align="center" style="color:#333;background:#00e400;">
                <td>0-50</td>
                <td>Good</td>
                <td>Green</td>
              </tr>
              <tr align="center" style="color:#333;background:yellow;">
                <td>51-100</td>
                <td>Moderate</td>
                <td>Yellow</td>
              </tr>
              <tr align="center" style="color:#333;background:#ff7e00;">
                <td>101-150</td>
                <td>Unhealthy for Sensitive Groups</td>
                <td>Orange</td>
              </tr>
              <tr align="center" style="color:white;background:red;">
                <td>151-200</td>
                <td>Unhealthy</td>
                <td>Red</td>
              </tr>
              <tr align="center" style="color:white;background:#99004c;">
                <td>201-300</td>
                <td>Very Unhealthy</td>
                <td>Purple</td>
              </tr>
              <tr align="center" style="color:white;background:#7e0023;">
                <td>301-500</td>
                <td>Hazardous</td>
                <td>Maroon</td>
              </tr>
            </table>
            <p>
              Each category corresponds to a different level of health concern. The six levels of health concern and what they mean are:
            </p>
            <ul>
              <li>
                "Good" AQI is 0 - 50. Air quality is OK.
              </li>
              <li>
                "Moderate" AQI is 51 - 100. Air quality is acceptable. People who are unusually sensitive to ozone may feel symptoms, such as coughing, a scratchy throat or trouble breathing.
              </li>
              <li>
                "Unhealthy for Sensitive Groups" AQI is 101 - 150. People with lung disease, people over 65 and children are at a greater risk from exposure to ozone. People with heart and lung disease, older adults and children are at greater risk from the presence of particles in the air.
              </li>
              <li>
                "Unhealthy" AQI is 151 - 200. Everyone may begin to feel symptoms, such as coughing, a scratchy throat or trouble breathing. People in the sensitive groups - people over 65, children, and people with asthma or COPD - may experience more serious effects.
              </li>
              <li>
                "Very Unhealthy" AQI is 201 - 300. Everyone may experience more serious health effects. 
              </li>
              <li>
                "Hazardous" AQI greater than 300. his is an emergency condition. The entire population is more likely to be affected.
              </li>
            </ul>
        </div><!-- end #understanding -->
        <h1>Join our new community health program to solve Louisville's asthma problem</h1>
        <p>Join the <a href="http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws">AIR Louisville project</a> and help us get off the Asthma Capitals list. We want to distribute 1,100 sensors to people around Jefferson County with asthma. The sensors fit on top of asthma inhalers and track when and where a person uses the inhaler. We will use this data to help individuals manage their asthma and to help the city make smart decisions about how to clean up our air.
        <p>Visit <a href="http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws">airlouisville.com</a> or call 1-877-251-5451 to join the project and get a sensor.
        <p>Visit the Institute's blog to learn more about the <a href="http://instituteforhealthyairwaterandsoil.org/2015/02/new-community-project-uses-sensors-to-track-asthma-attacks/">program</a>
        <p>You can also <a href="http://instituteforhealthyairwaterandsoil.org/join/">subscribe</a> to air quality alerts from the Institute and see for yourself how the air quality in our community changes every day</p>
        <p>Explore the <a href="http://www.louisvilleairmap.com/#10/38.2285/-85.7610">Louisville Air Map</a> and see for yourself how our health and environment varies widely across our community and from day to day.</p>
        <br />
        <p> The Institute for Healthy Air, Water, and Soil
        <br />
        <a href="mailto:louisville@instituteforhealthyairwaterandsoil.org">louisville@instituteforhealthyairwaterandsoil.org</a>
        <br />
        Follow us on <a href="http://twitter.com/healthyaws">Twitter</a> and <a href="http://facebook.com/Instituteforhealthyairwaterandsoil">Facebook</a></p>
        <p><em>Together let's preserve our World's Sacred Air, Water, and Soil, so as tocreate the healthy communities that are essential for the survival of all of life!</em></p>
        </body>
        </html>
      EOS

	#<a href="http://twitter.com/healthyaws">Twitter</a>

      message_text = <<-EOS
  .

  <Greeting />

  #{message_introduction}

  ## Today's Forecast ##
#{format_action_day_text(today_is_an_action_day)}#{format_forecasts_text(todays_forecasts)}
  ## Tomorrow's Forecast ##
#{format_action_day_text(today_is_an_action_day)}#{format_forecasts_text(tomorrows_forecasts)}

  ## From Our Blog ##
  #{blog_title}
  #{blog_date}

  #{blog_content_text}
  Read the full story at #{blog_link}


  ## Understanding the AQI
  The purpose of the AQI is to help you understand what local air quality means
  to your health. To make it easier to understand, the AQI is divided into six
  categories:

  Air Quality Index (AQI) Values |  Levels of Health Concern      | Colors
  When the AQI is in this range: | ..air quality conditions are:  | ...as symbolized by this color:
  0-50                           | Good                           | Green
  51-100                         | Moderate                       | Yellow
  101-150                        | Unhealthy for Sensitive Groups | Orange
  151 to 200                     | Unhealthy                      | Red
  201 to 300                     | Very Unhealthy                 | Purple
  301 to 500                     | Hazardous                      | Maroon

  Each category corresponds to a different level of health concern. The six
  levels of health concern and what they mean are:

  - "Good" AQI is 0 - 50. Air quality is OK.
  - "Moderate" AQI is 51 - 100. Air quality is acceptable. People who are unusually sensitive to ozone may feel symptoms, such as coughing, a scratchy throat or trouble breathing.
  - "Unhealthy for Sensitive Groups" AQI is 101 - 150. People with lung disease, people over 65 and children are at a greater risk from exposure to ozone. People with heart and lung disease, older adults and children are at greater risk from the presence of particles in the air.
  - "Unhealthy" AQI is 151 - 200. Everyone may begin to feel symptoms, such as coughing, a scratchy throat or trouble breathing. People in the sensitive groups - people over 65, children, and people with asthma or COPD - may experience more serious effects.
  - "Very Unhealthy" AQI is 201 - 300. Everyone may experience more serious health effects.
  - "Hazardous" AQI greater than 300. This is an emergency condition. The entire population is more likely to be affected.

  ## Join our new community health program to solve Louisville's asthma problem ##
  Join the AIR Louisville project at (http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws) and help us get off the Asthma Capitals list. We want to distribute 1,100 sensors to people around Jefferson County with asthma. The sensors fit on top of asthma inhalers and track when and where a person uses the inhaler. We will use this data to help individuals manage their asthma and to help the city make smart decisions about how to clean up our air.
  Visit (http://www.airlouisville.com/?utm_source=organic&utm_medium=referral&utm_campaign=inst_health_aws">airlouisville.com) or call 1-877-251-5451 to join the project and get a sensor.
  Visit the Institute's blog to learn more about the program at http://instituteforhealthyairwaterandsoil.org/2015/02/new-community-project-uses-sensors-to-track-asthma-attacks/
  You can also subscribe to air quality alerts from the Institute and see for yourself how the air quality in our community changes every day by visiting http://instituteforhealthyairwaterandsoil.org/join/
  Explore the Louisville Air Map at (http://www.louisvilleairmap.com/#10/38.2285/-85.7610) and see for yourself how our health and environment varies widely across our community and from day to day.</p>

  The Institute for Healthy Air, Water, and Soil
  louisville@instituteforhealthyairwaterandsoil.org
  Follow us on Twitter (http://twitter.com/healthyaws) and
  Facebook (http://facebook.com/Instituteforhealthyairwaterandsoil)

  EOS

      # Now that we've got the HTML and text versions of the email crafted, it's time to make API calls to Constant Contact
      time_sent = Time.now.utc.iso8601
      create_campaign_data = {
        "name" => "Daily Air Quality Email - #{time_sent}",
        "subject" => "Today's Air Quality Update for #{ENV['FOCUS_CITY_NAME']} ", # revised by BN
        "sent_to_contact_lists" => [{"id" => CTCT_LIST_ID}],
        "from_name" => "Institute for Healthy Air, Water, and Soil",
        "from_email" => "louisville@instituteforhealthyairwaterandsoil.org",
        "reply_to_email" => "louisville@instituteforhealthyairwaterandsoil.org",
        "is_permission_reminder_enabled" => false,
        "is_view_as_webpage_enabled" => false,
        "greeting_salutations" => "Hi",
        "greeting_name" => "FIRST_NAME",
        "greeting_string" => "Hi",
        "email_content" => message_html,
        "text_content" => message_text,
        "email_content_format" => "HTML",
        "style_sheet" => "",
        "message_footer" => {
          "organization_name" => "Institute for Healthy Air, Water, and Soil",
          "address_line_1" => "Waterfront Plaza, West Tower",
          "address_line_2" => "11th Floor 325 W. Main Street",
          "address_line_3" => "Suite 1110",
          "city" => "Louisville",
          "state" => "KY",
          "international_state" => "",
          "postal_code" => "40202",
          "country" => "US",
          "include_forward_email" => true,
          "forward_email_link_text" => "Click here to forward this message",
          "include_subscribe_link" => true,
          "subscribe_link_text" => "Subscribe!"
        }
      }
      puts "c response"
      # puts create_campaign_data.to_json
      
	begin
	      create_campaign_response = RestClient.post("https://api.constantcontact.com/v2/emailmarketing/campaigns?api_key=#{ENV['CONSTANT_CONTACT_API_KEY']}", create_campaign_data.to_json, :content_type => :json, :accept => :json, 'Authorization' => "Bearer #{ENV['CONSTANT_CONTACT_ACCESS_TOKEN']}")
	rescue => e
		puts e.response
		next
	end
      if create_campaign_response.code == 201
        create_campaign_result = JSON.parse(create_campaign_response)
        campaign_id = create_campaign_result["id"]

        schedule_campaign_response = RestClient.post("https://api.constantcontact.com/v2/emailmarketing/campaigns/#{campaign_id}/schedules?api_key=#{ENV['CONSTANT_CONTACT_API_KEY']}", {}.to_json, :content_type => :json, :accept => :json, 'Authorization' => "Bearer #{ENV['CONSTANT_CONTACT_ACCESS_TOKEN']}")
        if schedule_campaign_response.code == 201

          data_to_record = {
            :ctct_id => campaign_id.to_s,
            :ctct_list_id => CTCT_LIST_ID.to_s,
            :ctct_draft_saved_at => time_sent,
            :message_type => "daily",
            :message_html => create_campaign_data["email_content"],
            :message_text => create_campaign_data["text_content"],
            :today_action_day => (today_is_an_action_day ? 1 : 0),
            :tomorrow_action_day => (tomorrow_is_an_action_day ? 1 : 0),
            :institute_live_eggs => n_eggs_last_updated_within_a_week,
            :institute_total_eggs => n_eggs
          }
          unless todays_forecasts.empty?
            data_to_record[:today_forecast_prevailing_aqi] = todays_forecasts.first["AQI"]
            data_to_record[:today_forecast_prevailing_aqi_cat] = todays_forecasts.first["Category"]["Name"]
            data_to_record[:today_forecast_prevailing_aqi_param] = todays_forecasts.first["ParameterName"]
          end
          unless tomorrows_forecasts.empty?
            data_to_record[:tomorrow_forecast_prevailing_aqi] = tomorrows_forecasts.first["AQI"]
            data_to_record[:tomorrow_forecast_prevailing_aqi_cat] = tomorrows_forecasts.first["Category"]["Name"]
            data_to_record[:tomorrow_forecast_prevailing_aqi_param] = tomorrows_forecasts.first["ParameterName"]
          end

          upload_data_to_ckan_resource(CKAN_INSTITUTE_MESSAGES_RESOURCE_ID, [data_to_record], 'upsert')
          puts "Campaign scheduled and logged! It will go out in about 5 minutes"
        else
          raise StandardError, "Campaign ##{campaign_id} could not be scheduled"
        end

      else
        raise StandardError, "Campaign could not be created"
      end

    end

  end

end
