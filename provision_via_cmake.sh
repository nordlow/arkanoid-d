#!/bin/bash

set -euo pipefail

git clone https://github.com/libsdl-org/SDL.git

pushd SDL
mkdir -p build
pushd build

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${DST_PREFIX}/sdl-snapshot" ..
cmake --build . --config Release --parallel
cmake --install . --config Release

popd
