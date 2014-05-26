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
    
    name = patient.person.names.last rescue nil
    
    address = patient.person.addresses.last rescue nil
    
    person = {
      "national_id" => (params[:id] rescue nil),
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
      "attributes" => {
          "occupation" => nil,
          "cell_phone_number" => nil
      },
      "birthdate" => (patient.person.birthdate rescue nil),
      "patient" => {
          "identifiers" => patient.patient_identifiers.collect{|id| {id.type.name => id.identifier} if id.type.name.downcase != "national id"}.delete_if{|x| x.nil?}
      },
      "birthdate_estimated" => nil,
      "addresses" => {
          "current_residence" => (address.address1 rescue nil),
          "current_village" => (address.city_village rescue nil),
          "current_ta" => nil,
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

end
