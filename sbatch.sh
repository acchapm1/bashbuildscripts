#!/bin/bash

source ../../header.source
source ../../module.source

VERSION=`basename $PWD`
PKGNAME=`basename "${PWD%$VERSION}"`

if [[ $# -eq 1 ]] ; then
  ALTFILE=$1
else
  ALTFILE="variables.source"
fi

RAND=$RANDOM
SETUP_SBATCH=$(mktemp)

cat <<EOT > $SETUP_SBATCH
#!/bin/bash

$QOS
$PARTITION
#SBATCH -J "$PKGNAME/$VERSION CONFIGURE"
#SBATCH -N 1                        # number of nodes
#SBATCH -n 1                        # number of cores
#SBATCH -t 0-00:30                  # wall time (D-HH:MM)
##SBATCH -A jorgeh                  # Account hours will be pulled from (commented out with double # in front)
#SBATCH -o /packages/uniform/jobs/%j.out             # STDOUT (%j = JobId)
#SBATCH -e /packages/uniform/jobs/%j.err             # STDERR (%j = JobId)
#SBATCH --mail-type=ALL             # Send a notification when the job starts, stops, or fails
#SBATCH --mail-user=$USER@asu.edu   # send-to address

if [ "\$SLURM_JOB_PARTITION" == "phi" ]; then
  export MODULEPATH=/packages/uniform/modulefiles/phi:/packages/uniform/modulefiles/broadwell:/usr/share/Modules/modulefiles
elif [ "\$SLURM_JOB_PARTITION" == "cidsegpu1" ]; then
  export MODULEPATH=/packages/uniform/modulefiles/skylake:/packages/uniform/modulefiles/broadwell:/usr/share/Modules/modulefiles
else
  export MODULEPATH=/packages/uniform/modulefiles/broadwell:/usr/share/Modules/modulefiles
fi

cd ${TARGET_PREFIX}/build/$PKGNAME/$VERSION
./0_download.sh || { exit 10 ; }
./1_untar.sh $RAND $ALTFILE || { exit 1; }
./2_configure.sh $RAND || { exit 2; }
EOT

JID=$(sbatch --parsable $SETUP_SBATCH)
rm $SETUP_SBATCH
BUILD_SBATCH=$(mktemp)

cat <<EOT > $BUILD_SBATCH
#!/bin/bash

$QOS
$PARTITION
#SBATCH -J "$PKGNAME/$VERSION BUILD"
#SBATCH -N 1                        # number of nodes
#SBATCH -n $MAKE_SIMUL_JOBS         # number of cores
#SBATCH -t 0-03:00                  # wall time (D-HH:MM)
##SBATCH -A jorgeh                  # Account hours will be pulled from (commented out with double # in front)
#SBATCH -o /packages/uniform/jobs/%j.out             # STDOUT (%j = JobId)
#SBATCH -e /packages/uniform/jobs/%j.err             # STDERR (%j = JobId)
#SBATCH --mail-type=ALL             # Send a notification when the job starts, stops, or fails
#SBATCH --mail-user=$USER@asu.edu   # send-to address

if [ "\$SLURM_JOB_PARTITION" == "phi" ]; then
  export MODULEPATH=/packages/uniform/modulefiles/phi:/packages/uniform/modulefiles/broadwell:/usr/share/Modules/modulefiles
elif [ "\$SLURM_JOB_PARTITION" == "cidsegpu1" ]; then
  export MODULEPATH=/packages/uniform/modulefiles/skylake:/packages/uniform/modulefiles/broadwell:/usr/share/Modules/modulefiles
else
  export MODULEPATH=/packages/uniform/modulefiles/broadwell:/usr/share/Modules/modulefiles
fi

cd ${TARGET_PREFIX}/build/$PKGNAME/$VERSION
./3_build.sh $RAND || { exit 3; }
./4_install.sh $RAND || { exit 4; }
./5_make_module.sh $RAND || { exit 5; }
./9_rm_src.sh $RAND || { exit 9; }
EOT

JID2=$(sbatch --parsable --dependency=afterok:$JID $BUILD_SBATCH)
echo "Submitted job: $PKGNAME/$VERSION (build id: $RAND, job ids: $JID/$JID2)"
rm $BUILD_SBATCH

