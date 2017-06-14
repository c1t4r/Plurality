#!/bin/bash

# Works with singularity 2.3 / su
# Builds a base container image for justus

# Parameters
#  --local  ; local image only, requires root password
#  --remote ; triggers remote builds on shub
#  --all    ; local image plus triggering of remote builds
#
# TODO treat build modes properly
# TODO add dockerfile support
# 
# Default is: --all
BUILDMODE="${1:-'--local'}"
CALLINGDIR=`dirname $(readlink -f $0)`
GIT_URL="git@github.com:c1t4r/CiTAR-Containers.git"

SHAREDWORKDIR="$CALLINGDIR/$BASHPID" && mkdir -p $SHAREDWORKDIR && cd $SHAREDWORKDIR
IMGDIR="$CALLINGDIR/images"
IMPORTS="$CALLINGDIR/rootfs"

VNFSBaseImage="rhel7.stateless.CiTAR"
CITARROOTFS="/var/lib/perceus/vnfs/$VNFSBaseImage/rootfs"
DATESTR="+%Y-%m-%d-%H-%M"

echo "Building JUSTUS Base Image"

rpm --root $CITARROOTFS -q -a --queryformat '%{NAME} ' | sort > $SHAREDWORKDIR/packagelist.txt

SRCSUM="$(sha256sum $SHAREDWORKDIR/packagelist.txt | awk '{print $1}')"
SUM=$( [[ -f $IMGDIR/$SRCSUM/sha256 ]] && cat $IMGDIR/$SRCSUM/sha256 )

if [[ -d $IMGDIR/$SRCSUM ]]; then
    echo "An up-to-date image for $SRCSUM exists already, no changes detected..."
else
    echo "Building image for $SRCSUM from $VNFSBaseImage..."
    rpm --root $CITARROOTFS -q -a --queryformat '%{NAME} ' | sort > packagelist.txt
    cat << EOF_DEFFILE > singularity.def
BootStrap: docker
From: centos:7
IncludeCmd: yes

%runscript
    echo "This is what happens when you run the container..."

%environment
module() { eval `/usr/bin/modulecmd sh $*`; }
export MODULEPATH=/opt/bwhpc/ul/modulefiles:/opt/bwhpc/common/modulefiles
export PSM_SHAREDCONTEXTS_MAX=6 # do NOT allocate all HCs, leave remaining HCs for other MPI apps running simultaneously
export PS1="\[\033[01;32m\]\u@${SINGULARITY_CONTAINER}@\h\[\033[01;34m\] \w \$\[\033[00m\] "

%post
    echo "Installing JUSTUS software package list"
    yum -y install deltarpm
    yum -y --skip-broken install \\
EOF_DEFFILE
    echo "Retrieving package list..."
    cat packagelist.txt >> singularity.def
    echo "" >> singularity.def
    echo "    yum clean all" >> singularity.def
    echo "    mv /usr/bin/ssh /usr/bin/ssh_orig" >> singularity.def

cat << 'EOF_DEFFILE' >> singularity.def
    IMPORTDIR=$(mktemp -d)
    cd $IMPORTDIR
    git clone https://github.com/c1t4r/Plurality.git -b master
    cd Plurality/rootfs
    git checkout-index -a -f --prefix=$IMPORTDIR/
    find $IMPORTDIR/rootfs -type d -execdir rm -f {}/.gitignore \;
    rm -f /.singularity.d/actions/* 
    rsync --ignore-existing -rahlvp $IMPORTDIR/rootfs/ /
    cd /
    chmod -R a+rwx /opt/bwhpc/common /custom/*
    rm -rf $IMPORTDIR
EOF_DEFFILE

    cd $SHAREDWORKDIR 

    git clone $GIT_URL containerspec
    cp singularity.def containerspec/Singularity
    cd containerspec

    echo "" >> README.md
    echo "* updated build: $(date $DATESTR)" >> README.md
    git add Singularity README.md
    git commit -am 'updated build'
    git push

    cd ..

    ### begin - su part

    echo "Please enter root password for 'su' "
    stty -echo
    read -p "Password: " PASSWD; echo
    stty echo

    echo -n "Creating container image..." && echo "[$CONTAINER_COMMAND]"
    CONTAINER_COMMAND="singularity create -s 3000 centos7-justus.img" && echo "[$CONTAINER_COMMAND]"
    echo "$PASSWD" | su -c "$CONTAINER_COMMAND"

    echo -n "Bootstrapping CentOS7 base system... "
    CONTAINER_COMMAND="singularity bootstrap centos7-justus.img singularity.def" && echo "[$CONTAINER_COMMAND]"
    echo "$PASSWD" | su -c "$CONTAINER_COMMAND"

    # TODO needed???
    sync

    SUM="$(sha256sum centos7-justus.img | awk '{print $1}')"

    echo "Copying image into local archive..."
    mkdir -p $IMGDIR/$SRCSUM
    cp centos7-justus.img $IMGDIR/$SRCSUM/img
    echo $SUM > $IMGDIR/$SRCSUM/sha256
    ln -s $IMGDIR/$SRCSUM/img "$IMGDIR/$SUM"
    echo "Done!"
    ### end - su part
fi

echo "Updating the image link..."
READABLE_FN="$VNFSBaseImage-$(date $DATESTR).img"
ln -sf $IMGDIR/$SRCSUM/img "$IMGDIR/$READABLE_FN"

echo "Cleaning shared directory..."
#rm -rf $SHAREDWORKDIR

echo "DONE: Container is now accessible under $IMGDIR/$READABLE_FN"
