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

cd /gridappsd/debug-scripts
python3 goss_sender.py ${sim_id}
