cmake_minimum_required(VERSION 3.18)

set(EXECUTABLE_NAME touschek_background)

message(STATUS "Building ${EXECUTABLE_NAME}")

set(${EXECUTABLE_NAME}_SRC_FILES ${CMAKE_CURRENT_SOURCE_DIR}/touschek_background.f90 ${CMAKE_CURRENT_SOURCE_DIR}/touschek_background_mod.f90 ${CMAKE_CURRENT_SOURCE_DIR}/touschek_background_mpi_mod.f90 ${CMAKE_CURRENT_SOURCE_DIR}/special_collimate_lattice.f90)

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

target_link_libraries(${EXECUTABLE_NAME} PRIVATE bsim cpp_bmad_interface tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} X11)

enable_language( Fortran )

set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS ${EXECUTABLE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)
