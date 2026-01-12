#cmake_minimum_required(VERSION 3.18)

#project(BMADPROJ)

SET (LIBNAME tao)

message(STATUS "Now in file ${LIBNAME}/CMakeLists.txt")

if("${CONDA_BUILD}" STREQUAL "ON")
    set(INC_DIRS
        ${CONDA_BUILD_PATH}/include/
        ${CONDA_BUILD_PATH}/include/fgsl/
    )
else()
    set(INC_DIRS
    )
endif()

#enable_language( Fortran )

#clear ${LIBNAME}_SRC_FILES
set(${LIBNAME}_SRC_FILES)

#clear ${LIBNAME}_SRC_DIRS
set(${LIBNAME}_SRC_DIRS)

# list of directories that contain files that need to be "built"
set(${LIBNAME}_SRC_DIRS 
    code 
    # hook # Now using function pointers
    version
)

message(DEBUG "BUILDING LIST OF SRCS FROM ${LIBNAME} ${BASEDIR} ${SRCDIRS}")

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

add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})
add_library(BMAD_ECOSYSTEM::${LIBNAME} ALIAS ${LIBNAME})

target_link_libraries(${LIBNAME}
  PUBLIC
    BMAD_ECOSYSTEM::bmad
    BMAD_ECOSYSTEM::sim_utils
    BMAD_ECOSYSTEM::forest
  PRIVATE
    ${DEP_LIBS}
)

message(DEBUG "This will be the build of ${LIBNAME} directory")

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
#NEXT IS BETTER set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)
set_target_properties(${LIBNAME} PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

#message(STATUS "Our value of CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")

if(INC_FILES)
  file(COPY ${INC_FILES}
    DESTINATION "${CMAKE_BINARY_DIR}/${LIBNAME}/include")
endif()

# place the targets of this library into the lib directory of the CMAKE_INSTALL_PREFIX area
#install(TARGETS ${LIBNAME} LIBRARY DESTINATION lib)

#install(TARGETS ${LIBNAME} EXPORT ${LIBNAME}Targets)
install(TARGETS ${LIBNAME}
  EXPORT BMAD_ECOSYSTEMTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)

install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")

foreach (DIR ${${LIBNAME}_SRC_DIRS})
#    install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING PATTERN "*.f90")
#  install(DIRECTORY code DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING
  install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING
    PATTERN "*.f"
    PATTERN "*.f90"
    PATTERN "*.c"
    PATTERN "*.cc"
    PATTERN "*.CC"
    PATTERN "*.cpp"
    PATTERN "*.cxx"
  )
endforeach()

install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)


# now build library associated programs
add_subdirectory(tao)
