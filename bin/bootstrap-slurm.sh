#!/usr/bin/env bash

MUNGE_INSTALL_DIR=/opt/hpc/local/munge
SLURM_INSTALL_DIR=/opt/hpc/external/slurm

while read h; do
	echo "starting munged in host $h"
	ssh $h "${MUNGE_INSTALL_DIR}/sbin/munged" &
done </opt/hpc/external/slurm/etc/unique_hosts

# make sure the munged daemons have started before we begin starting the slurmds
sleep 2

while read h; do
	echo "starting slurmd in host $h"
	ssh $h "${SLURM_INSTALL_DIR}/sbin/slurmd" &
done </opt/hpc/external/slurm/etc/unique_hosts

echo "starting the controller..."
#${SLURM_INSTALL_DIR}/sbin/slurmctld -Dcvvvv > slurm_controller_out 2>&1 &
${SLURM_INSTALL_DIR}/sbin/slurmctld
sleep 5

