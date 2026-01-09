cmake_minimum_required(VERSION 3.18)

project(BMAD_ECOSYSTEM)

set(LIBNAME forest)

# list of directories that contain files that need to be included
set(INC_DIRS
    include
)


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
# places the ${LIBNAME}.so file in the build directory/${LIBNAME}/lib${LIBNAME}.so

add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})
add_library(BMAD_ECOSYSTEM::${LIBNAME} ALIAS ${LIBNAME})

#include_directories(${BMAD_EXTERNAL} ${INC_DIRS})


#note this had to get moved after add_library - for build time!

set(${LIBNAME}_INCLUDES)

message(STATUS "Values are current_binary - ${CMAKE_CURRENT_BINARY_DIR} - current_source - ${CMAKE_CURRENT_SOURCE_DIR}")

##if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/include)
#if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>)
##endif()
##if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/modules)
#if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
#message(STATUS "IT EXISTS!")
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>)
##endif()
##if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
##endif()

list(APPEND ${LIBNAME}_INCLUDES
#NOT SURE WHAT THIS DOES
# I added this - and it built fine - but I see an error - but without it - did it fail?  I thought so
# I don't understand how this made a difference.
#    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
    $<INSTALL_INTERFACE:include>
    $<INSTALL_INTERFACE:modules>
)

message(STATUS "VALUE of  ${LIBNAME}_INCLUDES is ${${LIBNAME}_INCLUDES}")

target_include_directories(${LIBNAME} PUBLIC 
   ${${LIBNAME}_INCLUDES}
)

#target_include_directories(${LIBNAME} PUBLIC ${INC_DIRS})
#target_include_directories(${LIBNAME} PUBLIC include)

# here are the list of libraries to link against
#target_link_libraries(${LIBNAME} ${DEP_LIBS})

#[[ JSL - We did this just for proof of principle!
 make this public allows anyone that links forest to also add gsl as a dependency

target_link_libraries(forest
    PUBLIC
        GSL::gsl
)
]]

target_link_libraries(forest PRIVATE ${DEP_LIBS})

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
#target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)


#target_include_directories(${LIBNAME} PUBLIC 
#  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
#  $<INSTALL_INTERFACE:include>
#  $<INSTALL_INTERFACE:modules>
#)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)
#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

#WORKS - BUT....
#COMMENTING NOW - set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)

#BETTER
set_target_properties(${LIBNAME} PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

# this is how the library files get into the /lib and /bin directories
#set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
#set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY .)# ${LIBNAME}) #${CMAKE_BINARY_DIR}/lib)

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

message(STATUS "Our value of CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")

# get the include files into our build area
file(GLOB INC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.inc")

file(COPY ${INC_FILES}
     DESTINATION "${CMAKE_BINARY_DIR}/${LIBNAME}/include")

#necessary for install
install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include")

# place the targets of this library into the lib directory of the CMAKE_INSTALL_PREFIX area
install(TARGETS ${LIBNAME}
        EXPORT BMAD_ECOSYSTEMTargets
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include
)

#install(TARGETS ${LIBNAME} EXPORT ${LIBNAME}Targets)



install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")
#install(DIRECTORY code DESTINATION src/${LIBNAME} FILESx2_MATCHING PATTERN "*.f90")
install(DIRECTORY code DESTINATION src/${LIBNAME} FILES_MATCHING PATTERN "*.f90")
#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")
#install(DIRECTORY "${CMAKE_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")

#MAYBE WORKS - BUT
install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)
#BETTER

#install(
#    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
#    DESTINATION modules
#)
