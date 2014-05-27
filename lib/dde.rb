module DDE
 
    def self.search_and_or_create(json)
    
      raise "Argument expected to be a JSON Object" if (JSON.parse(json) rescue nil).nil?

      person = JSON.parse(json) rescue {}
      
      birthdate_year = person["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = person["birthdate"].to_date.month rescue nil
      birthdate_day = person["birthdate"].to_date.day rescue nil
      gender = person["gender"] == "F" ? "Female" : "Male"

      passed = {
         "person"=>{"occupation"=>(person["person_attributes"]["occupation"] rescue nil),
         "age_estimate"=> (person["birthdate_estimated"] rescue nil),
         "cell_phone_number"=>(person["person_attributes"]["cell_phone_number"] rescue nil),
         "birth_month"=> birthdate_month ,
         "addresses"=>{"address1"=>(person["addresses"]["current_residence"] rescue nil),
              "address2"=>(person["addresses"]["home_district"] rescue nil),
              "city_village"=>(person["addresses"]["current_village"] rescue nil),
              "state_province"=>(person["addresses"]["current_district"] rescue nil),
              "neighborhood_cell"=>(person["addresses"]["home_village"] rescue nil),
              "county_district"=>(person["addresses"]["home_ta"] rescue nil)},
         "gender"=> gender ,
         "patient"=>{"identifiers"=>{"National id" => ((person["national_id"] || person["_id"]) || person["_id"])}},
         "birth_day"=>birthdate_day,
         "home_phone_number"=>(person["person_attributes"]["home_phone_number"] rescue nil),
         "names"=>{"family_name"=>person["names"]["family_name"],
         "given_name"=>person["names"]["given_name"],
         "middle_name"=>""},
         "birth_year"=>birthdate_year},
         "filter_district"=>"",
         "filter"=>{"region"=>"",
         "t_a"=>""},
         "relation"=>""
        }
        
      # Check if this patient exists locally
      result = PatientIdentifier.find_by_identifier((person["national_id"] || person["_id"]))
         
      if result.blank?
        # if patient does not exist locally, first verify if the patient is similar
        # to an existing one by national_id so you can update else create one
        
        (person["patient"]["identifiers"] || []).each do |identifier|
          
          result = PatientIdentifier.find_by_identifier(identifier[identifier.keys[0]], 
              :conditions => ["identifier_type = ?", 
              PatientIdentifierType.find_by_name("National id").id]) rescue nil
          
          break if !result.blank?
          
        end
        
        if !result.blank?
        
        # raise (person["national_id"] || person["_id"]).inspect
      
          current_national_id = self.get_full_identifier("National id", result.patient_id)        
          self.set_identifier("National id", (person["national_id"] || person["_id"]), result.patient_id)
          self.set_identifier("Old Identification Number", current_national_id.identifier, result.patient_id)
          current_national_id.void("National ID version change")
        
        elsif person["patient_id"].blank?     
        
          self.create_from_form(passed["person"])
          
          result = PatientIdentifier.find_by_identifier((person["national_id"] || person["_id"]))
          
        else
        
          result = Patient.find(person["patient_id"]) rescue nil
          
        end
        
      else
      
        # TODO: Add method to update updates from DDE to local copy
      
      end
       
      return result.patient_id rescue nil
        
    end
    
    def self.get_full_identifier(identifier, patient_id)
      PatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
          PatientIdentifierType.find_by_name(identifier).id, patient_id]) rescue nil
    end

    def self.set_identifier(identifier, value, patient_id)
      PatientIdentifier.create(:patient_id => patient_id, :identifier => value,
        :identifier_type => (PatientIdentifierType.find_by_name(identifier).id))
    end

	  def self.create_from_form(params)

		  address_params = params["addresses"]
		  names_params = params["names"]
		  patient_params = params["patient"]
		  params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
		  birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		  person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation|identifiers|attributes/) }

		  if person_params["gender"].to_s == "Female"
        person_params["gender"] = 'F'
		  elsif person_params["gender"].to_s == "Male"
        person_params["gender"] = 'M'
		  end

		  person = Person.create(person_params)

		  unless birthday_params.empty?
		    if birthday_params["birth_year"] == "Unknown"
          self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		    else
          self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		    end
		  end
		  person.save

		  person.names.create(names_params)
		  person.addresses.create(address_params) unless address_params.empty? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		    :value => params["occupation"]) unless params["occupation"].blank? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		    :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
		    :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

		  person.person_attributes.create(
		    :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
		    :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

      # TODO handle the birthplace attribute

		  if (!patient_params.nil?)
		    patient = person.create_patient

		    patient_params["identifiers"].each{|identifier_type_name, identifier|
          next if identifier.blank?
          identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
          patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		    } if patient_params["identifiers"]

		    # This might actually be a national id, but currently we wouldn't know
		    #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		  end

		  return person
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
