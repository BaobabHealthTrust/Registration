USE bart2;

DROP TABLE IF EXISTS `temp_obs`;

CREATE TABLE `temp_obs` (
  `obs_id` int(11) NOT NULL DEFAULT '0',
  `obs_datetime` datetime DEFAULT NULL,
  `old_value_coded` int(11) NOT NULL DEFAULT '0',
  `new_value_coded` int(11) NOT NULL DEFAULT '0',
  `value_coded_name_id` int(11) NOT NULL DEFAULT '0',
  KEY (`obs_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_obs (obs_id, obs_datetime, old_value_coded, new_value_coded, value_coded_name_id)
(SELECT  -- b1o.patient_id AS bart1_patient_id,
        -- b1o.obs_id AS bart1_obs_is,
        -- b1o.concept_id AS bart1_concept_id, 
        -- b1o.value_coded AS bart1_value_coded, 
        -- b1o.obs_datetime AS bart1_datetime,
        b2o.obs_id,
        b2o.obs_datetime,
        b2o.value_coded,
        CASE b1o.value_coded
            WHEN 478 THEN 7458
            WHEN 477 THEN 7456
            WHEN 508 THEN 7454
            WHEN 479 THEN 7455
            WHEN 397 THEN 1067
            WHEN 2   THEN 1067
        END AS required_bart2_value_coded,
        CASE b1o.value_coded
            WHEN 478 THEN 10279
            WHEN 477 THEN 10274
            WHEN 508 THEN 10270
            WHEN 479 THEN 10273
            WHEN 397 THEN 1104
            WHEN 2   THEN 1104
        END AS required_bart2_value_coded_id
    FROM bart1.obs b1o
        INNER JOIN bart2.obs b2o 
            ON b1o.patient_id = b2o.person_id 
            AND b1o.obs_datetime = b2o.obs_datetime
    WHERE b1o.concept_id = 509 AND b2o.concept_id = 7459
    HAVING required_bart2_value_coded <> b2o.value_coded
           AND required_bart2_value_coded IS NOT NULL);

UPDATE bart2.obs o
SET value_coded =   (SELECT new_value_coded 
                    FROM temp_obs 
                    WHERE obs_id = o.obs_id AND obs_datetime = o.obs_datetime),
    value_coded_name_id =  (SELECT value_coded_name_id 
                            FROM temp_obs 
                            WHERE obs_id = o.obs_id AND obs_datetime = o.obs_datetime)
WHERE o.obs_id IN (SELECT obs_id FROM temp_obs);

-- DROP TABLE IF EXISTS `temp_obs`;

-- SELECT * FROM temp_obs where value_coded_name_id NOT IN (10279, 10274, 10270, 10273, 1104);



