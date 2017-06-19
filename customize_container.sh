#!/bin/bash

# Works with singularity 2.3
# Customizes a base container image by a given definition file

SHUB_URL="shub://c1t4r/CiTAR-Containers"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 custom-container-dir"
    exit
fi

INPUTDIR="$(readlink -f $1)"
CONTAINERNAME="$(cat $INPUTDIR/containername)".img
FILELIST="$INPUTDIR/filelist"
MODFILELIST="$INPUTDIR/modulefilelist"
DUF="$INPUTDIR/du"

echo "Downloading latest JUSTUS base container"
singularity pull --name "$CONTAINERNAME" $SHUB_URL

if [[ -f $DUF ]]; then
    echo "Using predefined additional size information"
    DU="$(cat $DUF)"
else
    echo "Estimating additional size needed"
    DU=`du -m -c $(cat $FILELIST | sed 's/#.*//') | awk '/total/{printf("%s ",$1)}'`
    echo "$DU" > "$DUF"
fi

echo "${DU}Mb needed in addition, expanding the container..."
singularity expand --size $DU "$CONTAINERNAME"

echo "Importing files..."
OLDPWD=$(pwd)
cd $INPUTDIR
for filedir in $(cat $FILELIST | sed 's/#.*//'); do
    echo "Importing $filedir ..."
    tar -cph "$filedir" | singularity import "$OLDPWD/$CONTAINERNAME"
done
cd "$OLDPWD"

echo "Importing module files..."
for mfile in $(cat $MODFILELIST | sed 's/#.*//'); do
    tar -cph "$mfile" | singularity import "$CONTAINERNAME"
done

singularity exec Vasp+VMD.img test -f /.singularity.d/test && HASTEST=1

if [[ "$HASTEST" = "" ]]; then
    echo "No container test defined"
else
    singularity test "$CONTAINERNAME"

    if [[ "$?" == "0" ]]; then
        echo "Passed container test"
    else
        echo "Failed container test"
        exit 99
    fi
fi
