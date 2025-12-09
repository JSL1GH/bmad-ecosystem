This file describes the various options available for building the bad-ecosystem.

Recommended:

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

The default build assumes that bmad system libraries are available - that is typically not the case unless the external bmad repository has been built
By default, the external bmad repository is placed in ${HOME}/bmad/external
Therefore, the BMAD_EXTERNAL argument default value is ${HOME}/bmad/external


Additional options:

# - Specify where the bmad external library has been built (default: $ENV{HOME}/bmad/external)
-DBMAD_EXTERNAL=/path/to/bmad/external/build ()

# - Specify if would like static build of libraries (which will get linked into the executable) (default:BUILD_SHARED_LIBS=ON)
-DBUILD_SHARED_LIBS=OFF

# - Specify if building Bmad with conda (default:CONDA_BUILD=OFF)- If set to ON, user MUST supply a CONDA_PATH
-DCONDA_BUILD=ON

# - Specify location of conda related files (User MUST also specify CONDA_BUILD=ON)
CONDA_PATH=/path/to/conda/library/items

# - Specify if building Bmad with openmp (default:ENABLE_OPENMP=OFF)
-DENABLE_OPENMP=ON

# - Specify if building Bmad with openmp (default:ENABLE_MPI=OFF)
-DENABLE_MPI=ON

# - Specify location where bmad files should be placed, after building, during install (default:CMAKE_INSTALL_PREFIX=$ENV{HOME}/bmad/internal)
-DCMAKE_INSTALL_PREFIX=$ENV{HOME}/bmad/internal

# - Plot type for which bmad should be built (default:PLOT_TYPE=PLPLOT - options PLPLOT,NOPLOT,PGPLOT)
-DPLOT_TYPE=PLPLOT

# - include some test executables that are not necessary for standard build/install
-DBUILD_TEST=ON

# - exclude some libraries from being build by default - default is to build all libraries in bmad toolkit
# possible, as of 1/1/26, forest sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux regression_tests
# use -DBUILD_... - where ... is the library/directory - in CAPS!
# for example, -DBUILD_FOREST=OFF 

Debug help:
Some additional cmake build information can be obtained by building with a debug switch (--log-level=DEBUG)

Some additional build information can be found by using the --verbose switch (--verbose)


#cmake -DDEFAULT_BMAD_EXTERNAL=ON -DCESR_PLPLOT=ON -DCUSER_FORCE=true -DCMAKE_INSTALL_PREFIX:PATH=/home/cfsd/laster/bmad/internal -LH ..
