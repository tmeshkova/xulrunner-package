#!/bin/sh

CDR=$(pwd)
ARCH=`uname -m`
USERNAME=`whoami`
MOZCONFIG=""
EXTRAOPTS=""
TARGET_CONFIG=INVALID_TARGET_NAME
if [ "$1" != "" ]; then
TARGET_CONFIG=$1
fi
CUSTOM_BUILD=
if [ "$2" != "" ]; then
CUSTOM_BUILD=$2
fi
OBJTARGETDIR=objdir-$TARGET_CONFIG$CUSTOM_BUILD
HOST_QMAKE=qmake
TARGET_QMAKE=qmake
NEED_SBOX2=false

setup_cross_autoconf_env()
{
    if [ $NEED_SBOX2 = false ];then
        return;
    fi
    export CROSS_COMPILE=1
    export CROSS_TARGET="--host=arm-none-linux-gnueabi"
    export CC="$CROSS_COMPILER_PATH-gcc --sysroot=$TARGET_ROOTFS"
    export CPP=$CROSS_COMPILER_PATH-cpp
    export CXX="$CROSS_COMPILER_PATH-g++ --sysroot=$TARGET_ROOTFS"
    export STRIP=$CROSS_COMPILER_PATH-strip
    export LD="$CROSS_COMPILER_PATH-ld --sysroot=$TARGET_ROOTFS"
    export AR=$CROSS_COMPILER_PATH-ar
    export AS=$CROSS_COMPILER_PATH-as
}

check_sbox_rootfs()
{
    if [ -e $SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME/usr/lib/libdl.so ]; then
        echo "$TARGET_CONFIG rootfs state is good"
    else
        echo "Error:"
        echo "\tCurrent rootfs contain broken symlinks, please do next:"
        echo "\tcd $SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME/usr/lib"
        echo "\t$CDR/fix_sbox_rootfs_links.pl"
        exit 0;
    fi
}

check_sbox2()
{
    if [ $NEED_SBOX2 = false ];then
        return;
    fi
    export SB2_SHELL="sb2 -t $TARGET_CONFIG"
    which sb2;
    if [ "$?" = "1" ]; then
      echo "Error:\n\tscratchbox2 must be installed for harmattan cross compile environment for running rcc and moc qt tools";
      echo "\trun:\tsudo apt-get install scratchbox2"
      exit 1;
    fi
    sb2 -t harmattan echo
    if [ "$?" = "1" ]; then
      echo "scratchbox2 must have \"harmattan\" target wrapped around harmattan rootfs";
      echo "  execute: sudo /etc/init.d/scratchbox-core stop"
      echo "  and run:\n  cd $SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME;"
      echo "  sb2-init -n -N -M arm -m devel  -t $SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME harmattan /scratchbox/compilers/cs2009q3-eglibc2.10-armv7-hard/bin/arm-none-linux-gnueabi-gcc"
      exit 1;
    fi
}

case $TARGET_CONFIG in
  "desktop")
    echo "Building for desktop"
    MOZCONFIG=mozconfig.qtdesktop
    ;;
  "harmattan")
    echo "Building for harmattan"
    ROOTFSNAME=HARMATTAN_ARMEL

    SBOX_PATH=/scratchbox
    check_sbox_rootfs
    NEED_SBOX2=true
    MOZCONFIG=mozconfig.qtN9-qt-cross
    export CROSS_COMPILE=1
    export CROSS_TARGET=--target=arm-none-linux-gnueabi
    export HOST_QMAKE="$CDR/cross-tools/host-qmake-4.7.4"
    export HOST_MOC="$CDR/cross-tools/host-moc-4.7.4"
    export MOC="$CDR/cross-tools/host-moc-4.7.4"
    export HOST_RCC="$CDR/cross-tools/host-rcc-4.7.4"
    export RCC="$CDR/cross-tools/host-rcc-4.7.4"
    export TARGET_ROOTFS=$SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME
    export CROSS_COMPILER_PATH=$SBOX_PATH/compilers/cs2009q3-eglibc2.10-armv7-hard/bin/arm-none-linux-gnueabi
    export SYSROOT=$SBOX_PATH/compilers/cs2009q3-eglibc2.10-armv7-hard/arm-none-linux-gnueabi/libc
    ;;
  "fremantle")
    echo "Building for fremantle"
    ROOTFSNAME=FREMANTLE_ARMEL_GCC472
    SBOX_PATH=/scratchbox
    check_sbox_rootfs
    NEED_SBOX2=true
    MOZCONFIG=mozconfig.qtN900-qt-cross-x
    export HOST_QMAKE="$CDR/cross-tools/host-qmake-4.7.4"
    export HOST_MOC="$CDR/cross-tools/host-moc-4.7.4"
    export MOC="$CDR/cross-tools/host-moc-4.7.4"
    export HOST_RCC="$CDR/cross-tools/host-rcc-4.7.4"
    export RCC="$CDR/cross-tools/host-rcc-4.7.4"
    export TARGET_ROOTFS=$SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME
    export CROSS_COMPILER_PATH=$SBOX_PATH/compilers/linaro-4.7-2012.07-fremantle-armv7a/bin/arm-none-linux-gnueabi
    export SYSROOT=$SBOX_PATH/compilers/linaro-4.7-2012.07-fremantle-armv7a/arm-none-linux-gnueabi/libc
    ;;
  "mer")
    echo "Building for Mer"
    MOZCONFIG=mozconfig.merqtxulrunner
    ;;
  "raspberrypi")
    MOZCONFIG=mozconfig.rsppi-qt
    # assume rasppi embedlite build only works with qt5 located in /opt/qt5
    QT5DIR="/opt/qt5"
    EXTRAOPTS="$EXTRAOPTS ac_add_options --with-qtdir=$QT5DIR\n"
    # hardcode pkg config path for cross env
    export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
    # added default path to qt5 qmake
    export PATH=$QT5DIR/bin:$PATH
    ;;
  *)
    echo "Please specify valid target name\n\t Ex: ./build.sh desktop"
    exit 1;
    ;;
esac

echo "Building with MOZCONFIG=$MOZCONFIG in $OBJTARGETDIR"

# prepare engine mozconfig
cp -f $CDR/mozilla-central/embedding/embedlite/config/$MOZCONFIG $CDR/mozilla-central/
MOZCONFIG=$CDR/mozilla-central/$MOZCONFIG
echo "mk_add_options MOZ_OBJDIR=\"@TOPSRCDIR@/../$OBJTARGETDIR\"" >> $MOZCONFIG
echo "ac_add_options --disable-tests" >> $MOZCONFIG
echo "ac_add_options --disable-accessibility" >> $MOZCONFIG
#echo "ac_add_options --enable-debug" >> $MOZCONFIG
#echo "ac_add_options --enable-logging" >> $MOZCONFIG
echo "$EXTRAOPTS" >> $MOZCONFIG

build_engine()
{
    # Build engine
    echo "Checking $CDR/$OBJTARGETDIR/full_build_date"
    if [ -f $CDR/$OBJTARGETDIR/full_build_date ]; then
        echo "Full build ready"
        make -j4 -C $CDR/$OBJTARGETDIR/embedding/embedlite && make -j4 -C $CDR/$OBJTARGETDIR/toolkit/library
        RES=$?
        if [ "$RES" != "0" ]; then
            echo "Build failed, exit"
            exit $RES;
        fi
    else
        echo "Full build not ready"
        # build engine, take some time
        MOZCONFIG=$MOZCONFIG make -C mozilla-central -f client.mk build_all
        RES=$?
        if [ "$RES" != "0" ]; then
            echo "Build failed, exit"
            exit $RES;
        fi
        # disable symlinks for python stub
        cp -rfL $CDR/$OBJTARGETDIR/dist/sdk/bin $CDR/$OBJTARGETDIR/dist/sdk/bin_no_symlink
        rm -rf $CDR/$OBJTARGETDIR/dist/sdk/bin
        mv $CDR/$OBJTARGETDIR/dist/sdk/bin_no_symlink $CDR/$OBJTARGETDIR/dist/sdk/bin
        # make build stamp
        date +%s > $CDR/$OBJTARGETDIR/full_build_date
    fi

    if [ ! -f $CDR/$OBJTARGETDIR/dist/bin/libxul.so ]; then
        echo "Something went wrong, need full build"
        exit 1;
    fi
}

build_components()
{
    # Build Embedlite components
    setup_cross_autoconf_env
    mkdir -p $CDR/embedlite-components/$OBJTARGETDIR
    if [ ! -f $CDR/embedlite-components/configure ]; then
        cd $CDR/embedlite-components && NO_CONFIGURE=yes ./autogen.sh && cd $CDR
    fi
    if [ ! -f $CDR/embedlite-components/$OBJTARGETDIR/config.status ]; then
        cd $CDR/embedlite-components/$OBJTARGETDIR && $SB2_SHELL ../configure $CROSS_TARGET --prefix=/usr --with-engine-path=$CDR/$OBJTARGETDIR && cd $CDR
    fi
    export echo=echo && $SB2_SHELL make -j4 -C $CDR/embedlite-components/$OBJTARGETDIR
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    cd $CDR/embedlite-components && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin $OBJTARGETDIR
}

build_qtmozembed()
{
    check_sbox2
    # Build qtmozembed
    echo "BUILD: cd $CDR/qtmozembed && $SB2_SHELL $TARGET_QMAKE -recursive NO_TESTS=1 OBJ_PATH=$CDR/$OBJTARGETDIR OBJ_BUILD_PATH=$OBJTARGETDIR CONFIG+=staticlib && cd $CDR"
    cd $CDR/qtmozembed && $SB2_SHELL $TARGET_QMAKE -recursive NO_TESTS=1 OBJ_PATH=$CDR/$OBJTARGETDIR OBJ_BUILD_PATH=$OBJTARGETDIR CONFIG+=staticlib && cd $CDR
    cd $CDR/qtmozembed && $SB2_SHELL make clean
    $SB2_SHELL make -j4 -C $CDR/qtmozembed
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
}

build_qmlbrowser()
{
    check_sbox2
    # Build qmlmozbrowser
    cd $CDR/qmlmozbrowser && $SB2_SHELL $TARGET_QMAKE OBJ_BUILD_PATH=$OBJTARGETDIR DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin QTEMBED_LIB+=$CDR/qtmozembed/$OBJTARGETDIR/libqtembedwidget.a INCLUDEPATH+=$CDR/qtmozembed/src && cd $CDR
    cd $CDR/qmlmozbrowser && $SB2_SHELL make clean
    $SB2_SHELL make -j4 -C $CDR/qmlmozbrowser
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    if [ ! -f $CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTest ]; then
        cd $CDR/qmlmozbrowser && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin $OBJTARGETDIR
    fi
}

build_engine
build_components
build_qtmozembed
build_qmlbrowser

echo "
run test example:
$CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTest -url about:license
"
