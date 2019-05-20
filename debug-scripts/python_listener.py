import argparse
import json
from fncs import fncs

class PythonListener(object):
    def __init__(self, broker_port, sim_id, sim_length):
        self.broker_location = "tcp://localhost:{}".format(broker_port)
        self.subscription_topic = "{}/fncs_output".format(sim_id)
        self.sim_length = int(sim_length)
        self.sim_id = str(sim_id)


    def register_with_fncs(self):
        fncs_configuration = {
            "name" : "PythonListener{}".format(self.sim_id),
            "time_delta" : "1s",
            "broker" : self.broker_location,
            "values" : {
                "{}".format(self.sim_id) : {
                    "topic" : self.subscription_topic,
                    "default" : "{}",
                    "type" : "JSON",
                    "list" : "false"
                }
            }
        }
        configuration_zpl = ('name = {0}\n'.format(fncs_configuration['name'])
            + 'time_delta = {0}\n'.format(fncs_configuration['time_delta'])
            + 'broker = {0}\nvalues'.format(fncs_configuration['broker']))
        for x in fncs_configuration['values'].keys():
            configuration_zpl += '\n    {0}'.format(x)
            configuration_zpl += '\n        topic = {0}'.format(
                fncs_configuration['values'][x]['topic'])
            configuration_zpl += '\n        default = {0}'.format(
                fncs_configuration['values'][x]['default'])
            configuration_zpl += '\n        type = {0}'.format(
                fncs_configuration['values'][x]['type'])
            configuration_zpl += '\n        list = {0}'.format(
                fncs_configuration['values'][x]['list'])
        try:
            fncs.initialize(configuration_zpl)
            if not fncs.is_initialized():
                raise RuntimeError("fncs.initialize(configuration_zpl) failed!\nconfiguration_zpl = {}".format(configuration_zpl))
        except Exception as e:
            if fncs.is_initialized():
                fncs.die()
            raise


    def run_simulation(self):
        try:
            current_time = 0
            while current_time <= self.sim_length:
                sim_message_topics = fncs.get_events()
                if self.sim_id in sim_message_topics:
                    message = fncs.get_value(self.sim_id)
                time_request = current_time + 1
                if time_request > self.sim_length:
                    fncs.finalize()
                    break
                time_approved = fncs.time_request(time_request)
                if time_approved != time_request:
                    raise RuntimeError("The time approved from the fncs broker is not the time requested.\ntime_request = {}.\ntime_approved = {}".format(time_request, time_approved))
                current_time += 1
        except Exception as e:
            if fncs.is_initialized():
                fncs.die()
            raise


def get_opts():
    parser = argparse.ArgumentParser()
    parser.add_argument("broker_port", help="The port location for the FNCS broker.")
    parser.add_argument("simulation_id", help="The simulation id.")
    parser.add_argument("simulation_duration", help="The simulation runtime lenght.")
    opts = parser.parse_args()
    return opts


def main(broker_port, simulation_id, simulation_duration):
    listener = PythonListener(broker_port, simulation_id, simulation_duration)
    listener.register_with_fncs()
    listener.run_simulation()


if __name__ == "__main__":
    opts = get_opts()
    port = opts.broker_port
    sim_id = opts.simulation_id
    duration = opts.simulation_duration
    main(port, sim_id, duration)
