#cmake_minimum_required(VERSION 3.18)

#project(BMAD_ECOSYSTEM)

set(LIBNAME forest)

message(STATUS "Now in file ${LIBNAME}/CMakeLists.txt")

# list of directories that contain files that need to be included
#set(INC_DIRS
#    include
#)

#enable_language( Fortran )

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

#note this had to get moved after add_library - for build time!
#target_link_libraries(${LIBNAME} PUBLIC DEPENDENT_LIBRARY_NAME_IN_THIS_PROJECT PRIVATE ${DEP_LIBS})

#set(${LIBNAME}_INCLUDES)

#message(STATUS "Values are current_binary - ${CMAKE_CURRENT_BINARY_DIR} - current_source - ${CMAKE_CURRENT_SOURCE_DIR}")
#message(STATUS "VALUE of  ${LIBNAME}_INCLUDES is ${${LIBNAME}_INCLUDES}")

target_include_directories(${LIBNAME} PUBLIC
#  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
  $<INSTALL_INTERFACE:modules>
)

message(DEBUG "This will be the build of ${LIBNAME} directory")

set_target_properties(${LIBNAME} PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

#message(STATUS "Our value of CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")

# get the include files into our build area
file(GLOB INC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.inc")

file(COPY ${INC_FILES}
     DESTINATION "${CMAKE_BINARY_DIR}/${LIBNAME}/include")

#necessary for install
#install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include")

# place the targets of this library into the lib directory of the CMAKE_INSTALL_PREFIX area
install(TARGETS ${LIBNAME}
        EXPORT BMAD_ECOSYSTEMTargets
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include
)

install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")
#install(DIRECTORY code DESTINATION src/${LIBNAME} FILES_MATCHING PATTERN "*.f90")

foreach (DIR ${${LIBNAME}_SRC_DIRS})
#  install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING
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


#install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")
#install(DIRECTORY "${CMAKE_BINARY_DIR}/" DESTINATION modules FILES_MATCHING PATTERN "*.mod")

#foreach (DIR ${${LIBNAME}_SRC_DIRS})
#    install(DIRECTORY ${DIR}/ DESTINATION src/${LIBNAME}/${DIR} FILES_MATCHING PATTERN "*.f90")
#endforeach()

install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)

#[[
#this can be used to print out all of the variables cmake knows about at this time
#move around as needed

#get_cmake_property(_vars VARIABLES)
#foreach(_var ${_vars})
#  message(STATUS "${_var} = [${${_var}}]")
#endforeach()
]]
