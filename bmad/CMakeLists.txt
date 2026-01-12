#cmake_minimum_required(VERSION 3.18)

#project(BMADPROJ)

set(LIBNAME bmad)

message(STATUS "Now in file ${LIBNAME}/CMakeLists.txt")

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

#enable_language( Fortran )

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
        ${BASEDIR}/${LIBNAME}/${DIR}/*.f
        ${BASEDIR}/${LIBNAME}/${DIR}/*.f90
        ${BASEDIR}/${LIBNAME}/${DIR}/*.c
        ${BASEDIR}/${LIBNAME}/${DIR}/*.cc
        ${BASEDIR}/${LIBNAME}/${DIR}/*.CC
        ${BASEDIR}/${LIBNAME}/${DIR}/*.cpp
        ${BASEDIR}/${LIBNAME}/${DIR}/*.cxx
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

find_package(XRAYLIB REQUIRED)
find_package(HDF5BMAD REQUIRED)

#target_link_libraries(${LIBNAME} PRIVATE HDF5BMAD::HL_Fortran)
target_link_libraries(${LIBNAME} PUBLIC HDF5BMAD::HL_Fortran)
target_link_libraries(${LIBNAME} PUBLIC XRAYLIB::xraylib_fortran)
target_link_libraries(${LIBNAME} PUBLIC BMAD_ECOSYSTEM::forest)
target_link_libraries(${LIBNAME} PUBLIC BMAD_ECOSYSTEM::sim_utils)
target_link_libraries(${LIBNAME} PRIVATE ${DEP_LIBS})

message(DEBUG "This will be the build of ${LIBNAME} directory") # - ${CMAKE_BINARY_DIR} - ${CMAKE_CURRENT_BINARY_DIR} - ${CMAKE_CURRENT_SOURCE_DIR}")

# this is where to find the include and modules files needed for our build of ${LIBNAME}

#JSL - target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

#I DON'T KNOW IF THIS IS NEEDED!

#Then export that directory (from set_target_properties) to consumers:
#PUBLIC is important — it propagates to dependent targets.
#[[
target_include_directories(${LIBNAME} PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
  $<INSTALL_INTERFACE:include>
  $<INSTALL_INTERFACE:modules>
)
]]
target_include_directories(${LIBNAME} PUBLIC
#  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
  $<INSTALL_INTERFACE:modules>
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

#message(STATUS "Our value of CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")

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

#install(TARGETS ${LIBNAME} EXPORT ${LIBNAME}Targets)

install(TARGETS ${LIBNAME}
  EXPORT BMAD_ECOSYSTEMTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
)

install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")

foreach (DIR ${${LIBNAME}_SRC_DIRS})
#    install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING PATTERN "*.f90")
  install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING

#  install(DIRECTORY code DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING

    PATTERN "*.f"
    PATTERN "*.f90"
    PATTERN "*.c"
    PATTERN "*.cc"
    PATTERN "*.CC"
    PATTERN "*.cpp"
    PATTERN "*.cxx"
  )
endforeach()


#install(DIRECTORY code DESTINATION src/${LIBNAME} FILESx2_MATCHING PATTERN "*.f90")
#install(DIRECTORY code DESTINATION src/${LIBNAME} FILES_MATCHING PATTERN "*.f90")


#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")
#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION . FILES_MATCHING PATTERN "*.mod")
install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)
