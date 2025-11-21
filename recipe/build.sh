#!/bin/bash

echo "mpi = ${mpi}"
echo "build_type = ${build_type}"

export CONFIG_PARAMETERS_addmem=2000
export TFELHOME=${PREFIX}

export LIBPATH_METIS="${PREFIX}/lib"
export INCLUDES_METIS="${PREFIX}/include"

export LIBPATH_PETSC="${PREFIX}/lib"
export INCLUDES_PETSC="${PREFIX}/include"

export INCLUDES_BOOST=${PREFIX}/include
export LIBPATH_BOOST=${PREFIX}/lib
export LIB_BOOST="libboost_python$CONDA_PY"

export INCLUDES_MUMPS="${PREFIX}/include"
if [[ "$mpi" == "nompi" ]]; then
  export INCLUDES_MUMPS="${INCLUDES_MUMPS} ${PREFIX}/include/mumps_seq"
fi
export LIBPATH_MUMPS="${PREFIX}/lib"

export INCLUDES_MED="${PREFIX}/include"
export LIBPATH_MED="${PREFIX}/lib"

export LIBPATH_MEDCOUPLING="${PREFIX}/lib"
export INCLUDES_MEDCOUPLING="${PREFIX}/include"
export PYPATH_MEDCOUPLING=${SP_DIR}

python ${RECIPE_DIR}/config/update_version.py

mpi_type=std
if [[ "$mpi" != "nompi" ]]; then
  mpi_type=mpi
fi


echo "Debugging Disabled"
build_type=release

# if gfortran version > 9, we need to conditionally add -fallow-argument-mismatch
# to avoid mismatch errors related to floats and integer types
major_version=$($FC -dumpversion | awk -F. '{print $1}')
if [[ $major_version -gt 9 ]]; then
  echo "adding -fallow-argument-mismatch to FCFLAGS"

  export FCFLAGS="-fallow-argument-mismatch ${FCFLAGS}"
  export FFLAGS="-fallow-argument-mismatch ${FFLAGS}"
else
  echo "FCFLAGS: $FCFLAGS"
  echo "FFLAGS: $FFLAGS"
fi

echo "Using 64-bit integer type"
export "DEFINES=${DEFINES} ASTER_INT8"


if [[ "$mpi" == "nompi" ]]; then

  # Install for standard sequential
  waf \
    --use-config-dir=${SRC_DIR}/config/ \
    --prefix="${PREFIX}" \
    --med-libs="med medC medfwrap medimport" \
    --enable-med \
    --enable-hdf5 \
    --enable-mumps \
    --enable-metis \
    --mumps-libs="cmumps_seq dmumps_seq smumps_seq zmumps_seq pord_seq mumps_common_seq mpiseq_seq" \
    --enable-scotch \
    --enable-mfront \
    --libdir="${PREFIX}/lib" \
    --spdir="${SP_DIR}" \
    --disable-aster-subdir \
    --install-tests \
    --disable-mpi \
    --disable-petsc \
    --without-hg \
    configure

    echo "Debugging Disabled"
    waf install
else
  export PYTHONPATH="$PYTHONPATH:${PREFIX}/lib"
  export CONFIG_PARAMETERS_addmem=4096

  export ENABLE_MPI=1
  export CC=mpicc
  export CXX=mpicxx
  export FC=mpif90
  export F77=mpif77
  export F90=mpif90
  export OPAL_PREFIX=${PREFIX}

  waf configure \
    --use-config-dir=${SRC_DIR}/config/ \
    --enable-med \
    --enable-hdf5 \
    --enable-mumps \
    --enable-metis \
    --enable-scotch \
    --enable-mfront \
    --med-libs="med medC medfwrap medimport" \
    --prefix="${PREFIX}" \
    --enable-mpi \
    --libdir="${PREFIX}/lib" \
    --spdir="${SP_DIR}" \
    --disable-aster-subdir \
    --install-tests \
    --without-hg


  if [[ "${build_type}" == "debug" ]]; then
      waf install_debug
  else
      waf install
  fi
fi

echo "Compilation complete"

# With --spdir option, Python packages and extensions are installed directly to ${SP_DIR}:
# - code_aster/ and run_aster/ Python packages -> ${SP_DIR}
# - aster.so, aster_core.so, aster_fonctions.so -> ${SP_DIR}
# - elem.1 catalog file -> ${SP_DIR}
#
# C/C++/Fortran shared libraries remain in ${PREFIX}/lib:
# - libbibfor.so, libbibfor_ext.so, libbibcxx.so, libbibc.so, libAsterGC.so, libAsterMFrOfficial.so

ASTER_LIBDIR="${PREFIX}/lib"
echo "All Python files installed to: ${SP_DIR}"
echo "Shared libraries installed to: ${ASTER_LIBDIR}"

export LD_LIBRARY_PATH="${ASTER_LIBDIR}"

# Everything should already be in the right place!
# No file moving needed when using --spdir and --disable-aster-subdir




