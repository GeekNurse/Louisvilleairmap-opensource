// var map;

$(function() {
    Highcharts.setOptions({
        global: {
            timezoneOffset: Math.abs(gmt_offset) * 60
        }
    });


    $(".momentify").each(function(n,item){
      var original = $(item).html()
      var from_now = moment(original).fromNow()
      $(item).html("<abbr title='"+original+"'>"+from_now+"</abbr>")
    })

  $("tr[data-sensor-id]").each(function(n,row){
    var type = $(row).data("sensor-type")
    var id = $(row).data("sensor-id")
    var detail = $(row).data("detail-level")
    var param = $(row).data("sensor-param")
    var site_name = $(row).data("sensor-title")
    $.getJSON("/"+type+"/"+id+"/"+param+"/past_24h_aqi_chart.json", function(chart_data,status){
      $(row).children('td').last().find(".past24chart").highcharts({
        chart: { type: 'column', zoomType: 'x'  },
        credits: { enabled: false },
        legend: { enabled: false },
        title: { text: 'AQI at '+site_name +' (in GMT '+gmt_offset+')', style:{"fontSize": "13px" }},
        xAxis: { type: 'datetime' },
        yAxis: {
          endOnTick: false,
          min: 0,
          max: 180,
          title: {enabled: false},
          
  gridLineWidth: 0,
  minorGridLineWidth: 0,

          plotLines:[
            { value:50, color: '#FFFF00', width:2, dashStyle: 'Dash', zIndex:99},
            { value:99, color: '#FF7E00', width:2, dashStyle: 'Dash', zIndex:99},
            { value:150, color: '#FF0000', width:2, dashStyle: 'Dash', zIndex:99},
          ]
        },
        tooltip: {
          headerFormat: '<span style="font-size:10px">{point.key} (GMT '+gmt_offset+')</span><table>',
          pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
              '<td style="padding:0"><b> {point.y}</b></td></tr>',
          footerFormat: '</table>',
          shared: true,
          useHTML: true
        },
        plotOptions: {
            column: {
                pointPadding: 0.2,
                borderWidth: 0
            }
        },
        series: chart_data
      });
      $(window).resize()
    })
  })

})

  