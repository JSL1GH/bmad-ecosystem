cmake_minimum_required(VERSION 3.18)

set(EXECUTABLE_NAME cpp_bmad_interface_test)

set(${EXECUTABLE_NAME}_TEST_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../interface_test")

file(GLOB ${EXECUTABLE_NAME}_TEST_SOURCES ${${EXECUTABLE_NAME}_TEST_DIR}/*.f90 ${${EXECUTABLE_NAME}_TEST_DIR}/*.cpp)

set(${EXECUTABLE_NAME}_SRC_FILES ${${EXECUTABLE_NAME}_TEST_SOURCES})

message(DEBUG "Value of ${EXECUTABLE_NAME}_SRC_FILES is - ${${EXECUTABLE_NAME}_SRC_FILES}")

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

target_link_libraries(${EXECUTABLE_NAME} PRIVATE cpp_bmad_interface tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} X11)

message(STATUS "PLACING BUILD OF ${EXECUTABLE_NAME} in ${CMAKE_BINARY_DIR}/bin")

# here we fix the name and call it tao
set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

#necessary for install
install(TARGETS ${EXECUTABLE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)
