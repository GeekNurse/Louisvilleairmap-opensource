[![Build Status](https://travis-ci.org/marks/airqualityegg.com.png?branch=master)](https://travis-ci.org/xively/airqualityegg.com)

# Welcome to LouisvilleAirMap

This site is a [Ruby](http://www.ruby-lang.org/), 
[Sinatra](http://www.sinatrarb.com/) app that provides an data visualization layer on top of CKAN data. This site's development is supported by the [Institute for Healthy air, Water and Soil](http://instituteforhealthyairwaterandsoil.org/) out of Louisville Kentucky. 

## Development

### Get the code
`git clone https://github.com/amcgail/louisvilleairmap.com.git && cd louisvilleairmap.com`
`git submodule init`
`git submodule update`

### Prerequisites

* A working Ruby environment. The app should work in all common flavours
  of ruby (1.8.7, 1.9.2, 1.9.3, Rubinius, jruby)

### Add environment variables to .env file

```bash
# Sample .env file
AIRNOW_API_KEY="Your AirNow API Key"
AIRNOW_PASS="Your AirNow API Password"
AIRNOW_USER="Your API AirNow Username"
CKAN_API_KEY="Your CKAN API Key"
CKAN_AQE_DATASET_ID="air-quality-eggs"
CKAN_AQE_DATA_RESOURCE_NAME="Air Quality Egg Data"
CKAN_AQE_SITE_RESOURCE_NAME="Air Quality Egg Sites"
CKAN_AQS_DATASET_ID="aqs-data-from-airnow"
CKAN_AQS_DATA_RESOURCE_NAME="AirNow AQS Monitoring Data"
CKAN_AQS_SITE_RESOURCE_NAME="AirNow AQS Monitoring Sites"
CKAN_BIKE_DATASET_ID="bike-mounted-sensors"
CKAN_BIKE_DATA_RESOURCE_NAME="Bike Mounted Sensor Data"
CKAN_DATASET_KEYS="aqs,aqe,jeffschools,propaqe,bike,parks,food,pcsa,famallergy,nursinghome,wupws,institute_messages,he2014neighborhoodgeojson,waste,usgsw_sites,usgsw_data,usgsw_params,landfillsgeojson"
CKAN_DATASET_KEYS_SITES_JOINABLE="aqs,aqe,famallergy"
CKAN_FAMALLERGY_DATASET_ID="family-allergy-and-asthma-observations"
CKAN_FAMALLERGY_DATA_RESOURCE_NAME="Family Allergy and Asthma Monitoring Data"
CKAN_FAMALLERGY_SITE_RESOURCE_NAME="Family Allergy and Asthma Monitoring Sites"
CKAN_FOOD_DATASET_ID="city-of-louisville-food-service-inspections"
CKAN_FOOD_DATA_RESOURCE_NAME="Food Inspections CSV"
CKAN_HE2014NEIGHBORHOODGEOJSON_DATASET_ID="city-of-louisville-ky-health-equity-report-2014"
CKAN_HE2014NEIGHBORHOODGEOJSON_SITE_RESOURCE_NAME="Neighborhood Level Data: GeoJSON"
CKAN_HOST="Your CKAN Host"
CKAN_INSTITUTE_MESSAGES_DATASET_ID="institute-messages"
CKAN_INSTITUTE_MESSAGES_RESOURCE_NAME="Daily and Breaking Alerts"
CKAN_JEFFSCHOOLS_DATASET_ID="jefferson-county-kentucky-schools"
CKAN_JEFFSCHOOLS_SITE_RESOURCE_NAME="CSV of Schools with Lat and Lon"
CKAN_LANDFILLSGEOJSON_DATASET_ID="louisville-landfill-data"
CKAN_LANDFILLSGEOJSON_SITE_RESOURCE_NAME="Landfill_pt_latlon"
CKAN_NURSINGHOME_DATASET_ID="cms-nursing-home-compare"
CKAN_NURSINGHOME_SITE_RESOURCE_NAME="Nursing Homes in KY"
CKAN_PARKS_DATASET_ID="city-of-louisville-parks"
CKAN_PARKS_DATA_RESOURCE_NAME="Parks and their Amenities"
CKAN_PCSA_DATASET_ID="primary-care-service-area-data"
CKAN_PCSA_SITE_RESOURCE_NAME="Primary Care Service Area Data - 2009"
CKAN_PROPAQE_DATASET_ID="proposed-aqe-egg-sites"
CKAN_PROPAQE_SITE_RESOURCE_NAME="Fishnet in CSV"
CKAN_USGSW_DATA_DATASET_ID="usgs_water_sites"
CKAN_USGSW_DATA_SITE_RESOURCE_NAME="USGS Measurements"
CKAN_USGSW_PARAMS_DATASET_ID="usgs_water_sites"
CKAN_USGSW_PARAMS_SITE_RESOURCE_NAME="USGS Parameter List"
CKAN_USGSW_SITES_DATASET_ID="usgs_water_sites"
CKAN_USGSW_SITES_SITE_RESOURCE_NAME="USGS Water Sites"
CKAN_WASTE_DATASET_ID="hazardous_waste_lv"
CKAN_WASTE_SITE_RESOURCE_NAME="Hazardous Waste Management Fund active capital projects"
CKAN_WUPWS_DATASET_ID="weather-underground-personal-weather-stations"
CKAN_WUPWS_SITE_RESOURCE_NAME="Personal Weather Stations in Louisville"
CONSTANT_CONTACT_ACCESS_TOKEN="Your Constant contact access token"
CONSTANT_CONTACT_API_KEY="Your Constant Contact API Key"
CONSTANT_CONTACT_DEMO_LIST_ID="Constant Contact List ID"
CONSTANT_CONTACT_LIST_ID="constant Contact List ID"
CONSTANT_CONTACT_SECRET="Your Contant Contact Secret"
DATABASE_URL="Your PostGres DB URL"
FOCUS_CITY="Louisville"
FOCUS_CITY_LAT="38.228471"
FOCUS_CITY_LON="-85.760993"
FOCUS_CITY_NAME="Louisville, KY"
FOCUS_CITY_STATE="KY"
FOCUS_CITY_ZOOM="10"
GOOGLE_ANALYTICS_DOMAIN="louisvilleairmap.com/"
GOOGLE_ANALYTICS_TRACKING_ID="Your google analytics tracking ID"
HTTP_BASIC_PASS=" Password "
HTTP_BASIC_USER=" UserID"
LANG="en_US.UTF-8"
RACK_ENV="production"
SESSION_SECRET=" Session Secret"
WEATHER_UNDERGROUND_API_KEY="Your Weather Underground API Key"
WORDPRESS_BASE="Your wordpress URL to get latest blog post excerpt"
WORDPRESS_FACTS_PAGE_SLUG="facts"
XIVELY_API_KEY="Your Xively API Key for the air quality eggs"
XIVELY_PRODUCT_ID="Your Xively product ID for the air quality eggs"
```

The values in this file are required to interact with Xively, but some value
for each environment variable is required to boot the app locally, so initially
just create the file with dummy contents. Note that this means your local app 
won't be able to actually interact with Xively, but you will be able to view the 
AQE site running locally.

### Install bundler gem

`gem install bundler`

### Install all gem dependencies

`bundle install`

### Start webserver

`bundle exec foreman start`

Visit http://localhost:5000, and you should see a version of the AQE 
website running locally on your machine.

### Running the tests

`bundle exec rake`s

### Set up on heroku
Visit https://devcenter.heroku.com/articles/creating-apps for information on how to create a heroku app

#### Sample crontab entries when hosted on AWS - use the rake jobs with scheuler for Heroku
```bash
# run airnow on even hours and airqualityeggs updates on odd hours
30   */2     *   *  * ec2-user        source /home/ec2-user/.rvm/environments/ruby-2.0.0-p451 && cd /home/ec2-user/airqualityegg.com && foreman run bundle exec rake ckan:airnow:update
30    1-23/2    * * * ec2-user        source /home/ec2-user/.rvm/environments/ruby-2.0.0-p451 && cd /home/ec2-user/airqualityegg.com && foreman run bundle exec rake ckan:airqualityeggs:update

# family allergy and asthma data 
15   1  *	* * ec2-user        source /home/ec2-user/.rvm/environments/ruby-2.0.0-p451 && cd /home/ec2-user/airqualityegg.com && foreman run bundle exec rake ckan:famallergy:update 

# weather underground weather station scraping
45   3  *	* * ec2-user        source /home/ec2-user/.rvm/environments/ruby-2.0.0-p451 && cd /home/ec2-user/airqualityegg.com && foreman run bundle exec rake ckan:wupws:update 

# send daily email to subscribers at 6am each day
0   10  *	* * ec2-user        source /home/ec2-user/.rvm/environments/ruby-2.0.0-p451 && cd /home/ec2-user/airqualityegg.com && foreman run bundle exec rake mailer:institute_messages:daily
# check for notifcation-worthy observations
0   *  *	* * ec2-user        source /home/ec2-user/.rvm/environments/ruby-2.0.0-p451 && cd /home/ec2-user/airqualityegg.com && foreman run bundle exec rake mailer:institute_messages:breaking

```

## Sample CKAN (Datastore) SQL

### Join AQE sensor readings (from data_table) with their lat/lon values (from sites_table)
```sql
SELECT
  data_table.feed_id,data_table.datetime,data_table.parameter,data_table.value,data_table.unit,
  sites_table.location_lat, sites_table.location_lon
FROM
  "c0d9ab3c-91a3-4fe8-8f54-5d3009e4f01d" sites_table
INNER JOIN "d8482637-477b-4e45-a7f5-6b2ceb98c7e5" data_table ON sites_table.id = data_table.feed_id
LIMIT 10000
```

## Backing up

Virtual machine/AWS EC2 full image backups are always a good idea in addition to the following:

### CKAN
`paster --plugin=ckan db dump 06292014-ckan_full_dump.sql --config=/etc/ckan/default/development.ini`
`paster --plugin=ckan db simple-dump-json 06292014-ckan.json --config=/etc/ckan/default/development.ini`
`paster --plugin=ckan db simple-dump-csv 06292014-ckan.csv --config=/etc/ckan/default/development.ini`

### CKAN Datastore
`pg_dump datastore_default -U ckan_default -W > 06292014-ckan_datastore_dump.sql -h localhost`

## Contributing

Please see our [Contributing guidelines](https://github.com/xively/airqualityegg.com/blob/master/CONTRIBUTING.md).

## License

Please see [LICENSE](https://github.com/xively/airqualityegg.com/blog/master/LICENSE) for licensing details.

## Support

Please file any issues at our [Github issues page](https://github.com/xively/airqualityegg.com/issues).
For general disussion about the project please go to the [Air Quality Egg group](https://groups.google.com/forum/#!forum/airqualityegg).
