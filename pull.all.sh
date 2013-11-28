#!/bin/sh

#ENGINE_BRANCH=embedlite_26
#OTHER_BRANCH=embedlite_26
ENGINE_BRANCH=embedlite
OTHER_BRANCH=master
git pull && git submodule init && git submodule update && git submodule status
CURDIR=$PWD
cd embedlite-components && git checkout $OTHER_BRANCH && git pull && cd $CURDIR
cd qmlmozbrowser && git checkout master && git pull && cd $CURDIR
cd qtmozembed && git checkout $OTHER_BRANCH && git pull && cd $CURDIR
cd mozilla-central && git checkout $ENGINE_BRANCH && git fetch origin && git merge origin/$ENGINE_BRANCH && cd $CURDIR

