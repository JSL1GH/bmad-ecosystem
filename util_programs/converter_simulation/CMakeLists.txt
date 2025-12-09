cmake_minimum_required(VERSION 3.18)

set(EXECUTABLE_NAME converter_simulation)

message(STATUS "Building ${EXECUTABLE_NAME}")

file(GLOB ${EXECUTABLE_NAME}_SRC_FILES ${CMAKE_CURRENT_SOURCE_DIR}/../converter_element_modeling/simulation/*.cpp)

add_executable(${EXECUTABLE_NAME} ${${EXECUTABLE_NAME}_SRC_FILES})

target_link_libraries(${EXECUTABLE_NAME} PRIVATE bsim cpp_bmad_interface tao bmad sim_utils forest gomp readline ${LIST_OF_EXTERNAL_LIBRARIES} stdc++fs X11)

target_include_directories(${EXECUTABLE_NAME} BEFORE PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../converter_element_modeling/simulation)

target_compile_options(${EXECUTABLE_NAME} PRIVATE "-std=c++17")

enable_language( Fortran )

set_target_properties(${EXECUTABLE_NAME} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

install(TARGETS ${EXECUTABLE_NAME} RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)

#dependency on Geant4?
#[[


set (EXENAME converter_simulation)
set (CONVERTER_SIM_DIR converter_element_modeling/simulation)

#----------------------------------------------------------------------------
# Find Geant4 package
#
option(WITH_GEANT4_UIVIS OFF)
if(WITH_GEANT4_UIVIS)
  find_package(Geant4 REQUIRED ui_all vis_all)
else()
  find_package(Geant4 REQUIRED)
endif()

#----------------------------------------------------------------------------
# Setup Geant4 include directories and compile definitions
# Setup include directory for this project
#
include(${Geant4_USE_FILE})
get_property(INC_DIRS DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
set(INC_DIRS
  ${INC_DIRS}
  ${CONVERTER_SIM_DIR}/include
  )

#----------------------------------------------------------------------------
# Locate sources and headers for this project
# NB: headers are included so they will show up in IDEs
#
file(GLOB SRC_FILES
  ${CONVERTER_SIM_DIR}/src/*.cpp
  ${CONVERTER_SIM_DIR}/main.cpp
  )

#----------------------------------------------------------------------------
# Compiler flags
SET(GCC_COMPILE_FLAGS "-Wall -Wextra -Wpedantic -Wshadow -std=c++17")
#add_definitions(${GCC_COMPILE_FLAGS})
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${GCC_COMPILE_FLAGS}")
SET(CFLAGS "${CMAKE_CXX_FLAGS}")

#----------------------------------------------------------------------------
# Add the executable, and link it to the Geant4 libraries
#
SET (SHARED_LINK_LIBS
  stdc++fs
  ${Geant4_LIBRARIES}
  )
]]
