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
BUILD_X=false
GLPROVIDER=
BUILD_QT5QUICK1=
BUILD_QTMOZEMBEDSTATIC=false
OBJDIRS=
BUILD_BACKEND=false
ENGINE_ONLY=false
BUILD_SAILFISH=false
TOOLS_REDIRECT=false
NO_ENGINE_BUILD=false

usage()
{
    echo "./build.sh -t desktop"
}

while getopts “hdcjreno:x:s:g:t:p:v” OPTION
do
 case $OPTION in
     h)
         usage
         exit 1
         ;;
     c)
         BUILD_BACKEND=true
         ;;
     e)
         ENGINE_ONLY=true
         ;;
     d)
         DEBUG_BUILD=1
         ;;
     r)
         TOOLS_REDIRECT=true
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
     j)
         BUILD_SAILFISH=true
         ;;
     n)
         NO_ENGINE_BUILD=true
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

echo "DEBUG_BUILD=$DEBUG_BUILD, TARGET_CONFIG=$TARGET_CONFIG, CUSTOM_BUILD=$CUSTOM_BUILD GLPROVIDER=$GLPROVIDER BUILD_X=$BUILD_X QT_VERSION=$QT_VERSION BUILD_SAILFISH=$BUILD_SAILFISH"

if [ -z $TARGET_CONFIG ]
then
     usage
     exit 1
fi

OBJTARGETDIR=objdir-$TARGET_CONFIG$CUSTOM_BUILD
QT_VERSION=`qmake -v | grep 'Using Qt version' | grep -oP '\d+' | sed q`
if [ $QT_VERSION != 5 ]; then
  echo "Building with qt4 is not supported"
  exit 1
fi
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
    EXTRAQTMOZEMBEDFLAGS=""
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


echo "DEBUG_BUILD=$DEBUG_BUILD, TARGET_CONFIG=$TARGET_CONFIG, CUSTOM_BUILD=$CUSTOM_BUILD GLPROVIDER=$GLPROVIDER BUILD_X=$BUILD_X QT_VERSION=$QT_VERSION BUILD_SAILFISH=$BUILD_SAILFISH"
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
if [[ "$ARCH" != *arm* ]]
then
  echo "ac_add_options --disable-optimize" >> $MOZCONFIGTEMP
fi
fi
if [ $BUILD_X == false ];then
echo "ac_add_options --without-x" >> $MOZCONFIGTEMP
else
echo "ac_add_options --with-x" >> $MOZCONFIGTEMP
fi
if [ "$GLPROVIDER" == "GLX" ]; then
echo "ac_add_options --with-x" >> $MOZCONFIGTEMP
else
  if [ "$GLPROVIDER" == "" ]; then
    if [ $TARGET_CONFIG == "desktop" ]; then
      echo "ac_add_options --with-x" >> $MOZCONFIGTEMP
    fi
  fi
fi

if [ $GLPROVIDER ]; then
echo "ac_add_options --with-gl-provider=$GLPROVIDER" >> $MOZCONFIGTEMP
OBJTARGETDIR=$OBJTARGETDIR-$GLPROVIDER
fi
CPUNUM=`grep -c ^processor /proc/cpuinfo`
ans=$(( CPUNUM * 2 + 1 ))
PARALLEL_JOBS=$ans
echo "PARALLEL_JOBS=$PARALLEL_JOBS"
echo "mk_add_options MOZ_MAKE_FLAGS=\"-j$PARALLEL_JOBS\"" >> $MOZCONFIGTEMP
echo "mk_add_options MOZ_OBJDIR=\"@TOPSRCDIR@/../$OBJTARGETDIR\"" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-tests" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-accessibility" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-dbus" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-necko-wifi" >> $MOZCONFIGTEMP
echo "ac_add_options --disable-trace-malloc" >> $MOZCONFIGTEMP
echo "ac_add_options --enable-jemalloc" >> $MOZCONFIGTEMP
echo "mk_add_options AUTOCLOBBER=1" >> $MOZCONFIGTEMP
echo "$EXTRAOPTS" >> $MOZCONFIGTEMP

build_engine()
{
    # Setup tool redirection
    if [ $TOOLS_REDIRECT == true ]; then
        export SBOX_REDIRECT_FORCE=/usr/bin/python:/usr/bin/perl
        MOZDIR=$CDR/mozilla-central
        export DONT_POPULATE_VIRTUALENV=1
        export PYTHONPATH=$MOZDIR/python:$MOZDIR/config:$MOZDIR/build:$MOZDIR/xpcom/typelib/xpt/tools:$MOZDIR/dom/bindings:$MOZDIR/dom/bindings/parser:$MOZDIR/other-licenses/ply:$MOZDIR/media/webrtc/trunk/tools/gyp/pylib/
        for i in $(find $MOZDIR/python $MOZDIR/testing/mozbase -mindepth 1 -maxdepth 1 -type d); do
            export PYTHONPATH+=:$i
        done
    fi

    # Build engine
    echo "Checking $CDR/$OBJTARGETDIR/full_build_date"
    export MOZCONFIG=$MOZCONFIG
    cd $CDR/mozilla-central
    if [ -f $CDR/$OBJTARGETDIR/full_build_date ]; then
        echo "Full build ready"
        if [ $BUILD_BACKEND == true ]; then
          MOZCONFIG=$MOZCONFIG ./mach build-backend
        fi
        if [ $OBJDIRS ]; then
            MAKECMD=
            OBJDIRS=`echo $OBJDIRS | sed 's/,/ /g'`;
            echo "OBJDIRS=$OBJDIRS"
            for str in $OBJDIRS;do
                echo "MAKECMD=make -j$PARALLEL_JOBS -C $CDR/$OBJTARGETDIR/$str"
                make -j$PARALLEL_JOBS -C $CDR/$OBJTARGETDIR/$str
                RES=$?
                if [ "$RES" != "0" ]; then
                    echo "Build failed at $CDR/$OBJTARGETDIR/$str, exit: err code:$RES"
                    cd $CDR
                    exit $RES;
                fi
            done
        fi
        make -j$PARALLEL_JOBS -C $CDR/$OBJTARGETDIR/embedding/embedlite && make -j$PARALLEL_JOBS -C $CDR/$OBJTARGETDIR/toolkit/library
        RES=$?
        if [ "$RES" != "0" ]; then
            echo "Build failed, exit: err code:$RES"
            cd $CDR
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
            MOZCONFIG=$MOZCONFIG ./mach configure
            date +%s > $CDR/$OBJTARGETDIR/full_config_date
            cp $CDR/$OBJTARGETDIR/config.status $CDR/
        fi
        MOZCONFIG=$MOZCONFIG ./mach build
        #make -j8 -C $CDR/$OBJTARGETDIR
        RES=$?
        date +%s > $CDR/$OBJTARGETDIR/full_config_date
        if [ "$RES" != "0" ]; then
            echo "Build failed, exit"
            cd $CDR
            exit $RES;
        fi
        # disable symlinks for python stub
        cp -rfL $CDR/$OBJTARGETDIR/dist/sdk/bin $CDR/$OBJTARGETDIR/dist/sdk/bin_no_symlink
        rm -rf $CDR/$OBJTARGETDIR/dist/sdk/bin
        mv $CDR/$OBJTARGETDIR/dist/sdk/bin_no_symlink $CDR/$OBJTARGETDIR/dist/sdk/bin
        # make build stamp
        date +%s > $CDR/$OBJTARGETDIR/full_build_date
        rm -f $CDR/config.status $CDR/config.statusc
    fi

    cd $CDR
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
    if [ $BUILD_QTMOZEMBEDSTATIC == true ]; then
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
    SF_TARGET=
    if [ "$TARGET_CONFIG" == "mer" ]; then
      SF_TARGET=1
    fi
    LIBQTEMBEDWIDGET="libqt5embedwidget"
    cd $CDR/qmlmozbrowser && $SB2_SHELL $TARGET_QMAKE -recursive BUILD_QT5QUICK1=$BUILD_QT5QUICK1 SF_TARGET=$SF_TARGET OBJ_BUILD_PATH=$OBJTARGETDIR DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin QTEMBED_LIB+=$CDR/qtmozembed/$OBJTARGETDIR/src/$LIBQTEMBEDWIDGET.$LIBSUFFIX INCLUDEPATH+=$CDR/qtmozembed/src && cd $CDR
    cd $CDR/qmlmozbrowser && $SB2_SHELL make clean
    $SB2_SHELL make -j$PARALLEL_JOBS -C $CDR/qmlmozbrowser
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    cd $CDR/qmlmozbrowser && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin $OBJTARGETDIR
}

build_sailfish_browser()
{
    check_sbox2
    # Build sailfish_browser
    LIBSUFFIX="so"
    if [ $BUILD_QTMOZEMBEDSTATIC == true ]; then
      LIBSUFFIX="a"
    fi
    LIBQTEMBEDWIDGET="libqt5embedwidget"
    export USE_RESOURCES=1
    cd $CDR/sailfish-browser && $SB2_SHELL $TARGET_QMAKE -recursive USE_RESOURCES=1 BUILD_QT5QUICK1=$BUILD_QT5QUICK1 OBJ_BUILD_PATH=$OBJTARGETDIR DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin QTEMBED_LIB+=$CDR/qtmozembed/$OBJTARGETDIR/src/$LIBQTEMBEDWIDGET.$LIBSUFFIX INCLUDEPATH+=$CDR/qtmozembed/src && cd $CDR
    cd $CDR/sailfish-browser && $SB2_SHELL make clean
    $SB2_SHELL make -j$PARALLEL_JOBS -C $CDR/sailfish-browser
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    cd $CDR/sailfish-browser && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin $OBJTARGETDIR
}


if [ $NO_ENGINE_BUILD == false ]; then
  build_engine
fi
if [ $ENGINE_ONLY == false ]; then
  build_components
  build_qtmozembed
  build_qmlbrowser
  if [ $BUILD_SAILFISH == true ]; then
    build_sailfish_browser
  fi
fi


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
run test example:"
if [ $BUILD_QT5QUICK1 ]; then
echo
echo -n "$CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTest $EXTRA_ARGS -url about:license"
fi
if [ "$QT_VERSION" == "5" ]; then
echo
echo -n "$CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTestQt5 $EXTRA_ARGS -url about:license"
fi
if [ $BUILD_SAILFISH == true ]; then
echo
echo -n "$CDR/$OBJTARGETDIR/dist/bin/sailfish-browser about:license"
fi
echo;echo;

