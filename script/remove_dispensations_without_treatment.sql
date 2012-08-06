DELETE FROM obs 
WHERE concept_id = 2834 AND order_id  IS NULL OR order_id = 0; 

DELETE FROM encounter WHERE encounter_id NOT IN(SELECT encounter_id FROM obs);

