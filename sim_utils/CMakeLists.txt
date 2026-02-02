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

set(${LIBNAME}_DEP_LIBS
  FGSL::fgsl
  FFTW3::fftw3
  LAPACK95::lapack95
  PLPLOT::plplotfortran
)

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

target_include_directories(${LIBNAME} PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>
  $<INSTALL_INTERFACE:include>
  $<INSTALL_INTERFACE:modules>
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
  target_include_directories(${LIBNAME} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>)
endif()

#[[
# ------------------------------------------------------------
# Readline / libedit + append_history (portable + safe)
#
# Strategy:
#   - Prefer BMAD_EXTERNAL / conda / brew / macports prefixes first (NO_DEFAULT_PATH)
#   - Then fall back to system search (Linux)
#   - Reject Apple .tbd stubs
#   - Enable append_history only if the symbol exists AND links
#   - If nothing works: compile with HAVE_APPEND_HISTORY=0 (no hard fail)
# ------------------------------------------------------------

set(_RL_PREFIXES "")

if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  list(APPEND _RL_PREFIXES "${BMAD_EXTERNAL}")
endif()

if(DEFINED CONDA_BUILD_PATH AND NOT CONDA_BUILD_PATH STREQUAL "")
  list(APPEND _RL_PREFIXES "${CONDA_BUILD_PATH}")
endif()

if(DEFINED ENV{CONDA_PREFIX} AND NOT "$ENV{CONDA_PREFIX}" STREQUAL "")
  list(APPEND _RL_PREFIXES "$ENV{CONDA_PREFIX}")
endif()

if(APPLE)
  list(APPEND _RL_PREFIXES
    "/opt/homebrew/opt/readline" "/opt/homebrew"
    "/usr/local/opt/readline"   "/usr/local"
    "/opt/local"
  )
endif()

set(_RL_INCLUDE_DIR "")
set(_RL_LIBRARY "")
set(_HISTORY_LIBRARY "")
set(_CURSES_LIBRARY "")


get_property(_rl_inc_cache CACHE _RL_INCLUDE_DIR PROPERTY VALUE)
get_property(_rl_lib_cache CACHE _RL_LIBRARY     PROPERTY VALUE)
get_property(_rl_his_cache CACHE _HISTORY_LIBRARY PROPERTY VALUE)
message(STATUS "CACHE _RL_INCLUDE_DIR='${_rl_inc_cache}'")
message(STATUS "CACHE _RL_LIBRARY='${_rl_lib_cache}'")
message(STATUS "CACHE _HISTORY_LIBRARY='${_rl_his_cache}'")

# Prefer known prefixes first (avoid SDK stubs)
find_path(_RL_INCLUDE_DIR
  NAMES readline/readline.h editline/readline.h
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES include
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

find_library(_RL_LIBRARY
  NAMES readline edit
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES lib lib64
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

find_library(_HISTORY_LIBRARY
  NAMES history
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES lib lib64
  NO_DEFAULT_PATH
  NO_CMAKE_FIND_ROOT_PATH
)

# Fallback to system search if needed (mainly Linux)
if(NOT _RL_INCLUDE_DIR)
  find_path(_RL_INCLUDE_DIR NAMES readline/readline.h editline/readline.h PATH_SUFFIXES include)
endif()
if(NOT _RL_LIBRARY)
  find_library(_RL_LIBRARY NAMES readline edit PATH_SUFFIXES lib lib64)
endif()
if(NOT _HISTORY_LIBRARY)
  find_library(_HISTORY_LIBRARY NAMES history PATH_SUFFIXES lib lib64)
endif()

# Linux readline often needs curses/ncurses
if(NOT APPLE)
  find_library(_CURSES_LIBRARY NAMES ncurses curses)
endif()

# Reject Apple SDK stubs if they sneak in
if(APPLE AND _RL_LIBRARY MATCHES "\\.tbd$")
  message(STATUS "sim_utils: ignoring SDK stub library '${_RL_LIBRARY}'")
  set(_RL_LIBRARY "")
endif()

# Default: feature off
set(_HAVE_APPEND_HISTORY 0)

# Only try enabling if we have a real include+lib
if(_RL_INCLUDE_DIR AND _RL_LIBRARY)
  target_include_directories(${LIBNAME} PRIVATE "${_RL_INCLUDE_DIR}")
  target_link_libraries(${LIBNAME} PRIVATE "${_RL_LIBRARY}")
  if(_HISTORY_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${_HISTORY_LIBRARY}")
  endif()
  if(_CURSES_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${_CURSES_LIBRARY}")
  endif()

  # Now detect the symbol using the exact include+libs
  include(CheckSymbolExists)
  set(CMAKE_REQUIRED_INCLUDES "${_RL_INCLUDE_DIR}")
  set(CMAKE_REQUIRED_LIBRARIES "${_RL_LIBRARY}")
  if(_HISTORY_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${_HISTORY_LIBRARY}")
  endif()
  if(_CURSES_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${_CURSES_LIBRARY}")
  endif()

  check_symbol_exists(append_history "readline/history.h" _HAVE_APPEND_HISTORY)
  if(NOT _HAVE_APPEND_HISTORY)
    # libedit wrapper may declare it there
    check_symbol_exists(append_history "editline/readline.h" _HAVE_APPEND_HISTORY)
  endif()

  if(_HAVE_APPEND_HISTORY)
    message(STATUS "sim_utils: append_history available (enabled)")
  else()
    message(STATUS "sim_utils: append_history NOT available -> feature disabled")
  endif()

  message(STATUS "sim_utils: readline/edit include='${_RL_INCLUDE_DIR}', lib='${_RL_LIBRARY}'")
else()
  message(STATUS "sim_utils: readline/libedit not found -> feature disabled")
endif()

# Define once for this target
target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=${_HAVE_APPEND_HISTORY})
]]

#[[
###

# JSL 2nd drop in try
# ------------------------------------------------------------
# Readline / libedit + append_history (portable + safe)
#   - macOS: only accept a REAL dylib from brew/macports/conda/external
#            (never accept SDK .tbd)
#   - Linux: allow system fallback; link history/ncurses if needed
# ------------------------------------------------------------

set(_RL_PREFIXES "")

# 1) BMAD external stack first
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  list(APPEND _RL_PREFIXES "${BMAD_EXTERNAL}")
endif()

# 2) Conda (either your variable or active env)
if(DEFINED CONDA_BUILD_PATH AND NOT CONDA_BUILD_PATH STREQUAL "")
  list(APPEND _RL_PREFIXES "${CONDA_BUILD_PATH}")
endif()
if(DEFINED ENV{CONDA_PREFIX} AND NOT "$ENV{CONDA_PREFIX}" STREQUAL "")
  list(APPEND _RL_PREFIXES "$ENV{CONDA_PREFIX}")
endif()

# 3) macOS package manager prefixes
if(APPLE)
  list(APPEND _RL_PREFIXES
    "/opt/homebrew/opt/readline" "/opt/homebrew"
    "/usr/local/opt/readline"   "/usr/local"
    "/opt/local"
  )
endif()

set(_RL_INCLUDE_DIR "")
set(_RL_LIBRARY "")
set(_HISTORY_LIBRARY "")
set(_CURSES_LIBRARY "")
set(_HAVE_APPEND_HISTORY 0)

# --- Prefer known prefixes first (NO_DEFAULT_PATH) ---
find_path(_RL_INCLUDE_DIR
  NAMES readline/readline.h editline/readline.h
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES include
  NO_DEFAULT_PATH
)

find_library(_RL_LIBRARY
  NAMES readline edit
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES lib lib64
  NO_DEFAULT_PATH
)

find_library(_HISTORY_LIBRARY
  NAMES history
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES lib lib64
  NO_DEFAULT_PATH
)

message(STATUS "OUR LIST OF RL_PREFIXES WAS")
foreach (prefix ${_RL_PREFIXES})
  message(STATUS "${prefix}")
endforeach()


# --- Linux fallback (ONLY on non-Apple) ---
if(NOT APPLE)
  if(NOT _RL_INCLUDE_DIR)
    find_path(_RL_INCLUDE_DIR NAMES readline/readline.h editline/readline.h PATH_SUFFIXES include)
  endif()
  if(NOT _RL_LIBRARY)
    find_library(_RL_LIBRARY NAMES readline edit PATH_SUFFIXES lib lib64)
  endif()
  if(NOT _HISTORY_LIBRARY)
    find_library(_HISTORY_LIBRARY NAMES history PATH_SUFFIXES lib lib64)
  endif()

  find_library(_CURSES_LIBRARY NAMES ncurses curses)
endif()

message(STATUS "******************")
get_cmake_property(_vars VARIABLES)
foreach(_var ${_vars})
  message(STATUS "${_var} = [${${_var}}]")
endforeach()
message(STATUS "******************")

unset(_RL_INCLUDE_DIR CACHE)
unset(_RL_LIBRARY CACHE)
unset(_HISTORY_LIBRARY CACHE)
 
unset(_RL_INCLUDE_DIR)
unset(_RL_LIBRARY)
unset(_HISTORY_LIBRARY)

message(STATUS "_RL_INCLUDE_DIR='${_RL_INCLUDE_DIR}'")
message(STATUS "_RL_LIBRARY='${_RL_LIBRARY}'")
message(STATUS "_HISTORY_LIBRARY='${_HISTORY_LIBRARY}'")

# --- macOS guard: if not found in prefixes, DO NOT fallback to SDK (.tbd) ---
if(APPLE)
  if(_RL_LIBRARY AND _RL_LIBRARY MATCHES "\\.tbd$")
    message(STATUS "sim_utils: rejecting SDK stub '${_RL_LIBRARY}'")
    set(_RL_LIBRARY "")
  endif()
endif()

# Attach include + libraries if found; else feature stays disabled
if(_RL_INCLUDE_DIR AND _RL_LIBRARY)
  target_include_directories(${LIBNAME} PRIVATE "${_RL_INCLUDE_DIR}")
  target_link_libraries(${LIBNAME} PRIVATE "${_RL_LIBRARY}")

  # Some platforms put append_history in libhistory
  if(_HISTORY_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${_HISTORY_LIBRARY}")
  endif()

  # Linux often needs curses with readline
  if(_CURSES_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${_CURSES_LIBRARY}")
  endif()

  # Detect append_history against exactly what we will link
  include(CheckSymbolExists)
  set(CMAKE_REQUIRED_INCLUDES "${_RL_INCLUDE_DIR}")
  set(CMAKE_REQUIRED_LIBRARIES "${_RL_LIBRARY}")
  if(_HISTORY_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${_HISTORY_LIBRARY}")
  endif()
  if(_CURSES_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${_CURSES_LIBRARY}")
  endif()

  check_symbol_exists(append_history "readline/history.h" _HAVE_APPEND_HISTORY)
  if(NOT _HAVE_APPEND_HISTORY)
    check_symbol_exists(append_history "editline/readline.h" _HAVE_APPEND_HISTORY)
  endif()

  if(_HAVE_APPEND_HISTORY)
    message(STATUS "sim_utils: append_history available (enabled)")
  else()
    message(STATUS "sim_utils: append_history NOT available -> feature disabled")
  endif()

  message(STATUS "sim_utils: readline/edit include='${_RL_INCLUDE_DIR}', lib='${_RL_LIBRARY}'")
else()
  message(STATUS "sim_utils: readline/libedit not found (or rejected) -> feature disabled")
endif()

# Define once for this target (0/1)
target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=${_HAVE_APPEND_HISTORY})
####
]]

#3rd try

# ---- Readline / history ----
set(_RL_PREFIXES "")

if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  list(APPEND _RL_PREFIXES "${BMAD_EXTERNAL}")
endif()

if(DEFINED ENV{CONDA_PREFIX} AND NOT "$ENV{CONDA_PREFIX}" STREQUAL "")
  list(APPEND _RL_PREFIXES "$ENV{CONDA_PREFIX}")
endif()

if(APPLE)
  list(APPEND _RL_PREFIXES
    "/opt/homebrew/opt/readline" "/opt/homebrew"
    "/usr/local/opt/readline"   "/usr/local"
    "/opt/local"   # MacPorts
  )
endif()

# Prefer our prefixes first (NO_DEFAULT_PATH), then fall back to system
find_path(_RL_INCLUDE_DIR
  NAMES readline/readline.h editline/readline.h
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES include
  NO_DEFAULT_PATH
)
find_library(_RL_LIBRARY
  NAMES readline edit
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES lib lib64
  NO_DEFAULT_PATH
)
find_library(_HISTORY_LIBRARY
  NAMES history
  PATHS ${_RL_PREFIXES}
  PATH_SUFFIXES lib lib64
  NO_DEFAULT_PATH
)

if(NOT _RL_INCLUDE_DIR)
  find_path(_RL_INCLUDE_DIR NAMES readline/readline.h editline/readline.h PATH_SUFFIXES include)
endif()
if(NOT _RL_LIBRARY)
  find_library(_RL_LIBRARY NAMES readline edit PATH_SUFFIXES lib lib64)
endif()
if(NOT _HISTORY_LIBRARY)
  find_library(_HISTORY_LIBRARY NAMES history PATH_SUFFIXES lib lib64)
endif()

# Reject Apple SDK stubs if they sneak in
if(APPLE AND _RL_LIBRARY MATCHES "\\.tbd$")
  message(FATAL_ERROR "Found SDK stub readline: ${_RL_LIBRARY}. Need real Homebrew/MacPorts/Conda readline.")
endif()
if(APPLE AND _HISTORY_LIBRARY MATCHES "\\.tbd$")
  message(FATAL_ERROR "Found SDK stub history: ${_HISTORY_LIBRARY}. Need real Homebrew/MacPorts/Conda history.")
endif()

# Attach
if(_RL_INCLUDE_DIR AND _RL_LIBRARY)
  target_include_directories(${LIBNAME} PRIVATE "${_RL_INCLUDE_DIR}")
  target_link_libraries(${LIBNAME} PRIVATE "${_RL_LIBRARY}")
  if(_HISTORY_LIBRARY)
    target_link_libraries(${LIBNAME} PRIVATE "${_HISTORY_LIBRARY}")
  endif()

  # Linux sometimes needs curses too
  if(NOT APPLE)
    find_library(_CURSES_LIBRARY NAMES ncurses curses)
    if(_CURSES_LIBRARY)
      target_link_libraries(${LIBNAME} PRIVATE "${_CURSES_LIBRARY}")
    endif()
  endif()

  # Feature macro: only enable if symbol links with the libs we chose
  include(CheckSymbolExists)
  set(CMAKE_REQUIRED_INCLUDES "${_RL_INCLUDE_DIR}")
  set(CMAKE_REQUIRED_LIBRARIES "${_RL_LIBRARY}")
  if(_HISTORY_LIBRARY)
    list(APPEND CMAKE_REQUIRED_LIBRARIES "${_HISTORY_LIBRARY}")
  endif()

  check_symbol_exists(append_history "readline/history.h" HAVE_APPEND_HISTORY)
  target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=$<IF:$<BOOL:${HAVE_APPEND_HISTORY}>,1,0>)

  message(STATUS "sim_utils: readline include='${_RL_INCLUDE_DIR}'")
  message(STATUS "sim_utils: readline lib='${_RL_LIBRARY}'")
  message(STATUS "sim_utils: history  lib='${_HISTORY_LIBRARY}'")
else()
  target_compile_definitions(${LIBNAME} PRIVATE HAVE_APPEND_HISTORY=0)
  message(STATUS "sim_utils: readline/libedit not found -> feature disabled")
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
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
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
