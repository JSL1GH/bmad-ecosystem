cmake_minimum_required(VERSION 3.18)

set(EXECUTABLE_NAME analysis_test)

message(STATUS "Building ${EXECUTABLE_NAME}")

file(GLOB ${EXECUTABLE_NAME}_SRC_FILES ${CMAKE_CURRENT_SOURCE_DIR}/*.f90)

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

target_link_libraries(${EXECUTABLE_NAME} PRIVATE bsim cpp_bmad_interface tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} X11)

enable_language( Fortran )

set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS ${EXECUTABLE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
