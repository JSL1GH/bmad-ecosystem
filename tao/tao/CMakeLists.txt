#cmake_minimum_required(VERSION 3.18)

# because tao is the name of the library
# we need to use a different name for the target
set(EXECUTABLE_NAME tao.tmp)

message(STATUS "Building ${EXECUTABLE_NAME}")

set(${EXECUTABLE_NAME}_SRC_FILES ../program/tao_program.f90)

message(DEBUG "Value of ${EXECUTABLE_NAME}_SRC_FILES is - ${${EXECUTABLE_NAME}_SRC_FILES}")

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

#target_include_directories(${EXECUTABLE_NAME}
#    PRIVATE
#        $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/tao/modules>
##        $<TARGET_PROPERTY:tao,Fortran_MODULE_DIRECTORY>
#)

#target_link_libraries(${EXECUTABLE_NAME} PRIVATE tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} X11)
target_link_libraries(${EXECUTABLE_NAME} PRIVATE BMAD_ECOSYSTEM::tao)

#message(STATUS "PLACING BUILD OF ${EXECUTABLE_NAME} in ${CMAKE_BINARY_DIR}/bin")

#get_target_property(_mods tao Fortran_MODULE_DIRECTORY)
#message(STATUS "tao module dir = ${_mods}")

# here we fix the name and call it tao
set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    OUTPUT_NAME "tao"
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

#necessary for install
#note that the tao.tmp is just the TARGET - when it gets saved to CMAKE_INSTALL_PREFIX
#it will have the OUTPUT_NAME listed in set_target_properties
install(TARGETS ${EXECUTABLE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)
