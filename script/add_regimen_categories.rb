# add regimen category obs where they are missing
#
# script/runner -e production script/add_regimen_categories.rb
#


dispensation_controller = DispensationsController.new
concept_id = ConceptName.find_by_name('Regimen Category').concept_id
encounter_type_id = EncounterType.find_by_name('DISPENSING').id

dispensations = Encounter.find(
  :all,
  :joins => "LEFT JOIN obs o ON encounter.encounter_id = o.encounter_id AND
                                o.concept_id = #{concept_id}",
  :conditions => ['encounter_type = ? AND o.obs_id IS NULL AND
                  encounter.voided = 0',
                  encounter_type_id])
  
dispensations.each do |dispensation|
  treatment_obs = dispensation.observations.first(
                    :conditions => ['obs.order_id IS NOT NULL'],
                    :joins => :order)
  next if treatment_obs.blank?
  
  treatment_order = treatment_obs.order
  next if treatment_order.blank?
  
  treatment = treatment_order.encounter
  User.current = User.find(dispensation.creator)
  
  dispensation_controller.set_received_regimen(dispensation.patient,
                                               dispensation,
                                               treatment) 
end
