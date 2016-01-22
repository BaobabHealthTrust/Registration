query = "SELECT DISTINCT b2o.order_id
          FROM mpc_bart1_data.orders b1o LEFT JOIN mpc_bart1_data.encounter b1e ON b1e.encounter_id = b1o.encounter_id
                  LEFT JOIN mpc_bart2_data.encounter b2e ON b2e.encounter_type = 25
                              AND b1e.patient_id = b2e.patient_id AND b1e.encounter_type = 3
                              AND DATE(b1e.encounter_datetime) = DATE(b2e.encounter_datetime)

                  LEFT JOIN mpc_bart1_data.drug_order d ON b1o.order_id = d.order_id

                  LEFT JOIN mpc_bart2_data.orders b2o ON b2o.encounter_id = b2e.encounter_id
                  LEFT JOIN mpc_bart2_data.drug_order b2d ON b2d.order_id = b2o.order_id
                  LEFT JOIN mpc_bart2_data.bart1_to_bart2_drug_map bbm ON     b2d.drug_inventory_id = bbm.bart2_id
                  LEFT JOIN mpc_bart2_data.bart1_to_bart2_drug_map bbm2 ON d.drug_inventory_id = bbm2.bart1_id
          WHERE bbm.bart1_id = bbm2.bart1_id AND b1e.encounter_type = 3 
              AND b1o.voided = 1
              AND b2d.drug_inventory_id IS NOT NULL AND b2e.voided=0 AND b2o.voided = 0
              AND b2e.patient_id IN(15476, 16283, 36383, 43544,86655)"

orders_array = Order.find_by_sql(query) 

orders_array.each do |aOrder|
  order = Order.find(aOrder[:order_id])
  if order.voided != true
    order.void
  end
end
