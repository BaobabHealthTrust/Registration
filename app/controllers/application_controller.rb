class ApplicationController < ActionController::Base
  include AuthenticatedSystem
	  Mastercard
    PatientIdentifierType
    PatientIdentifier
    PersonAttribute
    PersonAttributeType
    WeightHeight
    CohortTool
    Encounter
    EncounterType
    Location
    DrugOrder
    District
    Region
    User
    Task
    GlobalProperty
    Person
    Regimen
    Relationship
    ConceptName
    Concept
	  Settings
  require "fastercsv"

  helper :all
  helper_method :next_task
  filter_parameter_logging :password
  before_filter :login_required, :except => ['login', 'logout','demographics','create_remote', 'mastercard_printable']
  before_filter :location_required, :except => ['login', 'logout', 'location','demographics','create_remote', 'mastercard_printable']
  
  def rescue_action_in_public(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    logger.info @message
    logger.info @backtrace
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end
  
  def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    render :template => 'print/print_location', :layout => nil
  end

  def show_lab_results
    CoreService.get_global_property_value('show.lab.results').to_s == "true" rescue false
  end

  def use_filing_number
    CoreService.get_global_property_value('use.filing.number').to_s == "true" rescue false
  end 
 
 def generic_locations
  field_name = "name"

  Location.find_by_sql("SELECT *
          FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end
  
  def referral_sections
    field_name = "name"
    referral_sections = CoreService.get_global_property_value("facility_referral_section_tag") rescue false
    Location.find_by_sql("SELECT *
          FROM location
          WHERE location_id IN (SELECT location_id
                         FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = '#{referral_sections}'))
             ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
  end

  def site_prefix
    site_prefix = CoreService.get_global_property_value("site_prefix") rescue false
    return site_prefix
  end

	def use_user_selected_activities
		CoreService.get_global_property_value('use.user.selected.activities').to_s == "true" rescue false
	end
  
  def tb_dot_sites_tag
    CoreService.get_global_property_value('tb_dot_sites_tag') rescue nil
  end

  def create_from_remote                                                        
    CoreService.get_global_property_value('create.from.remote').to_s == "true" rescue false
  end

  def concept_set(concept_name)
    concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

	return options
  end

  def concept_set_diff(concept_name, exclude_concept_name)
    concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
    set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
    options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    exclude_concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
                                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?", exclude_concept_name]).concept_id
    exclude_set = ConceptSet.find_all_by_concept_set(exclude_concept_id, :order => 'sort_weight')
    exclude_options = exclude_set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

    final_options = (options - exclude_options)
	return final_options
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
    task = Task.first rescue Task.new()

    type = 'PATIENT REGISTRATION'
    encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(type).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      task.encounter_type = type 
      if encounter_available.blank? 
        task.url = "/encounters/new/patient_registration?patient_id=#{patient.id}"
      else 
        task.encounter_type = 'NONE'
        task.url = "/patients/show/#{patient.id}"
     end
     return task
  end
  
  
  def validate_task(patient, task, location, session_date = Date.today)
    #return task unless task.has_program_id == 1
    return task if task.encounter_type == 'REGISTRATION'
    # allow EID patients at HIV clinic, but don't validate tasks
    return task if task.has_program_id == 4
    
    #check if the latest HIV program is closed - if yes, the app should redirect the user to update state screen
    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name('ART_INITIAL').id)
      latest_hiv_program = [] ; patient.patient_programs.collect{ | p |next unless p.program_id == 1 ; latest_hiv_program << p } 
      if latest_hiv_program.last.closed?
        task.url = '/patients/programs_dashboard/{patient}' ; task.encounter_type = 'Program enrolment'
        return task
      end rescue nil
    end

    return task if task.url == "/patients/show/{patient}"

    art_encounters = ['ART_INITIAL','HIV RECEPTION','VITALS','HIV STAGING','ART VISIT','ART ADHERENCE','TREATMENT','DISPENSING']

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
    art_reason = patient_obj.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
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

    unless PatientService.drug_given_before(patient,session_date).blank?
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

private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end

end
