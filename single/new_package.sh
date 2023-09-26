#!/bin/bash

PKGNAME=$1
VERSION=$2

if [[ $UID != 0 ]]; then
  echo "Please run this script with sudo:"
  echo "sudo $0 \$PKGNAME \$VERSION"
  exit 1
fi

WHOIAM=$(whoami)
if (( EUID == 0 )); then
    WHOIAM=${SUDO_USER}
fi

cd buildscripts/single
./update_variables.sh
cd ../..

if [ -d "${PKGNAME}" ]; then
  cp -R template/0.0.1 ${PKGNAME}/${VERSION}
  chown -R $WHOIAM:rcadmins ${PKGNAME}/${VERSION}
else
  cp -R template ${PKGNAME}
  mv ${PKGNAME}/0.0.1 ${PKGNAME}/${VERSION}
  chown -R $WHOIAM:rcadmins ${PKGNAME}
fi

sed -i "s+^PKGNAME=.*+PKGNAME=${PKGNAME}+" ${PKGNAME}/${VERSION}/variables.source
sed -i "s+^VERSION=.*+VERSION=${VERSION}+" ${PKGNAME}/${VERSION}/variables.source

echo ""
echo "A new template has been created at ${PKGNAME}/${VERSION}"
echo ""
echo "\`cd ${PKGNAME}/${VERSION}\`   #enter the build directory"
echo "\`vi variables.source\`   #fill in necessary build info."
echo "Afterward, run each of the build scripts to complete compilation."
echo ""
echo "./0_download.sh"
echo "./1_untar.sh"
echo "./2_configure.sh"
echo "./3_build.sh"
echo "./4_install.sh"
echo "./5_make_module.sh"

