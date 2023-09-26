#!/bin/bash

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
PKGNAME=""
ENVIRONMENTS=("$PACKAGE_ENV")
STOCK=0
INSTALLSD=0
GO=0

while getopts "h?igp:v:e:is" opt; do
    case "$opt" in
    h|\?)
        echo "Syntax: ./build.sh -p PKGNAME -v VER,VER -e ENV,ENV -i -g"
        echo ""
        echo "-p PKGNAME       Package name  (-p gcc)"
        echo "-v VERSION       Versions to compile (-v 7.3.0) (-v 7.3.0,6.4.0)"
        echo "-e ENVIRONMENTS  Environments to build for (-e broadwell) (-e broadwell,skylake)"
        echo "-s               Do only stock variables.source build"
        echo "-i               Recurse into installs.d directory"
        echo "-g               Actually submit jobs to slurm"
        exit 0
        ;;
    s)  STOCK=1
        ;;
    i)  INSTALLSD=1
        ;;
    g)  GO=1
        ;;
    p)  PKGNAME=$OPTARG
        ;;
    v)  VERSIONS=(${OPTARG//,/ })
        ;;
    e)  ENVIRONMENTS=(${OPTARG//,/ })
        ;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

# START OF ARGCHECK

if [ -z "$PKGNAME" ]; then
  echo "Please provide -p PACKAGENAME"
  exit 1
elif [ -z "$VERSIONS" ]; then
  echo "Please provide -v VERSIONS (7.3.0,6.4.0)"
  exit 1
elif [ -z "$ENVIRONMENTS" ]; then
  echo "Please provide -e ENVIRONMENTS (broadwell,skylake,phi)"
  exit 1
fi

# START OF DISPATCHING
source ../../header.source
source ../../module.source

if [ ! -d $TARGET_PREFIX/build/$PKGNAME ]; then
  echo "Package name \"$PKGNAME\" provided, but not found: aborting."
  exit 1
fi

echo ""
echo-green "Package: $PKGNAME"
echo ""

for e in "${ENVIRONMENTS[@]}"; do
  #echo "* $e"
  export PACKAGE_ENV=$e
  source ../../module.source

  if [ "$STOCK" = "1" ]; then
    for v in "${VERSIONS[@]}"; do
      if [ -d $TARGET_PREFIX/build/$PKGNAME/$v ]; then
        echo "  | $PKGNAME/$v"
        if [ "$GO" = 1 ]; then
          cd $TARGET_PREFIX/build/$PKGNAME/$v
          ../../buildscripts/single/sbatch.sh $PKGNAME $v
        fi
      else
        echo "Version $v not found, aborting."
        exit 1
      fi
    done
  fi

  if [ "$INSTALLSD" = "1" ]; then
    for v in "${VERSIONS[@]}"; do
      if [ -d $TARGET_PREFIX/build/$PKGNAME/$v ]; then
        if [ -d "/packages/uniform/build/$PKGNAME/$v/installs.d" ]; then
          for fn in $( ls /packages/uniform/build/$PKGNAME/$v/installs.d ); do
            echo "  | $PKGNAME/$v ($fn)"
            if [ "$GO" = 1 ]; then
              cd $TARGET_PREFIX/build/$PKGNAME/$v
              ../../buildscripts/single/sbatch.sh $PKGNAME $v $fn
            fi
          done
        fi
      else
        echo "Version $v not found, aborting."
        exit 1
      fi
    done
  fi
done

if [ "$GO" = 0 ]; then
  echo ""
  echo "This is a dry-run: add \`-g\` (go) switch to submit jobs"
fi
echo ""

if [ "$STOCK" -eq 0 ] && [ "$INSTALLSD" -eq 0 ]; then
  echo "Not seeing any results? Make sure to include"
  echo "      -s (standard variables.source)"
  echo "or    -i (installs.d variants)"
  echo ""
  exit 1
fi

#echo "Leftovers: $@"
# End of file
