#!/bin/sh

git pull && git submodule init && git submodule update && git submodule status
