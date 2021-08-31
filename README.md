# PMIx Docker Swarm Toy Box

These instructions worked on Mac OSX Mojave (10.14.6) with Docker Desktop 2.1.0.4. They should work more generally, but you know how that goes.

This assumes that you are using 1 node (your laptop), and do not need to setup any virtual machines.


## One time setup

Follow the Docker installation instructions, at:
https://docs.docker.com/engine/install/ubuntu/

It is recommended to use your own regular user, and not root.  Make sure to add your user to the docker group, as stated in the installation instructions:

```
usermod -aG docker <user>
```

Initialize the swarm cluster:

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
Bulding with Dockerfile.ssh ...
Sending build context to Docker daemon  12.04MB
Step 1/38 : FROM centos:7
 ---> 1e1148e4cc2c
Step 2/38 : MAINTAINER Josh Hursey <jhursey@us.ibm.com>
...
Successfully built 84d26427c5bf
Successfully tagged ompi-toy-box:latest
```

The Slurm specific Dockerfile.slurm can be selected for the build:

```
shell$ ./build.sh slurm 
Bulding with Dockerfile.slurm ...
...
```

For customized build, simply make a copy of one of the Dockerfiles and give it a custom extension.  For example, you can start from the Dockerfile.slurm, by making a copy and renaming it:

```
cp -a Dockerfile.slurm Dockerfile.foo
```

You can then update the file, and produce a custom build:

```
shell$ ./build.sh foo 
Bulding with Dockerfile.foo ...
...
```

## Setup your development environment outside the container

The container is self contained with all of the necessary software to build/run OpenPMIx/PRRTE/Open MPI from what was built inside.
However, for a developer you often want to use your version of these builds and use the editor from the host system.

We will use volume mounts to make a developer workflow function by overwriting the in-container version with the outside-container version of the files. We are using the local disk as a shared file system between the virtual nodes.

The key to making this work is that you can edit the source code outside of the container, but all builds must occur inside the container. This is because the relative paths to dependent libraries and install directories are relative to the paths inside the container's file system not the host file system.

Note that this will work when using Docker Swarm on a single machine. More work is needed if you are running across multiple physical machines.


### Checkout your version of OpenPMIx/PRRTE/Open MPI

For ease of use I'll checkout into a `build` subdirectory within this directory (`$TOPDIR` is the same locaiton as this `README.md` file), but these source directories can be located anywhere on your system as long as they are in the same directory. We will mount this directory over the top of `/opt/hpc/build` inside the container. The sub-directory names for the git checkouts can be whatever you want - we will just use the defaults for the examples here.

Setup the build directory.

```
cd $TOPDIR
mkdir -p build
cd build
```

Check out your OpenPMIx development branch (on your local file system, outside the container).

```
git clone git@github.com:openpmix/openpmix.git
```

Check out your PRRTE development branch (on your local file system, outside the container).

```
git clone git@github.com:openpmix/prrte.git
```

Check out your Open MPI development branch (on your local file system, outside the container).
Note: You can skip the Open MPI parts if you do not intend to use it

```
git clone git@github.com:open-mpi/ompi.git
```


### Create an install directory for OpenPMIx/PRRTE/Open MPI

This directory will serve as the shared install file system for the builds. We will mount this directory over the top of `/opt/hpc/external` inside the container. The container's environment is setup to look for these installs at specific paths so though you can build with whatever options your want, the `--prefix` shouldn't be changed:
 * OpenPMIx: `--prefix /opt/hpc/external/pmix`
 * PRRTE: `--prefix /opt/hpc/external/prrte`
 * Open MPI: `--prefix /opt/hpc/external/ompi`

```
cd $TOPDIR
mkdir -p install
```

For now it will be empty. We will fill it in with the build once we have the cluster started.


## Startup the cluster

This script will:
 * Create a private overlay network between the pods (`docker network create --driver overlay --attachable`)
 * Start N containers each named `$USER-nodeXY` where XY is the node number startig from `01`.


### To start with the internal versions of OpenPMIx/PRRTE/Open MPI 
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
         --install DIR         Full path to the 'install' directory
         --build DIR           Full path to the 'build' directory
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

### To start with the external/developer versions of OpenPMIx/PRRTE/Open MPI 

```
./start-n-containers.sh --install $PWD/install --build $PWD/build
```

Example:

```
shell$ ./start-n-containers.sh -n 5 --install $PWD/install --build $PWD/build
Establish network: pmix-net
Starting: jhursey-node01
Starting: jhursey-node02
Starting: jhursey-node03
Starting: jhursey-node04
Starting: jhursey-node05
```


## Drop into the first node

I made a little script which is easier than remembering the CLI
```
./drop-in.sh 
```

If you did not specify `--install $PWD/install --build $PWD/build` then you can run with the built in versions.


## (Developer) Verify the volume mounts

if you did specify `--install $PWD/install --build $PWD/build` then you can verify that the volumes were mounted in as the `mpiuser` in `/opt/hpc` directory.
 * Source/Build directory: `/opt/hpc/build`
 * Install directory: `/opt/hpc/external`

```
shell$ ./drop-in.sh 
[mpiuser@jhursey-node01 ~]$ whoami
mpiuser
[mpiuser@jhursey-node01 ~]$ ls -la /opt/hpc/
total 20
drwxr-xr-x 1 root    root    4096 Dec 21 14:54 .
drwxr-xr-x 1 root    root    4096 Dec 21 14:10 ..
drwxr-xr-x 8 mpiuser mpiuser  256 Dec 21 14:58 build
drwxrwxrwx 1 root    root    4096 Dec 21 14:54 etc
drwxrwxrwx 1 root    root    4096 Dec 21 14:25 examples
drwxr-xr-x 3 mpiuser mpiuser   96 Dec 21 14:59 external
drwxr-xr-x 1 root    root    4096 Dec 21 14:25 local
[mpiuser@jhursey-node01 ~]$ ls -la /opt/hpc/build/   
total 16
drwxr-xr-x  8 mpiuser mpiuser  256 Dec 21 14:58 .
drwxr-xr-x  1 root    root    4096 Dec 21 14:54 ..
drwxr-xr-x 27 mpiuser mpiuser  864 Dec 21 14:34 ompi
drwxr-xr-x 37 mpiuser mpiuser 1184 Dec 21 14:59 openpmix
drwxr-xr-x 22 mpiuser mpiuser  704 Dec 21 14:34 prrte
```

## Compile your code inside the first node

Edit your code on the host file system as normal. The changes to the files are immediately reflected inside all of the swarm containers.

When you are ready to compile drop into the container, change to the source directory, and build as normal.

Note: I created build scripts for OpenPMIx/PRRTE/Open MPI in `$TOPDIR/bin` that you can use. Just copy them into the `build` directory so they are visible inside the container.

```
shell$ cp -R bin build/
shell$ ./drop-in.sh 
[mpiuser@jhursey-node01 ~]$ whoami
mpiuser
[mpiuser@jhursey-node01 ~]$ cd /opt/hpc/build/openpmix
[mpiuser@jhursey-node01 openpmix]$ ../bin/build-openpmix.sh 
...
[mpiuser@jhursey-node01 openpmix]$ ../bin/build-prrte.sh 
...
```

The build and install directories are preserved on the host file system so you do not necessarily need to do a full rebuild everytime - just the first time.


## Run your code inside the first node

```
shell$ ./drop-in.sh 
[mpiuser@jhursey-node01 ~]$ whoami
mpiuser
[mpiuser@jhursey-node01 /]$ env | grep MCA
PRRTE_MCA_prrte_default_hostfile=/opt/hpc/etc/hostfile.txt
[mpiuser@jhursey-node01 build]$ mpirun -npernode 2 hostname
[jhursey-node01:94589] FINAL CMD: prte &
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
TERMINATING DVM...DONE
```

## Shutdown the cluster

The script (above) creates a shutdown file that can be used to cleanup when you are done.

```
./tmp/shutdown-*.sh 
```

## Setting up and bootstrapping Slurm 

Similarly to the other tools discussed above, first place the source code of Slurm under the build/ directory:

```
cd $TOPDIR/build
git clone git@github.com:SchedMD/slurm.git
```

Make sure that the Docker cluster has been started with the _start-n-containers.sh_ script as documented above.  A Slurm configuration template and a generator script is provided. These scripts depend on the node information produced by the _start-n-containers.sh_ script.  The _slurm.conf_ file needs to be generated at the host by the normal user (not root), before dropping into the first node:

```
shell$ cd $TOPDIR
shell$ ./start-n-containers.sh --install $PWD/install --build $PWD/build -n 4
Establish network: pmix-net
Starting: compres-node01
Starting: compres-node02
Starting: compres-node03
Starting: compres-node04
shell$ ./bin/generate-slurm-conf.sh
processing the provided hostfile 
getting unique entries...
hosts:
10.0.15.2
10.0.15.4
10.0.15.5
10.0.15.6
copying initial slurm.conf work file
setting up NodeName and PartitionName entries in slurm.conf ...
```

At this point, the cluster has been initialized, and a configuration for Slurm generated dynamically based on the host information.

We can continue by dropping into the first node, becoming root, and builing Slurm:

```
shell$ ./drop-in.sh
mpiuser@user-node01$ sudo su
root@user-node01$
```

Move to the slurm/ directory and use the provided script to build it.  Please note that Slurm depend on *Mumge*, *hwloc* and *Open PMIx*.  Munge and hwloc are built into the image with the provided Dockerfile.slurm file; however, we recommend that you build the Open PMIx library in the build/ directory.  Please refer to the intructions above.

```
root@user-node01$ cd /opt/hpc/build/slurm
root@user-node01$ ../bin/build-slurm.sh
```

Once Slurm is built and installed, you need to bootstrap the munged and slurmd daemons in all nodes.  The slurmctld daemon needs to be started in the first node only.  For this task, a bootstrap script is provided.  The bootstrap script needs to be run as the *root* user:

```
root@user-node01$ /opt/hpc/build/bin/bootstrap-slurm.sh
starting munged in host 10.0.15.2
starting munged in host 10.0.15.4
starting munged in host 10.0.15.5
starting munged in host 10.0.15.6
starting slurmd in host 10.0.15.2
starting slurmd in host 10.0.15.4
starting slurmd in host 10.0.15.5
starting slurmd in host 10.0.15.6
starting the controller...

```

At this point, it is recommended to become the *mpiuser* to run or queue jobs in the cluster.  

If the cluster is restarted, the Slurm configuration needs to be regenerated, and the daemons need to be bootstrapped again.  Docker will assign different IPs to the hosts, every time they are launched.

