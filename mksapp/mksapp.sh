#!/bin/bash

### load specs
CALLINGDIR=`dirname $(readlink -f $0)`

source "$1"

if [ "$1" == "" ]; then
  echo "Usage: $0 specs-file"
  exit 1
fi

SHAREDWORKDIR="$CALLINGDIR/$BASHPID" && mkdir -p $SHAREDWORKDIR && cd $SHAREDWORKDIR
IMGDIR="$CALLINGDIR/images"
INCLUDES="$CALLINGDIR/rootfs"

### CiTAR settings
RESOLVE_DEPS=1
CITARADMIN="ul_l_nsn25"
CITARROOTFS="/var/lib/perceus/vnfs/$VNFSBaseImage/rootfs"
MODULEPATH="/opt/bwhpc/ul/modulefiles:/opt/bwhpc/common/modulefiles"

DATESTR="+%Y-%m-%d-%H-%M"

get_basepath_list() {
  if [[ -f $INCLUDES/moduleimports ]]; then
    cat $INCLUDES/moduleimports | awk '{print $1}' | tr -s '\n' ' '
  else
    ## Fallback if no dependencies are defined by hand - determines base path of installed module
    for m in "$@"; do
      find $( module show $m 2>&1  | awk 'FNR==2{print;next} /^setenv[[:space:]]/{print $3;next} /^{prepend,append}-path[[:space:]]/{print $3;next}' | tr -d ':' | grep '^/' | sort -d -u ) -type d | sort -d -u | head -n 1
    done
  fi
}

echo "(1/2) - Building System Image"

if [[ -f "$CALLINGDIR/10G_template.img" ]]; then
    echo "Found empty template container...good!"
else
    echo "Empty template container not found. Generate it..."
    ssh adm02 "singularity create -s 10000 $CALLINGDIR/10G_template.img"
    echo "...Done!"
fi

SRCSUM="$(sha256sum /var/lib/perceus/vnfs/$VNFSBaseImage/vnfs.img | awk '{print $1}')"
SUM=$( [[ -f $IMGDIR/$SRCSUM/sha256 ]] && cat $IMGDIR/$SRCSUM/sha256 )

if [[ -d $IMGDIR/$SRCSUM ]]; then
    echo "An up-to-date image exists already, no changes detected..."
else
    echo "Building image from $VNFSBaseImage..."
    rpm --root $CITARROOTFS -q -a --queryformat '%{NAME} ' > packagelist.txt
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
    cat packagelist.txt >> docker.def

    cp $CALLINGDIR/10G_template.img $SHAREDWORKDIR/centos7-justus.img
    ssh adm02 "cd $SHAREDWORKDIR && singularity bootstrap centos7-justus.img docker.def"
    ssh adm02 "cd $SHAREDWORKDIR && singularity copy centos7-justus.img packagelist.txt docker.def /"
    ssh adm02 "cd $SHAREDWORKDIR && singularity import centos7-justus.img addons.tar"
    ssh adm02 "cd $SHAREDWORKDIR && singularity exec -w centos7-justus.img su -c 'mkdir -p /nfs /lustre /scratch /var/spool/torque'"
    ssh adm02 "cd $SHAREDWORKDIR && singularity exec -w centos7-justus.img su -c 'touch /etc/ws.ini'"
    ssh adm02 "cd $SHAREDWORKDIR && singularity exec -w centos7-justus.img su -c 'mv /usr/bin/ssh /usr/bin/ssh_orig'"
    ssh adm02 "cd $SHAREDWORKDIR && singularity exec -w centos7-justus.img yum clean all"
    ssh adm02 "cd $SHAREDWORKDIR && singularity export centos7-justus.img | gzip > img"

    SUM="$(sha256sum img | awk '{print $1}')"

    echo "Copying image into local archive..."
    mkdir -p $IMGDIR/$SRCSUM
    cp $SHAREDWORKDIR/img $IMGDIR/$SRCSUM/img
    echo $SUM > $IMGDIR/$SRCSUM/sha256
    ln -s $IMGDIR/$SRCSUM/img "$IMGDIR/$VNFSBaseImage-$(date $DATESTR).tgz"
    ln -s $IMGDIR/$SRCSUM/img "$IMGDIR/$SUM.tgz"
    echo "Done!"
fi

### clean shared dir
rm -rf $SHAREDWORKDIR/*

echo "(2/2) - Importing Software Modules"

### Resolving dependencies...

if [[ $RESOLVE_DEPS == 1 ]]; then
    MODULES_TO_CLONE=$(module show $IncludeModule 2>&1 | awk -v m="$IncludeModule" 'END{print m}/^module[[:space:]]+load/{print $3} /^prereq[[:space:]]/{print $2}' | sort -u | tr -s '\n' ' ')
else
    MODULES_TO_CLONE="$IncludeModule"
fi

echo "$IncludeModule depends on $MODULES_TO_CLONE"

### Get extended file access attributes
for m in $IncludeModule; do
    getfacl -p -R $(get_basepath_list $m) >> $SHAREDWORKDIR/ACL
done

### Build a list of all files with absolute paths to clone
tar  --hard-dereference "-capf" $SHAREDWORKDIR/SWStack.tar $(get_basepath_list $MODULES_TO_CLONE)
tar -rapf $SHAREDWORKDIR/SWStack.tar -C $SHAREDWORKDIR ACL

### Add required module files

for m in $MODULES_TO_CLONE; do
    tar -raphf $SHAREDWORKDIR/SWStack.tar /opt/bwhpc/common/modulefiles/$m
done

SRCSUM2=$(tar -O -xpf $SHAREDWORKDIR/SWStack.tar | sha256sum | awk '{print $1}')
SUM2=$( [[ -f $IMGDIR/$SRCSUM2/sha256 ]] && cat $IMGDIR/$SRCSUM2/sha256 )

if [[ -f $IMGDIR/$SRCSUM2/img ]]; then
    echo "An up-to-date image exists already, no changes detected...";
else
    echo "Merging image content..."
    cp $CALLINGDIR/10G_template.img $SHAREDWORKDIR/centos7-justus.img
    ssh adm02 "cd $SHAREDWORKDIR && zcat $IMGDIR/$SUM.tgz | singularity import centos7-justus.img"
    ssh adm02 "cd $SHAREDWORKDIR && cat SWStack.tar | singularity import centos7-justus.img"
    # FIXME some ldap users do not work
    ssh adm02 "singularity exec -w -B /etc/passwd -B /etc/group $SHAREDWORKDIR/centos7-justus.img sh -c 'setfacl --restore /ACL'"
    chmod +x $INCLUDES/{environment,test,singularity,.test}  # make these file executable otherwise things may break in the future
    ssh adm02 "cd $INCLUDES && tar -cp . | singularity import $SHAREDWORKDIR/centos7-justus.img"
    ssh adm02 "singularity test $SHAREDWORKDIR/centos7-justus.img"

    if [[ "$?" == "0" ]]; then
       echo "Passed container test"
    else
        echo "Failed container test. Will not remove $SHAREDWORKDIR"
        exit 99
    fi

    echo "Copying image into local archive..."
    mkdir -p $IMGDIR/$SRCSUM2
    cp $SHAREDWORKDIR/centos7-justus.img $IMGDIR/$SRCSUM2/img
    SUM2="$(sha256sum $IMGDIR/$SRCSUM2/img | awk '{print $1}')"
    echo $SUM2 > $IMGDIR/$SRCSUM2/sha256

    ln -s $IMGDIR/$SRCSUM2/img $IMGDIR/${SUM2}.img
    echo "Done!"
fi

READABLE_NAME="$ContainerName-$(date $DATESTR).img"
ln -s $IMGDIR/$SRCSUM2/img "$IMGDIR/$READABLE_NAME"

### clean shared dir
rm -rf $SHAREDWORKDIR
rm -f $INCLUDES/moduleimports
chown -R $CITARADMIN $IMGDIR

echo "Container is now accessible under $IMGDIR/$READABLE_NAME"

