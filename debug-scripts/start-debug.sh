#!/bin/bash

sim_id=$1
port_num=$2
run_realtime=$3
duration=$4
gridappsd_tmp="/tmp/gridappsd_tmp/${sim_id}"

if [[ ! -d ${gridappsd_tmp} ]]; then
    echo "Invalid simulation id";
    ls -la "/tmp/gridappsd_tmp"
    exit 0;
fi

export FNCS_LOG_LEVEL=DEBUG4
export FNCS_LOG_FILE="./${sim_id}_fncs_log.txt"
export FNCS_BROKER="tcp://*:${port_num}"
echo $FNCS_BROKER
fncs_broker 2 &>"./fncs_std_out_err.txt" &
cd /tmp/gridappsd_tmp/${sim_id}
gridlabd.sh "model_startup.glm" &>"/gridappsd/debug-scripts/gridlabd_std_out_err.txt" &
cd /gridappsd/services/fncsgossbridge/service
python fncs_goss_bridge.py ${sim_id} "tcp://127.0.0.1:${port_num}" "/tmp/gridappsd_tmp/${sim_id}/" "{\"simulation_config\":{\"run_realtime\":${run_realtime},\"duration\":${duration}}}" &>"/gridappsd/debug-scripts/fncsgossbridge_std_out_err.txt" &
while [ 0 ]; do 
  sleep 1;
done
echo "I am here";

