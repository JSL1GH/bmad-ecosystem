#!/usr/bin/env zsh
set -euo pipefail

# Prior to using this script:
# Make a directory called "${HOME}/Projects" if it does not exist
cd "$HOME/Projects"

# Require a non-empty rollout argument
if (( $# < 1 )) || [[ -z "${1:-}" ]]; then
  echo "Need a rollout argument (to make unique) - quitting" >&2
  exit 1
fi

ROLLOUT="$1"
echo "Installing in attempt.${ROLLOUT}"

# Create / enter working dir
mkdir -p "attempt.${ROLLOUT}"
cd "attempt.${ROLLOUT}"

# Create install prefix dir
mkdir -p "$HOME/bmadTryExternal.${ROLLOUT}"

# Clone repo (force directory name to be stable)
git clone -b updated_bmad --recurse-submodules \
  "https://github.com/JSL1GH/Bmad-external.git" "Bmad-external"

cd "Bmad-external"

# Build
mkdir -p build
cd build

cmake .. \
  -DCMAKE_PRINT_DEBUG=ON \
  -DBUILD_ALL=ON \
  -DBUILD_ANYWAY=ON \
  -DCUSER_FORCE=ON \
  -DCMAKE_INSTALL_PREFIX="$HOME/bmadTryExternal.${ROLLOUT}"

make
# If you actually want to install into the prefix, uncomment:
# make install
