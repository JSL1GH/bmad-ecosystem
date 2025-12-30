cmake_minimum_required(VERSION 3.18)

project(BMADPROJ)

set(LIBNAME bmad)

if("${CONDA_BUILD}" STREQUAL "ON")
    set(INC_DIRS
        ${CONDA_BUILD_PATH}/include/
        ${CONDA_BUILD_PATH}/include/xraylib/
        ${CONDA_BUILD_PATH}/include/fgsl/
    )
else()
    set(INC_DIRS
    )
endif()

#include_directories(${BMAD_EXTERNAL} ${INC_DIRS})

enable_language( Fortran )

#clear ${LIBNAME}_SRC_FILES
set(${LIBNAME}_SRC_FILES)

#clear ${LIBNAME}_SRC_DIRS
set(${LIBNAME}_SRC_DIRS)

set(${LIBNAME}_SRC_DIRS 
    code 
    # custom  # Using function pointers now
    geometry
    interface
    modules
    multiparticle
    output
    ptc
    photon
    parsing
    low_level
    hdf5
    space_charge
    spin
)

message(DEBUG "BUILDING LIST OF SRCS FROM ${LIBNAME} ${BASEDIR} ${${LIBNAME}_SRC_DIRS}")

# loop through the directories and add any files that will be built to the ${NEXT_DIR_FILES} variable
# at the end of discovering all of the files in a directory, we build the ${SRC_FILES} variable
foreach(DIR ${${LIBNAME}_SRC_DIRS})
    message(DEBUG "Looking at ${BASEDIR}/${LIBNAME}/${DIR}/*.f90")
    file( GLOB NEXT_DIR_FILES
        ${BASEDIR}/${LIBNAME}/${DIR}/*.f90
        ${BASEDIR}/${LIBNAME}/${DIR}/*.f
        ${BASEDIR}/${LIBNAME}/${DIR}/*.cc
        ${BASEDIR}/${LIBNAME}/${DIR}/*.cpp
        ${BASEDIR}/${LIBNAME}/${DIR}/*.cxx
        ${BASEDIR}/${LIBNAME}/${DIR}/*.c
        ${BASEDIR}/${LIBNAME}/${DIR}/*.CC
    )
    list(APPEND ${LIBNAME}_SRC_FILES ${NEXT_DIR_FILES})
endforeach()

message(STATUS "Value of ${LIBNAME}_SRC_FILES is - ${${LIBNAME}_SRC_FILES}")

message(DEBUG "THIS makes the library - ${LIBNAME} - from the .f90 files - list is ${${LIBNAME}_SRC_FILES}}")
message(STATUS "1. Working on ${LIBNAME}")

# this does the actual build of the library - done at 'make' time, not at cmake time!
# places the ${LIBNAME}.so file in the build directory/${LIBNAME}/lib${LIBNAME}.so
add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})

find_package(XRAYLIB REQUIRED)

if (APPLE)
    #Your top-level project is picking up Homebrew’s HDF5 instead of the one you built in ExternalProject_Add. On macOS, this is extremely common because #Homebrew installs libraries in /opt/homebrew/... and CMake’s module mode (FindHDF5.cmake) has higher precedence than the config files you built.
    #Solution: Force config mode by setting HDF5_DIR to your install path before calling find_package:

    #it turns out that all of the ChatGPT suggestions did not work
    #until at the end when it said we basically need to hardcode our version of hdf5
    #into the CMakeLists.txt file

    # ------------------------------------------------------------------
    # Find HDF5 (Fortran enabled)
    # ------------------------------------------------------------------
    # this is required to force cmake to find our config file before OS (Apple - Homebrew)
    find_package(HDF5 CONFIG REQUIRED COMPONENTS Fortran)

    # ============================================================
    # Explicit HDF5 import (bypasses broken HDF5 config files)
    # ============================================================

    set(HDF5_PREFIX ${BMAD_EXTERNAL})
    set(POSTFIX "dylib")

    # --- Core C library ---
    add_library(HDF5::C UNKNOWN IMPORTED)
    set_target_properties(HDF5::C PROPERTIES
        IMPORTED_LOCATION "${HDF5_PREFIX}/lib/libhdf5.${POSTFIX}"
        INTERFACE_INCLUDE_DIRECTORIES "${HDF5_PREFIX}/include"
    )

    # --- High-level C library ---
    add_library(HDF5::HL UNKNOWN IMPORTED)
    set_target_properties(HDF5::HL PROPERTIES
        IMPORTED_LOCATION "${HDF5_PREFIX}/lib/libhdf5_hl.${POSTFIX}"
        INTERFACE_INCLUDE_DIRECTORIES "${HDF5_PREFIX}/include"
    )
    target_link_libraries(HDF5::HL INTERFACE HDF5::C)

    # --- Fortran library ---
    add_library(HDF5::Fortran UNKNOWN IMPORTED)
    set_target_properties(HDF5::Fortran PROPERTIES
        IMPORTED_LOCATION "${HDF5_PREFIX}/lib/libhdf5_fortran.${POSTFIX}"
        INTERFACE_INCLUDE_DIRECTORIES "${HDF5_PREFIX}/include"
    )

    # --- Fortran High-level ---
    add_library(HDF5::HL_Fortran UNKNOWN IMPORTED)
    set_target_properties(HDF5::HL_Fortran PROPERTIES
        IMPORTED_LOCATION "${HDF5_PREFIX}/lib/libhdf5_hl_fortran.${POSTFIX}"
        INTERFACE_INCLUDE_DIRECTORIES "${HDF5_PREFIX}/include"
    )

    # --- HL Fortran C stubs (THIS WAS MISSING) ---
    add_library(HDF5::HL_F90CStub UNKNOWN IMPORTED)
    set_target_properties(HDF5::HL_F90CStub PROPERTIES
        IMPORTED_LOCATION "${HDF5_PREFIX}/lib/libhdf5_hl_f90cstub.${POSTFIX}"
        INTERFACE_INCLUDE_DIRECTORIES "${HDF5_PREFIX}/include"
    )

    # --- Fortran depends on C ---
    target_link_libraries(HDF5::Fortran INTERFACE HDF5::C)

    target_link_libraries(HDF5::HL_Fortran INTERFACE
        HDF5::HL_F90CStub
        HDF5::Fortran
    )

    target_link_libraries(HDF5::HL_F90CStub INTERFACE
        HDF5::HL
    )

    target_link_libraries(${LIBNAME}
        PUBLIC
#            ${DEP_LIBS} forest sim_utils ${xraylib_LIBRARIES}
            forest sim_utils ${xraylib_LIBRARIES}
    )

    target_link_libraries(${LIBNAME}
        PRIVATE
            HDF5::HL_Fortran
    )
else()
#    set(${LIBNAME}_DEP_LIBS ${fgsl_LIBRARIES} ${gsl_LIBRARIES} ${plplot_LIBRARIES} blas ${fftw_LIBRARIES} ${lapack95_LIBRARIES})

#    target_link_libraries(${LIBNAME}
#        PUBLIC
#            ${DEP_LIBS} forest sim_utils ${xraylib_LIBRARIES}
#            forest sim_utils ${xraylib_LIBRARIES}
#    ) 
    set(DEP_LIBS forest sim_utils ${xraylib_LIBRARIES})
    target_link_libraries(${LIBNAME} PUBLIC ${${LIBNAME}_DEP_LIBS} ${DEP_LIBS})
endif() # (if (APPLE))

message(DEBUG "This will be the build of ${LIBNAME} directory") # - ${CMAKE_BINARY_DIR} - ${CMAKE_CURRENT_BINARY_DIR} - ${CMAKE_CURRENT_SOURCE_DIR}")

# this is where to find the include and modules files needed for our build of ${LIBNAME}

#JSL - target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

#I DON'T KNOW IF THIS IS NEEDED!

foreach(dep_lib forest sim_utils)

    target_include_directories(${LIBNAME} PRIVATE
        $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/${dep_lib}/modules>
    )

endforeach()

#target_include_directories(${LIBNAME} PUBLIC
#    ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules ${CMAKE_BINARY_DIR}/sim_utils/modules)
set(${LIBNAME}_INCLUDES)


#if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
#endif()

##if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)    
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>)
##endif()
##if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)    
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>)
##endif()

list(APPEND ${LIBNAME}_INCLUDES
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
    $<INSTALL_INTERFACE:include>
    $<INSTALL_INTERFACE:modules>
)

#Then export that directory (from set_target_properties) to consumers:
#PUBLIC is important — it propagates to dependent targets.
target_include_directories(${LIBNAME} PUBLIC 
   ${${LIBNAME}_INCLUDES}
)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
#JSL - set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)



# this is how the library files get into the /lib and /bin directories
#JSL - set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)
#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)


#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)

# THIS IS CRITICAL - Tell CMake where the module files are generated:
set_target_properties(${LIBNAME} PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

#necessary for install
#install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include"
#)

#install(
#  TARGETS ${LIBNAME}
#  LIBRARY DESTINATION lib      # .so on Linux
#  ARCHIVE DESTINATION lib      # .a static libraries
#  RUNTIME DESTINATION bin      # .dll on Windows
#  PUBLIC_HEADER DESTINATION include
#)

message(STATUS "Our value of CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")

# get the include files into our build area
#if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
    file(GLOB INC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.inc")
#endif()

file(COPY ${INC_FILES}
     DESTINATION "${CMAKE_BINARY_DIR}/${LIBNAME}/include")

#necessary for install
install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include")

# place the targets of this library into the lib directory of the CMAKE_INSTALL_PREFIX area
install(TARGETS ${LIBNAME} LIBRARY DESTINATION lib)

install(TARGETS ${LIBNAME} EXPORT ${LIBNAME}Targets)
install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")

foreach (DIR ${${LIBNAME}_SRC_DIRS})
    install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING PATTERN "*.f90")
endforeach()


#install(DIRECTORY code DESTINATION src/${LIBNAME} FILESx2_MATCHING PATTERN "*.f90")
#install(DIRECTORY code DESTINATION src/${LIBNAME} FILES_MATCHING PATTERN "*.f90")


#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")
#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION . FILES_MATCHING PATTERN "*.mod")
install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)
