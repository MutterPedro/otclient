#!/usr/bin/env bash

cd build || mkdir build && cd build
rm * -rf
cmake ../
make