# Multi terminal debugging

This folder (debug-scripts) provides a way to start the individual components of gridappsd in 
seperate terminals to allow debugging almost independently of the maing goss process.  In order
for this to work there are several steps that must be completed.

1. Modify docker-compose.yml file to mount this directory in the container at
   /gridappsd/debug-scripts.  Do this by uncomment the following 2 lines:
   ````yaml
   #    volumes:
   #      - ./debug-scripts:/gridappsd/debug-scripts
   ````
   by removing the # in front of them so that it looks like 
   ````yaml
       volumes:
         - ./debug-scripts:/gridappsd/debug-scripts
   ````
2. In order for you to run a simulation from the debug scripts you must first have run a simulation
   within the platform.  Do that before continuing.
3. Open a second command window into the running gridappsd container by using the provided 
   gridappsd-shell.sh script from the root of this repository.
4. cd into /gridappsd/debug-scripts
5. execute list-simulations.sh to discover the simulation id and port.
6. edit the runit.sh script and modify the parameters you want to use
7. cd to /gridappsd and start the platform by executing ./run-gridappsd.sh
8. open a terminal outside the docker container.
9. run the modified runit.sh script

After following the above directions you should have 3 different terminals with the 3 different 
applications running in them.  To stop them use the ./stop-debug.sh script from the terminal outside
of the docker container itself.

**Note the different processes have their standard out and standard error teed to the output folder** 
**inside the debug-scripts directory**