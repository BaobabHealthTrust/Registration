DELETE FROM patient_state WHERE state = 7;

INSERT INTO patient_state (patient_program_id, state, start_date, creator, uuid)
(SELECT ps.patient_program_id, 7, DATE(obs1.obs_datetime), ps.creator, (SELECT UUID())
FROM patient_program pp
INNER JOIN (SELECT obs.person_id, MIN(obs.obs_datetime) AS obs_datetime FROM drug_order d
    LEFT JOIN orders o ON d.order_id = o.order_id
    LEFT JOIN obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
        AND quantity > 0
        AND obs.voided = 0
    GROUP BY obs.person_id) obs1 ON pp.patient_id = obs1.person_id AND pp.program_id = 1 
INNER JOIN patient_state ps ON pp.patient_program_id = ps.patient_program_id 
    AND DATE(obs1.obs_datetime) = DATE(ps.start_date)
WHERE 7 NOT IN (SELECT state FROM patient_state ps1 WHERE ps1.patient_program_id = pp.patient_program_id 
                AND DATE(ps1.start_date) =  DATE(obs1.obs_datetime))
GROUP BY pp.patient_id, DATE(obs1.obs_datetime));

