# set directory
setwd("~/anaconda3/envs/pracSQL/Chapter_15_views")

# load libraries
library(tidyverse)
#library('readxl')
library("RPostgreSQL")
options("scipen" = 10)

# connect to postgres (remembert to turn it on)
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv, dbname = "aranalysis",
                   host = "localhost", port = 5432,
                   user = "tbroderick")



# execute query
sql <- "SELECT count(*) FROM us_counties_2010;"
dbGetQuery(con, sql)

# create a view using us counties
sql <- "
CREATE OR REPLACE VIEW nevada_counties_pop_2010 AS
    SELECT geo_name,
    state_fips,
    county_fips,
    p0010001 AS pop_2010
FROM us_counties_2010
WHERE state_us_abbreviation = 'NV'
ORDER BY county_fips;
"
dbGetQuery(con, sql)

# let's see if that worked
sql <- "SELECT * FROM nevada_counties_pop_2010;"
nev <- dbGetQuery(con, sql)

# This is awesome. I can see creating a specific view for reports >= 300 and < 421
# we can save very detailed queries as views
sql <- "
CREATE OR REPLACE VIEW county_pop_change_2010_2000 AS
    SELECT c2010.geo_name,
c2010.state_us_abbreviation AS st,
c2010.state_fips,
c2010.county_fips,
c2010.p0010001 AS pop_2010,
c2000.p0010001 AS pop_2000,
round( (CAST(c2010.p0010001 AS numeric(8,1)) - c2000.p0010001)
/ c2000.p0010001 * 100, 1 ) AS pct_change_2010_2000
FROM us_counties_2010 c2010 INNER JOIN us_counties_2000 c2000
ON c2010.state_fips = c2000.state_fips
AND c2010.county_fips = c2000.county_fips
ORDER BY c2010.state_fips, c2010.county_fips;
"
dbGetQuery(con, sql)

sql <- "SELECT * 
from county_pop_change_2010_2000
WHERE st = 'NV'
ORDER BY pct_change_2010_2000 DESC
LIMIT 5"
dbGetQuery(con, sql)

# creating a view to limit access to a table

sql <- "SELECT * FROM employees;"
dbGetQuery(con, sql)

sql <- "
CREATE OR REPLACE VIEW employees_tax_dept AS
      SELECT emp_id,
      first_name,
      last_name,
      dept_id
FROM employees
WHERE dept_id = 1
ORDER BY emp_id
WITH LOCAL CHECK OPTION;
"
dbGetQuery(con, sql)

sql <- "SELECT * FROM employees_tax_dept;"
dbGetQuery(con, sql)

# since the view is just a straight select and doesn't involve joins
# we can do inserts and updates of the data in the underlying table
sql <- "
INSERT INTO employees_tax_dept (first_name, last_name, dept_id)
VALUES ('Suzanne', 'Legere', 1);"
dbGetQuery(con, sql)
# this works because the CHECK OPTION checks to see if dept_id = 1

sql <- "SELECT * FROM employees_tax_dept;"
dbGetQuery(con, sql)

# This is the view - but the actual employees table is what gets updated
sql <- "SELECT * FROM employees;"
dbGetQuery(con, sql)

# Apparently we can't insert salaries because that's not included in the view
# but we can make changes to available columns
sql <- "
UPDATE employees_tax_dept
SET last_name = 'Le Gere'
WHERE emp_id = 7;
"
dbGetQuery(con, sql)

sql <- "SELECT * FROM employees_tax_dept;"
dbGetQuery(con, sql)

# in the same way we can DELETE FROM as long as the employee is in dept_id 1

# ----------
# Creating and using functions

sql <- "CREATE OR REPLACE FUNCTION
percent_change(new_value numeric,
               old_value numeric,
               decimal_places integer DEFAULT 1)
RETURNS numeric AS
'SELECT round(
        ((new_value - old_value) / old_value) * 100, decimal_places
);'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;
"
dbGetQuery(con, sql)

# and the percent_change function has been added to the list in postgres

# using it
sql <- "SELECT percent_change(110, 108, 1);"
dbGetQuery(con, sql)
# in a query
sql <- "SELECT c2010.geo_name,
        c2010.state_us_abbreviation AS st,
        c2010.p0010001 AS pop_2010,
        percent_change(c2010.p0010001, c2000.p0010001) AS pct_chg_func,
        round( (CAST(c2010.p0010001 AS numeric(8,1)) - c2000.p0010001)
        / c2000.p0010001 * 100, 1 ) AS pct_chg_formula
FROM us_counties_2010 c2010 INNER JOIN us_counties_2000 c2000
ON c2010.state_fips = c2000.state_fips
AND c2010.county_fips = c2000.county_fips
ORDER BY pct_chg_func DESC
LIMIT 5;"
dbGetQuery(con, sql)

# updating with a function
sql <- "SELECT count(*) FROM teachers;"
dbGetQuery(con, sql)

# first add a column
sql <- "
ALTER TABLE teachers ADD COLUMN personal_days integer;

SELECT first_name,
last_name,
hire_date,
personal_days
FROM teachers;
"
dbGetQuery(con, sql)

# create a function that automatically updates personal days
# based on set conditions
sql <- "
CREATE OR REPLACE FUNCTION update_personal_days()
RETURNS void AS $$
BEGIN
UPDATE teachers
SET personal_days =
CASE WHEN (now() - hire_date) BETWEEN '5 years'::interval
AND '10 years'::interval THEN 4
WHEN (now() - hire_date) > '10 years'::interval THEN 5
ELSE 3
END;
RAISE NOTICE 'personal_days updated!';
END;
$$ LANGUAGE plpgsql;
"
dbGetQuery(con, sql)

# and this would be one where we suppress the warning
sql <- "SELECT update_personal_days();"
suppressWarnings( dbGetQuery(con, sql) )

# now let's check the result
sql <- "SELECT * FROM teachers;"
dbGetQuery(con, sql)


# ----------
# Creating and using triggers

# first create the tables we'll use
sql <- "

CREATE TABLE grades (
student_id bigint,
course_id bigint,
course varchar(30) NOT NULL,
grade varchar(5) NOT NULL,
PRIMARY KEY (student_id, course_id)
);

INSERT INTO grades
VALUES
(1, 1, 'Biology 2', 'F'),
(1, 2, 'English 11B', 'D'),
(1, 3, 'World History 11B', 'C'),
(1, 4, 'Trig 2', 'B');

CREATE TABLE grades_history (
student_id bigint NOT NULL,
course_id bigint NOT NULL,
change_time timestamp with time zone NOT NULL,
course varchar(30) NOT NULL,
old_grade varchar(5) NOT NULL,
new_grade varchar(5) NOT NULL,
PRIMARY KEY (student_id, course_id, change_time)
);
"
dbGetQuery(con, sql)

sql <- "SELECT * FROM grades;"
dbGetQuery(con, sql)

# grades_history is empty because the trigger function will fill that
# here's the function the trigger will invoke

sql <- "
CREATE OR REPLACE FUNCTION record_if_grade_changed()
    RETURNS trigger AS
$$
BEGIN
IF NEW.grade <> OLD.grade THEN
INSERT INTO grades_history (
            student_id,
            course_id,
            change_time,
            course,
            old_grade,
            new_grade)
VALUES
            (OLD.student_id,
            OLD.course_id,
            now(),
            OLD.course,
            OLD.grade,
            NEW.grade);
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
"
dbGetQuery(con, sql)

# and here's the trigger
sql <- "
CREATE TRIGGER grades_update
  AFTER UPDATE
ON grades
FOR EACH ROW
EXECUTE PROCEDURE record_if_grade_changed();
"
dbGetQuery(con, sql)


# let's see the grades again
sql <- "SELECT * FROM grades;"
dbGetQuery(con, sql)

# let's see what happens when we update
sql <- "
UPDATE grades
SET grade = 'C'
WHERE student_id = 1 AND course_id = 1;"
dbGetQuery(con, sql)

# the grades
sql <- "SELECT * FROM grades;"
dbGetQuery(con, sql)

# the grades history
# let's see the grades again
sql <- "SELECT * FROM grades_history;"
dbGetQuery(con, sql)

# automatically classifying temperatures
# create the table
sql <- "
CREATE TABLE temperature_test (
    station_name varchar(50),
observation_date date,
max_temp integer,
min_temp integer,
max_temp_group varchar(40),
PRIMARY KEY (station_name, observation_date)
);
"
dbGetQuery(con, sql)

# create the function for the trigger
sql <- "
CREATE OR REPLACE FUNCTION classify_max_temp()
    RETURNS trigger AS
$$
BEGIN
CASE
WHEN NEW.max_temp >= 90 THEN
NEW.max_temp_group := 'Hot';
WHEN NEW.max_temp BETWEEN 70 AND 89 THEN
NEW.max_temp_group := 'Warm';
WHEN NEW.max_temp BETWEEN 50 AND 69 THEN
NEW.max_temp_group := 'Pleasant';
WHEN NEW.max_temp BETWEEN 33 AND 49 THEN
NEW.max_temp_group :=  'Cold';
WHEN NEW.max_temp BETWEEN 20 AND 32 THEN
NEW.max_temp_group :=  'Freezing';
ELSE NEW.max_temp_group :=  'Inhumane';
END CASE;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
"
dbGetQuery(con, sql)

# and finally the trigger
sql <- "
CREATE TRIGGER temperature_insert
    BEFORE INSERT
ON temperature_test
FOR EACH ROW
EXECUTE PROCEDURE classify_max_temp();
"
dbGetQuery(con, sql)

# when we insert data into the table, the trigger should update the group column
sql <- "
INSERT INTO temperature_test (station_name, observation_date, max_temp, min_temp)
VALUES
('North Station', '1/19/2019', 10, -3),
('North Station', '3/20/2019', 28, 19),
('North Station', '5/2/2019', 65, 42),
('North Station', '8/9/2019', 93, 74);
"
dbGetQuery(con, sql)

# let's see
sql <- "SELECT * FROM temperature_test;"
dbGetQuery(con, sql)


# disconnect
dbDisconnect(con)
dbUnloadDriver(drv)

