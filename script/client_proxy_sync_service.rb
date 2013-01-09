# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'rubygems'
require 'rest-client'
require 'json'

class ClientProxySyncService
  def initialize
    
  end
  def self.getCurrentVersion4Ids
    ids = []
    identifier_type = PatientIdentifierType.find_by_name("National id").id
    national_ids = PatientIdentifier.find(:all,:conditions => ["identifier_type = ? and length(identifier) = ?",identifier_type,6]).collect{|nid|nid.identifier}

    national_ids.each do|national_id|
      ids << national_id
      if ids.length == 25
              uri = "http://#{'admin'}:#{'admin'}@#{'localhost:3001'}/people/national_ids_to_sync/"
              results = RestClient.post(uri,{"ids" => ids.to_json})
                if results
                   ids = []
                end
      end
    end
    
  end

  getCurrentVersion4Ids
 
end
