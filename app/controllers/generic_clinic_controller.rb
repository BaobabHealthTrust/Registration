class GenericClinicController < ApplicationController
  def index
  	session[:cohort] = nil
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = session[:datetime].to_date rescue Date.today.to_date

		@person = Person.find_by_person_id(current_user.person_id)

    @user = PatientService.name(@person)

    @roles = current_user.user_roles.collect{|r| r.role} rescue []

    render :template => 'clinic/index', :layout => false
  end

  def reports
    @reports = [
      ["Cohort","/cohort_tool/cohort_menu"],
      ["Supervision","/clinic/supervision"],
      ["Data Cleaning Tools", "/report/data_cleaning"],
      ["Stock report","/drug/date_select"]
    ]

    render :template => 'clinic/reports', :layout => 'clinic' 
  end

  def supervision
    @supervision_tools = [["Data that was Updated","summary_of_records_that_were_updated"],
      ["Drug Adherence Level","adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day", "visits_by_day"],
      ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

    @landing_dashboard = 'clinic_supervision'

    render :template => 'clinic/supervision', :layout => 'clinic' 
  end

  def properties
    @settings = [
      ["Set clinic days","/properties/clinic_days"],
      ["View clinic holidays","/properties/clinic_holidays"],
      ["Set clinic holidays","/properties/set_clinic_holidays"],
      ["Set site code", "/properties/site_code"],
      ["Set appointment limit", "/properties/set_appointment_limit"]
    ]
    render :template => 'clinic/properties', :layout => 'clinic' 
  end

  def management
    @reports = [
      ["New stock","delivery"],
      ["Edit stock","edit_stock"],
      ["Print Barcode","print_barcode"],
      ["Expiring drugs","date_select"],
      ["Removed from shelves","date_select"],
      ["Stock report","date_select"]
    ]
    render :template => 'clinic/management', :layout => 'clinic' 
  end

  def printing
    render :template => 'clinic/printing', :layout => 'clinic' 
  end

  def users
    render :template => 'clinic/users', :layout => 'clinic' 
  end

  def administration
    @reports =  [
                  ['/clinic/users','User accounts/settings'],
                  ['/clinic/management','Drug Management'], 
                  ['/clinic/location_management','Location Management']
                ]
    @landing_dashboard = 'clinic_administration'
    render :template => 'clinic/administration', :layout => 'clinic' 
  end

	def overview_tab
    simple_overview_property = CoreService.get_global_property_value("simple_application_dashboard") rescue nil

    simple_overview = false
    if simple_overview_property != nil
      if simple_overview_property == 'true'
        simple_overview = true
      end
    end
		
		@session_date = Date.today.to_date
		
		if session[:datetime]
			@session_date = session[:datetime].to_date
		end

    @types = EncounterType.all.map{|encounter_type| encounter_type.name if encounter_type.name == "REGISTRATION"}.to_s

    @current_user_id = current_user.user_id

    @me = Encounter.patient_registration(@types, @current_user_id, :conditions => ['DATE(patient.date_created) = DATE(NOW()) AND patient.creator = ?', current_user.user_id])

    @today = Encounter.patient_registration_total(@types, :conditions => ['DATE(date_created) = DATE(NOW())'])
    
    if !simple_overview
    	@types = CoreService.get_global_property_value("statistics.show_encounter_types") rescue EncounterType.all.map(&:name).join(",")
    	@types = @types.split(/,/)

    	@me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ?', current_user.user_id])
   	 @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW())'])

    	
      @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW())'])
      @ever = Encounter.statistics(@types)
    end

    @person = Person.find_by_person_id(current_user.person_id)

    @user = PatientService.name(@person)
		
		@services = PatientService.services(@current_user_id, @session_date)

		@existing_patients_by_current_user = 0
		@existing_patients_by_current_user = @services.length - @me['REGISTRATION'].to_i
		
		if @existing_patients_by_current_user < 0
			@existing_patients_by_current_user = 0
		end
		
		@casualty = []; @dental = []; @eye = []; @family_planing = []; @medical = []; @ob_gyn = [];
		@orthopedics = []; @other = []; @pediatrics = []; @skin = []; @sti_clinic = []; @surgical = []

 		@services.each do |service|
 			if service.value_text.capitalize.include?("Casualty")
 				@casualty << service
 			elsif service.value_text.capitalize.include?("Dental")
 				@dental << service
 			elsif service.value_text.capitalize.include?("Eye")
 				@eye << service
 			elsif service.value_text.include?("Family Planing")
 				@family_planing << service
 			elsif service.value_text.capitalize.include?("Medical")
 				@medical << service
 			elsif service.value_text.include?("OB/Gyn")
 				@ob_gyn << service
 			elsif service.value_text.capitalize.include?("Orthopedics")
 				@orthopedics << service
 			elsif service.value_text.capitalize.include?("Pediatrics")
 				@pediatrics << service
 			elsif service.value_text.strip.include?("Skin")
 				@skin << service
 			elsif service.value_text.include?("STI Clinic")
 				@sti_clinic << service
 			elsif service.value_text.capitalize.include?("Surgical")
 				@surgical << service
 			else service.value_text.capitalize.include?(" Other ")
 				@other << service
 			end
 		end

		@all_services = PatientService.all_services(@session_date)
		
		@existing_patients_by_all_users = 0
		@existing_patients_by_all_users = PatientService.all_patient_services.length - @today['REGISTRATION'].to_i
		if @existing_patients_by_all_users < 0
			@existing_patients_by_all_users = 0
		end
		
		@all_casualty = []; @all_dental = []; @all_eye = []; @all_family_planing = []; @all_medical = []; @all_ob_gyn = [];
		@all_orthopedics = []; @all_other = []; @all_pediatrics = []; @all_skin = []; @all_sti_clinic = []; @all_surgical = []

 		@all_services.each do |service|
 			if service.value_text.capitalize.include?("Casualty")
 				@all_casualty << service
 			elsif service.value_text.capitalize.include?("Dental")
 				@all_dental << service
 			elsif service.value_text.capitalize.include?("Eye")
 				@all_eye << service
 			elsif service.value_text.include?("Family Planing")
 				@all_family_planing << service
 			elsif service.value_text.capitalize.include?("Medical")
 				@all_medical << service
 			elsif service.value_text.include?("OB/Gyn")
 				@all_ob_gyn << service
 			elsif service.value_text.capitalize.include?("Orthopedics")
 				@all_orthopedics << service
 			elsif service.value_text.capitalize.include?("Pediatrics")
 				@all_pediatrics << service
 			elsif service.value_text.strip.include?("Skin")
 				@all_skin << service
 			elsif service.value_text.include?("STI Clinic")
 				@all_sti_clinic << service
 			elsif service.value_text.capitalize.include?("Surgical")
 				@all_surgical << service
 			else service.value_text.capitalize.include?(" Other ")
 				@all_other << service
 			end
 		end

    if simple_overview
        render :template => 'clinic/overview_simple.rhtml' , :layout => false
        return
    end
    render :layout => false
  end

  def reports_tab
    @reports = [
      ["Referral Report","/cohort_tool/referral_menu"],
      ["Registry Report","/cohort_tool/cohort_menu"]
     
    ]

    @reports = [
      ["Diagnosis","/drug/date_select?goto=/report/age_group_select?type=diagnosis"],
      ["Disaggregated Diagnosis","/drug/date_select?goto=/report/age_group_select?type=disaggregated_diagnosis"],
      ["Referrals","/drug/date_select?goto=/report/opd?type=referrals"],
      ["User Stats","/"],
      ["Diagnosis (By address)","/drug/date_select?goto=/report/age_group_select?type=diagnosis_by_address"],
      ["Diagnosis + demographics","/drug/date_select?goto=/report/age_group_select?type=diagnosis_by_demographics"]
    ] if Location.current_location.name.match(/Outpatient/i)
    render :layout => false
  end

  def data_cleaning_tab
    @reports = [
                 ['Missing Prescriptions' , '/cohort_tool/select?report_type=dispensations_without_prescriptions'],
                 ['Missing Dispensations' , '/cohort_tool/select?report_type=prescriptions_without_dispensations'],
                 ['Multiple Start Reasons' , '/cohort_tool/select?report_type=patients_with_multiple_start_reasons'],
                 ['Out of range ARV number' , '/cohort_tool/select?report_type=out_of_range_arv_number'],
                 ['Data Consistency Check' , '/cohort_tool/select?report_type=data_consistency_check']
               ] 
    render :layout => false
  end

  def properties_tab
    if current_program_location.match(/HIV program/i)
      @settings = [
        ["Set Clinic Days","/properties/clinic_days"],
        ["View Clinic Holidays","/properties/clinic_holidays"],
        ["Ask Pills remaining at home","/properties/creation?value=ask_pills_remaining_at_home"],
        ["Set Clinic Holidays","/properties/set_clinic_holidays"],
        ["Set Site Code", "/properties/site_code"],
        ["Manage Roles", "/properties/set_role_privileges"],
        ["Use Extended Staging Format", "/properties/creation?value=use_extended_staging_format"],
        ["Use User Selected Task(s)", "/properties/creation?value=use_user_selected_activities"],
        ["Use Filing Numbers", "/properties/creation?value=use_filing_numbers"],
        ["Show Lab Results", "/properties/creation?value=show_lab_results"],
        ["Set Appointment Limit", "/properties/set_appointment_limit"]
      ]
    else
      @settings = []
    end
    render :layout => false
  end

  def administration_tab
    @reports =  [
                  ['/clinic/users_tab','User Accounts'],
                  ['/clinic/location_management_tab','Location Management'],
                ]
    @landing_dashboard = 'clinic_administration'
    render :layout => false
  end

  def supervision_tab
    @reports = [
                 ["Data that was Updated","/cohort_tool/select?report_type=summary_of_records_that_were_updated"],
                 ["Drug Adherence Level","/cohort_tool/select?report_type=adherence_histogram_for_all_patients_in_the_quarter"],
                 ["Visits by Day", "/cohort_tool/select?report_type=visits_by_day"],
                 ["Non-eligible Patients in Cohort", "/cohort_tool/select?report_type=non_eligible_patients_in_cohort"]
               ]
    @landing_dashboard = 'clinic_supervision'
    render :layout => false
  end

  def users_tab
    render :layout => false
  end

  def location_management
    @reports =  [
                  ['/location/new?act=create','Add location'],
                  ['/location.new?act=delete','Delete location'], 
                  ['/location/new?act=print','Print location']
                ]
    render :template => 'clinic/location_management', :layout => 'clinic' 
  end

  def location_management_tab
    @reports =  [
                  ['/location/new?act=print','Print location']
                ]
    if current_user.admin?
      @reports << ['/location/new?act=create','Add location']
      @reports << ['/location/new?act=delete','Delete location']
    end
    render :layout => false
  end

  def management_tab
    @reports = [
      ["Enter receipts<br />(from warehouse)","delivery"],
      ["Enter verified stock count<br />(supervision)","delivery?id=verification"],
      ["Print<br />Barcode","print_barcode"],
      ["Expiring<br />drugs","date_select"],
      ["Enter drug relocation<br />(in or out) / disposal","edit_stock"],
      ["Stock<br />report","date_select"]
    ]
    render :layout => false
  end
  
  def lab_tab
    #only applicable in the sputum submission area
    enc_date = session[:datetime].to_date rescue Date.today
    @types = ['LAB ORDERS', 'SPUTUM SUBMISSION', 'LAB RESULTS', 'GIVE LAB RESULTS']
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = ? AND encounter.creator = ?', enc_date, current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = ?', enc_date])
    @user = User.find(current_user.user_id).name rescue ""

    render :template => 'clinic/lab_tab.rhtml' , :layout => false
  end

end
