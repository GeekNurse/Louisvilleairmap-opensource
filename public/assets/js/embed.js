$(function() { 

  $('#embedInstructions').on('show.bs.modal', function (e) {
    $("#embedInstructions pre.embed-snippet").append("\n&lt;iframe src='"+location.origin+location.pathname+"?embed=true"+location.hash+"' style='width:800px; height:600px;'>&lt;/iframe>")
  })

})