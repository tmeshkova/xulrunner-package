#!/bin/sh

#ENGINE_BRANCH=embedlite_aurora_26
ENGINE_BRANCH=embedlite
git pull && git submodule init && git submodule update && git submodule status
CURDIR=$PWD
cd embedlite-components && git checkout master && git pull && cd $CURDIR
cd qmlmozbrowser && git checkout master && git pull && cd $CURDIR
cd qtmozembed && git checkout master && git pull && cd $CURDIR
cd mozilla-central && git checkout $ENGINE_BRANCH && git fetch origin && git merge origin/$ENGINE_BRANCH && cd $CURDIR

