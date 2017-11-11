class PatientsController < GenericPatientsController
  def edit_missing
    if request.post?

     remote = DDE2Service.search_by_identifier(params['identifier']).last
     gender = remote['gender'].blank? ? params['gender'] : remote['gender']
     if ['M', 'F'].include?(gender)
       gender = {'M' => 'Male', 'F' => 'Female'}[gender]
     end

     year = params['person']['birth_year'] rescue nil
     month = (params['person']['birth_month'] rescue 7).to_s.rjust(2, '0')
     day = (params['person']['birth_day'] rescue 1).to_s.rjust(2, '0')
     birthdate = "#{year}-#{month}-#{day}"
     birthdate = remote['birthdate'].blank? ? birthdate : remote['birthdate']

     result = {
         "npid" => params['identifier'],
         "family_name"=> remote['names']['family_name'],
         "given_name"=> remote['names']['given_name'],
         "middle_name"=> remote['names']['middle_name'],
         "gender"=> gender,
         "birthdate"=> birthdate,
         "birthdate_estimated" => false,
         "home_district"=> (remote['addresses']['home_district'].blank? ? 'Other' : remote['addresses']['home_district']),
         "attributes" => (remote['attributes'].reject{|a, v| v.blank?} || {}),
         "token" => DDE2Service.token
     }
     url = "#{DDE2Service.dde2_url}/v1/update_patient"
     RestClient.post(url, result.to_json, :content_type => 'application/json'){|response, request, result|
        response = JSON.parse(response) rescue response

        if response['status'] == 200
          session.delete(:missing_fields)
          sleep(0.5)
          redirect_to "/people/search?identifier=#{params['identifier']}" and return
        else
          redirect_to "/" and return
        end
     }
    end
  end

end
