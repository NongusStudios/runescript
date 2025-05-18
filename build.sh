#!/bin/sh

if [ ! -d bin/release ];
then
mkdir -p bin/release
fi

if [ ! -d bin/debug ];
then
mkdir -p bin/debug
fi

DBG_OUTPUT=bin/debug/runescript.out
RELEASE_OUTPUT=bin/release/runescriot.out

if [ "$1" == "release" ];
then
    odin build src -o:speed -out:$RELEASE_OUTPUT
    ./$RELEASE_OUTPUT
else
    odin build src -out:$DBG_OUTPUT
    ./$DBG_OUTPUT
fi