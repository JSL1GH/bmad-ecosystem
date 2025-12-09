cmake_minimum_required(VERSION 3.18)

#we call it tao.tmp, because tao would interfere with the tao target - directory name
set(EXECUTABLE_NAME tao.tmp)

set(${EXECUTABLE_NAME}_SRC_FILES ../program/tao_program.f90)

message(DEBUG "Value of ${EXECUTABLE_NAME}_SRC_FILES is - ${${EXECUTABLE_NAME}_SRC_FILES}")

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

target_link_libraries(${EXECUTABLE_NAME} PRIVATE tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} X11)

message(STATUS "PLACING BUILD OF ${EXECUTABLE_NAME} in ${CMAKE_BINARY_DIR}/bin")

# here we fix the name and call it tao
set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    OUTPUT_NAME "tao"
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

#necessary for install
#note that the tao.tmp is just the TARGET - when it gets saved to CMAKE_INSTALL_PREFIX
#it will have the OUTPUT_NAME listed in set_target_properties
install(TARGETS tao.tmp RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
)
