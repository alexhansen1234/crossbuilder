# Author: Alex Hansen
# email:  ajhansen@mail.usf.edu
#
# Raspberry Pi Cross Compiler Build Script
#
# Set installation path with prompt, and get a coffee or something
#

binutils=binutils-2.28
glibc=glibc-2.24
gcc=gcc-8.1.0
error="is required and is not currently installed. build failed, exiting..."
n_cores=$( grep -c ^processor /proc/cpuinfo )

dpkg -s build-essential > /dev/null
if [ $? != 0 ]; then
  echo "build-essential $error"
  exit 1
fi

command -v gawk > /dev/null
if [ $? != 0 ]; then
  echo "gawk $error"
  exit 1
fi

command -v git > /dev/null
if [ $? != 0 ]; then
  echo "git $error"
  exit 1
fi

dpkg -s texinfo > /dev/null
if [ $? != 0 ]; then
  echo "texinfo $error"
  exit 1
fi

command -v bison > /dev/null
if [ $? != 0 ]; then
  echo "bison $error"
  exit 1
fi

command -v sed > /dev/null
if [ $? != 0 ]; then
  echo "sed $error"
  exit 1
fi

set -e
echo "Enter install path:"
read install_prefix
install_prefix=$(eval echo $install_prefix)
export PATH=$install_prefix/bin:$PATH

if [ ! -d $install_prefix ]; then
  # Not cross platform apparently, but not a problem for ARCE
  mkdir -p $install_prefix
fi

if [ ! -d gcc_all ]; then
  mkdir gcc_all
fi

cd gcc_all
top_level=$( pwd )

if [ ! -d $binutils ]; then
  wget https://ftpmirror.gnu.org/binutils/binutils-2.28.tar.bz2
  tar xf $binutils.tar.bz2
  rm $binutils.tar.bz2
fi

if [ ! -d gcc-6.3.0 ]; then
  wget https://ftpmirror.gnu.org/gcc/gcc-6.3.0/gcc-6.3.0.tar.gz
  tar xf gcc-6.3.0.tar.gz
  rm gcc-6.3.0.tar.gz
fi

if [ ! -d $glibc ]; then
  wget https://ftpmirror.gnu.org/glibc/glibc-2.24.tar.bz2
  tar xf $glibc.tar.bz2
  rm $glibc.tar.bz2
fi

if [ ! -d $gcc ]; then
  wget https://ftpmirror.gnu.org/gcc/gcc-8.1.0/gcc-8.1.0.tar.gz
  tar xf $gcc.tar.gz
  rm $gcc.tar.gz
fi

if [ ! -d linux ]; then
  git clone --depth=1 https://github.com/raspberrypi/linux
fi

cd gcc-6.3.0
contrib/download_prerequisites
rm *.tar.*
cd $top_level
cd gcc-8.1.0
contrib/download_prerequisites
rm *.tar.*
cd $top_level

cd linux
KERNEL=kernel7
make ARCH=arm INSTALL_HDR_PATH=$install_prefix/arm-linux-gnueabihf headers_install
cd $top_level

if [ ! -d build-binutils ]; then
  mkdir build-binutils
fi

cd build-binutils
$top_level/$binutils/configure --prefix=$install_prefix --target=arm-linux-gnueabihf --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib
make -j $n_cores
make install
cd ..

sed -i 's/\x7C\x7C xloc.file == \x27/\x7C\x7C xloc.file[0] == \x27/g' $top_level/gcc-6.3.0/gcc/ubsan.c

cd $top_level

if [ ! -d build-gcc ]; then
  mkdir build-gcc
fi

cd build-gcc

$top_level/gcc-6.3.0/configure --prefix=$install_prefix --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib
make -j $n_cores all-gcc
make install-gcc

cd $top_level

if [ ! -d build-glibc ]; then
  mkdir build-glibc
fi

cd build-glibc

$top_level/glibc-2.24/configure --prefix=$install_prefix/arm-linux-gnueabihf --build=$MACHTYPE --host=arm-linux-gnueabihf --target=arm-linux-gnueabihf --with-arch=armv6 --with-fpu=vfp --with-float=hard --with-headers=$install_prefix/arm-linux-gnueabihf/include --disable-multilib libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers
make -j $n_cores csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o $install_prefix/arm-linux-gnueabihf/lib
arm-linux-gnueabihf-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $install_prefix/arm-linux-gnueabihf/lib/libc.so
touch $install_prefix/arm-linux-gnueabihf/include/gnu/stubs.h

cd $top_level
cd build-gcc
make -j $n_cores all-target-libgcc
make install-target-libgcc

cd $top_level
cd build-glibc
make -j $n_cores
make install

cd $top_level
cd build-gcc
make -j $n_cores
make install
cd $top_level

cp -r $install_prefix $install_prefix-6.3.0

cd $top_level

if [ ! -d build-gcc8 ]; then
  mkdir build-gcc8
fi

cd build-gcc8
$top_level/$gcc/configure --prefix=$install_prefix --target=arm-linux-gnueabihf --enable-languages=c,c++,fortran --with-arch=armv6 --with-fpu=vfp --with-float=hard --disable-multilib
make -j $n_cores
make install

if [[ $( cat ~/.bashrc ) != *$install_prefix/bin* ]]; then
  echo "export PATH=$PATH" >> ~/.bashrc
fi
