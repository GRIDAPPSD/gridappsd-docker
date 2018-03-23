#!/bin/bash



usage () {
  /bin/echo "Usage:  $0 [-c|w]"
  /bin/echo "        -c      remove containers and downloaded dump files and mysql database"
  /bin/echo "        -w      remove containers and mysql database, preserve downloaded dump files"
  exit 2
}

clean_up () {
  echo " "
  echo "Removing docker containers"
  docker-compose down

  # remove the dump files if -c option
  if [ $cleanup -eq 1 ]; then

    if [ -f $data_dir/$mysql_file ] ; then
      echo " "
      echo "Removing mysql dump file"
      rm "$data_dir/$mysql_file" 
    fi
    
    # download may sometimes fail and create a directory
    if [ -d $data_dir/$mysql_file ] ; then
      echo " "
      echo "Removing mysql dump file"
      rmdir "$data_dir/$mysql_file" 
    fi
  
    echo " "
    for blazegraph_file in $blazegraph_models; do
      if [ -f $data_dir/$blazegraph_file ] ; then
        echo "Removing blazegraph import file $blazegraph_file"
        rm "$data_dir/$blazegraph_file"
      fi
      # download may sometimes fail and create a directory
      if [ -d $data_dir/$blazegraph_file ] ; then
        echo " "
        echo "Removing blazegraph import file $blazegraph_file"
      rmdir "$data_dir/$blazegraph_file"
      fi
    done
  fi

  if [ -f .env ] ; then
    echo " "
    echo "Removing the docker .env file"
    rm .env
  fi

  if [ -d gridappsdmysql ] ; then
    echo " "
    if [ -O gridappsdmysql ] ; then
      echo "Removing mysql database files"
      rm -r gridappsdmysql
    else
      echo "Error: unable to remove gridappsdmysql, please run the following command."
      echo "sudo rm -r gridappsdmysql"
    fi
  fi
}

blazegraph_models="EPRI_DPV_J1.xml IEEE123.xml R2_12_47_2.xml IEEE8500.xml ieee8500.xml"
mysql_file="gridappsd_mysql_dump.sql"
data_dir="dumps"
cleanup=0

# parse options
while getopts cw option ; do
  case $option in
    c) # Cleanup downloads and containers and dump files
      cleanup=1
      ;;
    w) # Cleanup downloads and containers
      cleanup=2
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

if [ $cleanup -gt 0 ]; then
  clean_up
fi

echo " "

exit 0
