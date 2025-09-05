#!/bin/bash

set -euo pipefail

dub -q build --compiler=dmd

LD_LIBRARY_PATH=/home/per/.local/sdl-snapshot/lib gdb arkanoid
