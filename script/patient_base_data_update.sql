/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

SET @'start_date' = '2012-02-11';

SET @'end_date' = '2012-02-15 23:59:59';

/* Reset users persons */
SET @'min_person_id' = (SELECT MIN(person_id) FROM bart2.users WHERE person_id > 1);

UPDATE bart2.users SET person_id = NULL;

DELETE FROM bart2.person_name WHERE person_id >= @'min_person_id';
UPDATE bart2.encounter SET provider_id = 1;
DELETE FROM bart2.person WHERE person_id >= @'min_person_id';

/* Update patient and person details */
INSERT INTO bart2.person (person_id, birthdate, birthdate_estimated, gender, death_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, birthdate, birthdate_estimated, gender, death_date, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient WHERE date_created BETWEEN @'start_date' AND @'end_date';

UPDATE bart2.person SET gender = LEFT(RTRIM(LTRIM(gender)), 1);

INSERT INTO bart2.patient (patient_id, creator, voided, voided_by, void_reason, date_voided, date_created)
SELECT patient_id, creator, voided, voided_by, void_reason, date_voided, date_created FROM bart1.patient WHERE date_created BETWEEN @'start_date' AND @'end_date';

/* Update patient person addresses */
INSERT INTO bart2.person_address (person_id, city_village, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, city_village, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_address WHERE date_created BETWEEN @'start_date' AND @'end_date';

/* Update patient identifiers and attributes */
INSERT INTO bart2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 3 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 1 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 17 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 10 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 4 AS identifier_type, preferred, location_id, CONCAT_WS('-ARV-', SUBSTRING(identifier, 1, 3), RTRIM(LTRIM(RIGHT(identifier, LENGTH(identifier) - 3)))) AS identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 18 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 18 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 19 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 13 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 3 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 12 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 5 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 14 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 11 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 15 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_identifier WHERE identifier_type = 12 AND date_created BETWEEN @'start_date' AND @'end_date';

/* Update patient person names */
INSERT INTO bart2.person_name (person_id, middle_name, given_name, family_name, preferred, prefix, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, middle_name, given_name, family_name, preferred, prefix, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart1.patient_name WHERE date_created BETWEEN @'start_date' AND @'end_date';

/* Update patient programs */
SET @'max_program_id' = (SELECT MAX(patient_program_id) FROM bart2.patient_program);

SET @'min_program_id' = (SELECT (MIN(patient_program_id) - 1) FROM bart1.patient_program WHERE date_created BETWEEN @'start_date' AND @'end_date');


INSERT INTO bart2.patient_program (patient_program_id, patient_id, program_id, date_enrolled, date_completed, creator, voided, voided_by, void_reason, date_voided, date_created, uuid, location_id)
SELECT ((patient_program_id - @'min_program_id') + @'max_program_id'), patient_id, program_id, date_enrolled, date_completed, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid, (SELECT property_value FROM bart1.global_property WHERE property = "current_health_center_id") AS location_id FROM bart1.patient_program WHERE patient_id IN (SELECT patient_id FROM bart1.patient) AND date_created BETWEEN @'start_date' AND @'end_date';

UPDATE bart2.patient_program program SET program.date_enrolled = IFNULL((SELECT dates.start_date FROM bart1.patient_start_dates dates WHERE program.patient_id = dates.patient_id), program.date_created) AND (date_created BETWEEN @'start_date' AND @'end_date');

INSERT INTO bart2.patient_state (patient_program_id, state, start_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_program_id, 1, date_enrolled, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart2.patient_program WHERE program_id = 1 AND date_created BETWEEN @'start_date' AND @'end_date';

INSERT INTO bart2.patient_state (patient_program_id, state, start_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_program_id, 118, date_enrolled, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM bart2.patient_program WHERE program_id = 2 AND date_created BETWEEN @'start_date' AND @'end_date';


INSERT INTO bart2.relationship (person_a, relationship, person_b, creator, date_created, voided, voided_by, date_voided, void_reason, uuid)
SELECT p1.patient_id, 13, p2.patient_id, creator, date_created, voided, voided_by, date_voided, void_reason, (SELECT UUID()) AS uuid FROM bart1.relationship rel LEFT JOIN bart1.person p1 ON rel.person_id = p1.person_id LEFT JOIN bart1.person p2 ON rel.relative_id = p2.person_id WHERE date_created BETWEEN @'start_date' AND @'end_date';

/* Update users persons */
SET @'max_person_id' = (SELECT MAX(person_id) FROM bart2.person);

INSERT INTO bart2.person (person_id, birthdate, birthdate_estimated, gender, death_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT (user_id + @'max_person_id') AS user_id, NOW(), 0, 'M', NULL, creator, retired, retired_by, retire_reason, date_retired, date_created, (SELECT UUID()) AS uuid FROM bart2.users;

UPDATE bart2.users SET person_id = user_id + @'max_person_id';
 
INSERT INTO bart2.person_name (person_id, middle_name, given_name, family_name, preferred, prefix, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT person_id, username, username, username,  1, NULL, creator, retired, retired_by, retire_reason, date_retired, date_created, (SELECT UUID()) AS uuid FROM bart2.users;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

