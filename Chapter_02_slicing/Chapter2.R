setwd("~/anaconda3/envs/pracSQL/Chapter_02")
library("RPostgreSQL")
#https://www.r-bloggers.com/getting-started-with-postgresql-in-r/

# loads the PostgreSQL driver
drv <- dbDriver("PostgreSQL")
# creates a connection to the postgres database
con <- dbConnect(drv, dbname = "aranalysis",
                 host = "localhost", port = 5432,
                 user = "tbroderick")#, password = pw)

#test to see if connection works, and teachers table is there
dbExistsTable(con, "teachers")

# Basic syntax for running sql requests
teachers <- dbGetQuery(con, "SELECT * from teachers")

summary(teachers)

# how about data types
sapply(teachers, class)

#---------------------------------
# Now we're going to see how much we can do with sql commands
# before we bring the data into R

# select only a few columsn
teachers <- dbGetQuery(con, "SELECT last_name, first_name, salary FROM teachers")
teachers

# distinct names of schools
teachers <- dbGetQuery(con, "SELECT DISTINCT school FROM teachers")
teachers

# distict schools and salaries
teachers <- dbGetQuery(con, "SELECT DISTINCT school, salary FROM teachers")
teachers

# ordered by
teachers <- dbGetQuery(con, "SELECT first_name, last_name, salary FROM teachers ORDER BY salary DESC")
teachers

# multi-line
teachers1 <- dbGetQuery(con, "SELECT first_name, last_name, salary 
                       FROM teachers 
                       ORDER BY salary DESC")
teachers1


# ordering by two things
teachers <- dbGetQuery(con, 
                       "SELECT last_name, school, hire_date 
                       FROM teachers
                       ORDER BY school ASC, hire_date DESC"
)

teachers

# filter using where
teachers <- dbGetQuery(con, 
                       "SELECT last_name, school, hire_date 
                       FROM teachers
                       WHERE school = 'Myers Middle School'"
)

teachers

# filtering using WHERE
# and different comparison operators

# this is does not equal
teachers <- dbGetQuery(con, 
                       "SELECT school 
                       FROM teachers
                       WHERE school != 'Myers Middle School'"
)

teachers

# hire date is before
teachers <- dbGetQuery(con, 
                       "SELECT first_name, last_name, hire_date 
                       FROM teachers
                       WHERE hire_date < '2006-01-01'"
)

teachers

# salary is between
teachers <- dbGetQuery(con, 
                       "SELECT first_name, last_name, salary 
                       FROM teachers
                       WHERE salary BETWEEN 40000 AND 65000"
)

teachers

# like and ILIKE
# like is case sensitive
# and sql requests using % wildcard need to be escaped using %%
teachers <- dbGetQuery(con, 
                       "SELECT first_name 
                       FROM teachers
                       WHERE first_name LIKE '%%am%%'"
)

teachers

# ILIKE is not case sensitive
teachers <- dbGetQuery(con, 
                       "SELECT first_name 
                       FROM teachers
                       WHERE first_name ILIKE 'sam%'"
)

teachers

# combining operators
teachers <- dbGetQuery(con, 
                       "SELECT * 
                       FROM teachers
                       WHERE school = 'Myers Middle School'
                       AND salary < 40000"
)

teachers

teachers <- dbGetQuery(con, 
                       "SELECT * 
                       FROM teachers
                       WHERE school = 'F.D. Roosevelt HS'
                       AND (salary < 38000 OR salary > 40000)"
)

teachers

# where and order by
teachers <- dbGetQuery(con, 
                       "SELECT first_name, last_name, school, hire_date, salary 
                       FROM teachers
                       WHERE school LIKE '%Roos%'
                       ORDER BY hire_date DESC"
)
teachers

# try it yourself
# list schools, then teachers in order
teachers <- dbGetQuery(con, 
                       "SELECT first_name, last_name, school 
                       FROM teachers
                       ORDER BY school ASC, last_name ASC"
)
teachers

# try it yourself
# find teacher whose first name starts with S
# and who makes more than $40,000
teachers <- dbGetQuery(con, 
                       "SELECT first_name, last_name, school, salary 
                       FROM teachers
                       WHERE first_name ILIKE 's%'
                       AND salary > 40000"
)
teachers

# try it yourself
# rank teachers hired since 2010-01-01, ordered by pay
teachers <- dbGetQuery(con, 
                       "SELECT first_name, last_name, school, salary, hire_date 
                       FROM teachers
                       WHERE hire_date > '2010-01-01'
                       ORDER BY salary DESC"
)
teachers


#---------------------------------------
# disconnect and unload driver when done
dbDisconnect(con)
dbUnloadDriver(drv)


