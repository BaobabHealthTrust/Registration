require 'rubygems'
require 'rest-client'
require 'json'

class ClientProxySyncService
  def self.get_current_ids
    identifier_type = PatientIdentifierType.find_by_name("National id").id
    national_ids = PatientIdentifier.find(:all,:conditions => ["identifier_type = ? and length(identifier) = ?",
                                          identifier_type,6]).collect{|nid|nid.identifier}
    return national_ids
  end
  
  def self.send_current_ids
    current_ids = self.get_current_ids
    (self.compile_ids(current_ids) || {}).each do |key,ids|
      param = "patient_ids=#{ids.join(',')}"
      RestClient.get("http://admin:admin@localhost:3001/people/national_ids_to_sync?#{param}")
    end
  end

  def self.get_current_person_ids
     person_ids = RestClient.get("http://admin:admin@localhost:3001/people/send_person_ids_to_client/")
     return JSON.parse(person_ids)
  end

  def self.get_demographics_from_proxy
    current_ids = self.get_current_person_ids
    (self.compile_ids(current_ids) || {}).each do |key,ids|
      param = "person_ids=#{ids.join(',')}"
      patient_demographics = RestClient.get("http://admin:admin@localhost:3001/people/sync_demographics_with_client?#{param}")
      patient_demographics.to_s.split("|").each do |demographics|
        raise patient_demographics.to_s.split("|").count.to_yaml
      end
    end
  end
  
  def self.compile_ids(current_ids)
    return {} if current_ids.blank?
    patients_ids_batch = {}
    count = 1
    patients_ids_batch[count] = []
    ids = []

    (current_ids || []).each do |person_id|
      if (patients_ids_batch[count].length < 25)
        ids << person_id
        patients_ids_batch[count] = ids
      else
        count+=1
        ids = []
        ids << person_id
        patients_ids_batch[count] = ids
      end
    end
    patients_ids_batch
  end
  #get_current_person_ids
  get_demographics_from_proxy
  #send_current_ids
end
