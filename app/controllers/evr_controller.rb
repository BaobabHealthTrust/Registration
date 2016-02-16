class EvrController < ApplicationController
  def home

    @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] rescue {}
    application_name = @settings["application_name"].strip rescue ""
    return_uri = session[:return_uri]
    if !return_uri.blank? && application_name.match("bart")
      session[:return_uri] = []
      redirect_to return_uri.to_s
      return
    end

    @facility = Location.current_health_center.name rescue ''
    @location = Location.find(session[:location_id]).name rescue ""
    @date = session[:datetime].to_date rescue Date.today.to_date
    @person = Person.find_by_person_id(current_user.person_id) rescue nil
    @user = PatientService.name(@person) rescue nil
    @roles = current_user.user_roles.collect { |r| r.role } rescue []

    render :layout => false
  end

end
