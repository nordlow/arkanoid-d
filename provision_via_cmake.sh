#!/bin/bash

set -euo pipefail

SDL_REPO_URL="https://github.com/libsdl-org/SDL.git"

# Pick 'ninja' if in the $PATH, otherwise 'make'.
if command -v ninja &> /dev/null; then
	BUILD_TOOL="ninja"
else
	BUILD_TOOL="make"
fi

# Map the build tool to the CMake generator and native silent flag
CMAKE_BUILD_TOOL=""
BUILD_TOOL_SILENT_FLAG=""
case "$BUILD_TOOL" in
	ninja)
		CMAKE_BUILD_TOOL="Ninja"
		BUILD_TOOL_SILENT_FLAG="--quiet"
		BUILD_FILE="build.ninja"
		;;
	make)
		CMAKE_BUILD_TOOL="Unix Makefiles"
		BUILD_TOOL_SILENT_FLAG="-s"
		BUILD_FILE="Makefile"
		;;
	*)
		echo "Error: Unknown build tool '${BUILD_TOOL}'. Supported tools are 'ninja' and 'make'." >&2
		exit 1
		;;
esac

if [ ! -d "SDL/.git" ]; then
	git clone "${SDL_REPO_URL}"
fi

SDL_BUILD_DIR=SDL/build

mkdir -p "${SDL_BUILD_DIR}"
pushd "${SDL_BUILD_DIR}" &>/dev/null || exit

DST_PREFIX="${HOME}/.local"
INSTALL_PREFIX="${DST_PREFIX}/sdl-snapshot"

if [[ ../CMakeLists.txt -nt "${BUILD_FILE}" ]]; then
	echo "Reconfiguring with CMake because '../CMakeLists.txt' is newer than 'Makefile'..."
	cmake --log-level=WARNING \
		-G "$CMAKE_BUILD_TOOL" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
		-DSDL_SHARED=ON \
		-DSDL_STATIC=ON \
		-DBUILD_SHARED_LIBS=ON \
		-DBUILD_STATIC_LIBS=ON \
		..
fi

# Build with the chosen tool and silent flag
cmake \
	--build . \
	--config Release \
	--parallel \
	-- \
	"$BUILD_TOOL_SILENT_FLAG" > /dev/null

popd &>/dev/null || exit
