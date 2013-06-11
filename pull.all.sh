#!/bin/sh

git pull && git submodule init && git submodule update && git submodule status
CURDIR=$PWD
cd embedlite-components && git checkout master && git pull && cd $CURDIR
cd qmlmozbrowser && git checkout master && git pull && cd $CURDIR
cd qtmozembed && git checkout master && git pull && cd $CURDIR
cd mozilla-central && git checkout embedlite && git pull && cd $CURDIR

