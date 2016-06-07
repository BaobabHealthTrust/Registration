class Cohort

  attr_accessor :start_date, :end_date

  @@first_registration_date = nil
  @@program_id = nil

  # Initialize class
  def initialize(start_date, end_date)
    @start_date = start_date #"#{start_date} 00:00:00"
    @end_date = "#{end_date} 23:59:59"

    @@first_registration_date = PatientProgram.find(
      :first,
      :conditions =>["program_id = ? AND voided = 0",1],
      :order => 'date_enrolled ASC'
    ).date_enrolled.to_date rescue nil

    @@program_id = Program.find_by_name('HIV PROGRAM').program_id
  end
  
	def registration_services(start_date = @start_date, end_date = @end_date)

    services_concept_id = ConceptName.find_by_name('SERVICES').concept_id
    
    registration_services_hash = {} ; services = []
    registration_services_hash['SERVICES'] = {'Casualty' => 0,'Dental' => 0,'Eye' => 0,'Family Planing' => 0,'Medical' => 0,'OB/Gyn' => 0,'Orthopedics' => 0,'Other' => 0,'Pediatrics' => 0,'Skin' => 0,'STI Clinic' => 0,'Surgical' => 0} 

    services = PatientProgram.find_by_sql("SELECT patient_id,value_text services,obs_datetime FROM obs
                                INNER JOIN patient p ON p.patient_id = obs.person_id
                                INNER JOIN concept_name n ON n.concept_id = obs.concept_id
                                WHERE obs.obs_datetime >='#{start_date}'
                                AND obs.obs_datetime <= '#{end_date}' 
                                AND obs.concept_id = #{services_concept_id}
                                AND n.name != ''
                                GROUP BY obs.obs_id").map{ | value | value.services }
                                
		( services || [] ).each do | service |
				  if service == 'Casualty'
				    registration_services_hash['SERVICES']['Casualty'] += 1
				  elsif service == 'Eye'
				    registration_services_hash['SERVICES']['Eye'] += 1
				  elsif service == 'Family Planing'
				    registration_services_hash['SERVICES']['Family Planing'] += 1
				  elsif service == 'Dental'
				    registration_services_hash['SERVICES']['Dental'] += 1
				  elsif service == 'Medical'
				    registration_services_hash['SERVICES']['Medical'] += 1
				  elsif service == 'OB/Gyn'
				    registration_services_hash['SERVICES']['OB/Gyn'] += 1
				  elsif service == 'Orthopedics'
				    registration_services_hash['SERVICES']['Orthopedics'] += 1
				  elsif service == 'Pediatrics'
				    registration_services_hash['SERVICES']['Pediatrics'] += 1
				  elsif service == ' Skin '
				    registration_services_hash['SERVICES']['Skin'] += 1
				  elsif service == 'STI Clinic'
				    registration_services_hash['SERVICES']['STI Clinic'] += 1
				  elsif service == 'Surgical'
				    registration_services_hash['SERVICES']['Surgical'] += 1
				  else
						registration_services_hash['SERVICES']['Other'] += 1
				  end
				end
				registration_services_hash
  end

  def registration_patient_services(start_date = @start_date, end_date = @end_date)

    services_concept_id = ConceptName.find_by_name('SERVICES').concept_id
    
    registration_services_hash = {} ; services = []
    registration_services_hash['SERVICES'] = {'Casualty' => 0,'Dental' => 0,'Eye' => 0,'Family Planing' => 0,'Medical' => 0,'OB/Gyn' => 0,'Orthopedics' => 0,'Other' => 0,'Pediatrics' => 0,'Skin' => 0,'STI Clinic' => 0,'Surgical' => 0} 

    services = []
    PatientProgram.find_by_sql("SELECT patient_id,value_text services,obs_datetime FROM obs
                                INNER JOIN patient p ON p.patient_id = obs.person_id
                                INNER JOIN concept_name n ON n.concept_id = obs.concept_id
                                WHERE obs.obs_datetime >='#{start_date}'
                                AND obs.obs_datetime <= '#{end_date}' 
                                AND obs.concept_id = #{services_concept_id}
                                AND n.name != ''
                                AND obs.voided = 0
                                GROUP BY obs.obs_id").each do | value | 
                                  services << [value.patient_id, value.services]
                                end
	end
	
  def referrals(start_date = @start_date, end_date = @end_date)
    outpatient_reception_encounter = EncounterType.find_by_name("OUTPATIENT RECEPTION").id
    referred_from_concept = ConceptName.find_by_name("REFERRED FROM").concept_id
    
    Observation.find_by_sql("SELECT l.name lname, COUNT(l.name) lcount FROM obs o INNER JOIN encounter e 
														ON o.encounter_id = e.encounter_id
														INNER JOIN location l
														ON l.location_id = o.value_text
														WHERE e.encounter_type = #{outpatient_reception_encounter} 
														AND o.concept_id = #{referred_from_concept} 
														AND e.date_created BETWEEN '#{start_date}' AND '#{end_date}' 
														GROUP BY l.name;").map{ | value | {value.lname => value.lcount} }
		
  end
	
end
