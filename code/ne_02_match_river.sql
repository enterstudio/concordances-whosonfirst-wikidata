
-- cleaning airport names for better matching;
CREATE OR REPLACE FUNCTION  river_clean(river_name text) 
    RETURNS text  
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE   AS
$func$
select trim( translate( regexp_replace(  nameclean( river_name ) ,
 $$[[:<:]](river|rio|le|de|)[[:>:]]$$,
  ' ',
  'gi'
),'  ',' ') );
$func$
;


CREATE OR REPLACE FUNCTION  river_array_clean(arr1 text[],arr2 text[]) 
    RETURNS text[]  
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE   AS
$func$
    select array_agg( distinct aname )  from 
    (
                 ( select  river_clean( arr1name ) as aname from unnest(arr1) as arr1name )
      union all  ( select  river_clean( arr2name ) as aname from unnest(arr1) as arr2name )
    ) t
$func$
;



drop table if exists                    newd.wd_match_river CASCADE;
EXPLAIN ANALYSE CREATE UNLOGGED TABLE   newd.wd_match_river  as
with x as
(
select
     wd_id
    ,wd_label               as wd_name_en
    ,check_number(wd_label) as wd_name_has_num
    ,          (regexp_split_to_array( wd_label , '[,()]'))[1]  as wd_name_en_clean
    ,river_clean((regexp_split_to_array( wd_label , '[,()]'))[1]) as una_wd_name_en_clean
    ,iscebuano                  as wd_is_cebuano
    ,nSitelinks    
    --  ,get_wdc_value(data, 'P1566')      as p1566_geonames    
    ,get_wdc_item_label(data,'P31')    as p31_instance_of
    ,get_wdc_item_label(data,'P17')    as p17_country_id 
    ,get_wd_name_array(data)           as wd_name_array 
    ,get_wd_altname_array(data)        as wd_altname_array
    --  ,get_wd_concordances(data)         as wd_concordances_array
    ,cartodb.CDB_TransformToWebmercator(geom::geometry)  as wd_point_merc
from wd.wdx 
where (a_wof_type  @> ARRAY['river','hasP625'] )    and  not iscebuano
)
select *
      ,river_array_clean(wd_name_array,wd_altname_array) as wd_all_name_array
from x      
;


CREATE INDEX  ON  newd.wd_match_river USING GIST(wd_point_merc);
CREATE INDEX  ON  newd.wd_match_river (wd_id);
ANALYSE           newd.wd_match_river ;


--
---------------------------------------------------------------------------------------
--

drop table if exists          newd.ne_match_river_europe CASCADE;
CREATE UNLOGGED TABLE         newd.ne_match_river_europe  as
select
     ogc_fid
    ,featurecla
    ,name                as ne_name
    ,river_clean(name)    as ne_una_name        
    ,check_number(name)  as ne_name_has_num
    ,ARRAY[name::text,river_clean(name)::text,river_clean(name_alt)::text,unaccent(name)::text,unaccent(name_alt)::text]     as ne_name_array
    ,cartodb.CDB_TransformToWebmercator(geometry)   as ne_geom_merc
    ,'' as ne_wd_id
from ne.ne_10m_rivers_europe
;

CREATE INDEX  ON newd.ne_match_river_europe  USING GIST(ne_geom_merc);
ANALYSE          newd.ne_match_river_europe;

\set wd_input_table           newd.wd_match_river
\set ne_input_table           newd.ne_match_river_europe

\set ne_wd_match               newd.ne_wd_match_river_europe_match
\set ne_wd_match_agg           newd.ne_wd_match_river_europe_match_agg
\set ne_wd_match_agg_sum       newd.ne_wd_match_river_europe_match_agg_sum
\set ne_wd_match_notfound      newd.ne_wd_match_river_europe_match_notfound

\set safedistance   400000
\set searchdistance 800003
\set suggestiondistance  80000

\set mcond1     (( ne.ne_una_name = wd.una_wd_name_en_clean ) or (  wd_name_array && ne_name_array ) or (  ne_name_array && wd_all_name_array ) or (  ne_name_array && wd_altname_array )  or (jarowinkler( ne.ne_una_name, wd.una_wd_name_en_clean)>.971 ) )
\set mcond2 and (ST_DWithin ( wd.wd_point_merc, ne.ne_geom_merc , :searchdistance ))
\set mcond3

\ir 'template_newd_matching.sql'








--
---------------------------------------------------------------------------------------
--

drop table if exists          newd.ne_match_river_north_america CASCADE;
CREATE UNLOGGED TABLE         newd.ne_match_river_north_america  as
select
     ogc_fid
    ,featurecla
    ,name                 as ne_name
    ,river_clean(name)    as ne_una_name        
    ,check_number(name)   as ne_name_has_num
    ,ARRAY[name::text,river_clean(name)::text,river_clean(name_alt)::text,unaccent(name)::text,unaccent(name_alt)::text]     as ne_name_array
    ,cartodb.CDB_TransformToWebmercator(geometry)   as ne_geom_merc
    ,'' as ne_wd_id
from ne.ne_10m_rivers_north_america
;

CREATE INDEX  ON newd.ne_match_river_north_america  USING GIST(ne_geom_merc);
ANALYSE          newd.ne_match_river_north_america;

\set wd_input_table           newd.wd_match_river
\set ne_input_table           newd.ne_match_river_north_america

\set ne_wd_match               newd.ne_wd_match_river_north_america_match
\set ne_wd_match_agg           newd.ne_wd_match_river_north_america_match_agg
\set ne_wd_match_agg_sum       newd.ne_wd_match_river_north_america_match_agg_sum
\set ne_wd_match_notfound      newd.ne_wd_match_river_north_america_match_notfound

\set safedistance   400000
\set searchdistance 800003
\set suggestiondistance  80000

\set mcond1     (( ne.ne_una_name = wd.una_wd_name_en_clean ) or (  wd_name_array && ne_name_array ) or (  ne_name_array && wd_all_name_array )  or (  ne_name_array && wd_altname_array )  or (jarowinkler( ne.ne_una_name, wd.una_wd_name_en_clean)>.971 ) )
\set mcond2 and (ST_DWithin ( wd.wd_point_merc, ne.ne_geom_merc , :searchdistance ))
\set mcond3

\ir 'template_newd_matching.sql'





drop table if exists          newd.ne_match_river_lake_centerlines CASCADE;
CREATE UNLOGGED TABLE         newd.ne_match_river_lake_centerlines  as
select
     ogc_fid
    ,featurecla 
    ,name                as ne_name
    ,river_clean(name)   as ne_una_name        
    ,check_number(name)  as ne_name_has_num
    ,ARRAY[name::text,river_clean(name)::text,river_clean(name_alt)::text,unaccent(name)::text,unaccent(name_alt)::text]     as ne_name_array
    ,cartodb.CDB_TransformToWebmercator(geometry)   as ne_geom_merc
    ,'' as ne_wd_id
from ne.ne_10m_rivers_lake_centerlines
;

CREATE INDEX  ON newd.ne_match_river_lake_centerlines  USING GIST(ne_geom_merc);
ANALYSE          newd.ne_match_river_lake_centerlines;

\set wd_input_table           newd.wd_match_river
\set ne_input_table           newd.ne_match_river_lake_centerlines

\set ne_wd_match               newd.ne_wd_match_river_lake_centerlines_match
\set ne_wd_match_agg           newd.ne_wd_match_river_lake_centerlines_match_agg
\set ne_wd_match_agg_sum       newd.ne_wd_match_river_lake_centerlines_match_agg_sum
\set ne_wd_match_notfound      newd.ne_wd_match_river_lake_centerlines_match_notfound

\set safedistance   400000
\set searchdistance 800003
\set suggestiondistance  80000

\set mcond1     (( ne.ne_una_name = wd.una_wd_name_en_clean ) or (  wd_name_array && ne_name_array ) or (  ne_name_array && wd_all_name_array )  or (  ne_name_array && wd_altname_array )  or (jarowinkler( ne.ne_una_name, wd.una_wd_name_en_clean)>.971 ) )
\set mcond2 and (ST_DWithin ( wd.wd_point_merc, ne.ne_geom_merc , :searchdistance ))
\set mcond3

\ir 'template_newd_matching.sql'


