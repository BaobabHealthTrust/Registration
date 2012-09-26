SET FOREIGN_KEY_CHECKS = 0;

SET @'start_date' = '1999-01-01';

SET @'end_date' = '2012-02-16 05:00:00';

-- Remove drug orders

DELETE FROM drug_order WHERE order_id IN 
	(SELECT order_id FROM orders WHERE encounter_id IN
		(SELECT encounter_id FROM encounter WHERE encounter_type IN 
			(SELECT encounter_type_id FROM encounter_type WHERE name IN ("APPOINTMENT", "HIV STAGING", "ART VISIT", "TREATMENT", "ART ADHERENCE", "DISPENSING"))
				AND encounter_datetime BETWEEN @'start_date' AND @'end_date'));

DELETE FROM obs WHERE encounter_id IN 
	(SELECT encounter_id FROM encounter WHERE encounter_type IN 
		(SELECT encounter_type_id FROM encounter_type WHERE name IN ("APPOINTMENT", "HIV STAGING", "ART VISIT", "TREATMENT", "ART ADHERENCE", "DISPENSING"))
			AND encounter_datetime BETWEEN @'start_date' AND @'end_date');


DELETE FROM orders WHERE encounter_id IN
		(SELECT encounter_id FROM encounter WHERE encounter_type IN 
			(SELECT encounter_type_id FROM encounter_type WHERE name IN ("APPOINTMENT", "HIV STAGING", "ART VISIT", "TREATMENT", "ART ADHERENCE", "DISPENSING"))
				AND encounter_datetime BETWEEN @'start_date' AND @'end_date');


DELETE FROM encounter WHERE encounter_type IN 
		(SELECT encounter_type_id FROM encounter_type WHERE name IN ("APPOINTMENT", "HIV STAGING", "ART VISIT", "TREATMENT", "ART ADHERENCE", "DISPENSING"))
			AND encounter_datetime BETWEEN @'start_date' AND @'end_date';

SET FOREIGN_KEY_CHECKS = 1;