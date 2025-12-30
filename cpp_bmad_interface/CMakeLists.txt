cmake_minimum_required(VERSION 3.18)

project(BMADPROJ)

set(LIBNAME cpp_bmad_interface)

if("${CONDA_BUILD}" STREQUAL "ON")
    set(INC_DIRS
        ${CONDA_BUILD_PATH}/include/
        ${CONDA_BUILD_PATH}/include/xraylib/
        ${CONDA_BUILD_PATH}/include/fgsl/
        include
    )
else()
    set(INC_DIRS include
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
)

message(DEBUG "BUILDING LIST OF SRCS FROM ${LIBNAME} ${BASEDIR} ${SRCDIRS}")

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

target_link_libraries(${LIBNAME} ${DEP_LIBS} sim_utils)

message(DEBUG "This will be the build of ${LIBNAME} directory")




#[[

# this is where to find the include and modules files needed for our build of ${LIBNAME}
target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

# this is how the library files get into the /lib and /bin directories
set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

#necessary for install
install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include"
)

]]

foreach(dep_lib forest sim_utils bmad tao)

    target_include_directories(${LIBNAME} PRIVATE
        $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/${dep_lib}/modules>
#        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
#        $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/modules>
    )

endforeach()
#foreach(dep_lib forest sim_utils bmad tao)
#foreach(dep_lib forest sim_utils bmad)
foreach(LIB cpp_bmad_interface)
    target_include_directories(${LIBNAME} PUBLIC
        $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/modules>
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>

#${dep_lib}/include>
#        $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
#        $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/modules>
    )

#as per chatgpt
#target_include_directories(mylib
#    PUBLIC
#        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
#        $<INSTALL_INTERFACE:include>
#)


endforeach()
## this is where to find the include and modules files needed for our build of ${LIBNAME}
#target_include_directories(${LIBNAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_BINARY_DIR}/include ${CMAKE_BINARY_DIR}/modules)

# this tells the build to place mod files into the ${CMAKE_BINARY_DIR}/modules directory
#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/modules)

# this is how the library files get into the /lib and /bin directories
#set_target_properties(${LIBNAME} PROPERTIES LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)


#NEXT IS BETTER set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY modules)
set_target_properties(${LIBNAME} PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

#set_target_properties(${LIBNAME} PROPERTIES Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/modules)

message(STATUS "Our value of CMAKE_CURRENT_BINARY_DIR is ${CMAKE_CURRENT_BINARY_DIR}")

file(COPY ${INC_FILES}
     DESTINATION "${CMAKE_BINARY_DIR}/${LIBNAME}/include")


##necessary for install
#install(TARGETS ${LIBNAME} PUBLIC_HEADER DESTINATION "${CMAKE_INSTALL_PREFIX}/include"
#)

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

install(
    DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
    DESTINATION modules
)



# now build library associated programs
add_subdirectory(cpp_bmad_interface_test)
