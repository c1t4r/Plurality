ContainerName="DaCapo.sapp"

IncludeModule="chem/dacapo/2.7.16"

VNFSBaseImage="rhel7.stateless.CiTAR"

cat << 'EOF' > $CALLINGDIR/rootfs/test
#!/bin/bash

source /environment

if [[ $@ == "" ]]; then
    echo "No arguments given, running benchmark example..."

    ### setting up environment
    unset LANG; export LC_ALL="C"; export MKL_NUM_THREADS=1; export OMP_NUM_THREADS=1
    ulimit -s unlimited
    export MOAB_JOBID=${MOAB_JOBID:=`date +%s`}
    export MOAB_SUBMITDIR=${MOAB_SUBMITDIR:=`pwd`}
    export MOAB_JOBNAME=${MOAB_JOBNAME:=`basename "$0"`}
    export MOAB_JOBNAME=$(echo "${MOAB_JOBNAME}" | sed 's/[^a-zA-Z0-9._-]/_/g')
    export MOAB_NODECOUNT=${MOAB_NODECOUNT:=1}
    export MOAB_PROCCOUNT=${MOAB_PROCCOUNT:=2}
    export DACAPO_CORES_PER_NODE=$MOAB_PROCCOUNT
    export DACAPO_CORES_PER_JOB=$MOAB_PROCCOUNT

    TMPDIR=$(mktemp -d)

    cd $TMPDIR

    cp /opt/bwhpc/common/chem/dacapo/2.7.16-intel-14.0/bwhpc-examples/* .

    module load chem/dacapo
    /usr/bin/python example_COCu111.py

    rm -rf $TMPDIR
    echo "Done!"
else
    module load chem/dacapo
    /usr/bin/python "$@"
fi
EOF

# FIXME add file lists there (optionally)
cat <<EOF > $CALLINGDIR/rootfs/moduleimports
/opt/bwhpc/common/chem/dacapo/2.7.16-intel-14.0/                                        # DaCapo+ASE
/opt/bwhpc/common/compiler/intel/compxe.2013.sp1.4.211/lib/intel64/                     # Intel Libs
/opt/bwhpc/common/compiler/intel/compxe.2013.sp1.4.211/mkl/lib/intel64/                 # Intel MKL
/opt/bwhpc/common/compiler/intel/compxe.2013.sp1.4.211/composer_xe_2013_sp1.4.211/mkl   # Intel MKL symlink
/opt/bwhpc/common/mpi/openmpi/1.8.7-intel-14.0/                                         # OpenMPI built using Intel Compiler
EOF
