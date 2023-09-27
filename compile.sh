#!/bin/bash

CROSS_COMPILE=1
BLUETOOTH=1

BUILDMACH=x86_64-pc-linux-gnu
TARGETMACH=arm-cortex_a8-linux-gnueabihf
THREADS=50

MESON_SYSTEM=linux
MESON_CPU_FAMILY=arm
MESON_CPU=armv7hl
MESON_ENDIAN=little

CURDIR=`pwd`

SYSROOT=${CURDIR}/sysroot
ASTERISK_INSTALLDIR=${CURDIR}/asterisk
BUILDDIR=${CURDIR}/build

########################SOURCE URLS############################################

URL_CT="https://github.com/crosstool-ng/crosstool-ng/releases/download/crosstool-ng-1.25.0/crosstool-ng-1.25.0.tar.xz"

#URL_ZLIB="http://zlib.net/zlib-1.2.13.tar.gz" #in glib2
URL_OPENSSL="https://www.openssl.org/source/openssl-1.1.1q.tar.gz"
URL_JANSSON="http://digip.org/jansson/releases/jansson-2.13.tar.gz"
URL_LIBUUID="https://sourceforge.net/projects/libuuid/files/libuuid-1.0.3.tar.gz/download"
URL_LIBXML2="ftp://xmlsoft.org/libxml2/libxml2-2.9.10-rc1.tar.gz"
URL_SQLITE="https://www.sqlite.org/src/tarball/sqlite.tar.gz?r=release"
URL_LIBSRTP2="https://github.com/cisco/libsrtp/archive/refs/tags/v2.4.2.tar.gz"
URL_LIBEDIT="https://thrysoee.dk/editline/libedit-20221030-3.1.tar.gz"
URL_LIBEVENT="https://github.com/libevent/libevent/archive/refs/tags/release-2.1.12-stable.tar.gz"
URL_CURL="https://github.com/curl/curl/releases/download/curl-7_86_0/curl-7.86.0.tar.gz"
#URL_LIBFFI="https://github.com/libffi/libffi/archive/refs/tags/v3.4.1.tar.gz" #in glib2
URL_GLIB2="https://download.gnome.org/sources/glib/2.74/glib-2.74.1.tar.xz"
URL_EXPAT="https://github.com/libexpat/libexpat/releases/download/R_2_5_0/expat-2.5.0.tar.gz"
URL_DBUS="https://gitlab.freedesktop.org/dbus/dbus/-/archive/dbus-1.14/dbus-dbus-1.14.tar.gz"
URL_LIBICAL="https://github.com/libical/libical/archive/refs/tags/v3.0.16.tar.gz"
URL_NCURSES="https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.3.tar.gz"
URL_READLINE="https://git.savannah.gnu.org/cgit/readline.git/snapshot/readline-readline-8.2.tar.gz"
URL_BLUEZ="http://www.kernel.org/pub/linux/bluetooth/bluez-5.65.tar.xz"
URL_ASTERISK="http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz"

############################COMPILER########################################

GLOBAL_CFLAGS="-Ofast"
GLOBAL_CXXFLAGS=${GLOBAL_CFLAGS}
GLOBAL_CPPFLAGS=""
GLOBAL_LDFLAGS=""

if [ "${CROSS_COMPILE}" -eq "0" ]; then
	BUILDMACH=
	TARGETMACH=
	COMPILERPREFIX=
else
	export PATH=$PATH:${HOME}/x-tools/${TARGETMACH}/bin
	COMPILERPREFIX=${TARGETMACH}-
	GLOBAL_CFLAGS="${GLOBAL_CFLAGS} -march=armv7-a -mthumb-interwork -mfloat-abi=hard -mfpu=neon -mtune=cortex-a8"
	GLOBAL_CXXFLAGS=${GLOBAL_CFLAGS}
fi

CC=${COMPILERPREFIX}gcc
CXX=${COMPILERPREFIX}g++
LD=${COMPILERPREFIX}ld
RANLIB=${COMPILERPREFIX}ranlib
AS=${COMPILERPREFIX}as
AR=${COMPILERPREFIX}ar
STRIP=${COMPILERPREFIX}strip
OBJCOPY=${COMPILERPREFIX}objcopy

########################BUILD DIRECTORIES###################################

mkdir -p ${ASTERISK_INSTALLDIR}
mkdir -p ${SYSROOT}
mkdir -p ${BUILDDIR}

cd ${BUILDDIR}

#############################DEPENDENCIES###################################

sudo apt update

#glib2 meson
#dbus autoconf-archive
#libical cmake
#ncurses autopoint gettext libgettext-ocaml
#asterisk menuselect lbxml2-dev

sudo apt install autoconf-archive cmake autopoint gettext libgettext-ocaml libxml2-dev

########################COMPILATION STARTS##################################

function checkLib() {
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" pkg-config --exists ${1}
	return $?
}

function checkLibInstall() {
	if ! checkLib ${1}; then
		echo "Error installing ${1}"
		exit
	fi
}

#Build toolchain
if ! command $CC -v &> /dev/null && [ ${CROSS_COMPILE} -eq "1" ]; then
	sudo apt install build-essential flex git texinfo help2man gawk libtool-bin libncurses-dev bison pkg-config
	wget ${URL_CT} -qO- | tar xJ
	cd ./crosstool-ng*
	./configure --enable-local
	make -j${THREADS}
	
	#Beaglebone Black
	./ct-ng arm-cortex_a8-linux-gnueabiex
	#Beaglebone Black
	sed -i "s/# CT_ARCH_FLOAT_HW is not set/CT_ARCH_FLOAT_HW=y/g" .config
	#Beaglebone Black
	sed -i 's/CT_ARCH_FLOAT_SW=y/# CT_ARCH_FLOAT_SW is not set/g' .config
	#Beaglebone Black
	sed -i 's/CT_ARCH_FLOAT="soft"/CT_ARCH_FLOAT="hard"/g' .config
	#Beaglebone Black
	sed -i 's/CT_ARCH_FPU=""/CT_ARCH_FPU="neon"/g' .config

	#Set number of threads
	sed -i "s/CT_PARALLEL_JOBS=0/CT_PARALLEL_JOBS=${THREADS}/g" .config
	./ct-ng menuconfig
	#zlib version bug
	sed -i 's/CT_ZLIB_VERSION="1.2.12"/CT_ZLIB_VERSION="1.2.13"/g' .config
	./ct-ng build
fi

if ! command $CC -v &> /dev/null; then
	echo "Error getting compiler"
	exit
fi

if [ ! -d ./glib* ] || ! checkLib glib-2.0; then
	if [ ! -d ./glib* ]; then
		wget ${URL_GLIB2} -qO- | tar xJ
	fi
	cd ./glib*
	mkdir -p ./build
	if [ "${CROSS_COMPILE}" -eq "1" ]; then
		echo -e "[host_machine]\nsystem = '${MESON_SYSTEM}'\ncpu_family = '${MESON_CPU_FAMILY}'\ncpu = '${MESON_CPU}'\nendian = '${MESON_ENDIAN}'\n" > ./cross_compile.txt
		echo -e "[properties]\nsys_root = '${SYSROOT}'\npkg_config_libdir = ['${SYSROOT}/lib/pkgconfig','${SYSROOT}/usr/local/lib/pkgconfig']\n" >> ./cross_compile.txt
		echo -e "[binaries]\nc = '${CC}'\ncpp = '${CXX}'\nar = '${AR}'\nas = '${AS}'\nranlib = '${RANLIB}'\nld = '${LD}'\nobjcopy = '${OBJCOPY}'\nstrip = '${STRIP}'\n" >> ./cross_compile.txt
		meson setup --cross-file ./cross_compile.txt ./build
	else
		meson setup ./build
	fi
	meson compile -C ./build -j ${THREADS}
	meson install -C ./build --destdir ${SYSROOT}
	# --skip-subprojects
	#Bug - for some reason glib doesnt produce the right pkg-config file entries
	LOCALDIR=`echo "${SYSROOT}/usr/local" | sed 's/\//\\\\\//g'`
	sed -i "s/prefix=\/usr\/local/prefix=${LOCALDIR}/g" ${SYSROOT}/usr/local/lib/pkgconfig/*.pc
	cd ${BUILDDIR}
	checkLibInstall glib-2.0
fi

#ZLIB - included in glib2
#if [ ! -d ./zlib* ] || ! checkLib zlib; then
#	wget ${URL_ZLIB} -qO- | tar xz
#	cd ./zlib*
#	CC=$CC LD=$LD RANLIB=$RANLIB AS=$AS AR=$AR BUILDMACH=$BUILDMACH TARGETMACH=${TARGETMACH} \
#	CPPFLAGS=$GLOBAL_CPPFLAGS CFLAGS=$GLOBAL_CFLAGS CXXFLAGS=$GLOBAL_CXXFLAGS LDFLAGS=$GLOBAL_LDFLAGS \
#	./configure --prefix=${SYSROOT}
#	make -j${THREADS} && make install
#	cd ${BUILDDIR}
#	checkLibInstall zlib
#fi

#OPENSSL
if [ ! -d ./openssl* ] || ! checkLib libssl; then
	if [ ! -d ./openssl* ]; then
		wget ${URL_OPENSSL} -qO- | tar xz
	fi
	cd ./openssl*
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CROSS_COMPILE=${COMPILERPREFIX} CC="gcc ${GLOBAL_CPPFLAGS} `pkg-config --cflags-only-I zlib` ${GLOBAL_CFLAGS}" \
	LD="ld ${GLOBAL_LDFLAGS}" \
	./Configure linux-generic32 shared zlib-dynamic --prefix=${SYSROOT} --openssldir=${SYSROOT}
	make depend
	make -j${THREADS} && make install_sw
	cd ${BUILDDIR}
	checkLibInstall libssl
fi

#JANSSON
if [ ! -d ./jansson* ] || ! checkLib jansson; then
	if [ ! -d ./jansson* ]; then
		wget ${URL_JANSSON} -qO- | tar xz
	fi
	cd ./jansson*
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --enable-shared --prefix=${SYSROOT}
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall jansson
fi

#LIBUUID
if [ ! -d ./libuuid-* ] || ! checkLib uuid; then
	if [ ! -d ./libuuid-* ]; then
		wget ${URL_LIBUUID} -qO- | tar xz
	fi
	cd ./libuuid-*
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --enable-shared --prefix=${SYSROOT}
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall uuid
fi

#LIBXML2
if [ ! -d ./libxml2-* ] || ! checkLib libxml-2.0; then
	if [ ! -d ./libxml2-* ]; then
		wget ${URL_LIBXML2} -qO- | tar xz
	fi
	cd ./libxml2-*
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --enable-shared --with-python=no --prefix=${SYSROOT}
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall libxml-2.0
fi

#SQLITE
if [ ! -d ./sqlite ] || ! checkLib sqlite3; then
	if [ ! -d ./sqlite ]; then
		wget ${URL_SQLITE} -qO- | tar xz
	fi
	cd ./sqlite
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --enable-shared --prefix=${SYSROOT}
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall sqlite3
fi

#LIBSRTP2
if [ ! -d ./libsrtp* ] || ! checkLib libsrtp2; then
	if [ ! -d ./libsrtp* ]; then
		wget ${URL_LIBSRTP2} -qO- | tar xz
	fi
	cd ./libsrtp*
	#The check for openssl_cleanse_broken doesnt work when cross compiling
	#This will assume it isn't broken
	#sed -i '5939,5949d;5902,5937d' ./configure
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --enable-openssl --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT}
	make libsrtp2.a -j${THREADS} && make libsrtp2.so.1 -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall libsrtp2
fi

#LIBEDIT
if [ ! -d ./libedit* ] || ! checkLib libedit; then
	if [ ! -d ./libedit* ]; then
		wget ${URL_LIBEDIT} -qO- | tar xz
	fi
	cd ./libedit*
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall libedit
fi

#LIBEVENT
if [ ! -d ./libevent* ] || ! checkLib libevent; then
	if [ ! -d ./libevent* ]; then
		wget ${URL_LIBEVENT} -qO- | tar xz
	fi
	cd ./libevent*
	./autogen.sh
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall libevent
fi

#CURL
if [ ! -d ./curl* ] || ! checkLib libcurl; then
	if [ ! -d ./curl* ]; then
		wget ${URL_CURL} -qO- | tar xz
	fi
	cd ./curl*
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
	./configure --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared --with-openssl
	make -j${THREADS} && make install
	cd ${BUILDDIR}
	checkLibInstall libcurl
fi

#BLUEZ and dependencies
if [ "${BLUETOOTH}" -eq "1" ]; then
	#EXPAT
	if [ ! -d ./expat* ] || ! checkLib expat; then
		if [ ! -d ./expat* ]; then
			wget ${URL_EXPAT} -qO- | tar xz
		fi
		cd ./expat*
		./buildconf.sh
		PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
		CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
		./configure  --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared
		make -j${THREADS} && make install
		cd ${BUILDDIR}
		checkLibInstall expat
	fi

	#DBUS
	if [ ! -d ./dbus* ] || ! checkLib dbus-1; then
		#sudo apt install autoconf-archive
		if [ ! -d ./dbus* ]; then
			wget ${URL_DBUS} -qO- | tar xz
		fi
		cd ./dbus*
		if [ -f ./config.cache ]; then
			#unclean build
			rm config.cache
		fi
		PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
		CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS="${GLOBAL_CFLAGS} -Wno-error=cast-align -Wno-error=sign-compare -Wno-error=unused-variable" \
		CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS="${GLOBAL_LDFLAGS} `pkg-config --libs zlib libffi gmodule-2.0 libpcre2-8 libpcre2-16 libpcre2-32`" \
		./autogen.sh --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared \
			    --disable-doxygen-docs               \
			    --disable-xml-docs                   \
			    --disable-static                     \
			    --with-systemduserunitdir=no         \
			    --with-systemdsystemunitdir=no
		make -j${THREADS} && make install
		cd ${BUILDDIR}
		checkLibInstall dbus-1
	fi
	
	#LIBICAL
	if [ ! -d ./libical* ] || ! checkLib libical; then
		#sudo apt install cmake
		if [ ! -d ./libical* ]; then
			wget ${URL_LIBICAL} -qO- | tar xz
		fi
		cd ./libical*
		if [ -d ./build ]; then
			#unclean build
			rm -rf ./build
		fi
		mkdir -p ./build
		cd ./build
		PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
		CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS="${GLOBAL_LDFLAGS} `pkg-config --libs zlib libxml-2.0`" \
		cmake .. -DCMAKE_C_COMPILER=${CC} -DCMAKE_CXX_COMPILER=${CXX} -DCMAKE_AR=${AR} -DCMAKE_LINKER=${LD} -DCMAKE_RANLIB=${RANLIB} \
		-DCMAKE_FIND_ROOT_PATH=${SYSROOT} -DCMAKE_INSTALL_PREFIX=${SYSROOT}  \
		      -DICAL_GLIB=false \
		      -DLIBICAL_BUILD_TESTING=false \
		      -DCMAKE_BUILD_TYPE=Release   \
		      -DSHARED_ONLY=true           \
		      -DICAL_BUILD_DOCS=false      \
		      -DGOBJECT_INTROSPECTION=false \
		      -DICAL_GLIB_VAPI=false       \
		      -DENABLE_GTK_DOC=false	\
		      -DLIBICAL_BUILD_TESTING=false
		make -j${THREADS} && make install
		cd ${BUILDDIR}
		checkLibInstall libical
	fi
	
	#NCURSES
	if [ ! -d ./ncurses* ] || ! checkLib ncurses; then
		if [ ! -d ./ncurses* ]; then
			wget ${URL_NCURSES} -qO- | tar xz
		fi
		cd ./ncurses*
		PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
		CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS=${GLOBAL_LDFLAGS} \
		./configure --build=$BUILDMACH --host=${TARGETMACH} --prefix=${SYSROOT} --disable-stripping --with-shared \
		--with-cxx-shared --without-normal --without-manpages --without-progs --without-tack --without-tests \
		--enable-pc-files --with-pkg-config-libdir="${SYSROOT}/lib/pkgconfig"
		make -j${THREADS} && make install
		cd ${BUILDDIR}
		#--enable-widec
		checkLibInstall ncurses
	fi

	#READLINE
	if [ ! -d ./readline* ] || ! checkLib readline; then
		if [ ! -d ./readline* ]; then
			wget ${URL_READLINE} -qO- | tar xz
		fi
		cd ./readline*
		PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
		CPPFLAGS=${GLOBAL_CPPFLAGS} CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS="${GLOBAL_LDFLAGS} -L${SYSROOT}/lib" \
		./configure --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared --with-curses
		make SHLIB_LIBS=-lncurses -j${THREADS} && make install
		cd ${BUILDDIR}
		checkLibInstall readline
	fi

	if [ ! -d ./bluez* ] || ! checkLib bluez; then
		if [ ! -d ./bluez* ]; then
			wget ${URL_BLUEZ} -qO- | tar xJ
		fi
		cd ./bluez*
		PKG_CONFIG_PATH="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
		CPPFLAGS="${GLOBAL_CPPFLAGS} `pkg-config --cflags-only-I readline`" \
		CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} \
		LDFLAGS="${GLOBAL_LDFLAGS} `pkg-config --libs zlib libxml-2.0 readline ncurses libffi gmodule-2.0 libpcre2-8 libpcre2-16 libpcre2-32`" \
		./configure --build=${BUILDMACH} --host=${TARGETMACH} --prefix=${SYSROOT} --enable-shared --enable-library \
		--with-systemdsystemunitdir=${SYSROOT}/lib/systemd/system \
		--with-systemduserunitdir=${SYSROOT}/usr/local/lib/systemd/system \
		--disable-manpages --disable-udev --disable-datafiles
		make -j${THREADS} && make install
		cd ${BUILDDIR}
		checkLibInstall bluez
	fi
fi

#ASTERISK
if [ ! -d ./asterisk* ] || [ ! -f ${ASTERISK_INSTALLDIR}/sbin/asterisk ]; then
	wget ${URL_ASTERISK} -qO- | tar xz
	rm ${ASTERISK_INSTALLDIR}/etc/asterisk/asterisk.conf
	cd ./asterisk-*
	#Asterisk doesnt use CPPFLAGS
	PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
	CFLAGS="${GLOBAL_CPPFLAGS} `pkg-config --cflags-only-I zlib sqlite3 uuid libcurl libcrypto libssl` ${GLOBAL_CFLAGS}" \
	CXXFLAGS="${GLOBAL_CPPFLAGS} `pkg-config --cflags-only-I zlib sqlite3 uuid libcurl libcrypto libssl` ${GLOBAL_CXXFLAGS}" \
	LDFLAGS="${GLOBAL_LDFLAGS} `pkg-config --libs zlib sqlite3 uuid`" \
	./configure \
	--build=${BUILDMACH} --host=${TARGETMACH} \
	--with-pjproject-bundled \
	--disable-xmldoc \
	--prefix=${ASTERISK_INSTALLDIR}
	make menuselect
	make -j${THREADS} && sudo make install && sudo rm -rf /opt/pjproject && sudo chown -R $USER:$USER ${ASTERISK_INSTALLDIR} && make basic-pbx && make install-headers

	cd ${ASTERISK_INSTALLDIR}/etc/asterisk
	echo "" >> asterisk.conf
	echo "[directories]" >> asterisk.conf
	echo "astetcdir => ${ASTERISK_INSTALLDIR}/etc/asterisk" >> asterisk.conf
	echo "astmoddir => ${ASTERISK_INSTALLDIR}/lib/asterisk/modules" >> asterisk.conf
	echo "astvarlibdir => ${ASTERISK_INSTALLDIR}/var/lib/asterisk" >> asterisk.conf
	echo "astdbdir => ${ASTERISK_INSTALLDIR}/var/lib/asterisk" >> asterisk.conf
	echo "astsbindir => ${ASTERISK_INSTALLDIR}/sbin" >> asterisk.conf
	echo "astdatadir => ${ASTERISK_INSTALLDIR}/var/lib/asterisk" >> asterisk.conf
	echo "astspooldir => ${ASTERISK_INSTALLDIR}/var/spool/asterisk" >> asterisk.conf
	echo "astrundir => ${ASTERISK_INSTALLDIR}/var/run/asterisk" >> asterisk.conf
	echo "astkeydir => ${ASTERISK_INSTALLDIR}/var/lib/asterisk" >> asterisk.conf
	echo "astagidir => ${ASTERISK_INSTALLDIR}/var/lib/asterisk/agi-bin" >> asterisk.conf
	echo "astlogdir => ${ASTERISK_INSTALLDIR}/var/log/asterisk" >> asterisk.conf
	echo "" >> asterisk.conf

	cd ${BUILDDIR}
fi

#CHAN-SCCP-B
if [ -d "chan-sccp" ]; then
	cd chan-sccp
	git pull
else
	git clone https://github.com/chan-sccp/chan-sccp.git chan-sccp
	cd chan-sccp
fi

PKG_CONFIG_LIBDIR="${SYSROOT}/lib/pkgconfig:${SYSROOT}/usr/local/lib/pkgconfig" \
CPPFLAGS="${GLOBAL_CPPFLAGS}" CFLAGS=${GLOBAL_CFLAGS} CXXFLAGS=${GLOBAL_CXXFLAGS} LDFLAGS="${GLOBAL_LDFLAGS}" \
./configure --with-asterisk=${ASTERISK_INSTALLDIR} --build=${BUILDMACH} --host=${TARGETMACH} --enable-conference --disable-doxygen-doc --prefix=${ASTERISK_INSTALLDIR}
make -j${THREADS} && make install

if [ ! -f ${ASTERISK_INSTALLDIR}/lib/asterisk/modules/chan_sccp.so ]; then
	echo "chan-sccp install failed"
	exit
fi

cd ${BUILDDIR}
