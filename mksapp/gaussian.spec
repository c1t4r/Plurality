ContainerName="Gaussian.sapp"
IncludeModule="chem/gaussian/g09.D.01"
VNFSBaseImage="rhel7.stateless.CiTAR"

cat << 'EOF' > $CALLINGDIR/rootfs/test
#!/bin/bash

source /environment

module load chem/gaussian

echo "TODO!"
EOF

cat <<EOF > $CALLINGDIR/rootfs/moduleimports
/opt/bwhpc/common/chem/gaussian/g09.D.01/                                                                   # Gaussian 09
EOF
