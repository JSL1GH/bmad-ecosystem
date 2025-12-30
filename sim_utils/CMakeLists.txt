cmake_minimum_required(VERSION 3.18)

project(BMADPROJ)

set(LIBNAME sim_utils)

if("${CONDA_BUILD}" STREQUAL "ON")
    set(INC_DIRS
        ${CONDA_BUILD_PATH}/include/
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

# list of directories that contain files that need to be "built"
set(${LIBNAME}_SRC_DIRS
    file 
    interfaces 
    io 
    math 
    matrix 
    misc
    optimizers
    plot 
    string
    geodesic_lm
    special_functions
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

# this does the actual build of the library - done at 'make' time, not at cmake time!
# places the ${LIBNAME}.so file in the build directory/${LIBNAME}/lib${LIBNAME}.so
add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})

# here are the list of libraries to link against
#find_package(PLPLOT CONFIG REQUIRED COMPONENTS plplot)
#find_package(plplot CONFIG REQUIRED COMPONENTS plplot)

#get_cmake_property(_vars VARIABLES)

#foreach(_var ${_vars})
#  message(STATUS "${_var} = [${${_var}}]")
#endforeach()

#find_package(plplot CONFIG REQUIRED)
#message(STATUS "plplot variables have the value of ${plplot_LIBRARIES}")
#find_package(fgsl REQUIRED)
#find_package(fftw REQUIRED)
##find_package(lapack REQUIRED)
#find_package(lapack95 REQUIRED)
find_package(FGSL REQUIRED)
find_package(FFTW REQUIRED)
#find_package(lapack REQUIRED)
find_package(LAPACK95 REQUIRED)

set(${LIBNAME}_DEP_LIBS ${fgsl_LIBRARIES} ${gsl_LIBRARIES} ${plplot_LIBRARIES} blas ${fftw_LIBRARIES} ${lapack95_LIBRARIES})

message(STATUS "OUR DEP_LIBS FOR sim_utils is ${LIBNAME}_DEP_LIBS - ${${LIBNAME}_DEP_LIBS}")

#    target_include_directories(${DIR} PRIVATE ${X11_INCLUDE_DIR})
#   target_link_libraries(${DIR} PRIVATE ${X11_LIBRARIES})
if (APPLE)
    target_link_libraries(${LIBNAME} ${${LIBNAME}_DEP_LIBS} PLPLOT::plplot
    PLPLOT::plplotfortran readline ${X11_LIBRARIES})
else()
    target_link_libraries(${LIBNAME} ${${LIBNAME}_DEP_LIBS} readline)
endif()

message(DEBUG "This will be the build of ${LIBNAME} directory")

# this is where to find the include and modules files needed for our build of ${LIBNAME}
#target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

set(${LIBNAME}_INCLUDES)

#if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/include)
#    set(${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
#endif()
##if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/include)
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>)
##endif()
##if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/modules)
    list(APPEND ${LIBNAME}_INCLUDES $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>)
##endif()

list(APPEND ${LIBNAME}_INCLUDES
    $<INSTALL_INTERFACE:include>
    $<INSTALL_INTERFACE:modules>
)

target_include_directories(${LIBNAME} PUBLIC 
   ${${LIBNAME}_INCLUDES}
)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

#JSL - set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)
#maybe this is issue - set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)

# this is how the library files get into the /lib and /bin directories
#set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

set_target_properties(${LIBNAME} PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

#necessary for install
#install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include"
#)

#install(TARGETS ${LIBNAME} EXPORT ${LIBNAME}Targets)
#install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")
##install(DIRECTORY code DESTINATION src/${LIBNAME} FILESx2_MATCHING PATTERN "*.f90")
#install(DIRECTORY code DESTINATION src/forest${LIBNAME} FILES_MATCHING PATTERN "*.f90")
#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")

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
#install(DIRECTORY code DESTINATION src/${LIBNAME} FILESx2_MATCHING PATTERN "*.f90")


foreach (DIR ${${LIBNAME}_SRC_DIRS})
    install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING PATTERN "*.f90")
endforeach()

#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")

#install(
#    DIRECTORY A/
#    DESTINATION library
#    FILES_MATCHING
#    PATTERN "*.f90"
#)

install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)
