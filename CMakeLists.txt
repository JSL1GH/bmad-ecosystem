cmake_minimum_required(VERSION 3.18)

#We are placing our build in bmadTryInternal    (CMAKE_INSTALL_PREFIX)
#We are dependent on the bmadTryExternal build  (BMAD_EXTERNAL CMAKE_PREFIX_PATH)
#cmake .. -DCMAKE_INSTALL_PREFIX:PATH=/home/cfsd/laster/bmadTryInternal -DBMAD_EXTERNAL=/home/cfsd/laster/bmadTryExternal -DCMAKE_PREFIX_PATH=/home/cfsd/laster/bmadTryExternal

#project(BMAD_ECOSYSTEM LANGUAGES CXX Fortran)
project(BMAD_ECOSYSTEM VERSION 1.0.0 LANGUAGES C CXX Fortran)

# special consideration if on APPLE - to determine if we are using HOMEBREW or MacPorts
if (APPLE)
# ---- Detect availability (simple heuristics; tweak if you want stricter checks) ----
find_program(BREW_EXECUTABLE brew)
find_program(PORT_EXECUTABLE port)

set(pm_available "")
if(BREW_EXECUTABLE)
  message(STATUS "BREW IS AVAILABLE")
  list(APPEND pm_available homebrew)
endif()
if(PORT_EXECUTABLE)
  message(STATUS "MacPorts IS AVAILABLE")
  list(APPEND pm_available macports)
endif()

if(pm_available STREQUAL "")
  message(FATAL_ERROR "No supported package manager found (need Homebrew 'brew' or MacPorts 'port').")
endif()

# ---- Read user request (honor -D if present) but keep our working var non-cached ----
set(_pm_user_provided FALSE)

if(DEFINED CACHE{PACKAGE_MANAGER})
#  set(PACKAGE_MANAGER "${CACHE{PACKAGE_MANAGER}}")
  set(PACKAGE_MANAGER "${PACKAGE_MANAGER}")
  set(_pm_user_provided TRUE)
elseif(DEFINED PACKAGE_MANAGER) # e.g. set by parent scope/toolchain
  set(_pm_user_provided TRUE)
endif()

# ---- Defaulting logic ----
if(NOT _pm_user_provided OR "${PACKAGE_MANAGER}" STREQUAL "")
  # Default to macports if available, else first available
  if("macports" IN_LIST pm_available)
    set(PACKAGE_MANAGER "macports")
    message(STATUS "PACKAGE_MANAGER not set; defaulting to 'macports'.")
  else()
    list(GET pm_available 0 PACKAGE_MANAGER)
    message(STATUS "PACKAGE_MANAGER not set; defaulting to '${PACKAGE_MANAGER}' (only available option).")
  endif()
else()
  # ---- Validate request ----
  set(pm_valid_values macports homebrew)
  if(NOT "${PACKAGE_MANAGER}" IN_LIST pm_valid_values)
    message(FATAL_ERROR
      "Invalid PACKAGE_MANAGER='${PACKAGE_MANAGER}'. Choose: macports or homebrew."
    )
  endif()
  message(STATUS "Values are ${PACKAGE_MANAGER} and ${pm_available}")
  if(NOT "${PACKAGE_MANAGER}" IN_LIST pm_available)
    message(FATAL_ERROR
      "Requested PACKAGE_MANAGER='${PACKAGE_MANAGER}' but it is not available on this system. "
      "Available: ${pm_available}"
    )
  endif()

  message(STATUS "Honoring PACKAGE_MANAGER='${PACKAGE_MANAGER}'.")
endif()

else()
  set(PACKAGE_MANAGER "linux")
  message(STATUS "Using PACKAGE_MANAGER='${PACKAGE_MANAGER}'.")
endif()

list(PREPEND CMAKE_MODULE_PATH
     "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

list(PREPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

#include(GNUInstallDirs)

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
#set(DIRLIST forest sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux regression_tests)
#set(DIRLIST forest )#sim_utils) #sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux regression_tests)
set(DIRLIST forest sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux)
#set(DIRLIST forest sim_utils bmad tao cpp_bmad_interface code_examples bsim util_programs lux)# bsim util_programs lux regression_tests)

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

if(DEFINED CMAKE_INSTALL_PREFIX)
   
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
#        message(DEBUG "Expecting to find bmad external packages at: $gBMAD_EXTERNAL}")
    endif()
else()
#    not possible, as we have supplied a value
    message(DEBUG "BMAD_EXTERNAL DOES NOT EXIST AT THIS POINT")
endif()

set(LIB_POSTFIX ".so")
if (APPLE)
    set(LIB_POSTFIX ".dylib")
endif()

# some more special APPLE things - have to tell it where to find our "installed" dylibs - or at least hint!
# macOS: make installed executables find installed dylibs in <prefix>/lib
#if(APPLE)
#  set(CMAKE_MACOSX_RPATH ON)
#  set(CMAKE_INSTALL_RPATH "@loader_path/../lib")
#  set(CMAKE_BUILD_WITH_INSTALL_RPATH OFF)
#endif()

# use our GSL first (external_stack - if it's found, we go with it)
find_package(GSL QUIET)
if (NOT GSL_FOUND)
# see if we can find one on the system
    find_package(GSL QUIET CONFIG)
endif()
if (NOT GSL_FOUND)
# make our own version of gsl and provide a target for it
    message(STATUS "GSL not found via config or find_package - creating imported target")
    add_library(GSL::gsl SHARED IMPORTED)

    set_target_properties(GSL::gsl PROPERTIES
        IMPORTED_LOCATION
            "${BMAD_EXTERNAL}/lib/libgsl${CMAKE_SHARED_LIBRARY_SUFFIX}"
        INTERFACE_INCLUDE_DIRECTORIES
            "${BMAD_EXTERNAL}/include"
    )
endif()



#do we want to use CMAKE_LIBRARY_PATH instead of all this?
if(DEFINED BMAD_EXTERNAL)
    foreach (LIB 
        fgsl gsl gslcblas lapack95 lapack fftw3
        hdf5_hl_fortran hdf5_hl_f90cstub hdf5_fortran blas
        xrlf03 xrl plplotfortran plplot csirocsa
        )
#        message(STATUS "Adding  ${BMAD_EXTERNAL}/lib/lib${LIB}${LIB_POSTFIX}")
        LIST(APPEND LIST_OF_EXTERNAL_LIBRARIES ${BMAD_EXTERNAL}/lib/lib${LIB}${LIB_POSTFIX})
    endforeach()
    set(LIST_OF_EXTERNAL_LIBRARY_INCLUDES ${BMAD_EXTERNAL}/include)
    message(DEBUG "List of external libraries is ${LIST_OF_EXTERNAL_LIBRARIES}")
    message(DEBUG "Path of external library includes is ${LIST_OF_EXTERNAL_LIBRARY_INCLUDES}")
message(STATUS "COMMENTED OUT THE LINE THAT GETS ALL OF OUR EXTERNAL LIBRARIES - FOR NOW!")
#JSL    include_directories(${LIST_OF_EXTERNAL_LIBRARY_INCLUDES})
else()
    message(STATUS "No external paths for bmad have been defined - hope the system has them!")
endif()

#PROTECTION - if use incorrect build string
if(CMAKE_INSTALL_PREFIX STREQUAL BMAD_EXTERNAL)
  message(FATAL_ERROR
    "BMAD_ECOSYSTEM install prefix must NOT be the same as BMAD_EXTERNAL")
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

# Linux/Mac specific testing - for 'readline'
include(CheckFunctionExists)

# Make sure we find Homebrew's readline if available
if(APPLE)
    # Optional: automatically locate Brew's readline
    execute_process(
        COMMAND brew --prefix readline
        OUTPUT_VARIABLE BREW_READLINE_PREFIX
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(BREW_READLINE_PREFIX)
        message(STATUS "Using Homebrew readline: ${BREW_READLINE_PREFIX}")
        include_directories(${BREW_READLINE_PREFIX}/include)
        link_directories(${BREW_READLINE_PREFIX}/lib)
    endif()


endif()

# Check if append_history exists in readline/history.h
#JSL - set(CMAKE_REQUIRED_LIBRARIES readline)

# JSL - check_function_exists(append_history HAVE_APPEND_HISTORY)
#JSL
#if(HAVE_APPEND_HISTORY)
#    message(STATUS "append_history() found")
#else()
#    message(STATUS "append_history() NOT found — using fallback behavior")
#endif()

if(APPLE)
    set(CMAKE_C_FLAGS "-I/opt/X11/include")
    set(CMAKE_EXE_LINKER_FLAGS "-L/opt/X11/lib")
    find_package(X11 REQUIRED)

    message(STATUS "ARE OVER HERE")

#    find_package(X11 REQUIRED)
#    target_include_directories(your_target PRIVATE ${X11_INCLUDE_DIR})
#    target_link_libraries(your_target PRIVATE ${X11_LIBRARIES})

endif()


# Make the result available to your source
#JSL - add_definitions(-DHAVE_APPEND_HISTORY=${HAVE_APPEND_HISTORY})


include(GNUInstallDirs)


configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/bmad-ecosystem-env.sh.in"
  "${CMAKE_BINARY_DIR}/bmad-ecosystem-env.sh"
  @ONLY
)

install(PROGRAMS
  "${CMAKE_BINARY_DIR}/bmad-ecosystem-env.sh"
  DESTINATION ${CMAKE_INSTALL_BINDIR}
)

################
# for setting if user is binding in RPATH or using a cmake runtime environment file

option(BMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH
  "Embed BMAD_EXTERNAL/lib in installed executables' RPATH (makes runtime 'just work' but less relocatable)"
  OFF
)

################
# for setting if user is binding in RPATH or using a cmake runtime environment file

# Internal libdir of this install (e.g. <prefix>/lib)
set(_BMAD_INTERNAL_LIBDIR "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")

if(APPLE)
  set(CMAKE_MACOSX_RPATH ON)

  # Always allow installed executables to find BMAD_ECOSYSTEM libs in <prefix>/lib
  # Executable is in <prefix>/bin, so this resolves to <prefix>/lib
  set(_BMAD_INSTALL_RPATH "@loader_path/../${CMAKE_INSTALL_LIBDIR}")

  # Optional: also embed BMAD_EXTERNAL/lib
#  if(BMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH AND DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
#    list(APPEND _BMAD_INSTALL_RPATH "${BMAD_EXTERNAL}/lib")
#  endif()
if(BMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH AND DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  if(EXISTS "${BMAD_EXTERNAL}/${CMAKE_INSTALL_LIBDIR}")
    list(APPEND _BMAD_INSTALL_RPATH "${BMAD_EXTERNAL}/${CMAKE_INSTALL_LIBDIR}")
  elseif(EXISTS "${BMAD_EXTERNAL}/lib")
    list(APPEND _BMAD_INSTALL_RPATH "${BMAD_EXTERNAL}/lib")
  elseif(EXISTS "${BMAD_EXTERNAL}/lib64")
    list(APPEND _BMAD_INSTALL_RPATH "${BMAD_EXTERNAL}/lib64")
  endif()
endif()

  # Apply globally to install tree
  set(CMAKE_INSTALL_RPATH "${_BMAD_INSTALL_RPATH}")
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

else() # Linux and others
  # Installed executables should find <prefix>/lib
  set(_BMAD_INSTALL_RPATH "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")

  if(BMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH AND DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
    list(APPEND _BMAD_INSTALL_RPATH "${BMAD_EXTERNAL}/lib")
  endif()

  set(CMAKE_INSTALL_RPATH "${_BMAD_INSTALL_RPATH}")
  set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
endif()
################

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

# one last piece of bookkeeping because of how we need to handle LAPACK and BLAS
# --- LAPACK/BLAS (external prefix provides a CONFIG but no targets) ---
find_package(LAPACK CONFIG REQUIRED)

if(NOT TARGET BLAS::BLAS)
  add_library(BLAS::BLAS INTERFACE IMPORTED)
  target_link_libraries(BLAS::BLAS INTERFACE ${LAPACK_blas_LIBRARIES})
endif()

if(NOT TARGET LAPACK::LAPACK)
  add_library(LAPACK::LAPACK INTERFACE IMPORTED)
  target_link_libraries(LAPACK::LAPACK INTERFACE ${LAPACK_lapack_LIBRARIES} BLAS::BLAS)
endif()


#now we do the build

foreach(DIR ${BUILD_LIST})
    message(STATUS "*********************************")
    message(STATUS "---- BUILDING - ${DIR} ----")
    message(STATUS "*********************************\n")
    add_subdirectory(${DIR})

if(APPLE)
    set(CMAKE_C_FLAGS "-I/opt/X11/include")
    set(CMAKE_EXE_LINKER_FLAGS "-L/opt/X11/lib")
    message(STATUS "ARE OVER HERE1")

#    target_include_directories(${DIR} PRIVATE ${X11_INCLUDE_DIR})
#   target_link_libraries(${DIR} PRIVATE ${X11_LIBRARIES})
endif()

    message(STATUS "---- END BUILD - ${DIR} ----")
    message(STATUS "*********************************\n")

endforeach()

message("This concludes the build of the bmad package\n")
#message("This concludes the build of the bmad package - ${CMAKE_INSTALL_LIBDIR}\n")

set(BMAD_ECOSYSTEM_INSTALL_CMAKEDIR
#    "${CMAKE_INSTALL_PREFIX}/cmake/BMAD_ECOSYSTEM"
    "${CMAKE_INSTALL_PREFIX}/lib/cmake/BMAD_ECOSYSTEM"
)

message("INSTALL_DIR WILL BE ${BMAD_ECOSYSTEM_INSTALL_CMAKEDIR}")

#include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/BMAD_ECOSYSTEMConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/BMAD_ECOSYSTEMConfig.cmake"
    INSTALL_DESTINATION "${BMAD_ECOSYSTEM_INSTALL_CMAKEDIR}"
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/BMAD_ECOSYSTEMConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/BMAD_ECOSYSTEMConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/BMAD_ECOSYSTEMConfigVersion.cmake"
    DESTINATION "${BMAD_ECOSYSTEM_INSTALL_CMAKEDIR}"
)

install(EXPORT BMAD_ECOSYSTEMTargets
    FILE BMAD_ECOSYSTEMTargets.cmake
    NAMESPACE BMAD_ECOSYSTEM::
    DESTINATION "${BMAD_ECOSYSTEM_INSTALL_CMAKEDIR}"
)

#install(FILES
#    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/FindFGSL.cmake"
#    DESTINATION "${BMAD_ECOSYSTEM_INSTALL_CMAKEDIR}/modules"
#)

#just use a global Find*.cmake command
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/cmake/"
  DESTINATION "${BMAD_ECOSYSTEM_INSTALL_CMAKEDIR}/modules"
  FILES_MATCHING PATTERN "Find*.cmake"
)

message(STATUS "********************************************")


#GUILLAUME - HSR modeling tools, database, transition
#



#[[

Mode 1 — embed external rpath (no activation required)

cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX=/.../bmadTryInternal \
  -DBMAD_EXTERNAL=/.../bmadTryExternal \
  -DBMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH=ON
cmake --build build
cmake --install build

_____

Mode 2 — don’t embed external rpath (activation script)

cmake -S . -B build \
  -DCMAKE_INSTALL_PREFIX=/.../bmadTryInternal \
  -DBMAD_EXTERNAL=/.../bmadTryExternal \
  -DBMAD_ECOSYSTEM_EMBED_EXTERNAL_RPATH=OFF
cmake --build build
cmake --install build

source /.../bmadTryInternal/bin/bmad-ecosystem-env.sh
/.../bmadTryInternal/bin/tao

]]
