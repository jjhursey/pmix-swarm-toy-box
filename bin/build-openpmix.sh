#!/bin/bash -xe

./autogen.pl
./configure --prefix=${PMIX_ROOT} \
            --with-hwloc=${HWLOC_INSTALL_PATH} \
            --with-libevent=${LIBEVENT_INSTALL_PATH} \
            2>&1 | tee configure.log.$$ 2>&1
make -j 10 2>&1 | tee make.log.$$ 2>&1
make -j 10 install 2>&1 | tee make.install.log.$$
