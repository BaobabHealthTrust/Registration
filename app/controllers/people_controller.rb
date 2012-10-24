class PeopleController < GenericPeopleController
    
  def search
		found_person = nil
		if params[:identifier]

      if  params[:identifier].length == 9 && params[:identifier][0].chr == "R"
         order = Order.find(:first,:conditions =>["accession_number = ? AND voided = 0",params[:identifier]])
         if order
           session[:examination_number] = order.accession_number
           redirect_to :controller => 'patients', :action => 'show',:patient_id => order.patient_id,
                       :encounter_date => order.date_created.to_date,:examination_number => order.accession_number and return
         else
           redirect_to :controller => 'clinic'
         end
      end

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
					redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
				end
			end
		end

		records_per_page = CoreService.get_global_property_value('records_per_page') || 5
		@relation = params[:relation]
		@people = PatientService.person_search(params)
		@patients = []

    unless @people.nil?
			@current_page = @people.paginate(:page => params[:page], :per_page => records_per_page.to_i)
		end

		@current_page.each do | person |
			patient = PatientService.get_patient(person) rescue nil
			@patients << patient
		end

	end
end
 
