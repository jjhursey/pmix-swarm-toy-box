#!/usr/bin/env bash

# configuration variables
# can these be pulled from Docker?
CORES_PER_NODE=8

# processing host-file
cat ./tmp/hostfile.txt > host_file
echo "processing the provided hostfile "
echo "getting unique entries..."
awk '!a[$0]++' host_file > ./tmp/unique_hosts
echo "hosts:"
cat ./tmp/unique_hosts 

# generating slurm.conf dynamically
echo "copying initial slurm.conf work file"
cp -a ./bin/slurm-input/slurm.conf.in ./tmp/slurm.conf.initial
cp -a ./bin/slurm-input/slurm.conf.in ./tmp/slurm.conf.work
echo "setting up NodeName and PartitionName entries in slurm.conf ..."
rm ./tmp/hosts
HostNumber=1
while read h; do
	#echo "NodeName=$h NodeAddr=$h CPUs=${CORES_PER_NODE} State=UNKNOWN" >> ./tmp/slurm.conf.work
	#echo "NodeName=$h NodeAddr=$h CPUs=${CORES_PER_NODE} State=UNKNOWN" >> ./tmp/slurm.conf.work
	echo "NodeName=${USER}-node0${HostNumber} NodeAddr=$h CPUs=${CORES_PER_NODE} State=UNKNOWN" >> ./tmp/slurm.conf.work
	echo "$h	${USER}-node0${HostNumber}" >> ./tmp/hosts
	echo "${USER}-node0${HostNumber}" >> ./tmp/nodes
	((HostNumber++))
done <./tmp/unique_hosts
#Nodes=`sed "N;s/\n/,/" ./tmp/nodes`
Nodes=`cat ./tmp/nodes | paste -sd "," -`
echo "PartitionName=local Nodes=${Nodes} Default=YES MaxTime=INFINITE State=UP" >> ./tmp/slurm.conf.work

FirstNodeName="${USER}-node01"
FirstNode=`head -n 1 ./tmp/unique_hosts`
echo "ControlMachine=${FirstNodeName}" >> ./tmp/slurm.conf.work
echo "ControlAddr=${FirstNode}" >> ./tmp/slurm.conf.work
mkdir -p ./install/slurm/etc/
cp -a ./tmp/slurm.conf.work ./install/slurm/etc/slurm.conf
cp -a ./tmp/unique_hosts ./install/slurm/etc/unique_hosts
cp -a ./tmp/hosts ./install/slurm/etc/hosts

exit 0
