#!/usr/bin/env bash

if [[ $# != 2 ]]; then
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
    exit 1;
fi

export FNCS_LOG_LEVEL=DEBUG4
export FNCS_LOG_FILE="./${sim_id}_fncs_log.txt"
export FNCS_BROKER="tcp://*:${port_num}"
echo "Running fncs broker here: $FNCS_BROKER"

fncs_broker 2 2>&1 | tee "output/fncs_output.txt"