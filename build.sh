#!/bin/bash

CDR=$(pwd)
ARCH=`uname -m`
USERNAME=`whoami`
EXTRA_ARGS=""
MOZCONFIG=""
EXTRAOPTS=""
TARGET_CONFIG=
CUSTOM_BUILD=
DEBUG_BUILD=
EXTRAQTMOZEMBEDFLAGS="NO_TESTS=1"
HOST_QMAKE=qmake
TARGET_QMAKE=qmake
NEED_SBOX2=false
BUILD_X=
GLPROVIDER=
BUILD_QT5QUICK1=
BUILD_QTMOZEMBEDSTATIC=
OBJDIRS=

usage()
{
    echo "./build.sh -t desktop"
}

while getopts “hdo:x:s:g:t:p:v” OPTION
do
 case $OPTION in
     h)
         usage
         exit 1
         ;;
     d)
         DEBUG_BUILD=1
         ;;
     t)
         TARGET_CONFIG=$OPTARG
         ;;
     g)
         GLPROVIDER=$OPTARG
         ;;
     o)
         OBJDIRS=$OPTARG
         ;;
     p)
         CUSTOM_BUILD=$OPTARG
         ;;
     x)
         BUILD_X=$OPTARG
         ;;
     s)
         BUILD_QTMOZEMBEDSTATIC=$OPTARG
         ;;
     v)
         VERBOSE=1
         ;;
     ?)
         usage
         exit
         ;;
 esac
done

echo "DEBUG_BUILD=$DEBUG_BUILD, TARGET_CONFIG=$TARGET_CONFIG, CUSTOM_BUILD=$CUSTOM_BUILD GLPROVIDER=$GLPROVIDER BUILD_X=$BUILD_X QT_VERSION=$QT_VERSION"

if [ -z $TARGET_CONFIG ]
then
     usage
     exit 1
fi

OBJTARGETDIR=objdir-$TARGET_CONFIG$CUSTOM_BUILD
QT_VERSION=`qmake -v | grep 'Using Qt version' | grep -oP '\d+' | sed q`
setup_qt_version()
{
  check_sbox2
  QT_VERSION=`$SB2_SHELL $TARGET_QMAKE  -v | grep 'Using Qt version' | grep -oP '\d+' | sed q`
}

setup_cross_autoconf_env()
{
    if [ $NEED_SBOX2 == false ];then
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
    if [ $NEED_SBOX2 == false ];then
        return;
    fi
    export SB2_SHELL="sb2 -t $TARGET_CONFIG"
    which sb2;
    if [ "$?" == "1" ]; then
      echo "Error:\n\tscratchbox2 must be installed for harmattan cross compile environment for running rcc and moc qt tools";
      echo "\trun:\tsudo apt-get install scratchbox2"
      exit 1;
    fi
    sb2 -t harmattan echo
    if [ "$?" == "1" ]; then
      echo "scratchbox2 must have \"harmattan\" target wrapped around harmattan rootfs";
      echo "  execute: sudo /etc/init.d/scratchbox-core stop"
      echo "  and run:\n  cd $SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME;"
      echo "  sb2-init -n -N -M arm -m devel  -t $SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME harmattan /scratchbox/compilers/cs2009q3-eglibc2.10-armv7-hard/bin/arm-none-linux-gnueabi-gcc"
      exit 1;
    fi
}

case $TARGET_CONFIG in
  "desktop")
    if [ $QT_VERSION == 5 ]; then
      EXTRAQTMOZEMBEDFLAGS=""
    fi
    echo "Building for desktop: $QT_VERSION"
    BUILD_QT5QUICK1=true
    MOZCONFIG=mozconfig.qtdesktop
    ;;
  "harmattan")
    echo "Building for harmattan"
    ROOTFSNAME=HARMATTAN_ARMEL

    SBOX_PATH=/scratchbox
    check_sbox_rootfs
    NEED_SBOX2=true
    setup_qt_version
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
    setup_qt_version
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
    EXTRAQTMOZEMBEDFLAGS=""
    EXTRA_ARGS=" -fullscreen "
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

if [ $DEBUG_BUILD ]; then
OBJTARGETDIR=$OBJTARGETDIR-dbg
fi


echo "DEBUG_BUILD=$DEBUG_BUILD, TARGET_CONFIG=$TARGET_CONFIG, CUSTOM_BUILD=$CUSTOM_BUILD GLPROVIDER=$GLPROVIDER BUILD_X=$BUILD_X QT_VERSION=$QT_VERSION"
echo "Building with MOZCONFIG=$MOZCONFIG in $OBJTARGETDIR"

# prepare engine mozconfig
cp -f $CDR/mozilla-central/embedding/embedlite/config/$MOZCONFIG $CDR/mozilla-central/$MOZCONFIG.temp
MOZCONFIGTEMP=$CDR/mozilla-central/$MOZCONFIG.temp
MOZCONFIG=$CDR/mozilla-central/$MOZCONFIG
if [ $DEBUG_BUILD ]; then
echo "Debug build enabled"
echo "ac_add_options --enable-debug" >> $MOZCONFIGTEMP
echo "ac_add_options --enable-logging" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-optimize" >> $MOZCONFIGTEMP
fi
if [ "$GLPROVIDER" == "GLX" ]; then
echo "ac_add_options --with-x" >> $MOZCONFIGTEMP
fi
if [ $BUILD_X ]; then
echo "ac_add_options --with-x" >> $MOZCONFIGTEMP
fi
if [ $GLPROVIDER ]; then
echo "ac_add_options --with-gl-provider=$GLPROVIDER" >> $MOZCONFIGTEMP
fi
CPUNUM=`grep -c ^processor /proc/cpuinfo`
ans=$(( CPUNUM * 2 + 1 ))
PARALLEL_JOBS=$ans
echo "PARALLEL_JOBS=$PARALLEL_JOBS"
echo "mk_add_options MOZ_MAKE_FLAGS=\"-j$PARALLEL_JOBS\"" >> $MOZCONFIGTEMP
echo "mk_add_options MOZ_OBJDIR=\"@TOPSRCDIR@/../$OBJTARGETDIR\"" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-tests" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-accessibility" >> $MOZCONFIGTEMP
echo "mk_add_options AUTOCLOBBER=1" >> $MOZCONFIGTEMP
echo "$EXTRAOPTS" >> $MOZCONFIGTEMP

build_engine()
{
    # Build engine
    echo "Checking $CDR/$OBJTARGETDIR/full_build_date"
    export MOZCONFIG=$MOZCONFIG
    if [ -f $CDR/$OBJTARGETDIR/full_build_date ]; then
        echo "Full build ready"
        if [ $OBJDIRS ]; then
            MAKECMD=
            OBJDIRS=`echo $OBJDIRS | sed 's/,/ /g'`;
            for str in $OBJDIRS;do
                MAKECMD="$MAKECMD make -j$PARALLEL_JOBS -C $OBJTARGETDIR/$str &&"
            done
            MAKECMD=`echo $MAKECMD | sed 's/\&\&$//'`
            echo "OBJDIRS=$OBJDIRS"
            echo "MAKECMD=$MAKECMD"
            $MAKECMD
        fi
        make -j$PARALLEL_JOBS -C $CDR/$OBJTARGETDIR/embedding/embedlite && make -j$PARALLEL_JOBS -C $CDR/$OBJTARGETDIR/toolkit/library
        RES=$?
        if [ "$RES" != "0" ]; then
            echo "Build failed, exit"
            exit $RES;
        fi
    else
        echo "Full build not ready"
        # build engine, take some time
        if [ -f $CDR/$OBJTARGETDIR/full_config_date ]; then
            echo "Already configured"
        else
            cp -f $MOZCONFIGTEMP $MOZCONFIG
            echo "Need Full configure"
            MOZCONFIG=$MOZCONFIG make -C mozilla-central -f client.mk configure
            date +%s > $CDR/$OBJTARGETDIR/full_config_date
        fi
        MOZCONFIG=$MOZCONFIG make -C mozilla-central -f client.mk build_all
        #make -j8 -C $CDR/$OBJTARGETDIR
        RES=$?
        date +%s > $CDR/$OBJTARGETDIR/full_config_date
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
    export echo=echo && $SB2_SHELL make -j$PARALLEL_JOBS -C $CDR/embedlite-components/$OBJTARGETDIR
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
    STATIC_ARGS=
    if [ $BUILD_QTMOZEMBEDSTATIC ]; then
      STATIC_ARGS="CONFIG+=staticlib"
    fi
    echo "BUILD: cd $CDR/qtmozembed && $SB2_SHELL $TARGET_QMAKE -recursive $EXTRAQTMOZEMBEDFLAGS OBJ_PATH=$CDR/$OBJTARGETDIR $STATIC_ARGS OBJ_BUILD_PATH=$OBJTARGETDIR && cd $CDR"
    cd $CDR/qtmozembed && $SB2_SHELL $TARGET_QMAKE -recursive $EXTRAQTMOZEMBEDFLAGS BUILD_QT5QUICK1=$BUILD_QT5QUICK1 $STATIC_ARGS DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin OBJ_PATH=$CDR/$OBJTARGETDIR OBJ_BUILD_PATH=$OBJTARGETDIR && cd $CDR
    cd $CDR/qtmozembed && $SB2_SHELL make clean
    $SB2_SHELL make -j$PARALLEL_JOBS -C $CDR/qtmozembed
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
    LIBSUFFIX="so"
    if [ $BUILD_QTMOZEMBEDSTATIC == true ]; then
      LIBSUFFIX="a"
    fi
    cd $CDR/qmlmozbrowser && $SB2_SHELL $TARGET_QMAKE -recursive BUILD_QT5QUICK1=$BUILD_QT5QUICK1 OBJ_BUILD_PATH=$OBJTARGETDIR DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin QTEMBED_LIB+=$CDR/qtmozembed/$OBJTARGETDIR/src/libqtembedwidget.$LIBSUFFIX INCLUDEPATH+=$CDR/qtmozembed/src && cd $CDR
    cd $CDR/qmlmozbrowser && $SB2_SHELL make clean
    $SB2_SHELL make -j$PARALLEL_JOBS -C $CDR/qmlmozbrowser
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    cd $CDR/qmlmozbrowser && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin $OBJTARGETDIR
}

build_engine
build_components
build_qtmozembed
build_qmlbrowser

echo -n "
prepare run-time environment:
export LD_LIBRARY_PATH=$CDR/qtmozembed/$OBJTARGETDIR/src"

echo "
export QML_IMPORT_PATH=$CDR/qtmozembed/$OBJTARGETDIR/qmlplugin$QT_VERSION
export QML2_IMPORT_PATH=$CDR/qtmozembed/$OBJTARGETDIR/qmlplugin$QT_VERSION

run unit-tests:
export QTTESTSROOT=$CDR/qtmozembed/tests
export QTTESTSLOCATION=$CDR/qtmozembed/tests/auto/$TARGET_CONFIG-qt$QT_VERSION
export QTMOZEMBEDOBJDIR=$CDR/qtmozembed/$OBJTARGETDIR
$CDR/qtmozembed/tests/auto/run-tests.sh
"

echo -n "
run test example:
$CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTest $EXTRA_ARGS -url about:license"
if [ "$QT_VERSION" == "5" ]; then
echo
echo -n "$CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTestQt5 $EXTRA_ARGS -url about:license"
fi
echo;echo;

