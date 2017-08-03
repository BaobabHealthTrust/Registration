class ApplicationController < GenericApplicationController

  def next_task(patient)
    session_date = session[:datetime].to_date rescue Date.today
    task = main_next_task(Location.current_location, patient,session_date)
    begin
      return task.url if task.present? && task.url.present?
      return "/patients/show/#{patient.id}" 
    rescue
      return "/patients/show/#{patient.id}" 
    end
  end

  def tb_next_form(location , patient , session_date = Date.today)
    task = Task.first rescue Task.new()
    
    if patient.patient_programs.in_uncompleted_programs(['TB PROGRAM', 'MDR-TB PROGRAM']).blank?
      #Patient has no active TB program ...'
      ids = Program.find(:all,:conditions =>["name IN(?)",['TB PROGRAM', 'MDR-TB PROGRAM']]).map{|p|p.id}
      last_active = PatientProgram.find(:first,:order => "date_completed DESC,date_created DESC",
                    :conditions => ["patient_id = ? AND program_id IN(?)",patient.id,ids])

      if not last_active.blank?
        state = last_active.patient_states.last.program_workflow_state.concept.fullname rescue 'NONE'
        task.encounter_type = state
        task.url = "/patients/show/#{patient.id}"
        return task
      end
    end
     
    #we get the sequence of clinic questions(encounters) form the GlobalProperty table
    #property: list.of.clinical.encounters.sequentially
    #property_value: ?

    #valid privileges for ART visit ....
    #1. Manage TB Reception Visits - TB RECEPTION
    #2. Manage TB initial visits - TB_INITIAL
    #3. Manage Lab orders - LAB ORDERS
    #4. Manage sputum submission - SPUTUM SUBMISSION
    #5. Manage Lab results - LAB RESULTS
    #6. Manage TB registration - TB REGISTRATION
    #7. Manage TB followup - TB VISIT
    #8. Manage HIV status updates - UPDATE HIV STATUS
    #8. Manage prescriptions - TREATMENT
    #8. Manage dispensations - DISPENSING

    tb_encounters =  [
                      'SOURCE OF REFERRAL','UPDATE HIV STATUS','LAB ORDERS',
                      'SPUTUM SUBMISSION','LAB RESULTS','TB_INITIAL',
                      'TB RECEPTION','TB REGISTRATION','TB VISIT','TB ADHERENCE',
                      'TB CLINIC VISIT','HIV CLINIC REGISTRATION','VITALS','HIV STAGING',
                      'HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING'
                     ] 
    user_selected_activities = current_user.activities.collect{|a| a.upcase }.join(',') rescue []
    if user_selected_activities.blank? or tb_encounters.blank?
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reason_for_art = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''
    
    tb_reception_attributes = []
    tb_obs = Encounter.find(:first,:order => "encounter_datetime DESC",
                    :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                    session_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id]).observations rescue []
    (tb_obs || []).each do | obs |
      tb_reception_attributes << obs.to_s.squish.strip 
    end

    tb_encounters.each do | type |
      task.encounter_type = type 

      case type
        when 'SOURCE OF REFERRAL'
          next if PatientService.patient_tb_status(patient).match(/treatment/i)

          if ['Lighthouse','Martin Preuss Centre'].include?(Location.current_health_center.name)
            if not (location.current_location.name.match(/Chronic Cough/) or 
              location.current_location.name.match(/TB Sputum Submission Station/i))
              next
            end
          end

          source_of_referral = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["encounter_datetime <= ?
                                      AND patient_id = ? AND encounter_type = ?",
                                      (session_date.to_date).strftime('%Y-%m-%d 23:59:59'),
                                      patient.id,EncounterType.find_by_name(type).id])

          if source_of_referral.blank? and user_selected_activities.match(/Manage Source of Referral/i) 
            task.url = "/encounters/new/source_of_referral?patient_id=#{patient.id}"
            return task
          elsif source_of_referral.blank? and not user_selected_activities.match(/Manage Source of Referral/i) 
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
        when 'UPDATE HIV STATUS'
          next_task = PatientService.checks_if_labs_results_are_avalable_to_be_shown(patient , session_date , task)
          return next_task unless next_task.blank?

          next if PatientService.patient_hiv_status(patient).match(/Positive/i)
          if not patient.patient_programs.blank?
            next if patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') 
          end

          hiv_status = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["encounter_datetime >= ? AND encounter_datetime <= ?
                                      AND patient_id = ? AND encounter_type = ?",(session_date.to_date - 3.month).strftime('%Y-%m-%d 00:00:00'),
                                      (session_date.to_date).strftime('%Y-%m-%d 23:59:59'),patient.id,EncounterType.find_by_name(type).id])

          if hiv_status.observations.map{|s|s.to_s.split(':').last.strip}.include?('Positive')
            next 
          end if not hiv_status.blank?

          if hiv_status.blank? and user_selected_activities.match(/Manage HIV Status Visits/i)
            task.url = "/encounters/new/hiv_status?show&patient_id=#{patient.id}"
            return task
          elsif hiv_status.blank? and not user_selected_activities.match(/Manage HIV Status Visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end

          xray = Observation.find(Observation.find(:first,
                    :order => "obs_datetime DESC,date_created DESC", 
                    :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= ?", 
                    patient.id, ConceptName.find_by_name("Refer to x-ray?").concept_id,
                    session_date.to_date])).to_s.strip.squish.upcase rescue ''

          if xray.match(/: Yes/i)
            task.encounter_type = "Xray scan"
            task.url = "/patients/show/#{patient.id}"
            return task
          end

          
          refered_to_htc_concept_id = ConceptName.find_by_name("Refer to HTC").concept_id

          refered_to_htc = Observation.find(Observation.find(:first,
                    :order => "obs_datetime DESC,date_created DESC",
                    :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) <= ?", 
                    patient.id, refered_to_htc_concept_id,
                    session_date.to_date])).to_s.strip.squish.upcase rescue nil

          if ('Refer to HTC: Yes'.upcase == refered_to_htc)
            task.encounter_type = 'Refered to HTC'
            task.url = "/patients/show/#{patient.id}"
            return task
          end

          if ('Refer to HTC: NO'.upcase == refered_to_htc) and location.name.upcase == "TB HTC"
            refered_to_htc = Encounter.find(:first,
              :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id",
              :order => "encounter_datetime DESC,date_created DESC",
              :conditions => ["patient_id = ? and concept_id = ? AND value_coded = ?",
              patient.id,refered_to_htc_concept_id,ConceptName.find_by_name('YES').concept_id])

            loc_name = refered_to_htc.observations.map do | obs |
              next unless obs.to_s.match(/Workstation location/i)
              obs.to_s.gsub('Workstation location:','').squish 
            end

            task.encounter_type = "#{loc_name}"
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'VITALS' 

          if not PatientService.patient_hiv_status(patient).match(/Positive/i) and not PatientService.patient_tb_status(patient).match(/treatment/i)
            next
          end 

          first_vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["patient_id = ? AND encounter_type = ?",
                                  patient.id,EncounterType.find_by_name(type).id])

          if not PatientService.patient_tb_status(patient).match(/treatment/i) and not tb_reception_attributes.include?('Any need to see a clinician: Yes')
            next
          end if not PatientService.patient_hiv_status(patient).match(/Positive/i)

          if PatientService.patient_tb_status(patient).match(/treatment/i) and not PatientService.patient_hiv_status(patient).match(/Positive/i)
            next
          end if not first_vitals.blank?

          vitals = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if vitals.blank? and user_selected_activities.match(/Manage Vitals/i) 
            task.encounter_type = 'VITALS'
            task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
            return task
          elsif vitals.blank? and not user_selected_activities.match(/Manage Vitals/i) 
            task.encounter_type = 'VITALS'
            task.url = "/patients/show/#{patient.id}"
            return task
          end 

        when 'TB RECEPTION'
          reception = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                     :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                     session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if reception.blank? and user_selected_activities.match(/Manage TB Reception Visits/i)
            task.url = "/encounters/new/tb_reception?show&patient_id=#{patient.id}"
            return task
          elsif reception.blank? and not user_selected_activities.match(/Manage TB Reception Visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'LAB ORDERS'
          next if PatientService.patient_tb_status(patient).match(/treatment/i)

          if ['Lighthouse','Martin Preuss Centre'].include?(Location.current_health_center.name)
            if not (location.current_location.name.match(/Chronic Cough/) or 
              location.current_location.name.match(/TB Sputum Submission Station/i))
              next
            end
          end

          lab_order = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

          next_lab_encounter =  PatientService.next_lab_encounter(patient , lab_order , session_date)

          if (lab_order.encounter_datetime.to_date == session_date.to_date)
            task.encounter_type = 'NONE'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not lab_order.blank? 

          if user_selected_activities.match(/Manage Lab Orders/i)
            task.url = "/encounters/new/lab_orders?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage Lab Orders/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (next_lab_encounter.blank? or next_lab_encounter == 'NO LAB ORDERS')
        when 'SPUTUM SUBMISSION'
          previous_sputum_sub = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

          next_lab_encounter =  PatientService.next_lab_encounter(patient , previous_sputum_sub , session_date)

          if (previous_sputum_sub.encounter_datetime.to_date == session_date.to_date)
            task.encounter_type = 'NONE'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not previous_sputum_sub.blank? 

          if not next_lab_encounter.blank?
            next
          end if not (next_lab_encounter == "NO LAB ORDERS")

          if next_lab_encounter.blank? and previous_sputum_sub.encounter_datetime.to_date == session_date.to_date
            task.encounter_type = 'NONE'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not previous_sputum_sub.blank?

          if user_selected_activities.match(/Manage Sputum Submissions/i)
            task.url = "/encounters/new/sputum_submission?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage Sputum Submissions/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (next_lab_encounter.blank?)
        when 'LAB RESULTS'
          lab_result = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

          next_lab_encounter =  PatientService.next_lab_encounter(patient , lab_result , session_date)

          if not next_lab_encounter.blank?
            next
          end if not (next_lab_encounter == "NO LAB ORDERS")

          if user_selected_activities.match(/Manage Lab Results/i)
            task.url = "/encounters/new/lab_results?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage Lab Results/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (next_lab_encounter.blank?)
        when 'TB CLINIC VISIT'

          next if PatientService.patient_tb_status(patient).match(/treatment/i)

          obs_ans = Observation.find(Observation.find(:first, 
                    :order => "obs_datetime DESC,date_created DESC",
                    :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",patient.id, 
                    ConceptName.find_by_name("ANY NEED TO SEE A CLINICIAN").concept_id,session_date])).to_s.strip.squish rescue nil

          if not obs_ans.blank?
            next if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
            if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: YES/i)
              tb_visits = Encounter.find(:all,:order => "encounter_datetime DESC,date_created DESC",
                            :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                            session_date.to_date,patient.id,EncounterType.find_by_name('TB VISIT').id])
              if (tb_visits.length == 1) 
                roles = current_user_roles.join(',') rescue ''
                if not (roles.match(/Clinician/i) or roles.match(/Doctor/i))
                    task.encounter_type = 'TB VISIT'
                    task.url = "/patients/show/#{patient.id}"
                    return task
                elsif user_selected_activities.match(/Manage TB Treatment Visits/i)
                  task.encounter_type = 'TB VISIT'
                  task.url = "/encounters/new/tb_visit?show&patient_id=#{patient.id}"
                  return task
                elsif not user_selected_activities.match(/Manage TB Treatment Visits/i)
                  task.encounter_type = 'TB VISIT'
                  task.url = "/patients/show/#{patient.id}"
                  return task
                end
              end
            end
          end

          visit_type = Observation.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?", 
                    patient.id, ConceptName.find_by_name("TYPE OF VISIT").concept_id,session_date])).to_s.strip.squish rescue nil

          if not visit_type.blank?  #and obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
            next if visit_type.match(/Reason for visit: Follow-up/i)
          end if obs_ans.blank?

          clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])


          if clinic_visit.blank? and user_selected_activities.match(/Manage TB clinic visits/i)
            task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
            return task
          elsif clinic_visit.blank? and not user_selected_activities.match(/Manage TB clinic visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end 

          clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          clinic_visit_obs = clinic_visit.observations.map{|o|
            o.to_s.upcase.strip.squish
          }.include?("REFER TO X-RAY?: YES") rescue false

          if clinic_visit_obs
            if user_selected_activities.match(/Manage TB clinic visits/i)
              task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
              return task
            elsif not user_selected_activities.match(/Manage TB clinic visits/i)
              task.url = "/patients/show/#{patient.id}"
              return task
            end 
          end if clinic_visit_obs

        when 'TB_INITIAL'
          #next if not patient.tb_status.match(/treatment/i)
          tb_initial = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          next if not tb_initial.blank?

          #enrolled_in_tb_program = patient.patient_programs.collect{|p|p.program.name}.include?('TB PROGRAM') rescue false

          if user_selected_activities.match(/Manage TB initial visits/i)
            task.url = "/encounters/new/tb_initial?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage TB initial visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
        when 'HIV CLINIC REGISTRATION'
          next unless PatientService.patient_hiv_status(patient).match(/Positive/i)
        
          enrolled_in_hiv_program = Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",patient.id, 
            ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil
      
          next unless enrolled_in_hiv_program == 'YES'
  
          enrolled_in_hiv_program = patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue false
          next if enrolled_in_hiv_program 

          hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                                         patient.id,EncounterType.find_by_name(type).id],
                                         :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          if hiv_clinic_registration.blank? and user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/encounters/new/hiv_clinic_registration?show&patient_id=#{patient.id}"
            return task
          elsif hiv_clinic_registration.blank? and not user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'HIV STAGING'
          #checks if vitals have been taken already 
          vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
          return vitals unless vitals.blank?

          enrolled_in_hiv_program = Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",patient.id, 
            ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil

          next if enrolled_in_hiv_program == 'NO'
          next if patient.patient_programs.blank?
          next if not patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') 

          next unless PatientService.patient_hiv_status(patient).match(/Positive/i)
          hiv_staging = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          if hiv_staging.blank? and user_selected_activities.match(/Manage HIV staging visits/i) 
            task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}"
            return task
          elsif hiv_staging.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?)
        when 'TB REGISTRATION'
          #checks if patient needs to be stage before continuing
          next_task = PatientService.need_art_enrollment(task,patient,location,session_date,user_selected_activities,reason_for_art)
          return next_task if not next_task.blank? and user_selected_activities.match(/Manage HIV staging visits/i)

          next unless PatientService.patient_tb_status(patient).match(/treatment/i)
          tb_registration = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          next if not tb_registration.blank?
          #enrolled_in_tb_program = patient.patient_programs.collect{|p|p.program.name}.include?('TB PROGRAM') rescue false

          #checks if vitals have been taken already 
          vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
          return vitals unless vitals.blank?

    
          if user_selected_activities.match(/Manage TB Registration visits/i)
            task.url = "/encounters/new/tb_registration?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage TB Registration visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'TB VISIT'
          if PatientService.patient_is_child?(patient) or PatientService.patient_hiv_status(patient).match(/Positive/i)
            clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id])
            #checks if vitals have been taken already 
            vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
            return vitals unless vitals.blank?


            if clinic_visit.blank? and user_selected_activities.match(/Manage TB Clinic Visits/i)
              task.encounter_type = "TB CLINIC VISIT"
              task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
              return task
            elsif clinic_visit.blank? and not user_selected_activities.match(/Manage TB Clinic Visits/i)
              task.encounter_type = "TB CLINIC VISIT"
              task.url = "/patients/show/#{patient.id}"
              return task
            end if not PatientService.patient_tb_status(patient).match(/treatment/i)
          end

          #checks if vitals have been taken already 
          vitals = PatientService.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
          return vitals unless vitals.blank?

          if not PatientService.patient_tb_status(patient).match(/treatment/i)
            next
          end if not tb_reception_attributes.include?('Reason for visit: Follow-up')

          tb_registration = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name('TB REGISTRATION').id])

          tb_followup = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if (tb_followup.encounter_datetime.to_date == tb_registration.encounter_datetime.to_date)
			      next
          end if not tb_followup.blank? and not tb_registration.blank?

          if tb_registration.blank?
            task.encounter_type = 'TB PROGRAM ENROLMENT'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not tb_reception_attributes.include?('Reason for visit: Follow-up')

          if tb_followup.blank? and user_selected_activities.match(/Manage TB Treatment Visits/i)
            task.url = "/encounters/new/tb_visit?show&patient_id=#{patient.id}"
            return task
          elsif tb_followup.blank? and not user_selected_activities.match(/Manage TB Treatment Visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end

          obs_ans = Observation.find(Observation.find(:first, 
                    :order => "obs_datetime DESC,date_created DESC",
                    :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?",patient.id, 
                    ConceptName.find_by_name("ANY NEED TO SEE A CLINICIAN").concept_id,session_date])).to_s.strip.squish rescue nil

          if not obs_ans.blank?
            next if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
            if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: YES/i)
              tb_visits = Encounter.find(:all,:order => "encounter_datetime DESC,date_created DESC",
                            :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                            session_date.to_date,patient.id,EncounterType.find_by_name('TB VISIT').id])
              if (tb_visits.length == 1) 
                roles = current_user_roles.join(',') rescue ''
                if not (roles.match(/Clinician/i) or roles.match(/Doctor/i))
                    task.encounter_type = 'TB VISIT'
                    task.url = "/patients/show/#{patient.id}"
                    return task
                elsif user_selected_activities.match(/Manage TB Treatment Visits/i)
                  task.encounter_type = 'TB VISIT'
                  task.url = "/encounters/new/tb_visit?show&patient_id=#{patient.id}"
                  return task
                elsif not user_selected_activities.match(/Manage TB Treatment Visits/i)
                  task.encounter_type = 'TB VISIT'
                  task.url = "/patients/show/#{patient.id}"
                  return task
                end
              end
            end
          end
        when 'HIV CLINIC CONSULTATION'  
          next unless patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue false
          clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id])
          goto_hiv_clinic_consultation = clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'ART visit:  Yes'.upcase rescue false
          goto_hiv_clinic_consultation_answered = clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'ART visit:'.upcase rescue false

          next if not goto_hiv_clinic_consultation and goto_hiv_clinic_consultation_answered
          

          hiv_clinic_consultation = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if hiv_clinic_consultation.blank? and user_selected_activities.match(/Manage HIV clinic consultations/i)
            task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
            return task
          elsif hiv_clinic_consultation.blank? and not user_selected_activities.match(/Manage HIV clinic consultations/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not reason_for_art.upcase ==  'UNKNOWN'
        when 'TB ADHERENCE'
          drugs_given_before = false
          PatientService.drug_given_before(patient,session_date).each do |order|
            drugs_given_before = true                                              
          end
           
          tb_adherence = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if tb_adherence.blank? and user_selected_activities.match(/Manage TB adherence/i)
            task.url = "/encounters/new/tb_adherence?show&patient_id=#{patient.id}"
            return task
          elsif tb_adherence.blank? and not user_selected_activities.match(/Manage TB adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if drugs_given_before
        when 'ART ADHERENCE'
          art_drugs_given_before = false
          PatientService.drug_given_before(patient,session_date).each do |order|
            next unless MedicationService.arv(order.drug_order.drug)
            art_drugs_given_before = true
          end

          art_adherence = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if art_adherence.blank? and user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
            return task
          elsif art_adherence.blank? and not user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if art_drugs_given_before
        when 'TREATMENT' 
          tb_treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                   :joins => "INNER JOIN obs USING(encounter_id)",
                                   :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
                                   session_date.to_date,patient.id,EncounterType.find_by_name(type).id,ConceptName.find_by_name('TB regimen type').concept_id])

          encounter_tb_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('TB VISIT').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          prescribe_drugs = encounter_tb_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false

          if not prescribe_drugs 
            encounter_tb_clinic_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

            prescribe_drugs = encounter_tb_clinic_visit.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false
          end

          if tb_treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/regimens/new?patient_id=#{patient.id}"
            return task
          elsif tb_treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if prescribe_drugs



          art_treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                                   :joins => "INNER JOIN obs USING(encounter_id)",
                                   :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
                                   session_date.to_date,patient.id,EncounterType.find_by_name(type).id,ConceptName.find_by_name('ARV regimen type').concept_id])

          encounter_hiv_clinic_consultation = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          prescribe_drugs = false

          prescribe_drugs = encounter_hiv_clinic_consultation.observations.map{|obs| obs.to_s.squish.strip.upcase }.include? 'Prescribe drugs: Yes'.upcase rescue false

          if art_treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/regimens/new?patient_id=#{patient.id}"
            return task
          elsif art_treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if prescribe_drugs
        when 'DISPENSING'
          treatment = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                            patient.id,session_date,EncounterType.find_by_name('TREATMENT').id])

          encounter = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                 patient.id,EncounterType.find_by_name('DISPENSING').id,session_date],
                                 :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          if encounter.blank? and user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/treatment_dashboard/#{patient.id}"
            return task
          elsif encounter.blank? and not user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not treatment.blank?

          complete = DrugOrder.all_orders_complete(patient,session_date.to_date)
         
          if not complete and user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/treatment_dashboard/#{patient.id}"
            return task
          elsif not complete and not user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not treatment.blank?
         
          appointment = Encounter.find(:first,:conditions =>["patient_id = ? AND 
                        encounter_type = ? AND DATE(encounter_datetime) = ?",
                        patient.id,EncounterType.find_by_name('APPOINTMENT').id,session_date],
                        :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          if complete and user_selected_activities.match(/Manage Appointments/i)
            start_date , end_date = DrugOrder.prescription_dates(patient,session_date.to_date)
            task.encounter_type = "Set Appointment date"
            task.url = "/encounters/new/appointment?end_date=#{end_date}&id=show&patient_id=#{patient.id}&start_date=#{start_date}"
            return task
          elsif complete and not user_selected_activities.match(/Manage Appointments/i)
            task.encounter_type = "Set Appointment date"
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not treatment.blank? and appointment.blank?
      end
    end
    #task.encounter_type = 'Visit complete ...'
    task.encounter_type = 'NONE'
    task.url = "/patients/show/#{patient.id}"
    return task
  end
  
  def next_form(location , patient , session_date = Date.today)
    #for Oupatient departments
    task = Task.first rescue Task.new()
    if location.name.match(/Outpatient/i)
      opd_reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                        patient.id, session_date, EncounterType.find_by_name('OUTPATIENT RECEPTION').id])
      if opd_reception.blank?
        task.url = "/encounters/new/opd_reception?show&patient_id=#{patient.id}"
        task.encounter_type = 'OUTPATIENT RECEPTION'
      else
        task.encounter_type = 'NONE'
        task.url = "/patients/show/#{patient.id}"
      end
      return task
    end

    current_user_activities = current_user.activities
    if current_program_location == "TB program"
      return tb_next_form(location , patient , session_date)
    end
    
    if current_user_activities.blank?
      task.encounter_type = "NO TASKS SELECTED"
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    
    current_day_encounters = Encounter.find(:all,
              :conditions =>["patient_id = ? AND DATE(encounter_datetime) = ?",
              patient.id,session_date.to_date]).map{|e|e.name.upcase}
    
    if current_day_encounters.include?("TB RECEPTION")
      return tb_next_form(location , patient , session_date)
    end

    #we get the sequence of clinic questions(encounters) form the GlobalProperty table
    #property: list.of.clinical.encounters.sequentially
    #property_value: ?

    #valid privileges for ART visit ....
    #1. Manage Vitals - VITALS
    #2. Manage pre ART visits - PART_FOLLOWUP
    #3. Manage HIV staging visits - HIV STAGING
    #4. Manage HIV reception visits - HIV RECEPTION
    #5. Manage HIV first visit - HIV CLINIC REGISTRATION
    #6. Manage drug dispensations - DISPENSING
    #7. Manage HIV clinic consultations - HIV CLINIC CONSULTATION
    #8. Manage TB reception visits -? 
    #9. Manage prescriptions - TREATMENT
    #10. Manage appointments - APPOINTMENT
    #11. Manage ART adherence - ART ADHERENCE

    encounters_sequentially = CoreService.get_global_property_value('list.of.clinical.encounters.sequentially')

    encounters = encounters_sequentially.split(',')

    user_selected_activities = current_user.activities.collect{|a| a.upcase }.join(',') rescue []
    if encounters.blank? or user_selected_activities.blank?
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reason_for_art = PatientService.reason_for_art_eligibility(patient)
	if !reason_for_art.nil? && reason_for_art.upcase == 'NONE'
		reason_for_art = nil				
	end
	 #raise encounters.to_yaml
    encounters.each do | type |
		type =type.squish
      encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(type).id, session_date],
                                     :order =>'encounter_datetime DESC,date_created DESC',:limit => 1) rescue nil
      
      # next if encounter_available.nil?
      
      reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                        patient.id,session_date,EncounterType.find_by_name('HIV RECEPTION').id]).observations.collect{| r | r.to_s}.join(',') rescue ''
        
      task.encounter_type = type 
      case type
        when 'VITALS'
          if encounter_available.blank? and user_selected_activities.match(/Manage Vitals/i) 
            task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage Vitals/i) 
            task.url = "/patients/show/#{patient.id}"
            return task
          end if reception.match(/PATIENT PRESENT FOR CONSULTATION:  YES/i)
        when 'HIV CLINIC CONSULTATION'
          if encounter_available.blank? and user_selected_activities.match(/Manage HIV clinic consultations/i)
            task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV clinic consultations/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
          
          #if a nurse has refered a patient to a doctor/clinic 
          concept_id = ConceptName.find_by_name("Refer to ART clinician").concept_id
          ob = Observation.find(:first,:conditions =>["person_id = ? AND concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",
              patient.id, concept_id, session_date, session_date.to_s + ' 23:59:59'],:order =>"obs_datetime DESC, date_created DESC")

          refer_to_clinician = ob.to_s.squish.upcase == 'Refer to ART clinician: yes'.upcase


          if current_user_roles.include?('Nurse')
            adherence_encounter_available = Encounter.find(:first,
              :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
              patient.id,EncounterType.find_by_name("ART ADHERENCE").id,session_date],
              :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

            arv_drugs_given = false                                               
            PatientService.drug_given_before(patient,session_date).each do |order|
              next unless MedicationService.arv(order.drug_order.drug)            
              arv_drugs_given = true                                              
            end                                                                   
            if arv_drugs_given                                           
              if adherence_encounter_available.blank? and user_selected_activities.match(/Manage ART adherence/i)
                task.encounter_type = "ART ADHERENCE"
                task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
                return task                                                         
              elsif adherence_encounter_available.blank? and not user_selected_activities.match(/Manage ART adherence/i)
                task.encounter_type = "ART ADHERENCE"
                task.url = "/patients/show/#{patient.id}"                           
                return task                                                         
              end if not PatientService.drug_given_before(patient,session_date).blank?
            end
          end if refer_to_clinician 

          
          if not encounter_available.blank? and refer_to_clinician 
            task.url = "/patients/show/#{patient.id}"
            task.encounter_type = "Clinician " + task.encounter_type
            return task
          end if current_user_roles.include?('Nurse')

          roles = current_user_roles.join(',') rescue ''
          clinician_or_doctor = roles.match(/Clinician/i) or roles.match(/Doctor/i)

          if not encounter_available.blank? and refer_to_clinician 
            if user_selected_activities.match(/Manage HIV clinic consultaions/i)
              task.url = "/encounters/new/hiv_clinic_consultation?patient_id=#{patient.id}"
              task.encounter_type = "Clinician " + task.encounter_type
              return task
            elsif not user_selected_activities.match(/Manage HIV clinic consultations/i)
              task.url = "/patients/show/#{patient.id}"
              task.encounter_type = "Clinician " + task.encounter_type
              return task
            end 
          end if clinician_or_doctor
        when 'HIV STAGING'
          arv_drugs_given = false
          PatientService.drug_given_before(patient,session_date).each do |order|
            next unless MedicationService.arv(order.drug_order.drug)
            arv_drugs_given = true
          end
          next if arv_drugs_given
          if encounter_available.blank? and user_selected_activities.match(/Manage HIV staging visits/i) 
            task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if reason_for_art.nil? or reason_for_art.blank?
        when 'HIV RECEPTION'
          encounter_hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                                         patient.id,EncounterType.find_by_name('HIV CLINIC REGISTRATION').id],
                                         :order =>'encounter_datetime DESC',:limit => 1)
          transfer_in = encounter_hiv_clinic_registration.observations.collect{|r|r.to_s.strip.upcase}.include?('HAS TRANSFER LETTER: YES'.upcase) rescue []
          hiv_staging = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                        patient.id,EncounterType.find_by_name('HIV STAGING').id],:order => "encounter_datetime DESC")
          
          if transfer_in and hiv_staging.blank? and user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}" 
            task.encounter_type = 'HIV STAGING'
            return task
          elsif encounter_available.blank? and user_selected_activities.match(/Manage HIV reception visits/i)
            task.url = "/encounters/new/hiv_reception?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV reception visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'HIV CLINIC REGISTRATION'
          #encounter_hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
           #                              patient.id,EncounterType.find_by_name(type).id],
            #                             :order =>'encounter_datetime DESC',:limit => 1)

          hiv_clinic_registration = require_hiv_clinic_registration(patient)

          if hiv_clinic_registration and user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/encounters/new/hiv_clinic_registration?show&patient_id=#{patient.id}"
            return task
          elsif hiv_clinic_registration and not user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'DISPENSING'
          encounter_hiv_clinic_consultation = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)
          next unless encounter_hiv_clinic_consultation.observations.map{|obs| obs.to_s.strip.upcase }.include? 'Prescribe drugs:  Yes'.upcase

          treatment = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                            patient.id,session_date,EncounterType.find_by_name('TREATMENT').id])

          if encounter_available.blank? and user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/treatment_dashboard/#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not treatment.blank?
        when 'TREATMENT'
          encounter_hiv_clinic_consultation = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('HIV CLINIC CONSULTATION').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          concept_id = ConceptName.find_by_name("Prescribe drugs").concept_id
          ob = Observation.find(:first,:conditions =>["person_id=? AND concept_id =?",
              patient.id,concept_id],:order =>"obs_datetime DESC,date_created DESC")

          prescribe_arvs = ob.to_s.squish.upcase == 'Prescribe drugs: Yes'.upcase

          concept_id = ConceptName.find_by_name("Refer to ART clinician").concept_id
          ob = Observation.find(:first,:conditions =>["person_id=? AND concept_id =?",
              patient.id,concept_id],:order =>"obs_datetime DESC,date_created DESC")

          not_refer_to_clinician = ob.to_s.squish.upcase == 'Refer to ART clinician: No'.upcase

          if prescribe_arvs and not_refer_to_clinician 
            show_treatment = true
          else
            show_treatment = false
          end

          if encounter_available.blank? and user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/regimens/new?patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if show_treatment
        when 'ART ADHERENCE'
          arv_drugs_given = false 
          PatientService.drug_given_before(patient,session_date).each do |order|
            next unless MedicationService.arv(order.drug_order.drug)
            arv_drugs_given = true
          end
          next unless arv_drugs_given
          if encounter_available.blank? and user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not PatientService.drug_given_before(patient,session_date).blank?
      end
    end
    #task.encounter_type = 'Visit complete ...'
    task.encounter_type = 'NONE'
    task.url = "/patients/show/#{patient.id}"
    return task
  end

  def next_task(patient)
    session_date = session[:datetime].to_date rescue Date.today
    task = main_next_task(Location.current_location, patient,session_date)
    begin
      return task.url if task.present? && task.url.present?
      return "/patients/show/#{patient.id}" 
    rescue
      return "/patients/show/#{patient.id}" 
    end
  end

  # Try to find the next task for the patient at the given location
  def main_next_task(location, patient, session_date = Date.today)

    if use_user_selected_activities
      return next_form(location , patient , session_date)
    end
    
    task = (Task.first || Task.new()) rescue Task.new()
    
    
    
    if !is_encounter_available(patient, 'OUTPATIENT RECEPTION', session_date) && (CoreService.get_global_property_value("is_referral_centre").to_s == 'true')
					task.encounter_type = 'OUTPATIENT RECEPTION'
					task.url = "/encounters/new/outpatient_reception?patient_id=#{patient.id}"
		else
        type = 'REGISTRATION'
    		encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(type).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      	
      	if encounter_available.blank? 
      	  task.encounter_type = type 
        	task.url = "/encounters/new/registration?patient_id=#{patient.id}"
				else
        	task.encounter_type = 'NONE'
        	task.url = "/patients/show/#{patient.id}"
        end
    end
    
    return task
    
  end
  
  
  def is_encounter_available(patient, encounter_type, session_date)
		is_available = false

		encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
        patient.id, EncounterType.find_by_name(encounter_type).id, session_date],
      :order =>'encounter_datetime DESC', :limit => 1)
		if encounter_available.blank?
			is_available = false
		else
			is_available = true
		end
		
		return is_available	
	end
  
  
  def validate_task(patient, task, location, session_date = Date.today)
    #return task unless task.has_program_id == 1
    return task if task.encounter_type == 'REGISTRATION'
    # allow EID patients at HIV clinic, but don't validate tasks
    return task if task.has_program_id == 4
    
    #check if the latest HIV program is closed - if yes, the app should redirect the user to update state screen
    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name('HIV CLINIC REGISTRATION').id)
      latest_hiv_program = [] ; patient.patient_programs.collect{ | p |next unless p.program_id == 1 ; latest_hiv_program << p } 
      if latest_hiv_program.last.closed?
        task.url = '/patients/programs_dashboard/{patient}' ; task.encounter_type = 'Program enrolment'
        return task
      end rescue nil
    end

    return task if task.url == "/patients/show/{patient}"

    art_encounters = ['HIV CLINIC REGISTRATION','HIV RECEPTION','VITALS','HIV STAGING','HIV CLINIC CONSULTATION','ART ADHERENCE','TREATMENT','DISPENSING']

    #if the following happens - that means the patient is a transfer in and the reception are trying to stage from the transfer in sheet
    if task.encounter_type == 'HIV STAGING' and location.name.match(/RECEPTION/i)
      return task 
    end

    #if the following happens - that means the patient was refered to see a clinician
    if task.description.match(/REFER/i) and location.name.match(/Clinician/i)
      return task 
    end

    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[0]).id).blank? and task.encounter_type != art_encounters[0]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[0].gsub(' ','_')}") 
      return task
    elsif patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[0]).id).blank? and task.encounter_type == art_encounters[0]
      return task
    end
    
    hiv_reception = Encounter.find(:first,
                                   :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name(art_encounters[1]).id,session_date],
                                   :order =>'encounter_datetime DESC')

    if hiv_reception.blank? and task.encounter_type != art_encounters[1]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[1].gsub(' ','_')}") 
      return task
    elsif hiv_reception.blank? and task.encounter_type == art_encounters[1]
      return task
    end

    reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                        patient.id,session_date,EncounterType.find_by_name(art_encounters[1]).id]).collect{|r|r.to_s}.join(',') rescue ''
    
    if reception.match(/PATIENT PRESENT FOR CONSULTATION:  YES/i)
      vitals = Encounter.find(:first,
                              :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                              patient.id,EncounterType.find_by_name(art_encounters[2]).id,session_date],
                              :order =>'encounter_datetime DESC')

      if vitals.blank? and task.encounter_type != art_encounters[2]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[2].gsub(' ','_')}") 
        return task
      elsif vitals.blank? and task.encounter_type == art_encounters[2]
        return task
      end
    end

    hiv_staging = patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[3]).id)
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''

    if ((reasons.blank?) and (task.encounter_type == art_encounters[3]))
      return task
    elsif hiv_staging.blank? and task.encounter_type != art_encounters[3]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[3].gsub(' ','_')}") 
      return task
    elsif hiv_staging.blank? and task.encounter_type == art_encounters[3]
      return task
    end

    pre_art_visit = Encounter.find(:first,
                                   :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('PART_FOLLOWUP').id,session_date],
                                   :order =>'encounter_datetime DESC',:limit => 1)

    if pre_art_visit.blank?
      art_visit = Encounter.find(:first,
                                     :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(art_encounters[4]).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)

      if art_visit.blank? and task.encounter_type != art_encounters[4]
        #checks if we need to do a pre art visit
        if task.encounter_type == 'PART_FOLLOWUP' 
          return task
        elsif reasons.upcase == 'UNKNOWN' or reasons.blank?
          task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
          return task
        end
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[4].gsub(' ','_')}") 
        return task
      elsif art_visit.blank? and task.encounter_type == art_encounters[4]
        return task
      end
    end

    arv_drugs_given = false
    PatientService.drug_given_before(patient,session_date).each do |order|
      next unless MedicationService.arv(order.drug_order.drug)            
      arv_drugs_given = true                                              
    end

    if arv_drugs_given
      art_adherance = Encounter.find(:first,
                                     :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(art_encounters[5]).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      
      if art_adherance.blank? and task.encounter_type != art_encounters[5]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[5].gsub(' ','_')}") 
        return task
      elsif art_adherance.blank? and task.encounter_type == art_encounters[5]
        return task
      end
    end

    if PatientService.prescribe_arv_this_visit(patient, session_date)
      art_treatment = Encounter.find(:first,
                                     :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(art_encounters[6]).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      if art_treatment.blank? and task.encounter_type != art_encounters[6]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[6].gsub(' ','_')}") 
        return task
      elsif art_treatment.blank? and task.encounter_type == art_encounters[6]
        return task
      end
    end

    task
  end
    

  def latest_state(patient_obj,visit_date)                                     
     program_id = Program.find_by_name('HIV PROGRAM').id                        
     patient_state = PatientState.find(:first,                                  
       :joins => "INNER JOIN patient_program p                                  
       ON p.patient_program_id = patient_state.patient_program_id",             
       :conditions =>["patient_state.voided = 0 AND p.voided = 0                
       AND p.program_id = ? AND start_date <= ? AND p.patient_id =?",           
       program_id,visit_date.to_date,patient_obj.id],                           
       :order => "start_date DESC, date_created DESC")                                       
                                                                                
     return if patient_state.blank?                                             
     ConceptName.find_by_concept_id(patient_state.program_workflow_state.concept_id).name
  end
  
	def require_hiv_clinic_registration(patient_obj = nil)
		require_registration = false
		patient = patient_obj || find_patient

		hiv_clinic_registration = Encounter.find(:first,:conditions =>["patient_id = ? 
		              AND encounter_type = ?",patient.id,
		              EncounterType.find_by_name("HIV CLINIC REGISTRATION").id],
		              :order =>'encounter_datetime DESC,date_created DESC')

		require_registration = true if hiv_clinic_registration.blank?
	
		if !require_registration
			session_date = session[:datetime].to_date rescue Date.today

			current_outcome = latest_state(patient, session_date) || ""

			on_art_before = has_patient_been_on_art_before(patient)

			if current_outcome.match(/Transferred out/i)
				if on_art_before
					require_registration = false
				else
					require_registration = true
				end
			end
		end
		return require_registration
	end

  def confirm_before_creating                                                   
    property = GlobalProperty.find_by_property("confirm.before.creating")       
    property.property_value == 'true' rescue false                              
  end

end
