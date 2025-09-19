#!/bin/bash

set -euo pipefail

exec dub -q run --compiler=dmd
