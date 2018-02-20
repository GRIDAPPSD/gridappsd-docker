#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 [-c] [-t tag]"
  /bin/echo "        -c      remove containers and downloads, pull updated images before starting"
  /bin/echo "        -t tag  specify gridappsd docker tag"
  exit 2
}

clean_up () {
  echo " "
  echo "Removing the docker containers"
  docker-compose down

  if [ -f $data_dir/$mysql_file ] ; then
    echo " "
    echo "Removing mysql dump file"
    rm "$data_dir/$mysql_file"
  fi

  if [ -d gridappsdmysql ] ; then
    echo " "
    echo "Removing mysql database files"
    rm -r gridappsdmysql
  fi

  if [ -f $data_dir/ieee8500.xml ] ; then
    echo " "
    echo "Removing blazegraph import file"
    rm "$data_dir/ieee8500.xml"
  fi

  if [ -f .env ] ; then
    echo " "
    echo "Removing the docker .env file"
    rm .env
  fi

  echo " "
  echo "Pulling updated docker images"
  create_env 
  docker-compose pull
}

create_env () {
  if [ -f '.env' ]; then
    prevtag=`cat .env | sed 's/GRIDAPPSD_TAG=://'`
    currtag=`echo $GRIDAPPSD_TAG | sed 's/://'`
    if [ "$prevtag" != "$currtag" ]; then
      echo "Error changing tag from $prevtag to $currtag"
      #echo "Please remove previous versions by runing ./stop.sh -c"
      exit 1
    fi
  else
    echo "Create the docker env file with the tag variables"
    # Create the docker env file with the tag variables
    cat > .env << EOF
GRIDAPPSD_TAG=$GRIDAPPSD_TAG
EOF
  fi
}

viz_url="http://localhost:8080/ieee8500"
blazegraph_url="http://localhost:8889/bigdata/"
mysql_file="gridappsd_mysql_dump.sql"
data_dir="dumps"
# set the default tag for the gridappsd and viz containers
GRIDAPPSD_TAG=':rc3'

# parse options
while getopts ct: option ; do
  case $option in
    c) # Cleanup downloads and containers
      clean_up
      ;;
    t) # Pass gridappsd tag to docker-compose
      GRIDAPPSD_TAG=":$OPTARG"
      ;;
    *) # Print Usage
      usage
      ;;
  esac
done
shift `expr $OPTIND - 1`

create_env

# Mysql
[ ! -d "$data_dir" ] && mkdir "$data_dir"
if [ ! -f "$data_dir/$mysql_file" ]; then
  echo " "
  echo "Downloading mysql data"
  curl -s -o "$data_dir/$mysql_file" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/$mysql_file"
  if [ -f $data_dir/$mysql_file ]; then
    sed -i'.bak' -e "s/'gridappsd'@'localhost'/'gridappsd'@'%'/g" $data_dir/$mysql_file
    # clean up 
    rm $data_dir/${mysql_file}.bak
  fi
fi

if [ ! -f "$data_dir/ieee8500.xml" ]; then
  echo " "
  echo "Downloading blazegraph data"
  curl -s -o "$data_dir/ieee8500.xml" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/ieee8500.xml"
fi


status=$(curl -s --head -w %{http_code} "$blazegraph_url" -o /dev/null)

echo " "
echo "Starting the docker containers"
docker-compose up -d
container_status=$?

if [ $container_status -ne 0 ]; then
  echo " "
  echo "Error starting containers"
  echo "Exiting "
  exit 1
fi

while [ $status -ne "200" ]
do
  status=$(curl -s --head -w %{http_code} "$blazegraph_url" -o /dev/null)
done

# sleep just a little longer to make sure blazegraph is ready to receive data.
sleep 3

# Check if blazegraph data is already loaded
rangeCount=`curl -s -G -H 'Accept: application/xml' "${blazegraph_url}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
if [ $rangeCount -eq 0 ]; then
  echo " "
  echo "Ingesting blazegraph data"
  curl_output=`curl -s -D- -H 'Content-Type: application/xml' --upload-file "$data_dir/ieee8500.xml" -X POST "${blazegraph_url}sparql"`

  echo " "
  echo "Verifying blazegraph data"
  rangeCount=`curl -s -G -H 'Accept: application/xml' "${blazegraph_url}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`

  echo " "
  if [ $rangeCount -gt 0 ]; then
    echo "Finished uploading blazegraph data"
  else
    echo "Error blazegraph data failed to load"
    echo $curl_output
    ## should we exit here?
  fi
fi

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

echo " "
echo "Containers are running"

docker exec -it gridappsddocker_gridappsd_1 /bin/bash

exit 0
