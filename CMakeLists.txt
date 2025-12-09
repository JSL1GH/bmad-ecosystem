cmake_minimum_required(VERSION 3.18)

project(ACC LANGUAGES CXX Fortran)

#determine the place from which cmake is being invoked
if(NOT DEFINED BASEDIR)
    message(DEBUG "BASEDIR NOT DEFINED")
    if(DEFINED ENV{BASEDIR})
        set(BASEDIR $ENV{BASEDIR})
        message(DEBUG "set BASEDIR to $ENV{BASEDIR}")
    else()
        set(BASEDIR ${CMAKE_SOURCE_DIR})
        message(DEBUG "Value of BASEDIR was not set - it's value has been set to ${CMAKE_SOURCE_DIR}")
    endif()
else()
    message(DEBUG "BASEDIR has a value of ${BASEDIR}")
endif()

message(DEBUG "VALUE of build directory is ${CMAKE_BINARY_DIR}")

#define all of the global variables used throughout the build
#note that these can be saved in a different file and included

#for d in hdf5 fftw lapack lapack95 gsl fgsl forest xraylib sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux regression_tests
set(DIRLIST forest sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux regression_tests)

option(BUILD_SHARED_LIBS "Specify if do not want shared object libraries (prefer static '.a') '-DBUILD_SHARED_LIBS=OFF'" ON)
if(NOT DEFINED BUILD_SHARED_LIBS)
    set(BUILD_SHARED_LIBS ON)
else()
    set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS})
endif()

option(CONDA_BUILD "Specify if building Bmad with conda '-DCONDA_BUILD=ON'" OFF)
if(NOT DEFINED CONDA_BUILD)
    set(CONDA_BUILD OFF CACHE BOOL "Specify if building Bmad with conda '-DCONDA_BUILD=ON'" FORCE)
else()
    # Ensure it is in the cache using the command-line supplied value
    set(CONDA_BUILD "${CONDA_BUILD}" CACHE BOOL "Specify if building Bmad with conda '-DCONDA_BUILD=ON'" FORCE)
endif()

if("${CONDA_BUILD}" STREQUAL "ON")
    if(NOT DEFINED ${CONDA_PATH})
        message(FATAL_ERROR "CONDA_PATH must be specified if CONDA_BUILD is set to ON")
    endif()
    set(CONDA_BUILD_PATH ${CONDA_PATH})
endif()

option(ENABLE_OPENMP "Specify if building Bmad with openmp '-DENABLE_OPENMP=ON'" OFF)
if(NOT DEFINED ENABLE_OPENMP)
    set(ENABLE_OPENMP OFF CACHE BOOL "Specify if building Bmad with openmp '-DENABLE_OPENMP=ON'" FORCE)
else()
    # Ensure it is in the cache using the command-line supplied value
    set(ENABLE_OPENMP "${ENABLE_OPENMP}" CACHE BOOL "Specify if building Bmad with openmp '-DENABLE_OPENMP=ON'" FORCE)
endif()

option(ENABLE_MPI "Specify if building Bmad with mpi '-DENABLE_MPI=ON'" OFF)
if(NOT DEFINED ENABLE_MPI)
    set(ENABLE_MPI OFF CACHE BOOL "Specify if building Bmad with mpi '-DENABLE_MPI=ON'" FORCE)
else()
    # Ensure it is in the cache using the command-line supplied value
    set(ENABLE_MPI "${ENABLE_MPI}" CACHE BOOL "Specify if building Bmad with mpi '-DENABLE_MPI=ON'" FORCE)
endif()


# this is where our created files will go - by default - with respect to where we make the current build
# did user specify a CMAKE_INSTALL_PREFIX (either on the command line or was already cached (which I hate!) ?
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    message(STATUS "CMAKE_INSTALL_PREFIX was not set - using its default value - ${CMAKE_INSTALL_PREFIX}")
else()
    message(STATUS "CMAKE_INSTALL_PREFIX was explicitly set by the user - ${CMAKE_INSTALL_PREFIX}")
endif()

#if end with a value other than /usr/local, we just go with it (may have come from command-line or cache
#but if is /usr/local, we abort - I cannot imagine why we would ever want bmad installed there
#Question - do we want something like the bmad-external build (we place in $ENV{HOME}/bmad/external)
#e.g. Bmad-ecosystem goes into $ENV{HOME/bmad/internal by default?
#or do we abort and tell the user we need a value!

if(EXISTS "${CMAKE_INSTALL_PREFIX}")
   
    # IF VALUE IS /usr/local, it means user did not supply a value - CMAKE DEFAULTS TO /usr/local!
    # therefore, we continue as if user supplied a value of $ENV{HOME}/bmad/external
    if(${CMAKE_INSTALL_PREFIX} STREQUAL "/usr/local")
        message(STATUS "User did not set a value (or set a value of '/usr/local)' for CMAKE_INSTALL_PREFIX - defaulting to $ENV{HOME}/bmad/internal")
        set(CMAKE_INSTALL_PREFIX $ENV{HOME}/bmad/internal)

        # now check again to see if the new value we just set - exists
        if(EXISTS "${CMAKE_INSTALL_PREFIX}")
            # did user supply force 
	    if(CUSER_FORCE)
	        #      message (STATUS "Directory path '${CMAKE_INSTALL_PREFIX}' already exists - user supplied force option! ('-force')")
	        message(DEBUG "Directory path '${CMAKE_INSTALL_PREFIX}' already exists - user supplied force option! ('-force') - continuing and building into it")
                option(CMAKE_INSTALL_PREFIX "Specify where Bmad should be installed when run with 'make install' - '-DCMAKE_INSTALL_PREFIX=/full_path/to_my_install_directory'" ${CMAKE_INSTALL_PREFIX})

	    else()
                message (FATAL_ERROR "Directory path '${CMAKE_INSTALL_PREFIX}' already exists - please modify or supply a build flag to override - in order continue installation ('-DCUSER_FORCE=true)...cancel'")
            endif()
        endif()
    else()
        message(STATUS "User has set a value of ${CMAKE_INSTALL_PREFIX}")
    endif()
else()  
    message(STATUS "No value given for CMAKE_INSTALL_PREFIX - defaulting to $ENV{HOME}/bmad/internal")
    set(CMAKE_INSTALL_PREFIX $ENV{HOME}/bmad/internal)
endif()

message(STATUS "Current CMAKE_INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")

set(CMAKE_FORTRAN_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

message(DEBUG "Value of CMAKE_FORTRAN_MODULE_DIRECTORY is ${CMAKE_BINARY_DIR}/modules}")

set(BMAD_EXTERNAL "$ENV{HOME}/bmad/external" CACHE PATH "Path to the bmad external directory")
if(DEFINED BMAD_EXTERNAL)
    #but user may have cleared the value - let's check against it - just to give a big warning message
    if ("${BMAD_EXTERNAL}" STREQUAL "")
        message(STATUS "WARNING: NO VALUE PROVIDED FOR BMAD_EXTERNAL - YOU WILL LIKELY ENCOUNTER A BUILD PROBLEM")
    else()
#        message(DEBUG "Expecting to find bmad external packages at: ${BMAD_EXTERNAL}")
    endif()
else()
#    not possible, as we have supplied a value
    message(DEBUG "BMAD_EXTERNAL DOES NOT EXIST AT THIS POINT")
endif()

#do we want to use CMAKE_LIBRARY_PATH instead of all this?
if(DEFINED BMAD_EXTERNAL)
    foreach (LIB 
        libfgsl.so libgsl.so libgslcblas.so liblapack95.so liblapack.so libfftw3.so
        libhdf5_hl_fortran.so libhdf5_hl_f90cstub.so libhdf5_fortran.so libblas.so
        libxrlf03.so libxrl.so libplplotfortran.so libplplot.so libcsirocsa.so
        )
        LIST(APPEND LIST_OF_EXTERNAL_LIBRARIES ${BMAD_EXTERNAL}/lib/${LIB})
    endforeach()
    set(LIST_OF_EXTERNAL_LIBRARY_INCLUDES ${BMAD_EXTERNAL}/include)
    message(DEBUG "List of external libraries is ${LIST_OF_EXTERNAL_LIBRARIES}")
    message(DEBUG "Path of external library includes is ${LIST_OF_EXTERNAL_LIBRARY_INCLUDES}")

    include_directories(${LIST_OF_EXTERNAL_LIBRARY_INCLUDES})
else()
    message(STATUS "No external paths for bmad have been defined - hope the system has them!")
endif()

# Define the option (this will set the variable from the command line if provided) - our default is PLPLOT!
set(PLOT_TYPE "PLPLOT" CACHE STRING "Choose the option (PLPLOT, NOPLOT, PGPLOT)")

# Define valid values
list(APPEND valid_values "PLPLOT" "NOPLOT" "PGPLOT")

# Optional: Ensure that the value is one of the valid choices
if(NOT PLOT_TYPE IN_LIST valid_values)
    message(FATAL_ERROR "Invalid value for PLOT_TYPE! Please choose one of: PLPLOT, NOPLOT, PGPLOT")
endif()

# Output the chosen value
message(STATUS "PLOT_TYPE is set to ${PLOT_TYPE}")


#Fortran flags needed for building of .f90 files
set(CMAKE_Fortran_FLAGS  "-DCESR_${PLOT_TYPE}=ON -dM -dI -cpp ${CMAKE_Fortran_FLAGS} -fdollar-ok -Wall -Wextra -ffree-line-length-none -Wunused-variable")

set(ONE_EXCLUDED 0)
set(BUILD_LIST)

# THIS SHOULD BE OPTIONS
option(BUILD_TEST "Specify if building Bmad with various test executables '-DBUILD_TEST=ON'" OFF)
if(NOT DEFINED BUILD_TEST)
    set(BUILD_TEST OFF CACHE BOOL "Specify if building Bmad with various test executables '-DBUILD_TEST=ON'" FORCE)
else()
    # Ensure it is in the cache using the command-line supplied value
    set(BUILD_TEST "${BUILD_TEST}" CACHE BOOL "Specify if building Bmad with various test executables '-DBUILD_TEST=ON'" FORCE)
endif()

message(STATUS "********************************************\n")
foreach(DIR ${DIRLIST})

    string(TOLOWER "${DIR}" lower)
    string(TOUPPER "${DIR}" upper)
    option(BUILD_${upper} "BUILD_${upper} - Build ${lower}" ON)

    if(BUILD_${upper})
	LIST(APPEND BUILD_LIST ${lower})
    else()
        message("****  Option 'BUILD_${upper}' supplied - User has elected NOT to build ${lower}  ****")
        set(ONE_EXCLUDED 1)
    endif()

endforeach()


if(${ONE_EXCLUDED})
    message(STATUS "")
endif()

message(STATUS "Will build the following libraries (and associated executables within):")
#message("BUILD_LIST IS ${BUILD_LIST}")
foreach (LIB ${BUILD_LIST})
    message(STATUS "\t${LIB}")
endforeach()

if(${ONE_EXCLUDED})
    message(STATUS "****  Note that excluding the building of some libraries may cause dependencies to not be available and the build may fail!  ****")
endif()

#now we do the build

foreach(DIR ${BUILD_LIST})
    message(STATUS "*********************************")
    message(STATUS "---- BUILDING - ${DIR} ----")
    message(STATUS "*********************************\n")
    add_subdirectory(${DIR})
    message(STATUS "---- END BUILD - ${DIR} ----")
    message(STATUS "*********************************\n")

endforeach()


message("This concludes the build of the bmad package\n")

message(STATUS "********************************************")

