#!/bin/bash


viz_url="http://localhost:8080/ieee8500"

DATA_DIR="dumps"

# Mysql
[ ! -d "$DATA_DIR" ] && mkdir "$DATA_DIR"
if [ ! -f "$DATA_DIR/gridappsd_mysql_dump.sql" ]; then
  echo " "
  echo "Downloading mysql data"
  curl -s -o "$DATA_DIR/gridappsd_mysql_dump.sql" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/gridappsd_mysql_dump.sql"
  sed -i -e "s/'gridappsd'@'localhost'/'gridappsd'@'%'/g" $DATA_DIR/gridappsd_mysql_dump.sql
fi

if [ ! -f "$DATA_DIR/ieee8500.xml" ]; then
  echo " "
  echo "Downloading blazegraph data"
  curl -s -o "$DATA_DIR/ieee8500.xml" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/ieee8500.xml"
fi


status=$(curl -s --head -w %{http_code} "http://localhost:8889/bigdata/" -o /dev/null)

docker-compose up -d

while [ $status -ne "200" ]
do
  status=$(curl -s --head -w %{http_code} "http://localhost:8889/bigdata/" -o /dev/null)
done

# sleep just a little longer to make sure blazegraph is ready to receive data.
sleep 3
echo "Ingesting blazegraph data"
output=`curl -s -D- -H 'Content-Type: application/xml' --upload-file "$DATA_DIR/ieee8500.xml" -X POST 'http://localhost:8889/bigdata/sparql'`
echo "Finished uploading blazegraph data"

status="0"
while [ $status -ne "200" ]
do
  status=$(curl -s --head -w %{http_code} "$viz_url" -o /dev/null)
done

echo "Opening web browser to the viz container $viz_url"
if [ `uname` == "Linux" ]; then
 xdg-open $viz_url
elif [ `uname` == "Darwin" ]; then
 open $viz_url
else
 echo "Please open a browser to $viz_url"
fi
