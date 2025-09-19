#!/bin/bash

set -euo pipefail

if [ ! -d "SDL/.git" ]; then
	git clone https://github.com/libsdl-org/SDL.git
# else
#	git -C SDL pull
fi

pushd SDL &>/dev/null || exit
mkdir -p build
pushd build &>/dev/null || exit

DST_PREFIX="${HOME}/.local"
INSTALL_PREFIX="${DST_PREFIX}/sdl-snapshot"

if [[ ../CMakeLists.txt -nt Makefile ]]; then
	echo "Reconfiguring with CMake because '../CMakeLists.txt' is newer than 'Makefile' ..."
	cmake --log-level=WARNING \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
		-DBUILD_SHARED_LIBS=ON \
		-DBUILD_STATIC_LIBS=ON \
		..
fi

cmake \
	--build . \
	--config Release \
	--parallel \
	-- \
	--silent > /dev/null

popd &>/dev/null || exit
popd &>/dev/null || exit
