#!/bin/sh

BUILDMACH=x86_64-pc-linux-gnu
TARGETMACH=arm-cortex_a8-linux-gnueabihf
ROOTDIR=${HOME}/AsteriskCrossCompile/sysroot
ASTERISKINSTALLDIR=${HOME}/AsteriskCrossCompile/asterisk
THREADS=16

########################SOURCE URLS############################################

URL_ZLIB="http://zlib.net/zlib-1.2.11.tar.gz"
URL_OPENSSL="https://www.openssl.org/source/openssl-1.1.1a.tar.gz"
URL_JANSSON="http://www.digip.org/jansson/releases/jansson-2.12.tar.gz"
URL_LIBUUID="https://sourceforge.net/projects/libuuid/files/libuuid-1.0.3.tar.gz/download"
URL_LIBXML2="ftp://xmlsoft.org/libxml2/libxml2-2.9.9-rc1.tar.gz"
URL_SQLITE="https://www.sqlite.org/src/tarball/sqlite.tar.gz?r=release"
URL_LIBSRTP="https://github.com/cisco/libsrtp/archive/v2.2.0.tar.gz"
URL_LIBEDIT="http://thrysoee.dk/editline/libedit-20181209-3.1.tar.gz"
URL_ASTERISK="http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-16-current.tar.gz"

########################END SOURCE URLS########################################

SYSROOT=${HOME}/x-tools/${TARGETMACH}/${TARGETMACH}/sysroot
export PATH=$PATH:${HOME}/x-tools/${TARGETMACH}/bin

CC=${TARGETMACH}-gcc
CXX=${TARGETMACH}-g++
LD=${TARGETMACH}-ld
RANLIB=${TARGETMACH}-ranlib
AS=${TARGETMACH}-as
AR=${TARGETMACH}-ar
STRIP=${TARGETMACH}-strip

mkdir -p ${ASTERISKINSTALLDIR}
mkdir -p ${ROOTDIR}

#######################COMPILATION STARTS#################################

#ZLIB
rm zlib*.tar.gz
wget ${URL_ZLIB}
tar zxf zlib*.tar.gz
cd zlib*
CC=$CC LD=$LD RANLIB=$RANLIB AS=$AS AR=$AR BUILDMACH=$BUILDMACH TARGETMACH=${TARGETMACH} ./configure --prefix=$ROOTDIR
CC=$CC LD=$LD RANLIB=$RANLIB AS=$AS AR=$AR BUILDMACH=$BUILDMACH TARGETMACH=${TARGETMACH} make -j${THREADS} && make install
cd ..

#OPENSSL
rm openssl*.tar.gz
wget ${URL_OPENSSL}
tar xzf openssl*.tar.gz
cd openssl*
CROSS_COMPILE=${TARGETMACH}- CC="gcc -I${SYSROOT}/include -I${ROOTDIR}/include" ./Configure linux-generic32 shared zlib-dynamic --prefix=$ROOTDIR --openssldir=$ROOTDIR
make depend
make -j${THREADS} && make install
cd ..

#JANSSON
rm jansson*.tar.gz
wget ${URL_JANSSON}
tar zxf jansson*.tar.gz
cd jansson*
CPPFLAGS="-fPIC" ./configure --build=$BUILDMACH --host=${TARGETMACH} --enable-shared --prefix=$ROOTDIR
make -j${THREADS} && make install
cd ..

#LIBUUID
rm libuuid*.tar.gz
wget ${URL_LIBUUID}
tar zxf libuuid*.tar.gz
cd libuuid-*
CPPFLAGS=-fPIC ./configure --build=$BUILDMACH --host=${TARGETMACH} --enable-shared --prefix=$ROOTDIR
make -j${THREADS} && make install
cd ..

#LIBXML2
rm libxml2-*.tar.gz
wget ${URL_LIBXML2}
tar zxf libxml2-*.tar.gz
cd libxml2-*
CPPFLAGS="-I${SYSROOT}/include -I${ROOTDIR}/include" LDFLAGS="-L${SYSROOT}/lib -L${ROOTDIR}/lib" ./configure --build=$BUILDMACH --host=${TARGETMACH} --enable-shared --with-zlib="${ROOTDIR}/include" --with-python=no --prefix=$ROOTDIR
make -j${THREADS} && make install
cd ..

#SQLITE
rm sqlite.tar.gz
wget ${URL_SQLITE}
mv "sqlite.tar.gz?r=release" "sqlite.tar.gz"
tar zxf sqlite.tar.gz
cd sqlite
./configure --build=$BUILDMACH --host=${TARGETMACH} --enable-shared --prefix=$ROOTDIR
make -j${THREADS} && make install
cd ..

#SRTP
rm v*.tar.gz
wget ${URL_LIBSRTP}
tar zxf v*.tar.gz
cd libsrtp*
CFLAGS="-I${ROOTDIR}/include" LDFLAGS="-L${ROOTDIR}/lib" ./configure --enable-openssl --with-openssl-dir=$ROOTDIR --build=$BUILDMACH --host=${TARGETMACH} --prefix=$ROOTDIR
make libsrtp2.so.1
make libsrtp2.a
make install
cd ..

#LIBEDIT
rm libedit*.tar.gz
wget ${URL_LIBEDIT}
tar zxf libedit*.tar.gz
cd libedit*
PKG_CONFIG_PATH="${ROOTDIR}/lib/pkgconfig" CFLAGS="-I${ROOTDIR}/include" LDFLAGS="-L${ROOTDIR}/lib" ./configure --build=$BUILDMACH --host=${TARGETMACH} --prefix=$ROOTDIR --enable-shared
make && make install
cd ..

#ASTERISK
rm asterisk*.tar.gz
wget ${URL_ASTERISK}
tar zxf asterisk*.tar.gz
cd asterisk-*
PKG_CONFIG_LIBDIR="${ROOTDIR}/lib/pkgconfig" CXXCPPFLAGS="-I${ROOTDIR}/include -I${ROOTDIR}/include/libxml2 -I${ROOTDIR}/include/srtp2" CXXFLAGS="-I${ROOTDIR}/include -I${ROOTDIR}/include/libxml2 -I${ROOTDIR}/include/srtp2" CPPFLAGS="-I${ROOTDIR}/include -I${ROOTDIR}/include/libxml2 -I${ROOTDIR}/include/srtp2" CFLAGS="-I${ROOTDIR}/include -I${ROOTDIR}/include/libxml2 -I${ROOTDIR}/include/srtp2" LDFLAGS="-L${ROOTDIR}/lib -luuid -lssl -lcrypto" ./configure --build=$BUILDMACH \
--host=${TARGETMACH} --with-ssl=$ROOTDIR --with-libxml2=$ROOTDIR --with-sqlite3=$ROOTDIR --with-jansson=$ROOTDIR --with-z=$ROOTDIR --disable-xmldoc \
--with-crypto=$ROOTDIR --with-srtp=$ROOTDIR \
--prefix=${ASTERISKINSTALLDIR}
make menuselect
make -j$THREADS 
make install && make basic-pbx
cd ..

#CHAN-SCCP-B
if [ -d "chan-sccp" ]; then
	cd chan-sccp
	git pull
else
	git clone https://github.com/chan-sccp/chan-sccp.git chan-sccp
	cd chan-sccp
fi
./configure --with-asterisk=${ASTERISKINSTALLDIR} --build=$BUILDMACH --host=${TARGETMACH} --enable-conference --disable-doxygen-doc --prefix=${ASTERISKINSTALLDIR}
make -j${THREADS}
make install
cd ..
