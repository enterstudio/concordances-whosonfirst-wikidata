
-- cleaning macrocounty names for better matching;
CREATE OR REPLACE FUNCTION  macrocounty_clean(airport_name text) 
    RETURNS text  
LANGUAGE sql IMMUTABLE   AS
$func$
select  trim(translate( regexp_replace(  nameclean( airport_name ) ,
 $$[[:<:]](arrondissement of|county|government region)[[:>:]]$$,
  ' ',
  'gi'
),'  ',' '));
$func$
;
--
--  select  wd_name_en, macrocounty_clean( wd_name_en) from wfwd.wd_match_macrocounty;
--




drop table if exists  wfwd.wd_match_macrocounty CASCADE;
create table          wfwd.wd_match_macrocounty  as
with x AS (
        select
            wd_id
            ,get_wdlabeltext(data->>'id'::text)     as wd_name_en
            ,(regexp_split_to_array( get_wdlabeltext(data->>'id'::text), '[,()]'))[1]   as wd_name_en_clean
            ,is_cebuano(data)                       as wd_is_cebuano
            ,get_wdc_value(data, 'P1566')           as p1566_geonames    
            ,ST_SetSRID(ST_MakePoint( 
                        cast(get_wdc_globecoordinate(data,'P625')->0->>'longitude' as double precision)
                        ,cast(get_wdc_globecoordinate(data,'P625')->0->>'latitude'  as double precision)
                        )
                , 4326) as wd_point
            ,get_wdc_item_label(data,'P31')    as p31_instance_of
            ,get_wdc_item_label(data,'P17')    as p17_country_id 
            ,get_wd_name_array(data)           as wd_name_array 
            ,get_wd_altname_array(data)        as wd_altname_array
            ,get_wd_concordances(data)         as wd_concordances_array
        from wd.wdx 
        where a_wof_type && ARRAY['macrocounty']    
    )
    SELECT *
          , macrocounty_clean(wd_name_en_clean)  as una_wd_name_en_clean
          , CDB_TransformToWebmercator(wd_point) as wd_point_merc
    FROM x
    WHERE wd_id != wd_name_en
      and wd_point is not null
      and wd_is_cebuano IS FALSE
    ;

CREATE INDEX  ON  wfwd.wd_match_macrocounty USING GIST(wd_point_merc);
CREATE INDEX  ON  wfwd.wd_match_macrocounty (una_wd_name_en_clean);
CREATE INDEX  ON  wfwd.wd_match_macrocounty (wd_id);
CREATE INDEX  ON  wfwd.wd_match_macrocounty USING GIN(wd_name_array );
CREATE INDEX  ON  wfwd.wd_match_macrocounty USING GIN(wd_altname_array );
ANALYSE   wfwd.wd_match_macrocounty ;




drop table if exists wfwd.wof_match_macrocounty CASCADE;
create table         wfwd.wof_match_macrocounty  as
select
     wof.id
    ,wof.properties->>'wof:name'            as wof_name
    ,macrocounty_clean(wof.properties->>'wof:name')  as una_wof_name
    ,wof.properties->>'wof:country'         as wof_country
    ,wof.wd_id                              as wof_wd_id
    ,get_wof_name_array(wof.properties)     as wof_name_array
    ,get_wof_concordances(wof.properties)   as wof_concordances_array
    ,CDB_TransformToWebmercator(COALESCE( wof.geom::geometry, wof.centroid::geometry ))   as wof_geom_merc
from wf.wof_macrocounty as wof
where  wof.is_superseded=0  and wof.is_deprecated=0
;

CREATE INDEX  ON wfwd.wof_match_macrocounty  USING GIST(wof_geom_merc);
CREATE INDEX  ON wfwd.wof_match_macrocounty  (una_wof_name);
CREATE INDEX  ON wfwd.wof_match_macrocounty  USING GIN ( wof_name_array);
ANALYSE          wfwd.wof_match_macrocounty ;


--
---------------------------------------------------------------------------------------
--

\set wd_input_table           wfwd.wd_match_macrocounty
\set wof_input_table          wfwd.wof_match_macrocounty

\set wd_wof_match             wfwd.wd_mmacrocounty_wof_match
\set wd_wof_match_agg         wfwd.wd_mmacrocounty_wof_match_agg
\set wd_wof_match_agg_sum     wfwd.wd_mmacrocounty_wof_match_agg_summary
\set wd_wof_match_notfound    wfwd.wd_mmacrocounty_wof_match_notfound
\set safedistance    40000
\set searchdistance 100003

\set mcond1     (( wof.una_wof_name = wd.una_wd_name_en_clean ) or (wof_name_array && wd_name_array ) or (  wof_name_array && wd_altname_array ) or (wd_concordances_array && wof_concordances_array) or (jarowinkler(wof.una_wof_name, wd.una_wd_name_en_clean)>.971 ) )
\set mcond2  and (ST_DWithin ( wd.wd_point_merc, wof.wof_geom_merc , :searchdistance ))
\set mcond3



\ir 'template_matching.sql'
