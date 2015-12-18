var aceEditor, mapView

$(function() { 
  // highly based on rgrp's ckan data explorer
  var ckan = new CKAN.Client(ckan_endpoint)
  var ace_sql_editor;
  var DataView = Backbone.View.extend({
    class: 'data-view',
    initialize: function(options) {
      var self = this;
      // var resource = new Backbone.Model
      this.dataset = new recline.Model.Dataset({
        id: options.resourceId,
        endpoint: ckan_endpoint,
        backend: 'ckan',
        initialSql: options.initialSql,
        isJoin: options.isJoin,
        datasetKeys: options.datasetKeys
      });
      this.dataset.fetch()
        .done(function() {
          self.render();
        });
    },
    render: function() {
      this.view = this._makeMultiView(this.dataset, this.$el.find('.multiview'));

      var dataset = this.dataset

      if(dataset.attributes.isJoin == false){     
        var sqlSamples = $.map(datasets[dataset_key].extras_hash, function(value,key){
          if(key.match("SQL Sample")){
            return {title: dataset_key.toUpperCase()+" "+key, sql: value}
          }
        })
        var resourceFields = $.map(dataset.fields.models, function(field,n){
          return {id: dataset.attributes.datasetKeys[0]+'.'+field.attributes.id, type: field.attributes.type}
        })
      } else {
        var resourceFields = [{id: 'Fields for joins coming soon!', type:''}]
        var sqlSamples = [{title: 'SQL for join', sql: dataset.attributes.initialSql}]
      }

      var datasetMetadata = []
      $.each(dataset.attributes.datasetKeys, function(n, datasetKey){
        var dataset = datasets[datasetKey]
        console.log(dataset)
        var url = ckan_endpoint.replace('/api','/dataset/') + dataset.name
        datasetMetadata.push({html: '<a target="blank" title="'+dataset.title+'" href="'+url+'"><strong>'+dataset.title+'</strong> on the Open Data Portal<i class="fa fa-external-link fa-fw"></i></a>' })
        $.each(["author","maintainer"], function(n,role){
          var role_email = dataset[role+'_email']
          var role_name = dataset[role]
          var role_html = ""
          if(role_email){ role_html += "<a href='mailto:"+role_email+"' title='Email maintainer'>" }
          if(role_name){ role_html += toTitleCase(role) +": " +role_name }
          if(role_email){ role_html += "</a>" }
          if(role_html != ""){ datasetMetadata.push({html: role_html}) }
        })
        datasetMetadata.push({html: 'Description: '+dataset.notes })
        $.each(dataset.extras_hash, function(key,value){
          if(key.match('field_containing_site_') && value != 'NULL'){
            datasetMetadata.push({html: 'Field for '+key.replace('field_containing_site_','')+': '+datasetKey+'.'+value})
          }
        })
      })

      var html = Mustache.render(this.template, {initialSql: dataset.attributes.initialSql, sqlSamples: sqlSamples, resourceFields: resourceFields, datasetMetadata: datasetMetadata});
      this.$el.html(html);
      
      $(".dataset-metadata-container .panel-body").height($(".sql-examples").parent().height()+10)
      this.sqlQuery()
    },

    _makeMultiView: function(dataset, $el) {
      var gridView = {
          id: 'grid',
          label: 'Grid',
          view: new recline.View.SlickGrid({
            model: dataset,
          })
        };
      var graphView = {
        id: 'graph',
        label: 'Graph',
        view: new recline.View.Flot({
          model: dataset
        })
      };
      mapView = {
        id: 'map',
        label: 'Map',
        view: new recline.View.Map({
          model: dataset,
        })
      };

      exportView = {
        id: 'export',
        label: 'Export',
        view: new recline.View.Export({
          model: dataset, // recline dataset
          size: 5 // optional, show only first 5 records in preview (default 10)
        })
      };

      filtersView = {
        id: 'filterEditor',
        label: 'Filters',
        view: new recline.View.FilterEditor({
          model: dataset
        })
      }

      fieldsView = {
        id: 'fieldsView',
        label: 'Fields',
        view: new recline.View.Fields({
          model: dataset
        })
      }

      mapView.view.geoJsonLayerOptions.onEachFeature = function(feature, layer){
        var attributes = view.model.records._byId[feature.properties.cid].attributes
        var aqi = attributes.computed_aqi
        if(aqi){
          var aqi_css_class = aqiToColor(aqi).replace("#","")
          layer.setIcon(L.divIcon({className: 'aqi-bg-'+aqi_css_class+' leaflet-div-icon'}))        
        } else {
          layer.setIcon(L.divIcon({className: 'leaflet-div-icon'}))        
        }
      }

      if(getURLParameterByKey("embed") == "true"){
        var sidebarViews = []
      } else {
        var sidebarViews = [fieldsView,filtersView]
      }
      view = new recline.View.MultiView({
        model: dataset,
        views: [gridView, graphView, mapView, exportView],
        sidebarViews: sidebarViews,
        el: $el,
        disablePager: true,
        disableQueryEditor: true
      });
      return view;
    },

    _onSwitchView: function(e) {
      var viewName = $(e.target).attr('data-view');
      addOrReplacePairInHash("viewName",viewName)
    },

    events: {
      'submit .query-sql': 'sqlQuery',
      'click .navigation a': '_onSwitchView'
    },

    template: ' \
      <div class="row hide-on-embed" style="padding-left: 8px; padding-right: 8px;"> \
        <div class="col-md-8"> \
          <div class="panel panel-default"> \
            <div class="panel-heading"> \
              <h4 class="panel-title">Example SQL Queries</h4> \
            </div> \
            <div class="panel-collapse collapse in"> \
              <div class="panel-body"> \
                <div class="sql-examples"> \
                  <div class="table-responsive"> \
                    <table class="table table-bordered table-striped"> \
                        <thead> \
                          <tr> \
                            <th>Name</th> \
                            <th>SQL</th> \
                          </tr> \
                        </thead> \
                        <tbody> \
                          {{#sqlSamples}} \
                            <tr class="example-query"> \
                                <td class="example-sql-description"><a href="#" data-sql="{{sql}}">{{title}}</a></td> \
                                <td><span style="font-family: monospace">{{sql}}</span></td> \
                            </tr>\
                          {{/sqlSamples}} \
                        </tbody> \
                    </table> \
                  </div> \
                </div> \
              </div> \
            </div> \
          </div> \
        </div> \
        <div class="col-md-4"> \
          <div class="panel panel-default"> \
            <div class="panel-heading"> \
              <h4 class="panel-title">Dataset Metadata</h4> \
            </div> \
            <div class="dataset-metadata-container" class="panel-collapse collapse in"> \
              <div class="panel-body"> \
                <ul class="dataset-metadata"> \
                  {{#datasetMetadata}} \
                    <li>{{{html}}}</li> \
                  {{/datasetMetadata}} \
                </ul> \
                <hr /> \
                <h5>Fields/Columns</h5> \
                <div class="resource-fields" style="overflow:scroll;"> \
                  <div class="table-responsive"> \
                    <table class="table table-bordered table-striped"> \
                      <thead> \
                          <tr> \
                              <th>Name</th> \
                              <th>Type</th> \
                          </tr> \
                      </thead> \
                      <tbody> \
                        {{#resourceFields}}\
                          <tr class="resource-field">\
                              <td>{{id}}</td>\
                              <td>{{type}}</span></td>\
                          </tr> \
                        {{/resourceFields}} \
                      </tbody> \
                    </table> \
                  </div> \
                </div> \
              </div> \
            </div> \
          </div> \
        </div> \
      </div> \
      <div class="panel hide-on-embed panel-default"> \
        <div class="panel-heading"> \
          <h4 class="panel-title">SQL Query</h4> \
        </div> \
        <div class="panel-collapse collapse in"> \
          <div class="panel-body"> \
            <form class="form query-sql" role="form"> \
              <div class="form-group"> \
              <div id="sql-query" style="width:100%; height:150px;">{{initialSql}}</div> \
              </div> \
              <div class="sql-error alert alert-error alert-danger" style="display: none;"></div> \
              <button type="submit" class="btn btn-lg btn-primary btn-default pull-right">Run Query</button> \
              </div> \
            </form> \
          </div> \
        </div> \
      </div> \
      <div class="panel panel-default"> \
        <div class="panel-heading hide-on-embed"> \
          <h4 class="panel-title">Results: Browse, Visualize, and/or Export</h4> \
        </div> \
        <div class="panel-collapse collapse in"> \
          <div class="panel-body"> \
            <div class="sql-results"></div> \
            <div class="multiview"></div> \
          </div> \
        </div> \
      </div> \
      ',

    sqlQuery: function(e) {
      var self = this;
      if(e){ e.preventDefault(); }

      var $error = this.$el.find('.sql-error');
      $error.hide();

      if(typeof(aceEditor) != "undefined"){
        var sql = aceEditor.getValue()// this.$el.find('.query-sql textarea').val();        
      } else {
        // if aceEditor hasnt loaded yet, just use the iniitalSql option. User shouldnt have had time to change it
        var sql = view.model.attributes.initialSql
      }

      // replace ';' on end of sql as seems to trigger a json error
      sql = sql.replace(/;$/, '');

      // save hash here
      addOrReplacePairInHash("sql",encodeURIComponent(sql))

      ckan.datastoreSqlQuery(sql, function(err, data) {
        if (err) {
          var msg = '<p>Error: ' + err.message + '</p>';
          $error.html(msg);
          $error.show('slow');
          return;
        }

        // now handle good case ...
        var dataset = new recline.Model.Dataset({
          records: data.hits,
          fields: data.fields
        });
        dataset.fetch();
        // destroy existing view ...
        var $el = $('<div />');
        $('.sql-results').append($el);
        if (self.sqlResultsView) {
          self.sqlResultsView.remove();
        }

        $(".multiview").hide()

        self.sqlResultsView = self._makeMultiView(dataset, $el);
        dataset.query({size: dataset.recordCount});

        var requested_view = getURLParameterByKey("viewName",true)
        if(requested_view != ""){
          view.updateNav(requested_view)
          view.state.set({currentView: requested_view});
        }
      });
    }
  });


  // data visualization wizard
  if($(".wizardify").length){
    var dataset_key, resource_id, chosen_resource;

    $('.wizardify').bootstrapWizard({
      tabClass: 'bwizard-steps',
      onTabShow: function(tab, navigation, index) {
        if(index == 0){
          if(getURLParameterByKey("datasets",true) != ""){
            prechosen_dataset_keys = getURLParameterByKey("datasets",true).split(",")
            $.each(prechosen_dataset_keys, function(n,item){
              $("input[data-dataset-key='"+item+"']").attr("checked",true)
            })
            setTimeout(function(){
              $(".wizardify").bootstrapWizard("show",1)
            }, 0);
          }
        }

        if(index == 1){
          var chosen_dataset_keys = _.map($("#tab1 .checkbox input:checked"),function(x){return $(x).data("dataset-key")}).sort()
          
          // location.hash = "#datasets="+chosen_dataset_keys.join(",")
          addOrReplacePairInHash("datasets",chosen_dataset_keys.join(","))

          if ( chosen_dataset_keys.toString() == datasets_sites_joinable.toString() ){ // doing an allowed join
          } else if( chosen_dataset_keys.length != 1 ){
            alert("Please select exactly one dataset to build a visualization off of or select datasets that can be joined together")
            $(".wizardify").bootstrapWizard("show",0)
            return false;
          }

          chosen_resource = $(".resource-choose:checked")
          resource_id = chosen_resource.data("resource-id") // used even for joins
          dataset_key = chosen_resource.data("dataset-key")

          // only show examples if we are dealing with just one data set (not a join)
          if(chosen_dataset_keys.length == 1){
            var isJoin = false
            if(datasets[dataset_key]['extras_hash']['Default SQL']){
              var initialSql = datasets[dataset_key]['extras_hash']['Default SQL']
            } else {
              var initialSql = 'SELECT * FROM "'+resource_id+'" '+ dataset_key
            }
            
          } else { // for joins
            var isJoin = true
            var datasets_sites_join_sql = _.map(chosen_dataset_keys, function(chosen_dataset_key){
              return datasets[chosen_dataset_key]["site_join_sql"]
            }).join(" UNION ")
            $("#sql-query").val(datasets_sites_join_sql)
            var initialSql = datasets_sites_join_sql
            $(".sql-examples tbody").append("<tr class='example-query'><td class='example-sql-description'><strong><a href='#' data-sql='"+initialSql+"'>Default SQL for joining "+chosen_dataset_keys.join('/')+" datasets together</a></strong><td class='example-sql'><span style='font-family: monospace'>"+initialSql+"</span></td></tr>")
          }

          // override initialSql if it's specied in the URL
          if(getURLParameterByKey("sql",true)){ var initialSql = getURLParameterByKey("sql", true) }

          var view = new DataView({
            resourceId: resource_id,
            el: $(".data-view"),
            initialSql: initialSql,
            isJoin: isJoin,
            datasetKeys: chosen_dataset_keys
          });

          setTimeout(function(){
            aceEditor = ace.edit("sql-query");
            aceEditor.getSession().setMode("ace/mode/sql");
            aceEditor.getSession().setWrapLimitRange(80,120);
            aceEditor.getSession().setUseWrapMode(true);     
          }, 1500); // TODO - figure out why this has to wait 1 second

        }
      }
    });

  }

  $(".example-sql-description a").live('click', function(e) {
    e.preventDefault();
    
    var sql = $(e.target).data("sql")
    aceEditor.setValue(sql)
  })

  $(".zoom-to-city").live('click', function(e, target){
    e.preventDefault();
    mapView.view.map.setView(focus_city.latlon, focus_city.zoom)
  })

});