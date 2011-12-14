class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today

	  @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
	  @patient_bean = PatientService.get_patient(@patient.person)
	  @encounters = @patient.encounters.find_by_date(session_date)
    @ward = referral_section
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
        @hiv_status = PatientService.patient_hiv_status(@patient)
        @reason_for_art_eligibility = PatientService.reason_for_art_eligibility(@patient)
        @arv_number = PatientService.get_patient_identifier(@patient, 'ARV Number')
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

    @links << ["Demographics (Print)","/patients/print_demographics/#{patient.id}"]
    @links << ["Visit Summary (Print)","/patients/dashboard_print_visit/#{patient.id}"]
    @links << ["National ID (Print)","/patients/dashboard_print_national_id/#{patient.id}"]

    if use_filing_number and not PatientService.get_patient_identifier(patient, 'Filing Number').blank?
      @links << ["Filing Number (Print)","/patients/print_filing_number/#{patient.id}"]
    end 

    @links << ["Recent Lab Orders Label","/patients/recent_lab_orders?patient_id=#{patient.id}"]
    @links << ["Transfer out label (Print)","/patients/print_transfer_out_label/#{patient.id}"]

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
  
  def dashboard_print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")
  end
  
  def print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end

  def print_demographics
    print_and_redirect("/patients/patient_demographics_label/#{@patient.id}", "/patients/show/#{params[:id]}")
  end
 
  def print_filing_number
    print_and_redirect("/patients/filing_number_label/#{params[:id]}", "/patients/show/#{params[:id]}")  
  end
   
  def print_transfer_out_label
    print_and_redirect("/patients/transfer_out_label?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")  
  end
   
  def patient_demographics_label
    print_string = demographics_label(params[:id])
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def national_id_label
    print_string = PatientService.patient_national_id_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_lab_orders
    print_and_redirect("/patients/lab_orders_label/?patient_id=#{@patient.id}", next_task(@patient))
  end

  def lab_orders_label
    label_commands = patient_lab_orders_label(@patient.id)
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def filing_number_label
    patient = Patient.find(params[:id])
    label_commands = patient_filing_number_label(patient)
    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def filing_number_and_national_id
    patient = Patient.find(params[:patient_id])
    label_commands = PatientService.patient_national_id_label(patient) + patient_filing_number_label(patient)

    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def visit_label
    print_string = patient_visit_label(@patient) rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
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

  def number_of_booked_patients
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id
    count = Observation.count(:all,
            :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
            :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
            concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    render :text => count
  end

  def recent_lab_orders_print
    patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].split(":")

    label_commands = recent_lab_orders_label(lab_orders_label, patient)
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbs", :disposition => "inline")
  end

  def print_recent_lab_orders_label
    lab_orders_label = params[:lab_tests].join(":")
    print_and_redirect("/patients/recent_lab_orders_print/#{params[:id]}?lab_tests=#{lab_orders_label}" , "/patients/show/#{params[:id]}")
  end

  def recent_lab_orders
    patient = Patient.find(params[:patient_id])
    @lab_order_labels = get_recent_lab_orders_label(patient.id)
    @patient_id = params[:patient_id]
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

    type = EncounterType.find_by_name("APPOINTMENT")
    next_appt = Observation.find(:first,:order => "encounter_datetime DESC,encounter.date_created DESC",
               :joins => "INNER JOIN encounter ON obs.encounter_id = encounter.encounter_id",
               :conditions => ["concept_id = ? AND encounter_type = ? AND patient_id = ?",
               ConceptName.find_by_name('Appointment date').concept_id,
               type.id,patient.id]).to_s rescue nil
    alerts << ('Next ' + next_appt).capitalize unless next_appt.blank?

    # BMI alerts
    if patient_bean.age >= 15
      bmi_alert = current_bmi_alert(PatientService.get_patient_attribute_value(patient, "current_weight"), PatientService.get_patient_attribute_value(patient, "current_height"))
      alerts << bmi_alert if bmi_alert
    end

    hiv_status = PatientService.patient_hiv_status(patient)
    alerts << "HIV Status : #{hiv_status} more than 3 months" if ("#{hiv_status.strip}" == 'Negative' && PatientService.months_since_last_hiv_test(patient.id) > 3)
   
    alerts << "HIV Status : #{hiv_status}" if "#{hiv_status.strip}" == 'Unknown'

    alerts
  end

  def get_recent_lab_orders_label(patient_id)
    encounters = Encounter.find(:all,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient_id]).last(5)
      observations = []

    encounters.each{|encounter|
      encounter.observations.each{|observation|
       unless observation['concept_id'] == Concept.find_by_name("Workstation location").concept_id
          observations << ["#{ConceptName.find_by_concept_id(observation['value_coded'].to_i).name} : #{observation['date_created'].strftime("%Y-%m-%d") }",
                            "#{observation['obs_id']}"]
       end
      }
    }
    return observations
  end

  def recent_lab_orders_label(test_list, patient)
  	patient_bean = PatientService.get_patient(patient.person)
    lab_orders = test_list
    labels = []
    i = 0
    lab_orders.each{|test|
      observation = Observation.find(test.to_i)

      accession_number = "#{observation.accession_number rescue nil}"
		patient_national_id_with_dashes = PatientService.get_national_id_with_dashes(patient)
        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
          label.draw_multi_text("#{patient_bean.name.titleize.delete("'")} #{patient_national_id_with_dashes}")
          label.draw_multi_text("#{observation.name rescue nil} - #{accession_number rescue nil}")
          label.draw_multi_text("#{observation.date_created.strftime("%d-%b-%Y %H:%M")}")
          labels << label
         end

         i = i + 1
    }

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(1) if labels[label] != nil
        label = label + 1
      end

      return print_labels
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

  #moved from the patient model. Needs good testing
  def demographics_label(patient_id)
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    demographics = mastercard_demographics(patient)
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient.id])

    tb_within_last_two_yrs = "tb within last 2 yrs" unless demographics.tb_within_last_two_yrs.blank?
    eptb = "eptb" unless demographics.eptb.blank?
    pulmonary_tb = "Pulmonary tb" unless demographics.pulmonary_tb.blank?

    cd4_count_date = nil ; cd4_count = nil ; pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        pregnant = obs.to_s.split(':')[1] rescue nil
      end
    end rescue []

    office_phone_number = PatientService.get_attribute(patient.person, 'Office phone number')
    home_phone_number = PatientService.get_attribute(patient.person, 'Home phone number')
    cell_phone_number = PatientService.get_attribute(patient.person, 'Cell phone number')

    phone_number = office_phone_number if not office_phone_number.downcase == "not available" and not office_phone_number.downcase == "unknown" rescue nil
    phone_number= home_phone_number if not home_phone_number.downcase == "not available" and not home_phone_number.downcase == "unknown" rescue nil
    phone_number = cell_phone_number if not cell_phone_number.downcase == "not available" and not cell_phone_number.downcase == "unknown" rescue nil

    initial_height = PatientService.get_patient_attribute_value(patient, "initial_height")
    initial_weight = PatientService.get_patient_attribute_value(patient, "initial_weight")

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{PatientService.birthdate_formatted(patient.person)}",25,90,0,3,1,1,false)
    label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
    if demographics.address.length > 48
      label.draw_text("Addr:  #{demographics.address[0..47]}",25,150,0,3,1,1,false)
      label.draw_text("    :  #{demographics.address[48..-1]}",25,180,0,3,1,1,false)
      last_line = 180
    else
      label.draw_text("Addr:  #{demographics.address}",25,150,0,3,1,1,false)
      last_line = 150
    end

    label.draw_text("Occupation:    #{demographics.occupation}",25,last_line+=30,0,3,1,1,false)
    label.draw_text("Landmark:   #{demographics.landmark}",25,last_line+=30,0,3,1,1,false)


    label2 = ZebraPrinter::StandardLabel.new

    label2.draw_line(25,170,795,3)
    label2.draw_text("HEIGHT: #{initial_height}",570,70,0,2,1,1,false)
    label2.draw_text("WEIGHT: #{initial_weight}",570,110,0,2,1,1,false)

    return "#{label.print(1)} #{label2.print(1)}"
  end

  def referral_section
    @patient_bean = PatientService.get_patient(@patient.person)
    
    ward = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", @patient.person.id, ConceptName.find_by_name("WARD").concept_id])
   
    if ward.value_text
        @ward = ward.value_text
    else
        @ward = ConceptName.find_by_concept_id(ward.value_coded).name
    end
  end

  def programs_dashboard
	  @patient_bean = PatientService.get_patient(@patient.person)
    @ward = referral_section
    render :template => 'dashboards/programs_dashboard', :layout => false
  end

  def patient_transfer_out_label(patient_id)
    patient = Patient.find(patient_id)
    patient_bean = PatientService.get_patient(patient.person)
    demographics = mastercard_demographics(patient)
    demographics_str = []
    demographics_str << "Name: #{demographics.name}"
    demographics_str << "DOB: #{patient_bean.birth_date}"
    demographics_str << "DOB-E: #{patient_bean.birthdate_estimated}"
    demographics_str << "Sex: #{demographics.sex}"
    demographics_str << "Guardian name: #{demographics.guardian}"
    demographics_str << "ARV number: #{demographics.arv_number}"
    demographics_str << "National ID: #{demographics.national_id}"

    demographics_str << "Address: #{demographics.address}"
    demographics_str << "FU: #{demographics.agrees_to_followup}"
    demographics_str << "1st alt line: #{demographics.alt_first_line_drugs.join(':')}"
    demographics_str << "BMI: #{demographics.bmi}"
    demographics_str << "CD4: #{demographics.cd4_count}"
    demographics_str << "CD4 date: #{demographics.cd4_count_date}"
    demographics_str << "1st line date: #{demographics.date_of_first_line_regimen}"
    demographics_str << "ERA: #{demographics.ever_received_art}"
    demographics_str << "1st line: #{demographics.first_line_drugs.join(':')}"
    demographics_str << "1st pos HIV test date: #{demographics.first_positive_hiv_test_date}"

    demographics_str << "1st pos HIV test site: #{demographics.first_positive_hiv_test_site}"
    demographics_str << "1st pos HIV test type: #{demographics.first_positive_hiv_test_type}"
    demographics_str << "Test date: #{demographics.hiv_test_date.gsub('/','-')}" if demographics.hiv_test_date
    demographics_str << "Test loc: #{demographics.hiv_test_location}"
    demographics_str << "Init HT: #{demographics.init_ht}"
    demographics_str << "Init WT: #{demographics.init_wt}"
    demographics_str << "Landmark: #{demographics.landmark}"
    demographics_str << "Occupation: #{demographics.occupation}"
    demographics_str << "Preg: #{demographics.pregnant}" if patient.person.gender == 'F'
    demographics_str << "SR: #{demographics.reason_for_art_eligibility}"
    demographics_str << "2nd line: #{demographics.second_line_drugs}"
    demographics_str << "TB status: #{demographics.tb_status_at_initiation}"
    demographics_str << "TI: #{demographics.transfer_in}"
    demographics_str << "TI date: #{demographics.transfer_in_date}"


    visits = visits(patient) ; count = 0 ; visit_str = nil
    (visits || {}).sort{|a,b| b[0].to_date<=>a[0].to_date}.each do | date,visit |
      break if count > 3
      visit_str = "Visit date: #{date}" if visit_str.blank?
      visit_str += ";Visit date: #{date}" unless visit_str.blank?
      visit_str += ";wt: #{visit.weight}" if visit.weight
      visit_str += ";ht: #{visit.height}" if visit.height
      visit_str += ";bmi: #{visit.bmi}" if visit.bmi
      visit_str += ";Outcome: #{visit.outcome}" if visit.outcome
      visit_str += ";Regimen: #{visit.reg}" if visit.reg
      visit_str += ";Adh: #{visit.adherence.join(' ')}" if visit.adherence
      visit_str += ";TB status: #{visit.tb_status}" if visit.tb_status
      gave = nil
      (visit.gave.uniq || []).each do | name , quantity |
        gave += "  #{name} (#{quantity})" unless gave.blank?
        gave = ";Gave: #{name} (#{quantity})" if gave.blank?
      end rescue []
      visit_str += gave unless gave.blank?
      count+=1
      demographics_str << visit_str
    end

    label = ZebraPrinter::StandardLabel.new
    label.draw_2D_barcode(80,20,'P',700,600,'x2','y7','l100','r100','f0','s5',"#{demographics_str.join(',').gsub('/','')}")
    label.print(1)
  end

  def patient_lab_orders_label(patient_id)
    patient = Patient.find(patient_id)
    lab_orders = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,patient.id]).observations
      labels = []
      i = 0

      while i <= lab_orders.size do
        accession_number = "#{lab_orders[i].accession_number rescue nil}"
		patient_national_id_with_dashes = PatientService.get_national_id_with_dashes(patient) 
        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::Label.new(500,165)
          label.font_size = 2
          label.font_horizontal_multiplier = 1
          label.font_vertical_multiplier = 1
          label.left_margin = 300
          label.draw_barcode(50,105,0,1,4,8,50,false,"#{accession_number}")
          label.draw_multi_text("#{patient.person.name.titleize.delete("'")} #{patient_national_id_with_dashes}")
          label.draw_multi_text("#{lab_orders[i].name rescue nil} - #{accession_number rescue nil}")
          label.draw_multi_text("#{lab_orders[i].obs_datetime.strftime("%d-%b-%Y %H:%M")}")
          labels << label
          end
          i = i + 1
      end

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(2) if labels[label] != nil
        label = label + 1
      end

      return print_labels
  end

  def patient_filing_number_label(patient, num = 1)
    file = PatientService.get_patient_identifier(patient, 'Filing Number')[0..9]
    file_type = file.strip[3..4]
    version_number=file.strip[2..2]
    number = file
    len = number.length - 5
    number = number[len..len] + "   " + number[(len + 1)..(len + 2)]  + " " +  number[(len + 3)..(number.length)]

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("#{number}",75, 30, 0, 4, 4, 4, false)
    label.draw_text("Filing area #{file_type}",75, 150, 0, 2, 2, 2, false)
    label.draw_text("Version number: #{version_number}",75, 200, 0, 2, 2, 2, false)
    label.print(num)
  end

  def patient_visit_label(patient, date = Date.today)
    result = Location.current_location.name.match(/outpatient/i).nil?

    if result == false
      return mastercard_visit_label(patient,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = patient.encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.humanize == "Registration"
        label.draw_multi_text("#{encounter.name.humanize}: #{encounter.to_s}", :font_reverse => false)
      }
      label.print(1)
    end
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

  def visits(patient_obj,encounter_date = nil)
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    if encounter_date.blank?
      observations = Observation.find(:all,:conditions =>["voided = 0 AND person_id = ?",patient_obj.patient_id],:order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    else
      observations = Observation.find(:all,
        :conditions =>["voided = 0 AND person_id = ? AND Date(obs_datetime) = ?",
        patient_obj.patient_id,encounter_date.to_date],:order =>"obs_datetime").map{|obs| obs if !obs.concept.nil?}
    end

    clinic_encounters = ["APPOINTMENT", "HEIGHT","WEIGHT","PATIENT REGISTRATION","VISIT","BMI"]
    clinic_encounters.map do |field|
      gave_hash = Hash.new(0) 
      observations.map do |obs|
         encounter_name = obs.encounter.name rescue []
         next if encounter_name.blank?
         next if encounter_name.match(/REGISTRATION/i)
         visit_date = obs.obs_datetime.to_date
         patient_visits[visit_date] = Mastercard.new() if patient_visits[visit_date].blank?
         case field
          when 'APPOINTMENT'
            concept_name = obs.concept.fullname
            next unless concept_name.upcase == 'APPOINTMENT DATE' 
            patient_visits[visit_date].appointment_date = obs.value_datetime
          when 'HEIGHT'
            concept_name = obs.concept.fullname rescue nil
            next unless concept_name.upcase == 'HEIGHT (CM)' 
            patient_visits[visit_date].height = obs.value_numeric
          when "WEIGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'WEIGHT (KG)' 
            patient_visits[visit_date].weight = obs.value_numeric
          when "BMI"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name.upcase == 'BODY MASS INDEX, MEASURED' 
            patient_visits[visit_date].bmi = obs.value_numeric
         end
      end
    end

    patient_visits
  end

  def save_mastercard_attribute(params)
    patient = Patient.find(params[:patient_id])
    case params[:field]
    when "name"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
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
