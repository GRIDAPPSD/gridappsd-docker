# gridappsd-docker

## Requirements

## Docker and prerequisite install on OS X
 - git
    - OS X requires xcode
 ```
 xcode-select --install
 ```
  - docker version 1.09.0 or higher
  - docker-compose version 1.16.1 or higher
## Docker and prerequisite install on Ubuntu
 - git
 - docker-ce 
        - Based on instructions from https://docs.docker.com/install/linux/docker-ce/ubuntu/#set-up-the-repository
        ```
         sudo apt-get update
         
         sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
         
         curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
         
         sudo apt-key fingerprint 0EBFCD88
         
         sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
         
         sudo apt-get update
         
         sudo apt-get install docker-ce

         sudo usermod -a -G docker $USER
        ```
   - docker-compose   
     - Based on instructions from https://docs.docker.com/compose/install/
      ```
        sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
        sudo chmod a+x /usr/local/bin/docker-compose
      ```

## Clone or download the repository
```
  git clone https://github.com/GRIDAPPSD/gridappsd-docker
  cd gridappsd-docker
```

## Start the docker container services
```
./run.sh
```
The run.sh does the folowing
 -  download the mysql dump file
 -  download the blazegraph data
 -  download the applications
 -  download the services
 -  start the docker containers
 -  ingest the blazegraph data

## Start gridappsd

Connect to the running gridappsd container
```
user@foo>docker exec -it gridappsddocker_gridappsd_1 bash

```
Now we are inside the executing container
```
root@737c30c82df7:/gridappsd# ./gridappsd.run.sh

```
Open your browser to http://localhost:8080/ieee8500

Click the triangle in the top right corner to have a simulation run.

## Exiting the container and stopping the containers

```
Use Ctrl+C to stop gridappsd from running
exit
./stop.sh
```

## Restarting the containers
```
./run.sh
```

## Future enhancements    
  -  open a web browser to the viz container http://localhost:8080
