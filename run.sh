#!/bin/bash

set -euo pipefail

DST_PREFIX=SDL/build
LD_LIBRARY_PATH="${DST_PREFIX}" exec dub -q run --compiler=dmd
