
DROP MATERIALIZED VIEW IF EXISTS wof_extended CASCADE;
CREATE MATERIALIZED VIEW wof_extended
as

with 
        disamb as (
            select id, 1 as is_disambiguation
            from wof_disambiguation_report
        ),
        redirected as (
            select id, 1 as is_redirected
            from wof_wd_redirects
        ),        
        extrdist as (
            select id, distance_km, 1 as is_extreme_distance
            from wof_extreme_distance_report
        )
select 
     wof.id
    ,wof.metatable
    ,case when disamb.is_disambiguation=1                                       then 'wikidata-ERR01-Disambiguation'
          when redirected.is_redirected=1                                       then 'wikidata-ERR02-Redirected'           
          when extrdist.is_extreme_distance=1   and  extrdist.distance_km>=1500 then 'wikidata-ERR03-Extreme distance 1500-    km'    
          when extrdist.is_extreme_distance=1   and  extrdist.distance_km>=700  then 'wikidata-ERR04-Extreme distance  700-1500km'
          when extrdist.is_extreme_distance=1   and  extrdist.distance_km>=400  then 'wikidata-ERR05-Extreme distance  400- 700km'
          when extrdist.is_extreme_distance=1   and  extrdist.distance_km>=200  then 'wikidata-ERR06-Extreme distance  200- 400km'
          when extrdist.is_extreme_distance=1   and  extrdist.distance_km>=50   then 'wikidata-ERR07-Extreme distance   50- 200km'                              
          when wof.wd_id!=''                                                    then 'wikidata-MAYBE ok (need more investigate)'
                                                                                else 'no-wikidataid-yet'
     end as _status   
    ,case when   disamb.is_disambiguation=1 
              or redirected.is_redirected=1
              or extrdist.is_extreme_distance=1     then 1
                                                    else 0
     end as _wd_is_problematic       
    ,wof.is_superseded
    ,wof.is_deprecated
    ,wof.properties->>'wof:name'                    as wof_name 
    ,wof.properties->>'wof:country'                 as wof_country
    ,wof.wd_id
    ,wof.properties->>'wof:population'              as wof_population
    ,wof.properties->>'wof:population_rank'         as wof_population_rank     
from wof
  left join disamb      on disamb.id    = wof.id
  left join extrdist    on extrdist.id  = wof.id   
  left join redirected  on redirected.id = wof.id
order by wof.id  
;

CREATE UNIQUE INDEX  wof_extended_id            ON wof_extended( id );
CREATE        INDEX  wof_extended_wd_id         ON wof_extended( wd_id );
CREATE        INDEX  wof_extended_wof_country   ON wof_extended( wof_country );

ANALYSE wof_extended;


-- helper table for country extract  
create or replace view wof_extended_wd_ok
as
    select id,metatable,wof_name,wof_country,wd_id
    from  wof_extended
    where _wd_is_problematic=0 and wd_id!=''
;


create or replace view wof_extended_meta_status_country_summary
as
    select metatable, _status , wof_country, count(*) as N
    from wof_extended
    group by metatable, _status , wof_country
    order by metatable, _status , wof_country
;

create or replace view wof_extended_status_summary
as
    select  _status , count(*) as N
    from wof_extended
    group by _status
    order by _status
;