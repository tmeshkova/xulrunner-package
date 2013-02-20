#!/bin/sh

CDR=$(pwd)
ARCH=`uname -m`
OBJTARGETDIR=objdir-$ARCH
MOZCONFIG=""
EXTRAOPTS=""
if [ "$ARCH" = "arm" ]; then
    gcc --version | grep cs2009q3-hard-67-sb16
    if [ "$?" = "0" ]; then
        MOZCONFIG=mozconfig.qtN9-qt
    else
        gcc --version | grep "sbox-arm-none-linux-gnueabi-gcc (GCC) 4.2.1"
        if [ "$?" = "0" ]; then
            MOZCONFIG=mozconfig.qtN900-qt
        else
            gcc --version | grep "crosstool-NG"
            if [ "$?" = "0" ]; then
                MOZCONFIG=mozconfig.rsppi-qt
                # assume rasppi embedlite build only works with qt5 located in /opt/qt5
                QT5DIR="/opt/qt5"
                EXTRAOPTS="ac_add_options --with-qtdir=$QT5DIR"
                # hardcode pkg config path for cross env
                export PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig
                # added default path to qt5 qmake
                export PATH=$QT5DIR/bin:$PATH
            else
                echo "Unknow config for this environment"
                exit 1;
            fi
        fi
    fi
else
    if [ "$ARCH" = "armv7l" ]; then
        MOZCONFIG=mozconfig.merqtxulrunner
    else
        MOZCONFIG=mozconfig.qtdesktop
    fi
fi

echo "Building with MOZCONFIG=$MOZCONFIG in $OBJTARGETDIR"

# prepare engine mozconfig
cp -f $CDR/mozilla-central/embedding/embedlite/config/$MOZCONFIG $CDR/mozilla-central/
MOZCONFIG=$CDR/mozilla-central/$MOZCONFIG
echo "mk_add_options MOZ_OBJDIR=\"@TOPSRCDIR@/../$OBJTARGETDIR\"" >> $MOZCONFIG
echo "ac_add_options --disable-tests" >> $MOZCONFIG
echo "ac_add_options --disable-accessibility" >> $MOZCONFIG
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
        cd $CDR/embedlite-components/$OBJTARGETDIR && ../configure --prefix=/usr --with-engine-path=$CDR/$OBJTARGETDIR && cd $CDR
    fi
    export echo=echo && make -j4 -C $CDR/embedlite-components/$OBJTARGETDIR
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    if [ ! -f $CDR/$OBJTARGETDIR/dist/bin/components/EmbedLiteBinComponents.manifest ]; then
        cd $CDR/embedlite-components && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin/components
    fi
}

build_qtmozembed()
{
    # Build qtmozembed
    cd $CDR/qtmozembed && qmake OBJ_PATH=$CDR/$OBJTARGETDIR OBJ_ARCH=$ARCH CONFIG+=staticlib && cd $CDR
    cd $CDR/qtmozembed && make clean
    make -j4 -C $CDR/qtmozembed
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
}

build_qmlbrowser()
{
    # Build qmlmozbrowser
    cd $CDR/qmlmozbrowser && qmake OBJ_ARCH=$ARCH DEFAULT_COMPONENT_PATH=$CDR/$OBJTARGETDIR/dist/bin/components QTEMBED_LIB+=$CDR/qtmozembed/obj-$ARCH-dir/libqtembedwidget.a INCLUDEPATH+=$CDR/qtmozembed && cd $CDR
    cd $CDR/qmlmozbrowser && make clean
    make -j4 -C $CDR/qmlmozbrowser
    RES=$?
    if [ "$RES" != "0" ]; then
        echo "Build failed, exit"
        exit $RES;
    fi
    if [ ! -f $CDR/$OBJTARGETDIR/dist/bin/qmlMozEmbedTest ]; then
        cd $CDR/qmlmozbrowser && ./link_to_system.sh $CDR/$OBJTARGETDIR/dist/bin
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
