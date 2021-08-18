#!/bin/bash -xe

# we don't run autogen in Slurm
# Slurm code is distributed with pre-generated autotools based buildsystem

./configure --prefix=${SLURM_ROOT} \
            --with-hwloc=${HWLOC_INSTALL_PATH} \
            --with-munge=${MUNGE_INSTALL_PATH} \
            --with-pmix=${PMIX_ROOT} \
            --enable-silent-rules \
            2>&1 | tee configure.log.$$ 2>&1
make -j 10 2>&1 | tee make.log.$$ 2>&1
make -j 10 install 2>&1 | tee make.install.log.$$
