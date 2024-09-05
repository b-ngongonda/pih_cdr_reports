CREATE PROCEDURE `create_pepfar_tb_prev_generic`(IN _startDate DATE,IN _endDate DATE, IN _location VARCHAR(255),IN _defaultCutOff INT,IN _birthDateDivider INT,
IN _ageGroup varchar(15))
BEGIN

call create_age_groups();
call create_last_art_outcome_at_facility(_endDate,_location);
call create_hiv_cohort(_startDate,_endDate,_location,_birthDateDivider);

insert into pepfar_tb_prev(age_group,gender,new_start_three_hp,new_start_six_h,previous_start_three_hp,previous_start_six_h,
completed_new_start_three_hp,completed_new_start_six_h,completed_old_three_hp,completed_old_six_h)

SELECT "All" as age_group, _ageGroup as gender,
COUNT(IF(((y.initial_visit_date >= @sixMonthsStartDate and y.transfer_in_date is null) or y.start_date >= @sixMonthsStartDate)
and ((y.first_inh_300 is not null and y.first_rfp_150 is not null) or y.first_rfp_inh is not null),1,NULL)) as new_start_three_hp,
COUNT(IF(((y.initial_visit_date >= @sixMonthsStartDate and y.transfer_in_date is null) or y.start_date >= @sixMonthsStartDate)
and (y.first_inh_300 is not null and y.first_rfp_150 is null),1,NULL)) as new_start_six_h,
COUNT(IF(y.initial_visit_date < @sixMonthsStartDate
and ((y.first_inh_300 is not null and y.first_rfp_150 is not null) or y.first_rfp_inh is not null),1,NULL)) as old_start_three_hp,
COUNT(IF(y.initial_visit_date < @sixMonthsStartDate
and (y.first_inh_300 is not null and y.first_rfp_150 is null),1,NULL)) as old_start_six_h,
COUNT(IF(((y.initial_visit_date >= @sixMonthsStartDate and y.transfer_in_date is null) or y.start_date >= @sixMonthsStartDate)
and
( coalesce(total_6_months_rfp_150_pills,0) + coalesce(total_6_months_rfp_inh_pills,0) ) >= 33,1,NULL )) as completed_new_start_three_hp,
COUNT(IF(((y.initial_visit_date >= @sixMonthsStartDate and y.transfer_in_date is null) or y.start_date >= @sixMonthsStartDate)
and total_1_yr_inh_300_pills >= 144, 1, null)) as completed_new_start_six_h,
COUNT(IF(y.initial_visit_date < @sixMonthsStartDate
and ( coalesce(total_6_months_rfp_150_pills,0)  + coalesce(total_6_months_rfp_inh_pills,0) ) >= 33,1,NULL )) as completed_old_three_hp,
COUNT(IF(y.initial_visit_date < @sixMonthsStartDate
and total_1_yr_inh_300_pills >= 144, 1, null)) as completed_old_six_h
from
(
select *
from (
select distinct(mwp.patient_id) as patient_id, opi.identifier,ops.state,ops.start_date, mwp.gender,
 If(ops.state = "On antiretrovirals",floor(datediff(_endDate,mwp.birthdate)/_birthDateDivider),floor(datediff(ops.start_date,mwp.birthdate)/_birthDateDivider)) as age,
 ops.location, patient_visit.last_appt_date,patient_visit.followup_visit_date, patient_visit.art_regimen as current_regimen,
 patient_visit.pregnant_or_lactating, patient_initial_visit.initial_pregnant_or_lactating, patient_initial_visit.initial_visit_date,
 patient_initial_visit.transfer_in_date,first_ipt_date,first_inh_300,first_inh_300_pills,first_rfp_150,first_rfp_150_pills,first_rfp_inh,first_rfp_inh_pills,last_inh_300,last_inh_300_pills,last_rfp_150,
 last_rfp_150_pills,last_rfp_inh,last_rfp_inh_pills,last_ipt_date,previous_inh_300,previous_inh_300_pills,previous_rfp_150,
 previous_rfp_150_pills,previous_rfp_inh,previous_rfp_inh_pills,previous_ipt_date,
 total_1_yr_inh_300_pills, total_1_yr_rfp_150_pills,total_1_yr_rfp_inh_pills, total_6_months_inh_300_pills,
 total_6_months_rfp_150_pills, total_6_months_rfp_inh_pills
from  mw_patient mwp
LEFT join (
	select map.patient_id, map.visit_date as followup_visit_date, map.next_appointment_date as last_appt_date, map.art_regimen,
    map.pregnant_or_lactating
    from mw_art_followup map
join
(
	select patient_id,MAX(visit_date) as visit_date ,MAX(next_appointment_date) as last_appt_date from mw_art_followup where visit_date <= _endDate
	group by patient_id
	) map1
ON map.patient_id = map1.patient_id and map.visit_date = map1.visit_date) patient_visit
            on patient_visit.patient_id = mwp.patient_id
LEFT join (
	select map.patient_id, map.visit_date as last_ipt_date, map.inh_300 as last_inh_300,
    map.inh_300_pills as last_inh_300_pills,map.rfp_150 as last_rfp_150,map.rfp_150_pills as last_rfp_150_pills,
    map.rfp_inh as last_rfp_inh,map.rfp_inh_pills as last_rfp_inh_pills
    from mw_art_followup map
join
(
	select patient_id,MAX(visit_date) as visit_date
    from mw_art_followup where visit_date between @sixMonthsStartDate and _endDate and
    ((inh_300 is not null or inh_300_pills is not null) or (rfp_150 is not null or rfp_150_pills is not null) or (rfp_inh is not null or rfp_inh_pills is not null))
	group by patient_id
	) map1
ON map.patient_id = map1.patient_id and map.visit_date = map1.visit_date) last_ipt_visit
            on last_ipt_visit.patient_id = mwp.patient_id


LEFT join (
	select map.patient_id, map.visit_date as previous_ipt_date, map.inh_300 as previous_inh_300,
    map.inh_300_pills as previous_inh_300_pills,map.rfp_150 as previous_rfp_150,map.rfp_150_pills as previous_rfp_150_pills,
    map.rfp_inh as previous_rfp_inh,map.rfp_inh_pills as previous_rfp_inh_pills
    from mw_art_followup map
join
(
	select patient_id,MAX(visit_date) as visit_date
    from mw_art_followup where visit_date <= DATE_SUB(@sixMonthsStartDate, INTERVAL 1 DAY) and
    ((inh_300 is not null or inh_300_pills is not null) or (rfp_150 is not null or rfp_150_pills is not null) or (rfp_inh is not null or rfp_inh_pills is not null))
	group by patient_id
	) map1
ON map.patient_id = map1.patient_id and map.visit_date = map1.visit_date) before_start_date_ipt_visit
            on before_start_date_ipt_visit.patient_id = mwp.patient_id



LEFT join (
	select map.patient_id, map.visit_date as first_ipt_date, map.next_appointment_date as last_appt_date, map.art_regimen,
    map.pregnant_or_lactating, map.inh_300 as first_inh_300,map.inh_300_pills as first_inh_300_pills,
    map.rfp_150 as first_rfp_150,map.rfp_150_pills as first_rfp_150_pills, map.rfp_inh as first_rfp_inh,map.rfp_inh_pills as first_rfp_inh_pills
    from mw_art_followup map
join
(
	select patient_id,MIN(visit_date) as visit_date
    from mw_art_followup where visit_date between @sixMonthsStartDate and _endDate and
    ((inh_300 is not null or inh_300_pills is not null) or (rfp_150 is not null or rfp_150_pills is not null) or (rfp_inh is not null or rfp_inh_pills is not null))
	group by patient_id
	) map1
ON map.patient_id = map1.patient_id and map.visit_date = map1.visit_date) min_patient_visit
            on min_patient_visit.patient_id = mwp.patient_id

left join
(
	select patient_id,SUM(inh_300_pills) as total_1_yr_inh_300_pills, sum(rfp_150_pills) as total_1_yr_rfp_150_pills,
    SUM(rfp_inh_pills) as total_1_yr_rfp_inh_pills
    from mw_art_followup where visit_date between @thirteenMonthsStartDate and _endDate
    group by patient_id
	) map2
ON map2.patient_id = mwp.patient_id
left join
(
	select patient_id,SUM(inh_300_pills) as total_6_months_inh_300_pills, sum(rfp_150_pills) as total_6_months_rfp_150_pills,
    SUM(rfp_inh_pills) as total_6_months_rfp_inh_pills
    from mw_art_followup where visit_date between @sevenMonthsStartDate and _endDate
    group by patient_id
	) map3
ON map3.patient_id = mwp.patient_id
LEFT join (
	select mar.patient_id, mar.visit_date as initial_visit_date,
    mar.pregnant_or_lactating as initial_pregnant_or_lactating, mar.transfer_in_date
    from mw_art_initial mar
join
(
	select patient_id,MAX(visit_date) as visit_date  from mw_art_initial where visit_date <= _endDate
	group by patient_id
	) mar1
ON mar.patient_id = mar1.patient_id and mar.visit_date = mar1.visit_date) patient_initial_visit
            on patient_initial_visit.patient_id = mwp.patient_id
join omrs_patient_identifier opi
on mwp.patient_id = opi.patient_id

JOIN
         last_facility_outcome as ops
            on opi.patient_id = ops.pat and opi.location = ops.location
            where opi.type = "ARV Number"

) x where first_ipt_date >= @sixMonthsStartDate
) y

join
(
	select * from hiv_cohort where  
	(case 
		WHEN _ageGroup = "FP" then pregnant_or_lactating = "Patient Pregnant" and gender = "F"
		when _ageGroup = "FNP" then (pregnant_or_lactating = "No" or pregnant_or_lactating is null) and gender = "F"
		WHEN _ageGroup = "FBF" then pregnant_or_lactating = "Currently breastfeeding child" and gender = "F"
		WHEN _ageGroup = "Male"  then gender = "M"
	 end)
    
) sub1 on sub1.patient_id=y.patient_id;


END
