#!/bin/bash

docker exec -it -u mpiuser -w  /home/mpiuser/ --env COLUMNS=`tput cols` --env LINES=`tput lines` $USER-node01 bash
