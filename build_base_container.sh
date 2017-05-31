#!/bin/bash

# works with singularity 2.2.1 / su
# builds a base container image for justus

CALLINGDIR=`dirname $(readlink -f $0)`

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
    tar -C $CITARROOTFS -cpf addons.tar usr/local
    cat << EOF_DEFFILE > docker.def
BootStrap: docker
From: centos:7
IncludeCmd: yes

%runscript
    echo "This is what happens when you run the container..."

%post
    echo "Installing JUSTUS software package list"
    yum -y install deltarpm
    yum -y --skip-broken install \\
EOF_DEFFILE
    echo "Retrieving package list..."
    cat packagelist.txt >> docker.def
    echo "" >> docker.def
    echo "    yum clean all" >> docker.def

    echo "Adding definition bootstrap file for building the container and the packagelist to the file imports..."
    cp docker.def packagelist.txt $IMPORTS

    echo -n "Creating home directory bind points as imports... "
    cd $IMPORTS
    rm -rf home
    HOMEDIRS="$(getent passwd | awk -F: '/ul_theochem/{print "."$6}/ul_theophys/{print "."$6}/ul_kiz/{print "."$6}' | tr -s '\n' ' ')"
    cd $IMPORTS && mkdir -p $HOMEDIRS

    ### begin - su part

    echo "Please enter root password for 'su' "
    stty -echo
    read -p "Password: " PASSWD; echo
    stty echo

    if [[ -f $CALLINGDIR/template.img ]]; then
        echo "Template container image found, using it..."
    else
        echo -n "Creating template container image..." && echo "[$CONTAINER_COMMAND]"
        CONTAINER_COMMAND="singularity create -s 3000 $CALLINGDIR/template.img" && echo "[$CONTAINER_COMMAND]"
        echo "$PASSWD" | su -c "$CONTAINER_COMMAND"
    fi

    cp $CALLINGDIR/template.img $SHAREDWORKDIR/centos7-justus.img
    cd $SHAREDWORKDIR 

    echo -n "Bootstrapping CentOS7 base system... "
    CONTAINER_COMMAND="singularity bootstrap centos7-justus.img docker.def" && echo "[$CONTAINER_COMMAND]"
    echo "$PASSWD" | su -c "$CONTAINER_COMMAND"

    echo -n "Adding locally installed software... "
    CONTAINER_COMMAND="singularity import centos7-justus.img addons.tar" && echo "[$CONTAINER_COMMAND]"
    echo "$PASSWD" | su -c "$CONTAINER_COMMAND"

    echo -n "Installing SSH wrapper for multi node MPI... "
    CONTAINER_COMMAND="singularity exec -c -w centos7-justus.img su -c 'mv /usr/bin/ssh /usr/bin/ssh_orig'" &&  echo "[$CONTAINER_COMMAND]"
    echo "$PASSWD" | su -c "$CONTAINER_COMMAND"

    echo -n "Importing local files/directories into container... "
    cd $IMPORTS && tar --owner=root --group=root -cpsf $SHAREDWORKDIR/imports.tar . && cd $SHAREDWORKDIR
    CONTAINER_COMMAND="singularity import centos7-justus.img imports.tar" &&  echo "[$CONTAINER_COMMAND]"
    echo "$PASSWD" | su -c "$CONTAINER_COMMAND"

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
if [[ -f "$SHAREDWORKDIR/centos7-justus.img" ]]; then
  echo "Deleting container image..."
  echo "$PASSWD" | su -c "rm $SHAREDWORKDIR/centos7-justus.img"
fi

rm -rf $SHAREDWORKDIR

echo "DONE: Container is now accessible under $IMGDIR/$READABLE_FN"
