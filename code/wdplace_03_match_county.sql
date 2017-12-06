



drop table if exists  wdplace.wd_match_county CASCADE;
create table          wdplace.wd_match_county  as
    select
     data->>'id'::text                  as wd_id  
    ,get_wdlabeltext(data->>'id'::text) as wd_name_en
    ,get_wdlabeltext(data->>'id'::text) as wd_name_en_clean
    ,unaccent(get_wdlabeltext(data->>'id'::text))   as una_wd_name_en_clean

    ,get_countrycode( (get_wdc_item(data,'P17'))->>0 )   as wd_country 

    ,get_wdc_item_label(data,'P31')    as p31_instance_of
    ,get_wdc_item_label(data,'P17')    as p17_country_id    

    --,(get_wdc_value(data, 'P901'))->>0  as fips10_4

    --,get_wdc_value(data, 'P300')    as p300_iso3166_2
    --,get_wdc_value(data, 'P901')    as p901_fips10_4
    --,get_wdc_value(data, 'P1566')   as p1566_geonames
        
    --,get_wdc_monolingualtext(data, 'P1813')   as p1813_short_name
    --,get_wdc_monolingualtext(data, 'P1549')   as p1549_demonym
    --,get_wdc_monolingualtext(data, 'P1448')   as p1448_official_name
    --,get_wdc_monolingualtext(data, 'P1705')   as p1705_native_label
    --,get_wdc_monolingualtext(data, 'P1449')   as p1449_nick_name    

    ,get_wd_name_array(data)           as wd_name_array 
    ,get_wd_altname_array(data)        as wd_altname_array

    ,CDB_TransformToWebmercator(ST_SetSRID(ST_MakePoint( 
             cast(get_wdc_globecoordinate(data,'P625')->0->>'longitude' as double precision)
            ,cast(get_wdc_globecoordinate(data,'P625')->0->>'latitude'  as double precision)
            )
    , 4326)) as wd_point_merc
    
    from wdplace.wd_county
    order by  wd_country, una_wd_name_en_clean  
;

CREATE INDEX  ON  wdplace.wd_match_county USING GIST(wd_point_merc);
CREATE INDEX  ON  wdplace.wd_match_county (una_wd_name_en_clean);
CREATE INDEX  ON  wdplace.wd_match_county (wd_id);
CREATE INDEX  ON  wdplace.wd_match_county  USING GIN(wd_name_array );
CREATE INDEX  ON  wdplace.wd_match_county  USING GIN(wd_altname_array );
ANALYSE   wdplace.wd_match_county;



drop table if exists wof_match_county CASCADE;
create table         wof_match_county  as
select
     wof.id
    ,wof.properties->>'wof:name'            as wof_name 
    ,unaccent(wof.properties->>'wof:name')  as una_wof_name 
    ,wof.properties->>'wof:country'         as wof_country
    ,wof.wd_id                              as wof_wd_id
    ,get_wof_name_array(wof.properties)     as wof_name_array
    ,CDB_TransformToWebmercator(COALESCE( wof.geom::geometry, wof.centroid::geometry ))  as wof_geom_merc
from wof_county as wof
where  wof.is_superseded=0 
   and wof.is_deprecated=0
order by wof_country,  una_wof_name 
;

CREATE INDEX ON  wof_match_county  USING GIST(wof_geom_merc);
CREATE INDEX ON  wof_match_county  (una_wof_name);
ANALYSE  wof_match_county ;




\set searchdistance 500003
\set safedistance   100000
\set wd_input_table           wdplace.wd_match_county
\set wof_input_table          wof_match_county

\set wd_wof_match             wd_mcounty_wof_match
\set wd_wof_match_agg         wd_mcounty_wof_match_agg
\set wd_wof_match_agg_sum     wd_mcounty_wof_match_agg_summary
\set wd_wof_match_notfound    wd_mcounty_wof_match_notfound

\set mcond1  ( wof.wof_country  = wd.wd_country )
\set mcond2  and (( wof.una_wof_name = wd.una_wd_name_en_clean ) or (wof_name_array && wd_name_array ) or (  wof_name_array && wd_altname_array ) or (jarowinkler(wof.una_wof_name, wd.una_wd_name_en_clean)>.971 ) )
\set mcond3  and (ST_DWithin ( wd.wd_point_merc, wof.wof_geom_merc , :searchdistance ))

\ir 'template_matching.sql'

