class GenericPeopleController < ApplicationController
    
	def index
		redirect_to "/clinic"
	end

	def new
		@occupations = occupations
	end

	def identifiers
	end

  def create_confirm
    @search_results = {}                                                        
    @patients = []
     
    (PatientService.search_demographics_from_remote(params[:user_entered_params]) || []).each do |data|            
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil    
      national_id = data["npid"]["value"] if national_id.blank? rescue nil      
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil
                                                                              
      next if national_id.blank?                                                
      results = PersonSearch.new(national_id)                                   
      results.national_id = national_id                                         
      results.current_residence = data["person"]["data"]["addresses"]["city_village"]
      results.person_id = 0                                                     
      results.home_district = data["person"]["data"]["addresses"]["address2"]   
      results.neighborhood_cell = data["person"]["data"]["addresses"]["neighborhood_cell"]   
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]                                 
      results.occupation = data["person"]["data"]["occupation"]                 
      results.sex = (gender == 'M' ? 'Male' : 'Female')                         
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date         
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results                            
    end if create_from_dde_server

    (params[:people_ids] || []).each do |person_id|
      patient = PatientService.get_patient(Person.find(person_id))

      results = PersonSearch.new(patient.national_id || patient.patient_id)     
      results.national_id = patient.national_id                                 
      results.birth_date = patient.birth_date                                   
      results.current_residence = patient.current_residence                     
      results.guardian = patient.guardian                                       
      results.person_id = patient.person_id                                     
      results.home_district = patient.home_district                             
      results.neighborhood_cell = patient.home_village                            
      results.current_district = patient.current_district                       
      results.traditional_authority = patient.traditional_authority             
      results.mothers_surname = patient.mothers_surname                         
      results.dead = patient.dead                                               
      results.arv_number = patient.arv_number                                   
      results.eid_number = patient.eid_number                                   
      results.pre_art_number = patient.pre_art_number                           
      results.name = patient.name                                               
      results.sex = patient.sex                                                 
      results.age = patient.age                                                 
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

    (@search_results || {}).each do | npid , data |
      @patients << data
    end

    @parameters = params[:user_entered_params]
    render :layout => 'menu'
  end
  
	def create_remote
		if current_user.blank?
		  user = User.authenticate('admin', 'test')
		  sign_in(:user, user) if !user.blank?
      set_current_user
		end rescue []

		if Location.current_location.blank?
			Location.current_location = Location.find(CoreService.get_global_property_value('current_health_center_id'))
		end rescue []

    if create_from_dde_server

      passed_params = {"region" => "" ,
     "person"=>{"occupation"=> params["occupation"] ,
     "age_estimate"=> params["patient_age"]["age_estimate"] ,
     "cell_phone_number"=> params["cell_phone"]["identifier"] ,
     "birth_month"=> params["patient_month"],
     "addresses"=>{"address1"=> "",
     "address2"=>  "",
     "city_village"=>  params["patientaddress"]["city_village"] ,
     "county_district"=> params["patient"]["birthplace"] },
     "gender"=>  params["patient"]["gender"],
     "patient"=>"",
     "birth_day"=>  params["patient_day"] ,
     "home_phone_number"=> params["home_phone"]["identifier"] ,
     "names"=>{"family_name"=> params["patient_name"]["family_name"],
     "given_name"=> params["patient_name"]["given_name"],
     "middle_name"=> params["patient_name"]["middle_name"] },
     "birth_year"=> params["patient_year"] },
     "filter_district"=> params["patient"]["birthplace"] ,
     "filter"=>{"region"=> "" ,
     "t_a"=> params["current_ta"]["identifier"] ,
     "t_a_a"=>""},
     "relation"=>"",
     "p"=>{"'address2_a'"=>"",
     "addresses"=>{"county_district_a"=>"",
     "city_village_a"=>""}},
     "identifier"=> params["old_national_id"]
     }

      person = PatientService.create_patient_from_dde(passed_params)
    else
      person_params = {"occupation"=> params[:occupation],
        "age_estimate"=> params['patient_age']['age_estimate'],
        "cell_phone_number"=> params['cell_phone']['identifier'],
        "birth_month"=> params[:patient_month],
        "addresses"=>{ "address2" => params['p_address']['identifier'],
              "address1" => params['p_address']['identifier'],
        "city_village"=> params['patientaddress']['city_village'],
        "county_district"=> params[:birthplace] },
        "gender" => params['patient']['gender'],
        "birth_day" => params[:patient_day],
        "names"=> {"family_name2"=>"Unknown",
        "family_name"=> params['patient_name']['family_name'],
        "given_name"=> params['patient_name']['given_name'] },
        "birth_year"=> params[:patient_year] }

      person = PatientService.create_from_form(person_params)

      if person
        patient = Patient.new()
        patient.patient_id = person.id
        patient.save
        PatientService.patient_national_id_label(patient)
      end
    end

		render :text => PatientService.remote_demographics(person).to_json
	end
  
	def remote_demographics
		# Search by the demographics that were passed in and then return demographics
		people = PatientService.find_person_by_demographics(params)
		result = people.empty? ? {} : PatientService.demographics(people.first)
		render :text => result.to_json
	end
  
	def art_information
		national_id = params["person"]["patient"]["identifiers"]["National id"] rescue nil
    national_id = params["person"]["value"] if national_id.blank? rescue nil
		art_info = Patient.art_info_for_remote(national_id)
		art_info = art_info_for_remote(national_id)
		render :text => art_info.to_json
	end
	
=begin
	def search
		found_person = nil
		if params[:identifier]
			local_results = PatientService.search_by_identifier(params[:identifier])
			if local_results.length > 1
				@people = PatientService.person_search(params)
			elsif local_results.length == 1
				found_person = local_results.first
			else
				# TODO - figure out how to write a test for this
				# This is sloppy - creating something as the result of a GET
				if create_from_remote
					found_person_data = PatientService.find_remote_person_by_identifier(params[:identifier])
					found_person = PatientService.create_from_form(found_person_data['person']) unless found_person_data.blank?
				end
			end
			if found_person
        patient = DDEService::Patient.new(found_person.patient)

        patient.check_old_national_id(params[:identifier])

				if params[:relation]
					redirect_to search_complete_url(found_person.id, params[:relation]) and return
				else
          #creating patient's footprint so that we can track them later when they visit other sites
          DDEService.create_footprint(PatientService.get_patient(found_person).national_id, session[:location_id])
					redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
				end
			end
		end
		@relation = params[:relation]
		@people = PatientService.person_search(params)
		@patients = []
		@people.each do | person |
			patient = PatientService.get_patient(person) rescue nil
			@patients << patient
		end
	end
=end
  
  def search_from_dde
		found_person = PatientService.person_search_from_dde(params)
    if found_person
      if params[:relation]
        redirect_to search_complete_url(found_person.id, params[:relation]) and return
      else
        redirect_to :action => 'confirm', 
          :found_person_id => found_person.id, 
          :relation => params[:relation] and return
      end
    else
      redirect_to :action => 'search' and return 
    end
  end
   
	def confirm
		session_date = session[:datetime] || Date.today
		if request.post?
			redirect_to search_complete_url(params[:found_person_id], params[:relation]) and return
		end
		@found_person_id = params[:found_person_id] 
		@relation = params[:relation]
		@person = Person.find(@found_person_id) rescue nil
    @task = main_next_task(Location.current_location, @person.patient, session_date.to_date)
	  @patient_bean = PatientService.get_patient(@person)                                                         
    render :layout => false	
	end

	def tranfer_patient_in
		@data_demo = {}
		if request.post?
			params[:data].split(',').each do | data |
				if data[0..4] == "Name:"
					@data_demo['name'] = data.split(':')[1]
					next
				end
				if data.match(/guardian/i)
					@data_demo['guardian'] = data.split(':')[1]
					next
				end
				if data.match(/sex/i)
					@data_demo['sex'] = data.split(':')[1]
					next
				end
				if data[0..3] == 'DOB:'
					@data_demo['dob'] = data.split(':')[1]
					next
				end
				if data.match(/National ID:/i)
					@data_demo['national_id'] = data.split(':')[1]
					next
				end
				if data[0..3] == "BMI:"
					@data_demo['bmi'] = data.split(':')[1]
					next
				end
				if data.match(/ARV number:/i)
					@data_demo['arv_number'] = data.split(':')[1]
					next
				end
				if data.match(/Address:/i)
					@data_demo['address'] = data.split(':')[1]
					next
				end
				if data.match(/1st pos HIV test site:/i)
					@data_demo['first_positive_hiv_test_site'] = data.split(':')[1]
					next
				end
				if data.match(/1st pos HIV test date:/i)
					@data_demo['first_positive_hiv_test_date'] = data.split(':')[1]
					next
				end
				if data.match(/FU:/i)
					@data_demo['agrees_to_followup'] = data.split(':')[1]
					next
				end
				if data.match(/1st line date:/i)
					@data_demo['date_of_first_line_regimen'] = data.split(':')[1]
					next
				end
				if data.match(/SR:/i)
					@data_demo['reason_for_art_eligibility'] = data.split(':')[1]
					next
				end
			end
		end
		render :layout => "menu"
	end

	# This method is just to allow the select box to submit, we could probably do this better
	def select
    if !params[:person][:patient][:identifiers]['National id'].blank? &&
        !params[:person][:names][:given_name].blank? &&
          !params[:person][:names][:family_name].blank?
      redirect_to :action => :search, :identifier => params[:person][:patient][:identifiers]['National id']
      return
    end rescue nil

    if !params[:identifier].blank? && !params[:given_name].blank? && !params[:family_name].blank?
      redirect_to :action => :search, :identifier => params[:identifier]
    elsif params[:person][:id] != '0' && Person.find(params[:person][:id]).dead == 1
      redirect_to :controller => :patients, :action => :show, :id => params[:person][:id]
    else
      if params[:person][:id] != '0'
        person = Person.find(params[:person][:id])
        patient = DDEService::Patient.new(person.patient)
        patient_id = PatientService.get_patient_identifier(person.patient, "National id")
        if patient_id.length != 6 and create_from_dde_server
          patient.check_old_national_id(patient_id)
          #creating patient's footprint so that we can track them later when they visit other sites
          DDEService.create_footprint(PatientService.get_patient(person).national_id, 'Registration')
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient)) and return
        end
        #creating patient's footprint so that we can track them later when they visit other sites
        DDEService.create_footprint(PatientService.get_patient(person).national_id, 'Registration')
      end
      
      redirect_to search_complete_url(params[:person][:id], params[:relation]) and return unless params[:person][:id].blank? || params[:person][:id] == '0'

      redirect_to :action => :new, :gender => params[:gender], :given_name => params[:given_name], :family_name => params[:family_name], :family_name2 => params[:family_name2], :address2 => params[:address2], :identifier => params[:identifier], :relation => params[:relation]
    end
	end
 
   def create

    if confirm_before_creating and not params[:force_create] == 'true' and params[:relation].blank?
     @parameters = params
     birthday_params = params.reject{|key,value| key.match(/gender/) }
     unless birthday_params.empty?                                               
       if params[:person]['birth_year'] == "Unknown"   
         birthdate = Date.new(Date.today.year - params[:person]["age_estimate"].to_i, 7, 1)
       else                                                                      
         year = params[:person]["birth_year"].to_i 
         month = params[:person]["birth_month"] 
         day = params[:person]["birth_day"].to_i

         month_i = (month || 0).to_i                                                 
         month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?   
         month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
                                                     
         if month_i == 0 || month == "Unknown"                                       
           birthdate = Date.new(year.to_i,7,1)                                
         elsif day.blank? || day == "Unknown" || day == 0                            
           birthdate = Date.new(year.to_i,month_i,15)                         
         else                                                                        
           birthdate = Date.new(year.to_i,month_i,day.to_i)                   
         end
       end                                                                       
     end                                                                         
     
     start_birthdate = (birthdate - 5.year)
     end_birthdate   = (birthdate + 5.year)                                                                   

     given_name_code = @parameters[:person][:names]['given_name'].soundex
     family_name_code = @parameters[:person][:names]['family_name'].soundex
     gender = @parameters[:person]['gender']
     ta = @parameters[:person][:addresses]['county_district']
     home_district = @parameters[:person][:addresses]['address2']       
     home_village = @parameters[:person][:addresses]['neighborhood_cell']

     people = Person.find(:all,:joins =>"INNER JOIN person_name pn 
       ON person.person_id = pn.person_id
       INNER JOIN person_name_code pnc ON pnc.person_name_id = pn.person_name_id
       INNER JOIN person_address pad ON pad.person_id = person.person_id",
       :conditions =>["(pad.address2 LIKE (?) OR pad.county_district LIKE (?)
       OR pad.neighborhood_cell LIKE (?)) AND pnc.given_name_code LIKE (?)
       AND pnc.family_name_code LIKE (?) AND person.gender = '#{gender}'
       AND (person.birthdate >= ? AND person.birthdate <= ?)","%#{home_district}%",
       "%#{ta}%","%#{home_village}%","%#{given_name_code}%","%#{family_name_code}%",
       start_birthdate,end_birthdate],:group => "person.person_id")

     if people
       people_ids = []
       (people).each do |person|
         people_ids << person.id
       end
     end

    
     #............................................................................
     @dde_search_results = {}
     (PatientService.search_demographics_from_remote(params) || []).each do |data|            
       national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
       national_id = data["person"]["value"] if national_id.blank? rescue nil    
       national_id = data["npid"]["value"] if national_id.blank? rescue nil      
       national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil
                                                                                
       next if national_id.blank?                                                
       results = PersonSearch.new(national_id)                                   
       results.national_id = national_id                                         
       results.current_residence = data["person"]["data"]["addresses"]["city_village"]
       results.person_id = 0                                                     
       results.home_district = data["person"]["data"]["addresses"]["address2"]   
       results.neighborhood_cell = data["person"]["data"]["addresses"]["neighborhood_cell"]   
       results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
       results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
       gender = data["person"]["data"]["gender"]                                 
       results.occupation = data["person"]["data"]["occupation"]                 
       results.sex = (gender == 'M' ? 'Male' : 'Female')                         
       results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
       results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
       results.birthdate = (data["person"]["data"]["birthdate"]).to_date         
       results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
       @dde_search_results[results.national_id] = results                            
       break
     end if create_from_dde_server
     #............................................................................

     if not people_ids.blank? or not @dde_search_results.blank?
       redirect_to :action => :create_confirm , :people_ids => people_ids , 
        :user_entered_params => @parameters and return
     end
   end

    success = false
    Person.session_datetime = session[:datetime].to_date rescue Date.today
    identifier = params[:identifier] rescue nil
    if identifier.blank?
      identifier = params[:person][:patient][:identifiers]['National id']
    end rescue nil

    if create_from_dde_server
      unless identifier.blank?
        params[:person].merge!({"identifiers" => {"National id" => identifier}})
        success = true
        person = PatientService.create_from_form(params[:person])
        if identifier.length != 6
           patient = DDEService::Patient.new(person.patient)
           national_id_replaced = patient.check_old_national_id(identifier)
        end
      else
        person = PatientService.create_patient_from_dde(params)
        success = true
      end

    #If we are creating from DDE then we must create a footprint of the 
    #just created patient to enable future                                                              
    DDEService.create_footprint(PatientService.get_patient(person).national_id, 'Registration')

    #for now BART2 will use BART1 for patient/person creation until we upgrade BART1 to 2
    #if GlobalProperty.find_by_property('create.from.remote') and property_value == 'yes'
    #then we create person from remote machine
    elsif create_from_remote
      person_from_remote = PatientService.create_remote_person(params)
      person = PatientService.create_from_form(person_from_remote["person"]) unless person_from_remote.blank?

      if !person.blank?
        success = true
        #person.patient.remote_national_id
        PatientService.get_remote_national_id(person.patient)
      end
    else
      success = true
      params[:person].merge!({"identifiers" => {"National id" => identifier}}) unless identifier.blank?
      person = PatientService.create_from_form(params[:person])
    end

    if params[:person][:patient] && success
      PatientService.patient_national_id_label(person.patient)
      unless (params[:relation].blank?)
        redirect_to search_complete_url(person.id, params[:relation]) and return
      else

       tb_session = false
       if current_user.activities.include?('Manage Lab Orders') or current_user.activities.include?('Manage Lab Results') or
        current_user.activities.include?('Manage Sputum Submissions') or current_user.activities.include?('Manage TB Clinic Visits') or
         current_user.activities.include?('Manage TB Reception Visits') or current_user.activities.include?('Manage TB Registration Visits') or
          current_user.activities.include?('Manage HIV Status Visits')
         tb_session = true
       end

        #raise use_filing_number.to_yaml
        if use_filing_number and not tb_session
          PatientService.set_patient_filing_number(person.patient)
          archived_patient = PatientService.patient_to_be_archived(person.patient)
          message = PatientService.patient_printing_message(person.patient,archived_patient,creating_new_patient = true)
          unless message.blank?
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}" , next_task(person.patient),message,true,person.id)
          else
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient))
          end
        else
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
        end
      end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def set_datetime
    if request.post?
      unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = Time.mktime(params[:set_year].to_i,
                                        params[:set_month].to_i,                                
                                        params[:set_day].to_i,0,0,1) 
        session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
      end
      unless params[:id].blank?
        redirect_to next_task(Patient.find(params[:id])) 
      else
        redirect_to :action => "index"
      end
    end
    @patient_id = params[:id]
  end

  def reset_datetime
    session[:datetime] = nil
    if params[:id].blank?
      redirect_to :action => "index" and return
    else
      redirect_to "/patients/show/#{params[:id]}" and return
    end
  end

  def find_by_arv_number
    if request.post?
      redirect_to :action => 'search' ,
        :identifier => "#{site_prefix}-ARV-#{params[:arv_number]}" and return
    end
  end

  # List traditional authority containing the string given in params[:value]
  def traditional_authority
    district_id = District.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "%#{params[:search_string]}%", district_id]

    traditional_authorities = TraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value='#{t_a.name}'>#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end

  # Regions containing the string given in params[:value]
  def region_of_origin
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'region_id')
    regions = regions.map do |r|
      "<li value='#{r.name}'>#{r.name}</li>"
    end
    render :text => regions.join('')  and return
  end
  
  def region
    region_conditions = ["name LIKE (?)", "#{params[:value]}%"]

    regions = Region.find(:all,:conditions => region_conditions, :order => 'region_id')
    regions = regions.map do |r|
      if r.name != "Foreign"
        "<li value='#{r.name}'>#{r.name}</li>"
      end
    end
    render :text => regions.join('')  and return
  end

    # Districts containing the string given in params[:value]
  def district
    region_id = Region.find_by_name("#{params[:filter_value]}").id
    region_conditions = ["name LIKE (?) AND region_id = ? ", "#{params[:search_string]}%", region_id]

    districts = District.find(:all,:conditions => region_conditions, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') and return
  end

    # Villages containing the string given in params[:value]
  def village
    traditional_authority_id = TraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "%#{params[:search_string]}%", traditional_authority_id]

    villages = Village.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value='#{v.name}'>#{v.name}</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end
  
  # Landmark containing the string given in params[:value]
  def landmark
    landmarks = PersonAddress.find(:all, :select => "DISTINCT address1" , :conditions => ["city_village = (?) AND address1 LIKE (?)", "#{params[:filter_value]}", "#{params[:search_string]}%"])
    landmarks = landmarks.map do |v|
      "<li value='#{v.address1}'>#{v.address1}</li>"
    end
    render :text => landmarks.join('') + "<li value='Other'>Other</li>" and return
  end

  def tb_initialization_district
    districts = District.find(:all, :order => 'name')
    districts = districts.map do |d|
      "<li value='#{d.name}'>#{d.name}</li>"
    end
    render :text => districts.join('') + "<li value='Other'>Other</li>" and return
  end

=begin
  #This method was taken out of encounter model. It is been used in
  #people/index (view) which seems not to be used at present.
  def count_by_type_for_date(date)
    # This query can be very time consuming, because of this we will not consider
    # that some of the encounters on the specific date may have been voided
    ActiveRecord::Base.connection.select_all("SELECT count(*) as number, encounter_type FROM encounter GROUP BY encounter_type")
    todays_encounters = Encounter.find(:all, :include => "type", :conditions => ["DATE(encounter_datetime) = ?",date])
    encounters_by_type = Hash.new(0)
    todays_encounters.each{|encounter|
      next if encounter.type.nil?
      encounters_by_type[encounter.type.name] += 1
    }
    encounters_by_type
  end
=end

  def art_info_for_remote(national_id)

    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}

    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","HIV CLINIC CONSULTATION","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','HIV CLINIC REGISTRATION']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first,
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'


      art_start_date = PatientService.patient_art_start_date(patient.id).strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

      program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'

      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
        'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end

  def art_info_for_remote(national_id)
    patient = PatientService.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}
    
    if PatientService.art_patient?(patient)
      clinic_encounters = ["APPOINTMENT","HIV CLINIC CONSULTATION","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','HIV CLINIC REGISTRATION']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'
      

      art_start_date = patient.art_start_date.strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

     program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'
      
      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
         'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => PatientService.get_patient_identifier(patient, 'ARV Number')
      }
    end

    results["person"] = result_hash
    return results
  end
  
  def occupations
    ['','Driver','Housewife','Messenger','Business','Farmer','Salesperson','Teacher',
     'Student','Security guard','Domestic worker', 'Police','Office worker',
     'Preschool child','Mechanic','Prisoner','Craftsman','Healthcare Worker','Soldier'].sort.concat(["Other","Unknown"])
  end

  def edit
    # only allow these fields to prevent dangerous 'fields' e.g. 'destroy!'
    valid_fields = ['birthdate','gender']
    unless valid_fields.include? params[:field]
      redirect_to :controller => 'patients', :action => :demographics, :id => params[:id]
      return
    end

    @person = Person.find(params[:id])
    if request.post? && params[:field]
      if params[:field]== 'gender'
        @person.gender = params[:person][:gender]
      elsif params[:field] == 'birthdate'
        if params[:person][:birth_year] == "Unknown"
          @person.set_birthdate_by_age(params[:person]["age_estimate"])
        else
          PatientService.set_birthdate(@person, params[:person]["birth_year"],
                                params[:person]["birth_month"],
                                params[:person]["birth_day"])
        end
        @person.birthdate_estimated = 1 if params[:person]["birthdate_estimated"] == 'true'
        @person.save
      end
      @person.save
      redirect_to :controller => :patients, :action => :edit_demographics, :id => @person.id
    else
      @field = params[:field]
      @field_value = @person.send(@field)
    end
  end

  def edit_demographics
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @field = params[:field]
    render :partial => "edit_demographics", :field =>@field, :layout => true and return
  end

  def update_demographics
    PatientService.update_demographics(params)
    redirect_to :action => 'demographics', :patient_id => params['person_id'] and return
  end
  
  def dde_search
    # result = '[{"person":{"created_at":"2012-01-06T10:08:37Z","data":{"addresses":{"state_province":"Balaka","address2":"Hospital","city_village":"New Lines Houses","county_district":"Kalembo"},"birthdate":"1989-11-02","attributes":{"occupation":"Police","cell_phone_number":"0999925666"},"birthdate_estimated":"0","patient":{"identifiers":{"diabetes_number":""}},"gender":"M","names":{"family_name":"Banda","given_name":"Laz"}},"birthdate":"1989-11-02","creator_site_id":"1","birthdate_estimated":false,"updated_at":"2012-01-06T10:08:37Z","creator_id":"1","gender":"M","id":1,"family_name":"Banda","given_name":"Laz","remote_version_number":null,"version_number":"0","national_id":null}}]'
    
    @dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
    
    @dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
    
    @dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
    
    url = "http://#{@dde_server_username}:#{@dde_server_password}@#{@dde_server}" + 
      "/people/find.json?given_name=#{params[:given_name]}" + 
      "&family_name=#{params[:family_name]}&gender=#{params[:gender]}"
    
    result = RestClient.get(url)
    
    render :text => result, :layout => false
  end

  def demographics
    if params[:id].blank?
      person_id = params[:patient_id]
    else
      person_id = params[:id]
    end
    @person = Person.find(person_id)
		@patient_bean = PatientService.get_patient(@person)
		render :layout => 'menu'
  end
  
  def demographics_remote
    identifier = params[:person][:patient][:identifiers]["national_id"]
    people = PatientService.search_by_identifier(identifier)
    render :text => "" and return  if people.blank?
    patient = DDEService::Patient.new(people.first.patient)
    patient.check_old_national_id(identifier)
    render :text => PatientService.remote_demographics(people.first).to_json rescue ""
    return
  end

  def duplicates
    @duplicates = []
    people = PatientService.person_search(params[:search_params])
    people.each do |person|
      @duplicates << PatientService.get_patient(person)
    end unless people == "found duplicate identifiers"

    if create_from_dde_server
      @remote_duplicates = []
      PatientService.search_from_dde_by_identifier(params[:search_params][:identifier]).each do |person|
        @remote_duplicates << PatientService.get_dde_person(person)
      end
    end

    @selected_identifier = params[:search_params][:identifier]
    render :layout => 'menu'
  end

  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def remote_duplicates
    if params[:patient_id]
      @primary_patient = PatientService.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end

    @dde_duplicates = []
    if create_from_dde_server
      PatientService.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << PatientService.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => 'menu'
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    if create_from_dde_server
      passed_params = PatientService.demographics(patient.person)
      new_npid = PatientService.create_from_dde_server_only(passed_params)
      npid = PatientIdentifier.new()
      npid.patient_id = patient.id
      npid.identifier_type = PatientIdentifierType.find_by_name('National ID')
      npid.identifier = new_npid
      npid.save
    else
      PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
           :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = current_user.id
    npid.save

    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end

  def create_person_from_dde
    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end
  
private
  
	def search_complete_url(found_person_id, primary_person_id)
		unless (primary_person_id.blank?)
			# Notice this swaps them!
			new_relationship_url(:patient_id => primary_person_id, :relation => found_person_id)
		else
			#
			# Hack reversed to continue testing overnight
			#
			# TODO: This needs to be redesigned!!!!!!!!!!!
			#
			#url_for(:controller => :encounters, :action => :new, :patient_id => found_person_id)
			patient = Person.find(found_person_id).patient
      if create_from_dde_server
        p = DDEService::Patient.new(patient)
        identifier_type = PatientIdentifierType.find_by_name("National id")
        patient_national_id = patient.patient_identifiers.find_by_identifier_type(identifier_type.id).identifier rescue nil
        national_id_replaced = p.check_old_national_id(patient_national_id) unless patient_national_id.blank?
      end

			show_confirmation = CoreService.get_global_property_value('show.patient.confirmation').to_s == "true" rescue false
			if show_confirmation
				url_for(:controller => :people, :action => :confirm , :found_person_id =>found_person_id)
			else
				next_task(patient)
			end
		end
	end
end
 
