import argparse
import json
import logging
import sys
import time

from gridappsd import GridAPPSD, DifferenceBuilder, utils
from gridappsd.topics import fncs_input_topic, fncs_output_topic


def _main():
    parser = argparse.ArgumentParser()
    parser.add_argument("simulation_id",
                        help="Simulation id to use for responses on the message bus.")
    opts = parser.parse_args()
    gapps = GridAPPSD(opts.simulation_id, address=utils.get_gridappsd_address(),
                      username=utils.get_gridappsd_user(), password=utils.get_gridappsd_pass())
    x = input("Press Enter to continue...")
    message = {'command' : 'StartSimulation'}
    print(fncs_input_topic(opts.simulation_id))
    print(json.dumps(message))
    gapps.send(fncs_input_topic(opts.simulation_id), json.dumps(message))
    while True:
        sleep(0.1)


if __name__ == "__main__":
    _main()
