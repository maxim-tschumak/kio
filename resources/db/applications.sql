-- name: read-applications
SELECT a_id,
       a_team_id,
       a_active,
       a_name,
       a_subtitle,
       a_service_url,
       a_scm_url,
       a_documentation_url,
       a_specification_url,
       a_last_modified
  FROM zk_data.application
 WHERE a_last_modified <= COALESCE(:modified_before, a_last_modified)
   AND a_last_modified >= COALESCE(:modified_after, a_last_modified);

-- name: search-applications
  SELECT a_id,
         a_team_id,
         a_active,
         a_name,
         a_subtitle,
         a_service_url,
         a_scm_url,
         a_documentation_url,
         a_specification_url,
         a_last_modified,
         ts_rank_cd(vector, query) AS a_matched_rank,
         ts_headline('simple', a_description, query) AS a_matched_description
    FROM (SELECT a_id,
                 a_team_id,
                 a_active,
                 a_name,
                 a_subtitle,
                 a_service_url,
                 a_scm_url,
                 a_documentation_url,
                 a_specification_url,
                 a_last_modified,
                 a_description,
                 setweight(to_tsvector('simple', a_name), 'A')
                 || setweight(to_tsvector('simple', COALESCE(a_subtitle, '')), 'B')
                 || setweight(to_tsvector('simple', COALESCE(a_description, '')), 'C')
                   as vector
            FROM zk_data.application
           WHERE a_last_modified <= COALESCE(:modified_before, a_last_modified)
             AND a_last_modified >= COALESCE(:modified_after, a_last_modified)) as apps,
                 to_tsquery('simple', :searchquery) query
   WHERE query @@ vector
ORDER BY a_matched_rank DESC;

--name: read-application
SELECT a_id,
       a_team_id,
       a_active,
       a_name,
       a_subtitle,
       a_description,
       a_service_url,
       a_scm_url,
       a_documentation_url,
       a_specification_url,
       a_specification_type,
       a_criticality_level,
       a_created,
       a_created_by,
       a_last_modified,
       a_last_modified_by,
       a_publicly_accessible
  FROM zk_data.application
 WHERE a_id = :id;

-- name: create-or-update-application!
WITH application_update AS (
     UPDATE zk_data.application
        SET a_team_id             = :team_id,
            a_active              = :active,
            a_name                = :name,
            a_subtitle            = :subtitle,
            a_description         = :description,
            a_service_url         = :service_url,
            a_scm_url             = :scm_url,
            a_documentation_url   = :documentation_url,
            a_specification_url   = :specification_url,
            a_specification_type  = :specification_type,
            a_last_modified       = NOW(),
            a_last_modified_by    = :last_modified_by,
            a_publicly_accessible = :publicly_accessible
      WHERE a_id = :id
  RETURNING *)
INSERT INTO zk_data.application (
            a_id,
            a_team_id,
            a_active,
            a_name,
            a_subtitle,
            a_description,
            a_service_url,
            a_scm_url,
            a_documentation_url,
            a_specification_url,
            a_specification_type,
            a_created_by,
            a_last_modified_by,
            a_publicly_accessible)
     SELECT :id,
            :team_id,
            :active,
            :name,
            :subtitle,
            :description,
            :service_url,
            :scm_url,
            :documentation_url,
            :specification_url,
            :specification_type,
            :created_by,
            :last_modified_by,
            :publicly_accessible
      WHERE NOT EXISTS (SELECT * FROM application_update);

-- name: update-application-criticality!
UPDATE zk_data.application
   SET a_criticality_level = :criticality_level,
       a_last_modified = NOW(),
       a_last_modified_by = :last_modified_by
 WHERE a_id = :id;
