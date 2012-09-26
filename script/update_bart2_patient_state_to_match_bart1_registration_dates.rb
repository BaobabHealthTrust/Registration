
patient_list = []
conditions = ""

if patients_list.blank?
  condition = "WHERE patient_id IN (#{patient_list})
                        AND prd.registration_date = ps.start_date"
else
  condition = "WHERE prd.registration_date = ps.start_date"
end

query = " SELECT bps.patient_state_id
          FROM bart2.patient_program bpp
          INNER JOIN (
                      SELECT prd.patient_id, prd.registration_date
                      FROM bart1.patient_registration_dates prd
                        LEFT JOIN bart1.patient_start_dates psd USING(patient_id)
                        LEFT JOIN bart2.patient_program pp USING(patient_id)
                        LEFT JOIN bart2.patient_state ps ON 
                                  pp.patient_program_id = ps.patient_program_id AND state = 7 
                      #{condition} 
                      GROUP BY prd.patient_id
                      ORDER BY patient_id, registration_date) os
              ON bpp.patient_id = os.patient_id
          INNER JOIN bart2.patient_state bps
              ON bpp.patient_program_id = bps.patient_program_id
              AND bps.start_date < os.registration_date
          WHERE bpp.program_id = 1 AND bps.state = 7 "

states_array = PatientState.find_by_sql(query)

states_array.each do |state_id|
  ps = PatientState.find(state_id[:patient_state_id])
  ps.void
end
