#!/bin/bash

# Detect docker compose command (newer 'docker compose' vs older 'docker-compose')
detect_docker_compose() {
  if docker compose version &>/dev/null; then
    echo "docker compose"
  elif docker-compose --version &>/dev/null; then
    echo "docker-compose"
  else
    echo ""
  fi
}

DOCKER_COMPOSE_CMD=$(detect_docker_compose)

if [ -z "$DOCKER_COMPOSE_CMD" ]; then
  echo "Error: Neither 'docker compose' nor 'docker-compose' command found"
  echo "Please install Docker Compose"
  exit 1
fi

echo "Using: $DOCKER_COMPOSE_CMD"

usage () {
  /bin/echo "Usage:  $0 [-c|w]"
  /bin/echo "        -c      remove containers and downloaded dump files and mysql database"
  /bin/echo "        -w      remove containers and mysql database, preserve downloaded dump files"
  exit 2
}

clean_up () {
  echo " "
  echo "Removing docker containers"
  $DOCKER_COMPOSE_CMD $compose_files down

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
  
    for blazegraph_file in $blazegraph_models; do
      if [ -f $data_dir/$blazegraph_file ] ; then
        echo " "
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

  if [ -f conf/viz.config ] ; then
    echo " "
    echo "Removing the remote viz configuration file"
    rm conf/viz.config
  fi

  if [ -f docker-compose.d/viz.yml ] ; then
    echo " "
    echo "Removing the remote viz compose file"
    rm docker-compose.d/viz.yml
  fi

  for dbdir in $database_dirs; do
    if [ -d $dbdir ] ; then
      echo " "
      if [ -O $dbdir ] ; then
        echo "Removing $dbdir database files"
        rm -r $dbdir
      else
        echo "Error: unable to remove $dbdir, please run the following command."
        echo "sudo rm -r $dbdir"
      fi
    fi
  done
}

blazegraph_models="EPRI_DPV_J1.xml IEEE123.xml R2_12_47_2.xml IEEE8500.xml ieee8500.xml"
mysql_file="gridappsd_mysql_dump.sql"
data_dir="dumps"
cleanup=0
database_dirs="gridappsdmysql gridappsd"

compose_files=$( ls -1 docker-compose.d/*yml 2>/dev/null | sed -e 's/^/-f /g' | tr '\n' ' ' )
compose_files="-f docker-compose.yml $compose_files"
echo "Compose files: $compose_files"

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
$DOCKER_COMPOSE_CMD $compose_files stop

if [ $cleanup -gt 0 ]; then
  clean_up
fi

echo " "

exit 0
