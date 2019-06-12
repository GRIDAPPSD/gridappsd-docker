#!/bin/bash


if [[ $# != 4 ]]; then
    echo "
ERROR
Invalid number of parameters.
simulation_id port_num run_realtime duration
";
    exit 1;
fi

sim_id=$1
port_num=$2
run_realtime=$3
duration=$4

echo "Starting fncs"
x-terminal-emulator -e "docker exec -it gridappsddocker_gridappsd_1 /gridappsd/debug-scripts/run-fncs.sh ${sim_id} ${port_num}"
sleep 2
echo "Starting gridlabd"
x-terminal-emulator -e "docker exec -it gridappsddocker_gridappsd_1 /gridappsd/debug-scripts/run-gridlabd.sh ${sim_id}"
sleep 2
echo "starting fncsbridge"
x-terminal-emulator -e "docker exec -it gridappsddocker_gridappsd_1 /gridappsd/debug-scripts/run-fncsbridge.sh ${sim_id} ${port_num} ${run_realtime} ${duration}"
sleep 2
echo "starting goss_sender"
x-terminal-emulator -e "docker exec -it gridappsddocker_gridappsd_1 /gridappsd/debug-scripts/run-goss_sender.sh ${sim_id}"
