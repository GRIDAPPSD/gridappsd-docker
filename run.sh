#!/bin/bash


echo " "
echo "Downloading mysql data"

#[ ! -d mysqldump ] && mkdir mysqldump
#curl -o mysqldump/gridappsd_mysql_dump.sql https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/gridappsd_mysql_dump.sql
#sed -i -e "s/'gridappsd'@'localhost'/'gridappsd'@'%'/g" mysqldump/gridappsd_mysql_dump.sql



echo " "
echo "Starting docker contianers"

#docker-compose up


echo " "
echo "Downloading and importing blazegraph data"

#curl -o ieee8500.xml https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/ieee8500.xml
curl -D- -H 'Content-Type: application/xml' --upload-file ieee8500.xml -X POST 'http://localhost:8889/bigdata/sparql'


echo " "
echo "Opening web browser to the viz container http://localhost:8080"
open http://localhost:8080