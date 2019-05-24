#!/usr/bin/env bash

docker exec -it gridappsddocker_gridappsd_1 pkill fncs_broker
docker exec -it gridappsddocker_gridappsd_1 pkill python
docker exec -it gridappsddocker_gridappsd_1 pkill bash
echo ""