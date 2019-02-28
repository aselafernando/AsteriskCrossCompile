# AsteriskCrossCompile
Script to allow cross compilation of Asterisk

I recommend using crosstool-ng (https://crosstool-ng.github.io/) to generate your cross compiling toolchain and installing in the default directory
${HOME}/x-tools/${TARGETMACH}/

This script assumes the cross compiling toolchain is installed under
${HOME}/x-tools/${TARGETMACH}/

# Variables
```
BUILDMACH = The architecture of the machine you are building on, almost always x86_64-pc-linux-gnu
TARGETMACH = The architecture of the machine you are building for, i.e. arm-cortex_a8-linux-gnueabihf
THREADS = Number of threads to use when compiling
SYSROOT = The sysroot of the cross compiling chain, if you install the cross compiling toolchain into the default location of ${HOME}/x-tools/${TARGETMACH}/ there is no need to change this.
ROOTDIR = The location to "install" all the cross compiled libraries. Defaults to sysroot in the current directory
ASTERISKINSTALLDIR = The location to install the cross compiled Asterisk. Defaults to asterisk in the current directory.
BUILDDIR = The location to stage the build. Defaults to build in the current directory
```

# Usage
You have two options, install the dependencies of Asterisk on the target from the target's package manager or use the cross compiled versions.

# Using Target Package Manager
1. Install the Asterisk Dependencies on the target

SSH/Console in and install ZLib, Jansson, LibEdit, LibXSLT, LibXML2, LibSRTP, SQLite, OpenSSL, LibUUID
Note: Some packages may be preinstalled on certain distributions

i.e. for ArchLinux
```
pacman -Syu jansson libedit libxslt libxml2 libsrtp openssl
```

2. Make note of the versions of these libraries, as we will have to download the same versions to compile against on the host machine.
Note: The versions of libuuid and SQLite appear not to be so strict in matching

3. On your host machine, modify the SOURCE URLS section of the script to download the same versions of the libraries you just installed on the target

4. Execute the script on the host

5. Enter ${ASTERISKINSTALLDIR}
You will see the following folders
```
etc/
include/
lib/
sbin/
share/
var/
```
This is the base installation of Asterisk + Chan SCCP

6. Edit ${ASTERISKINSTALLDIR}/etc/asterisk/asterisk.conf and modify based on where Asterisk will live on your target device:
```
[directories]
astetcdir = /etc/asterisk
astmoddir => /lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir = /var/lib/asterisk
astsbindir => /asterisk/sbin
astdatadir = /var/lib/asterisk
astspooldir = /var/spool/asterisk
astrundir = /var/run/asterisk
astkeydir = /var/lib/asterisk
astagidir = /var/lib/asterisk/agi-bin
astlogdir = /var/log/asterisk
```
7. Copy the contents of ${ASTERISKINSTALLDIR} to the desired location on the target

8. Run sudo ldconfig -v to update the shared libraries (if you installed the asterisk libraries in a non-standard location you will have to add these to the shared linker paths by creating a file under /etc/ld.so.conf/myCustomLocation.conf and inserting the location of your custom libary directory before running the command)

9. Asterisk is now ready to run, specify the conf file using the -C parameter
```
asterisk -f -C /etc/asterisk/asterisk.conf
```

# Using Compiled Versions

Skip steps 1 and 2 above, and in step 3 pick and choose the versions of libaries you wish to use.
Lastly you will have to copy over the libraries to the target located in ${ROOTDIR}
