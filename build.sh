#!/bin/bash

docker build -t ompi-toy-box:latest -f Dockerfile.ssh .

docker build -t ompi-toy-box:cnt8 -f Dockerfile.ssh.cnt8 .

docker build -t ompi-toy-box:ubi8 -f Dockerfile.ssh.ubi8 .
