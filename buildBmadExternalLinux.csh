#!/bin/tcsh

#prior to using this script
#make a directory called ${HOME}/Projects if it does not exist
cd ${HOME}/Projects

if ($#argv > 0) then
  if ("$1" == "") then
    echo "Need a rollout argument (to make unique) - quitting"
    exit
  endif
else
    echo "No argument supplied - need a rollout argument (to make unique) - quitting"
    exit
endif

set ROLLOUT = "$argv[1]"

echo "Installing in attempt.${ROLLOUT}"

mkdir attempt.${ROLLOUT}
cd attempt.${ROLLOUT}

mkdir ${HOME}/bmadTryExternal.${ROLLOUT}
git clone -b updated_bmad https://github.com/JSL1GH/Bmad-external.git --recurse-submodules

cd Bmad-external

mkdir build
cd build

cmake .. -DCMAKE_PRINT_DEBUG=True -DBUILD_ALL=ON -DBUILD_ANYWAY=ON -DCUSER_FORCE=ON -DCMAKE_INSTALL_PREFIX=${HOME}/bmadTryExternal.${ROLLOUT}

make
