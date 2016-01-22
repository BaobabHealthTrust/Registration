def find

	Person.find_by_sql("
SELECT DISTINCT p1 FROM (
SELECT bart1.p1, bart1.drug_id, o2.value_drug, bart1.total_drugs, SUM(IF(ISNULL(value_numeric), 0, value_numeric)) AS total_drugs_bart2, bart1.encounter_datetime, o2.obs_datetime, o2.voided
    FROM 
(
SELECT  e1.patient_id AS p1, e1.encounter_datetime, 
        bbm.bart2_id AS drug_id, SUM(IF(ISNULL(d1.quantity), 0, d1.quantity)) AS total_drugs
        FROM mpc_bart1_data.encounter e1 LEFT JOIN
                mpc_bart1_data.orders o1 ON o1.encounter_id=e1.encounter_id
                LEFT JOIN mpc_bart1_data.drug_order d1 ON o1.order_id=d1.order_id
                LEFT JOIN mpc_bart2_data.bart1_to_bart2_drug_map bbm ON bbm.bart1_id = d1.drug_inventory_id
        WHERE e1.encounter_type = 3 AND o1.encounter_id IS NOT NULL
        GROUP BY e1.patient_id, DATE(e1.encounter_datetime), bbm.bart1_id
) AS bart1
    LEFT JOIN mpc_bart2_data.encounter e2 ON bart1.encounter_datetime = e2.encounter_datetime AND bart1.p1 = e2.patient_id
    LEFT JOIN mpc_bart2_data.obs o2 ON o2.encounter_id=e2.encounter_id AND bart1.drug_id=o2.value_drug
WHERE concept_id = 2834  AND e2.encounter_datetime <= TIMESTAMP('2012-02-15 11:59:59')
GROUP BY bart1.p1 , DATE(e2.encounter_datetime), o2.value_drug
HAVING bart1.total_drugs != total_drugs_bart2) missing
	")

end

print "\e[H\e[2J"

patients=find
f = File.open("/tmp/patients_id_with_missing_orders.DAT", 'w')

patients.each do |p|
	f.puts p.p1
	print "\r\r\r#{p.p1}"
end

f.close

puts "\r\rTotal Number of patients: #{patients.size}\n#{'/tmp/patients_id_with_missing_orders.DAT'}"
