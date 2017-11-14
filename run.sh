#!/bin/bash


usage () {
  /bin/echo "Usage:  $0 [-c] "
  /bin/echo "        -c      remove containers and downloads, pull updated images before starting"
  exit 2
}


clean_up () {
  echo " "
  echo "Removing docker containers"
  docker-compose down

  echo " "
  echo "Removing mysql dump file"
  rm "$data_dir/gridappsd_mysql_dump.sql" 

  echo " "
  echo "Removing blazegraph import file"
  rm "$data_dir/ieee8500.xml"

  echo " "
  echo "Pulling updated docker images"
  docker-compose pull

}


viz_url="http://localhost:8080/ieee8500"
blazegraph_url="http://localhost:8889/bigdata/"
data_dir="dumps"

# parse options
while getopts Rcgmps:f:n:d:r:e: option ; do
  case $option in
    c) # Cleanup downloads and containers
      clean_up
      ;;
    *) # Print Usage
      usage
      ;;
  esac
done
shift `expr $OPTIND - 1`


# Mysql
[ ! -d "$data_dir" ] && mkdir "$data_dir"
if [ ! -f "$data_dir/gridappsd_mysql_dump.sql" ]; then
  echo " "
  echo "Downloading mysql data"
  curl -s -o "$data_dir/gridappsd_mysql_dump.sql" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/gridappsd_mysql_dump.sql"
  sed -i '' -e "s/'gridappsd'@'localhost'/'gridappsd'@'%'/g" $data_dir/gridappsd_mysql_dump.sql
fi

if [ ! -f "$data_dir/ieee8500.xml" ]; then
  echo " "
  echo "Downloading blazegraph data"
  curl -s -o "$data_dir/ieee8500.xml" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/ieee8500.xml"
fi


status=$(curl -s --head -w %{http_code} "$blazegraph_url" -o /dev/null)

echo " "
echo "Starting docker containers"
docker-compose up -d

while [ $status -ne "200" ]
do
  status=$(curl -s --head -w %{http_code} "$blazegraph_url" -o /dev/null)
done

# sleep just a little longer to make sure blazegraph is ready to receive data.
sleep 3
echo " "
echo "Ingesting blazegraph data"
output=`curl -s -D- -H 'Content-Type: application/xml' --upload-file "$data_dir/ieee8500.xml" -X POST "$blazegraph_url/sparql"`
echo "Finished uploading blazegraph data"

status="0"
while [ $status -ne "200" ]
do
  status=$(curl -s --head -w %{http_code} "$viz_url" -o /dev/null)
done

# echo " "
# echo "Opening web browser to the viz container $viz_url"
# if [ `uname` == "Linux" ]; then
#  xdg-open $viz_url
# elif [ `uname` == "Darwin" ]; then
#  open $viz_url
# else
#   echo " "
#   echo "Please open a browser to $viz_url"
# fi

exit 0
