
USE mpc_bart2_data;

DELETE FROM patient_state 
	WHERE patient_program_id IN (SELECT patient_program_id FROM patient_program 
	WHERE program_id = 1) AND state = 118;

DROP TABLE IF EXISTS `temp_patient_list`;

DROP TABLE IF EXISTS `temp_patient_list2`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `patient_id` int(11) NOT NULL DEFAULT '0',
  KEY (`patient_program_id`),
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `temp_patient_list2` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `patient_id` int(11) NOT NULL DEFAULT '0',
  KEY (`patient_program_id`),
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_patient_list (patient_program_id, patient_id)
	SELECT patient_program_id, patient_id FROM patient_program 
	WHERE voided = 0 AND location_id = (SELECT property_value FROM mpc_bart2_data.global_property WHERE property = "current_health_center_id")
	GROUP BY patient_id, program_id
	HAVING program_id = 1 AND COUNT(*) > 1;

INSERT INTO temp_patient_list2 (patient_program_id, patient_id)
	SELECT patient_program_id, patient_id FROM patient_program 
		WHERE patient_id IN (SELECT patient_id FROM temp_patient_list)
			AND patient_program_id NOT IN (SELECT patient_program_id FROM temp_patient_list)
			AND program_id = 1;

SET FOREIGN_KEY_CHECKS = 0;

DELETE FROM patient_state 
	WHERE patient_program_id IN (SELECT patient_program_id FROM temp_patient_list2); 

DELETE FROM patient_program 
	WHERE patient_program_id IN (SELECT patient_program_id FROM temp_patient_list2); 

DELETE FROM patient_program 
	WHERE voided = 1
	AND program_id = 1;
	
DELETE FROM patient_program 
	WHERE date_enrolled IS NULL AND program_id = 1; 

DELETE FROM patient_state 
	WHERE patient_program_id NOT IN (SELECT patient_program_id FROM patient_program); 

	
SET FOREIGN_KEY_CHECKS = 1;

DROP TABLE IF EXISTS `temp_patient_list`;
DROP TABLE IF EXISTS `temp_patient_list2`;

DELETE FROM mpc_bart2_data.patient_state
	WHERE state = 1 ;

DELETE FROM mpc_bart2_data.patient_state
	WHERE state IN (6,2)  AND start_date <= '2012-02-12' ;

UPDATE mpc_bart2_data.person SET death_date = NULL, dead = 0 
	WHERE date_created <= '2012-02-12' ;

DELETE FROM mpc_bart2_data.patient_state
	WHERE state = 7;

INSERT INTO mpc_bart2_data.patient_program (patient_id, program_id, date_enrolled, 
            creator, date_created, uuid, location_id)
	SELECT patient_id, 1, NOW(), creator, 
    		date_created, (SELECT UUID()) AS uuid, 
    		(SELECT property_value FROM mpc_bart2_data.global_property WHERE property = "current_health_center_id")
	FROM mpc_bart2_data.patient 
	WHERE voided = 0 AND patient_id NOT IN (SELECT patient_id FROM patient_program WHERE program_id = 1 AND voided = 0); 

INSERT INTO mpc_bart2_data.patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
    SELECT pp.patient_program_id, 1, pp.date_enrolled, 1, NOW(), (SELECT UUID())
    FROM  mpc_bart2_data.patient p
        LEFT JOIN mpc_bart2_data.patient_program pp ON p.patient_id = pp.patient_id AND pp.program_id = 1 AND pp.voided = 0
    WHERE p.voided = 0;


INSERT INTO patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
(SELECT pp.patient_program_id, 7, DATE(obs1.obs_datetime), pp.creator, NOW(), (SELECT UUID())
FROM mpc_bart2_data.patient_program pp
INNER JOIN (SELECT obs.person_id, MIN(obs.obs_datetime) AS obs_datetime FROM mpc_bart2_data.drug_order d
    LEFT JOIN mpc_bart2_data.orders o ON d.order_id = o.order_id
    LEFT JOIN mpc_bart2_data.obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
        AND quantity > 0
        AND obs.voided = 0
        AND o.voided = 0
    GROUP BY obs.person_id) obs1 ON pp.patient_id = obs1.person_id AND pp.program_id = 1 
GROUP BY pp.patient_id, DATE(obs1.obs_datetime));

UPDATE mpc_bart2_data.patient_program
    SET date_enrolled = (SELECT MIN(start_date)
                            FROM mpc_bart2_data.patient_state ps2 
                            WHERE ps2.patient_program_id = mpc_bart2_data.patient_program.patient_program_id)
    WHERE program_id = 1;

UPDATE mpc_bart2_data.patient_state 
    SET start_date = (SELECT date_enrolled
                    FROM mpc_bart2_data.patient_program pp2 
                    WHERE pp2.patient_program_id = mpc_bart2_data.patient_state.patient_program_id)
    WHERE state = 1;

-- update end date for pre art state for all those on arv

DROP TABLE IF EXISTS `temp_patient_list`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`patient_program_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO temp_patient_list
SELECT patient_program_id, start_date
    FROM patient_state
    WHERE state = 7 ;

UPDATE mpc_bart2_data.patient_state 
    SET end_date = (SELECT start_date
                    FROM temp_patient_list pp
                    WHERE pp.patient_program_id = mpc_bart2_data.patient_state.patient_program_id)
    WHERE state = 1;

DROP TABLE IF EXISTS `temp_patient_list`;
-- end 

-- inserting state died in patient state

INSERT INTO mpc_bart2_data.patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
    SELECT pp.patient_program_id, 3, MIN(o.obs_datetime), 1, NOW(), (SELECT UUID())
        FROM mpc_bart1_data.obs o LEFT JOIN mpc_bart2_data.patient_program pp ON o.patient_id = pp.patient_id AND pp.program_id = 1
        WHERE o.concept_id = 28 AND o.value_coded = 322 AND o.voided = 0
        GROUP BY o.patient_id;

DROP TABLE IF EXISTS `temp_patient_list`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  KEY (`patient_program_id`),
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO temp_patient_list (patient_program_id, patient_id, start_date)
SELECT ps.patient_program_id, pp.patient_id, ps.start_date
    FROM patient_state ps LEFT JOIN patient_program pp ON ps.patient_program_id = pp.patient_program_id
    WHERE state = 3 ;

UPDATE mpc_bart2_data.patient_state
    SET end_date = (SELECT MIN(start_date)
                        FROM temp_patient_list pp
                        WHERE pp.patient_program_id = mpc_bart2_data.patient_state.patient_program_id
                        GROUP BY pp.patient_program_id)
    WHERE state = 7 AND end_date IS NULL;

UPDATE mpc_bart2_data.patient_program
    SET date_completed = (SELECT MIN(start_date)
                            FROM temp_patient_list pp
                            WHERE pp.patient_program_id = mpc_bart2_data.patient_program.patient_program_id
                            GROUP BY pp.patient_program_id)
    WHERE program_id = 1 AND date_completed IS NULL;

UPDATE person
    SET dead = 1, death_date = (SELECT MIN(start_date) 
                                    FROM temp_patient_list t 
                                    WHERE t.patient_id = person.person_id
					GROUP BY t.patient_id)
    WHERE person_id IN (SELECT patient_id FROM temp_patient_list);

DROP TABLE IF EXISTS `temp_patient_list`;

-- Create Treatment Stopped states
INSERT INTO mpc_bart2_data.patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
    SELECT pp.patient_program_id, 6, o.obs_datetime, 1, NOW(), (SELECT UUID())
        FROM mpc_bart1_data.obs o LEFT JOIN mpc_bart2_data.patient_program pp ON o.patient_id = pp.patient_id AND pp.program_id = 1
        WHERE (o.concept_id = 28 AND o.value_coded = 386 AND o.voided = 0) 
        OR (o.concept_id = 367 AND o.value_coded = 4 AND o.voided = 0)
        GROUP BY DATE(o.obs_datetime), o.patient_id;
        
DROP TABLE IF EXISTS `temp_patient_list`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  KEY (`patient_program_id`),
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO temp_patient_list (patient_program_id, patient_id, start_date)
SELECT ps.patient_program_id, pp.patient_id, ps.start_date
    FROM patient_state ps LEFT JOIN patient_program pp ON ps.patient_program_id = pp.patient_program_id
    WHERE state = 6 ;

UPDATE mpc_bart2_data.patient_state
    SET end_date = (SELECT MIN(start_date)
                        FROM temp_patient_list pp
                        WHERE pp.patient_program_id = mpc_bart2_data.patient_state.patient_program_id
                        GROUP BY pp.patient_program_id)
    WHERE state = 7 AND end_date IS NULL;
    
INSERT INTO patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
SELECT t.patient_program_id, 7, MIN(DATE(obs1.obs_datetime)) AS dispensation_date, 1, ADDTIME(NOW(), -2000), (SELECT UUID())
    FROM temp_patient_list t
        LEFT JOIN (SELECT obs.person_id, DATE(obs.obs_datetime) AS obs_datetime 
                        FROM mpc_bart2_data.drug_order d 
                            LEFT JOIN mpc_bart2_data.orders o ON d.order_id = o.order_id
                            LEFT JOIN mpc_bart2_data.obs ON d.order_id = obs.order_id
                        WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
                            AND quantity > 0
                            AND obs.voided = 0
                            AND o.voided = 0
                            -- AND o.obs_datetime > 
                        GROUP BY obs.person_id, DATE(obs.obs_datetime)) obs1 ON t.patient_id = obs1.person_id AND t.start_date < DATE(obs1.obs_datetime)
    GROUP BY t.patient_id, t.patient_program_id, t.start_date
    HAVING dispensation_date IS NOT NULL;    

UPDATE mpc_bart2_data.patient_program
    SET date_completed = (NULL)
    WHERE current_state_for_program(patient_id, 1, '2012-02-12') = 7;

-- Create Transfer Out states

INSERT INTO mpc_bart2_data.patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
    SELECT pp.patient_program_id, 2, o.obs_datetime, 1, NOW(), (SELECT UUID())
        FROM mpc_bart1_data.obs o LEFT JOIN mpc_bart2_data.patient_program pp ON o.patient_id = pp.patient_id AND pp.program_id = 1
        WHERE (o.concept_id = 28 AND o.value_coded IN (374, 383, 325) AND o.voided = 0) 
        OR (o.concept_id = 372 AND o.value_coded = 325 AND o.voided = 0)
        GROUP BY DATE(o.obs_datetime), o.patient_id;

DROP TABLE IF EXISTS `temp_patient_list`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  KEY (`patient_program_id`),
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO temp_patient_list (patient_program_id, patient_id, start_date)
SELECT ps.patient_program_id, pp.patient_id, ps.start_date
    FROM patient_state ps LEFT JOIN patient_program pp ON ps.patient_program_id = pp.patient_program_id AND pp.program_id = 1
    WHERE state = 2;

UPDATE mpc_bart2_data.patient_state
    SET end_date = (SELECT MIN(start_date)
                        FROM temp_patient_list pp
                        WHERE pp.patient_program_id = mpc_bart2_data.patient_state.patient_program_id
                        GROUP BY pp.patient_program_id)
    WHERE state = 7 AND end_date IS NULL;

UPDATE mpc_bart2_data.patient_program
    SET date_completed = (SELECT MAX(start_date)
                            FROM temp_patient_list pp
                            WHERE pp.patient_program_id = mpc_bart2_data.patient_program.patient_program_id
                            GROUP BY pp.patient_program_id)
    WHERE program_id = 1 AND date_completed IS NULL;
    

INSERT INTO patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
SELECT t.patient_program_id, 7, MIN(DATE(obs1.obs_datetime)) AS dispensation_date, 1, ADDTIME(NOW(), -2000), (SELECT UUID())
    FROM temp_patient_list t
        LEFT JOIN (SELECT obs.person_id, DATE(obs.obs_datetime) AS obs_datetime 
                        FROM mpc_bart2_data.drug_order d 
                            LEFT JOIN mpc_bart2_data.orders o ON d.order_id = o.order_id
                            LEFT JOIN mpc_bart2_data.obs ON d.order_id = obs.order_id
                        WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
                            AND quantity > 0
                            AND obs.voided = 0
                            AND o.voided = 0
                            -- AND o.obs_datetime > 
                        GROUP BY obs.person_id, DATE(obs.obs_datetime)) obs1 ON t.patient_id = obs1.person_id AND t.start_date < DATE(obs1.obs_datetime)
    GROUP BY t.patient_id, t.patient_program_id, t.start_date
    HAVING dispensation_date IS NOT NULL;

DELETE FROM patient_program 
	WHERE date_enrolled IS NULL AND program_id = 1;
