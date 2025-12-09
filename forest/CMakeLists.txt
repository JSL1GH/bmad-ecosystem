cmake_minimum_required(VERSION 3.18)

project(ACC)

set(LIBNAME forest)

# list of directories that contain files that need to be included
set(INC_DIRS
    include
)

include_directories(${BMAD_EXTERNAL} ${INC_DIRS})

enable_language( Fortran )

#clear ${LIBNAME}_SRC_FILES
set(${LIBNAME}_SRC_FILES)

#clear ${LIBNAME}_SRC_DIRS
set(${LIBNAME}_SRC_DIRS)

# list of directories that contain files that need to be "built"
set(${LIBNAME}_SRC_DIRS
    code
)

message(DEBUG "BUILDING LIST OF SRCS FROM ${LIBNAME} ${BASEDIR} ${${LIBNAME}_SRC_DIRS}")

# loop through the directories and add any files that will be built to the ${NEXT_DIR_FILES} variable
# at the end of discovering all of the files in a directory, we build the ${SRC_FILES} variable
foreach(DIR ${${LIBNAME}_SRC_DIRS})
    message(DEBUG "Looking at  ${BASEDIR}/${LIBNAME}/${DIR}/*.f90")
    file ( GLOB NEXT_DIR_FILES
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

# this does the actual build of the library - done at 'make' time, not at cmake time!
add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})

# here are the list of libraries to link against
target_link_libraries(${LIBNAME} ${DEP_LIBS})

message(DEBUG "This will be the build of ${LIBNAME} directory")

## in case we look for a library in the INC_DIRS list and it doesn't exist (e.g. first time build)
## but it will exist once we build it - this assumes we will be placing files in ${CMAKE_INSTALL_PREFIX}/include
#foreach(DIR ${INC_DIRS})
#    if(NOT EXISTS "${CMAKE_BINARY_DIR}/${DIR}")
#        # we create the directory in order to avoid an error in case we have no ${DIR} directory
#        file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/${DIR}")
#    endif()
#endforeach()

# this is where to find the include and modules files needed for our build of ${LIBNAME}
target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)
set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

# this is how the library files get into the /lib and /bin directories
set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

#necessary for install
install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include")

# place the targets of this library into the lib directory of the CMAKE_INSTALL_PREFIX area
install(TARGETS ${LIBNAME} LIBRARY DESTINATION lib)

## place the modules for this library into the modules directory of the CMAKE_INSTALL_PREFIX area
## place the header files for this library into the include directory of the CMAKE_INSTALL_PREFIX area
#install(
#    DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules/
#    DESTINATION modules
#)

## place the modules for this library into the modules directory of the CMAKE_INSTALL_PREFIX area
#install(
#    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/
#    DESTINATION include
#)
