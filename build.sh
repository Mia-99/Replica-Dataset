#!/usr/bin/env bash
# Copyright (c) Facebook, Inc. and its affiliates. All Rights Reserved

cd 3rdparty/Pangolin
mkdir build
cd build
cmake ..
make -j

cd ../../../
mkdir build
cd build
cmake .. -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
make -j
