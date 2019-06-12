#!/bin/bash

grep -H "option \"transport:hostname*" /tmp/gridappsd_tmp/*/model_startup.glm  | awk -F"/" '{print $4, $NF}' 
#find /tmp/gridappsd_tmp -name "option \"transport:hostname*"
#ls -la /tmp/gridappsd_tmp


