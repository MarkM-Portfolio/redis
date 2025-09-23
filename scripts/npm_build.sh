#!/bin/bash

set -ex

PACKAGE_VERSION=`node -e "console.log(require('./package.json').version)"`
BUILD_VERSION="${PACKAGE_VERSION}-${TIMESTAMP}"

echo "${BUILD_VERSION}" > ./.version

npm run build:tests
