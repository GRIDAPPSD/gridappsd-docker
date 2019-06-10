#!/usr/bin/env bash

if [[ $# != 1 ]]; then
    echo "
ERROR
Invalid number of parameters.
simulation_id
";
    echo ""
    echo "Press enter to exit terminal"
    read
    exit 1;
fi

sim_id=$1

# CD to where this source is running from because
# we should have write permissions to this space.
cd "$( dirname "${BASH_SOURCE[0]}" )"

mkdir -p "output"

cd /tmp/gridappsd_tmp/${sim_id}

echo "Running gridlabd here"
gridlabd.sh "model_startup.glm" 2>&1 | tee "/gridappsd/debug-scripts/output/gridlabd_out.txt"
