FROM mysql/mysql-server:5.7

COPY ./dumps/gridappsd_mysql_dump.sql /docker-entrypoint-initdb.d/schema.sql
#ADD https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/gridappsd_mysql_dump.sql /docker-entrypoint-initdb.d/

