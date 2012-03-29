class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today

	  @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
	  @patient_bean = PatientService.get_patient(@patient.person)
	  @encounters = @patient.encounters.find_by_date(session_date)
	  @referral_section = get_referral_section(@patient.person, session_date).map{|service| service.value_text}.join(', ')  rescue 'None'
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date) rescue nil

    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|    
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

     @location = Location.find(session[:location_id]).name rescue ""
     if @location.downcase == "outpatient" || params[:source]== 'opd'
        render :template => 'dashboards/opdtreatment_dashboard', :layout => false
     else
        @task = main_next_task(Location.current_location,@patient,session_date)
        render :template => 'patients/index', :layout => false
     end
  end

  def index
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date)
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")
    @task = main_next_task(Location.current_location,@patient,session_date)

    render :template => 'patients/index', :layout => false
  end

  def overview
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = alerts(@patient, session_date) rescue nil
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    render :template => 'dashboards/overview_tab', :layout => false
  end

  def all_districts
   districts = []

   all_districts = District.find(:all, :order => 'name')
   all_districts.map do |district|
    districts << district.name
   end
   return districts
  end

  def all_traditional_authorities
    patient_bean = PatientService.get_patient(@patient.person)
    
    traditional_authorities = []
    district_id = District.find_by_name("#{patient_bean.home_district}").id
    traditional_authority_conditions = ["district_id = ?}%", district_id]

    all_traditional_authorities = TraditionalAuthority.find(:all, :conditions => ["district_id = ?", District.find_by_name("#{patient_bean.home_district}").id], :order => 'name')
   
    all_traditional_authorities.map do |ta|
      traditional_authorities << ta.name
    end

    return traditional_authorities
  end
  
  def edit_demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @person = @patient.person
    @patient_bean = PatientService.get_patient(@person)
    render :layout => 'edit_demographics'
  end
  
  def update_demographics
   update_demo_graphics(params)
   redirect_to :action => 'edit_demographics', :patient_id => params['person_id'] and return
  end

  def patient_demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @patient_bean = PatientService.get_patient(@patient.person)
    @cell_phone_number = PatientService.get_attribute(@patient.person, "Cell Phone Number")
    @home_phone_number = PatientService.get_attribute(@patient.person, "Home Phone Number")
    render :template => 'patients/patient_demographics', :layout => 'menu'
  end

  def problems
    render :template => 'dashboards/problems', :layout => 'dashboard' 
  end

  def personal
    @links = []
    patient = Patient.find(params[:id])

    @links << ["National ID (Print)","/patients/dashboard_print_national_id/#{patient.id}"]

    render :template => 'dashboards/personal_tab', :layout => false
  end

  def history
    render :template => 'dashboards/history', :layout => 'dashboard' 
  end

  def programs
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    flash.now[:error] = params[:error] unless params[:error].blank?

    unless flash[:error].nil?
      redirect_to "/patients/programs_dashboard/#{@patient.id}?error=#{params[:error]}" and return
    else
      render :template => 'dashboards/programs_tab', :layout => false
    end
  end

  def graph
    @currentWeight = params[:currentWeight]
    render :template => "graphs/#{params[:data]}", :layout => false 
  end

  def void 
    @encounter = Encounter.find(params[:encounter_id])
    @encounter.void
    show and return
  end
  
  def print_registration
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def dashboard_print_national_id
    unless params[:redirect].blank?
      redirect = "/#{params[:redirect]}/#{params[:id]}"
    else
      redirect = "/patients/show/#{params[:id]}"
    end
    print_and_redirect("/patients/national_id_label?patient_id=#{params[:id]}", redirect)  
  end
   
  def national_id_label
    print_string = PatientService.patient_national_id_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def visit
    @patient_id = params[:patient_id] 
    @date = params[:date].to_date
    @patient = Patient.find(@patient_id)
    @patient_bean = PatientService.get_patient(@patient.person)
    @patient_gaurdians = @patient.person.relationships.map{|r| PatientService.name(Person.find(r.person_b)) }.join(' : ')
    @visits = visits(@patient,@date)
    render :layout => "menu"
  end

  def mastercard_modify
    @occupations = PatientService.occupations
    @districts = all_districts
    @traditional_authorities = all_traditional_authorities
    
    if request.method == :get
      @patient_id = params[:id]
      @patient = Patient.find(params[:id])
      @edit_page = edit_mastercard_attribute(params[:field].to_s)

      if @edit_page == "guardian"
        @guardian = {}
        @patient.person.relationships.map{|r| @guardian[Person.find(r.person_b).name] = Person.find(r.person_b).id.to_s;'' }
        if  @guardian == {}
          redirect_to :controller => "relationships" , :action => "search",:patient_id => @patient_id
        end
      end
    else
      @patient_id = params[:patient_id]
      save_mastercard_attribute(params)
      if params[:source].to_s == "opd"
        redirect_to "/patients/opdcard/#{@patient_id}" and return

      else
        redirect_to :action => "patient_demographics",:patient_id => @patient_id and return
      end
    end
  end

 	def get_referral_section(person_obj, session_date)
		referral_services = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?", person_obj.id, ConceptName.find_by_name("SERVICES").concept_id, session_date.to_date])

		if referral_services.blank?
			services = PatientService.previous_referral_section(person_obj)
		else
			services = referral_services
		end

		return services
  end

  def summary
    @encounter_type = params[:skipped]
    @patient_id = params[:patient_id]
    render :layout => "menu"
  end
  
  def demographics
	  @patient_bean = PatientService.get_patient(@patient.person)
    render :layout => false
  end

  def patient_details
    render :layout => false
  end

  def status_details
    render :layout => false
  end

  def mastercard_details
    render :layout => false
  end

  def mastercard_header
    render :layout => false
  end

  def next_task_description
    @task = Task.find(params[:task_id])
    render :template => 'dashboards/next_task_description', :layout => false
  end

  def alerts(patient, session_date = Date.today) 
    # next appt
    # adherence
    # drug auto-expiry
    # cd4 due
		patient_bean = PatientService.get_patient(patient.person)
    alerts = []
		
		weight = 0; height = 0

		if !PatientService.get_patient_attribute_value(patient, "current_weight").blank?
			weight = PatientService.get_patient_attribute_value(patient, "current_weight")
		end

		if !PatientService.get_patient_attribute_value(patient, "current_height").blank?
			height = PatientService.get_patient_attribute_value(patient, "current_weight")
		end

    # BMI alerts
    if patient_bean.age >= 15
      bmi_alert = current_bmi_alert(weight, height)
      alerts << bmi_alert if bmi_alert
    end

    alerts << "Demographics: Area of residence has not been changed in the past 6 months" if PatientService.months_since_last_update_area_of_residence(patient_bean.person_id) >= 6

    alerts
  end

  # Get the any BMI-related alert for this patient
  def current_bmi_alert(patient_weight, patient_height)
    weight = patient_weight
    height = patient_height
    alert = nil
    unless weight == 0 || height == 0
      current_bmi = (weight/(height*height)*10000).round(1);
      if current_bmi <= 18.5 && current_bmi > 17.0
        alert = 'Low BMI: Eligible for counseling'
      elsif current_bmi <= 17.0
        alert = 'Low BMI: Eligible for therapeutic feeding'
      end
    end

    alert
  end

  def programs_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
	  @referral_section = PatientService.previous_referral_section(@patient.person).first.value_text rescue 'None'
    render :template => 'dashboards/programs_dashboard', :layout => false
  end

  def mastercard_demographics(patient_obj)
  	patient_bean = PatientService.get_patient(patient_obj.person)
    visits = Mastercard.new()
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_bean.arv_number
    visits.address = patient_bean.address
    visits.national_id = patient_bean.national_id
    visits.name = patient_bean.name rescue nil
    visits.sex = patient_bean.sex
    visits.age = patient_bean.age
    visits.occupation = PatientService.get_attribute(patient_obj.person, 'Occupation')
    visits.landmark = patient_obj.person.addresses.first.address1
    visits.init_wt = PatientService.get_patient_attribute_value(patient_obj, "initial_weight")
    visits.init_ht = PatientService.get_patient_attribute_value(patient_obj, "initial_height")
    visits.bmi = PatientService.get_patient_attribute_value(patient_obj, "initial_bmi")
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = visits.hiv_test_location.to_s.split(':')[1].strip rescue nil
    visits
  end

  def save_mastercard_attribute(params)
    patient = Patient.find(params[:patient_id])
    case params[:field]
    when "name"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "first_name"
      names_params =  {"given_name" => params[:given_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "last_name"
      names_params =  {"family_name" => params[:family_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "age"
      birthday_params = params[:person]

      if !birthday_params.empty?
        if birthday_params["birth_year"] == "Unknown"
          PatientService.set_birthdate_by_age(patient.person, birthday_params["age_estimate"])
        else
          PatientService.set_birthdate(patient.person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
        end
        patient.person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
        patient.person.save
      end
    when "sex"
      gender ={"gender" => params[:gender].to_s}
      patient.person.update_attributes(gender) if !gender.empty?
    when "location"
      location = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(location) if location
    when "occupation"
      attribute = params[:person][:attributes]
      occupation_attribute = PersonAttributeType.find_by_name("Occupation")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, occupation_attribute.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:occupation].to_s})
      end
    when "address"
      address2 = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(address2) if address2
    when "home_district"
      address2 = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(address2) if address2
    when "city_village"
      city_village = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(city_village) if city_village
    when "ta"
      county_district = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(county_district) if county_district
    when "cell_phone_number"
      attribute = params[:person][:attributes]
      cell_phone_number_attribute = PersonAttributeType.find_by_name("Cell Phone Number")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, cell_phone_number_attribute.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:cell_phone_number].to_s})
      end
   when "home_phone_number"
      attribute = params[:person][:attributes]
      cell_phone_number_attribute = PersonAttributeType.find_by_name("Home Phone Number")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, cell_phone_number_attribute.person_attribute_type_id]) rescue nil

      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:home_phone_number].to_s})
      end
    end
  end

  def edit_mastercard_attribute(attribute_name)
    edit_page = attribute_name
  end

  def void_encounter
    @encounter = Encounter.find(params[:encounter_id])
    ActiveRecord::Base.transaction do
      @encounter.void
    end
    return
  end
  
  private

end
