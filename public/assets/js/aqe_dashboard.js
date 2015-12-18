var map;

$(function() {


  // map stuff
  map = L.map('map_canvas', {scrollWheelZoom: false, loadingControl: true, layers: []}) // propellerhealth_layer
  map.setView(focus_city.latlon, focus_city.zoom)
  L.tileLayer('http://{s}.tile.stamen.com/toner-lite/{z}/{x}/{y}.png', {
      attribution: 'Map tiles by <a href="http://stamen.com">Stamen Design</a>, under <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a>. Data by <a href="http://openstreetmap.org">OpenStreetMap</a>, under <a href="http://creativecommons.org/licenses/by-sa/3.0">CC BY SA</a>.',
      maxZoom: 18
  }).addTo(map);
  L.control.locate({locateOptions: {maxZoom: 9}}).addTo(map);
  L.control.fullscreen().addTo(map);

  $("tr[data-sensor-id]").each(function(n,row){
    var type = $(row).data("sensor-type")
    var id = $(row).data("sensor-id")
    var detail = $(row).data("detail-level")
    $.getJSON("/"+type+"/"+id+".json?include_recent_history=1&include_recent_history_days=3", function(data,status){

      // console.log(data)


      // manipulate row
      if(data.status == "not_found"){
        $(row).find(".sensor-status").html("not_found")
        $(row).addClass("danger")
        $(row).children('td').last().html("No data for this site")
        move_row_to_top(row)
        $(".num-sensors-not_found").html(parseInt($(".num-sensors-not_found").html()) + 1)
      }
      else {

        // add to map
        var eggMarker = L.marker([data.location_lat, data.location_lon])
        onEachEggFeature(data,eggMarker)
        eggMarker.setIcon(L.divIcon({className: 'leaflet-icon-egg-'+data.status+' leaflet-icon-egg'}))        
        eggMarker.addTo(map);

        $(row).find(".sensor-title").html(data.site_name || data.title)
        $(row).find(".sensor-description").html(data.msa_name || data.cmsa_name || data.description)
        if(detail == "dashboard"){
          if(data.status == "frozen"){
            $(row).addClass("warning")
            $(".num-sensors-frozen").html(parseInt($(".num-sensors-frozen").html()) + 1)
            move_row_to_top(row)
          } else {
            $(row).addClass("success")
            $(".num-sensors-live").html(parseInt($(".num-sensors-live").html()) + 1)
          }
          $(row).find(".sensor-status").html(data.status)
          $(row).find(".sensor-created_at").html(moment(data.created).fromNow()+" ("+moment(data.created).calendar()+")")
        }
        var html = formatDashboardSensorDetails(data)
        $(row).children('td').last().html(html)
        $(".inlinesparkline").sparkline(
          'html',
          { tooltipFormatter: function (sparkline, options, fields) {return fields.y + " @ " + moment(fields.x+72000000).format("MM/DD/YY [at] h:mm a ([GMT] Z)")  ;}}
        );
        $(".inlinesparkline").show()
      } 
    })
	})
})


function formatDashboardSensorDetails(data){
  var html = ""
  if(data.prevailing_aqi){
    html += " <div class='alert' style='padding: 5px; background-color:"+data.prevailing_aqi.aqi_cat.color+"; color:"+data.prevailing_aqi.aqi_cat.font+"'>This location's air is "+data.prevailing_aqi.aqi_cat.name+"</div> "
  }
  var sensor_table = "<table class='table table-striped'><tr><th>Sensor</th><th>Latest Reading</th></tr></tr>"
  html += sensor_table
  $.each(data.datastreams, function(name,item){
    if(item){
      html += "<tr>"
      html += "<td>"+name+"</td>"
      html += "<td>"
      if(item.computed_aqi > 0){
        html += " <span class='alert' style='padding: 2px; background-color:"+item.aqi_cat.color+"; color:"+item.aqi_cat.font+"'>"+item.aqi_cat.name+" (AQI = "+item.computed_aqi+")</span> "
      }
      html += " " + item.value + " " + item.unit
      if(item.datetime){ html += " (" + moment(item.datetime+"Z").fromNow() +  ")"  }
      else if(item.time){ html += " (" + moment(item.date + " " + item.time).fromNow() +  ")" }
      else {html += " (" + moment(item.date ).fromNow() +  ")" }

      if(item.recent_history){
        var values = $.map(item.recent_history,function(pair,i){return pair[0]+":"+pair[1]})
        html += "<span class=\"inlinesparkline\" values=\""+values.join(",")+"\"></span>"
      }


      html += "</td>"
      html += "</tr>"
    }        
  })
  html += "</table>"
  if(html == sensor_table+"</table>"){html = "<em>No recent data available</em>"}
  return html
}
