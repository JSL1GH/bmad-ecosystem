# sim_utils/CMakeLists.txt

set(LIBNAME sim_utils)
message(STATUS "Now in file ${LIBNAME}/CMakeLists.txt")

# ------------------------------------------------------------
# Sources
# ------------------------------------------------------------
set(${LIBNAME}_SRC_FILES)
set(${LIBNAME}_SRC_DIRS
  file
  interfaces
  io
  math
  matrix
  misc
  optimizers
  plot
  string
  geodesic_lm
  special_functions
)

foreach(DIR ${${LIBNAME}_SRC_DIRS})
  file(GLOB NEXT_DIR_FILES
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

message(STATUS "1. Working on ${LIBNAME}")
add_library(${LIBNAME} ${${LIBNAME}_SRC_FILES})
add_library(BMAD_ECOSYSTEM::${LIBNAME} ALIAS ${LIBNAME})

# ------------------------------------------------------------
# Dependencies (targets)
# ------------------------------------------------------------
find_package(plplot CONFIG REQUIRED)
message(STATUS "sim_utils: plplot_DIR='${plplot_DIR}', plplot_FOUND='${plplot_FOUND}'")

find_package(FGSL REQUIRED)
find_package(FFTW3 REQUIRED MODULE)
find_package(LAPACK95 REQUIRED)

# Prefer the real imported targets (avoid raw ${gsl_LIBRARIES} if possible)
# FGSL::fgsl already pulls GSL::gsl if your FindFGSL.cmake created it.
set(${LIBNAME}_DEP_LIBS
  FGSL::fgsl
  FFTW3::fftw3
  LAPACK95::lapack95
  PLPLOT::plplotfortran
)

# X11 is only meaningful on Apple if your PLplot build needs it; if your top-level
# already did find_package(X11 REQUIRED) you can rely on X11_LIBRARIES being set.
# If not, this stays harmless.
if(APPLE AND DEFINED X11_LIBRARIES)
  list(APPEND ${LIBNAME}_DEP_LIBS ${X11_LIBRARIES})
endif()

target_link_libraries(${LIBNAME} PUBLIC ${${LIBNAME}_DEP_LIBS})

# ------------------------------------------------------------
# Fortran module + include propagation
# ------------------------------------------------------------
set_target_properties(${LIBNAME} PROPERTIES
  Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules"
)

# Only add source include dir if it exists (avoids -Wmissing-include-dirs)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
  target_include_directories(${LIBNAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
  )
endif()

# Always expose the module directory to dependents
target_include_directories(${LIBNAME} PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
  $<INSTALL_INTERFACE:modules>
)

# ------------------------------------------------------------
# Readline / history (append_history) support
#   - works with Homebrew, MacPorts, Conda, or system
#   - defines HAVE_APPEND_HISTORY as 0/1 *once* for this target
# ------------------------------------------------------------
# We do NOT use include_directories()/link_directories() here.
# Everything is target-based.

set(_READLINE_HINTS "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  list(APPEND _READLINE_HINTS "${BMAD_EXTERNAL}")
endif()

if("${CONDA_BUILD}" STREQUAL "ON" AND DEFINED CONDA_BUILD_PATH AND NOT CONDA_BUILD_PATH STREQUAL "")
  list(APPEND _READLINE_HINTS "${CONDA_BUILD_PATH}")
elseif(DEFINED ENV{CONDA_PREFIX} AND NOT "$ENV{CONDA_PREFIX}" STREQUAL "")
  list(APPEND _READLINE_HINTS "$ENV{CONDA_PREFIX}")
endif()

if(APPLE)
  # Homebrew + Intel brew + MacPorts prefixes
  list(APPEND _READLINE_HINTS "/opt/homebrew/opt/readline" "/usr/local/opt/readline" "/opt/local")
endif()

# Header: we specifically want readline/history.h if present (declares append_history)
find_path(READLINE_INCLUDE_DIR
  NAMES readline/history.h
  HINTS ${_READLINE_HINTS}
  PATH_SUFFIXES include
)

# Library: GNU readline
find_library(READLINE_LIBRARY
  NAMES readline
  HINTS ${_READLINE_HINTS}
  PATH_SUFFIXES lib
)

# Optional separate history library (more common on Linux)
find_library(HISTORY_LIBRARY
  NAMES history
  HINTS ${_READLINE_HINTS}
  PATH_SUFFIXES lib
)

# Optional curses dependency on Linux
set(NCURSES_LIBRARY "")
if(NOT APPLE)
  find_library(NCURSES_LIBRARY NAMES ncurses curses)
endif()

# If we have a candidate, attach it and test append_history.
# If we cannot find it, we degrade gracefully and compile without append_history.
if(READLINE_INCLUDE_DIR AND READLINE_LIBRARY)
  target_include_directories(${LIBNAME} PRIVATE "${READLINE_INCLUDE_DIR}")
  target_link_libraries(${LIBNAME} PRIVATE "${READLINE_LIBRARY}")
  if(HISTORY_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${HISTORY_LIBRARY}")
  endif()
  if(NCURSES_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${NCURSES_LIBRARY}")
  endif()

  include(CheckSymbolExists)
  set(CMAKE_REQUIRED_INCLUDES "${READLINE_INCLUDE_DIR}")
  set(CMAKE_REQUIRED_LIBRARIES "${READLINE_LIBRARY}")
  if(HISTORY_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${HISTORY_LIBRARY}")
  endif()
  if(NCURSES_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${NCURSES_LIBRARY}")
  endif()

  check_symbol_exists(append_history "readline/history.h" HAVE_APPEND_HISTORY)

  if(HAVE_APPEND_HISTORY)
    target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=1)
    message(STATUS "sim_utils: append_history available (readline)")
  else()
    target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=0)
    message(STATUS "sim_utils: append_history NOT available -> feature disabled")
  endif()

  message(STATUS "sim_utils: readline include='${READLINE_INCLUDE_DIR}', lib='${READLINE_LIBRARY}'")
else()
  target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=0)
  message(STATUS "sim_utils: readline not found -> append_history feature disabled")
endif()

# ------------------------------------------------------------
# Install (exported target + includes/modules + source)
# ------------------------------------------------------------
# Copy .inc into build tree include (optional)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
  file(GLOB INC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/*.inc")
  if(INC_FILES)
    file(COPY ${INC_FILES} DESTINATION "${CMAKE_BINARY_DIR}/${LIBNAME}/include")
  endif()
endif()

install(TARGETS ${LIBNAME}
  EXPORT BMAD_ECOSYSTEMTargets
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)

# install include .inc files
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
  install(DIRECTORY include/ DESTINATION include FILES_MATCHING PATTERN "*.inc")
endif()

# install modules
install(
  DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules/"
  DESTINATION modules
)

# install sources (your bookkeeping requirement)
foreach(DIR ${${LIBNAME}_SRC_DIRS})
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



