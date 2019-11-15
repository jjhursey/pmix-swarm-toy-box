#!/bin/bash

docker exec -it -u mpiuser --env COLUMNS=`tput cols` --env LINES=`tput lines` $USER-node01 bash
