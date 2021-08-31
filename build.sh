#!/bin/bash

if [ -z "$1" ]
  then
    echo "Bulding with Dockerfile.ssh ..."
    docker build -t ompi-toy-box:latest -f Dockerfile.ssh .
else 
    echo "Bulding with Dockerfile.$1 ..."
    docker build -t ompi-toy-box:latest -f Dockerfile.$1 .
fi


