#!/usr/bin/env bash
set -e

## The invocation of the script happens as a consequence of the first step of appimage-builder.yml


## This script is used by the image generated by builder.Dockerfile to create the AppImage for sast-scan
## if you want to use this standalone, ensure ARCH is set to the right architecture, currently it has only
## been tested on x86_64 and arm64
## Fail if ARCH is not set
if [ -z "$ARCH" ]; then
    echo "ARCH is not set, please set it to the architecture you want to build for"
    exit 1
fi

## mayberm deletes the passed file only if KEEP_BUILD_ARTIFACTS variable is not set
mayberm() {
    if [ -z "$KEEP_BUILD_ARTIFACTS" ]; then
        rm "$1"
    fi
}

## App Versions
GOSEC_VERSION=2.17.0
TFSEC_VERSION=1.28.1
KUBESEC_VERSION=2.13.0
KUBE_SCORE_VERSION=1.17.0
DETEKT_VERSION=1.23.1
GITLEAKS_VERSION=8.17.0
SC_VERSION=2023.1.5 # 0.4.5, staticcheck actually uses date versions now
PMD_VERSION=6.55.0
FSB_VERSION=1.12.0
SB_CONTRIB_VERSION=7.4.7
SB_VERSION=4.7.3
NODE_VERSION=18.17.1

# Account for non conventional Arch names in downloadables
if [ "$ARCH" = "x86_64" ]; then
    NODE_ARCH="x64"
else
    NODE_ARCH="$ARCH"
fi
if [ "$ARCH" = "x86_64" ]; then
    ARCH_ALT_NAME="amd64"
else
    ARCH_ALT_NAME="$ARCH"
fi
if [ "$ARCH" = "aarch64" ]; then
    LIBARCH="arm64"
else
    LIBARCH="$ARCH"
fi

## First parameter is the path to the AppDir where all the building happens, you can use whatever path you want
## but it needs to be the same as the one in appimage-builder.yml if you are using it too.
APPDIR=$1
echo "AppDir is ${APPDIR}"


## Remove any previous build
if [ -z "$KEEP_BUILD_ARTIFACTS" ]; then
        rm -rf "${APPDIR}"
        mkdir -p "${APPDIR}"
else
        echo "Keeping build artifacts from previous build"
fi

## Make usr and icons dirs
mkdir -p "${APPDIR}"/usr/src
mkdir -p "${APPDIR}"/usr/local/lib/"${LIBARCH}"-linux-gnu
mkdir -p "${APPDIR}"/usr/share/{metainfo,icons}

## Ensure the required folders exist.
USR_BIN_PATH=${APPDIR}/usr/bin/
OPTDIR=${APPDIR}/opt
mkdir -p "$USR_BIN_PATH"
mkdir -p "$OPTDIR"

## Ensure our binaries to be downloaded are in the path.
export PATH=$PATH:${USR_BIN_PATH}:${USR_BIN_PATH}/nodejs/bin

echo $PWD

## Download and install nodeJS (https://nodejs.org)
NODE_TAR=node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz
# if file not there, download it
if [ ! -f "${NODE_TAR}" ]; then
    echo "Downloading ${NODE_TAR}"
    curl -LO "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TAR}"
fi
if [ ! -d "${USR_BIN_PATH}"nodejs/node-v${NODE_VERSION}-linux-"${NODE_ARCH}" ]; then
    echo "Installing ${NODE_TAR}"
    tar -C "${USR_BIN_PATH}" -xzf "${NODE_TAR}"
    mv -f "${USR_BIN_PATH}"node-v${NODE_VERSION}-linux-"${NODE_ARCH}" "${USR_BIN_PATH}"nodejs
    chmod +x "${USR_BIN_PATH}"nodejs/bin/node
    chmod +x "${USR_BIN_PATH}"nodejs/bin/npm
    mayberm "${NODE_TAR}"
else
    echo "NodeJS already installed"
fi


## Download and install gosec (https://github.com/securego/gosec)
GOSEC_TAR="gosec_${GOSEC_VERSION}_linux_${ARCH_ALT_NAME}.tar.gz"
    echo "Downloading ${GOSEC_TAR}"
    curl -LO "https://github.com/securego/gosec/releases/download/v${GOSEC_VERSION}/${GOSEC_TAR}"
    tar -C "${USR_BIN_PATH}" -xzvf "${GOSEC_TAR}"
    chmod +x "${USR_BIN_PATH}"gosec
    mayberm "${GOSEC_TAR}"

## Download and install staticcheck (https://github.com/dominikh/go-tools)
STCHECK_TAR="staticcheck_linux_${ARCH_ALT_NAME}.tar.gz"
    echo "Downloading ${STCHECK_TAR}"
    curl -LO "https://github.com/dominikh/go-tools/releases/download/${SC_VERSION}/${STCHECK_TAR}"
    tar -C /tmp -xzvf "${STCHECK_TAR}"
    chmod +x /tmp/staticcheck/staticcheck
    cp /tmp/staticcheck/staticcheck "${USR_BIN_PATH}"staticcheck
    mayberm "${STCHECK_TAR}"

## Download and install gitleaks (https://github.com/zricethezav/gitleaks)
GLEAKS_FOLDER="gitleaks_${GITLEAKS_VERSION}_linux_${NODE_ARCH}"
GLEAKS_TAR="${GLEAKS_FOLDER}.tar.gz"
echo "Downloading ${GLEAKS_TAR}"
curl -LO "https://github.com/zricethezav/gitleaks/releases/download/v${GITLEAKS_VERSION}/${GLEAKS_TAR}"
mkdir -p /tmp/${GLEAKS_FOLDER}
tar -C /tmp/${GLEAKS_FOLDER} -xzvf "${GLEAKS_TAR}"
cp /tmp/${GLEAKS_FOLDER}/gitleaks "${USR_BIN_PATH}"gitleaks
chmod +x "${USR_BIN_PATH}"gitleaks

## Download and install tfsec (https://github.com/aquasecurity/tfsec)
TFSEC_TAR="tfsec-linux-${ARCH}"
echo "Downloading ${TFSEC_TAR}"
curl -L "https://github.com/aquasecurity/tfsec/releases/download/v${TFSEC_VERSION}/${TFSEC_TAR}" -o "${USR_BIN_PATH}tfsec"
chmod +x "${USR_BIN_PATH}"tfsec

## Download and install kube-score (https://github.com/zegl/kube-score)
K8SCORE_TAR="kube-score_${KUBE_SCORE_VERSION}_linux_${ARCH}"
echo "Downloading ${K8SCORE_TAR}"
curl -L "https://github.com/zegl/kube-score/releases/download/v${KUBE_SCORE_VERSION}/${K8SCORE_TAR}" -o "${USR_BIN_PATH}kube-score"
chmod +x "${USR_BIN_PATH}"kube-score

## Download and install pmd (https://github.com/pmd/pmd)
PMD_ZIP=pmd-bin-${PMD_VERSION}.zip
if [ ! -f "${PMD_ZIP}" ]; then
    echo "Downloading ${PMD_ZIP}"
    wget "https://github.com/pmd/pmd/releases/download/pmd_releases%2F${PMD_VERSION}/${PMD_ZIP}"
fi
if [ ! -d "${OPTDIR}"/pmd-bin ]; then
    echo "Installing ${PMD_ZIP}"
    unzip -q pmd-bin-${PMD_VERSION}.zip -d "${OPTDIR}"/
    mv -f "${OPTDIR}"/pmd-bin-${PMD_VERSION} "${OPTDIR}"/pmd-bin
    mayberm ${PMD_ZIP}
else
    echo "PMD already installed"
fi

## Download and install kubesec (https://github.com/controlplaneio/kubesec)
K8SSEC_TAR="kubesec_linux_${ARCH_ALT_NAME}.tar.gz"
if [ ! -f "${K8SSEC_TAR}" ]; then
    echo "Downloading ${K8SSEC_TAR}"
    curl -LO "https://github.com/controlplaneio/kubesec/releases/download/v${KUBESEC_VERSION}/${K8SSEC_TAR}"
fi
echo "Installing ${K8SSEC_TAR}"
tar -C "${USR_BIN_PATH}" -xzvf "${K8SSEC_TAR}"
mayberm "${K8SSEC_TAR}"

## Download and install detekt (https://github.com/detekt/detekt)
curl -L "https://github.com/detekt/detekt/releases/download/v${DETEKT_VERSION}/detekt-cli-${DETEKT_VERSION}-all.jar" -o "${USR_BIN_PATH}detekt-cli.jar"

# SpotBugs ---------------------------------------------------------------
## Download and install spotbugs (https://github.com/spotbugs/spotbugs)
SPOTBUGS_TGZ="spotbugs-${SB_VERSION}.tgz"
SPOTBUGS_OPTDIR="${OPTDIR}/spotbugs-${SB_VERSION}"
if [ ! -d "${OPTDIR}"/spotbugs ]; then
    echo "Downloading ${SPOTBUGS_TGZ}"
    curl -LO "https://github.com/spotbugs/spotbugs/releases/download/${SB_VERSION}/${SPOTBUGS_TGZ}"
    tar -C "${OPTDIR}" -xzvf spotbugs-${SB_VERSION}.tgz
    rm ${SPOTBUGS_TGZ}

    ## Download and install findsecbugs plugin for spotbugs (https://find-sec-bugs.github.io/)
    curl -LO "https://repo1.maven.org/maven2/com/h3xstream/findsecbugs/findsecbugs-plugin/${FSB_VERSION}/findsecbugs-plugin-${FSB_VERSION}.jar"
    mv -f findsecbugs-plugin-${FSB_VERSION}.jar "${SPOTBUGS_OPTDIR}"/plugin/findsecbugs-plugin.jar

    ## Download and install sb-contrib plugin for spotbugs (https://github.com/mebigfatguy/fb-contrib)
    curl -LO "https://repo1.maven.org/maven2/com/mebigfatguy/sb-contrib/sb-contrib/${SB_CONTRIB_VERSION}/sb-contrib-${SB_CONTRIB_VERSION}.jar"
    mv -f sb-contrib-${SB_CONTRIB_VERSION}.jar "${SPOTBUGS_OPTDIR}"/plugin/sb-contrib.jar

    mv -f "${SPOTBUGS_OPTDIR}" "${OPTDIR}"/spotbugs
else
    echo "SpotBugs already installed"
fi

# End SpotBugs -----------------------------------------------------------

## install composer
if [ ! -f composer-setup.php ]; then
    echo "Downloading composer"
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
fi
php composer-setup.php
mv -f composer.phar "${USR_BIN_PATH}"composer
mayberm composer-setup.php

# Install application dependencies
npm install --no-audit --progress=false --omit=dev --production --no-save --prefix "${APPDIR}"/usr/local/lib yarn @cyclonedx/cdxgen @microsoft/rush
mkdir -p "${APPDIR}"/opt/phpsast
pushd "${APPDIR}"/opt/phpsast
composer init --name shiftleft/scan --description scan --quiet
composer require --quiet --no-cache -n --no-ansi --dev vimeo/psalm:^5.15
popd
python3 -m pip install -v --prefix=/usr --root="${APPDIR}" -r "${PWD}"/requirements.txt --no-warn-script-location --exists-action=i
composer require --quiet --no-cache --dev phpstan/phpstan

## Copy the python application code into the AppDir if APPIMAGE is set
if [ -n "${APPIMAGE}" ]; then
  cp -r scan lib tools_config "${APPDIR}"/usr/src
  cp tools_config/scan.png "${APPDIR}"/usr/share/icons/
  cp tools_config/io.shiftleft.scan.appdata.xml "${APPDIR}"/usr/share/metainfo/
fi
