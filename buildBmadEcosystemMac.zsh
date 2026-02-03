#!/usr/bin/env zsh
set -euo pipefail

# prior to using this script
# make a directory called ${HOME}/Projects if it does not exist
cd "$HOME/Projects"

# Arg check
if (( $# < 1 )) || [[ -z "${1:-}" ]]; then
  echo "Need a rollout argument (to make unique) - quitting" >&2
  exit 1
fi

ROLLOUT="$1"
echo "Installing in attempt.${ROLLOUT}"

attempt_dir="$HOME/Projects/attempt.${ROLLOUT}"

# make sure it exists
if [[ ! -d "$attempt_dir" ]]; then
  echo "Directory does not exist - $attempt_dir" >&2
  echo "It is expected that it was created for the external libraries - exiting" >&2
  exit 1
else
  echo "Found directory - \"$attempt_dir\" - continuing..."
fi

mkdir -p "$HOME/bmadTryInternal.${ROLLOUT}"

cd "$attempt_dir"
mkdir -p "bmadEcosystem.${ROLLOUT}"
cd "bmadEcosystem.${ROLLOUT}"

git clone -b updated_bmad https://github.com/JSL1GH/bmad-ecosystem.git
cd bmad-ecosystem
mkdir -p build
cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX:PATH="$HOME/bmadTryInternal.${ROLLOUT}" \
  -DBMAD_EXTERNAL="$HOME/bmadTryExternal.${ROLLOUT}" \
  -DCMAKE_PREFIX_PATH="$HOME/bmadTryExternal.${ROLLOUT}" \
  -DBMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH=ON

make install


