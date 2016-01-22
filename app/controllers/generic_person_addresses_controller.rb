class GenericPersonAddressesController < ApplicationController
  def village
    traditional_authority_id = DDETraditionalAuthority.find_by_name("#{params[:filter_value]}").id
    village_conditions = ["name LIKE (?) AND traditional_authority_id = ?", "%#{params[:search_string]}%", traditional_authority_id]

    villages = DDEVillage.find(:all,:conditions => village_conditions, :order => 'name')
    villages = villages.map do |v|
      "<li value=\"#{v.name}\">#{v.name}</li>"
    end
    render :text => villages.join('') + "<li value='Other'>Other</li>" and return
  end

  def traditional_authority
    district_id = DDEDistrict.find_by_name("#{params[:filter_value]}").id
    traditional_authority_conditions = ["name LIKE (?) AND district_id = ?", "%#{params[:search_string]}%", district_id]

    traditional_authorities = DDETraditionalAuthority.find(:all,:conditions => traditional_authority_conditions, :order => 'name')
    traditional_authorities = traditional_authorities.map do |t_a|
      "<li value=\"#{t_a.name}\">#{t_a.name}</li>"
    end
    render :text => traditional_authorities.join('') + "<li value='Other'>Other</li>" and return
  end
  
  def landmark
    search("address1", params[:search_string])
  end

  def address2
    search("address2", params[:search_string])
  end

  def search(field_name, search_string)
    @names = PersonAddress.find_most_common(field_name, search_string).collect{|person_name| person_name.send(field_name)}
    render :text => "<li>" + @names.join("</li><li>") + "</li>"
    #redirect_to :action => :new, :address2 => params[:address2]
  end
  
  def edit
    # only allow these fields to prevent dangerous 'fields' e.g. 'destroy!'
    valid_fields = ['home_district','contact_address']
    unless valid_fields.include? params[:field]
      redirect_to :controller => 'patients', :action => :demographics, :id => params[:id]
      return
    end
    if request.post? && params[:id]
      patient = Patient.find(params[:id])
      current_addresses = patient.person.addresses
      current_addresses.each do |identifier|
        identifier.void('given another address')
      end if current_addresses

	    person_address = PersonAddress.new(params[:person][:addresses])
      person_address.person_id = patient.person.id
	    person_address.save
      redirect_to :controller => :patients, :action => :edit_demographics, :id => patient.id
    else
      @patient = Patient.find(params[:id])
      @address = @patient.person.addresses.last
      @field = params[:field]
      render :layout => true
    end
  end
end
