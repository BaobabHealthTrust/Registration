USE bart1;

DROP TABLE IF EXISTS `temp_orders`;

CREATE TABLE `temp_orders` (
  `order_id` int(11) NOT NULL DEFAULT '0',
  `encounter_id` int(11) NOT NULL DEFAULT '0', 
  KEY (`order_id`),
  KEY (`encounter_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT INTO temp_orders (order_id, encounter_id) 
SELECT bo.order_id, bo.encounter_id FROM bart1.orders bo INNER JOIN bart1.drug_order bdo ON bo.order_id = bdo.order_id
    WHERE bo.order_id NOT IN (SELECT d.order_id
        FROM bart1.orders b1o LEFT JOIN bart1.encounter b1e ON b1e.encounter_id = b1o.encounter_id
                LEFT JOIN bart2.encounter b2e ON b2e.encounter_type = 25
                            AND b1e.patient_id = b2e.patient_id AND b1e.encounter_type = 3
                            AND DATE(b1e.encounter_datetime) = DATE(b2e.encounter_datetime)
 
                LEFT JOIN bart1.drug_order d ON b1o.order_id = d.order_id

                LEFT JOIN bart2.orders b2o ON b2o.encounter_id = b2e.encounter_id
                LEFT JOIN bart2.drug_order b2d ON b2d.order_id = b2o.order_id
                LEFT JOIN bart2.bart1_to_bart2_drug_map bbm ON     b2d.drug_inventory_id = bbm.bart2_id
                LEFT JOIN bart2.bart1_to_bart2_drug_map bbm2 ON d.drug_inventory_id = bbm2.bart1_id
        WHERE bbm.bart1_id = bbm2.bart1_id AND b1e.encounter_type = 3 AND b2d.drug_inventory_id IS NOT NULL AND b2e.voided=0);

