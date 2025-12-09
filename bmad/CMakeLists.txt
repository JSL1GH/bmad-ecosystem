cmake_minimum_required(VERSION 3.18)

project(ACC)

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

include_directories(${BMAD_EXTERNAL} ${INC_DIRS})

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

message(DEBUG "Value of ${LIBNAME}_SRC_FILES is - ${${LIBNAME}_SRC_FILES}")

message(DEBUG "THIS makes the library - ${LIBNAME} - from the .f90 files - list is ${${LIBNAME}_SRC_FILES}}")
message(STATUS "1. Working on ${LIBNAME}")

add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})

target_link_libraries(${LIBNAME} ${DEP_LIBS})

message(DEBUG "This will be the build of ${LIBNAME} directory")

# this is where to find the include and modules files needed for our build of ${LIBNAME}
target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

# this is how the library files get into the /lib and /bin directories
set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

#necessary for install
install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include"
)
