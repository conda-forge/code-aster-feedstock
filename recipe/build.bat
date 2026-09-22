@echo on
setlocal enabledelayedexpansion

set CONFIG_PARAMETERS_addmem=5000

:: ifx for Fortran, clang-cl for C/C++ (MSVC ABI)
set FC=ifx.exe
set CC=clang-cl.exe
set CXX=clang-cl.exe

set ASTER_PLATFORM_MSVC64=1
set ASTER_PLATFORM_WINDOWS=1

set "LIB_ROOT=%LIBRARY_PREFIX:\=/%"
set "PREF_ROOT=%PREFIX:\=/%"
set "MKLROOT=%LIB_ROOT%"

set "LIBPATH_HDF5=%LIB_ROOT%/lib"
set "INCLUDES_HDF5=%LIB_ROOT%/include"
set "LIBPATH_MED=%LIB_ROOT%/lib"
set "INCLUDES_MED=%LIB_ROOT%/include"
set "LIBPATH_METIS=%LIB_ROOT%/lib"
set "INCLUDES_METIS=%LIB_ROOT%/include"
set "LIBPATH_MUMPS=%LIB_ROOT%/lib"
set "INCLUDES_MUMPS=%LIB_ROOT%/include %LIB_ROOT%/include/mumps_seq"
set "LIBPATH_SCOTCH=%LIB_ROOT%/lib"
set "INCLUDES_SCOTCH=%LIB_ROOT%/include"
set "LIBPATH_MGIS=%LIB_ROOT%/bin"
set "INCLUDES_MGIS=%LIB_ROOT%/include"
set "TFELHOME=%LIB_ROOT%"

:: /MD: link against the dynamic CRT; /FS: parallel writes to the shared .pdb
set "CFLAGS=%CFLAGS% /FS /MD"
:: C++20 for MGIS std::span
set "CXXFLAGS=/std:c++20 /EHs /permissive- /MD /FS"

:: code_aster Fortran is built with 64-bit default integers/reals (ASTER_INT8).
:: The conda-forge ifx MUMPS headers use explicit INTEGER(4), so its derived
:: types keep the library layout under /integer-size:64.
set "FCFLAGS=%FCFLAGS% /fpp /integer-size:64 /real-size:64 /MD /names:lowercase /assume:underscore /assume:nobscc /fpe:0 /traceback /nologo"

set "LDFLAGS=%LDFLAGS% /LIBPATH:%LIB_ROOT%/lib /LIBPATH:%LIB_ROOT%/bin /LIBPATH:%PREF_ROOT%/libs"
set "LDFLAGS=%LDFLAGS% mkl_intel_lp64_dll.lib mkl_intel_thread_dll.lib mkl_core_dll.lib libiomp5md.lib"
:: mpiseq is built into mumps_common on Windows
set "LDFLAGS=%LDFLAGS% mumps_common.lib dmumps.lib smumps.lib cmumps.lib zmumps.lib pord.lib"
set "LDFLAGS=%LDFLAGS% esmumps.lib scotch.lib scotcherr.lib scotcherrexit.lib metis.lib"
set "LDFLAGS=%LDFLAGS% med.lib medC.lib medfwrap.lib medimport.lib"

set "INCLUDES_BIBC=%PREF_ROOT%/include %SRC_DIR:\=/%/bibfor/include %INCLUDES_BIBC%"
set "DEFINES=H5_BUILT_AS_DYNAMIC_LIB _CRT_SECURE_NO_WARNINGS _SCL_SECURE_NO_WARNINGS WIN32_LEAN_AND_MEAN ASTER_PLATFORM_MSVC64 ASTER_INT8"

:: tell config/ifort.py to take the activated conda ifx environment
set "CONDA_BUILD_INTEL_FORTRAN=1"
:: ifx activation only sets FC: expose its runtime import libs (ifconsol.lib, ...),
:: its intrinsic modules and helper binaries from the build environment
set "PATH=%BUILD_PREFIX%\Library\bin\compiler;%PATH%"
set "LIB=%BUILD_PREFIX%\Library\lib;%LIB%"
set "INCLUDE=%BUILD_PREFIX%\opt\compiler\include\intel64;%INCLUDE%"

python "%RECIPE_DIR%\config\update_version.py"
if errorlevel 1 exit 1

waf configure ^
  --safe ^
  --check-fortran-compiler=ifort ^
  --med-libs="med medC medfwrap medimport" ^
  --prefix="%LIB_ROOT%" ^
  --out="%SRC_DIR%/build" ^
  --libdir="%LIBRARY_PREFIX%/lib" ^
  --bindir="%LIBRARY_PREFIX%/bin" ^
  --site-packages="%SP_DIR%" ^
  --disable-aster-subdir ^
  --enable-med ^
  --enable-hdf5 ^
  --enable-mumps ^
  --enable-metis ^
  --enable-scotch ^
  --enable-mfront ^
  --disable-mpi ^
  --disable-openmp ^
  --disable-petsc ^
  --maths-libs=auto ^
  --msvc-entry ^
  --without-hg ^
  --without-repo
if errorlevel 1 (
  type "%SRC_DIR%\build\config.log"
  exit 1
)

:: bibcxx's templated C++ (pybind11 bindings, Exceptions.h) is memory-hungry under
:: clang-cl; -j == full core count (e.g. 24 cores / 32 GB) OOMs the frontend
:: ("LLVM ERROR: out of memory"). Cap parallelism instead of using every core.
set /a JOBS=%CPU_COUNT%
if %JOBS% GTR 8 set JOBS=8

waf install -j %JOBS%
if errorlevel 1 exit 1

:: Run the code_aster testcases from the source tree against the installed
:: build, mirroring the run_ctest step of build.sh on Linux. See
:: config/run_win_testcases.py for the label/known-failures/rerun logic
:: (kept out of batch: delayed-expansion/quoting make that class of logic
:: much more error-prone here than in Python).
python "%RECIPE_DIR%\config\run_win_testcases.py"
if errorlevel 1 exit 1

endlocal
