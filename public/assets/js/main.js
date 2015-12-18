var oldAjax = $.ajax;

$.ajax = function() {
  var key = JSON.stringify(arguments[0]);
  arguments[0].success = arguments[0].success || function() {};

  if (typeof localStorage[key] !== 'undefined') {
    var entry = $.parseJSON(localStorage[key]);
    if (Date.now() - entry.whengotten < 2 * 60 * 1000) {
      console.log("ALREADY EXISTS: " + key);
      arguments[0].success.call(this, entry.response);
      return;
    }
  }

  var success = (function(s) {
    return function(resp) {
      localStorage[key] = JSON.stringify( {
        "whengotten": Date.now(),
        "response": resp
      } );

      s.call( this, resp );
    };
  })(arguments[0].success || function() {});

  arguments[0].success = success;

  return oldAjax.apply($, arguments);
};

var things_loading = {};

function start_loading(key) {
  $("#loadingbox").toggle(true);
  $("#loadingcont").toggle(true);
  things_loading[key] = true;
}

function stop_loading(key) {
  things_loading[key] = false;
}

setInterval(function() {

  var something = false;

  for (var i in things_loading) {
    if (things_loading[i]) {
      something = true;
    }
  }

  if (something) {
    $("#loadingbox").toggle(true);
    $("#loadingcont").toggle(true);
  } else {
    $("#loadingbox").toggle(false);
    $("#loadingcont").toggle(false);
  }

}, 500);

var map, in_bounds, drawn;
var filter_selections = {};
var loaded_at = new Date();
var breakpoints = [];
var legend_html = '';



var geoJsonLayers = {};
var layersData = {};
var added = [];
var mypatterns = [
  "NE_purple",
  "W_yellow",
  "NW_red",
  "N_blue",
  "orange_grid",
  "blue_diagonals",
  "hs",
  "diag_rect",
  "space",
  "dot_blue"
];
var all_labels = [];

var AQE = (function($) {
  "use strict";

  var aqsIconURL = '/assets/img/blue-dot_15.png';
  var aqsIcon = L.icon({
    iconUrl: aqsIconURL,
    iconSize: [12, 12], // size of the icon
  });
  var aqsIconURL_o = '/assets/img/orange-dot_15.svg';
  var aqsIcon_o = L.icon({
    iconUrl: aqsIconURL_o,
    iconSize: [12, 12], // size of the icon
  });
  var schoolIconURL = '/assets/img/blackboard.png';
  var schoolIcon = L.icon({
    iconUrl: schoolIconURL,
    iconSize: [17, 17], // size of the icon
  });
  var famallergyIconURL = '/assets/img/famallergy.png';
  var famallergyIcon = L.icon({
    iconUrl: famallergyIconURL,
    iconSize: [17, 17], // size of the icon
  });
  var nursinghomeIconURL = '/assets/img/nursing_home_icon.png';
  var nursinghomeIcon = L.icon({
    iconUrl: nursinghomeIconURL,
    iconSize: [30, 30], // size of the icon
  });
  var foodIconURL = '/assets/img/fastfood_icon.png';
  var foodIcon = L.icon({
    iconUrl: foodIconURL,
    iconSize: [30, 30], // size of the icon
  });
  var parkIconURL = '/assets/img/urbanpark_icon.png';
  var parkIcon = L.icon({
    iconUrl: parkIconURL,
    iconSize: [30, 30], // size of the icon
  });
  var weatherStationIconURL = '/assets/img/weather_station_icon.png';
  var weatherStationIcon = L.icon({
    iconUrl: weatherStationIconURL,
    iconSize: [30, 30], // size of the icon
  });
  var wasteIconURL = '/assets/img/hazard.png';
  var wasteIcon = L.icon({
    iconUrl: wasteIconURL,
    iconSize: [30, 30], // size of the icon
  });
  var defaultIconURL = '/vendor/leaflet-0.8-dev-06062014/images/marker-icon.png';
  var defaultIcon = L.icon({
    iconUrl: defaultIconURL,
    iconSize: [12, 20], // size of the icon
  });

  var breakpointColorsHigherIsBetter = [
    '#2c7bb6', // 80% and higher
    '#abd9e9', // 60% and higher
    '#ffffbf', // 40% and hight
    '#fdae61', // 20% and higher
    '#d7191c' // anything else (below 20%)
  ];
  var breakpointColorsLowerIsBetter = [
    '#d7191c', // 80% and higher
    '#fdae61', // 60% and higher
    '#ffffbf', // 40% and hight
    '#abd9e9', // 20% and higher
    '#2c7bb6' // anything else (below 20%)
  ];
  var breakpointColorsHigherIsBetterByLachel = [
    '#FF0000', // 80% and higher
    '#1F5BFF', // 60% and higher
    '#F29600', // 40% and hight
    '#C000E7', // 20% and higher
    '#00F312' // anything else (below 20%)
  ];
  var breakpointColorsLowerIsBetterByLachel = [
    '#00F312', // 80% and higher
    '#C000E7', // 60% and higher
    '#F29600', // 40% and hight
    '#1F5BFF', // 20% and higher
    '#FF0000' // anything else (below 20%)
  ];

  var breakpointWidthHigherIsBetter = [
    13, // 80% and higher
    9, // 60% and higher
    6, // 40% and hight
    3, // 20% and higher
    1 // anything else (below 20%)
  ];

  var healthEquity2014NeighborhoodStyle = {
    color: "#dbb67a",
    opacity: 0.7,
    fillOpacity:0.2,
    weight:3
  };

  var heatmapIconURL = '/assets/img/heatmap_legend.png';

  // OpenWeatherMap Layers
  var clouds_layer = L.OWM.clouds({
    opacity: 0.8,
    legendImagePath: 'files/NT2.png'
  });
  var precipitation_layer = L.OWM.precipitation({
    opacity: 0.5
  });
  var rain_layer = L.OWM.rain({
    opacity: 0.5
  });
  var snow_layer = L.OWM.snow({
    opacity: 0.5
  });
  var pressure_layer = L.OWM.pressure({
    opacity: 0.4
  });
  var temp_layer = L.OWM.temperature({
    opacity: 0.5
  });
  var wind_layer = L.OWM.wind({
    opacity: 0.5
  });

  var groupedOverlays = {
    "Census Data from JusticeMap.org": {},
    "Open Weather Map": {
      "Clouds": clouds_layer,
      "Precipitation": precipitation_layer,
      "Rain": rain_layer,
      "Snow": snow_layer,
      "Pressure": pressure_layer,
      "Temperature": temp_layer,
      "Wind": wind_layer
    },
    "Esri ArcGIS Layers": {}
  };

  groupedOverlays["Esri ArcGIS Layers"]["USGS USA Soil Survey"] = new L.esri.tiledMapLayer(
    "http://server.arcgisonline.com/ArcGIS/rest/services/Specialty/Soil_Survey_Map/MapServer",
    {
      opacity: 0.45,
      attribution:"<a href='http://www.arcgis.com/home/item.html?id=204d94c9b1374de9a21574c9efa31164' target='blank'>USA Soil Survey via ArcGIS MapServer</a>"
    }
  );

  groupedOverlays["Esri ArcGIS Layers"]["USA Median Age from 2012 US Census"] = new L.esri.tiledMapLayer(
    "http://server.arcgisonline.com/arcgis/rest/services/Demographics/USA_Median_Age/MapServer",
    {
      opacity: 0.45,
      attribution:"<a href='http://www.arcgis.com/home/item.html?id=fce0ca8972ae4268bc4a69443b8d1ef5' target='blank'>USA Median Age using 2010 US Census via ArcGIS MapServer</a>"
    }
  );

  groupedOverlays["Esri ArcGIS Layers"]["Esri USA Tapestry"] = new L.esri.tiledMapLayer(
    "http://server.arcgisonline.com/arcgis/rest/services/Demographics/USA_Tapestry/MapServer",
    {
      opacity: 0.45,
      attribution:"<a href='http://www.arcgis.com/home/item.html?id=f5c23594330d431aa5d9a27abb90296d' target='blank'>Esri USA Tapestry via ArcGIS MapServer</a>"
    }
  );

  var legend = L.control({position: 'bottomright'});
  var justiceMapAttribution = '<a target=blank href="http://census.gov">Demographics from 2010 US Census & 2011 American Community Survey (5 yr summary)</a> via <a target=blank href="http://justicemap.org">JusticeMap.org</a>';
  groupedOverlays["Census Data from JusticeMap.org"] = {};
  $.each(["asian","black","hispanic","indian","multi","white","nonwhite","other","income"], function(n,layer_name){
    groupedOverlays["Census Data from JusticeMap.org"][toTitleCase(layer_name) + " by Census Tract"] = L.tileLayer(
        'http://www.justicemap.org/tile/{size}/{layer_name}/{z}/{x}/{y}.png',
        {
          size: 'tract',
          layer_name: layer_name,
          opacity: 0.45,
          attribution: justiceMapAttribution
        }
        );
  });
  var aqheatmap = false
  var aqheatmapshapes = []
  var aqheatmaplayer = ""
  var updatedtime = ""

  initialize();

  function initialize() {
    // $(document.body).append(
    //     $("<div>").attr("id", "loadingbox"),
    //     $("<div>").attr("id", "loadingcont").append(
    //       $("<div>").attr("id", "loadingtext").html("One Moment Please While We Load The Data")
    //       ).toggle(false)
    //     );

    // load feeds and then initialize map and add the markers
    if ($(".map").length >= 1) {
      // set up leaflet map
      map = L.map('map_canvas', {
        scrollWheelZoom: false,
        loadingControl: true,
        layers: []
      }); // propellerhealth_layer
      // map.fireEvent('dataloading')

      if (location.hash === "") {
        map.setView(focus_city.latlon, focus_city.zoom);
      } else {
        var hash_info = location.hash.replace('#', '').split("/");
        map.setView([hash_info[1], hash_info[2]], hash_info[0]);
      }

      setTimeout(function() {
        var hash = new L.Hash(map);
      }, 500);

      var drawControl = new L.Control.Draw({
        draw: {
          polyline: false,
          marker: false
        }
      });
      map.addControl(drawControl);

      L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: 'Map data © <a target=blank href="http://openstreetmap.org">OpenStreetMap</a> contributors',
          maxZoom: 18
          }).addTo(map);
      L.control.groupedLayers([], groupedOverlays).addTo(map);
      L.control.locate({
        locateOptions: {
          maxZoom: 9
        }
      }).addTo(map);
      L.control.fullscreen().addTo(map);

      legend.onAdd = function(map) {
        // console.log(map)
        var div = L.DomUtil.create('div', 'info legend');
        var div_html = "";
        div_html += "<div id='legend' class='leaflet-control-layers leaflet-control leaflet-control-legend leaflet-control-layers-expanded'><div class='leaflet-control-layers-base'></div><div class='leaflet-control-layers-separator' style='display: none;'></div><div class='leaflet-control-layers-overlays'><div class='leaflet-control-layers-group' id='leaflet-control-layers-group-2'><span class='leaflet-control-layers-group-name'></span>";

        // in-Leaflet control layers
        $.each($(".leaflet-control-layers").find("input:checked"), function(n,item) {
          var name = $.trim($(item).parent().text());
          div_html += "<img src='/assets/img/map_legends/" + name + ".png' alt='legend for " + name + "'/>";
        });

        // outside-Leaflet layers with legends
        $.each($(".leaflet-layer-with-legend").find("input:checked:not(.doesntcount)"), function(n, item) {
          var this_item = $(item);
          var dataset_name = $.trim(this_item.parent().text());
          var variable_name = this_item.parent().parent().find("select").val();
          var dataset_variable = dataset_name + "-" + variable_name;

          var fullnames = {
            "LifeExpect": "Life Expectancy",
            "AlcoholDru": "Alcohol or other drugs*",
            "HeartDisea": "Heart disease*",
            "Homicide": "Homicide*",
            "Suicide": "Suicide*",
            "HIV": "HIV*",
            "Diabetes": "Diabetes*",
            "Unintended": "Unintentional injury*",
            "Cancer": "Cancer*",
            "Stroke": "Stroke*"
          };

          if (dataset_variable.indexOf('Neighborhood Health Equity 2014') === 0) {
            div_html += "<table>";
            for (var izz in added) {
              var color = "url(#" + mypatterns[parseInt(izz)] + ")";
              div_html += "<tr><td><svg width=15 height=15><rect width='15' height='15' style='fill:" + color + ";stroke-width:1;stroke:black' /></svg></td>";
              div_html += "<td>" + fullnames[added[izz][0]] + "</td></tr>";
            }
            div_html += "</table>";
          } else {
            div_html += "<img src='/assets/img/map_legends/" + dataset_variable + ".png' alt='legend for " + dataset_variable + "'/>";
          }
        });

        // add legend_html and then clear it
        div_html += legend_html;
        legend_html = '';

        div_html += "</div></div></div>";
        div.innerHTML = div_html;
        return div;
      };

      map.on('overlayadd', function(eventLayer) {
        handleMapLegend();
      });

      map.on('overlayremove', function(eventLayer) {
        handleMapLegend();
      });

      map.on('moveend', function(eventLayer) {
        var map_center = map.getCenter();
        $("#home-map-aqis-container").html("");
        $.getJSON("/aqs/forecast.json?lat=" + map_center.lat + "&lon=" + map_center.lng, formatForecastDetails);
        // get bounding box coordinates and put into variables for testing
        var bbox = map.getBounds();
        // var filtervalue = $('input.filter-airnow-sites-epa:checked').val();
        // var show = true;
        // if (filtervalue === "true"){
        //   show = true;
        // }
        // else {
        //   show = false;
        // }
        // if (filtervalue === "true" ){
        // console.log(filtervalue);
        // var parameter_name_forjson = document.getElementById("airqualityselection").value;
        // console.log(parameter_name_forjson)
        // call the airnow API to get recent AQI values for mapping
          $.getJSON("/aqs/currentairquality.json?&BBOX=" + bbox._southWest.lng.toFixed(4) + "," + bbox._southWest.lat.toFixed(4) + "," + bbox._northEast.lng.toFixed(4) + "," + bbox._northEast.lat.toFixed(4), function(data) {
            console.log( data )
            for(var i = 0; i < data.length; i++) {
              var marker = data[i];
              var longitude = marker[0]
              var lattitude = marker[1]
              // logic for various icon colors
              if (marker[6] <= 50) var iconcolor = "#00e400"
              else if (marker[6] >50 && marker[6] <=100) var iconcolor = "#ffff00"
              else if (marker[6] >101 && marker[6] <=150) var iconcolor = "#ff7e00"
              else if (marker[6] >151 && marker[6] <=200) var iconcolor = "#ff0000"
              else if (marker[6] >201 && marker[6] <=300) var iconcolor = "#99004c"
              else if (marker[6] >301 && marker[6] <=500) var iconcolor = "#7E0023"
              else var iconcolor = "#FFFFFF"
              var markerItem = L.circleMarker(
              [longitude,lattitude], {
                radius: 14,
                fillColor: iconcolor,
                color: "#000",
                weight: 1,
                opacity: 1,
                fillOpacity: 1.0,
              }).bindPopup(
                  "<div><h4>AirNow AQS Site Details</h4><table class='table table-striped' data-aqs_id='"+ marker[10].toString() +"'>"
                  + "<tr><td>Site: </td><td> <a href='/aqs/" + marker[10].toString() + "'><strong>" + marker[8].toString() +" / "+ marker[10].toString() +"</strong></a></td></tr>"
                  + "<tr><td>Agency: </td><td>" + marker[9].toString() + "</td></tr>"
                  + "<tr><td>Parameter: </td><td>" + marker[3].toString() + " of " + marker[4].toString() + " " + marker[5].toString() + "</td></tr>"
                  + "<tr><td>Current AQI: </td><td bgcolor="+iconcolor.toString()+">" + marker[6].toString() + "</td></tr>"
                  + "<tr><td>Agency: </td><td>" + marker[9].toString() + "</td></tr>"
                  + "<tr><td>AQI Reference: </td><td> <a href='http://airnow.gov/index.cfm?action=aqibasics.aqi'>AirNow AQI Reference</a></td></tr>"
                  + "</table>"
                  + "<div id='aqs_" + marker[10].toString() + "'></div>"
                  + "<p style='text-align: right'><a href='/aqs/" + marker[10].toString() + "'>More about this AQS site including historical graphs →</a></p>"
                  + "</div>"
                );
              var airDivIcon = L.divIcon({
                className: 'leaflet-div-icon-aqi',
                html: marker[6].toString(),
              });
              // if (filtervalue === "true" ){
              //   map.addLayer(markerItem);
              //   L.marker([longitude,lattitude],{icon: airDivIcon}).addTo(map);
              // } else {
              //   map.removeLayer(markerItem);
              // } 
              map.addLayer(markerItem);
              L.marker([longitude,lattitude],{icon: airDivIcon}).addTo(map);
            }
          })
        // }
      });
      map.fireEvent('moveend');
      map.on('draw:created', compareFeatures);
    }

    // if on an site's page, zoom in close to the site
    if ($(".dashboard-map").length && feed_location) {
      map.setView(feed_location,9);
    }

    // loop through datasets
    $.each(dataset_keys, function(n, key){
      if ($(".filter-" + key + ":checked").length > 0){
        $.post("/ckan_proxy/" + key + ".geojson", function(data){
          layersData[key] = data;
          update_map(key);
        });
      }
    });

    // if on egg dashboard
    if ($("#dashboard-egg-chart").length){
      graphEggHistoricalData();
    }

    // if on AQS dashboard
    if ($("#dashboard-aqs-chart").length){
      graphAQSHistoricalData();
    }

    $("tr[data-sensor-id]").each(function(n, row){
      var type = $(row).data("sensor-type");
      var id = $(row).data("sensor-id");
      $.getJSON("/"+type+"/"+id+".json", function(data, status){
        if(data.status === "not_found"){
          $(row).find(".sensor-status").html("not_found");
          $(row).addClass("danger");
          $(row).children('td').last().html("No data for this site");
          move_row_to_top(row);
          $(".num-sensors-not_found").html(parseInt($(".num-sensors-not_found").html()) + 1);
        }
        else {
          $(row).find(".sensor-title").html(data.site_name || data.title);
          $(row).find(".sensor-description").html(data.msa_name || data.cmsa_name || data.description);
          var html = formatSensorDetails(data);
          $(row).children('td').last().html(html);
        }
      });
    });

    $(".momentify").each(function(n,item){
      var original = $(item).html();
      var from_now = moment(original).fromNow();
      $(item).html("<abbr title='"+original+"'>"+from_now+"</abbr>");
    });

    $(".filter-he2014neighborhoodgeojson").change( function() {
      $("#filter-he2014neighborhoodgeojson-fine").toggle( this.checked );
    });

    aqheatmaplayer = L.geoJson()
    updatedtime = new Date(0)
    $(".submit-map-filters").on('click',function( event ) {
      event.preventDefault();
      authenticateAndLoadAsthmaHeatLayer($('input.filter-asthmaheat-user').val(),$('input.filter-asthmaheat-pass').val());
      // layersData.bike = undefined // BIKE HACK
      $.each(dataset_keys, function(n,key){
        if( key === 'bike' ) return;
        // console.log( key );
        if($(".filter-"+key+":checked").length > 0 || filter_selections[key] === true){
          if(layersData[key] === undefined){
            // start_loading(key);
            var post_data = choose_post_data(key);
            $.post("/ckan_proxy/"+key+".geojson", post_data, function(data){
              layersData[key] = data;
              update_map(key);
              // stop_loading(key);
            });
          } else {
            // start_loading(key);
            update_map(key);
            toggleAQHeatmap();
            // stop_loading(key);
          };
        } else {
          update_map(key);
        };
      });
      var bbox = map.getBounds();
        var parameter_name_forjson = document.getElementById("airqualityselection").value;
        console.log(parameter_name_forjson)
        // call the airnow API to get recent AQI values for mapping
          $.getJSON("/aqs/currentairquality.json?&parameters=" + parameter_name_forjson + "&BBOX=" + bbox._southWest.lng.toFixed(4) + "," + bbox._southWest.lat.toFixed(4) + "," + bbox._northEast.lng.toFixed(4) + "," + bbox._northEast.lat.toFixed(4), function(data) {
            console.log( data )
            for(var i = 0; i < data.length; i++) {
              var marker = data[i];
              var longitude = marker[0]
              var lattitude = marker[1]
              // logic for various icon colors
              if (marker[6] <= 50) var iconcolor = "#00e400"
              else if (marker[6] >50 && marker[6] <=100) var iconcolor = "#ffff00"
              else if (marker[6] >101 && marker[6] <=150) var iconcolor = "#ff7e00"
              else if (marker[6] >151 && marker[6] <=200) var iconcolor = "#ff0000"
              else if (marker[6] >201 && marker[6] <=300) var iconcolor = "#99004c"
              else if (marker[6] >301 && marker[6] <=500) var iconcolor = "#7E0023"
              else var iconcolor = "#FFFFFF"
              var markerItem = L.circleMarker(
              [longitude,lattitude], {
                radius: 14,
                fillColor: iconcolor,
                color: "#000",
                weight: 1,
                opacity: 1,
                fillOpacity: 1.0,
              }).bindPopup(
                  "<div><h4>AirNow AQS Site Details</h4><table class='table table-striped' data-aqs_id='"+ marker[10].toString() +"'>"
                  + "<tr><td>Site: </td><td> <a href='/aqs/" + marker[10].toString() + "'><strong>" + marker[8].toString() +" / "+ marker[10].toString() +"</strong></a></td></tr>"
                  + "<tr><td>Agency: </td><td>" + marker[9].toString() + "</td></tr>"
                  + "<tr><td>Parameter: </td><td>" + marker[3].toString() + " of " + marker[4].toString() + " " + marker[5].toString() + "</td></tr>"
                  + "<tr><td>Current AQI: </td><td bgcolor="+iconcolor.toString()+">" + marker[6].toString() + "</td></tr>"
                  + "<tr><td>Agency: </td><td>" + marker[9].toString() + "</td></tr>"
                  + "<tr><td>AQI Reference: </td><td> <a href='http://airnow.gov/index.cfm?action=aqibasics.aqi'>AirNow AQI Reference</a></td></tr>"
                  + "</table>"
                  + "<div id='aqs_" + marker[10].toString() + "'></div>"
                  + "<p style='text-align: right'><a href='/aqs/" + marker[10].toString() + "'>More about this AQS site including historical graphs →</a></p>"
                  + "</div>"
                );
              var airDivIcon = L.divIcon({
                className: 'leaflet-div-icon-aqi',
                html: marker[6].toString(),
              });
              map.addLayer(markerItem);
              L.marker([longitude,lattitude],{icon: airDivIcon}).addTo(map);
            };
          });
    });
  

    $(".row.aqe .average-Temperature").each(function(n, item){
      var c = $(item).text();
      var f = celsiusToFahrenheit(c);
      var f_rounded = Math.round( f * 10 ) / 10;
      $(item).text(f_rounded);
    });
  }

  function toggleAQHeatmap(){
    var currentTime = new Date()
    var needupdate = !(currentTime.getDate() == updatedtime.getDate() && currentTime.getFullYear() == updatedtime.getFullYear() && currentTime.getHours() == updatedtime.getHours())
    
    if(!aqheatmap && map.hasLayer(aqheatmaplayer)) { map.removeLayer(aqheatmaplayer) }
    if(aqheatmap && !map.hasLayer(aqheatmaplayer)) { aqheatmaplayer.addTo(map) }
    if(!needupdate) { return } //we're done unless the map needs to update

    if(aqheatmapshapes.length > 0){ //if the aqheatmaplayer is filled in empty it
       for(var i=0; i < aqheatmapshapes.length; i++)
       {
         aqheatmaplayer.removeLayer(aqheatmapshapes[i])
       }
    }
    aqheatmapshapes = []

    var x=[]
    var y=[]
    var z=[]

    // start_loading();
    $.getJSON('/aqs/airnowapi.json', function(data){
          console.log ( data )
          for(var i=0; i<data.length; i++)
          {
            var lon=data[i][1]
            var lat=data[i][0]
            var val=data[i][6]

            if(val==-999) continue;

            x.push(lon)
            y.push(lat)
            z.push(val)
          }
                
          var x0 = -95.339355
          var y0 = 32.805745
          var xd = 0.070532225
          var yd = 0.06833496

          var M = 200
          var N = 200

          for(var i=0; i<M; i++){
             for(var j=0; j<N; j++){
               var dist = []
               var xij = x0+(i*xd)
               var yij = y0+(j*yd)
               var zij = 0.0
               for(var k=0; k < x.length; k++ )
               {
                  dist[k] = Math.pow(x[k]-xij,2) + Math.pow(y[k]-yij,2)
               }
               var values=[ Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER ]
         var nearest=[0,0,0]
               for(var k=0; k < dist.length; k++)
               {
     if (dist[k]<values[0]){
                    values[2]=values[1]
                    values[1]=values[0]
                    values[0]=dist[k]
                    nearest[2]=nearest[1]
                    nearest[1]=nearest[0]
                    nearest[0]=k
                 } else if(dist[k]<values[1]){
                    values[2]=values[1]
                    values[1]=dist[k]
                    nearest[2]=nearest[1]
                    nearest[1]=k
                 } else if(dist[k]<values[2]){
                    values[2]=dist[k]
                    nearest[2]=k
                 }
               }
               var weight = dist.map(function(n){
                  return 1.0/Math.pow(n,5)
               })
              var sensors_in_range = 0
               for(var k=0; k < nearest.length; k++)
               {
                if(dist[nearest[k]] < .55) {
                 zij = zij + (z[nearest[k]] * weight[nearest[k]])
                 sensors_in_range++;
                }
               }
               var total_weight = 0
               for(var k = 0; k < sensors_in_range; k++) {
                total_weight = total_weight + weight[nearest[k]]
               }
               zij = zij / (total_weight)

               var bounds = [[yij-(yd/2),xij-(xd/2)],[yij+(yd/2),xij+(xd/2)]];
               var color = ""

               if (zij > 300){
     color = "#800000"
               } else if (zij > 200) {
     color = "#800080"
               } else if (zij > 150) {
     color = "#FF0000"
               } else if (zij > 100) {
     color = "#FFA500"
               } else if (zij > 50) {
     color = "#ffff00"
               } else if (zij > 0){
     color = "#008000"
               } else {
     color = "#808080"
               }

                aqheatmapshapes.push( L.rectangle(bounds, {color: color, stroke: false, fillOpacity: 0.25 }).bindPopup("Estimated AQI: " + zij.toString()) )
                
             }
          }
          for(var i=0; i < aqheatmapshapes.length; i++)
          {
            aqheatmapshapes[i].addTo(aqheatmaplayer)
          }
          if(aqheatmap)
          {
            aqheatmaplayer.addTo(map)
          }
          updatedtime = currentTime
          // stop_loading()
      })
  }

  function formatForecastDetails(data){
    var html = "";
    $.each(data, function(n, item){
      html += "<div class='alert' style='margin-bottom:10px; padding: 5px; background-color:"+item.aqi_cat.color+"; color:"+item.aqi_cat.font+"'>";
      html += "<strong>AQI category "+item.Category.Name.toLowerCase()+ " forecasted for "+item.ParameterName+" on "+item.DateForecast+" in/around "+item.ReportingArea+"</strong>";
      html += "</div> ";
    });

    if (html === ""){
      html = "<div class='alert alert-info'>AirNowAPI.org doesnt have any AQI forecasts within 50 miles of the map center. Try panning to a different area.</div>";
    }
    $("#home-map-aqis-container").html(html);
  }

  function onEachFeature(feature, layer) {
    var item = feature.properties;
    layer.ref = {type: item.type, id: item.id};
    if (item.type === "aqe"){
      onEachEggFeature(item,layer);
    }
    else if (item.type === "aqs"){
      var html = "";
      if ( item.agency_name === "ManyLabs" ) {
        layer.setIcon(aqsIcon_o);
        html += "<div><h4>ManyLabs AQS Site Details</h4><table class='table table-striped' data-aqs_id='"+item.aqs_id+"'>";
      } else {
        layer.setIcon(aqsIcon);
        html += "<div><h4>AirNow AQS Site Details</h4><table class='table table-striped' data-aqs_id='"+item.aqs_id+"'>";
      }
      html += "<tr><td>Site</td><td> <a href='/aqs/" + item.aqs_id + "'><strong>" + item.site_name+" / "+item.aqs_id+"</strong></a></td></tr>";
      html += "<tr><td>Agency</td><td>" + item.agency_name + "</td></tr>";
      html += "<tr><td>Position</td><td> " + item.elevation + " elevation</td></tr>";
      if (item.msa_name) {
        html += "<tr><td>MSA</td><td> " + item.msa_name + "</td></tr>";
      }
      if (item.cmsa_name) {
        html += "<tr><td>CMSA</td><td> " + item.cmsa_name + "</td></tr>";
      }
      html += "<tr><td>County</td><td>" + item.county_name + "</td></tr>";
      html += "<tr><td>Status</td><td>" + item.status + "</td></tr>";
      html += "</table>";
      html += "<div id='aqs_" + item.aqs_id + "'></div>";
      html += "<p style='text-align: right'><a href='/aqs/" + item.aqs_id + "'>More about this AQS site including historical graphs →</a></p>";
      html += "</div>";
      layer.bindPopup(html);
      layer.on('click', onAQSSiteMapMarkerClick);
    } else if (item.type === "jeffschools") {
      layer.setIcon(schoolIcon);
      var html = "<div><h4>School Details</h4>";
      html += "<table class='table table-striped' data-school_id='" + item.NCESSchoolID+"'>";
      html += "<tr><td>School Name </td><td>" + item.SchoolName + " </td></tr>";
      html += "<tr><td>Grades </td><td>" + item.LowGrade + " through " + item.HighGrade + " </td></tr>";
      html += "<tr><td>Phone # </td><td>" + item.Phone + " </td></tr>";
      html += "<tr><td># Students </td><td>" + item["Students*"] + " </td></tr>";
      html += "<tr><td>Student-Teacher Ratio </td><td>" + item["StudentTeacherRatio*"] + " </td></tr>";
      html += "<tr><td>Title I School (Wide)? </td><td>" + item["TitleISchool*"] + " (" + item["Title1SchoolWide*"]+") </td></tr>";
      html += "<tr><td>Magnet School? </td><td>" + item["Magnet*"] + " </td></tr>";
      html += "<tr><td>School District </td><td>" + item.District + " </td></tr>";
      html += "<tr><td>NCES School ID </td><td>" + item.NCESDistrictID + " </td></tr>";
      html += "<tr><td>State School ID </td><td>" + item.StateSchoolID + " </td></tr>";
      html += "</table>"; // <hr />"
      html += "<p style='font-size:80%'>From CCD public school data 2011-2012, 2011-2012 school years. To download full CCD datasets, please go to <a href='http://nces.ed.gov/ccd' target='blank'>the CCD home page</a>.";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "propaqe") {
      layer.setIcon(L.divIcon({
        className: 'leaflet-div-icon leaflet-div-icon-propaqe', html:item.group_code
      }));
      var html = "<div><h4>Proposed Egg Location Details</h4>";
      html += "<table class='table table-striped' data-object_id='" + item.object_id  + "'>";
      html += "<tr><td>Object ID</td><td>" + item.object_id + " </td></tr>";
      html += "<tr><td>Group Code </td><td>" + item.group_code + "</td></tr>";
      html += "<tr><td>Coordinates </td><td>" + item.lat+", " + item.lon+"</td></tr>";
      html += "</table>";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "bike") {
      layer.setIcon(L.divIcon({className: 'leaflet-div-icon leaflet-div-icon-bike', html:item.bike_id}));
      var html = "<div><h4>Bike Sensor Details</h4>";
      html += "<table class='table table-striped' data-bike_id='" + item.bike_id + "'>";
      html += "<tr><td>Bike ID</td><td>" + item.bike_id + " </td></tr>";
      html += "<tr><td>Time</td><td>" + item.datetime + " </td></tr>";
      html += "<tr><td>Sensor </td><td>" + item.parameter + "</td></tr>";
      html += "<tr><td>Value </td><td>" + item.value + "</td></tr>";
      html += "<tr><td>Units </td><td>" + item.unit + "</td></tr>";
      if(item.computed_aqi) {
        html += "<tr><td>Computed AQI </td><td>" + item.computed_aqi + "</td></tr>";
      }
      html += "<tr><td>Coordinates </td><td>" + item.lat + ", " + item.lon+"</td></tr>";
      html += "</table>";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "parks") {
      layer.setIcon(parkIcon);
      var html = "<div><h4>Park Details</h4>";
      html += "<table class='table table-striped' data-parks_id='" + item.ParkKey + "'>";
      html += "<tr><td>Park Key</td><td>" + item.ParkKey + " </td></tr>";
      html += "<tr><td>Name</td><td><a href='" + item.Url + "' target='blank'>" + item.DisplayName + "</a> </td></tr>";
      html += "<tr><td>Amenities</td><td>" + item.Amenities.join("<br />") + " </td></tr>";
      html += "<tr><td>Telephone</td><td>" + item.Telephone + " </td></tr>";
      html += "<tr><td>Address</td><td>" + item.StreetAddr + " </td></tr>";
      html += "<tr><td>City</td><td>" + item.City + " </td></tr>";
      html += "<tr><td>State</td><td>" + item.State + " </td></tr>";
      html += "<tr><td>Zip</td><td>" + item.ZipCode + " </td></tr>";
      html += "</table>";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "food") {
      layer.setIcon(foodIcon);
      var html = "<div><h4>Inspected Establishment Details</h4>";
      html += "<table class='table table-striped' data-food_id='" + item.EstablishmentID + "'>";
      html += "<tr><td>Establishment ID</td><td>" + item.EstablishmentID + " </td></tr>";
      html += "<tr><td>Name</td><td>" + item.EstablishmentName + "</a> </td></tr>";
      html += "<tr><td>Inspection Scores</td><td>" + item.Inspections.join("<br />") + " </td></tr>";
      html += "<tr><td>Address</td><td>" + item.Address + " </td></tr>";
      html += "<tr><td>City</td><td>" + item.City + " </td></tr>";
      html += "<tr><td>State</td><td>" + item.State + " </td></tr>";
      html += "<tr><td>Zip</td><td>" + item.Zip + " </td></tr>";
      html += "</table>" ;
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "famallergy") {
      layer.setIcon(famallergyIcon);
      var html = "<div><h4>Family Allergy & Asthma Observation</h4>";
      html += "<table class='table table-striped' data-famallergy_id='" + item.id+"'>";
      html += "<tr><td>Site Name</td><td>" + item.name + " </td></tr>";
      html += "<tr><td>Site Adddress</td><td>" + item.address + " </td></tr>";
      html += "<tr><td>Site Lat, Lon</td><td>" + item.lat + ", " + item.lon + " </td></tr>";
      html += "<tr><td>Latest Pollen Counts</td><td>" + moment(item.datetime+"Z").fromNow();
      html += "<br /><strong>Tree:</strong> " + item.trees;
      html += "<br /><strong>Weeds:</strong> " + item.weeds;
      html += "<br /><strong>Grass:</strong> " + item.grass;
      html += "<br /><strong>Mold:</strong> " + item.mold + " </td></tr>";
      html += "</table>";
      html += "<p style='font-size:80%'>From <a href='http://www.familyallergy.com/' target='blank'>Family Allergy and Asthma</a> (a group of board-certified allergy and asthma specialists practicing at more than 20 locations throughout Kentucky and Southern Indiana)";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "nursinghome") {
      layer.setIcon(nursinghomeIcon);
      var html = "<div><h4>" + item.provider_name + "</h4>";
      html += "<table class='table table-striped' data-nursinghome_id='" + item.id + "'>";
      html += "<tr><td>Legal Business Name</td><td>" + item.legal_business_name + " </td></tr>";
      html += "<tr><td>Federal Provider #</td><td><a href='http://www.medicare.gov/nursinghomecompare/profile.html#profTab=0&ID=" + item.federal_provider_number + "' target='blank'>" + item.federal_provider_number + "</a></td></tr>";
      html += "<tr><td>Provider Address</td><td>" + item.provider_name + " </td></tr>";
      html += "<tr><td>Provider City, State, Zip</td><td>" + item.provider_city + ", " + item.provider_state + " " + item.provider_zip_code + " </td></tr>";
      html += "<tr><td>Provider County Name</td><td>" + item.provider_county_name + " </td></tr>";
      html += "<tr><td>Provider Phone</td><td>" + item.provider_phone_number + " </td></tr>";
      html += "<tr><td>Ownership Type</td><td>" + item.ownership_type + " </td></tr>";
      html += "<tr><td>Provider Type</td><td>" + item.provider_type + " </td></tr>";
      html += "<tr><td>Ratings</td><td>";
      html += "<strong>Staffing:</strong> " + item.staffing_rating + "/5";
      html += "<br /><strong>RN Staffing:</strong> " + item.rn_staffing_rating + "/5";
      html += "<br /><strong>Quality Measure:</strong> " + item.qm_rating + "/5";
      html += "<br /><strong>Health Inspection:</strong> " + item.health_inspection_rating + "/5";
      html += "</td></tr>";
      html += "<tr><td>Total Weighted Health Survey Score</td><td>" + item.total_weighted_health_survey_score + " </td></tr>";
      html += "<tr><td>Total # of Penalties</td><td>" + item.total_number_of_penalties + " </td></tr>";
      html += "<tr><td># of Facility Reported Incidents</td><td>" + item.number_of_facility_reported_incidents + " </td></tr>";
      html += "<tr><td># of Certified Beds</td><td>" + item.number_of_certified_beds + " </td></tr>";
      html += "</table>";
      html += "<p style='font-size:80%'>From <a href='https://data.medicare.gov/data/nursing-home-compare' target='blank'>CMS Nursing Home Compare</a>. This provider was last processed " + moment(item.processing_date).fromNow() + " on " + moment(item.processing_date).calendar() + ".";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "wupws") {
      layer.setIcon(weatherStationIcon);
      var html = "<div><h4>" + item.id + "</h4>";
      html += "<table class='table table-striped' data-wupws_id='" + item.id + "'>";
      html += "<tr><td>Neighborhood</td><td>" + item.neighborhood + " </td></tr>";
      html += "<tr><td>City</td><td>" + item.city + " </td></tr>";
      html += "<tr><td>Time Zone</td><td>" + item.tz_short + " </td></tr>";
      html += "<tr><td>Station Equipment</td><td>" + item.station_type + " </td></tr>";
      html += "<tr><td>Lat, Lon</td><td>" + item.lat + ", " + item.lon + " </td></tr>";
      html += "</table>";
      html += "<p style='text-align: right'><a target='blank' href='" + item.wuiurl + "?apiref=8839d23d1235ce5f'>More about this weather station including historical graphs →</a></p>";
      html += "<p style='font-size:80%'>From <a href='http://www.wunderground.com/?apiref=8839d23d1235ce5f' target='blank' title='weather underground'><img src='/assets/img/wunderground.jpg'></a>.";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "he2014neighborhoodgeojson") {
      var itemarr = {
        "LifeExpect":"<tr><td>Life Expectancy</td><td>" + item.LifeExpect + " </td></tr>",
        "AlcoholDru":"<tr><td>Alcohol or other drugs*</td><td>" + item.AlcoholDru + " </td></tr>",
        "HeartDisea":"<tr><td>Heart Disease*</td><td>" + item.HeartDisea + " </td></tr>",
        "Homicide":"<tr><td>Homicide*</td><td>" + item.Homicide + " </td></tr>",
        "Suicide":"<tr><td>Suicide*</td><td>" + item.Suicide + " </td></tr>",
        "HIV":"<tr><td>HIV*</td><td>" + item.HIV + " </td></tr>",
        "Diabetes":"<tr><td>Diabetes*</td><td>" + item.Diabetes + " </td></tr>",
        "Unintended":"<tr><td>Unintentional Injury*</td><td>" + item.Unintended + " </td></tr>",
        "Cancer":"<tr><td>Cancer*</td><td>" + item.Cancer + " </td></tr>",
        "Stroke":"<tr><td>Stroke*</td><td>" + item.Stroke + " </td></tr>"
      };
      var html = "<div><h4>" + item.Neighbor + " Neighborhood</h4>";
      html += "<table class='table table-striped' data-he2014neighborhoodgeojson_id='" + item.OBJECTID + "'>";
      for (var index in added) {
        html += itemarr[added[index][0]];
      }
      html += "</table>" ;
      html += "<p>* Age Adjusted death rate per 100,000 population</p>";
      html += "<p style='font-size:80%'>From <a href='http://www.louisvilleky.gov/health/equity/' target='blank'>Louisville, KY Health Equity Report 2014 edition (updated July 2014)</a>.";
      html += "</div>";

      if (added.length === 1) {
        var label = new L.Label();
        label.setContent((Math.floor( layer.feature.properties[added[0][0]] * 100) / 100).toString());
        label.setLatLng(L.polygon( layer._latlngs ).getBounds().getCenter());
        map.showLabel(label);
        all_labels.push( label );
      } else {
        layer.bindPopup(html);
      }
    } else if (item.type === "trafficcountsgeojson") {
      var html = "<div><h4>Traffic Flow Information for Route #" + item.RT_NE_UNIQ + "</h4>";
      html += "<table class='table table-striped'>";
      html += "<tr><td>Traffic Count Station ID</td><td>" + item.ADTSTATN + " (<a href='http://datamart.business.transportation.ky.gov/EDSB_SOLUTIONS/CTS/stationdetail.aspx?STATION=" + item.ADTSTATN + "' target='blank'>history</a>)</td></tr>";
      html += "<tr><td>Begin Point Description @ Milepost</td><td>" + item.BEGDESC + " @ MP " + item.BEGIN_MP + " </td></tr>";
      html += "<tr><td>End Point Description @ Milepost</td><td>" + item.ENDDESC + " @ MP " + item.END_MP + " </td></tr>";
      html += "<tr><td>Last Actual AADT Count</td><td>" + item.LASTCNT + " </td></tr>";
      html += "<tr><td>Year of Last Actual ADT Count</td><td>" + item.LASTCNTYR + " </td></tr>";
      html += "<tr><td>K Factor</td><td>" + item.K_FACTOR + " </td></tr>";
      html += "<tr><td>D Factor</td><td>" + item.D_FACTOR + " </td></tr>";
      html += "<tr><td>% Combination Trucks (Peak)</td><td>" + item.PCCOMBOP + " (" + item.PCCOMBPK + ") </td></tr>";
      html += "<tr><td>% Single Unit Trucks (Peak)</td><td>" + item.PCSINGOP + " (" + item.PCSINGPK+") </td></tr>";
      html += "</table>";
      html += "<p><ul><li>ADT = Average Daily Traffic</li><li>AADT = Annual Average Daily Traffic</li><li>K Factor = peak hour volume as a percentage of the AADT</li><li>D Factor = percentage of peak hour volume flowing in the peak direction</li></ul></p>";
      html += "<p style='font-size:80%'>From <a href='http://datamart.business.transportation.ky.gov' target='blank'>KY Transportation Cabinet</a> datamart 'Traffic Flow' spatial data.";
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "waste") {
      layer.setIcon(wasteIcon);
      var html = "<div><h4>" + item.Name + "</h4>";
      if (item.Summary === "") {
        html += "No summary is available at this time";
      } else {
        html += "<table class='table table-striped'>";
        html += "<tr><td>Summary</td><td>" + item.Summary + "</td></tr>";
        html += "</table>";
      }
      html += "</div>";
      layer.bindPopup(html);
    } else if (item.type === "usgsw") {
      layer.setIcon(wasteIcon);
      var html = "YO!";
      layer.bindPopup(html);
    } else if (item.type === "louisville-landfill-data") {
      layer.setIcon(wasteIcon);
    } else {
      if (item.type) {
        var html = "<div><h4>" + item.type.toUpperCase() + " ID #" + item.id + "</h4></div>";
        layer.bindPopup(html);
      }
    }
  }

  function filterFeatures(feature, layer) {
    var item = feature.properties;
    var show = true;

    if (item.type === "aqe") {
      // AQE indoor/outdoor ===========
      if (filter_selections["outdoor-eggs"] === "true" && item.location_exposure === "outdoor") {
        show = true;
      } else if (filter_selections["indoor-eggs"] === "true" && item.location_exposure === "indoor") {
        show = true;
      } else {
        show = false;
      }

      // AQE time basis ===============
      if (item.last_datapoint) {
        var last_datapoint = new Date(item.last_datapoint+"Z");
      } else {
        var last_datapoint = new Date(0,0,0);
      }

      if (show === true && filter_selections["last-datapoint-not-within-168-hours"] === "true") {
        var x_hours_ago = new Date().setHours(loaded_at.getHours()-168);
        if (last_datapoint >= x_hours_ago) {
          show = false;
        } else {
          show = true;
        }
      }

      if (show === true && filter_selections["last-datapoint-within-168-hours"] === "true") {
        var x_hours_ago = new Date().setHours(loaded_at.getHours()-168);
        if (last_datapoint >= x_hours_ago){
          show = true;
        }
        else {
          show = false;
        }
      }
      if (show === true && filter_selections["last-datapoint-within-24-hours"] === "true") {
        var x_hours_ago = new Date().setHours(loaded_at.getHours()-24);
        if (last_datapoint >= x_hours_ago){
          show = true;
        } else {
          show = false;
        }
      }
      if (show === true && filter_selections["last-datapoint-within-6-hours"] === "true") {
        var x_hours_ago = new Date().setHours(loaded_at.getHours()-6);
        if (last_datapoint >= x_hours_ago){
          show = true;
        } else {
          show = false;
        }
      }

      if(filter_selections["last-datapoint-within-6-hours"] === "true" &&
          filter_selections["last-datapoint-within-24-hours"] === "true" &&
          filter_selections["last-datapoint-within-168-hours"] === "true" &&
          filter_selections["last-datapoint-not-within-168-hours"] === "true") {
        show = true;
      }

    } else if (item.type === "aqs" && item.agency_name === "ManyLabs") {
      if (filter_selections["airbare"] === "true" && item.status === "Active") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "aqs") {
      if (filter_selections["epa"] === "true" && item.status === "Active") {
        show = true;
      } else {
        show = false;
      }

    } else if (item.type === "jeffschools") {
      if (filter_selections["jeffschools"] === "true" && item.District === "JEFFERSONCOUNTY") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "nursinghome") {
      if (filter_selections["nursinghome"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "wupws") {
      if (filter_selections["wupws"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "famallergy") {
      if (filter_selections["famallergy"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "parks") {
      if (filter_selections["parks"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "food") {
      if (filter_selections["food"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "propaqe") {
      if (filter_selections["propaqe-group-1"] === "true" && item.group_code === "1") {
        show = true;
      } else if (filter_selections["propaqe-group-2"] === "true" && item.group_code === "2") {
        show = true;
      } else if (filter_selections["propaqe-group-3"] === "true" && item.group_code === "3") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "bike" &&
        filter_selections["bike-bike_id"] !== "" &&
        filter_selections["bike-parameter" !== ""]) {
      if (filter_selections["bike-bike_id"] === item.bike_id &&
          filter_selections["bike-parameter"] === item.parameter) {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "he2014neighborhoodgeojson") {
      if (filter_selections["he2014neighborhoodgeojson"] === true) {
        show = true;
      } else {
        show = false;
      }
    } else if(item.type === "trafficcountsgeojson") {
      if (filter_selections["trafficcountsgeojson"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "waste") {
      if (filter_selections["waste"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "usgsw") {
      if (filter_selections["usgsw"] === "true") {
        show = true;
      } else {
        show = false;
      }
    } else if (item.type === "louisville-landfill-data") {
      if (filter_selections["louisville-landfill-data"] === "true") {
        show = true;
      } else {
        show = false;
      }
    }
    return show;
  }

  function update_filters(){
    // set filter selections to be used by filterFeatures
    // aqheatpmap
    aqheatmap = $('input.aq-heatmap:checked').val();
    // aqe specific
    filter_selections["indoor-eggs"] = $('input.filter-indoor-eggs:checked').val();
    filter_selections["outdoor-eggs"] = $('input.filter-outdoor-eggs:checked').val();
    filter_selections["last-datapoint-within-6-hours"] = $('input.filter-last-datapoint-within-6-hours:checked').val();
    filter_selections["last-datapoint-within-24-hours"] = $('input.filter-last-datapoint-within-24-hours:checked').val();
    filter_selections["last-datapoint-within-168-hours"] = $('input.filter-last-datapoint-within-168-hours:checked').val();
    filter_selections["last-datapoint-not-within-168-hours"] = $('input.filter-last-datapoint-not-within-168-hours:checked').val();
    // propaqe
    filter_selections["propaqe-group-1"] = $('input.filter-propaqe-group-1:checked').val();
    filter_selections["propaqe-group-2"] = $('input.filter-propaqe-group-2:checked').val();
    filter_selections["propaqe-group-3"] = $('input.filter-propaqe-group-3:checked').val();
    //waste
    filter_selections['waste'] = $('input.filter-waste:checked').val();
    //usgsw
    filter_selections['usgsw'] = $('input.filter-usgsw:checked').val();
    // aqs specific
    filter_selections["epa"] = $('input.filter-active-sites-epa:checked').val();
    filter_selections["airbare"] = $('input.filter-active-sites-airbare:checked').val();
    // jeffschools specific
    filter_selections["jeffschools"] = $('input.filter-jeffschools:checked').val();
    // nursing home specific
    filter_selections["nursinghome"] = $('input.filter-nursinghome:checked').val();
    // weather station (wupws) specific 
    filter_selections["wupws"] = $('input.filter-wupws:checked').val();
    // famallergy specific
    filter_selections["famallergy"] = $('input.filter-famallergy:checked').val();
    // portal.louisvilleky.gov
    filter_selections["food"] = $('input.filter-food:checked').val();
    filter_selections["parks"] = $('input.filter-parks:checked').val();
    // durham labs
    filter_selections["bike-bike_id"] = $('select.filter-bike-bike_id').val();
    filter_selections["bike-parameter"] = $('select.filter-bike-parameter').val();

    if (filter_selections["bike-bike_id"] !== "" && filter_selections["bike-parameter"] !== ""){
      filter_selections["bike"] = true;
    } else {
      filter_selections["bike"] = false;
    }

    // health equity report 2014
    filter_selections["he2014neighborhoodgeojson"] = false;
    filter_selections["he2014neighborhoodgeojson_colorBy"] = [];

    if ($('input.filter-he2014neighborhoodgeojson').is(":checked")) {
      filter_selections["he2014neighborhoodgeojson"] = true;
      var inparr = [
        [ "LifeExpect", true ],
        ["AlcoholDru", false],
        ["HeartDisea", false],
        ["Homicide", false],
        ["Suicide", false],
        ["HIV", false],
        ["Diabetes", false],
        ["Unintended", false],
        ["Cancer", false],
        ["Stroke", false]
      ];
      for (var i in inparr) {
        if ($("input.filter-he2014neighborhoodgeojson-" + inparr[i][0]).is(":checked"))
          filter_selections["he2014neighborhoodgeojson_colorBy"].push(inparr[i]);
      }
    }
    // traffic counts
    filter_selections["trafficcountsgeojson"] = $('input.filter-trafficcountsgeojson:checked').val();
    filter_selections["trafficcountsgeojson_colorBy"] = $('select.filter-trafficcountsgeojson-colorBy').val();
    filter_selections["trafficcountsgeojson_higherBetter"] = $('select.filter-trafficcountsgeojson-colorBy option:selected').data("higherbetter");

    // landfills
    filter_selections["louisville-landfill-data"] = true;
  }

  function update_map(key){
    if (key === "he2014neighborhoodgeojson"){
      for (var i in added) {
        map.removeLayer(geoJsonLayers[key + "." + added[i][0]]);
      }
      for(i in all_labels) {
        all_labels[i].close();
        //console.log( all_labels[i] );
      } try {
        map.removeControl(legend);
      } catch(e) {

      } //remove legend
    }

    if (typeof(geoJsonLayers[key]) !== "undefined"){
      map.removeLayer(geoJsonLayers[key]);  // remove layer's markers
    }
    update_filters();

    // special for geojson polygon and line layers -- TODO refactor!
    if (key === "he2014neighborhoodgeojson" &&
        filter_selections["he2014neighborhoodgeojson"] === "true" &&
        filter_selections["he2014neighborhoodgeojson_colorBy"] !== undefined) {
      var array_of_values = layersData[key].features.map(function(i) {
        return i.properties[filter_selections["he2014neighborhoodgeojson_colorBy"]];
      });
      var s1 = new Stats().push(array_of_values);
      breakpoints = [s1.percentile(80), s1.percentile(60), s1.percentile(40), s1.percentile(20), s1.percentile(0)];
    } else if (key === "trafficcountsgeojson" &&
        filter_selections["trafficcountsgeojson"] === "true" &&
        filter_selections["trafficcountsgeojson_colorBy"] !== undefined) {
      var array_of_values = layersData[key].features.map(function(i) {
        var value = i.properties[filter_selections["trafficcountsgeojson_colorBy"]];
        if (value !== 0 && value !== undefined) {
          return value;
        }
      });
      var s1 = new Stats().push(array_of_values);
      if (filter_selections["trafficcountsgeojson_colorBy"] === "LASTCNTYR") {
        var this_year = new Date().getUTCFullYear();
          breakpoints = [this_year, this_year-1, this_year-3, this_year-5];
      } else {
        breakpoints = [s1.percentile(80), s1.percentile(60), s1.percentile(40), s1.percentile(20), s1.percentile(0)];
      }
      legend.addTo(map);
    }

    if (key === "he2014neighborhoodgeojson") {
      added = filter_selections["he2014neighborhoodgeojson_colorBy"];
      legend.addTo(map);
      var step = 1 / added.length;

      for (var istr in added) {
        var a = layersData[key].features.map(function(i){
          return i.properties[added[istr][0]];
        });
        var arr_max = a[0];
        var arr_min = a[0];
        for (i in a) {
          if (arr_min > a[i])
            arr_min = a[i];
          if (arr_max < a[i])
            arr_max = a[i];
        }

        var i = parseInt(istr);
        var tsc = $.extend(true, {}, layersData[key]);

        /*
        if( i < added.length - 1 )
        for( var j in tsc['features'] ) {
        var original_shape = tsc['features'][j]['geometry']['coordinates'][0];
        tsc['features'][j]['geometry']['coordinates'] = [
        shrinkshape( original_shape, 1 - step * i ),
        shrinkshape( original_shape, 1 - step * (i+1) )
        ];
        }
        else
        for( var j in tsc['features'] ) {
        var original_shape = tsc['features'][j]['geometry']['coordinates'][0];
        tsc['features'][j]['geometry']['coordinates'] = [
        shrinkshape( original_shape, 1 - step * i )
        ];
        }
        */

        geoJsonLayers[key + "." + added[istr][0]] = L.geoJson(tsc, {
          onEachFeature: onEachFeature,
          filter: filterFeatures,
          style: (function(colorBy) {
            return function(feature) {
              var style = {};
              style.fillColor = "url(#" + mypatterns[parseInt(istr)] + ")";
              style.weight = 4;
                //console.log
                style.fillOpacity = (feature.properties[colorBy[0]] - arr_min) / (arr_max - arr_min);

                if (colorBy[1] === true)
                  style.fillOpacity = 1 - style.fillOpacity;

                //console.log( style.fillOpacity );
                style.fillOpacity = 2 * Math.floor(10 * style.fillOpacity / 2) / 10;
                //console.log( style.fillOpacity );
                // style.color = 'white'
                style.color = 'black';
                style.dashArray = '3';
                return style;
            };
          })(added[istr])
        }).addTo(map);
      }
    } else {
      geoJsonLayers[key] = L.geoJson(layersData[key], {
        onEachFeature: onEachFeature,
        filter: filterFeatures,
        style: geoJsonStyle
      }).addTo(map);
    }
    breakpoints = []; // reset breakpoints to null
  }

  function shrinkshape(arr, byhowmuch) {
    var newarr = [];
    var totx = 0;
    var cntx = 0;
    var toty = 0;
    var cnty = 0;

    for (var k in arr) {
      totx += arr[k][0];
      cntx += 1;
      toty += arr[k][1];
      cnty += 1;
    }

    var avgx = totx / cntx;
    var avgy = toty / cnty;

    for (var k in arr) {
      var ox = arr[k][0];
      var oy = arr[k][1];

      newarr.push([avgx + (ox - avgx)*byhowmuch, avgy + (oy - avgy)*byhowmuch]);
    }

    return newarr;
  }

  function getDisplayValueByBreakpoint(value, displayValues) {
    return value >= breakpoints[0] ? displayValues[0]:
      value >= breakpoints[1] ? displayValues[1]:
      value >= breakpoints[2] ? displayValues[2]:
      value >= breakpoints[3] ? displayValues[3]:
      displayValues[4];
  }

  var counter = 1;

  function geoJsonStyle(feature) {
    // console.log(feature);
    var style = {className: 'type-' + feature.properties.type};
    if (filter_selections["he2014neighborhoodgeojson"] === "true" && breakpoints.length !== 0) {
      if (filter_selections["he2014neighborhoodgeojson_higherBetter"] === true){
        var colorsArray = breakpointColorsHigherIsBetterByLachel;
      } else {
        var colorsArray = breakpointColorsHigherIsBetterByLachel;
      }
      var codedColor = getDisplayValueByBreakpoint(feature.properties[filter_selections["he2014neighborhoodgeojson_colorBy"]], colorsArray);
      style.weight = 2;
      style.opacity = 1;
      style.color = '#000';
      style.fillOpacity = 1;
      style.className = style.className + ' svgCrossHatch-' + codedColor.replace('#', '');
    } else if (filter_selections["trafficcountsgeojson"] === "true" && breakpoints.length !== 0) {
      if (filter_selections["trafficcountsgeojson_colorBy"] === "LASTCNT") {
        style.color = '#333';
        style.opacity = 0.8;
        style.weight = getDisplayValueByBreakpoint(feature.properties[filter_selections["trafficcountsgeojson_colorBy"]], breakpointWidthHigherIsBetter);
      } else if (filter_selections["trafficcountsgeojson_colorBy"] === "LASTCNTYR") {
        style.color = getDisplayValueByBreakpoint(feature.properties[filter_selections["trafficcountsgeojson_colorBy"]], breakpointColorsHigherIsBetter);
      }
    }
    return style;

    var style = {};
    counter += 1;
    if (counter === 4) counter = 1;
    var mynewarray = ['0', '1', '2', '3', '4'];
    mynewarray = mynewarray.map(function(a) {
      return 'url(#img' + a + ')';
          });
      style.fillColor = getDisplayValueByBreakpoint(feature.properties[filter_selections["he2014neighborhoodgeojson_colorBy"]], mynewarray);
      style.fillOpacity = 1;
      style.color = 'white';
      return style;
      }

      function onAQSSiteMapMarkerClick(e) {
        var aqs_id = $(".leaflet-popup-content .table").first().data("aqs_id");
        if (typeof(ga) !== "undefined") {
          ga('send', 'event', 'aqs_' + aqs_id, 'click', 'aqs_on_map', 1);
        }

        $.getJSON("/aqs/"+aqs_id+".json", function(data){
          var html = formatSensorDetails(data);
          $("#aqs_"+aqs_id).append(html);
        });
      }

      function graphEggHistoricalData(){
        // create skeleton chart
        $.getJSON(location.pathname+".json?include_recent_history=1", function(data) {
          var recent_history = $.map(data.datastreams, function(data2, name){
            return {data: data2.recent_history, name: name+" ("+data2.unit+")"};
          });

          // console.log(recent_history)

          $.each(recent_history, function(i, series) {
            if (series.name.match(/ppb/gi)) {
              series.yAxis = 0;
            } else {
              series.yAxis = 1;
            }
          });

          $('#dashboard-egg-chart').highcharts({
            chart: {
              type: 'spline',
              zoomType: 'xy',
            },
            credits: { enabled: false },
            title: { text: "This Egg's Datastreams" },
            xAxis: { type: 'datetime' },
            yAxis: [
              {title:
                {text: 'ppb (parts per billion)'},
                min: 0
              },
              { title:
                {text: ''},
                min: 0,
                opposite: true
              }
            ],
            tooltip: {
              formatter: function(){
                var time = moment(this.x);
                var series_label = this.series.name.replace(/ \(.+\)/g,"");
                var series_unit = this.series.name.replace(/.+\ \((.+)\)/,"$1");
                return ''+time.format("MMM D, YYYY [at] h:mm a ([GMT] Z)")+' ('+time.fromNow()+')<br />'+'<b>'+ series_label +':</b> '+this.y+' '+series_unit;
              }
            },
            series: recent_history
          });
        });
      }

      function graphAQSHistoricalData(){
        // create skeleton chart
        $.getJSON(location.pathname+".json?include_recent_history=1", function(data) {
          var recent_history = $.map(data.datastreams,function(data2,name){
            return {data: data2.recent_history, name: name+" ("+data2.unit+")"};
          });
          $.each(recent_history, function(i,series) {
            if (series.name.match(/ppb/gi)) {
              series.yAxis = 0;
            } else {
              series.yAxis = 1;
            }
          });

          $('#dashboard-aqs-chart').highcharts({
            chart: {
              type: 'spline',
              zoomType: 'xy',
            },
            credits: { enabled: false },
            title: { text: "This AQS Site's Datastreams" },
            xAxis: { type: 'datetime' },
            yAxis: [
              {title:
                {text: 'ppb (parts per billion)'},
                min: 0
              },
              {title:
                {text: ''},
                min: 0,
                opposite: true
              }
            ],
            tooltip: {
              formatter: function() {
                var time = moment(this.x);
                var series_label = this.series.name.replace(/ \(.+\)/g,"");
                var series_unit = this.series.name.replace(/.+\ \((.+)\)/,"$1");
                return ''+time.format("MMM D, YYYY [at] h:mm a ([GMT] Z)")+' ('+time.fromNow()+')<br />'+'<b>'+ series_label +':</b> '+this.y+' '+series_unit;
              }
            },
            series: recent_history
          });
        });
      }

      function handleMapLegend(){
        var controlContainer = $(map._controlContainer);
        // remove legend altogether
        if (controlContainer.find("#legend").length > 0) {
          map.removeControl(legend);
        }
        // add legend if it part of a group that has a legend
        if(controlContainer.find("div:contains('Census Data') input:checked").length > 0) {
          legend.addTo(map);
        }
      }

      function authenticateAndLoadAsthmaHeatLayer(username,password){
        if (username !== "" && password !== "" ) {
          $.post('/asthmaheat', {username: username, password: password}).done(function(data) {
            var propellerhealth_layer_url = data;
            var propellerhealth_layer_bounds = [[37.8419378866983038, -86.0292621133016979], [38.5821425225734487, -85.1883896469475275]];
            var propellerhealth_layer = L.layerGroup([L.imageOverlay(propellerhealth_layer_url, propellerhealth_layer_bounds, {
              opacity: 0.8,
              attribution: "Asthma hotspot heatmap from <a href='http://propellerhealth.com' target=blank>Propeller Health</a>"
            })
            ]);
            map.addLayer(propellerhealth_layer);
          });
        }
      }

      function choose_post_data(key){
        var post_data = {};
        if (key === "bike"){ // BIKE HACK
          post_data['bike_id'] = filter_selections["bike-bike_id"];
          post_data['parameter'] = filter_selections["bike-parameter"];
        }
        return post_data;
      }

      function compareFeatures(e){
        if (typeof(drawn) !== "undefined"){map.removeLayer(drawn);} // remove previously drawn item
        in_bounds = {}; // reset in_bounds away
        var type = e.layerType;
        var layer = e.layer;
        drawn = layer;

        $.each(Object.keys(geoJsonLayers), function(n,type){
          $.each(geoJsonLayers[type].getLayers(), function(n,item){
            var layer_in_bounds = drawn.getBounds().contains(item.getLatLng());
            if (layer_in_bounds){
              if (typeof(in_bounds[item.ref.type]) === "undefined"){
                in_bounds[item.ref.type] = [];
              }
              in_bounds[item.ref.type].push(item.ref.id);
            }
          });
        });

        var form = document.createElement("form");
        form.action = "/compare";
        form.target = "_blank";
        var count = 0;
        $.each(in_bounds, function(type,ids){
          var input = document.createElement("input");
          input.name = type;
          input.value = ids.join(",");
          count += ids.length;
          form.appendChild(input);
        });
        if (count > 100){
          form.method = "post";
        } else {
          form.method = "get";
        }
        // console.log(count,form)
        document.body.appendChild(form);
        form.submit();
        map.addLayer(layer);
      }

      // landfillGeoJson = 
      // var landfillLayer = L.geoJson(land).addTo(map);
      // map.addLayer(landfillLayer);
})(jQuery);
