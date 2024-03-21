#!/bin/bash
set -ex

export CLICOLOR_FORCE=1

PATH=$PREFIX/bin:$PATH # to make /usr/bin/env find the right python interpreter
export PYTHONPATH=${PREFIX}/lib/python${PY_VER}/site-packages:$PYTHONPATH
export LD_LIBRARY_PATH=${PREFIX}/lib:$LD_LIBRARY_PATH
export DEFINES=H5_BUILT_AS_DYNAMIC_LIB

export BUILD=${SRC_DIR}/codeaster-prerequisites
cd $BUILD
source VERSION

export ROOT="$BUILD"
export ARCH=seq
export DEST="${BUILD}/dest"
cd ${SRC_DIR}

echo "**************** M E T I S  B U I L D  S T A R T S  H E R E ****************"

mkdir -p ${BUILD}/metis/
tar xzf ${BUILD}/archives/metis-${METIS}.tar.gz -C ${BUILD}/metis/ --strip-components 1
cd ${BUILD}/metis
make config CFLAGS="-fPIC ${CFLAGS}" prefix=${DEST}/metis-${METIS}
make -j $CPU_COUNT
make install
cd ${SRC_DIR}

echo "**************** M E T I S  B U I L D  E N D S  H E R E ****************"

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
               --enable-scotch \
               --install-tests \
               --prefix=${DEST}/mumps-${MUMPS_GPL}

$PYTHON ./waf build --jobs=1
$PYTHON ./waf install --jobs=1

cd ${SRC_DIR}

echo "**************** M U M P S  B U I L D  E N D S  H E R E ****************"


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

echo "**************** A S T E R  B U I L D  S T A R T S  H E R E ****************"

$PYTHON "${RECIPE_DIR}/config/update_version.py"

export CONFIG_PARAMETERS_addmem=3000

export LIBPATH_PETSC="$PREFIX/lib"
export INCLUDES_PETSC="$PREFIX/include"

export INCLUDES_BOOST=$PREFIX/include
export LIBPATH_BOOST=$PREFIX/lib
export LIB_BOOST="libboost_python$CONDA_PY"

export LIBPATH_MEDCOUPLING="$PREFIX/lib"
export INCLUDES_MEDCOUPLING="$PREFIX/include"
export PYPATH_MEDCOUPLING=$SP_DIR

export INCLUDES_SCOTCH="$PREFIX/lib"
export LIBPATH_SCOTCH="$PREFIX/include"

export TFELHOME=$PREFIX

export LIBPATH_METIS="${DEST}/metis-${METIS}/lib $PREFIX/lib"
export INCLUDES_METIS="${DEST}/metis-${METIS}/include $PREFIX/include"

export LIBPATH_MUMPS="${DEST}/mumps-${MUMPS_GPL}/lib $PREFIX/lib"
export INCLUDES_MUMPS="${DEST}/mumps-${MUMPS_GPL}/include $PREFIX/include ${DEST}/mumps-${MUMPS_GPL}/include_seq"

LDFLAGS="-Wl,--no-as-needed -lmedC -lhdf5 -lesmumps -lscotch -lscotcherr -lscotcherrexit -lz -ldl -lm ${LDFLAGS}" \
FCFLAGS="-fallow-argument-mismatch ${FCFLAGS}" \
  ./waf_std \
     --python=$PYTHON \
     --prefix="${PREFIX}" \
     --libdir="${PREFIX}/lib" \
     --install-tests \
     --enable-metis \
     --embed-metis \
     --enable-mumps \
     --embed-mumps \
     --enable-scotch \
     --enable-mfront \
     --enable-med \
     --enable-hdf5 \
     --embed-aster \
     --disable-mpi \
     --disable-petsc \
     --without-hg \
     --without-repo \
     configure

./waf_std build -j $CPU_COUNT

./waf_std --python=$PYTHON install

mv ./astest ./alltest
mkdir ./astest
cp ./alltest/forma01a.* $PREFIX/share/aster/tests
cp ./alltest/sslp114a.* $PREFIX/share/aster/tests
cp ./alltest/mumps05a.* $PREFIX/share/aster/tests
cp ./alltest/mumps01a.* $PREFIX/share/aster/tests
cp ./alltest/erreu03a.* $PREFIX/share/aster/tests
cp ./alltest/umat001a.* $PREFIX/share/aster/tests
cp ./alltest/zzzz121a.* $PREFIX/share/aster/tests
cp ./alltest/mfron01a.* $PREFIX/share/aster/tests
cp ./alltest/*.mfront $PREFIX/share/aster/tests
rm -Rf ./alltest

ln -rs $PREFIX/share/aster $PREFIX/stable
cp -R ${SRC_DIR}/code_aster ${SP_DIR}

find $PREFIX -name "profile.sh" -exec sed -i 's/PYTHONHOME=/#PYTHONHOME=/g' {} \;
find $PREFIX -name "profile.sh" -exec sed -i 's/export PYTHONHOME/#export PYTHONHOME/g' {} \;

echo "**************** A S T E R  B U I L D  E N D S  H E R E ****************"

echo "**************** C L E A N U P  S T A R T S  H E R E ****************"

rm -Rf $BUILD

echo "**************** C L E A N U P  E N D S  H E R E ****************"
