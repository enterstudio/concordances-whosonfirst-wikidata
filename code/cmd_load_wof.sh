#!/bin/bash

set -e
set -u

wof_repo=/wof/whosonfirst-data/
table=$1
csv=$2


echo """
    DROP TABLE IF EXISTS ${table} CASCADE ;
    CREATE UNLOGGED TABLE ${table} (
         id             BIGINT PRIMARY KEY
        ,parent_id      BIGINT
        ,placetype_id   BIGINT
        ,wd_id          TEXT
        ,is_superseded  SMALLINT
        ,is_deprecated  SMALLINT
        ,meta           JSONB
        ,properties     JSONB
        ,geom_hash      TEXT
        ,lastmod        TEXT
        ,geom           GEOGRAPHY(MULTIPOLYGON, 4326)
        ,centroid       GEOGRAPHY(POINT, 4326)
    )
    ;  
""" | psql -e 


echo "--------------- load ${table} - with wof-pgis-index -----------------"
time /wof/tools/go-whosonfirst-pgis/bin/wof-pgis-index \
    -pgis-password $PGPASSWORD \
    -pgis-host     $PGHOST \
    -pgis-table ${table} \
    -mode meta ${wof_repo}meta/${csv}
    
echo "======== index & test: ${table} ==========="

echo """

    -- delete superseded or deprecated records;
    DELETE FROM ${table} 
       WHERE  is_superseded=1 OR is_deprecated=1 
    ;

    -- index --

    CREATE INDEX   ON ${table}(wd_id)   WITH (fillfactor = 100);

    -- CREATE INDEX   ON ${table} USING GIST(geom);
    -- CREATE INDEX   ON ${table} USING GIST(centroid);
    -- CREATE INDEX   ON ${table} (placetype_id);
    -- CREATE INDEX   ON ${table} USING GIN (properties);
    -- CREATE INDEX   ON ${table} USING GIN (properties jsonb_path_ops);

    -- analyze --
    analyze ${table};

    -- test --
    SELECT 
        id
    ,placetype_id
    ,properties->>'wof:name'                     AS wof_name
    ,wd_id
    FROM ${table}
    LIMIT 10;

    ;  
""" | psql -e


