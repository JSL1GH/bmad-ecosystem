
message(STATUS "In FindXRAYLIB.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

set(_XRAY_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_XRAY_PREFIX "${BMAD_EXTERNAL}")
endif()

find_path(XRAYLIB_INCLUDE_DIR
  NAMES xraylib.h
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES include include/xraylib
)

# C library
find_library(XRAYLIB_C_LIBRARY
  NAMES xrl xraylib
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES lib lib64
)

# Fortran wrapper library (this is the one bmad needs)
find_library(XRAYLIB_Fortran_LIBRARY
  NAMES xrlf03
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES lib lib64
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(XRAYLIB
  REQUIRED_VARS XRAYLIB_C_LIBRARY XRAYLIB_Fortran_LIBRARY XRAYLIB_INCLUDE_DIR
)

if(XRAYLIB_FOUND AND NOT TARGET XRAYLIB::xraylib)
  add_library(XRAYLIB::xraylib UNKNOWN IMPORTED)
  set_target_properties(XRAYLIB::xraylib PROPERTIES
    IMPORTED_LOCATION "${XRAYLIB_C_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${XRAYLIB_INCLUDE_DIR}"
  )
endif()

if(XRAYLIB_FOUND AND NOT TARGET XRAYLIB::xraylib_fortran)
  add_library(XRAYLIB::xraylib_fortran UNKNOWN IMPORTED)
  set_target_properties(XRAYLIB::xraylib_fortran PROPERTIES
    IMPORTED_LOCATION "${XRAYLIB_Fortran_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${XRAYLIB_INCLUDE_DIR}"
  )
  target_link_libraries(XRAYLIB::xraylib_fortran INTERFACE XRAYLIB::xraylib)
endif()

message(STATUS "XRAYLIB found: C='${XRAYLIB_C_LIBRARY}', Fortran='${XRAYLIB_Fortran_LIBRARY}', include='${XRAYLIB_INCLUDE_DIR}'")





#[[
message(STATUS "In FindXRAYLIB.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

# Prefer external prefix if provided
set(_XRAY_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_XRAY_PREFIX "${BMAD_EXTERNAL}")
endif()


find_path(XRAYLIB_INCLUDE_DIR
  NAMES xraylib.h
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES include include/xraylib
)

# XrayLib library name varies by distro/build:
# commonly: libxrl.so  (name "xrl")
# sometimes: libxraylib.so (name "xraylib")
find_library(XRAYLIB_LIBRARY
  NAMES xrl xraylib
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES lib lib64
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(XRAYLIB
  REQUIRED_VARS XRAYLIB_LIBRARY XRAYLIB_INCLUDE_DIR
)

find_library(XRAYLIB_C_LIBRARY
  NAMES xrl xraylib
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES lib lib64
)

find_library(XRAYLIB_Fortran_LIBRARY
  NAMES xrlf03 xraylibf03
  HINTS ${_XRAY_PREFIX}
  PATH_SUFFIXES lib lib64
)

# Require at least the C lib + headers
find_package_handle_standard_args(XRAYLIB
  REQUIRED_VARS XRAYLIB_C_LIBRARY XRAYLIB_INCLUDE_DIR
)


if(XRAYLIB_FOUND AND NOT TARGET XRAYLIB::xraylib)
  add_library(XRAYLIB::xraylib UNKNOWN IMPORTED)
  set_target_properties(XRAYLIB::xraylib PROPERTIES
    IMPORTED_LOCATION "${XRAYLIB_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${XRAYLIB_INCLUDE_DIR}"
  )
endif()

if(XRAYLIB_FOUND AND NOT TARGET XRAYLIB::xraylib)
  add_library(XRAYLIB::xraylib UNKNOWN IMPORTED)
  set_target_properties(XRAYLIB::xraylib PROPERTIES
    IMPORTED_LOCATION "${XRAYLIB_C_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${XRAYLIB_INCLUDE_DIR}"
  )
endif()

# Provide a Fortran target if available (this is what bmad needs)
if(XRAYLIB_Fortran_LIBRARY AND NOT TARGET XRAYLIB::xraylib_fortran)
  add_library(XRAYLIB::xraylib_fortran UNKNOWN IMPORTED)
  set_target_properties(XRAYLIB::xraylib_fortran PROPERTIES
    IMPORTED_LOCATION "${XRAYLIB_Fortran_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${XRAYLIB_INCLUDE_DIR}"
  )
  # Fortran wrapper usually depends on the C lib
  if(TARGET XRAYLIB::xraylib)
    target_link_libraries(XRAYLIB::xraylib_fortran INTERFACE XRAYLIB::xraylib)
  endif()
endif()


# Legacy variables (optional, no PARENT_SCOPE)
set(xraylib_LIBRARIES "${XRAYLIB_LIBRARY}")
set(xraylib_INCLUDE_DIRS "${XRAYLIB_INCLUDE_DIR}")

message(STATUS "XRAYLIB found: lib='${XRAYLIB_LIBRARY}', include='${XRAYLIB_INCLUDE_DIR}'")
]]
