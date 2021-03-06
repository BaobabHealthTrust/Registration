require File.dirname(__FILE__) + '/../test_helper'

class EncountersControllerTest < ActionController::TestCase
  fixtures :person, :person_name, :person_name_code, :person_address, 
           :patient, :patient_identifier, :patient_identifier_type,
           :concept, :concept_name, :concept_class,
           :encounter, :encounter_type, :obs, :global_property

  def setup  
    @controller = EncountersController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end

  context "Encounters controller" do
    
    should "create a new encounter" do
      logged_in_as :mikmck, :registration do
        get :create, {:id => "vitals", :encounter =>{:provider_id => "1",
                      :encounter_type_name => "VITALS", 
                      :patient_id => patient(:evan).patient_id,
                      :encounter_datetime =>"2011-06-28T10:33:31+02:00"},
                      :observations => 
                        [{:patient_id => patient(:evan).patient_id,
                          :concept_name => "WEIGHT (KG)", :person_id => person(:evan).person_id,
                          :obs_datetime => Date.today, :encounter_id => 204,
                          :value_numeric => "56.0"},
                         {:patient_id => patient(:evan).patient_id,
                          :concept_name => "HEIGHT (CM)", :person_id => person(:evan).person_id,
                          :obs_datetime => Date.today, :encounter_id => 1,
                          :value_numeric => "165.0"},
                         {:patient_id => patient(:evan).patient_id,
                          :concept_name => "BODY MASS INDEX,MEASURED",
                          :person_id => person(:evan).person_id,:obs_datetime => Date.today,
                          :encounter_id => 204, :value_numeric => "20.6"}],
                          :filter => {:provider_id => "" }}
        assert_response :redirect
      end
    end            
  end
  
  should "get a child bearing age female patient" do
    logged_in_as :mikmck, :registration do
        get :new, {:patient_id => patient(:evan).patient_id}
        assert_response :redirect
    end
  end  
end
