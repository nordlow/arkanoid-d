#!/bin/bash

set -euo pipefail

if [ ! -d "SDL/.git" ]; then
  echo "Cloning SDL..."
  git clone https://github.com/libsdl-org/SDL.git
else
  git -C SDL pull
fi

pushd SDL
mkdir -p build
pushd build

DST_PREFIX=${HOME}/.local

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${DST_PREFIX}/sdl-snapshot" -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=ON ..
cmake --build . --config Release --parallel
cmake --install . --config Release

popd
