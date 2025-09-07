#!/bin/bash

set -euo pipefail

DST_PREFIX=${HOME}/.local
LD_LIBRARY_PATH="${DST_PREFIX}"/sdl-snapshot/lib exec dub -q run --compiler=dmd
