#!/usr/bin/env bash

if [[ $# != 4 ]]; then
    echo "
ERROR
Invalid number of parameters.
simulation_id port_num
";
    echo ""
    echo "Press enter to exit terminal"
    read
    exit 1;
fi

sim_id=$1
port_num=$2
run_realtime=$3
duration=$4

# CD to where this source is running from because
# we should have write permissions to this space.
cd "$( dirname "${BASH_SOURCE[0]}" )"

mkdir -p "output"

sim_id=$1
port_num=$2

gridappsd_tmp="/tmp/gridappsd_tmp/${sim_id}"

if [[ ! -d ${gridappsd_tmp} ]]; then
    echo "Invalid simulation id";
    ls -la "/tmp/gridappsd_tmp"
    echo "Press enter to exit"
    read
    exit 1;
fi

export FNCS_LOG_LEVEL=DEBUG1
export FNCS_LOG_FILE="/gridappsd/debug-scripts/output/${sim_id}_fncs_log.txt"
#export FNCS_BROKER="tcp://*:${port_num}"
#echo $FNCS_BROKER
cd /gridappsd/services/fncsgossbridge/service
python fncs_goss_bridge.py ${sim_id} "tcp://127.0.0.1:${port_num}" "/tmp/gridappsd_tmp/${sim_id}/" "{\"simulation_config\":{\"run_realtime\":${run_realtime},\"duration\":${duration}}}" 2>&1 | tee "/gridappsd/debug-scripts/output/fncsgossbridge_out.txt"


