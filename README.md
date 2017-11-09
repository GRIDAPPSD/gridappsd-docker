# gridappsd-docker

## Start the docker container services

    ./run.sh

The run.sh does the folowing
 -  download the mysql dump file
 -  download the blazegraph data
 -  download the applications
 -  download the services
 -  start the docker containers
 -  ingest the blazegraph data
 -  open a web browser to the viz container http://localhost:8080


## Close and remove the containers

    docker-compose down
