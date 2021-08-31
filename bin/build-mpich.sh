#!/bin/bash -xe

./autogen.sh
./configure --prefix=${MPICH_ROOT} \
            --with-hwloc=${HWLOC_INSTALL_PATH} \
            --with-pm=no \
            --with-pmi=pmix \
            --with-pmix=${PMIX_ROOT} \
            --with-slurm=${SLURM_ROOT} \
            --with-device=ch4:ofi \
            2>&1 | tee configure.log.$$ 2>&1
make -j 10 2>&1 | tee make.log.$$ 2>&1
make -j 10 install 2>&1 | tee make.install.log.$$
