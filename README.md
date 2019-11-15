# PMIx Docker Swarm Toy Box

These instructions worked on Mac OSX Mojave (10.14.6) with Docker Desktop 2.1.0.4. They should work more generally, but you know how that goes.

This assumes that you are using 1 node (your laptop), and do not need to setup any virtual machines.


## One time setup

Initialize the swarm cluster

```
docker swarm init
```

## Build the Docker image

```
./build.sh
```

Example:
```
shell$ ./build.sh 
Sending build context to Docker daemon  12.04MB
Step 1/38 : FROM centos:7
 ---> 1e1148e4cc2c
Step 2/38 : MAINTAINER Josh Hursey <jhursey@us.ibm.com>
...
Successfully built 84d26427c5bf
Successfully tagged ompi-toy-box:latest
```

## Startup the cluster

This script will:
 * Create a private overlay network between the pods (`docker network create --driver overlay --attachable`)
 * Start N containers each named `$USER-nodeXY` where XY is the node number startig from `0`.

```
./start-n-containers.sh
```

Example:

```
shell$ ./start-n-containers.sh --help
Usage: start-n-containers.sh [option]
    -p | --prefix PREFIX       Prefix string for hostnames (Default: jhursey-)
    -n | --num NUM             Number of nodes to start on this host (Default: 2)
    -i | --image NAME          Name of the container image (Required)
    -d | --dryrun              Dry run. Do not actually start anything.
    -h | --help                Print this help message
shell$ ./start-n-containers.sh -n 5
Establish network: pmix-net
Starting: jhursey-node01
Starting: jhursey-node02
Starting: jhursey-node03
Starting: jhursey-node04
Starting: jhursey-node05
```

## Drop into the first node and get to work

I made a little script which is easier than remembering the CLI
```
./drop-in.sh 
```

```
shell$ ./drop-in.sh 
[mpiuser@jhursey-node01 /]$ whoami
mpiuser
[mpiuser@jhursey-node01 /]$ env | grep OMPI_MCA
OMPI_MCA_orte_default_hostfile=/opt/mpi/etc/hostfile.txt
[mpiuser@jhursey-node01 /]$ mpirun -npernode 2 hostname
jhursey-node01
jhursey-node01
jhursey-node04
jhursey-node04
jhursey-node03
jhursey-node03
jhursey-node05
jhursey-node05
jhursey-node02
jhursey-node02
```

## Shutdown the cluster

The script (above) creates a shutdown file that can be used to cleanup when you are done.

```
./tmp/shutdown-*.sh 
```