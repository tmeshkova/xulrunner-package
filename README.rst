This project contains scripts useful for hacking `the lightweight embedding
for Gecko <https://wiki.mozilla.org/Embedding/IPCLiteAPI>`_.

How to configure development environment for Mer
================================================

Gecko engine development for embedded devices is quite resource consuming.
If you want to try it you'd better have a mighty computer running Linux and
avoid virtualization.

First of all you'll need to install Mer platform SDK and enter into it. Look at
`this wiki page <https://wiki.merproject.org/wiki/Platform_SDK>`_ for details and
follow the instructions till the part "Basic tasks".

Then you'll need to create and install a rootfs. More detailed instructions
can be found `here <https://wiki.merproject.org/wiki/Platform_SDK_and_SB2>`_,
but below is an extarct from there::

  MerSDK$ sudo mkdir -p /parentroot/srv/mer/targets
  MerSDK$ cd /tmp

Now in the current directory (which is /tmp) create a file `mer-target-armv7hl.ks`
with the following content::

  # -*-mic2-options-*- --arch=armv7hl -*-mic2-options-*-

  lang en_US.UTF-8
  keyboard us
  timezone --utc UTC
  part / --size 500 --ondisk sda --fstype=ext4
  rootpw rootme

  user --name mer  --groups audio,video --password rootme

  repo --name=sailfish --baseurl=http://releases.jolla.com/releases/latest/jolla/armv7hl --save --debuginfo

  %packages
  glibc-devel
  mesa-llvmpipe-libEGL-devel
  mesa-llvmpipe-libGLESv2-devel
  shadow-utils
  rpm-build
  meego-rpm-config
  zypper
  %end

  %post
  ## rpm-rebuilddb.post from mer-kickstarter-configs package
  # Rebuild db using target's rpm
  echo -n "Rebuilding db using target rpm.."
  rm -f /var/lib/rpm/__db*
  rpm --rebuilddb
  echo "done"
  ## end rpm-rebuilddb.post

  ## arch-armv7hl.post from mer-kickstarter-configs package
  # Without this line the rpm don't get the architecture right.
  echo -n 'armv7hl-meego-linux' > /etc/rpm/platform

  # Also libzypp has problems in autodetecting the architecture so we force tha as well.
  # https://bugs.meego.com/show_bug.cgi?id=11484
  echo 'arch = armv7hl' >> /etc/zypp/zypp.conf
  ## end arch-armv7hl.post

  %end

Then create a target::

  MerSDK$ sudo mic create fs mer-target-armv7hl.ks -o /parentroot/srv/mer/targets --pkgmgr=zypp --arch=armv7hl --tokenmap=MER_RELEASE:latest
  MerSDK$ sudo chown -R $USER /parentroot/srv/mer/targets/mer-target-armv7hl/

Now tweak the target to recognize you::

  MerSDK$ cd /parentroot/srv/mer/targets/mer-target-armv7hl/
  MerSDK$ grep :$(id -u): /etc/passwd >> etc/passwd
  MerSDK$ grep :$(id -g): /etc/group >> etc/group
  
Configure it to work with Scratchbox2 together::

  MerSDK$ cd /parentroot/srv/mer/targets/mer-target-armv7hl/
  MerSDK$ sb2-init -d -L "--sysroot=/" -C "--sysroot=/" -c /usr/bin/qemu-arm-dynamic -m sdk-build -n -N -t / mer-target-armv7hl /opt/cross/bin/armv7hl-meego-linux-gnueabi-gcc
  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-install -R zypper ref --force

Clone web engine git repos to your local file system (e.g. into
the local directory `$HOME/tmp/mozilla-temp/`)::

  $ mkdir -p $HOME/tmp/mozilla-temp
  $ cd $HOME/tmp/mozilla-temp
  $ git clone git@github.com:tmeshkova/xulrunner-package.git
  $ cd xulrunner-package
  $ ./pull.all.sh

After that install build requirements to the rootfs::

  MerSDK$ cd $HOME/tmp/mozilla-temp/xulrunner-package
  MerSDK$ grep --color=never BuildRequires mozilla-central/rpm/xulrunner-qt5.spec | sed -e '/^#.*$/d' | gawk -F: '{ print $2 }' | tr ',' ' '| xargs sb2 -t mer-target-armv7hl -m sdk-install -R zypper in
  MerSDK$ grep --color=never BuildRequires qtmozembed/rpm/qtmozembed-qt5.spec | sed -e '/^#.*$/d' | gawk -F: '{ print $2 }' | tr ',' ' '|xargs sb2 -t mer-target-armv7hl -m sdk-install -R zypper in
  MerSDK$ grep --color=never BuildRequires embedlite-components/rpm/embedlite-components-qt5.spec | sed -e '/^#.*$/d' | gawk -F: '{ print $2 }' | tr ',' ' '|xargs sb2 -t mer-target-armv7hl -m sdk-install -R zypper in
  MerSDK$ grep --color=never BuildRequires sailfish-browser/rpm/sailfish-browser.spec | sed -e '/^#.*$/d' | gawk -F: '{ print $2 }' | tr ',' ' '|xargs sb2 -t mer-target-armv7hl -m sdk-install -R zypper in

Remove the packages that are not really needed for engine development::

  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-install -R zypper rm qtmozembed-qt5 qtmozembed-qt5-devel xulrunner-qt5 xulrunner-qt5-devel

And finally build the stuff with the `build.sh` script::

  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-build ./build.sh -j -t mer

The option `-j` here makes `build.sh` build sailfish-browser binaries as well.

When everything is successfully built the script will show instructions on how
to run the newly built browser::

  ...
  make[1]: Leaving directory `/home/rozhkov/tmp/mozilla-temp/xulrunner-package/sailfish-browser/src'
  make: Leaving directory `/home/rozhkov/tmp/mozilla-temp/xulrunner-package/sailfish-browser'

  prepare run-time environment:
  export LD_LIBRARY_PATH=/home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer/src
  export QML_IMPORT_PATH=/home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer/qmlplugin5
  export QML2_IMPORT_PATH=/home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer/qmlplugin5

  run unit-tests:
  export QTTESTSROOT=/home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/tests
  export QTTESTSLOCATION=/home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/tests/auto/mer-qt5
  export QTMOZEMBEDOBJDIR=/home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer
  /home/rozhkov/tmp/mozilla-temp/xulrunner-package/qtmozembed/tests/auto/run-tests.sh

  run test example:
  /home/rozhkov/tmp/mozilla-temp/xulrunner-package/objdir-mer/dist/bin/qmlMozEmbedTestQt5  -fullscreen  -url about:license
  /home/rozhkov/tmp/mozilla-temp/xulrunner-package/objdir-mer/dist/bin/sailfish-browser about:license

.. note::
   Due to a bug in gecko build scripts you might encounter an error message about missing `config.status`
   file after the build configuration phase. In this case just copy the file `objdir-mer/config.status`
   to your working directory and run `build.sh` again::

     MerSDK$ cp objdir-mer/config.status .
     MerSDK$ sb2 -t mer-target-armv7hl -m sdk-build ./build.sh -j -t mer

The best way to test the build is to mount the working directory into the
device's file system so that the path to the built binaries on the device is
the same as in the host filesystem. For this you'll need to have the package
`sshfs` installed on the device::

  [nemo@localhost-001 ~]$ mkdir tmp
  [nemo@localhost-001 ~]$ sshfs <your_username>@192.168.2.14:/home/<your_username>/tmp tmp
  [nemo@localhost-001 ~]$ devel-su
  [root@localhost-001 nemo]$ cd /home
  [root@localhost-001 home]$ ln -s nemo <your_username>
  [root@localhost-001 home]$ exit
  [nemo@localhost-001 ~]$ cd tmp/mozilla-temp/xulrunner-package
  [nemo@localhost-001 xulrunner-package]$ export LD_LIBRARY_PATH=/home/<your_username>/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer/src
  [nemo@localhost-001 xulrunner-package]$ export QML_IMPORT_PATH=/home/<your_username>/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer/qmlplugin5
  [nemo@localhost-001 xulrunner-package]$ export QML2_IMPORT_PATH=/home/<your_username>/tmp/mozilla-temp/xulrunner-package/qtmozembed/objdir-mer/qmlplugin5
  [nemo@localhost-001 xulrunner-package]$ /home/<your_username>/tmp/mozilla-temp/xulrunner-package/objdir-mer/dist/bin/sailfish-browser about:license

By now you should have working development environment. If you change code under
`mozilla-central/embedding/embedlite`, `qtmozembed`, `embedlite-components` or
`sailfish-browser` just run the `build.sh` script again::

  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-build ./build.sh -j -t mer

If you change something inside other gecko components, e.g. under `mozilla-central/dom/events`
or `mozilla-central/gfx`,
then you'll need to rebuild the outdated object files too with the option `-o`::

  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-build ./build.sh -j -t mer -o dom/events,gfx

This way there is no need to rebuild all other object files. And if you're working
on the engine only then you might want to use the option `-e` of `build.sh` that
makes the script to rebuild only the engine::

  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-build ./build.sh -e -t mer

Useful info
-----------

If you're working on JS components don't forget to reset the start up cache
before testing your work::

  [nemo@localhost-001 xulrunner-package]$ rm -fr ~/.mozilla/mozembed/startupCache/

If you need to switch on `logging <https://wiki.mozilla.org/MailNews:Logging>`_
in the engine then define `NSPR_LOG_MODULES` environment variable::

  [nemo@localhost-001 xulrunner-package]$ export NSPR_LOG_MODULES=TabChildHelper:5,EmbedLiteTrace:5,EmbedContentController:5 

.. warning::
   In order to see logging from components other than EmbedLite you'd need to
   have a so called debug build of xulrunner. Use the option `-d` of the
   `build.sh` script to create it.

Unfortunately the gecko build system is based on python which runs under qemu
inside Scratchbox2 by default (unless you do x86 build). It is possible to accelerate python though.
To achieve this you need to use a special Scratchbox2 mode `sdk-build+pp` and
to add the option `-r` to `build.sh`::

  MerSDK$ sb2 -t mer-target-armv7hl -m sdk-build+pp ./build.sh -r -j -t mer

Happy hacking!
