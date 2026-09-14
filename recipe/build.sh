#!/bin/bash

bash "${RECIPE_DIR}/build_homard.sh"

echo "mpi = ${mpi}"

export CONFIG_PARAMETERS_addmem=2000
export TFELHOME=${PREFIX}

export LIBPATH_METIS="${PREFIX}/lib"
export INCLUDES_METIS="${PREFIX}/include"

export LIBPATH_PETSC="${PREFIX}/lib"
export INCLUDES_PETSC="${PREFIX}/include"

export INCLUDES_BOOST=${PREFIX}/include
export LIBPATH_BOOST=${PREFIX}/lib

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
    --site-packages="${SP_DIR}" \
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
  # The UCX byte transfer layer reserves a huge virtual address space during MPI_Init on
  # machines with many cores, which fails the VmSize check of 'waf configure' (> 10 GB).
  export OMPI_MCA_btl=^uct

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
    --site-packages="${SP_DIR}" \
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

# The testcases are shipped in the separate noarch code-aster-tests output.
# '--install-tests' is still passed so config.txt and CTestTestfile.cmake reference
# the installed location (share/aster/tests) instead of a symlink into the build tree.
rm -rf "${PREFIX}/share/aster/tests"

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

# Run the code_aster testcases from the source tree against the installed build.
# ASTER_BUILD_TESTS: ctest label to run, "submit" (default), "verification" (full suite) or "none".
# Only the testcases matching the build are selected ("sequential" for nompi, all for mpi).
if [[ "${ASTER_BUILD_TESTS}" != "none" ]]; then
  export PATH="${PREFIX}/bin:${PATH}"
  export OMPI_ALLOW_RUN_AS_ROOT=1
  export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

  known_failures="${SRC_DIR}/known_failures.list"
  cat "${RECIPE_DIR}/known_failures.list" > "${known_failures}"
  if [[ "$mpi" == "nompi" ]]; then
    cat "${RECIPE_DIR}/known_failures_nompi.list" >> "${known_failures}"
  else
    cat "${RECIPE_DIR}/known_failures_mpi.list" >> "${known_failures}"
  fi

  jobs=${CPU_COUNT:-2}
  mem_mb=$(awk '/MemTotal/ {print int($2 / 1024)}' /proc/meminfo)
  ctest_args=(
    --testdir="${SRC_DIR}/astest"
    --resutest="${SRC_DIR}/build_testcases"
    --clean
    --jobs="${jobs}"
    --memory-per-slot="$(( mem_mb / jobs ))"
    --timefactor=4.0
    --only-failed-results
    --exclude-testlist="${known_failures}"
    -L "${ASTER_BUILD_TESTS}"
    -LE need_data
  )
  echo "Running code_aster testcases: run_ctest ${ctest_args[*]}"
  # rerun failed testcases twice, as done in code_aster CI
  if ! { run_ctest "${ctest_args[@]}" \
      || run_ctest "${ctest_args[@]}" --rerun-failed \
      || run_ctest "${ctest_args[@]}" --rerun-failed; }; then
    # print the diagnostics of the failed testcases, their output files are not kept by CI
    failed_list="${SRC_DIR}/build_testcases/Testing/Temporary/LastTestsFailed.log"
    for name in $(sed -e 's/^[0-9]*:ASTER_[0-9.]*_//' "${failed_list}"); do
      mess="${SRC_DIR}/build_testcases/${name}.mess"
      echo "::group::code_aster testcase ${name}"
      if [[ -f "${mess}" ]]; then
        grep -nE "<F>|<E>|<EXCEPTION>|NOOK|Traceback|Error|DIAGNOSTIC JOB" "${mess}" | head -n 40
        echo "--- last lines of ${name}.mess:"
        tail -n 80 "${mess}"
      else
        echo "no output file for ${name}"
      fi
      echo "::endgroup::"
    done
    echo "code_aster testcases failed"
    exit 1
  fi
fi
