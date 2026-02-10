This file describes the various options available for building the bmad-ecosystem.

*** NOTE: The bmad-ecosystem relies on external libraries being available. They may be     ***
***       installed on the machine - or the user must build them and make them available   ***
***       There is a script in the bmad-ecosystem called buildBmadExternalLinux.csh        ***
***       (or use buildBmadExternalMac.zsh on a Mac).  Running this script will build the  ***
***       necessary libraries that the bmad-ecosystem will need.                           ***
***       The CMAKE_INSTALL_PREFIX is very important and informs cmake of the location for ***
***       the install of the libraries.  This location will also be used to inform the     ***
***       bmad-ecosystem, during its build, of the location of the external libraries.     ***
**********************************************************************************************

Recommended:

Linux

Copy the two scripts from https://github.com/JSL1GH/bmad-ecosystem/tree/updated_bmad
   (bmad-ecosystem/updated_bmad branch)

   Linux
     a. buildBmadExternalLinux.csh
     b. buildBmadEcosystemLinux.csh

     The scripts make assumptions about the installation area and program "options".
     See below for customizations in the building of the bmad-ecosystem
  
   Mac
     a  buildBmadExternalMac.zsh
     b. buildBmadEcosystemMac.zsh

Essentially, the script clones the gitrepo and builds the "standard" version of the bmad-ecosystem

The default values for the build - used in the script:
- internal libraries (where this build will place its files - bin/lib/modules/source)
- external libraries (location where the external packages have been built and will be found - otherwise they must be present on the system)
- prefix path (location of find_package and configuration files used by cmake
cmake .. -DCMAKE_INSTALL_PREFIX:PATH=${HOME}/bmadTryInternal.${ROLLOUT} -DBMAD_EXTERNAL=${HOME}/bmadTryExternal.${ROLLOUT} -DCMAKE_PREFIX_PATH=${HOME}/bmadTryExternal.${ROLLOUT}



Alternatively, to build step-by-step:

After downloading the bmad-ecosystem, enter the bmad-ecosystem directory (cd ./bmad-ecosystem)
Create a build directory and enter the build directory (mkdir build; cd build)
Build the bmad-ecosystem (cmake -DCMAKE_INSTALL_PREFIX:PATH=/path/to/install/of/bmad ..)
Make the installation (make)
Install the installation (make install)

The result of this will be a fully compiled bmad library.

The build will place:
    executable files in .../bmad-ecosystem/build/bin
    lib files in .../bmad-ecosystem/build/lib
    header files in .../bmad-ecosystem/build/include
    mod files in .../bmad-ecosystem/build/modules

Note:
1) cmake caches switch values between successive runs of cmake - this is very confusing!
   If there are ever questions about a build, one should clear the cache
   rm -rf CMakeFiles; rm CMakeCache.txt

2) default is to build shared libraries

The default, the build assumes that bmad system libraries are available - that is typically
not the case unless the external bmad repository has been built.

By default, the external bmad repository is placed in ${HOME}/bmad/external
Therefore, the BMAD_EXTERNAL argument default value is ${HOME}/bmad/external

_________________________________________________________________________________________________

BMAD-ECOSYSTEM (bmad-ecosystem) - OPTIONS - (options provided as switches should be
prefaced with a -D)

e.g. CMAKE_INSTALL_PREFIX ----> -DCMAKE_INSTALL_PREFIX=/install/prefix/path

1. CMAKE_INSTALL_PREFIX: indicates where the bmad_ecosystem package should be installed.
                default: ${HOME}/bmad/internal



(Note: if a value is set - or cached - the build will fail if the area already exists
  - so as not to accidentally overwrite a previous installation - the CUSER_FORCE variable
  can be used to reinstall over the initial area)

# - Specify where the bmad external library has been built (default: $ENV{HOME}/bmad/external)
-DBMAD_EXTERNAL=/path/to/bmad/external/build ()

# - Specify location where bmad files should be placed, after building, during install
   (default:CMAKE_INSTALL_PREFIX=$ENV{HOME}/bmad/internal)
-DCMAKE_INSTALL_PREFIX=$ENV{HOME}/bmad/internal

# - Specify location where find_package files can be located in external_prefix
-DCMAKE_PREFIX_PREFIX=$ENV{HOME}/bmad/external

# - Specify if would like static build of libraries (which will get linked into the executable)
   (default:BUILD_SHARED_LIBS=ON)
-DBUILD_SHARED_LIBS=OFF

# - Specify if building Bmad with conda (default:CONDA_BUILD=OFF)- If set to ON, user MUST supply a CONDA_PATH
-DCONDA_BUILD=ON

# - Specify location of conda related files (User MUST also specify CONDA_BUILD=ON)
-DCONDA_PATH=/path/to/conda/library/items

# - Specify if building Bmad with openmp (default:ENABLE_OPENMP=OFF)
-DENABLE_OPENMP=ON

# - Specify if building Bmad with openmp (default:ENABLE_MPI=OFF)
-DENABLE_MPI=ON

# - Plot type for which bmad should be built (default:PLOT_TYPE=PLPLOT - options PLPLOT,NOPLOT,PGPLOT)
-DPLOT_TYPE=PLPLOT

# - include some test executables that are not necessary for standard build/install
-DBUILD_TEST=ON

# - indicate if the executables should include (that is, if we build-in the shared object
# library path for runtime executables) the path to the external libraries
# - if this is not supplied (or is set to OFF), the user must supply the runtime path,
# through 'sourcing' a supplied script, prior to launching the executable
-DBMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH=ON

# - exclude some libraries from being built by default - default is to build all libraries in bmad toolkit
# possible, as of 1/1/26, forest sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux regression_tests
# use -DBUILD_... - where ... is the library/directory - in CAPS!
# for example, -DBUILD_FOREST=OFF 

_________________________________________________________________________________________________


Debug help:
Some additional cmake build information can be obtained by building with a debug switch (--log-level=DEBUG)

Some additional build information can be found by using the --verbose switch (--verbose)


One can determine the variables used in the build of the ecosystem by issuing the build command and
appending '-LH' (see below)



FYI:
IF want to build a single subdirectory (and it's dependencies)

1.

  cmake -S . -B build   # once

2.

  cmake --build build --target cpp_bmad_interface

or

  cd build
  make cpp_bmad_interface



# Here is an example of preparing the build by executing the cmake command with -LH
(Note in this case, the BMAD_EXTERNAL and CMAKE_PREFIX_PATH are not pointing to an already built external package,
therefore, it is not surprising to receive the message regarding LAPACK not found!)

cmake .. -DCMAKE_INSTALL_PREFIX:PATH=${HOME}/bmadTryInternal.${ROLLOUT} -DBMAD_EXTERNAL=${HOME}/bmadTryExternal.${ROLLOUT} -DCMAKE_PREFIX_PATH=${HOME}/bmadTryExternal.${ROLLOUT} -LH
-- The C compiler identification is GNU 8.4.1
-- The CXX compiler identification is GNU 8.4.1
-- The Fortran compiler identification is GNU 8.4.1
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /usr/bin/gcc - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Check for working CXX compiler: /usr/bin/g++ - skipped
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Detecting Fortran compiler ABI info
-- Detecting Fortran compiler ABI info - done
-- Check for working Fortran compiler: /usr/bin/gfortran - skipped
-- Checking whether /usr/bin/gfortran supports Fortran 90
-- Checking whether /usr/bin/gfortran supports Fortran 90 - yes
-- Using PACKAGE_MANAGER='linux'.
-- CMAKE_INSTALL_PREFIX was explicitly set by the user - /home/cfsd/laster/bmadTryInternal.32
-- User has set a value of /home/cfsd/laster/bmadTryInternal.32
-- Current CMAKE_INSTALL_PREFIX: /home/cfsd/laster/bmadTryInternal.32
-- Found PkgConfig: /usr/bin/pkg-config (found version "1.4.2") 
-- COMMENTED OUT THE LINE THAT GETS ALL OF OUR EXTERNAL LIBRARIES - FOR NOW!
-- PLOT_TYPE is set to PLPLOT
-- ********************************************

-- Will build the following libraries (and associated executables within):
-- 	forest
-- 	sim_utils
-- 	bmad
-- 	tao
-- 	cpp_bmad_interface
-- 	code_examples
-- 	bsim
-- 	util_programs
-- 	lux
-- 	regression_tests
CMake Error at CMakeLists.txt:445 (find_package):
  Could not find a package configuration file provided by "LAPACK" with any
  of the following names:

    LAPACKConfig.cmake
    lapack-config.cmake

  Add the installation prefix of "LAPACK" to CMAKE_PREFIX_PATH or set
  "LAPACK_DIR" to a directory containing one of the above files.  If "LAPACK"
  provides a separate development package or SDK, be sure it has been
  installed.


-- Configuring incomplete, errors occurred!
See also "/home/cfsd/laster/Projects/attempt.32/bmadEcosystem.32/bmad-ecosystem/build/CMakeFiles/CMakeOutput.log".
-- Cache values
// Embed BMAD_EXTERNAL/lib in installed executables' RPATH (makes runtime 'just work' but less relocatable)
BMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH:BOOL=OFF

// Path to the bmad external directory
BMAD_EXTERNAL:PATH=/home/cfsd/laster/bmadTryExternal.32

// BUILD_BMAD - Build bmad
BUILD_BMAD:BOOL=ON

// BUILD_BSIM - Build bsim
BUILD_BSIM:BOOL=ON

// BUILD_CODE_EXAMPLES - Build code_examples
BUILD_CODE_EXAMPLES:BOOL=ON

// BUILD_CPP_BMAD_INTERFACE - Build cpp_bmad_interface
BUILD_CPP_BMAD_INTERFACE:BOOL=ON

// BUILD_FOREST - Build forest
BUILD_FOREST:BOOL=ON

// BUILD_LUX - Build lux
BUILD_LUX:BOOL=ON

// BUILD_REGRESSION_TESTS - Build regression_tests
BUILD_REGRESSION_TESTS:BOOL=ON

// Specify if do not want shared object libraries (prefer static '.a') '-DBUILD_SHARED_LIBS=OFF'
BUILD_SHARED_LIBS:BOOL=ON

// BUILD_SIM_UTILS - Build sim_utils
BUILD_SIM_UTILS:BOOL=ON

// BUILD_TAO - Build tao
BUILD_TAO:BOOL=ON

// Specify if building Bmad with various test executables '-DBUILD_TEST=ON'
BUILD_TEST:BOOL=OFF

// BUILD_UTIL_PROGRAMS - Build util_programs
BUILD_UTIL_PROGRAMS:BOOL=ON

// Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel ...
CMAKE_BUILD_TYPE:STRING=

// No help, variable specified on the command line.
CMAKE_INSTALL_PREFIX:PATH=/home/cfsd/laster/bmadTryInternal.32

// Specify if building Bmad with conda '-DCONDA_BUILD=ON'
CONDA_BUILD:BOOL=OFF

// Specify if building Bmad with mpi '-DENABLE_MPI=ON'
ENABLE_MPI:BOOL=OFF

// Specify if building Bmad with openmp '-DENABLE_OPENMP=ON'
ENABLE_OPENMP:BOOL=OFF

// The directory containing a CMake configuration file for LAPACK.
LAPACK_DIR:PATH=LAPACK_DIR-NOTFOUND

// Choose the option (PLPLOT, NOPLOT, PGPLOT)
PLOT_TYPE:STRING=PLPLOT
