#!/bin/bash


viz_url="http://localhost:8080"



# Mysql
[ ! -d mysqldump ] && mkdir mysqldump
if [ ! -f mysqldump/gridappsd_mysql_dump.sql ]; then
  echo " "
  echo "Downloading mysql data"
  curl -s -o mysqldump/gridappsd_mysql_dump.sql https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/gridappsd_mysql_dump.sql
  sed -i -e "s/'gridappsd'@'localhost'/'gridappsd'@'%'/g" mysqldump/gridappsd_mysql_dump.sql
fi

# Docker
echo " "
echo "Starting docker containers"

docker-compose up -d


# Blazegraph
if [ ! -f ieee8500.xml ]; then
  echo " "
  if [ `docker-compose ps | grep -c "gridappsddocker_blazegraph"` -gt 0 ]; then
    echo "Downloading and importing blazegraph data"
  
    curl -s -o ieee8500.xml https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/ieee8500.xml
    output=`curl -s -D- -H 'Content-Type: application/xml' --upload-file ieee8500.xml -X POST 'http://localhost:8889/bigdata/sparql'`

    if [ `echo $output | grep -c 'data modified="446127"'` -lt 1 ]; then
      echo "Blazegraph import failed"
      echo $output
    else
      echo "Blazegraph data imported"
    fi
  else
    echo "Error connecting with blazegraph container"
  fi
  echo " "
fi



#echo " "
#echo "Opening web browser to the viz container $viz_url"
#if [ `uname` == "Linux" ]; then
#  xdg-open $viz_url
#elif [ `uname` == "Darwin" ]; then
#  open $viz_url
#else
#  echo "Please open a browser to $viz_url"
#fi
