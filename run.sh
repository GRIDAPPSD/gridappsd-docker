#!/bin/bash

usage () {
  /bin/echo "Usage:  $0 [-d] [-p] [-t tag]"
  /bin/echo "        -d      debug"
  /bin/echo "        -p      pull updated containers"
  /bin/echo "        -t tag  specify gridappsd docker tag"
  exit 2
}

create_env () {
  if [ -f '.env' ]; then
    prevtag=`grep GRIDAPPSD_TAG .env | sed 's/GRIDAPPSD_TAG=://'`
    currtag=`echo $GRIDAPPSD_TAG | sed 's/://'`
    if [ "$prevtag" != "$currtag" ]; then
      echo " "
      echo "Error changing tag from $prevtag to $currtag"
      echo "Please run the stop.sh script with the -c option to remove "
      echo "your existing containers before changing tags"
      echo "  ./stop.sh -c"
      echo " "
      echo "Exiting "
      echo " "
      #echo "Please remove previous versions by runing ./stop.sh -c"
      exit 1
    fi
  else
    echo " "
    echo "Create the docker env file with the tag variables"
    # Create the docker env file with the tag variables
    cat > .env << EOF
# This file is auto generated, please change the tag with the run.sh -t option
GRIDAPPSD_TAG=$GRIDAPPSD_TAG
EOF
  fi
}

debug_msg() {
  msg=$1
  if [ $debug == 1 ]; then
    now=`date`
    echo "DEBUG : $now : $msg"
  fi
}

pull_containers() {
  echo " "
  echo "Pulling updated containers"
  docker-compose pull
}

http_status_container() {
  cnt=$1

  echo " "
  echo "Getting $cnt status"
  if [ "$cnt" == "blazegraph" ]; then
    url=$url_blazegraph
  elif [ "$cnt" == "viz" ]; then
    url=$url_viz
  fi
  debug_msg "$cnt $url"
  status="0"
  count=0
  maxcount=10
  while [ $status -ne "200" -a $count -lt $maxcount ]
  do
    status=$(curl -s --head -w %{http_code} "$url" -o /dev/null)
    debug_msg "curl status: $status"
    sleep 1
    count=`expr $count + 1`
  done
  
  debug_msg "tried $url $count times, max is $maxcount"
  if [ $count -ge $maxcount ]; then
    echo "Error contacting $url ($status)"
    echo "Exiting "
    echo " "
    exit 1
  fi
}

url_viz="http://localhost:8080/"
url_blazegraph="http://localhost:8889/bigdata/"
mysql_file="gridappsd_mysql_dump.sql"
data_dir="dumps"
debug=0
exists=0
# set the default tag for the gridappsd and viz containers
GRIDAPPSD_TAG=':develop'

# parse options
while getopts dpt: option ; do
  case $option in
    d) # enable debug output
      debug=1
      ;;
    p) # pull updated containers
      pull_containers
      exit 0
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

[ -f '.env' ] && exists=1
create_env

# Mysql
[ ! -d "$data_dir" ] && mkdir "$data_dir"
if [ ! -f "$data_dir/$mysql_file" ]; then
  echo " "
  echo "Downloading mysql data"
  debug_msg "curl -s -o \"$data_dir/$mysql_file\" \"https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/$mysql_file\""
  curl -s -o "$data_dir/$mysql_file" "https://raw.githubusercontent.com/GRIDAPPSD/Bootstrap/master/$mysql_file"
  if [ -f $data_dir/$mysql_file ]; then
    sed -i'.bak' -e "s/'gridappsd'@'localhost'/'gridappsd'@'%'/g" $data_dir/$mysql_file
    # clean up 
    rm $data_dir/${mysql_file}.bak
  else
    echo "Error downloading $data_dir/$mysql_file"
    echo "Exiting "
    echo " "
    exit 1
  fi
fi

echo " "
echo "Getting blazegraph status"
status=$(curl -s --head -w %{http_code} "$url_blazegraph" -o /dev/null)
debug_msg "blazegraph curl status: $status"

if [ $GRIDAPPSD_TAG  == ':develop' ]; then
  pull_containers
fi

echo " "
echo "Starting the docker containers"
echo " "
echo " "
docker-compose up -d
container_status=$?

if [ $container_status -ne 0 ]; then
  echo " "
  echo "Error starting containers"
  echo "Exiting "
  echo " "
  exit 1
fi

http_status_container 'blazegraph'

# sleep just a little longer to make sure blazegraph is ready to receive data.
sleep 3

bz_load_status=0
echo " "
echo "Checking blazegraph data"

echo " "
# Check if blazegraph data is already loaded
rangeCount=`curl -s -G -H 'Accept: application/xml' "${url_blazegraph}sparql" --data-urlencode ESTCARD | sed 's/.*rangeCount=\"\([0-9]*\)\".*/\1/'`
echo "Blazegrpah data available ($rangeCount)"

http_status_container 'viz'

# echo " "
# echo "Opening web browser to the viz container $url_viz"
# if [ `uname` == "Linux" ]; then
#  xdg-open $url_viz
# elif [ `uname` == "Darwin" ]; then
#  open $url_viz
# else
#   echo " "
#   echo "Please open a browser to $url_viz"
# fi

echo " "
echo "Containers are running"

gridappsd_container=`docker inspect  --format="{{.Name}}" \`docker-compose ps -q gridappsd\` | sed 's:/::'`

echo " "
echo "Connecting to the gridappsd container"
echo "docker exec -it $gridappsd_container /bin/bash"
echo " "
docker exec -it $gridappsd_container /bin/bash

exit 0
