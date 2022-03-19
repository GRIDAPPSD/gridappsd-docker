# gridappsd-docker

## Requirements
  - git
  - docker version 17.12 or higher
  - docker-compose version 1.16.1 or higher

## Docker and prerequisite install on OS X
 - git
    - OS X requires xcode
 ```
 xcode-select --install
 ```

## Clone or download the repository
```
  git clone https://github.com/GRIDAPPSD/gridappsd-docker
  cd gridappsd-docker
```

## Install Docker on Ubuntu
  - run the docker-ce installation script
 ```
 ./docker_install_ubuntu.sh
 ```
  - log out of your Ubuntu session and log back in to make the docker groups change active

## Start the docker container services
```
./run.sh
```
The run.sh does the folowing
 -  download the mysql dump file
 -  download the blazegraph data
 -  start the docker containers
 -  ingest the blazegraph data
 -  connect to the gridappsd container

## Start gridappsd

Now we are inside the executing container
```
root@737c30c82df7:/gridappsd# ./run-gridappsd.sh

```
Open your browser to http://localhost:8080/

[Using GridAPPS-D](https://gridappsd.readthedocs.io/en/master/using_gridappsd/index.html)

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

## Reconnecting to the gridappsd container

Reconnect to the running gridappsd container
```
user@foo>docker exec -it gridappsd bash

```

## Next Steps
  - Add applications/services to the containers (see how <https://github.com/GRIDAPPSD/gridappsd-sample-app>)

## Advanced Usage
### Using GridAPPS-D on a remote system with a local browser

## Start the docker container services
```
./run.sh -r
```

## Start gridappsd

Now we are inside the executing container
```
root@737c30c82df7:/gridappsd# ./run-gridappsd.sh

```

Open your browser to http://remoteip:8080/
