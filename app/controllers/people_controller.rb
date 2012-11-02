class PeopleController < GenericPeopleController
  
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

        national_id_replaced = patient.check_old_national_id(params[:identifier])

				if params[:relation]
					redirect_to search_complete_url(found_person.id, params[:relation]) and return
        elsif national_id_replaced
          print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
        else
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

end
 
