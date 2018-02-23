#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 [-t tag]"
  /bin/echo "        -t tag  specify gridappsd docker tag"
  exit 2
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
blazegraph_models="EPRI_DPV_J1.xml IEEE123.xml R2_12_47_2.xml ieee8500.xml"
blazegraph_url="http://localhost:8889/bigdata/"
mysql_file="gridappsd_mysql_dump.sql"
data_dir="dumps"
# set the default tag for the gridappsd and viz containers
GRIDAPPSD_TAG=':rc3'

# parse options
while getopts t: option ; do
  case $option in
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
  else
    echo "Error downloading $data_dir/$mysql_file"
    exit 1
  fi
fi

echo " "
for blazegraph_file in $blazegraph_models; do
  if [ ! -f "$data_dir/$blazegraph_file" ]; then
    echo "Downloading blazegraph data $blazegraph_file"
    curl -s -o "$data_dir/$blazegraph_file" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/$blazegraph_file"
    if [ ! -f "$data_dir/$blazegraph_file" ]; then
      echo "Error downloading $data_dir/$blazegraph_file"
      exit 1
    fi
  fi
done


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
if [ x"$rangeCount" == x"0" ]; then
  for blazegraph_file in $blazegraph_models; do
    echo " "
    echo "Ingesting blazegraph data $data_dir/$blazegraph_file ${blazegraph_url}sparql"
    #echo "curl -s -D- -H 'Content-Type: application/xml' --upload-file \"$data_dir/$blazegraph_file\" -X POST \"${blazegraph_url}sparql\""
    curl_output=`curl -s -D- -H 'Content-Type: application/xml' --upload-file "$data_dir/$blazegraph_file" -X POST "${blazegraph_url}sparql"`
    bz_status=`echo $curl_output | grep -c 'data modified='`

    if [ ${bz_status:-0} -ne 1 ]; then
      echo " "
      echo "Error could not load blazegraph data $data_dir/$blazegraph_file"
    fi
  done

  echo " "
  echo "Verifying blazegraph data"
  rangeCount=`curl -s -G -H 'Accept: application/xml' "${blazegraph_url}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`

  echo " "
  if [ ${rangeCount:-0} -gt 0 ]; then
    echo "Finished uploading blazegraph data ($rangeCount)"
  else
    echo "Error blazegraph data failed to load"
    #echo $curl_output
    exit 1
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
