#!/bin/bash
set -e

export CLICOLOR_FORCE=1

PATH=$PREFIX/bin:$PATH # to make /usr/bin/env find the right python interpreter
export PYTHONPATH=${PREFIX}/lib/python${PY_VER}/site-packages:$PYTHONPATH
export LD_LIBRARY_PATH=${PREFIX}/lib:$LD_LIBRARY_PATH


export BUILD=${SRC_DIR}/codeaster-prerequisites
cd $BUILD
source VERSION

export ROOT="$BUILD"
export ARCH=seq
export DEST="${BUILD}/dest"
cd ${SRC_DIR}
echo "**************** H D F 5  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/hdf5/
tar xzf ${BUILD}/archives/hdf5-${HDF5}.tar.gz -C ${BUILD}/hdf5/ --strip-components 1
cd ${BUILD}/hdf5
CFLAGS="-fPIC -DPIC ${CFLAGS}" \
    FCFLAGS="-fPIC -DPIC ${FCFLAGS}" \
    ./configure --enable-static=yes --enable-shared=no --enable-fortran=yes --prefix=${DEST}/hdf5-${HDF5}
make -j $CPU_COUNT
make install
cd ${SRC_DIR}

echo "**************** H D F 5  B U I L D  E N D S  H E R E ****************"

echo "**************** M E D  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/med/
tar xzf ${BUILD}/archives/med-${MED}.tar.gz -C ${BUILD}/med/ --strip-components 1
cd ${BUILD}/med
if [ ${MED} = "4.1.1" ]; then
    patch -p1 < ${BUILD}/patches/med-4.1.1-check-hdf5-with-tabs.diff
    patch -p1 < ${BUILD}/patches/med-4.1.1-check-hdf5-parallel.diff
fi
sed -i 's/.*find hdf5 library/##/' configure # disabling non-working check

# Set only fortran length for integer, C/C++ flags will be automatically adapted
FFLAGS="-fdefault-integer-8 -fPIC -DPIC ${FFLAGS}" \
    CFLAGS="-fPIC -DPIC ${CFLAGS}" \
    CPPFLAGS="-fPIC -DPIC ${CPPFLAGS}" \
    CXXFLAGS="-fPIC -DPIC ${CXXFLAGS}" \
    HDF5_CPPFLAGS="-fPIC -DPIC ${HDF5_CPPFLAGS}" \
    FFLAGS="-fPIC -DPIC ${FFLAGS}" \
    FCFLAGS="-fdefault-integer-8 -fPIC -DPIC ${FCFLAGS}" \
    F77=${FC} \
    CXXFLAGS='-std=gnu++98' \
    ./configure \
        --enable-mesgerr \
        --with-swig=no \
        --enable-static=yes \
        --enable-shared=no \
        --disable-python \
        --with-hdf5=${DEST}/hdf5-${HDF5} \
        --prefix=${DEST}/med-${MED}
make CPPFLAGS="-fPIC -DPIC ${CXXFLAGS}" CXXFLAGS="-fPIC -DPIC ${CXXFLAGS}" HDF5_CPPFLAGS="-fPIC ${HDF5_CPPFLAGS}" -j $CPU_COUNT
make install
cd ${SRC_DIR}

echo "**************** M E D  B U I L D  E N D S  H E R E ****************"
echo "**************** M E D C O U P L I N G  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/medcouping/
tar xzf ${BUILD}/archives/medcoupling-${MEDCOUPLING}.tar.gz -C ${BUILD}/medcouping/ --strip-components 1
cd ${BUILD}/medcouping/
mkdir -p ${BUILD}/medcouping/configuration
tar xzf ${BUILD}/archives/configuration-${MEDCOUPLING}.tar.gz -C ${BUILD}/medcouping/configuration --strip-components 1
mkdir -p ${BUILD}/medcouping/build
cd ${BUILD}/medcouping/build
cmake ${BUILD}/medcouping/ \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DCONFIGURATION_ROOT_DIR=${BUILD}/medcouping/configuration \
    -DLIBXML2_ROOT_DIR=${PREFIX} \
    -DPYTHON_ROOT_DIR=${PREFIX} \
    -DBOOST_ROOT_DIR=${PREFIX} \
    -DSWIG_ROOT_DIR=${PREFIX} \
    -Wno-dev \
    -DSALOME_CMAKE_DEBUG=OFF \
    -DSALOME_USE_MPI=OFF \
    -DMEDCOUPLING_BUILD_TESTS=OFF \
    -DMEDCOUPLING_BUILD_PY_TESTS=OFF \
    -DMEDCOUPLING_BUILD_DOC=OFF \
    -DMED_INT_IS_LONG=ON \
    -DMEDCOUPLING_USE_64BIT_IDS=ON \
    -DMEDCOUPLING_USE_MPI=OFF \
    -DMEDCOUPLING_MEDLOADER_USE_XDR=OFF \
    -DXDR_INCLUDE_DIRS="" \
    -DMEDCOUPLING_PARTITIONER_PARMETIS=OFF \
    -DMEDCOUPLING_PARTITIONER_METIS=OFF \
    -DMEDCOUPLING_PARTITIONER_SCOTCH=OFF \
    -DMEDCOUPLING_PARTITIONER_PTSCOTCH=OFF \
    -DMEDCOUPLING_ENABLE_PYTHON=ON \
    -DMEDCOUPLING_BUILD_STATIC=ON \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DHDF5_ROOT_DIR=${DEST}/hdf5-${HDF5} \
    -DMEDFILE_ROOT_DIR=${DEST}/med-${MED} \
    -DMPI_C_COMPILER:PATH=$(which mpicc) \
    -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON} \
    -DCMAKE_BUILD_TYPE=Release \
    ..
make -j $CPU_COUNT
make install

cd ${SRC_DIR}

echo "**************** M E D C O U P L I N G  B U I L D  E N D S  H E R E ****************"

echo "**************** H O M A R D  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/homard/
tar xzf ${BUILD}/archives/homard-${HOMARD}.tar.gz -C ${BUILD}/homard/ --strip-components 1
cd ${BUILD}/homard/
$PYTHON setup_homard.py --prefix=${PREFIX}/bin -en -v
cd ${SRC_DIR}

echo "**************** H O M A R D  B U I L D  E N D S  H E R E ****************"

echo "**************** A S R U N  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/asrun/
tar xzf ${BUILD}/archives/codeaster-frontend-${ASRUN}.tar.gz -C ${BUILD}/asrun/ --strip-components 1
cd ${BUILD}/asrun/
# add configuration for editor, terminal, platform...
cat << EOF > external_configuration.py
parameters = {
    "IFDEF": "LINUX64",
    "EDITOR": "gedit",
    "TERMINAL": "xterm",
    "CTAGS_STYLE": ""
}
EOF
PYTHONPATH=".:$PYTHONPATH" $PYTHON setup.py install --prefix=${PREFIX}
cd ${SRC_DIR}

echo "**************** A S R U N  B U I L D  E N D S  H E R E ****************"

echo "**************** M E T I S  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/metis/
tar xzf ${BUILD}/archives/metis-${METIS}.tar.gz -C ${BUILD}/metis/ --strip-components 1
cd ${BUILD}/metis
make config CFLAGS="-fPIC ${CFLAGS}" prefix=${DEST}/metis-${METIS}
make -j $CPU_COUNT
make install
cd ${SRC_DIR}

echo "**************** M E T I S  B U I L D  E N D S  H E R E ****************"

#echo "**************** S C O T C H  B U I L D  S T A R T S  H E R E ****************"
#
#mkdir -p ${BUILD}/scotch/
#tar xzf ${BUILD}/archives/scotch-${SCOTCH}.tar.gz -C ${BUILD}/scotch/ --strip-components 1
#cd ${BUILD}/scotch/src
#mkinc=Make.inc/Makefile.inc.x86-64_pc_linux2
#sed -e "s|CFLAGS\s*=|CFLAGS = ${CFLAGS} -Wl,--no-as-needed -DINTSIZE64|g" \
#     -e "s|CCD\s*=.*$|CCD = ${GCC}|g" \
#     -e "s|CCS\s*=.*$|CCS = ${GCC}|g" \
#     -e "s|LDFLAGS\s*=|LDFLAGS = -L${PREFIX}/lib |g" \
#     ${mkinc} > Makefile.inc
#make scotch -j $CPU_COUNT
#make esmumps -j $CPU_COUNT
#mkdir -p ${DEST}/scotch-${SCOTCH}
#make install prefix=${DEST}/scotch-${SCOTCH}
#cd ${SRC_DIR}
#
#echo "**************** S C O T C H  B U I L D  E N D S  H E R E ****************"

#echo "**************** P A R M E T I S  B U I L D  S T A R T S  H E R E ****************"

#mkdir -p ${BUILD}/parmetis/
#tar xzf ${BUILD}/archives/parmetis-${PARMETIS}.tar.gz -C ${BUILD}/parmetis/ --strip-components 1
#cd ${BUILD}/parmetis/
#make config CFLAGS="-fPIC ${CFLAGS}" prefix=${DEST}/parmetis-${PARMETIS}
#make -j $CPU_COUNT
#make install
#cd ${SRC_DIR}

#echo "**************** P A R M E T I S  B U I L D  E N D S  H E R E ****************"

echo "**************** M U M P S  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/mumps/
tar xzf ${BUILD}/archives/mumps-${MUMPS_GPL}.tar.gz -C ${BUILD}/mumps/ --strip-components 1
cd ${BUILD}/mumps/

CFLAGS="-DUSE_SCHEDAFFINITY -Dtry_null_space ${CFLAGS}" \
    FCFLAGS="-DUSE_SCHEDAFFINITY -Dtry_null_space -fallow-argument-mismatch ${FCFLAGS}" \
    LIBPATH="${PREFIX}/lib ${DEST}/metis-${METIS}/lib ${DEST}/parmetis-${PARMETIS}/lib ${DEST}/scotch-${SCOTCH}/lib $LIBPATH" \
    INCLUDES="${PREFIX}/include ${DEST}/metis-${METIS}/include ${DEST}/parmetis-${PARMETIS}/include ${DEST}/scotch-${SCOTCH}/include $INCLUDES" \
    $PYTHON ./waf configure --enable-openmp \
               --enable-metis \
               --embed-metis \
               --disable-parmetis \
               --disable-scotch \
               --install-tests \
               --prefix=${DEST}/mumps-${MUMPS_GPL}

$PYTHON ./waf build --jobs=1
$PYTHON ./waf install --jobs=1

cd ${SRC_DIR}

echo "**************** M U M P S  B U I L D  E N D S  H E R E ****************"

echo "**************** A S T E R  B U I L D  S T A R T S  H E R E ****************"

$PYTHON "${RECIPE_DIR}/config/update_version.py"

export CONFIG_PARAMETERS_addmem=3000

export LIBPATH_PETSC="$PREFIX/lib"
export INCLUDES_PETSC="$PREFIX/include"

export INCLUDES_BOOST=$PREFIX/include
export LIBPATH_BOOST=$PREFIX/lib
export LIB_BOOST="libboost_python$CONDA_PY"

export INCLUDES_HDF5="${DEST}/hdf5-${HDF5}/include"
export LIBPATH_HDF5="${DEST}/hdf5-${HDF5}/lib"

export INCLUDES_MED="${DEST}/med-${MED}/include"
export LIBPATH_MED="${DEST}/med-${MED}/lib"

export LIBPATH_MEDCOUPLING="$PREFIX/lib"
export INCLUDES_MEDCOUPLING="$PREFIX/include"
export PYPATH_MEDCOUPLING=$SP_DIR

export TFELHOME=$PREFIX

export LIBPATH_METIS="${DEST}/metis-${METIS}/lib $PREFIX/lib"
export INCLUDES_METIS="${DEST}/metis-${METIS}/include $PREFIX/include"

export LIBPATH_MUMPS="${DEST}/mumps-${MUMPS_GPL}/lib $PREFIX/lib"
export INCLUDES_MUMPS="${DEST}/mumps-${MUMPS_GPL}/include $PREFIX/include ${DEST}/mumps-${MUMPS_GPL}/include_seq"

LDFLAGS="-Wl,--no-as-needed -L${DEST}/med-${MED}/lib -lmed -L${DEST}/hdf5-${HDF5}/lib -lhdf5 -lz -ldl -lm ${LDFLAGS}" \
    FCFLAGS="-fallow-argument-mismatch ${FCFLAGS}" \
    ./waf_std \
     --python=$PYTHON \
     --prefix="${PREFIX}" \
     --libdir="${PREFIX}/lib" \
     --enable-metis \
     --embed-metis \
     --enable-mumps \
     --embed-mumps \
     --enable-mfront \
     --enable-med \
     --embed-med \
     --enable-hdf5 \
     --embed-hdf5 \
     --embed-aster \
     --disable-mpi \
     --disable-petsc \
     --without-hg \
     --without-repo \
     configure

./waf_std build -j $CPU_COUNT

./waf_std --python=$PYTHON install

# mkdir -p $PREFIX/share/aster/tests
# cp ./astest/forma01a.* $PREFIX/share/aster/tests
# cp ./astest/sslp114a.* $PREFIX/share/aster/tests
# cp ./astest/mumps05a.* $PREFIX/share/aster/tests
# cp ./astest/mumps01a.* $PREFIX/share/aster/tests
# cp ./astest/erreu03a.* $PREFIX/share/aster/tests
# cp ./astest/umat001a.* $PREFIX/share/aster/tests
# cp ./astest/zzzz121a.* $PREFIX/share/aster/tests
# cp ./astest/mfron01a.* $PREFIX/share/aster/tests
# cp ./astest/*.mfront $PREFIX/share/aster/tests


ln -rs $PREFIX/share/aster $PREFIX/stable
cp -R ${SRC_DIR}/code_aster ${SP_DIR}

find $PREFIX -name "profile.sh" -exec sed -i 's/PYTHONHOME=/#PYTHONHOME=/g' {} \;
find $PREFIX -name "profile.sh" -exec sed -i 's/export PYTHONHOME/#export PYTHONHOME/g' {} \;

echo "**************** A S T E R  B U I L D  E N D S  H E R E ****************"

echo "**************** C L E A N U P  S T A R T S  H E R E ****************"

rm -Rf $BUILD

echo "**************** C L E A N U P  E N D S  H E R E ****************"
