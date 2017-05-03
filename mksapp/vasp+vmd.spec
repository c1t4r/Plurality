ContainerName="Vasp_VMD.sapp"
IncludeModule="chem/vasp/5.3.3.4 chem/vmd/1.9.2"
VNFSBaseImage="rhel7.stateless.CiTAR"

cat << 'EOF' > $CALLINGDIR/rootfs/test
#!/bin/bash

source /environment
module load chem/vasp

cd /tmp
cp /opt/bwhpc/common/chem/vasp/5.3.3.4/examples/benchPdO2.tar.gz .
tar xzf benchPdO2.tar.gz
cd benchPdO2
vasp -n 8 -s gamma
echo "...Finished!"
EOF

cat <<EOF > $CALLINGDIR/rootfs/moduleimports
/opt/bwhpc/common/chem/vasp/5.3.3.4/                                                                        # VASP
/opt/bwhpc/common/compiler/intel/compxe.2015.3.187/impi/5.0.3.048/intel64/lib/libmpifort.so.12*             # workaround wrongly linked MPI lib
/opt/bwhpc/common/compiler/intel/compxe.2015.3.187/impi/5.0.3.048/intel64/lib/release_mt/libmpi.so.12*      # workaround wrongly linked MPI lib
/opt/bwhpc/common/chem/vmd/1.9.2/bin                 # VMD
/opt/bwhpc/common/chem/vmd/1.9.2/examples
/opt/bwhpc/common/chem/vmd/1.9.2/lib
/opt/bwhpc/common/chem/vmd/1.9.2/modulefiles
EOF

cat << 'EOF' > $CALLINGDIR/rootfs/singularity
#!/bin/bash
source /environment
module load chem/vasp/5.3.3.4
/opt/bwhpc/common/chem/vasp/5.3.3.4/bin/vasp "$@"
EOF
