#!/usr/bin/env bash

# https://docs.conda.io/projects/conda/en/latest/dev-guide/deep-dives/activation.html

export PYTHONPATH="${CONDA_PREFIX}/lib/aster:${CONDA_PREFIX}/lib:${PYTHONPATH}"
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib/aster:${CONDA_PREFIX}/lib/petsc4py/lib:${LD_LIBRARY_PATH}"

# Not sure if these really matter
export C_INCLUDE_PATH="${CONDA_PREFIX}/include/aster:${CONDA_PREFIX}/lib/petsc4py/include:${C_INCLUDE_PATH}"
export CPLUS_INCLUDE_PATH="${CONDA_PREFIX}/include/aster:${CONDA_PREFIX}/lib/petsc4py/include:${CPLUS_INCLUDE_PATH}"

export ASTER_LIBDIR="$CONDA_PREFIX/lib/aster"
export ASTER_DATADIR="$CONDA_PREFIX/share/aster"
export ASTER_LOCALEDIR="$CONDA_PREFIX/share/locale/aster"
export ASTER_ELEMENTSDIR="$CONDA_PREFIX/lib/aster"
