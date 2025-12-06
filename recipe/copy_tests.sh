#!/bin/bash
set -ex

# Create the destination directory
mkdir -p "${PREFIX}/share/aster/tests"

# Copy the 'astest' folder from the source directory to the destination
cp -r "${SRC_DIR}/astest" "${PREFIX}/aster/tests/"