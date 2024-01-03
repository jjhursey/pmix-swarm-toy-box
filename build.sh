#!/bin/bash

if [ -z "$1" ]
  then
    echo "Bulding with Dockerfile.ssh ..."
    docker build -t ompi-toy-box:latest -f Dockerfile.ssh .
elif [ "$1" = "all" ]
  then
    docker build -t ompi-toy-box:latest -f Dockerfile.ssh .
    docker build -t ompi-toy-box:slurm -f Dockerfile.slurm .
else
    echo "Bulding with Dockerfile.$1 ..."
    docker build -t ompi-toy-box:$1 -f Dockerfile.$1 .
fi


