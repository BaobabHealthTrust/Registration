SET @'set_date' = '2012-01-01';

UPDATE bart2.patient_state 
SET voided = 1
WHERE patient_program_id IN (
                            SELECT patient_program_id
                            FROM bart2.patient_program bpp
                            INNER JOIN (SELECT p.patient_id
                                        FROM bart2.patient_program pp 
                                             INNER JOIN bart2.patient_state ps
                                                 ON pp.patient_program_id = ps.patient_program_id
                                             INNER JOIN bart2.patient p 
                                                ON p.patient_id = pp.patient_id 
                                        WHERE ps.state =7 
                                            AND p.voided=0 AND pp.voided=0 AND ps.voided=0 
                                            AND p.date_created < @'set_date' AND ps.start_date < @'set_date' 
                                            AND p.patient_id NOT IN (SELECT r.patient_id 
                                                                     FROM bart1.patient_registration_dates r, patient p 
                                                                     WHERE r.patient_id = p.patient_id 
                                                                     AND p.date_created < @'set_date')
                                        GROUP BY patient_id) pat
                                 ON bpp.patient_id = pat.patient_id
                            WHERE bpp.program_id = 1
                            )
AND state = 7 AND start_date < @'set_date';

UPDATE bart2.orders
SET voided = 1
WHERE encounter_id IN ( SELECT b2e.encounter_id
                        FROM bart2.encounter b2e
                        INNER JOIN (SELECT p.patient_id
                                        FROM bart2.patient_program pp 
                                             INNER JOIN bart2.patient_state ps
                                                 ON pp.patient_program_id = ps.patient_program_id
                                             INNER JOIN bart2.patient p 
                                                ON p.patient_id = pp.patient_id 
                                        WHERE ps.state =7 
                                            AND p.voided=0 AND pp.voided=0 AND ps.voided=0 
                                            AND p.date_created < @'set_date' AND ps.start_date < @'set_date' 
                                            AND p.patient_id NOT IN (SELECT r.patient_id 
                                                                     FROM bart1.patient_registration_dates r, patient p 
                                                                     WHERE r.patient_id = p.patient_id 
                                                                     AND p.date_created < @'set_date')
                                        GROUP BY patient_id) pat
                            ON b2e.patient_id = pat.patient_id
                        WHERE b2e.encounter_type = 54 AND b2e.encounter_datetime < @'set_date');



UPDATE bart2.encounter
SET voided = 1
WHERE patient_id IN (   SELECT p.patient_id
                        FROM bart2.patient_program pp 
                             INNER JOIN bart2.patient_state ps
                                 ON pp.patient_program_id = ps.patient_program_id
                             INNER JOIN bart2.patient p 
                                ON p.patient_id = pp.patient_id 
                        WHERE ps.state =7 
                            AND p.voided=0 AND pp.voided=0 AND ps.voided=0 
                            AND p.date_created < @'set_date' AND ps.start_date < @'set_date' 
                            AND p.patient_id NOT IN (SELECT r.patient_id 
                                                     FROM bart1.patient_registration_dates r, patient p 
                                                     WHERE r.patient_id = p.patient_id 
                                                     AND p.date_created < @'set_date')
                        GROUP BY patient_id) 
AND encounter_type = 54 AND encounter_datetime < @'set_date';
