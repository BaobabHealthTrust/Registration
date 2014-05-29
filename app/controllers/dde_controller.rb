class DdeController < ApplicationController

  def index
    session[:cohort] = nil
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = session[:datetime].to_date rescue Date.today.to_date

		@person = Person.find_by_person_id(current_user.person_id)

    @user = PatientService.name(@person)

    @roles = current_user.user_roles.collect{|r| r.role} rescue []

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    
    render :template => 'dde/index', :layout => false
  end

  def search
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    
    render :layout => false
  end

  def new
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
  end

  def process_result
  
    patient_id = DDE.search_and_or_create(params["person"]) # rescue nil 
    
    json = JSON.parse(params["person"]) rescue {}
    
    patient = Patient.find(patient_id) rescue nil
    
    print_and_redirect("/patients/national_id_label?patient_id=#{patient_id}", next_task(patient)) and return if !patient.blank? and (json["print_barcode"] rescue false)
    
    redirect_to "/encounters/new/registration?patient_id=#{patient_id}" and return if !patient_id.blank?

    flash["error"] = "Sorry! Something went wrong. Failed to process properly!"

    redirect_to "/clinic" and return

  end  

  def process_data
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    
    patient = PatientIdentifier.find_by_identifier(params[:id]).patient rescue nil
    
    national_id = ((patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil) || params[:id])
    
    name = patient.person.names.last rescue nil
    
    address = patient.person.addresses.last rescue nil
    
    person = {
      "national_id" => national_id,
      "application" => "#{@settings["application_name"]}",
      "site_code" => "#{@settings["site_code"]}",
      "return_path" => "http://#{request.host_with_port}/process_result",
      "patient_id" => (patient.patient_id rescue nil),
      "names" =>
      {
          "family_name" => (name.family_name rescue nil),
          "given_name" => (name.given_name rescue nil)
      },
      "gender" => (patient.person.gender rescue nil),
      "person_attributes" => {
          "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
          "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
          "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
          "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
          "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
      },
      "birthdate" => (patient.person.birthdate rescue nil),
      "patient" => {
          "identifiers" => (patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?} rescue [])
      },
      "birthdate_estimated" => nil,
      "addresses" => {
          "current_residence" => (address.address1 rescue nil),
          "current_village" => (address.city_village rescue nil),
          "current_ta" => (address.township_division rescue nil),
          "current_district" => (address.state_province rescue nil),
          "home_village" => (address.neighborhood_cell rescue nil),
          "home_ta" => (address.county_district rescue nil),
          "home_district" => (address.address2 rescue nil)
      }
    }
              
    render :text => person.to_json
  end

  def search_name
    
    result = {}
      
    json = {"results" => []}
  
    Person.find(:all, :joins => [:names], :conditions => ["given_name = ? AND family_name = ? AND gender = ?", params["given_name"], params["family_name"], params["gender"]]).each do |person|
      
      json["results"] << {
        "uuid" => person.id,
        "person" => {
          "display" => ("#{person.names.last.given_name} #{person.names.last.family_name}" rescue nil),
          "age" => ((Date.today - person.birthdate.to_date).to_i / 365 rescue nil),
          "birthdateEstimated" => ((person.birthdate_estimated == 1 ? true : false) rescue false),
          "gender" => (person.gender rescue nil),
          "preferredAddress" => {
            "cityVillage" => (person.addresses.last.city_village rescue nil)
          }
        },
        "identifiers" => person.patient.patient_identifiers.collect{|id| 
          {
            "identifier" => (id.identifier rescue "Unknown"),
            "identifierType" => {
              "display" => (id.type.name rescue "Unknown")
            }
          }
        }
      }      
      
    end
    
    # raise json.inspect
    
    json["results"].each do |o|
      
      person = {
        :uuid => (o["uuid"] rescue nil),
        :name => (o["person"]["display"] rescue nil),
        :age => (o["person"]["age"] rescue nil),
        :estimated => (o["person"]["birthdateEstimated"] rescue nil),
        :identifiers => o["identifiers"].collect{|id|
          {
            :identifier => (id["identifier"] rescue nil),
            :idtype => (id["identifierType"]["display"] rescue nil)
          }
        },
        :gender => (o["person"]["gender"] rescue nil),
        :village => (o["person"]["preferredAddress"]["cityVillage"] rescue nil)
      }
    
      result[o["uuid"]] = person
      
    end
        
    render :text => result.to_json and return
    
  end

  def new_patient
    
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
            
  end

  def edit_patient
    if params[:id].blank?
      person_id = params[:patient_id]
    else
      person_id = params[:id]
    end
    
    @person = Person.find(person_id)    
  end

  def edit_demographics
    @field = params[:field]
    
    if params[:id].blank?
      person_id = params[:patient_id]
    else
      person_id = params[:id]
    end
    @person = Person.find(person_id)   
    
    @patient = @person.patient rescue nil 
  end

  def update_demographics
    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    
    patient = Person.find(params[:person_id]).patient rescue nil
    
    if patient.blank? 
    
      flash[:error] = "Sorry, patient with that ID not found! Update failed."
      
      redirect_to "/" and return
    
    end
    
    national_id = ((patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil) || params[:id])
    
    name = patient.person.names.last rescue nil
    
    address = patient.person.addresses.last rescue nil
    
    dob = (patient.person.birthdate.strftime("%Y-%m-%d") rescue nil)
    
    estimate = false
    
    if !(params[:person][:birth_month] rescue nil).blank? and (params[:person][:birth_month] rescue nil).to_s.downcase == "unknown"
    
      dob = "#{params[:person][:birth_year]}-07-10"
      
      estimate = true
    
    elsif !(params[:person][:birth_month] rescue nil).blank? and (params[:person][:birth_month] rescue nil).to_s.downcase != "unknown" and !(params[:person][:birth_day] rescue nil).blank? and (params[:person][:birth_day] rescue nil).to_s.downcase == "unknown"
    
      dob = "#{params[:person][:birth_year]}-#{"%02d" % params[:person][:birth_month].to_i}-05"
    
      estimate = true
    
    elsif !(params[:person][:birth_month] rescue nil).blank? and (params[:person][:birth_month] rescue nil).to_s.downcase != "unknown" and !(params[:person][:birth_day] rescue nil).blank? and (params[:person][:birth_day] rescue nil).to_s.downcase != "unknown" and !(params[:person][:birth_year] rescue nil).blank? and (params[:person][:birth_year] rescue nil).to_s.downcase != "unknown"
          
      dob = "#{params[:person][:birth_year]}-#{"%02d" % params[:person][:birth_month].to_i}-#{"%02d" % params[:person][:birth_day].to_i}"
    
      estimate = false    
    
    end
    
    identifiers = []
    
    patient.patient_identifiers.each{|id| 
      identifiers << {id.type.name => id.identifier} if id.type.name.downcase != "national id"
    } 
    
    # raise identifiers.inspect
    
    person = {
      "national_id" => national_id,
      "application" => "#{@settings["application_name"]}",
      "site_code" => "#{@settings["site_code"]}",
      "return_path" => "http://#{request.host_with_port}/process_result",
      "patient_id" => (patient.patient_id rescue nil),
      "patient_update" => true,
      "names" =>
      {
          "family_name" => (!(params[:person][:names][:family_name] rescue nil).blank? ? (params[:person][:names][:family_name] rescue nil) : (name.family_name rescue nil)),
          "given_name" => (!(params[:person][:names][:given_name] rescue nil).blank? ? (params[:person][:names][:given_name] rescue nil) : (name.given_name rescue nil))
      },
      "gender" => (!params["gender"].blank? ? params["gender"] : (patient.person.gender rescue nil)),
      "person_attributes" => {
          "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
          "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
          "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
          "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
          "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
      },
      "birthdate" => dob,
      "patient" => {
          "identifiers" => identifiers
      },
      "birthdate_estimated" => estimate,
      "addresses" => {
          "current_residence" => (!(params[:person][:addresses][:address1] rescue nil).blank? ? (params[:person][:addresses][:address1] rescue nil) : (address.address1 rescue nil)),
          "current_village" => (!(params[:person][:addresses][:city_village] rescue nil).blank? ? (params[:person][:addresses][:city_village] rescue nil) : (address.city_village rescue nil)),
          "current_ta" => (!(params[:person][:addresses][:township_division] rescue nil).blank? ? (params[:person][:addresses][:township_division] rescue nil) : (address.township_division rescue nil)),
          "current_district" => (!(params[:person][:addresses][:state_province] rescue nil).blank? ? (params[:person][:addresses][:state_province] rescue nil) : (address.state_province rescue nil)),
          "home_village" => (!(params[:person][:addresses][:neighborhood_cell] rescue nil).blank? ? (params[:person][:addresses][:neighborhood_cell] rescue nil) : (address.neighborhood_cell rescue nil)),
          "home_ta" => (!(params[:person][:addresses][:county_district] rescue nil).blank? ? (params[:person][:addresses][:county_district] rescue nil) : (address.county_district rescue nil)),
          "home_district" => (!(params[:person][:addresses][:address2] rescue nil).blank? ? (params[:person][:addresses][:address2] rescue nil) : (address.address2 rescue nil))
      }
    }
    
    result = RestClient.post("http://#{@settings["dde_username"]}:#{@settings["dde_password"]}@#{@settings["dde_server"]}/process_confirmation", {:person => person, :target => "update"})
    
    json = JSON.parse(result) rescue {}
    
    if json["patient"]["identifiers"].class.to_s.downcase == "hash"
      
      tmp = json["patient"]["identifiers"]
      
      json["patient"]["identifiers"] = []
      
      tmp.each do |key, value|
        
        json["patient"]["identifiers"] << {key => value}
        
      end
    
    end 
    
    patient_id = DDE.search_and_or_create(json.to_json) # rescue nil 
    
    # raise patient_id.inspect
    
    patient = Patient.find(patient_id) rescue nil
    
    print_and_redirect("/patients/national_id_label?patient_id=#{patient_id}", "/dde/edit_patient/id=#{patient_id}") and return if !patient.blank? and (json["print_barcode"] rescue false)
    
    redirect_to "/dde/edit_patient/#{patient_id}" and return if !patient_id.blank?

    flash["error"] = "Sorry! Something went wrong. Failed to process properly!"

    redirect_to "/clinic" and return
  end

end
