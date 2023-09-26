#!/bin/bash

source ../../header.source
source ../../module.source
VARIABLES_SOURCE_PATH=variables.source

if [ $# -eq 1 ]; then
  BUILD_ID=$1
  echo-green "* using supplied build id... $BUILD_ID"
elif [ $# -eq 2 ]; then
  VARIABLES_SOURCE_PATH=installs.d/$2
  BUILD_ID=$1
  echo-green "* using alternate variables.install: installs.d/$2"
  echo-green "* using supplied build id... $BUILD_ID"
else
  ./9_rm_src.sh
  BUILD_ID=$RANDOM
  echo-green "* generating random build id... $BUILD_ID"
fi

source $VARIABLES_SOURCE_PATH

echo ""
echo "These instructions are functionally equivalent to the commands"
echo "executed when each script is run. Each command has a different"
echo "color according to its status."
echo ""
echo-green "GREEN: appears to have been previously executed (evidence of attempt)"
echo-yellow "YELLOW: complete previous commands prior to execution"
echo "WHITE: ready to run (no evidence of attempt)"
echo-red "RED: command needs sudo/will cause changes outside this source tree"
echo ""

echo-yellow "# ************************ #"
echo-yellow "# Overview for $PKGNAME"
echo-yellow "# ************************ #"

echo "# VERSION: $VERSION"
echo "# VARIANT: ${MODULE_VERSION:-$VERSION}"
echo ""
echo "# BUILD_DEPS: $BUILD_DEPS"
echo "# RUNTIME_DEPS: $RUNTIME_DEPS"

ECHO="echo-red"

#################
# 0_download.sh
#################
echo ""
echo-blue "# [0_download.sh] steps"
echo-blue ""

STEP_ZERO_FINISHED=false

case "$WGET_DEST" in
*.git )
  if [ -d "$DOWNLOAD_DIR" ]; then
    if [ $(find $DOWNLOAD_DIR -type d -name '.git') ]; then
      ECHO="echo-green"
      $ECHO "mkdir -p $DOWNLOAD_DIR"
      $ECHO "cd $DOWNLOAD_DIR"
      $ECHO "git clone $WGET_URL $EXTRACTED_DIRNAME"
    else
      ECHO="echo"
      echo-green "mkdir -p $DOWNLOAD_DIR"
      $ECHO "cd $DOWNLOAD_DIR"
      $ECHO "git clone $WGET_URL $EXTRACTED_DIRNAME"
    fi
  else
    ECHO="echo-yellow"
    echo "mkdir -p $DOWNLOAD_DIR"
    $ECHO "cd $DOWNLOAD_DIR"
    $ECHO "git clone $WGET_URL $EXTRACTED_DIRNAME"
  fi
  ;;
* )
  if [ -f "$DOWNLOAD_DIR/$WGET_DEST" ]; then
    ECHO="echo-green"
    $ECHO "mkdir -p $DOWNLOAD_DIR"
    $ECHO "cd $DOWNLOAD_DIR"
    $ECHO "wget -c $WGET_URL -O $WGET_DEST"
  else
    ECHO="echo-yellow"
    if [ -d "$DOWNLOAD_DIR" ]; then
      echo-green "mkdir -p $DOWNLOAD_DIR"
      echo "cd $DOWNLOAD_DIR"
      echo "wget -c $WGET_URL -O $WGET_DEST"
    else
      echo "mkdir -p $DOWNLOAD_DIR"
      echo-yellow "cd $DOWNLOAD_DIR"
      echo-yellow "wget -c $WGET_URL -O $WGET_DEST"
    fi
  fi
  ;;
esac

if [ $ECHO = "echo-green" ]; then
  STEP_ZERO_FINISHED=true
  $ECHO "#COMPLETE"
fi

#################
# 1_untar.sh
#################
echo-blue ""
echo-blue "# [1_untar.sh] steps"
echo-blue ""

STEP_ONE_FINISHED=false

SCRATCH_ROOT=/scratch/$USER/builds/$PKGNAME/$BUILD_ID
SRC_DIR=$SCRATCH_ROOT/src

if [ -d "$SRC_DIR" ]; then
  ECHO="echo-green"
  $ECHO "mkdir -p $SCRATCH_ROOT/src"
elif [ -d "$SCRATCH_ROOT" ]; then
  ECHO="echo"
  echo-green "mkdir -p $SCRATCH_ROOT"
else
  ECHO="echo"
  $ECHO "mkdir -p $SCRATCH_ROOT"
fi

case "$WGET_DEST" in
  *.tar.gz | *.tgz | *.bz2 | *.xz )
    if [ -d "$SRC_DIR" ]; then
      ECHO="echo-green"
      $ECHO "cd $DOWNLOAD_DIR"
      $ECHO "tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT"
      $ECHO "mv $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    elif [ -d "$SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION}" ]; then
      ECHO="echo-yellow"
      echo-green "cd $DOWNLOAD_DIR"
      echo-green "tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT"
      echo "mv $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    else
      ECHO="echo-yellow"
      echo "cd $DOWNLOAD_DIR"
      echo "tar xf $DOWNLOAD_DIR/$WGET_DEST -C $SCRATCH_ROOT"
      $ECHO "mv $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    fi
    ;;
  *.zip )
    if [ -d "$SRC_DIR" ]; then
      ECHO="echo-green"
      $ECHO "cd $DOWNLOAD_DIR"
      $ECHO "unzip $DOWNLOAD_DIR/$WGET_DEST -d $SCRATCH_ROOT/$EXTRACTED_DIRNAME"
      $ECHO "mv $SCRATCH_ROOT/${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    elif [ -d "$SCRATCH_ROOT/$EXTRACTED_DIRNAME" ]; then
      ECHO="echo"
      echo-green "cd $DOWNLOAD_DIR"
      echo-green "unzip $DOWNLOAD_DIR/$WGET_DEST -d $EXTRACTED_DIRNAME"
      $ECHO "mv ${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    else
      ECHO="echo-yellow"
      echo "cd $DOWNLOAD_DIR"
      echo "unzip $DOWNLOAD_DIR/$WGET_DEST -d $EXTRACTED_DIRNAME"
      $ECHO "mv ${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    fi
    ;;
  *.git )
    if [ -d "$SRC_DIR" ]; then
      ECHO="echo-green"
      $ECHO "cd $DOWNLOAD_DIR"
      $ECHO "cp -R $DOWNLOAD_DIR/$EXTRACTED_DIRNAME $SCRATCH_ROOT"
      $ECHO "mv ../${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    elif [ -d "$PWD/$EXTRACTED_DIRNAME" ]; then
      ECHO="echo"
      echo-green "cd $DOWNLOAD_DIR"
      echo-green "cp -R $DOWNLOAD_DIR/$EXTRACTED_DIRNAME $SCRATCH_ROOT"
      $ECHO "mv ../${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
    else
      ECHO="echo-yellow"
      echo "cd $DOWNLOAD_DIR"
      echo "cp -R $DOWNLOAD_DIR/$EXTRACTED_DIRNAME $SCRATCH_ROOT"
      echo-yellow "mv ${EXTRACTED_DIRNAME:=$PKGNAME-$VERSION} $SRC_DIR"
      #TODO: Add .sh code here
    fi
    ;;
esac

#TODO: Add git checkout code here

if [ $ECHO = "echo-green" ]; then
  STEP_ZERO_FINISHED=true
  $ECHO "#COMPLETE"
fi

#################
# 2_configure.sh
#################
echo-blue ""
echo-blue "# [2_configure.sh] steps"
echo-blue ""

DEPS_LOADED=0

for dep in "${BUILD_DEPS[@]}"
do
  OUTPUT=$(modulecmd bash list -l 2>&1)
  if [ "$(echo $OUTPUT | grep "$dep")" ]; then
    DEPS_LOADED=$(($DEPS_LOADED+1))
    ECHO="echo-green"
  else
    ECHO="echo"
  fi
  if [ "$dep" ]; then
    $ECHO "module load $dep"
  fi
done
ECHO="echo"

COMPILER_USED="gcc-stock"
MPI_USED=""
if [ "$TARGET_PREFIX" = '/packages/uniform' ]; then
  case $PKGNAME in
    gcc | intel | pgi)
      #compiling a compiler for `uniform`
      if [ -f $SCRATCH_ROOT/_install_dest ]; then
        echo-green "echo $TARGET_PREFIX/arch/$MTUNE/compilers/$PKGNAME/${MODULE_VERSION:-$VERSION} > $SCRATCH_ROOT/_install_dest"
      else
        ECHO="echo"
        $ECHO "echo $TARGET_PREFIX/arch/$MTUNE/compilers/$PKGNAME/${MODULE_VERSION:-$VERSION} > $SCRATCH_ROOT/_install_dest"
      fi
      ;;
    *)
      #compiling software for `uniform`, check deps to determine where it'll save to
      for dep in "${BUILD_DEPS[@]}"; do
        case "$dep" in
          gcc/* | intel/* | pgi/* )
            COMPILER_USED=${dep/\//-}
            break
            ;;
        esac
      done
      for dep in "${BUILD_DEPS[@]}"; do
        case "$dep" in
          mvapich2/* | openmpi/* | intel-mpi/* )
            MPI_USED=${dep/\//-}
            break
            ;;
        esac
      done
      export COMPILER_USED
      export MPI_USED
      export PACKAGE_BASEDIR="$TARGET_PREFIX/arch/$MTUNE/$COMPILER_USED"
      export PACKAGE_BASEDIR_STOCKGCC="$TARGET_PREFIX/arch/$MTUNE/gcc-stock"
      export PACKAGE_BASEDIR_STOCKGCC_BROADWELL="$TARGET_PREFIX/arch/broadwell/gcc-stock"
      export PACKAGE_BASEDIR_STOCKGCC_LOWEST="$TARGET_PREFIX/arch/broadwell/gcc-stock"
      source $VARIABLES_SOURCE_PATH
      if [ -f $SCRATCH_ROOT/_install_dest ]; then
        echo-green "echo $TARGET_PREFIX/arch/$MTUNE/${COMPILER_USED}/$PKGNAME/${MODULE_VERSION:-$VERSION}" > $SCRATCH_ROOT/_install_dest
      else
        ECHO="echo"
        $ECHO "echo $TARGET_PREFIX/arch/$MTUNE/${COMPILER_USED}/$PKGNAME/${MODULE_VERSION:-$VERSION}" > $SCRATCH_ROOT/_install_dest
      fi
        
      ;;
  esac
  if [ -f $SCRATCH_ROOT/_compiler_used ]; then
    echo-green "echo \"$COMPILER_USED\" > $SCRATCH_ROOT/_compiler_used"
  else
    $ECHO "echo \"$COMPILER_USED\" > $SCRATCH_ROOT/_compiler_used"
  fi

  if [ -f $SCRATCH_ROOT/_mpi_used ]; then
    echo-green "echo \"$COMPILER_USED\" > $SCRATCH_ROOT/_mpi_used"
  else
    $ECHO "echo \"$COMPILER_USED\" > $SCRATCH_ROOT/_mpi_used"
  fi
  #needs a file rather than an export because new sbatch loses this value at step 5
else
  #Path taken by non-uniform (all uniform routes create _install_dest)
  export COMPILER_USED
  export MPI_USED
  echo "$COMPILER_USED > $SCRATCH_ROOT/_compiler_used"
  echo "$MPI_USED > $SCRATCH_ROOT/_mpi_used"
  export PACKAGE_BASEDIR="$TARGET_PREFIX"
  source $VARIABLES_SOURCE_PATH
  INSTALL_DEST="$TARGET_PREFIX/$PKGNAME/${MODULE_VERSION:-$VERSION}"
  echo "$INSTALL_DEST > $SCRATCH_ROOT/_install_dest"
fi

if [ ! -z "${STEP_INTO_SUBDIR:-}" ]; then  #if non-empty value (-z)
  ADJUSTED_SRC="$SRC_DIR/${STEP_INTO_SUBDIR}"
else
  ADJUSTED_SRC="$SRC_DIR"
fi

if [ ${BUILD_IN_SRC_DIR} = true ]; then
  BUILD_DIR=$ADJUSTED_SRC
else
  BUILD_DIR=$SCRATCH_ROOT/objdir
  if [ -d $BUILD_DIR ]; then
    echo "mkdir -p $BUILD_DIR"
  fi #TODO
  simple_error_check
fi

#2.2
if [ ! -z "${CMAKE_ARGS:-}" ]; then  #if not empty (existence/empty implied via ":-")
  if [ -f "${ADJUSTED_SRC}/CMakeCache.txt" ]; then
    ECHO="echo-green"
  else
    ECHO="echo"
  fi

  if [ $DEPS_LOADED -ne ${#BUILD_DEPS[@]} ]; then
    ECHO="echo-yellow"
  else
    ECHO="echo"
  fi

  $ECHO "cd $ADJUSTED_SRC"

  if [ ! -z "${PRE_CONFIGURE_CMD:-}" ]; then  #if not empty (existence/empty implied via ":-")
    $ECHO "$PRE_CONFIGURE_CMD"
  fi

  $ECHO "cmake $CMAKE_ARGS ${ADJUSTED_SRC}"
fi

#2.3
if [ ! -z "${CONFIGURE_ARGS:-}" ]; then  #if not empty (existence/empty implied via ":-")
  if [ -f "${ADJUSTED_SRC}/config.status" ]; then
    ECHO="echo-green"
  else
    ECHO="echo"
  fi

  if [ $DEPS_LOADED -ne ${#BUILD_DEPS[@]} ]; then
    ECHO="echo-yellow"
  else
    ECHO="echo"
  fi

  $ECHO "cd $ADJUSTED_SRC"

  if [ ! -z "${PRE_CONFIGURE_CMD:-}" ]; then  #if not empty (existence/empty implied via ":-")
    $ECHO "$PRE_CONFIGURE_CMD"
  fi

  $ECHO "$ADJUSTED_SRC/configure $CONFIGURE_ARGS"
fi

#2.4
if [ ! -z "${POST_CONFIGURE_CMD:-}" ]; then  #if not empty (existence/empty implied via ":-")
  $ECHO "$POST_CONFIGURE_CMD"
fi

#################
# 3_build.sh
#################
echo-blue ""
echo-blue "# [3_build.sh] steps"
echo-blue ""

DEPS_LOADED=0

for dep in "${BUILD_DEPS[@]}"
do
  OUTPUT=$(modulecmd bash list -l 2>&1)
  if [ "$(echo $OUTPUT | grep "$dep")" ]; then
    DEPS_LOADED=$(($DEPS_LOADED+1))
    ECHO="echo-green"
  else
    ECHO="echo"
  fi
  if [ "$dep" ]; then
    $ECHO "module load $dep"
  fi
done

if [ $DEPS_LOADED -ne ${#BUILD_DEPS[@]} ]; then
  ECHO="echo-yellow"
else
  ECHO="echo"
fi

$ECHO "cd $ADJUSTED_SRC"

#3.1
if [ ! -z "${ALTERNATE_BUILD_COMMAND:-}" ]; then  #if not empty (existence/empty implied via ":-")
  #3.1a
  echo "$ALTERNATE_BUILD_COMMAND"
else
  #3.1b
  CONCURRENT_JOBS=${MAKE_JOBS:--j $MAKE_SIMUL_JOBS}
  $ECHO "make ${MAKE_ARGS:-} $CONCURRENT_JOBS"
fi

#3.2
if [ ! -z "${MAKE_TARGETS:-}" ]; then
  for dep in "${MAKE_TARGETS[@]}"
  do
    $ECHO "make $dep"
  done
fi

#################
# 4_install.sh
#################
echo-blue ""
echo-blue "# [4_install.sh] steps"
echo-blue ""

DEPS_LOADED=0

for dep in "${BUILD_DEPS[@]}"
do
  OUTPUT=$(modulecmd bash list -l 2>&1)
  if [ "$(echo $OUTPUT | grep "$dep")" ]; then
    DEPS_LOADED=$(($DEPS_LOADED+1))
    ECHO="echo-green"
  else
    ECHO="echo"
  fi
  $ECHO "module load $dep"
done

if [ $DEPS_LOADED -ne ${#BUILD_DEPS[@]} ]; then
  ECHO="echo-yellow"
else
  ECHO="echo"
fi

$ECHO "cd $ADJUSTED_SRC"

#4.1
if [ ! -z "${CONTENTS_TO_CP:-}" ]; then  #if not empty (existence/empty implied via ":-")
  #4.1a
  echo-red "sudo mkdir -p $DEST_FOR_CP"

  if [ ! -z "${CP_ONLY_WHITELISTED_FILES:-}" ]; then  #if not empty (existence/empty implied via ":-")
    for wlf in "${CP_ONLY_WHITELISTED_FILES[@]}"; do
      echo-red "sudo cp $CONTENTS_TO_CP/${wlf} $DEST_FOR_CP/"
    done
  else
    echo-red "sudo cp -R $CONTENTS_TO_CP/* $DEST_FOR_CP/"
  fi
else
  #4.1b
  echo-red "sudo make ${MAKE_INSTALL_ARGS:-} install"
fi

#################
# 5_make_module.sh
#################
echo-blue ""
echo-blue "# [5_make_module.sh] steps"
echo-blue ""

VERS=${MODULE_VERSION:-$VERSION}
MODULE_FILENAME=$MODULE_DIR/${PKGNAME}/${VERS}

if [ -f "${MODULE_FILENAME}" ]; then
  echo-green "#modulefile already exists: $MODULE_FILENAME"
else
  echo-red "#modulefile must be created: $MODULE_FILENAME"
fi

echo ""
echo-yellow "# ************************ #"
echo-yellow "# End build process"
echo-yellow "# ************************ #"

