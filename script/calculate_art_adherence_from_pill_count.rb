  AdherenceConcept = ConceptName.find_by_name("What was the patients adherence for this drug order").concept
  CurrentUser = User.find(1)

  def calculate_art_adherence
    results = []
    records = Patient.find_by_sql("SELECT obs.person_id,obs_datetime,value_numeric,
      d.drug_inventory_id,obs.encounter_id FROM patient p 
      INNER JOIN obs ON person_id=patient_id
      INNER JOIN drug_order d ON obs.order_id = d.order_id 
      INNER JOIN drug dn ON d.drug_inventory_id = dn.drug_id
      WHERE obs.voided = 0 AND obs.concept_id IN 
      (SELECT concept_id FROM concept_name 
      WHERE name IN('Amount of drug brought to clinic','AMOUNT OF DRUG REMAINING AT HOME'))
      GROUP BY obs.person_id,d.drug_inventory_id,obs_datetime")    
    

    puts "looping through #{count = records.length} records ...."
    sleep 5

    records.each do |record|
      patient = Patient.find(record.person_id)
      visit_date = record.obs_datetime.to_date
      drug_given_before(patient, visit_date).uniq.each do |order|
        next unless MedicationService.arv(order.drug_order.drug)
        drug = order.drug_order.drug 
        have_adherence_calculated = adherence_calculated_already(patient,drug,visit_date)
        next if have_adherence_calculated
        daily_consumption = order.drug_order.equivalent_daily_dose 
        order_start_date = order.start_date
        order_auto_expire_date = order.auto_expire_date
        amount_given_last_time = order.drug_order.quantity 

        amount_remaining = get_amount_remaining(patient.id,drug,visit_date)
        expected_amount_remaining = remaining_amount(amount_given_last_time,daily_consumption,order_start_date.to_date,visit_date) 
        adherence = (100*(amount_given_last_time - amount_remaining) / (amount_given_last_time - expected_amount_remaining))

        adherence = adherence.to_f.round(2)

        new_adherence = Observation.new()
        new_adherence.person_id = patient.id
        new_adherence.obs_datetime = visit_date.strftime("%Y-%m-%d 00:00:01")
        new_adherence.value_text = adherence
        new_adherence.creator = CurrentUser.id
        new_adherence.concept_id = AdherenceConcept.id
        new_adherence.order_id = order.id
        new_adherence.encounter_id = record.encounter_id
        new_adherence.save
        puts "adherence >> #{adherence}"
      end
      puts "#{count -= 1} of #{records.length} records ...."
    end
    puts "done ..........."  
  end

  def adherence_calculated_already(patient,drug,visit_date)
    Observation.find(:first,
      :joins => "INNER JOIN drug_order d USING(order_id)",
      :conditions =>["concept_id = ? AND person_id = ? AND drug_inventory_id = ?
      AND obs_datetime >= ? AND obs_datetime <= ? AND obs.voided = 0",
      AdherenceConcept.id,patient.id,drug.id,visit_date.strftime('%Y-%m-%d 00:00:00'),
      visit_date.strftime('%Y-%m-%d 23:59:59')]) != nil
  end

  def get_amount_remaining(patient_id,drug,visit_date)
    records = Patient.find_by_sql("SELECT d.drug_inventory_id, value_numeric
      FROM patient p                                        
      INNER JOIN obs ON person_id=patient_id AND patient_id = #{patient_id}                                   
      INNER JOIN drug_order d ON obs.order_id = d.order_id                      
      INNER JOIN drug dn ON d.drug_inventory_id = dn.drug_id AND d.drug_inventory_id = #{drug.id}
      WHERE obs.voided = 0 AND obs.concept_id IN                                
      (SELECT concept_id FROM concept_name                                      
      WHERE name IN('Amount of drug brought to clinic','AMOUNT OF DRUG REMAINING AT HOME'))
      AND obs_datetime >= '#{visit_date.strftime('%Y-%m-%d 00:00:00')}' 
      AND obs_datetime <= '#{visit_date.strftime('%Y-%m-%d 23:59:59')}'
      GROUP BY obs.person_id,d.drug_inventory_id,obs_datetime")
    
    total = 0

    records.each do |record|
      total += record.value_numeric.to_f
    end
    total 
  end

  def remaining_amount(amount_given_last_time,daily_consumption,start_date,visit_date)
    remaining = (amount_given_last_time - ((visit_date - start_date)) * daily_consumption)
    return 0 if remaining < 0
    return remaining
  end

   def drug_given_before(patient, date = Date.today)                        
    clinic_encounters = ["APPOINTMENT", "VITALS","HIV CLINIC CONSULTATION","HIV RECEPTION",
      "HIV CLINIC REGISTRATION","TREATMENT","DISPENSING",'ART ADHERENCE','HIV STAGING']
    encounter_type_ids = EncounterType.find_all_by_name(clinic_encounters).collect{|e|e.id}
                                                                                
    latest_encounter_date = Encounter.find(:first,:conditions =>["patient_id=? AND encounter_datetime < ? AND 
        encounter_type IN(?)",patient.id,date.strftime('%Y-%m-%d 00:00:00'),    
        encounter_type_ids],:order =>"encounter_datetime DESC").encounter_datetime rescue nil
                                                                                
    return [] if latest_encounter_date.blank?                                   
                                                                                
    start_date = latest_encounter_date.strftime('%Y-%m-%d 00:00:00')            
    end_date = latest_encounter_date.strftime('%Y-%m-%d 23:59:59')              
                                                                                
    concept_id = Concept.find_by_name('AMOUNT DISPENSED').id                    
    Order.find(:all,:joins =>"INNER JOIN obs ON obs.order_id = orders.order_id",
        :conditions =>["obs.person_id = ? AND obs.concept_id = ?                    
        AND obs_datetime >=? AND obs_datetime <=?",                             
        patient.id,concept_id,start_date,end_date],                             
        :order =>"obs_datetime")                                                
  end           


  calculate_art_adherence
