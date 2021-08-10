#!/usr/bin/env bash

MUNGE_INSTALL_DIR=/opt/hpc/local/munge
SLURM_INSTALL_DIR=/opt/hpc/external/slurm

while read h; do
	ssh $h "${MUNGE_INSTALL_DIR}/sbin/munged -Ff > munge_remote_daemon_out 2>&1" &
done </opt/hpc/external/slurm/etc/unique_hosts

# make sure the munged daemons have started before we begin starting the slurmds
sleep 2

while read h; do
	ssh $h "${SLURM_INSTALL_DIR}/sbin/slurmd -Dc > slurm_remote_daemon_out 2>&1" &
done </opt/hpc/external/slurm/etc/unique_hosts

echo "starting the controller..."
${SLURM_INSTALL_DIR}/sbin/slurmctld -Dcvvvv > slurm_controller_out 2>&1 &
sleep 5

