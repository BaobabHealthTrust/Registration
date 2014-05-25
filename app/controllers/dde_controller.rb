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
    @settings = YAML.load_file("#{Rails.root}/config/application.yml")[Rails.env] rescue {}
  end

  def new
    @settings = YAML.load_file("#{Rails.root}/config/application.yml")[Rails.env] rescue {}
  end

  def process_result
  
    # raise params["person"].inspect
  
    patient_id = DDE.search_and_or_create(params["person"]) # rescue nil 
    
    redirect_to "/encounters/new/registration?patient_id=#{patient_id}" and return if !patient_id.blank?

    flash["error"] = "Sorry! Something went wrong. Failed to process properly!"

    redirect_to "/clinic" and return

  end  

  def process_data
    @settings = YAML.load_file("#{Rails.root}/config/application.yml")[Rails.env] rescue {}
    
    patient = PatientIdentifier.find_by_identifier(params[:id]).patient rescue nil
    
    name = patient.person.names.last rescue nil
    
    address = patient.person.addresses.last rescue nil
    
    person = {
      "national_id" => (params[:id] rescue nil),
      "application" => "#{@settings["application_name"]}",
      "site_code" => "#{@settings["site_code"]}",
      "return_path" => "http://#{request.host_with_port}/process_result",
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
          "identifiers" => []
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

end
