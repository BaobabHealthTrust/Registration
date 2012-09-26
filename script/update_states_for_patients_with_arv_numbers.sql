INSERT INTO patient_state (patient_program_id, state, start_date, creator, uuid)
(SELECT ps.patient_program_id, 7, DATE(obs1.obs_datetime), ps.creator, (SELECT UUID())
FROM bart2.patient_program pp
INNER JOIN (SELECT obs.person_id, MIN(obs.obs_datetime) AS obs_datetime FROM bart2.drug_order d
    LEFT JOIN bart2.orders o ON d.order_id = o.order_id
    LEFT JOIN bart2.obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
        AND quantity > 0
        AND obs.voided = 0
    GROUP BY obs.person_id) obs1 ON pp.patient_id = obs1.person_id AND pp.program_id = 1 
INNER JOIN patient_state ps ON pp.patient_program_id = ps.patient_program_id 
    AND DATE(obs1.obs_datetime) = DATE(ps.start_date)
WHERE pp.patient_id IN (SELECT sp.main_patient FROM (
                        SELECT p.patient_id AS main_patient, prd.patient_id
                        FROM bart1.patient p
                        LEFT JOIN bart1.patient_registration_dates prd
                            ON p.patient_id = prd.patient_id
                        WHERE p.patient_id IN (
                            SELECT patient_id
                            FROM bart2.patient_identifier 
                            WHERE identifier_type=4 
                                AND voided=0 
                                AND patient_id NOT IN ( SELECT pp.patient_id 
                                                        FROM bart2.patient_program pp
                                                             INNER JOIN bart2.patient_state ps 
                                                             ON pp.patient_program_id = ps.patient_program_id
                                                        WHERE ps.state =7 
                                                               -- AND ps.end_date IS NULL 
                                                               AND pp.program_id=1 
                                                               AND ps.voided=0))
                        HAVING prd.patient_id IS NOT NULL) sp
                        )
GROUP BY pp.patient_id, DATE(obs1.obs_datetime))