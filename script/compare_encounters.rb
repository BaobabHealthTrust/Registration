encounter_params = ARGV

encounter_pair = { 
										"registration" => [1,9],
										"staging" => [5, 52],
										"dispense" => [3, 54],
										"consultation" => [2 ,53],
										"adherence" => [2 ,68],
										"treatment" => [2 ,25]
								  }

def compare_encounters(bart1_encounter_type_id, bart2_encounter_type_id)
		Encounter.find_by_sql("
		SELECT b1e.encounter_id, b1e.patient_id, b1e.encounter_datetime,
						b1e.encounter_type
			FROM mpc_bart1_data.encounter b1e LEFT JOIN mpc_bart2_data.encounter b2e ON b2e.encounter_type = #{bart2_encounter_type_id}
									AND b1e.patient_id = b2e.patient_id AND
									b1e.encounter_datetime = b2e.encounter_datetime
			WHERE b1e.encounter_type = #{bart1_encounter_type_id}
			AND b2e.patient_id IS NULL;
	")
end

total = 0

encounter_params.each do |p|
	 if encounter_pair[p]
			puts  "#{p.capitalize} >>"
			
			enc = compare_encounters(encounter_pair[p].first, encounter_pair[p].second)
			File.open("/tmp/#{p}.DAT", 'w') do |f|
				
				#f.puts "patient_id,encounter_id,encounter_type,encounter_datetime"
				enc.each do |e|
					#f.puts "#{e.patient_id},#{e.encounter_id},#{e.encounter_type},#{e.encounter_datetime.strftime("%Y-%m-%d %H:%M:%S")}"
					f.puts "#{e.encounter_id}"
				end
				
			end
	 		puts "	Records found : #{enc.size} \n"
	 		puts "	location: '/tmp/#{p}.DAT' \n\n"
	 end
end
