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

# make sure it exists
if (! -d $HOME/Projects/attempt.${ROLLOUT}) then
    echo "Directory does not exist - $HOME/Projects/attempt.${ROLLOUT}"
    echo "It is expected that it was created for the external libraries - exiting"
    exit
else
#    echo "This string has" '"actual quotes"' "inside it."
    echo "Found directory - "\""$HOME/Projects/attempt.${ROLLOUT}"\"" - continuing..."
endif

mkdir ${HOME}/bmadTryInternal.${ROLLOUT}
cd ${HOME}/Projects
cd attempt.${ROLLOUT}
mkdir bmadEcosystem.${ROLLOUT}
cd bmadEcosystem.${ROLLOUT}
git clone -b updated_bmad https://github.com/JSL1GH/bmad-ecosystem.git
cd bmad-ecosystem
mkdir build
cd build

#cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/home/cfsd/laster/bmadTryInternal.31 -DBMAD_EXTERNAL=/home/cfsd/laster/bmadTryExternal.31 -DCMAKE_MODULE_PATH=/home/cfsd/laster/bmadTryExternal.31 -DCMAKE_PREFIX_PATH=/home/cfsd/laster/bmadTryExternal.31 --debug-find
#cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/home/cfsd/laster/bmadTryInternal.31 -DBMAD_EXTERNAL=/home/cfsd/laster/bmadTryExternal.31 -DCMAKE_PREFIX_PATH=/home/cfsd/laster/bmadTryExternal.31

#cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/home/cfsd/laster/bmadTryInternal.31 -DBMAD_EXTERNAL=/home/cfsd/laster/bmadTryExternal.31 -DCMAKE_PREFIX_PATH=/home/cfsd/laster/bmadTryExternal.31 -DBMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH=ON

cmake .. -DCMAKE_INSTALL_PREFIX:PATH=${HOME}/bmadTryInternal.${ROLLOUT} -DBMAD_EXTERNAL=${HOME}/bmadTryExternal.${ROLLOUT} -DCMAKE_PREFIX_PATH=${HOME}/bmadTryExternal.${ROLLOUT}

make install

