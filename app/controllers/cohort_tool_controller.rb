class CohortToolController < ApplicationController

  def select
    @cohort_quarters  = [""]
    @report_type      = params[:report_type]
    @header 	        = params[:report_type] rescue ""
    @page_destination = ("/" + params[:dashboard].gsub("_", "/")) rescue ""

    if @report_type == "in_arv_number_range"
      @arv_number_start = params[:arv_number_start]
      @arv_number_end   = params[:arv_number_end]
    end

    start_date  = PatientService.initial_encounter.encounter_datetime rescue Date.today

    end_date    = Date.today

    @cohort_quarters  += Report.generate_cohort_quarters(start_date, end_date)
  end

  def records_that_were_updated
    @quarter    = params[:quarter]

    date_range  = Report.generate_cohort_date_range(@quarter)
    @start_date = date_range.first
    @end_date   = date_range.last

    @encounters = records_that_were_corrected(@quarter)

    render :layout => false
  end

  def records_that_were_corrected(quarter)

    date        = Report.generate_cohort_date_range(quarter)
    start_date  = (date.first.to_s  + " 00:00:00")
    end_date    = (date.last.to_s   + " 23:59:59")

    voided_records = {}

    other_encounters = Encounter.find_by_sql("SELECT encounter.* FROM encounter
                        INNER JOIN obs ON encounter.encounter_id = obs.encounter_id
                        WHERE ((encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'))
                        GROUP BY encounter.encounter_id
                        ORDER BY encounter.encounter_type, encounter.patient_id")

    drug_encounters = Encounter.find_by_sql("SELECT encounter.* as duration FROM encounter
                        INNER JOIN orders ON encounter.encounter_id = orders.encounter_id
                        WHERE ((encounter.encounter_datetime BETWEEN '#{start_date}' AND '#{end_date}'))
                        ORDER BY encounter.encounter_type")

    voided_encounters = []
    other_encounters.delete_if { |encounter| voided_encounters << encounter if (encounter.voided == 1)}

    voided_encounters.map do |encounter|
      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)

      new_encounter  = other_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
                        e.patient_id      == encounter.patient_id &&
                        e.encounter_type  == encounter. encounter_type)
        result
      end

      new_encounter = new_encounter.last

      next if new_encounter.nil?

      voided_observations = voided_observations(encounter)
      changed_to    = changed_to(new_encounter)
      changed_from  = changed_from(voided_observations)

      if( voided_observations && !voided_observations.empty?)
          voided_records[encounter.id] = {
              "id"              => patient.patient_id,
              "arv_number"      => patient_bean.arv_number,
              "name"            => patient_bean.name,
              "national_id"     => patient_bean.national_id,
              "encounter_name"  => encounter.name,
              "voided_date"     => encounter.date_voided,
              "reason"          => encounter.void_reason,
              "change_from"     => changed_from,
              "change_to"       => changed_to
            }
      end
    end

    voided_treatments = []
    drug_encounters.delete_if { |encounter| voided_treatments << encounter if (encounter.voided == 1)}

    voided_treatments.each do |encounter|

      patient           = Patient.find(encounter.patient_id)
      patient_bean = PatientService.get_patient(patient.person)
      
      orders            = encounter.orders
      changed_from      = ''
      changed_to        = ''

     new_encounter  =  drug_encounters.reduce([])do |result, e|
        result << e if( e.encounter_datetime.strftime("%d-%m-%Y") == encounter.encounter_datetime.strftime("%d-%m-%Y")&&
                        e.patient_id      == encounter.patient_id &&
                        e.encounter_type  == encounter. encounter_type)
          result
        end

      new_encounter = new_encounter.last

      next if new_encounter.nil?
      changed_from  += "Treatment: #{voided_orders(new_encounter).to_s.gsub!(":", " =>")}</br>"
      changed_to    += "Treatment: #{encounter.to_s.gsub!(":", " =>") }</br>"

      if( orders && !orders.empty?)
        voided_records[encounter.id]= {
            "id"              => patient.patient_id,
            "arv_number"      => patient_bean.arv_number,
            "name"            => patient_bean.name,
            "national_id"     => patient_bean.national_id,
            "encounter_name"  => encounter.name,
            "voided_date"     => encounter.date_voided,
            "reason"          => encounter.void_reason,
            "change_from"     => changed_from,
            "change_to"       => changed_to
        }
      end

    end

    show_tabuler_format(voided_records)
  end

   def show_tabuler_format(records)

    patients = {}

    records.each do |key,value|

      sorted_values = sort(value)

      patients["#{key},#{value['id']}"] = sorted_values
    end

    patients
  end

  def sort(values)
    name              = ''
    patient_id        = ''
    arv_number        = ''
    national_id       = ''
    encounter_name    = ''
    voided_date       = ''
    reason            = ''
    obs_names         = ''
    changed_from_obs  = {}
    changed_to_obs    = {}
    changed_data      = {}

    values.each do |value|
      value_name =  value.first
      value_data =  value.last

      case value_name
        when "id"
          patient_id = value_data
        when "arv_number"
          arv_number = value_data
        when "name"
          name = value_data
        when "national_id"
          national_id = value_data
        when "encounter_name"
          encounter_name = value_data
        when "voided_date"
          voided_date = value_data
        when "reason"
          reason = value_data
        when "change_from"
          value_data.split("</br>").each do |obs|
            obs_name  = obs.split(':')[0].strip
            obs_value = obs.split(':')[1].strip rescue ''

            changed_from_obs[obs_name] = obs_value
          end unless value_data.blank?
        when "change_to"

          value_data.split("</br>").each do |obs|
            obs_name  = obs.split(':')[0].strip
            obs_value = obs.split(':')[1].strip rescue ''

            changed_to_obs[obs_name] = obs_value
          end unless value_data.blank?
      end
    end

    changed_from_obs.each do |a,b|
      changed_to_obs.each do |x,y|

        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_from_obs.delete(a)
          changed_to_obs.delete(x)
        end
      end
    end

    changed_to_obs.each do |a,b|
      changed_from_obs.each do |x,y|
        if (a == x)
          next if b == y
          changed_data[a] = "#{b} to #{y}"

          changed_to_obs.delete(a)
          changed_from_obs.delete(x)
        end
      end
    end

    changed_data.each do |k,v|
      from  = v.split("to")[0].strip rescue ''
      to    = v.split("to")[1].strip rescue ''

      if obs_names.blank?
        obs_names = "#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      else
        obs_names += "</br>#{k}||#{from}||#{to}||#{voided_date}||#{reason}"
      end
    end

    results = {
        "id"              => patient_id,
        "arv_number"      => arv_number,
        "name"            => name,
        "national_id"     => national_id,
        "encounter_name"  => encounter_name,
        "voided_date"     => voided_date,
        "obs_name"        => obs_names,
        "reason"          => reason
      }

    results
  end

  def changed_from(observations)
    changed_obs = ''

    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
          when "value_coded"
            next if obs.value_coded.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_datetime"
            next if obs.value_datetime.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_numeric"
            next if obs.value_numeric.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_text"
            next if obs.value_text.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_modifier"
            next if obs.value_modifier.blank?
            changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end

  def changed_to(enc)
    encounter_type = enc.encounter_type

    encounter = Encounter.find(:first,
                 :joins       => "INNER JOIN obs ON encounter.encounter_id=obs.encounter_id",
                 :conditions  => ["encounter_type=? AND encounter.patient_id=? AND Date(encounter.encounter_datetime)=?",
                                  encounter_type,enc.patient_id, enc.encounter_datetime.to_date],
                 :group       => "encounter.encounter_type",
                 :order       => "encounter.encounter_datetime DESC")

    observations = encounter.observations rescue nil
    return if observations.blank?

    changed_obs = ''
    observations.collect do |obs|
      ["value_coded","value_datetime","value_modifier","value_numeric","value_text"].each do |value|
        case value
          when "value_coded"
            next if obs.value_coded.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_datetime"
            next if obs.value_datetime.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_numeric"
            next if obs.value_numeric.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_text"
            next if obs.value_text.blank?
            changed_obs += "#{obs.to_s}</br>"
          when "value_modifier"
            next if obs.value_modifier.blank?
            changed_obs += "#{obs.to_s}</br>"
        end
      end
    end

    changed_obs.gsub("00:00:00 +0200","")[0..-6]
  end
  
  def list_patients_details
    @report = []
    @patient_registration_services = []

    include_url_params_for_back_button
#raise session[:start_date].to_yaml
    
    cohort = Cohort.new(session[:start_date],session[:end_date])
    @patient_registration_services = cohort.registration_patient_services
		
		#populating patient services
		@casualty = []; @dental = []; @eye = []; @family_planing = []; @medical = []; @ob_gyn = [];
		@orthopedics = []; @other = []; @pediatrics = []; @skin = []; @sti_clinic = []; @surgical = []
 		
 		@patient_registration_services.each do |service|
 			if service.services.include?("Casualty")
 				@casualty << service.patient_id
 			elsif service.services.include?("Dental")
 				@dental << service.patient_id
 			elsif service.services.include?("Eye")
 				@eye << service.patient_id
 			elsif service.services.include?("Family Planing")
 				@family_planing << service.patient_id
 			elsif service.services.include?("Medical")
 				@medical << service.patient_id
 			elsif service.services.include?("OB/Gyn")
 				@ob_gyn << service.patient_id
 			elsif service.services.include?("Orthopedics")
 				@orthopedics << service.patient_id
 			elsif service.services.include?("Pediatrics")
 				@pediatrics << service.patient_id
 			elsif service.services.include?(" Skin ")
 				@skin << service.patient_id
 			elsif service.services.include?("STI Clinic")
 				@sti_clinic << service.patient_id
 			elsif service.services.include?("Surgical")
 				@surgical << service.patient_id
 			else service.services.include?(" Other ")
 				@other << service.patient_id
 			end
 		end
 		
    #populating the @report with patient's details on each and every link
    case params[:field]
      when 'casualty' then
      	@casualty.each do |patient|
      	  raise patient.to_yaml
          patient = Patient.find_by_patient_id(patient.patient_id)
          @report << PatientService.get_patient(patient.person) 
        end
      when 'dental' then
        @casualty.each do |patient|
          patient = Patient.find_by_patient_id(patient)
                	  #raise PatientService.get_patient(patient.person).to_yaml
          @report << PatientService.get_patient(patient.person) 
        end
      when 'eye' then
        patients_initiated_on_art_first_time = []
    
        patients_initiated_on_art_first_time = cohort.patients_initiated_on_art_first_time
        
        patients_initiated_on_art_first_time.each do |patient_id|
          patient = Patient.find_by_patient_id(patient_id.patient_id)
          @report << PatientService.get_patient(patient.person) 
        end
      when 'family_planning' then
        patients_initiated_on_art_first_time = []

        patients_initiated_on_art_first_time = cohort.patients_initiated_on_art_first_time(@first_registration_date)
        
        patients_initiated_on_art_first_time.each do |patient_id|
          patient = Patient.find_by_patient_id(patient_id.patient_id)
          @report << PatientService.get_patient(patient.person) 
        end     
      when 'medical' then
        men_all_ages = []

        men_all_ages = cohort.total_registered_by_gender_age(start_date,end_date,"M")
        men_all_ages.each do |patient|
          patient_obj = Patient.find_by_patient_id(patient.patient_id)
          @report << PatientService.get_patient(patient_obj.person) 
        end
      else
    end

    render :layout => 'report'
  end

  def include_url_params_for_back_button
       #@report_quarter = params[:quarter]
       @report_type = params[:report_type]
  end
  
  def cohort
    @selSelect = params[:selSelect] rescue nil
    @selYear = params[:selYear] rescue nil
    @selMonth = params[:selMonth] rescue nil
    @selQtr = "#{par      	  raise patient.to_yamlams[:selQtr].gsub(/&/, "_")}" rescue nil
		@location =  Location.current_health_center.name rescue ''

		case params[:selSelect]
		  when "month"
		    @start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
		    @end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
		      ("2010-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : 31) }").to_date.strftime("%Y-%m-%d")

		  when "quarter"
		    start_date = params[:selQtr].to_s.gsub(/&max=(.+)$/,'')
		    end_date = params[:selQtr].to_s.gsub(/^min=(.+)&max=/,'')

				@start_date = start_date.gsub(/^min=/,'')
				@end_date		= end_date
		  end
     
    session[:start_date] = @start_date
    session[:end_date] = @end_date

    cohort = Cohort.new(@start_date,@end_date)
    @services = cohort.registration_services
    
		if @selSelect.include?('month')
			@report_type =	@start_date.to_date.strftime("%B") + "  " + @selYear
		else
			@report_type = @start_date.to_date.strftime("%Y-%B-%d") + " to " + @end_date.to_date.strftime("%Y-%B-%d")
		end
    render :layout => 'cohort'
  end

  def cohort_menu
  end


end

