-- Adjust schema and table names as required
-- Adjust average road speeds as required
-- It's a good idea to VACUUM ANALYZE your table once you've finished

-- add pgRouting fields
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

-- add indices to make it fast
CREATE INDEX strat_rds_source_idx ON os_strategi.strat_rds USING btree(source);
CREATE INDEX strat_rds_target_idx ON os_strategi.strat_rds USING btree(target);

-- update link coordinates
UPDATE os_strategi.strat_rds SET 
	x1 = st_x(st_startpoint(geometry)),
	y1 = st_y(st_startpoint(geometry)),
	x2 = st_x(st_endpoint(geometry)),
	y2 = st_y(st_endpoint(geometry));

-- update length cost fields
UPDATE os_strategi.strat_rds SET
	cost_len = ST_Length(geometry),
	rcost_len = ST_Length(geometry);

-- set average road speeds for time costs
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

-- update time cost fields
UPDATE os_strategi.strat_rds SET
	cost_time = cost_len/1000.0/speed_km::numeric*3600.0,
	rcost_time = cost_len/1000.0/speed_km::numeric*3600.0;

-- build the network
SELECT pgr_createtopology('os_strategi.strat_rds',0.001,'geometry','gid','source','target');

-- check the network
SELECT pgr_analyzegraph('os_strategi.strat_rds',0.001,'geometry','gid','source','target');

-- clean out the cruft, update stats		
-- VACUUM ANALYZE VERBOSE os_strategi.strat_rds;
