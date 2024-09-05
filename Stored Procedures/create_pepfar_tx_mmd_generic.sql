CREATE PROCEDURE `create_pepfar_tx_mmd_generic`(IN _startDate DATE,IN _endDate DATE, IN _location VARCHAR(255),IN _defaultCutOff INT,IN _birthDateDivider INT,
IN _ageGroup varchar(15))
BEGIN
call create_age_groups();
call create_last_art_outcome_at_facility(_endDate,_location);
call create_hiv_cohort(_startDate,_endDate,_location,_birthDateDivider);

insert into pepfar_tx_mmd(age_group,gender,less_than_three_months,three_to_five_months,six_months_plus)

SELECT "All" as age_group, _ageGroup as gender,
COUNT(IF((days_diff < 80), 1, NULL)) as less_than_three_months,
COUNT(IF((days_diff BETWEEN 80 and 168), 1, NULL)) as three_to_five_months,
COUNT(IF((days_diff > 168), 1, NULL)) as six_months_plus
from
(
select map.patient_id,mwp.gender,floor(datediff(_endDate,mwp.birthdate)/_birthDateDivider) as age, map.visit_date,
 map.next_appointment_date as next_appt_date, map.art_regimen, map.arvs_given, datediff(map.next_appointment_date,map.visit_date) as days_diff
    from mw_art_followup map
join
(
	select patient_id,MAX(visit_date) as visit_date ,MAX(next_appointment_date) as last_appt_date from mw_art_followup where visit_date <= _endDate
	group by patient_id
	) map1
ON map.patient_id = map1.patient_id and map.visit_date = map1.visit_date
join mw_patient mwp
on mwp.patient_id = map.patient_id
where map.patient_id in (select pat from last_facility_outcome where state = "On antiretrovirals")
and floor(datediff(_endDate,map.next_appointment_date)) <=  _defaultCutOff
)x

 join
(
  select * from hiv_cohort where  
	(case 
		WHEN _ageGroup = "FP" then pregnant_or_lactating = "Patient Pregnant" and gender = "F"
		when _ageGroup = "FNP" then (pregnant_or_lactating = "No" or pregnant_or_lactating is null) and gender = "F"
		WHEN _ageGroup = "FBF" then pregnant_or_lactating = "Currently breastfeeding child" and gender = "F"
		WHEN _ageGroup = "Male"  then gender = "M"
	 end)
)sub1 on sub1.patient_id=x.patient_id;

END
