#!/bin/sh

CDR=$(pwd)
ARCH=`uname -m`
MOZCONFIG=""
EXTRAOPTS=""
TARGET_CONFIG=INVALID_TARGET_NAME
if [ "$1" != "" ]; then
TARGET_CONFIG=$1
fi
OBJTARGETDIR=objdir-$TARGET_CONFIG$CUSTOM_BUILD
TARGET_QMAKE=qmake

case $TARGET_CONFIG in
  "desktop")
    echo "Building for desktop"
    MOZCONFIG=mozconfig.qtdesktop
    ;;
  "harmattan")
    echo "Building for harmattan"
    ROOTFSNAME=HARMATTAN_ARMEL
    SBOX_PATH=/scratchbox
    which sb2;
    if [ "$?" = "1" ]; then
      echo "scratchbox2 must be installed for harmattan cross compile environment for running rcc and moc qt tools";
      exit 1;
    fi
    sb2 -t harmattan echo
    if [ "$?" = "1" ]; then
      echo "scratchbox2 must have \"harmattan\" target wrapped around harmattan rootfs";
      echo "  execute: sudo /etc/init.d/scratchbox-core stop"
      echo "  and run:\n  cd $SBOX_PATH/users/`whoami`/targets/$ROOTFSNAME;"
      echo "  sb2-init -n -N -M arm -m devel  -t $SBOX_PATH/users/`whoami`/targets/$ROOTFSNAME harmattan /scratchbox/compilers/cs2009q3-eglibc2.10-armv7-hard/bin/arm-none-linux-gnueabi-gcc"
      exit 1;
    fi
    if [ -e $SBOX_PATH/users/`whoami`/targets/$ROOTFSNAME/usr/lib/libdl.so ]; then
        echo "Harmattan rootfs state is good"
    else
        echo "Error:"
        echo "\tCurrent rootfs contain broken symlinks, please do next:"
        echo "\tcd $SBOX_PATH/users/`whoami`/targets/$ROOTFSNAME/usr/lib"
        echo "\t$CDR/fix_sbox_rootfs_links.pl"
        exit 0;
    fi

    MOZCONFIG=mozconfig.qtN9-qt-cross
    USERNAME=`whoami`
    export HOST_MOC="sb2 -t harmattan host-moc"
    export HOST_RCC="sb2 -t harmattan host-rcc"
    export MOC="sb2 -t harmattan host-moc"
    export RCC="sb2 -t harmattan host-rcc"
    export SB2_SHELL="sb2 -t harmattan"
    export TARGET_ROOTFS=$SBOX_PATH/users/$USERNAME/targets/$ROOTFSNAME
    export CROSS_COMPILER_PATH=$SBOX_PATH/compilers/cs2009q3-eglibc2.10-armv7-hard/bin/arm-none-linux-gnueabi
    export SYSROOT=$SBOX_PATH/compilers/cs2009q3-eglibc2.10-armv7-hard/arm-none-linux-gnueabi/libc
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
    mkdir -p $CDR/embedlite-components/$OBJTARGETDIR
    if [ ! -f $CDR/embedlite-components/configure ]; then
        cd $CDR/embedlite-components && NO_CONFIGURE=yes ./autogen.sh && cd $CDR
    fi
    if [ ! -f $CDR/embedlite-components/$OBJTARGETDIR/config.status ]; then
        cd $CDR/embedlite-components/$OBJTARGETDIR && $SB2_SHELL ../configure --prefix=/usr --with-engine-path=$CDR/$OBJTARGETDIR && cd $CDR
    fi
    export echo=echo && $SB2_SHELL make -j4 -C $CDR/embedlite-components/$OBJTARGETDIR
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    if [ ! -f $CDR/$OBJTARGETDIR/dist/bin/components/EmbedLiteBinComponents.manifest ]; then
        cd $CDR/embedlite-components && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin $CUSTOM_BUILD
    fi
}

build_qtmozembed()
{
    # Build qtmozembed
    cd $CDR/qtmozembed && $SB2_SHELL $TARGET_QMAKE OBJ_PATH=$CDR/$OBJTARGETDIR OBJ_BUILD_PATH=$OBJTARGETDIR CONFIG+=staticlib && cd $CDR
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
    # Build qmlmozbrowser
    cd $CDR/qmlmozbrowser && $SB2_SHELL $TARGET_QMAKE OBJ_BUILD_PATH=$OBJTARGETDIR DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin QTEMBED_LIB+=$CDR/qtmozembed/$OBJTARGETDIR/libqtembedwidget.a INCLUDEPATH+=$CDR/qtmozembed && cd $CDR
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
