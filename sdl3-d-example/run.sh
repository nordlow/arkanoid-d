#!/bin/bash

set -euo pipefail

LD_LIBRARY_PATH="${HOME}"/.local/sdl-snapshot/lib dub run
