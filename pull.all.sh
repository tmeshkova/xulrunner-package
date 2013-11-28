#!/bin/sh

ENGINE_BRANCH=embedlite
OTHER_BRANCH=master
#ENGINE_BRANCH=embedlite_26
#OTHER_BRANCH=embedlite_26
git pull && git submodule init && git submodule update && git submodule status
CURDIR=$PWD
cd embedlite-components && echo embedlite-components && git checkout $OTHER_BRANCH && git fetch origin && git merge origin/$OTHER_BRANCH && cd $CURDIR
cd qmlmozbrowser && echo qmlmozbrowser && git checkout master && git pull && cd $CURDIR
cd qtmozembed && echo qtmozembed && git checkout $OTHER_BRANCH && git fetch origin && git merge origin/$OTHER_BRANCH && cd $CURDIR
cd mozilla-central && echo mozilla-central && git checkout $ENGINE_BRANCH && git fetch origin && git merge origin/$ENGINE_BRANCH && cd $CURDIR

