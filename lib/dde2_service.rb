=begin
  Things to watch out for:

  1. The patient_identifier model is supposed to have it's after_save method
     changed to check if there is a DDE server to refer to first for this to work
  2. add the the hook after successifully searching for a patient as follows:

        patient = DDEService::Patient.new(found_person.patient)

        patient.check_old_national_id(params[:identifier])
  3. this module runs as all the other services. It had to have some of it's methods
      replicated for local use to allow for independence when being used in systems
      that don't need the other libraries as well as customisation of some methods for its use
=end

module DDE2Service

  class Patient

    attr_accessor :patient, :person

    def initialize(patient)
      self.patient = patient
      self.person = self.patient.person
    end

    def get_full_attribute(attribute)
      PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
          PersonAttributeType.find_by_name(attribute).id,self.person.id]) rescue nil
    end

    def set_attribute(attribute, value)
      PersonAttribute.create(:person_id => self.person.person_id, :value => value,
        :person_attribute_type_id => (PersonAttributeType.find_by_name(attribute).id))
    end

    def get_full_identifier(identifier)
      PatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
          PatientIdentifierType.find_by_name(identifier).id, self.patient.id]) rescue nil
    end

    def set_identifier(identifier, value)
      PatientIdentifier.create(:patient_id => self.patient.patient_id, :identifier => value,
        :identifier_type => (PatientIdentifierType.find_by_name(identifier).id))
    end

    def name
      "#{self.person.names.first.given_name} #{self.person.names.first.family_name}".titleize rescue nil
    end

    def first_name
      "#{self.person.names.first.given_name}".titleize rescue nil
    end

    def last_name
      "#{self.person.names.first.family_name}".titleize rescue nil
    end

    def middle_name
      "#{self.person.names.first.middle_name}".titleize rescue nil
    end

    def maiden_name
      "#{self.person.names.first.family_name2}".titleize rescue nil
    end

    def current_address2
      "#{self.person.addresses.last.city_village}" rescue nil
    end

    def current_address1
      "#{self.person.addresses.last.county_district}" rescue nil
    end

    def current_district
      "#{self.person.addresses.last.state_province}" rescue nil
    end

    def current_address
      "#{self.current_address1}, #{self.current_address2}, #{self.current_district}" rescue nil
    end

    def home_district
      "#{self.person.addresses.last.address2}" rescue nil
    end

    def home_ta
      "#{self.person.addresses.last.county_district}" rescue nil
    end

    def home_village
      "#{self.person.addresses.last.neighborhood_cell}" rescue nil
    end

    def national_id(force = true)
      id = self.patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
      return id unless force
      id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self.patient).identifier
      id
    end

    def self.set_birthdate_by_age(person, age, today = Date.today)
        person.birthdate = Date.new(today.year - age.to_i, 7, 1)
        person.birthdate_estimated = 1
    end

    def self.set_birthdate(person, year = nil, month = nil, day = nil)
        raise "No year passed for estimated birthdate" if year.nil?

        # Handle months by name or number (split this out to a date method)
        month_i = (month || 0).to_i
        month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
        month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

        if month_i == 0 || month == "Unknown"
        person.birthdate = Date.new(year.to_i,7,1)
        person.birthdate_estimated = 1
        elsif day.blank? || day == "Unknown" || day == 0
        person.birthdate = Date.new(year.to_i,month_i,15)
        person.birthdate_estimated = 1
        else
        person.birthdate = Date.new(year.to_i,month_i,day.to_i)
        person.birthdate_estimated = 0
        end
    end
  end

    def self.authenticate_user

    end

    def self.add_user

    end

    def self.check_if_token_authenticated
    
    end  
    
    def self.add_new_patient

    end 

    def self.search_by_identifier

    end
    
    def self.search_by_name_and_gender

    end

    def self.advanced_search

    end     

    def self.update_existing_patient     

    end

    def self.merge_patients

    end

    def self.connection
      dde_server = GlobalProperty.find_by_property("dde2_server_ip").property_value rescue ""
      dde_server_username = GlobalProperty.find_by_property("dde2_server_username").property_value rescue ""
      dde_server_password = GlobalProperty.find_by_property("dde2_server_password").property_value rescue ""
      server_url = "http://#{dde_server}/v1/authenticate"

      user_params = {"username" => dde_server_username, "password" => dde_server_password}

      response = RestClient::Request.execute(:method => :post, 
                                             :url => server_url, 
                                             :payload => user_params.to_json, 
                                             :headers => {:accept => :json,
                                                          :content_type => :json
                                                          })
      
      raise response.inspect

    end    

 end

