class EncountersController < GenericEncountersController
	
	def new	
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today
		
		@retrospective = 'false'
		if session[:datetime]
			if session[:datetime].to_date != Date.today.to_date
      	@retrospective = 'true'
      end  
		end

		@programs = @patient.patient_programs.all
		#@referral_sections = patient_referral_sections(@patient_bean.age)

    @current_encounters = @patient.encounters.find_by_date(session_date)   
		@current_user_role = self.current_user_role

		@patient_is_child_bearing_female = is_child_bearing_female(@patient)
		@select_options = select_options

		@patients = nil

		redirect_to "/" and return unless @patient

		redirect_to next_task(@patient) and return unless params[:encounter_type]

		if params[:encounter_type]
			render :action => params[:encounter_type] if params[:encounter_type]
		end

	end

  def patient_referral_sections(patient_age)
		@sections = []

		if patient_age <= 15
      @sections = peads_facility_referral_sections
    else
      @sections = all_facility_referral_sections - peads_facility_referral_sections
    end

  end


	def select_options
    select_options = {
     'services' => [
        ['',''],
        ['Casualty','Casualty'],
        ['Dental','Dental'],
        ['Eye','Eye'],
        ['Family Planing','Family Planing'],
        ['Medical','Medical'],
        ['OB/Gyn','OB/Gyn'],
        ['Orthopedics','Orthopedics'],
        ['Pediatrics','Pediatrics'],
        ['Skin',' Skin '],
        ['STI Clinic','STI Clinic'],
        ['Surgical','Surgical'],
        ['Other',' Other ']]}
	end

	def return_original_suggested_date(suggested_date, booked_dates)
  suggest_original_date = nil
  #second_biggest_date_available = nil
  
  booked_dates.each do |booked_date|
    sdate = booked_date.to_s.split(":")[0].to_date
    
    if(sdate.to_date >= suggested_date.to_date)
      #second_biggest_date_available = suggested_date
      suggest_original_date = sdate
      suggested_date = sdate
    end
  end if booked_dates.to_s.size > 0
  
  @massage="All available days this calender week are fully booked"

  return suggest_original_date
end

  def is_below_limit(recommended_date, bookings)
    clinic_appointment_limit = CoreService.get_global_property_value('clinic.appointment.limit').to_i rescue 0
		clinic_appointment_limit = 0 if clinic_appointment_limit.blank?
		within_limit = true
		
    if (bookings.blank? || clinic_appointment_limit <= 0)
      within_limit = true;
    else
      recommended_date_limit = bookings[recommended_date] rescue 0

		  if (recommended_date_limit >= clinic_appointment_limit)
		    within_limit = false
		  end
    end

	return within_limit
 end

	def suggested_date(prescription_expiry_date, holidays, bookings, clinic_days)
		number_of_suggested_booked_dates_tried = 0

		skip = true
		recommended_date = prescription_expiry_date
		nearest_clinic_day = nil
    
		while skip
			clinic_days.each do |d|
			if (d.to_s.upcase == recommended_date.strftime('%A').to_s.upcase)
				nearest_clinic_day = recommended_date if nearest_clinic_day.blank?
				skip = is_holiday(recommended_date, holidays)
				break
			end
		end


		if (skip)
			recommended_date = recommended_date - 1.day
		else
			below_limit = is_below_limit(recommended_date, bookings)
			if (below_limit == false)
				recommended_date = recommended_date - 1.day
				skip = true
			end
		end

		number_of_suggested_booked_dates_tried += 1
		total_booked_dates = booked_dates.length rescue 0

		test = (number_of_suggested_booked_dates_tried > 4 && total_booked_dates > 0)
		if test
			recommended_date = nearest_clinic_day
		end
    end

    return recommended_date
   
 end

  def assign_close_to_expire_date(set_date,auto_expire_date)
    if (set_date < auto_expire_date)
      while (set_date < auto_expire_date)
        set_date = set_date + 1.day
      end
        #Give the patient a 2 day buffer*/
        set_date = set_date - 1.day
    end
    return set_date
  end

	def suggest_appointment_date
		#for now we disable this because we are already checking for this
		#in the browser - the method is suggested_return_date
		#@number_of_days_to_add_to_next_appointment_date = number_of_days_to_add_to_next_appointment_date(@patient, session[:datetime] || Date.today)

		dispensed_date = session[:datetime].to_date rescue Date.today
		prescription_expiry_date = prescription_expiry_date(@patient, dispensed_date)
		
		#if the patient is a child (age 14 or less) and the peads clinic days are set - we
		#use the peads clinic days to set the next appointment date		
		peads_clinic_days = CoreService.get_global_property_value('peads.clinic.days')
				
		if (@patient_bean.age <= 14 && !peads_clinic_days.blank?)
			clinic_days = peads_clinic_days
		else
			clinic_days = CoreService.get_global_property_value('clinic.days') || 'Monday,Tuesday,Wednesday,Thursday,Friday'		
		end
		clinic_days = clinic_days.split(',')		

		bookings = bookings_within_range(prescription_expiry_date)
		clinic_holidays = CoreService.get_global_property_value('clinic.holidays') || '1900-12-25,1900-03-03'
		clinic_holidays = clinic_holidays.split(',').map{|day|day.to_date}.join(',').split(',') rescue []
		
		limit = CoreService.get_global_property_value('clinic.appointment.limit') rescue 0

		return suggested_date(prescription_expiry_date ,clinic_holidays, bookings, clinic_days)
	end
	
	def prescription_expiry_date(patient, dispensed_date)
    	session_date = dispensed_date.to_date
    
		orders_made = PatientService.drugs_given_on(patient, session_date).reject{|o| !MedicationService.arv(o.drug_order.drug) }

		auto_expire_date = Date.today + 2.days
		
		if orders_made.blank?
			orders_made = PatientService.drugs_given_on(patient, session_date)
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date if !orders_made.blank?
		else
			auto_expire_date = orders_made.sort_by(&:auto_expire_date).first.auto_expire_date.to_date
		end

		orders_made.each do |order|
			amounts_dispensed = Observation.all(:conditions => ['concept_id = ? AND order_id = ?', 
						     ConceptName.find_by_name("AMOUNT DISPENSED").concept_id , order.id])
			total_dispensed = amounts_dispensed.sum{|amount| amount.value_numeric}
			
			amounts_brought_to_clinic = Observation.all( :joins => 'INNER JOIN drug_order USING (order_id)', 
				:conditions => ['obs.concept_id = ? AND drug_order.drug_inventory_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ?', 
						     ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id , order.drug_order.drug_inventory_id, session_date.to_date, session_date.to_date.to_s + ' 23:59:59'])

			total_brought_to_clinic = amounts_brought_to_clinic.sum{|amount| amount.value_numeric}

			total_brought_to_clinic = total_brought_to_clinic + amounts_brought_to_clinic.sum{|amount| (amount.value_text.to_f rescue 0)}

			prescription_duration = ((total_dispensed + total_brought_to_clinic)/order.drug_order.equivalent_daily_dose).to_i
			expire_date = order.start_date.to_date + prescription_duration.days

			auto_expire_date = expire_date  if expire_date  > auto_expire_date
		end
		
		return auto_expire_date - 2.days
	end
	
  def bookings_within_range(end_date = nil)
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    booked_dates = Hash.new(0)
   
    clinic_days = GlobalProperty.find_by_property("clinic.days")
    clinic_days = clinic_days.property_value.split(',') rescue 'Monday,Tuesday,Wednesday,Thursday,Friday'.split(',')

    count = 0
    start_date = end_date 
    while (count < 4)
      if clinic_days.include?(start_date.strftime("%A"))
        start_date -= 1.day
        count+=1
      else
        start_date -= 1.day
      end
    end

    Observation.find(:all,:order => "value_datetime DESC",
    :joins => "INNER JOIN encounter e USING(encounter_id)",
    :conditions => ["encounter_type = ? AND value_datetime IS NOT NULL
    AND (DATE(value_datetime) >= ? AND DATE(value_datetime) <= ?)",
    encounter_type.id,start_date,end_date]).map do | obs |
      next unless clinic_days.include?(obs.value_datetime.to_date.strftime("%A"))
      booked_dates[obs.value_datetime.to_date]+=1
    end  

    return booked_dates
  end

  def create_remote
    location = Location.find(params["location"]) rescue nil
    user = User.first rescue nil

    if !location.nil? and !user.nil?
      self.current_location = location
      User.current = user

      Location.current_location = location

      target = {
        :observations=>[],
        :encounter=>params["encounter"]
      }

      params["obs"].each{|k,v|
        target[:observations] << v
      }

      params = target

      if params[:change_appointment_date] == "true"
        session_date = session[:datetime].to_date rescue Date.today
        type = EncounterType.find_by_name("APPOINTMENT")
        appointment_encounter = Observation.find(:first,
          :order => "encounter_datetime DESC,encounter.date_created DESC",
          :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
          :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?
      AND encounter_datetime >= ? AND encounter_datetime <= ?",
            ConceptName.find_by_name('Appointment date').concept_id,
            type.id, params[:encounter]["patient_id"],session_date.strftime("%Y-%m-%d 00:00:00"),
            session_date.strftime("%Y-%m-%d 23:59:59")]).encounter
        appointment_encounter.void("Given a new appointment date")
      end

      if params[:encounter]['encounter_type_name'] == 'TB_INITIAL'
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'TRANSFER IN' and observation['value_coded_or_text'] == "YES"
            params[:observations] << {"concept_name" => "TB STATUS","value_coded_or_text" => "Confirmed TB on treatment"}
          end
        end
      end

      if params[:encounter]['encounter_type_name'] == 'HIV_CLINIC_REGISTRATION'

        has_tranfer_letter = false
        (params[:observations]).each do |ob|
          if ob["concept_name"] == "HAS TRANSFER LETTER"
            has_tranfer_letter = (ob["value_coded_or_text"].upcase == "YES")
            break
          end
        end

        if params[:observations][0]['concept_name'].upcase == 'EVER RECEIVED ART' and params[:observations][0]['value_coded_or_text'].upcase == 'NO'
          observations = []
          (params[:observations] || []).each do |observation|
            next if observation['concept_name'].upcase == 'HAS TRANSFER LETTER'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            next if observation['concept_name'].upcase == 'ART NUMBER AT PREVIOUS LOCATION'
            next if observation['concept_name'].upcase == 'DATE ART LAST TAKEN'
            next if observation['concept_name'].upcase == 'LAST ART DRUGS TAKEN'
            next if observation['concept_name'].upcase == 'TRANSFER IN'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            observations << observation
          end
        elsif params[:observations][4]['concept_name'].upcase == 'DATE ART LAST TAKEN' and params[:observations][4]['value_datetime'] != 'Unknown'
          observations = []
          (params[:observations] || []).each do |observation|
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO WEEKS'
            next if observation['concept_name'].upcase == 'HAS THE PATIENT TAKEN ART IN THE LAST TWO MONTHS'
            observations << observation
          end
        end

        params[:observations] = observations unless observations.blank?

        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'LOCATION OF ART INITIATION' or observation['concept_name'].upcase == 'CONFIRMATORY HIV TEST LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end
          observations << observation
        end

        params[:observations] = observations unless observations.blank?

        observations = []
        vitals_observations = []
        initial_observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'WHO STAGES CRITERIA PRESENT'
            observations << observation
          elsif observation['concept_name'].upcase == 'WHO STAGES CRITERIA PRESENT'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT LOCATION'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT DATETIME'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT LESS THAN OR EQUAL TO 250'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 COUNT LESS THAN OR EQUAL TO 350'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 PERCENT'
            observations << observation
          elsif observation['concept_name'].upcase == 'CD4 PERCENT LESS THAN 25'
            observations << observation
          elsif observation['concept_name'].upcase == 'REASON FOR ART ELIGIBILITY'
            observations << observation
          elsif observation['concept_name'].upcase == 'WHO STAGE'
            observations << observation
          elsif observation['concept_name'].upcase == 'BODY MASS INDEX, MEASURED'
            bmi = nil
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "BODY MASS INDEX, MEASURED"
                bmi = ob["value_numeric"]
                break
              end
            end
            next if bmi.blank?
            vitals_observations << observation
          elsif observation['concept_name'].upcase == 'WEIGHT (KG)'
            weight = 0
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "WEIGHT (KG)"
                weight = ob["value_numeric"].to_f rescue 0
                break
              end
            end
            next if weight.blank? or weight < 1
            vitals_observations << observation
          elsif observation['concept_name'].upcase == 'HEIGHT (CM)'
            height = 0
            (params[:observations]).each do |ob|
              if ob["concept_name"] == "HEIGHT (CM)"
                height = ob["value_numeric"].to_i rescue 0
                break
              end
            end
            next if height.blank? or height < 1
            vitals_observations << observation
          else
            initial_observations << observation
          end
        end if has_tranfer_letter

        date_started_art = nil
        (initial_observations || []).each do |ob|
          if ob['concept_name'].upcase == 'DATE ANTIRETROVIRALS STARTED'
            date_started_art = ob["value_datetime"].to_date rescue nil
            if date_started_art.blank?
              date_started_art = ob["value_coded_or_text"].to_date rescue nil
            end
          end
        end

        unless vitals_observations.blank?
          encounter = Encounter.new()
          encounter.encounter_type = EncounterType.find_by_name("VITALS").id
          encounter.patient_id = params[:encounter]['patient_id']
          encounter.encounter_datetime = date_started_art
          if encounter.encounter_datetime.blank?
            encounter.encounter_datetime = params[:encounter]['encounter_datetime']
          end
          if params[:filter] and !params[:filter][:provider].blank?
            user_person_id = User.find_by_username(params[:filter][:provider]).person_id
          else
            user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
          end
          encounter.provider_id = user_person_id
          encounter.save
          params[:observations] = vitals_observations
          create_obs(encounter , params)
        end

        unless observations.blank?
          encounter = Encounter.new()
          encounter.encounter_type = EncounterType.find_by_name("HIV STAGING").id
          encounter.patient_id = params[:encounter]['patient_id']
          encounter.encounter_datetime = date_started_art
          if encounter.encounter_datetime.blank?
            encounter.encounter_datetime = params[:encounter]['encounter_datetime']
          end
          if params[:filter] and !params[:filter][:provider].blank?
            user_person_id = User.find_by_username(params[:filter][:provider]).person_id
          else
            user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
          end
          encounter.provider_id = user_person_id
          encounter.save

          params[:observations] = observations

          (params[:observations] || []).each do |observation|
            if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
              observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
              observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
            end
          end
          create_obs(encounter , params)
        end
        params[:observations] = initial_observations if has_tranfer_letter
      end

      if params[:encounter]['encounter_type_name'].upcase == 'HIV STAGING'
        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'CD4 COUNT' or observation['concept_name'].upcase == "LYMPHOCYTE COUNT"
            observation['value_modifier'] = observation['value_numeric'].match(/=|>|</i)[0] rescue nil
            observation['value_numeric'] = observation['value_numeric'].match(/[0-9](.*)/i)[0] rescue nil
          end
          if observation['concept_name'].upcase == 'CD4 COUNT LOCATION' or observation['concept_name'].upcase == 'LYMPHOCYTE COUNT LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end
          if observation['concept_name'].upcase == 'CD4 PERCENT LOCATION'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end

          observations << observation
        end

        params[:observations] = observations unless observations.blank?
      end

      if params[:encounter]['encounter_type_name'].upcase == 'ART ADHERENCE'
        previous_hiv_clinic_consultation_observations = []
        art_adherence_observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'REFER TO ART CLINICIAN'
            previous_hiv_clinic_consultation_observations << observation
          elsif observation['concept_name'].upcase == 'PRESCRIBE DRUGS'
            previous_hiv_clinic_consultation_observations << observation
          elsif observation['concept_name'].upcase == 'ALLERGIC TO SULPHUR'
            previous_hiv_clinic_consultation_observations << observation
          else
            art_adherence_observations << observation
          end
        end

        unless previous_hiv_clinic_consultation_observations.blank?
          #if "REFER TO ART CLINICIAN","PRESCRIBE DRUGS" and "ALLERGIC TO SULPHUR" has
          #already been asked during HIV CLINIC CONSULTATION - we append the observations to the latest
          #HIV CLINIC CONSULTATION encounter done on that day

          session_date = session[:datetime].to_date rescue Date.today
          encounter_type = EncounterType.find_by_name("HIV CLINIC CONSULTATION")
          encounter = Encounter.find(:first,:order =>"encounter_datetime DESC,date_created DESC",
            :conditions =>["encounter_type=? AND patient_id=? AND encounter_datetime >= ?
          AND encounter_datetime <= ?",encounter_type.id,params[:encounter]['patient_id'],
              session_date.strftime("%Y-%m-%d 00:00:00"),session_date.strftime("%Y-%m-%d 23:59:59")])
          if encounter.blank?
            encounter = Encounter.new()
            encounter.encounter_type = encounter_type.id
            encounter.patient_id = params[:encounter]['patient_id']
            encounter.encounter_datetime = session_date.strftime("%Y-%m-%d 00:00:01")
            if params[:filter] and !params[:filter][:provider].blank?
              user_person_id = User.find_by_username(params[:filter][:provider]).person_id
            else
              user_person_id = User.find_by_user_id(params[:encounter]['provider_id']).person_id
            end
            encounter.provider_id = user_person_id
            encounter.save
          end
          params[:observations] = previous_hiv_clinic_consultation_observations
          create_obs(encounter , params)
        end

        params[:observations] = art_adherence_observations

        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER'
            observation['value_numeric'] = observation['value_text'] rescue nil
            observation['value_text'] =  ""
          end

          if observation['concept_name'].upcase == 'MISSED HIV DRUG CONSTRUCT'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_coded_or_text'] = ""
          end
          observations << observation
        end
        params[:observations] = observations unless observations.blank?
      end

      if params[:encounter]['encounter_type_name'].upcase == 'REFER PATIENT OUT?'
        observations = []
        (params[:observations] || []).each do |observation|
          if observation['concept_name'].upcase == 'REFERRAL CLINIC IF REFERRED'
            observation['value_numeric'] = observation['value_coded_or_text'] rescue nil
            observation['value_text'] = Location.find(observation['value_coded_or_text']).name.to_s rescue ""
            observation['value_coded_or_text'] = ""
          end

          observations << observation
        end

        params[:observations] = observations unless observations.blank?
      end

      @patient = Patient.find(params[:encounter][:patient_id]) rescue nil
      if params[:location]
        if @patient.nil?
          @patient = Patient.find_with_voided(params[:encounter][:patient_id])
        end

        Person.migrated_datetime = params[:encounter]['date_created']
        Person.migrated_creator  = params[:encounter]['creator'] rescue nil

        # set current location via params if given
        Location.current_location = Location.find(params[:location])
      end

      if params[:encounter]['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
        concept_id = ConceptName.find_by_name("RETURN VISIT DATE").concept_id
        encounter_id_s = Observation.find_by_sql("SELECT encounter_id
                       FROM obs
                       WHERE concept_id = #{concept_id} AND person_id = #{@patient.id}
                            AND DATE(value_datetime) = DATE('#{params[:old_appointment]}') AND voided = 0
          ").map{|obs| obs.encounter_id}.each do |encounter_id|
          Encounter.find(encounter_id).void
        end
      end

      # Encounter handling
      encounter = Encounter.new(params[:encounter])
      unless params[:location]
        encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      else
        encounter.encounter_datetime = params[:encounter]['encounter_datetime']
      end

      if params[:filter] and !params[:filter][:provider].blank?
        user_person_id = User.find_by_username(params[:filter][:provider]).person_id
      elsif params[:location] # Migration
        user_person_id = encounter[:provider_id]
      else
        user_person_id = User.find_by_user_id(encounter[:provider_id]).person_id
      end
      encounter.provider_id = user_person_id

      encounter.save

      #create observations for the just created encounter
      create_obs(encounter , params)

      if !params[:recalculate_bmi].blank? && params[:recalculate_bmi] == "true"
				weight = 0
				height = 0

				weight_concept_id  = ConceptName.find_by_name("Weight (kg)").concept_id
				height_concept_id  = ConceptName.find_by_name("Height (cm)").concept_id
				bmi_concept_id = ConceptName.find_by_name("Body mass index, measured").concept_id
				work_station_concept_id = ConceptName.find_by_name("Workstation location").concept_id

				vitals_encounter_id = EncounterType.find_by_name("VITALS").encounter_type_id
				enc = Encounter.find(:all, :conditions => ["encounter_type = ? AND patient_id = ?
											AND voided=0", vitals_encounter_id, @patient.id])

				encounter.observations.each do |o|
          height = o.value_text if o.concept_id == height_concept_id
				end

				enc.each do |e|
          obs_created = false
          weight = nil

          e.observations.each do |o|
            next if o.concept_id == work_station_concept_id

            if o.concept_id == weight_concept_id
              weight = o.value_text.to_i
            elsif o.concept_id == height_concept_id || o.concept_id == bmi_concept_id
              o.voided = 1
              o.date_voided = Time.now
              o.voided_by = encounter.creator
              o.void_reason = "Back data entry recalculation"
              o.save
            end
          end

          bmi = (weight.to_f/(height.to_f*height.to_f)*10000).round(1) rescue "NaN"

          height_obs = Observation.new(
            :concept_name => "Height (cm)",
            :person_id => @patient.id,
            :encounter_id => e.id,
            :value_text => height,
            :obs_datetime => e.encounter_datetime)

          height_obs.save

          bmi_obs = Observation.new(
            :concept_name => "Body mass index, measured",
            :person_id => @patient.id,
            :encounter_id => e.id,
            :value_text => bmi,
            :obs_datetime => e.encounter_datetime)

          bmi_obs.save
				end
      end

      # Program handling
      date_enrolled = params[:programs][0]['date_enrolled'].to_time rescue nil
      date_enrolled = session[:datetime] || Time.now() if date_enrolled.blank?
      (params[:programs] || []).each do |program|
        # Look up the program if the program id is set
        @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?

        #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        #if params[:location] is not blank == migration params
        if params[:location]
          next if not @patient.patient_programs.in_programs("HIV PROGRAM").blank?
        end
        #>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

        # If it wasn't set, we need to create it
        unless (@patient_program)
          @patient_program = @patient.patient_programs.create(
            :program_id => program[:program_id],
            :date_enrolled => date_enrolled)
        end
        # Lots of states bub
        unless program[:states].blank?
          #adding program_state start date
          program[:states][0]['start_date'] = date_enrolled
        end
        (program[:states] || []).each {|state| @patient_program.transition(state) }
      end

      # Identifier handling
      arv_number_identifier_type = PatientIdentifierType.find_by_name('ARV Number').id
      (params[:identifiers] || []).each do |identifier|
        # Look up the identifier if the patient_identfier_id is set
        @patient_identifier = PatientIdentifier.find(identifier[:patient_identifier_id]) unless identifier[:patient_identifier_id].blank?
        # Create or update
        type = identifier[:identifier_type].to_i rescue nil
        unless (arv_number_identifier_type != type) and @patient_identifier
          arv_number = identifier[:identifier].strip
          if arv_number.match(/(.*)[A-Z]/i).blank?
            if params[:encounter]['encounter_type_name'] == 'TB REGISTRATION'
              identifier[:identifier] = "#{PatientIdentifier.site_prefix}-TB-#{arv_number}"
            else
              identifier[:identifier] = "#{PatientIdentifier.site_prefix}-ARV-#{arv_number}"
            end
          end
        end

        if @patient_identifier
          @patient_identifier.update_attributes(identifier)
        else
          @patient_identifier = @patient.patient_identifiers.create(identifier)
        end
      end

      # person attribute handling
      (params[:person] || []).each do | type , attribute |
        # Look up the attribute if the person_attribute_id is set
        @person_attribute = nil 

        if not @person_attribute.blank?
          @patient_identifier.update_attributes(person_attribute)
        else
          case type
          when 'agrees_to_be_visited_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
              :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to be visited at home for TB therapy").person_attribute_type_id,
              :value => attribute)
          when 'agrees_phone_text_for_TB_therapy'
            @person_attribute = @patient.person.person_attributes.create(
              :person_attribute_type_id => PersonAttributeType.find_by_name("Agrees to phone text for TB therapy").person_attribute_type_id,
              :value => attribute)
          end
        end
      end

      render :text => "OK"

    else
      render :text => "Location not found or not valid"
    end

  end

end
