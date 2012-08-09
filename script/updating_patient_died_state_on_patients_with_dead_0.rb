#updating the last patient state to patient_died if the patient has the patient died state in bart1
def updating_patient_died_state_on_patients_with_dead_0
	#find the patient_ids
	persons = Person.find_by_sql("SELECT * FROM bart1.patient_historical_outcomes WHERE outcome_concept_id = 322 and patient_id NOT IN(SELECT patient_id FROM bart2.patient_program p INNER JOIN bart2.patient_state s USING (patient_program_id) WHERE s.state = 3)")#.map{|patient| patient.patient_id}

	#loop through each patient_id to find the patient_program then patient_states
	program_id = Program.find_by_name('HIV PROGRAM').program_id
	persons.each do |person|
		person_obj = Person.find_by_person_id(person.patient_id)
		patient_program = PatientProgram.all(:conditions => ["patient_id = ? AND program_id = ?", person_obj.patient.patient_id, program_id ])

		patient_program_id = patient_program.map{|patient| patient.patient_program_id} 

		#find the current patient_states
		patient_states = patient_program.last.patient_states

		current_active_state = patient_states.last
		current_active_state.end_date = person.outcome_date.to_date

		patient_died_concept_id = ConceptName.find_by_name('PATIENT DIED').concept_id
		patient_died_state = ProgramWorkflowState.find(
																										:first,
																										:conditions => ["concept_id IN (?)",
																										patient_died_concept_id]
																										).program_workflow_state_id

		#update the current_state
		patient_state = patient_program.last.patient_states.build(
			:state => patient_died_state,
			:start_date => person.outcome_date.to_date)

		current_active_state.save if patient_state.save
				
		updated_state_concept_name = "PATIENT DIED"

		if updated_state_concept_name.match(/DIED/i)
			person_obj.dead = 1
			person_obj.save
		end
	end
end
