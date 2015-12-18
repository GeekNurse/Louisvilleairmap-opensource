require 'time'

desc "Get heatmap data"
task :get_aqheatmap_data do |t|
	date = Date.today.to_s
	hour_end = Time.now.hour
	puts hour_end
	hour_start = hour_end-1
	puts hour_start
	if hour_start.to_i > 0
        hour_start_transformed = hour_start
    else
        hour_start_transformed = "23"
    end
	puts hour_start_transformed
	heatmapurl = "http://www.airnowapi.org/aq/data/?startDate=#{date}T#{hour_start_transformed}&endDate=#{date}T#{hour_end}&parameters=PM25&BBOX=-130.536499,21.726009,-56.005249,50.139721&dataType=B&format=text/csv&API_KEY=#{ENV["AIRNOW_API_KEY"]}"
	puts "here is the API call ...."
	puts heatmapurl
	data = CSV.parse(RestClient.get(heatmapurl))
	puts data
end