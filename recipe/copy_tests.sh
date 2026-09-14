#!/bin/bash
set -ex

# Same layout as 'waf install --install-tests': contents of astest/ (without its wscript)
# go to share/aster/tests, which is where run_ctest and CTestTestfile.cmake look for them.
mkdir -p "${PREFIX}/share/aster/tests"
cp -r "${SRC_DIR}/astest/." "${PREFIX}/share/aster/tests/"
rm -f "${PREFIX}/share/aster/tests/wscript"
