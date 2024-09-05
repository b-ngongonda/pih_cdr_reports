CREATE PROCEDURE `create_pepfar_tx_pvls_generic`(IN _startDate DATE,IN _endDate DATE, IN _location VARCHAR(255),IN _defaultCutOff INT,IN _birthDateDivider INT,
IN _ageGroup varchar(15))
BEGIN

call create_age_groups();
call create_last_art_outcome_at_facility(_endDate,_location);
call create_hiv_cohort(_startDate,_endDate,_location,_birthDateDivider);

insert into pepfar_tx_pvls(age_group,gender,tx_curr,due_for_vl,routine_samples_drawn,target_samples_drawn,
routine_low_vl_less_than_1000_copies,routine_high_vl_more_than_1000_copies,targeted_low_vl_less_than_1000_copies, targeted_high_vl_more_than_1000_copies)

SELECT "All" as age_group, _ageGroup as gender,
count(IF((vl1.state = 'On antiretrovirals'), 1, NULL)) as tx_curr,
COUNT(IF((due_over_1_year='yes'), 1, NULL)) as due_for_vl,
COUNT(IF((reason_for_test='Routine'), 1, NULL)) as routine_samples_drawn,
COUNT(IF((reason_for_test='Target'), 1, NULL)) as target_samples_drawn,
COUNT(IF((routine_low_vl_less_than_1000_copies='routine low'), 1, NULL)) as routine_low_vl_less_than_1000_copies,
COUNT(IF((routine_high_vl_more_than_1000_copies='routine high'), 1, NULL)) as routine_high_vl_more_than_1000_copies,
COUNT(IF((targeted_low_vl_less_than_1000_copies='targeted low'), 1, NULL)) as targeted_low_vl_less_than_1000_copies,
COUNT(IF((targeted_high_vl_more_than_1000_copies='targeted low'), 1, NULL)) as targeted_high_vl_more_than_1000_copies

from(

SELECT opi.identifier, vl.location, mwp.gender,
 floor(datediff(@endDate,mwp.birthdate)/@birthDateDivider) as age, last_visit_date, next_appointment_date,
 state, vl.patient_id,
reason_for_test, test_date,
CASE
WHEN ldl IS NOT NULL THEN 'LDL'
WHEN other_results IS NOT NULL THEN other_results
WHEN viral_load_result IS NOT NULL THEN viral_load_result
WHEN less_than_limit IS NOT NULL THEN less_than_limit
END AS Result,
CASE WHEN (DATEDIFF(next_appointment_date,test_date)>365) THEN "yes"
ELSE "no" END AS due_over_1_year,
 IF(
    (less_than_limit < 1000 OR viral_load_result < 1000 OR ldl = 'True') AND reason_for_test = 'routine', 'routine low', NULL
) AS routine_low_vl_less_than_1000_copies,
IF(
  (less_than_limit>1000 or viral_load_result>1000) and reason_for_test='routine', 'routine high', null
) as routine_high_vl_more_than_1000_copies,

 IF(
    (less_than_limit < 1000 OR viral_load_result < 1000 OR ldl = 'True') AND reason_for_test = 'target', 'targeted low', NULL
) AS targeted_low_vl_less_than_1000_copies,
IF(
  (less_than_limit>1000 or viral_load_result>1000) and reason_for_test='target', 'target high', null
) as targeted_high_vl_more_than_1000_copies

FROM
(
select avl1.patient_id, location, reason_for_test, visit_date as test_date, lab_location, viral_load_result,less_than_limit, ldl,other_results
from mw_art_viral_load avl1
join
(
	select patient_id,MAX(visit_date) as test_date
    from mw_art_viral_load where visit_date <= @startOfTheYear
	group by patient_id
	) avl2
ON avl1.patient_id = avl2.patient_id and avl1.visit_date = avl2.test_date)vl

LEFT JOIN (
SELECT maf.patient_id, maf.visit_date AS last_visit_date, next_appointment_date
FROM mw_art_followup maf
JOIN (
SELECT patient_id, MAX(visit_date) AS visit_date
FROM mw_art_followup WHERE visit_date <= @startOfTheYear
GROUP BY patient_id
) map1 ON maf.patient_id = map1.patient_id AND maf.visit_date = map1.visit_date
) mmaf ON mmaf.patient_id = vl.patient_id

join mw_patient mwp
on mwp.patient_id = vl.patient_id

join omrs_patient_identifier opi
on opi.patient_id=mmaf.patient_id and opi.type='arv number'
left join last_facility_outcome lfo
on lfo.pat=mmaf.patient_id
WHERE  next_appointment_date BETWEEN @startOfTheYear AND @endDate
and DATEDIFF(next_appointment_date,vl.test_date)>365  and vl.location=@location
and reason_for_test in ('Routine', 'Target')
) vl1
join
(
	select * from hiv_cohort where  
	(case 
		WHEN _ageGroup = "FP" then pregnant_or_lactating = "Patient Pregnant" and gender = "F"
		when _ageGroup = "FNP" then (pregnant_or_lactating = "No" or pregnant_or_lactating is null) and gender = "F"
		WHEN _ageGroup = "FBF" then pregnant_or_lactating = "Currently breastfeeding child" and gender = "F"
		WHEN _ageGroup = "Male"  then gender = "M"
	 end)
    
) sub1 on sub1.patient_id=vl1.patient_id;


END
