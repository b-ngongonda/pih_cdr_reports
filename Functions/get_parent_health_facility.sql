USE openmrs_neno_warehouse_2022;

/* Function will help get parent health facility for outreach clinics */
DELIMITER //

CREATE FUNCTION get_parent_health_facility ( location VARCHAR(100) )

RETURNS VARCHAR(100)

BEGIN

    IF location IN ("Binje Outreach Clinic","Ntaja Outreach Clinic","Golden Outreach Clinic") 
    THEN
         RETURN "Neno District Hospital";
	ELSEIF location IN ("Felemu Outreach Clinic") 
    THEN
		RETURN "Chifunga HC";
	ELSEIF location IN ("Kasamba Outreach Clinic ") 
    THEN
		RETURN "Midzemba HC";
	ELSE
		RETURN location;
	END IF;

END; //

DELIMITER ;

select get_parent_health_facility("Felemu Outreach Clinic");
