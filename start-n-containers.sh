#!/bin/bash

#
# Default values
#
IMAGE_NAME=ompi-toy-box:latest
OVERLAY_NETWORK=pmix-net
NNODES=2
INSTALL_DIR=
BUILD_DIR=

COMMON_PREFIX=$USER"-"

MPI_HOSTFILE=$PWD/tmp/hostfile.txt
SHUTDOWN_FILE=$PWD/tmp/shutdown-`hostname -s`.sh

DRYRUN=0

#
# Argument parsing
#
while [[ $# -gt 0 ]] ; do
    case $1 in
        "-h" | "--help")
            printf "Usage: %s [option]
    -p | --prefix PREFIX       Prefix string for hostnames (Default: %s)
    -n | --num NUM             Number of nodes to start on this host (Default: %s)
    -i | --image NAME          Name of the container image (Required)
         --install DIR         Full path to the 'install' directory
         --build DIR           Full path to the 'build' directory
    -d | --dryrun              Dry run. Do not actually start anything.
    -h | --help                Print this help message\n" \
        `basename $0` $COMMON_PREFIX $NNODES
            exit 0
            ;;
        "-p" | "--prefix")
            shift
            COMMON_PREFIX=$1
            ;;
        "-n" | "--num")
            shift
            NNODES=$1
            ;;
        "-i" | "--image" | "-img")
            shift
            IMAGE_NAME=$1
            ;;
        "--install")
            shift
            INSTALL_DIR=$1
            ;;
        "--build")
            shift
            BUILD_DIR=$1
            ;;
        "-d" | "--dryrun")
            DRYRUN=1
            ;;
        *)
            printf "Unkonwn option: %s\n" $1
            exit 1
            ;;
    esac
    shift
done

if [ "x$IMAGE_NAME" == "x" ] ; then
    echo "Error: --image must be specified"
    exit 1
fi

#
# Spin up all of the containers
#

ALL_CONTAINERS=()

startup_container()
{
    C_ID=$(($1 + 0))
    C_HOSTNAME=`printf "%s%s%02d" $COMMON_PREFIX "node" $C_ID`

    if [ 0 != $DRYRUN ] ; then
        echo ""
        echo "Starting: $C_HOSTNAME"
        echo "---------------------"
    else
        echo "Starting: $C_HOSTNAME"
    fi

    # Add other volume mounts here
    _OTHER_ARGS=""

    if [ "x" != "x$BUILD_DIR" ] ; then
        _OTHER_ARGS+=" -v $BUILD_DIR:/opt/hpc/build"
    fi
    if [ "x" != "x$INSTALL_DIR" ] ; then
        _OTHER_ARGS+=" -v $INSTALL_DIR:/opt/hpc/external"
    fi

    CMD="docker run --rm \
        --cap-add=SYS_NICE --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        -v $MPI_HOSTFILE:/opt/hpc/etc/hostfile.txt:ro \
        $_OTHER_ARGS \
        --network $OVERLAY_NETWORK \
        -h $C_HOSTNAME --name $C_HOSTNAME \
        --detach $IMAGE_NAME"
    if [ 0 != $DRYRUN ] ; then
        echo $CMD
        return
    fi

    C_FULL_ID=`$CMD`
    RTN=$?
    if [ 0 != $RTN ] ; then
        echo "Error: Failed to create $C_HOSTNAME"
        echo $C_FULL_ID
        exit 1
    fi

    C_SHORT_ID=`echo $C_FULL_ID | cut -c -12`
    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $C_SHORT_ID >> $MPI_HOSTFILE
    ALL_CONTAINERS+=($C_SHORT_ID)
}

mkdir -p tmp
if [ 0 == $DRYRUN ] ; then
    rm -f $MPI_HOSTFILE
    touch $MPI_HOSTFILE
fi

# Create network
CMD="docker network create --driver overlay --attachable $OVERLAY_NETWORK"
if [ 0 == $DRYRUN ] ; then
    echo "Establish network: $OVERLAY_NETWORK"
    RTN=`$CMD`
else
    echo ""
    echo "Establish network: $OVERLAY_NETWORK"
    echo "---------------------"
    echo $CMD
fi

# Create each virtual node
for i in $(seq 1 $NNODES); do
    startup_container $i
done

if [ 0 != $DRYRUN ] ; then
    exit 0
fi

#
# Create a shutdown file to help when we cleanup
rm -f $SHUTDOWN_FILE

touch $SHUTDOWN_FILE
chmod +x $SHUTDOWN_FILE
for cid in "${ALL_CONTAINERS[@]}" ; do
    echo "docker stop $cid" >> $SHUTDOWN_FILE
done

CMD="docker network rm $OVERLAY_NETWORK"
if [ 0 == $DRYRUN ] ; then
    echo $CMD >> $SHUTDOWN_FILE
else
    echo ""
    echo "Remove network: $OVERLAY_NETWORK"
    echo "---------------------"
    echo $CMD
fi
