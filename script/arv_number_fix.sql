UPDATE patient_identifier
	SET identifier = CONCAT_WS('-ARV-', SUBSTRING(identifier, 1, 3), RTRIM(LTRIM(RIGHT(identifier,LENGTH(identifier) - 3))))
	WHERE identifier_type = (SELECT patient_identifier_type_id FROM patient_identifier_type WHERE name = "ARV Number")	
	AND INSTR(identifier, '-ARV-') = 0
