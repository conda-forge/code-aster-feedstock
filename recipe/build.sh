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

echo "**************** M E D C O U P L I N G  B U I L D  S T A R T S  H E R E ****************"

mkdir ${BUILD}/medcouping/
tar xzf ${BUILD}/archives/medcoupling-${MEDCOUPLING}.tar.gz -C ${BUILD}/medcouping/ --strip-components 1
cd ${BUILD}/medcouping/
mkdir ${BUILD}/medcouping/configuration
tar xzf ${BUILD}/archives/configuration-${MEDCOUPLING}.tar.gz -C ${BUILD}/medcouping/configuration --strip-components 1
mkdir ${BUILD}/medcouping/build
cd ${BUILD}/medcouping/build
cmake ${BUILD}/medcouping/ \
    -DCMAKE_INSTALL_PREFIX=${PREFIX} \
    -DCONFIGURATION_ROOT_DIR=${BUILD}/medcouping/configuration \
    -DPYTHON_ROOT_DIR=${PREFIX} \
    -Wno-dev \
    -DSALOME_CMAKE_DEBUG=ON \
    -DSALOME_USE_MPI=OFF \
    -DMEDCOUPLING_BUILD_TESTS=OFF \
    -DMEDCOUPLING_BUILD_DOC=OFF \
    -DMEDCOUPLING_USE_64BIT_IDS=ON \
    -DMEDCOUPLING_USE_MPI=OFF \
    -DMEDCOUPLING_MEDLOADER_USE_XDR=OFF \
    -DXDR_INCLUDE_DIRS="" \
    -DMEDCOUPLING_PARTITIONER_PARMETIS=OFF \
    -DMEDCOUPLING_PARTITIONER_METIS=OFF \
    -DMEDCOUPLING_PARTITIONER_SCOTCH=OFF \
    -DMEDCOUPLING_PARTITIONER_PTSCOTCH=OFF \
    -DMPI_C_COMPILER:PATH=$(which mpicc) \
    -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON} \
    -DBOOST_ROOT=${PREFIX} \
    -DCMAKE_BUILD_TYPE=Release
make -j $CPU_COUNT
make install

cd ${SRC_DIR}

echo "**************** M E D C O U P L I N G  B U I L D  E N D S  H E R E ****************"

echo "**************** H O M A R D  B U I L D  S T A R T S  H E R E ****************"

mkdir ${BUILD}/homard/
tar xzf ${BUILD}/archives/homard-${HOMARD}.tar.gz -C ${BUILD}/homard/ --strip-components 1
cd ${BUILD}/homard/
$PYTHON setup_homard.py --prefix=${PREFIX}/bin -en -v
cd ${SRC_DIR}

echo "**************** H O M A R D  B U I L D  E N D S  H E R E ****************"

echo "**************** A S R U N  B U I L D  S T A R T S  H E R E ****************"

mkdir ${BUILD}/asrun/
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

cd ${BUILD}
LDFLAGS="-L${STDLIB_DIR}" make metis
cd ${SRC_DIR}

echo "**************** M E T I S  B U I L D  E N D S  H E R E ****************"

#echo "**************** P A R M E T I S  B U I L D  S T A R T S  H E R E ****************"

#mkdir ${BUILD}/parmetis/
#tar xzf ${BUILD}/archives/parmetis-${PARMETIS}.tar.gz -C ${BUILD}/parmetis/ --strip-components 1
#cd ${BUILD}/parmetis/
#make config CFLAGS="-fPIC ${CFLAGS}" prefix=${DEST}/parmetis-${PARMETIS}
#make -j $CPU_COUNT
#make install
#cd ${SRC_DIR}

#echo "**************** P A R M E T I S  B U I L D  E N D S  H E R E ****************"

echo "**************** M U M P S  B U I L D  S T A R T S  H E R E ****************"

mkdir ${BUILD}/mumps/
tar xzf ${BUILD}/archives/mumps-${MUMPS_GPL}.tar.gz -C ${BUILD}/mumps/ --strip-components 1
cd ${BUILD}/mumps/

CFLAGS="-DUSE_SCHEDAFFINITY -Dtry_null_space ${CFLAGS}" \
FCFLAGS="-DUSE_SCHEDAFFINITY -Dtry_null_space -fallow-argument-mismatch ${FCFLAGS}" \
LIBPATH="${PREFIX}/lib ${DEST}/metis-${METIS}/lib ${DEST}/parmetis-${PARMETIS}/lib $LIBPATH" \
INCLUDES="${PREFIX}/include ${DEST}/metis-${METIS}/include ${DEST}/parmetis-${PARMETIS}/include $INCLUDES" \
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

echo "**************** A S T E R  B U I L D  S T A R T S  H E R E ****************"

$PYTHON "${RECIPE_DIR}/config/update_version.py"
#cp -Rf $RECIPE_DIR/contrib/asrun $SP_DIR/
#cp -Rf $RECIPE_DIR/contrib/scripts/* $PREFIX/bin

export CONFIG_PARAMETERS_addmem=3000

export LIBPATH_PETSC="$PREFIX/lib"
export INCLUDES_PETSC="$PREFIX/include"

export INCLUDES_BOOST=$PREFIX/include
export LIBPATH_BOOST=$PREFIX/lib
export LIB_BOOST="libboost_python$CONDA_PY"

export INCLUDES_MED="$PREFIX/include"
export LIBPATH_MED="$PREFIX/lib"

export LIBPATH_MEDCOUPLING="$PREFIX/lib"
export INCLUDES_MEDCOUPLING="$PREFIX/include"
export PYPATH_MEDCOUPLING=$SP_DIR

export TFELHOME=$PREFIX

export LIBPATH_METIS="${DEST}/metis-${METIS}/lib $PREFIX/lib"
export INCLUDES_METIS="${DEST}/metis-${METIS}/include $PREFIX/include"

export LIBPATH_MUMPS="${DEST}/mumps-${MUMPS_GPL}/lib $PREFIX/lib"
export INCLUDES_MUMPS="${DEST}/mumps-${MUMPS_GPL}/include $PREFIX/include ${DEST}/mumps-${MUMPS_GPL}/include $PREFIX/include_seq"

./waf_std \
     --python=$PYTHON \
     --help

#    --use-config=wafcfg_conda \
 #    --use-config-dir="$RECIPE_DIR"/config \
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
     --enable-mfront \
     --disable-mpi \
     --disable-petsc \
     --without-hg \
     configure

./waf_std build -j $CPU_COUNT

./waf_std --python=$PYTHON install

#find $PREFIX -name "profile.sh" -exec sed -i 's/PYTHONHOME=/#PYTHONHOME=/g' {} \;
#find $PREFIX -name "profile.sh" -exec sed -i 's/export PYTHONHOME/#export PYTHONHOME/g' {} \;

#mkdir -p $PREFIX/etc/codeaster/
#cp -Rf $RECIPE_DIR/contrib/etc/* $PREFIX/etc/codeaster/

# Change the PYTHONPATH just for pybind11_stubgen to find the necessary module
# Generate stubs for pybind11
PYTHONPATH="$PREFIX/lib/aster:$SRC_DIR/stubgen" \
LD_LIBRARY_PATH="${PREFIX}/lib/aster" \
$PYTHON  ${RECIPE_DIR}/stubs/custom_stubs_gen.py
echo "Stubs generation completed"

# copy modified shell scripts and create backups of the ones we don't want.
cp $PREFIX/bin/run_aster $PREFIX/bin/_run_aster_old
cp $PREFIX/bin/run_ctest $PREFIX/bin/_run_ctest_old

cp $RECIPE_DIR/config/run_aster $PREFIX/bin/run_aster
cp $RECIPE_DIR/config/run_ctest $PREFIX/bin/run_ctest
# Alternative, I could move the entire code_aster subdirectory to site-packages granted I am able to relocate all
# relevant .so files
# Add activation/deactivation scripts to set/unset required env variables for code-aster
mkdir -p $PREFIX/etc/conda/activate.d
cp $RECIPE_DIR/config/code_aster_activate.sh $PREFIX/etc/conda/activate.d/code_aster_activate.sh
chmod +x $PREFIX/etc/conda/activate.d/code_aster_activate.sh

mkdir -p $PREFIX/etc/conda/deactivate.d
cp $RECIPE_DIR/config/code_aster_deactivate.sh $PREFIX/etc/conda/deactivate.d/code_aster_deactivate.sh
chmod +x $PREFIX/etc/conda/deactivate.d/code_aster_deactivate.sh

echo "**************** A S T E R  B U I L D  E N D S  H E R E ****************"

echo "**************** C L E A N U P  S T A R T S  H E R E ****************"

rm -Rf $BUILD

echo "**************** C L E A N U P  E N D S  H E R E ****************"