# strategi-for-pgrouting
Building a pgRouting network from Ordnance Survey's Strategi dataset.  The SQL in the assets directory contains everything to get you up and running.

Get the data
------------

Download the Strategi shapefiles for the UK from https://www.ordnancesurvey.co.uk/opendatadownload/products.html

Merge the roads
---------------

+ unzip the downloaded strategi data to a suitable location.
+ using QGIS you can merge all the roads shapefiles to make one shapefile layer.
+ From the Vector Menu choose Data Management > Merge Shapefiles To One
+ Choose all roads layers from the folder
+ Save the merged roads layer
+ Add the new layer to QGIS

Load to the database
--------------------

+ Use the DB Manager in QGIS to load the data to PostGIS
+ Optionally create a new schema: os_strategi (or use public)
+ Create table: strat_rds
+ Set the primary key field: gid 
+ Set the geometry field: geometry 
+ Set the SRID: 27700
+ Check box to create single part features
+ Check the box to create spatial index.

Create a network table
----------------------

Add some fields that pgRouting needs

	ALTER TABLE os_strategi.strat_rds
		ADD COLUMN source integer,
		ADD COLUMN target integer,
		ADD COLUMN speed_km integer,
		ADD COLUMN cost_len double precision,
		ADD COLUMN rcost_len double precision,
		ADD COLUMN cost_time double precision,
		ADD COLUMN rcost_time double precision,
		ADD COLUMN x1 double precision,
		ADD COLUMN y1 double precision,
		ADD COLUMN x2 double precision,
		ADD COLUMN y2 double precision,
		ADD COLUMN to_cost double precision,
		ADD COLUMN rule text,
		ADD COLUMN isolated integer;

Build the indices on the *source* and *target* fields to speed things up
		
	CREATE INDEX strat_rds_source_idx ON os_strategi.strat_rds USING btree(source);
	CREATE INDEX strat_rds_target_idx ON os_strategi.strat_rds USING btree(target);

Populate the network table
--------------------------

Calculate coordinates for start and end points of lines

	UPDATE os_strategi.strat_rds SET 
		x1 = st_x(st_startpoint(geometry)),
			y1 = st_y(st_startpoint(geometry)),
			x2 = st_x(st_endpoint(geometry)),
			y2 = st_y(st_endpoint(geometry));

Update the length fields with length of the links			
			
	UPDATE os_strategi.strat_rds SET
		cost_len = ST_Length(geometry),
		rcost_len = ST_Length(geometry);

Set some average speeds used to calculate travel time.  Adjust as required.		
		
	UPDATE os_strategi.strat_rds SET speed_km =
		CASE WHEN legend = 'A Road, Dual Carriageway' THEN 60
		WHEN legend = 'A Road, Dual Carriageway, planned' THEN 1
		WHEN legend = 'A Road, Dual C''way over other feature' THEN 60
		WHEN legend = 'A Road, Narrow' THEN 50
		WHEN legend = 'A Road, Single Carriageway' THEN 50
		WHEN legend = 'A Road, Single C''way over other feature' THEN 50
		WHEN legend = 'A Road, Single C''way under construction' THEN 1
		WHEN legend = 'A Road tunnel' THEN 50
		WHEN legend = 'B Road, Dual Carriageway' THEN 60
		WHEN legend = 'B Road, Dual C''way over other feature' THEN 60
		WHEN legend = 'B Road, Narrow' THEN 40
		WHEN legend = 'B Road, Narrow over other feature' THEN 40
		WHEN legend = 'B Road, Single Carriageway' THEN 50
		WHEN legend = 'B Road, Single C''way over other feature' THEN 50
		WHEN legend = 'Dead-end Road gen < 4 metres wide (over)' THEN 10
		WHEN legend = 'Dead-end Road gen under 4 metres wide' THEN 10
		WHEN legend = 'Long Distance Footpath' THEN 1
		WHEN legend = 'Minor Road over 4 metres wide' THEN 30
		WHEN legend = 'Minor Road over 4 metres wide (over)' THEN 30
		WHEN legend = 'Minor Road over 4 metres wide tunnel' THEN 30
		WHEN legend = 'Minor Road under 4 metres wide' THEN 20
		WHEN legend = 'Minor Road under 4 metres wide (over)' THEN 20
		WHEN legend = 'Minor Road under 4 metres wide tunnel' THEN 20
		WHEN legend = 'Motorway' THEN 70
		WHEN legend = 'Motorway over other feature' THEN 70
		WHEN legend = 'Motorway, planned' THEN 1
		WHEN legend = 'Motorway tunnel' THEN 70
		WHEN legend = 'Other Track or Road' THEN 10
		WHEN legend = 'Other Track or Road over other feature' THEN 10
		WHEN legend = 'Primary Route, D C''way over other feature' THEN 65
		WHEN legend = 'Primary Route, D C''way under construction' THEN 1
		WHEN legend = 'Primary Route, Dual Carriageway' THEN 60
		WHEN legend = 'Primary Route, Dual Carriageway, planned' THEN 1
		WHEN legend = 'Primary Route, Narrow' THEN 50
		WHEN legend = 'Primary Route, S Carriageway, planned' THEN 1
		WHEN legend = 'Primary Route, S C''way over other feature' THEN 50
		WHEN legend = 'Primary Route, S C''way under construction' THEN 1
		WHEN legend = 'Primary Route, Single Carriageway' THEN 50
		WHEN legend = 'Primary Route tunnel' THEN 50
		ELSE 1 END;

Calculate the travel time for each link		
		
	UPDATE os_strategi.strat_rds SET
		cost_time = cost_len/1000.0/speed_km::numeric*3600.0,
		rcost_time = cost_len/1000.0/speed_km::numeric*3600.0; 

Update the statistics on the table and clear out the cruft		
		
	VACUUM ANALYZE VERBOSE os_strategi.strat_rds;

Build the topology
------------------

Build your network

	SELECT pgr_createtopology('os_strategi.strat_rds',0.001,'geometry','gid','source','target');

Analyse the network
-------------------

Analyse your network for errors.  You may get some complaints about the geometry being MULTILINESTRING rather than LINESTRING

	SELECT pgr_analyzegraph('os_strategi.strat_rds',0.001,'geometry','gid','source','target');

Get lost
--------

Use the pgRouting Layer plugin in QGIS to load your network table and do some routing.
