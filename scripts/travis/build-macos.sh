#!/bin/bash

#
# This source file is part of appleseed.
# Visit https://appleseedhq.net/ for additional information and resources.
#
# This software is released under the MIT license.
#
# Copyright (c) 2018-2019 David Coeurjolly, The appleseedhq Organization
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#


set -e

THISDIR=`pwd`


#--------------------------------------------------------------------------------------------------
# Configure CMake.
#--------------------------------------------------------------------------------------------------

cmake --version


#--------------------------------------------------------------------------------------------------
# Install Homebrew packages.
#--------------------------------------------------------------------------------------------------

echo "travis_fold:start:brew"
echo "Installing Homebrew packages..."

brew update
brew upgrade

brew install boost-python llvm@3.9 lz4 openimageio xerces-c zlib

brew tap cartr/qt4
brew tap-pin cartr/qt4
brew install qt@4 pyqt@4

mkdir -p $HOME/Library/Python/2.7/lib/python/site-packages
echo 'import site; site.addsitedir("/usr/local/lib/python2.7/site-packages")' \
    >> $HOME/Library/Python/2.7/lib/python/site-packages/homebrew.pth

echo "travis_fold:end:brew"


#--------------------------------------------------------------------------------------------------
# Build OSL.
#--------------------------------------------------------------------------------------------------

echo "travis_fold:start:osl"
echo "Building OSL..."

git clone https://github.com/imageworks/OpenShadingLanguage.git
pushd OpenShadingLanguage

git checkout Release-1.8.12

mkdir build
cd build

cmake \
    -Wno-dev \
    -DLLVM_STATIC=ON \
    -DENABLERTTI=ON \
    -DUSE_LIBCPLUSPLUS=ON \
    -DLLVM_DIRECTORY=/usr/local/opt/llvm@3.9/ \
    -DCMAKE_INSTALL_PREFIX=$THISDIR \
    ..

make install -j 2

popd

echo "travis_fold:end:osl"


#--------------------------------------------------------------------------------------------------
# Build SeExpr.
#--------------------------------------------------------------------------------------------------

echo "travis_fold:start:seexpr"
echo "Building SeExpr..."

git clone https://github.com/wdas/SeExpr
pushd SeExpr

git checkout db9610a24401fa7198c54c8768d0484175f54172

mkdir build
cd build

cmake \
    -Wno-dev \
    -DCMAKE_POLICY_DEFAULT_CMP0042=OLD \
    -DCMAKE_INSTALL_PREFIX=$THISDIR \
    ..

mkdir src/doc/html
make install -j 2

popd

echo "travis_fold:end:seexpr"


#--------------------------------------------------------------------------------------------------
# Prepare to run appleseed.
# This must be done before compiling appleseed because the compiling process needs to invokes oslc.
#--------------------------------------------------------------------------------------------------

export LD_LIBRARY_PATH=$THISDIR/lib:sandbox/lib/Debug:$LD_LIBRARY_PATH      # TODO: is this useful?
export DYLD_LIBRARY_PATH=$THISDIR/lib:$DYLD_LIBRARY_PATH
export PYTHONPATH=$PYTHONPATH:sandbox/lib/Debug/python


#--------------------------------------------------------------------------------------------------
# Build appleseed.
#--------------------------------------------------------------------------------------------------

echo "travis_fold:start:build"
echo "Building appleseed..."

mkdir build
pushd build

# TODO: is it necessary to set DBoost_PYTHON_LIBRARY_RELEASE?
cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DWITH_STUDIO=OFF \
    -DWITH_DISNEY_MATERIAL=ON \
    -DWITH_PYTHON2_BINDINGS=OFF \
    -DUSE_STATIC_BOOST=OFF \
    -DBoost_PYTHON_LIBRARY_RELEASE=/usr/local/lib/libboost_python27.dylib \
    -DOSL_INCLUDE_DIR=$THISDIR/include \
    -DOSL_LIBRARIES=$THISDIR/lib \
    -DOSL_EXEC_LIBRARY=$THISDIR/lib/liboslexec.dylib \
    -DOSL_COMP_LIBRARY=$THISDIR/lib/liboslcomp.dylib \
    -DOSL_QUERY_LIBRARY=$THISDIR/lib/liboslquery.dylib \
    -DOSL_COMPILER=$THISDIR/bin/oslc \
    -DOSL_QUERY_INFO=$THISDIR/bin/oslinfo \
    -DPYTHON_INCLUDE_DIR=/usr/local/Cellar/python@2/2.7.15/Frameworks/Python.framework/Versions/2.7/include/python2.7/ \
    -DPYTHON_LIBRARY=/usr/local/Cellar/python@2/2.7.15/Frameworks/Python.framework/Versions/2.7/lib/libpython2.7.dylib \
    -DSEEXPR_INCLUDE_DIR=$THISDIR/include \
    -DSEEXPR_LIBRARY=$THISDIR/lib/libSeExpr.dylib \
    -DSEEXPREDITOR_INCLUDE_DIR=$THISDIR/include \
    -DSEEXPREDITOR_LIBRARY=$THISDIR/lib/libSeExprEditor.dylib \
    -DZLIB_INCLUDE_DIR=/usr/local/opt/zlib/include \
    -DZLIB_LIBRARY=/usr/local/opt/zlib/lib/libz.dylib \
    ..

make -j 2

popd

echo "travis_fold:end:build"


#--------------------------------------------------------------------------------------------------
# Run appleseed unit tests.
#--------------------------------------------------------------------------------------------------

echo "travis_fold:start:unit-tests"
echo "Running appleseed unit tests..."

sandbox/bin/Debug/appleseed.cli --run-unit-tests --verbose-unit-tests

echo "travis_fold:end:unit-tests"


#--------------------------------------------------------------------------------------------------
# Run appleseed.python unit tests.
#--------------------------------------------------------------------------------------------------

# echo "travis_fold:start:python-unit-tests"
# echo "Running appleseed.python unit tests..."
#
# python sandbox/lib/Debug/python/appleseed/test/runtests.py
#
# echo "travis_fold:end:python-unit-tests"


set +e
