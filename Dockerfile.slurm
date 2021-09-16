#
# Base Build box for Slurm
#
# Requires:
#  - Basic compile tooling and runtime support
#  - libevent
#  - hwloc 2.x
#  - munge
#
# Directory structure for volume mounting
# - Build directory to mount in the source from the local file system
#   /opt/hpc/local/build/
# - Install directory to mount in an installation directory to be shared between containers
#   /opt/hpc/external/{pmix,prrte,ompi}
#
FROM centos:7

MAINTAINER Josh Hursey <jhursey@us.ibm.com>
MAINTAINER Isaias A. Compres U. <isaias.compres@tum.de>

# ------------------------------------------------------------
# Install required packages
# ------------------------------------------------------------
RUN yum -y update && \
    yum -y install \
    openssh-server openssh-clients \
    gcc gcc-gfortran gcc-c++ gdb strace \
    binutils less wget which sudo \
    perl perl-Data-Dumper numactl \
    autoconf automake libtool flex bison python3 \
    iproute net-tools hwloc make git \
    libnl3 gtk2 atk cairo tcl tcsh tk pciutils lsof ethtool bc file \
    psmisc valgrind openssl-devel libfabric zlib zlib-devel && \
    yum -y install epel-release && \
    yum -y install pandoc --enablerepo=epel && \
    yum clean all

# ------------------------------------------------------------
# Define support libraries
# - hwloc
# - libevent
# - munge
# ------------------------------------------------------------
RUN mkdir -p /opt/hpc/local/build
COPY src /opt/hpc/local/src

ARG LIBEVENT_INSTALL_PATH=/opt/hpc/local/libevent
ENV LIBEVENT_INSTALL_PATH=$LIBEVENT_INSTALL_PATH
ARG HWLOC_INSTALL_PATH=/opt/hpc/local/hwloc
ENV HWLOC_INSTALL_PATH=$HWLOC_INSTALL_PATH
ARG MUNGE_INSTALL_PATH=/opt/hpc/local/munge
ENV MUNGE_INSTALL_PATH=$MUNGE_INSTALL_PATH

RUN cd /opt/hpc/local/build && \
    tar -zxf ../src/libevent* && \
    cd libevent-* && \
    ./configure --prefix=${LIBEVENT_INSTALL_PATH} > /dev/null && \
    make > /dev/null && \
    make install > /dev/null
RUN cd /opt/hpc/local/build && \
    tar -zxf ../src/hwloc-2* && \
    cd hwloc-2* && \
    ./configure --prefix=${HWLOC_INSTALL_PATH} > /dev/null && \
    make > /dev/null && \
    make install > /dev/null 
RUN cd /opt/hpc/local/build && \
    tar -xf ../src/munge-* && \
    cd munge-* && \
    ./configure --prefix=${MUNGE_INSTALL_PATH} > /dev/null && \
    make > /dev/null && \
    make install > /dev/null && \
    cd .. && \
    rm -rf /opt/hpc/local/src /opt/hpc/local/build/*
ENV LD_LIBRARY_PATH="$HWLOC_INSTALL_PATH/bin:$LIBEVENT_INSTALL_PATH/lib:$MUNGE_INSTALL_PATH/lib:${LD_LIBRARY_PATH}"


# -----------------------------
# Allow forced rebuild from this point
# -----------------------------
COPY .build-timestamp /root/

# ------------------------------------------------------------
# PMIx Environment
# ------------------------------------------------------------
ENV PMIX_ROOT=/opt/hpc/external/pmix
ENV LD_LIBRARY_PATH="$PMIX_ROOT/lib:${LD_LIBRARY_PATH}"

# ------------------------------------------------------------
# PRRTE Environment
# ------------------------------------------------------------
ENV PRRTE_ROOT=/opt/hpc/external/prrte
ENV PATH="$PRRTE_ROOT/bin:${PATH}"
ENV LD_LIBRARY_PATH="$PRRTE_ROOT/lib:${LD_LIBRARY_PATH}"

# ------------------------------------------------------------
# Open MPI Environment
# ------------------------------------------------------------
ENV MPI_ROOT=/opt/hpc/external/ompi

ENV PATH="$MPI_ROOT/bin:${PATH}"
ENV LD_LIBRARY_PATH="$MPI_ROOT/lib:${LD_LIBRARY_PATH}"

ARG _BUILD_OMPI_VERSION=4.0.3
ENV _BUILD_OMPI_VERSION=${_BUILD_OMPI_VERSION}
ARG _BUILD_OMPI_BASE_VERSION=4.0
ENV _BUILD_OMPI_BASE_VERSION=${_BUILD_OMPI_BASE_VERSION}

# ------------------------------------------------------------
# Flush but keep the build directory
# - We will mount in the pmix/prrte/ompi source in there
# ------------------------------------------------------------
RUN rm -rf /opt/hpc/local/build && mkdir -p /opt/hpc/local/build

# ------------------------------------------------------------
# Copy in an MPI test program
# ------------------------------------------------------------
RUN mkdir -p /opt/hpc/examples && chmod og+rwX /opt/hpc/examples && \
    mkdir -p /opt/hpc/etc && chmod og+rwX /opt/hpc/etc
COPY tests /opt/hpc/examples

#
# Setup munge security for Slurm
#
RUN dd if=/dev/urandom bs=1 count=1024 > ${MUNGE_INSTALL_PATH}/etc/munge/munge.key
RUN chown root: ${MUNGE_INSTALL_PATH}/etc/munge/munge.key
RUN chmod 400 ${MUNGE_INSTALL_PATH}/etc/munge/munge.key

# ------------------------------------------------------------
# Fixup the ssh login
# ------------------------------------------------------------
RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" && \
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key  -N "" && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key  -N "" && \
    echo "        LogLevel ERROR" >> /etc/ssh/ssh_config && \
    echo "        StrictHostKeyChecking no" >> /etc/ssh/ssh_config && \
    echo "        UserKnownHostsFile=/dev/null" >> /etc/ssh/ssh_config

# ------------------------------------------------------------
# Adjust default ulimit for core files
# ------------------------------------------------------------
RUN echo '*               hard    core            -1' >> /etc/security/limits.conf && \
    echo '*               soft    core            -1' >> /etc/security/limits.conf && \
    echo 'ulimit -c unlimited' >> /root/.bashrc

# ------------------------------------------------------------
# Create a user account
# ------------------------------------------------------------
RUN groupadd -r mpiuser && useradd --no-log-init -r -m -b /home -g mpiuser -G wheel mpiuser
USER mpiuser
RUN  cd /home/mpiuser && \
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa && chmod og+rX . && \
        cd .ssh && cat id_rsa.pub > authorized_keys && chmod 644 authorized_keys && \
        exit

#
# Need to enable root ssh without password
#
USER root
RUN  cd /root/ && \
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa && chmod og+rX . && \
        cd .ssh && cat id_rsa.pub > authorized_keys && chmod 644 authorized_keys && \
        exit

# ------------------------------------------------------------
# Give the user passwordless sudo powers
# ------------------------------------------------------------
USER root
RUN echo "mpiuser    ALL = NOPASSWD: ALL" >> /etc/sudoers

# ------------------------------------------------------------
# Add directories required to support rpmbuild
# ------------------------------------------------------------
USER mpiuser
RUN mkdir /home/mpiuser/RPMBUILD /home/mpiuser/RPMBUILD/BUILD \
          /home/mpiuser/RPMBUILD/RPMS /home/mpiuser/RPMBUILD/SOURCES \
          /home/mpiuser/RPMBUILD/SPECS /home/mpiuser/RPMBUILD/SRPMS

# ------------------------------------------------------------
# Adjust the default environment
# ------------------------------------------------------------
USER root

ENV PRTE_MCA_prte_default_hostfile=/opt/hpc/etc/hostfile.txt
ENV OMPI_MCA_btl_tcp_if_include=eth0
ENV PRTE_MCA_oob_tcp_if_include=eth0
ENV PMIX_MCA_ptl_base_if_include=eth0
ENV PATH=$PATH:/opt/hpc/local/hwloc/bin
# Need to do this so that the 'mpiuser' can have them too, not just root
RUN echo "export PMIX_ROOT=/opt/hpc/external/pmix" >> /etc/bashrc && \
    echo "export PRRTE_ROOT=/opt/hpc/external/prrte" >> /etc/bashrc  && \
    echo "export OMPI_ROOT=/opt/hpc/external/ompi" >> /etc/bashrc  && \
    echo "export MPICH_ROOT=/opt/hpc/external/mpich" >> /etc/bashrc  && \
    echo "export SLURM_ROOT=/opt/hpc/external/slurm" >> /etc/bashrc  && \
    echo "export PATH=\$OMPI_ROOT/bin:\$PATH" >> /etc/bashrc  && \
    echo "export PATH=\$MPICH_ROOT/bin:\$PATH" >> /etc/bashrc  && \
    echo "export PATH=\$SLURM_ROOT/bin:\$PATH" >> /etc/bashrc  && \
    echo "export PATH=\$SLURM_ROOT/sbin:\$PATH" >> /etc/bashrc  && \
    echo "export PATH=\$MUNGE_INSTALL_PATH/bin:\$PATH" >> /etc/bashrc  && \
    echo "export PATH=\$MUNGE_INSTALL_PATH/sbin:\$PATH" >> /etc/bashrc  && \
    echo "export PATH=\$PRRTE_ROOT/bin:\$MPI_ROOT/bin:\$PATH" >> /etc/bashrc  && \
    echo "export LD_LIBRARY_PATH=\$MPI_ROOT/lib:\$LD_LIBRARY_PATH" >> /etc/bashrc && \
    echo "export LD_LIBRARY_PATH=\$PMIX_ROOT/lib:\$LD_LIBRARY_PATH" >> /etc/bashrc && \
    echo "export LD_LIBRARY_PATH=\$HWLOC_INSTALL_PATH/lib:\$LD_LIBRARY_PATH" >> /etc/bashrc && \
    echo "export LD_LIBRARY_PATH=\$LIBEVENT_INSTALL_PATH/lib:\$LD_LIBRARY_PATH" >> /etc/bashrc && \
    echo "export LD_LIBRARY_PATH=\$PRRTE_ROOT/lib:\$LD_LIBRARY_PATH" >> /etc/bashrc && \
    echo "export PRTE_MCA_prte_default_hostfile=$PRTE_MCA_prte_default_hostfile" >> /etc/bashrc && \
    echo "export PMIX_MCA_ptl_base_if_include=$PMIX_MCA_ptl_base_if_include" >> /etc/bashrc && \
    echo "export OMPI_MCA_btl_tcp_if_include=$OMPI_MCA_btl_tcp_if_include" >> /etc/bashrc && \
    echo "export PRTE_MCA_oob_tcp_if_include=$PRTE_MCA_oob_tcp_if_include" >> /etc/bashrc && \
    echo "export LIBEVENT_INSTALL_PATH=/opt/hpc/local/libevent" >> /etc/bashrc && \
    echo "export HWLOC_INSTALL_PATH=/opt/hpc/local/hwloc" >> /etc/bashrc && \
    echo "export MUNGE_INSTALL_PATH=/opt/hpc/local/munge" >> /etc/bashrc && \
    echo "export OMPI_MCA_btl_tcp_if_include=eth0" >> /etc/bashrc && \
    echo "ulimit -c unlimited" >> /etc/bashrc && \
    echo "alias pd=pushd" >> /etc/bashrc

# ------------------------------------------------------------
# Kick off the ssh daemon
# ------------------------------------------------------------
EXPOSE 22
# Make sure these ports match Slurm defaults or slurm.conf 
EXPOSE 7002
EXPOSE 7003
CMD ["/usr/sbin/sshd", "-D"]

