message(STATUS "In FindLAPACK95.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

# Prefer external prefix if provided
set(_LAPACK95_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_LAPACK95_PREFIX "${BMAD_EXTERNAL}")
endif()

# Find the LAPACK95 library
find_library(LAPACK95_LIBRARY
  NAMES lapack95
  HINTS ${_LAPACK95_PREFIX}
  PATH_SUFFIXES lib lib64
)

# LAPACK is required underneath LAPACK95
# JSL - replacing find_package(LAPACK CONFIG REQUIRED)
# WITH
# --- Find LAPACK underneath LAPACK95 ---
# Strategy:
#  1) Prefer CONFIG under BMAD_EXTERNAL (curated external stack)
#  2) Otherwise fall back to system/module FindLAPACK.cmake

set(_lapack_found FALSE)

# Try CONFIG mode using BMAD_EXTERNAL as a hint (if provided)
if(_LAPACK95_PREFIX)
  find_package(LAPACK QUIET CONFIG HINTS "${_LAPACK95_PREFIX}")
  if(LAPACK_FOUND)
    set(_lapack_found TRUE)
  endif()
endif()

# Fall back to module mode (system, distro, etc.)
if(NOT _lapack_found)
  find_package(LAPACK REQUIRED MODULE)
  set(_lapack_found TRUE)
endif()

# LAPACK package may provide only variables; wrap into targets if needed
if(NOT TARGET BLAS::BLAS)
  add_library(BLAS::BLAS INTERFACE IMPORTED)

  if(DEFINED LAPACK_blas_LIBRARIES AND LAPACK_blas_LIBRARIES)
    target_link_libraries(BLAS::BLAS INTERFACE ${LAPACK_blas_LIBRARIES})
  elseif(DEFINED BLAS_LIBRARIES AND BLAS_LIBRARIES)
    target_link_libraries(BLAS::BLAS INTERFACE ${BLAS_LIBRARIES})
  elseif(DEFINED LAPACK_LIBRARIES AND LAPACK_LIBRARIES)
    # As a last resort
    target_link_libraries(BLAS::BLAS INTERFACE ${LAPACK_LIBRARIES})
  endif()
endif()

if(NOT TARGET LAPACK::LAPACK)
  add_library(LAPACK::LAPACK INTERFACE IMPORTED)

  if(DEFINED LAPACK_lapack_LIBRARIES AND LAPACK_lapack_LIBRARIES)
    target_link_libraries(LAPACK::LAPACK INTERFACE ${LAPACK_lapack_LIBRARIES} BLAS::BLAS)
  elseif(DEFINED LAPACK_LIBRARIES AND LAPACK_LIBRARIES)
    target_link_libraries(LAPACK::LAPACK INTERFACE ${LAPACK_LIBRARIES})
  endif()
endif()

###

# LAPACK package is variable-only: wrap into targets if needed
if(NOT TARGET BLAS::BLAS)
  add_library(BLAS::BLAS INTERFACE IMPORTED)
  target_link_libraries(BLAS::BLAS INTERFACE ${LAPACK_blas_LIBRARIES})
endif()

if(NOT TARGET LAPACK::LAPACK)
  add_library(LAPACK::LAPACK INTERFACE IMPORTED)
  target_link_libraries(LAPACK::LAPACK INTERFACE ${LAPACK_lapack_LIBRARIES} BLAS::BLAS)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LAPACK95
  REQUIRED_VARS LAPACK95_LIBRARY
)

# Imported target for consumers
if(LAPACK95_FOUND AND NOT TARGET LAPACK95::lapack95)
  add_library(LAPACK95::lapack95 UNKNOWN IMPORTED)
  set_target_properties(LAPACK95::lapack95 PROPERTIES
    IMPORTED_LOCATION "${LAPACK95_LIBRARY}"
  )
  target_link_libraries(LAPACK95::lapack95 INTERFACE LAPACK::LAPACK)
endif()

message(STATUS "LAPACK95 found: lib='${LAPACK95_LIBRARY}'")
