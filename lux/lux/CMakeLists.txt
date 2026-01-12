#cmake_minimum_required(VERSION 3.18)

# because lux is the name of the library
# we need to use a different name for the target
set(EXECUTABLE_NAME lux.tmp)

message(STATUS "Building ${EXECUTABLE_NAME}")

#here we have to specify lux.f90 because our general method of using EXECUTABLE_NAME breaks down.
set(${EXECUTABLE_NAME}_SRC_FILES ${CMAKE_CURRENT_SOURCE_DIR}/../program/lux.f90)

message(DEBUG "Value of ${EXECUTABLE_NAME}_SRC_FILES is - ${${EXECUTABLE_NAME}_SRC_FILES}")

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

target_link_libraries(${EXECUTABLE_NAME} PRIVATE BMAD_ECOSYSTEM::lux)
# bsim cpp_bmad_interface tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} X11)

#enable_language( Fortran )

set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    OUTPUT_NAME "lux"
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS ${EXECUTABLE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
