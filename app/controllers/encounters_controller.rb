class EncountersController < ApplicationController
  def create(params=params, session=session)
    #raise params.to_yaml

    @patient = Patient.find(params[:encounter][:patient_id]) rescue nil
    if params[:location]
      if @patient.nil?
        @patient = Patient.find_with_voided(params[:encounter][:patient_id])
      end

      Person.migrated_datetime = params['encounter']['date_created']
      Person.migrated_creator  = params['encounter']['creator'] rescue nil

      # set current location via params if given
      Location.current_location = Location.find(params[:location])
    end

    # Encounter handling
    encounter = Encounter.new(params[:encounter])
    unless params[:location]
      encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
    else
      encounter.encounter_datetime = params['encounter']['encounter_datetime']
    end

    if !params[:filter][:provider].blank?
     user_person_id = User.find_by_username(params[:filter][:provider]).person_id
     encounter.provider_id = user_person_id
    else
     user_person_id = User.find_by_user_id(encounter[:provider_id]).person_id
     encounter.provider_id = user_person_id
    end

    encounter.save    

		#create observations for the just created encounter
    create_obs(encounter , params)


    # Go to the next task in the workflow (or dashboard)
    # only redirect to next task if location parameter has not been provided
    unless params[:location]
    #find a way of printing the lab_orders labels
     if params['encounter']['encounter_type_name'] == "LAB ORDERS"
       redirect_to"/patients/print_lab_orders/?patient_id=#{@patient.id}"
     elsif params['encounter']['encounter_type_name'] == "TB suspect source of referral" && !params[:gender].empty? && !params[:family_name].empty? && !params[:given_name].empty?
       redirect_to"/encounters/new/tb_suspect_source_of_referral/?patient_id=#{@patient.id}&gender=#{params[:gender]}&family_name=#{params[:family_name]}&given_name=#{params[:given_name]}"
     else
      if params['encounter']['encounter_type_name'].to_s.upcase == "APPOINTMENT" && !params[:report_url].nil? && !params[:report_url].match(/report/).nil?
         redirect_to  params[:report_url].to_s and return
      end
      redirect_to next_task(@patient)
     end
    else
      if params[:voided]
        encounter.void(params[:void_reason],
                       params[:date_voided],
                       params[:voided_by])
      end
      #made restful the default due to time
      render :text => encounter.encounter_id.to_s and return
      #return encounter.id.to_s  # support non-RESTful creation of encounters
    end
  end

	def new	
		@patient = Patient.find(params[:patient_id] || session[:patient_id])
		@patient_bean = PatientService.get_patient(@patient.person)
		session_date = session[:datetime].to_date rescue Date.today
		
		if session[:datetime]
			@retrospective = true 
		else
			@retrospective = false
		end
		
		@programs = @patient.patient_programs.all
		@referral_sections = patient_referral_sections(@patient_bean.age)

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

	def current_user_role
		@role = User.current_user.user_roles.map{|r|r.role}
		return @role
	end

	def locations
		search_string = (params[:search_string] || 'neno').upcase
		filter_list = params[:filter_list].split(/, */) rescue []    
		locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'])
		render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
	end

	def observations
		# We could eventually include more here, maybe using a scope with includes
		@encounter = Encounter.find(params[:id], :include => [:observations])
		render :layout => false
	end

	def void
		@encounter = Encounter.find(params[:id])
		@encounter.void
		head :ok
	end

  def is_child_bearing_female(patient)
  	patient_bean = PatientService.get_patient(patient.person)
    (patient_bean.sex == 'Female' && patient_bean.age >= 9 && patient_bean.age <= 45) ? true : false
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
	
	private

	def create_obs(encounter , params)
		# Observation handling

		(params[:observations] || []).each do |observation|
			# Check to see if any values are part of this observation
			# This keeps us from saving empty observations
			values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map { |value_name|
				observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
			}.compact
			
			next if values.length == 0

			observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
			observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
			observation[:encounter_id] = encounter.id
			observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
			observation[:person_id] ||= encounter.patient_id
			observation[:concept_name].upcase ||= "DIAGNOSIS" if encounter.type.name.upcase == "OUTPATIENT DIAGNOSIS"

			# Handle multiple select

			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(String)
				observation[:value_coded_or_text_multiple] = observation[:value_coded_or_text_multiple].split(';')
			end
      
			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
				observation[:value_coded_or_text_multiple].compact!
				observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
			end  
      
			# convert values from 'mmol/litre' to 'mg/declitre'
			if(observation[:measurement_unit])
				observation[:value_numeric] = observation[:value_numeric].to_f * 18 if ( observation[:measurement_unit] == "mmol/l")
				observation.delete(:measurement_unit)
			end

			if(observation[:parent_concept_name])
				concept_id = Concept.find_by_name(observation[:parent_concept_name]).id rescue nil
				observation[:obs_group_id] = Observation.find(:first, :conditions=> ['concept_id = ? AND encounter_id = ?',concept_id, encounter.id]).id rescue ""
				observation.delete(:parent_concept_name)
			end
      
			extracted_value_numerics = observation[:value_numeric]
			extracted_value_coded_or_text = observation[:value_coded_or_text]

			if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
				values = observation.delete(:value_coded_or_text_multiple)
				values.each do |value| 
					observation[:value_coded_or_text] = value
					if observation[:concept_name].humanize == "Tests ordered"
						observation[:accession_number] = Observation.new_accession_number 
					end

					observation = update_observation_value(observation)

					Observation.create(observation) 
				end
			elsif extracted_value_numerics.class == Array
				extracted_value_numerics.each do |value_numeric|
					observation[:value_numeric] = value_numeric
					Observation.create(observation)
				end
			else      
				observation.delete(:value_coded_or_text_multiple)
				observation = update_observation_value(observation) if !observation[:value_coded_or_text].blank?
				Observation.create(observation)
			end
		end
  	end

	def update_observation_value(observation)
		value = observation[:value_coded_or_text]
		value_coded_name = ConceptName.find_by_name(value)

		if value_coded_name.blank?
			observation[:value_text] = value
		else
			observation[:value_coded_name_id] = value_coded_name.concept_name_id
			observation[:value_coded] = value_coded_name.concept_id
		end
		observation.delete(:value_coded_or_text)
		return observation
	end
	
end
