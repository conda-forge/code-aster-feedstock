#!/usr/bin/env bash

# Remove paths from PYTHONPATH
export PYTHONPATH=$(echo $PYTHONPATH | sed "s|${CONDA_PREFIX}/lib/aster:||g")
export PYTHONPATH=$(echo $PYTHONPATH | sed "s|${CONDA_PREFIX}/lib:||g")

# Remove paths from LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed "s|${CONDA_PREFIX}/lib/aster:||g")
export LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | sed "s|${CONDA_PREFIX}/lib/petsc4py/lib:||g")

# Remove paths from C_INCLUDE_PATH
export C_INCLUDE_PATH=$(echo $C_INCLUDE_PATH | sed "s|${CONDA_PREFIX}/include/aster:||g")
export C_INCLUDE_PATH=$(echo $C_INCLUDE_PATH | sed "s|${CONDA_PREFIX}/lib/petsc4py/include:||g")

# Remove paths from CPLUS_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$(echo $CPLUS_INCLUDE_PATH | sed "s|${CONDA_PREFIX}/include/aster:||g")
export CPLUS_INCLUDE_PATH=$(echo $CPLUS_INCLUDE_PATH | sed "s|${CONDA_PREFIX}/lib/petsc4py/include:||g")

# Unset ASTER environment variables
unset ASTER_LIBDIR
unset ASTER_DATADIR
unset ASTER_LOCALEDIR
unset ASTER_ELEMENTSDIR
