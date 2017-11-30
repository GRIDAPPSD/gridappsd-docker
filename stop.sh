#!/bin/bash



usage () {
  /bin/echo "Usage:  $0 [-c]"
  /bin/echo "        -c      remove containers and downloaded dump files"
  exit 2
}

clean_up () {
  echo " "
  echo "Removing docker containers"
  docker-compose down

  if [ -f $data_dir/$mysql_file ] ; then
    echo " "
    echo "Removing mysql dump file"
    rm "$data_dir/$mysql_file" 
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

}

mysql_file="gridappsd_mysql.sql"
data_dir="dumps"
cleanup=0

# parse options
while getopts c option ; do
  case $option in
    c) # Cleanup downloads and containers
      cleanup=1
      ;;
    *) # Print Usage
      usage
      ;;
  esac
done
shift `expr $OPTIND - 1`

echo " "
echo "Shutting down the docker containers"
docker-compose stop

if [ $cleanup == 1 ]; then
  clean_up
fi

echo " "

exit 0
