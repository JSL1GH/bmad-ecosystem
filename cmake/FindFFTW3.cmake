message(STATUS "In FindFFTW3.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

set(_FFTW_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_FFTW_PREFIX "${BMAD_EXTERNAL}")
endif()

find_path(FFTW3_INCLUDE_DIR
  NAMES fftw3.h
  HINTS ${_FFTW_PREFIX}
  PATH_SUFFIXES include
)

find_library(FFTW3_LIBRARY
  NAMES fftw3
  HINTS ${_FFTW_PREFIX}
  PATH_SUFFIXES lib lib64
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(FFTW3
  REQUIRED_VARS FFTW3_LIBRARY FFTW3_INCLUDE_DIR
)

set(FFTW3_INCLUDE_DIRS "${FFTW3_INCLUDE_DIR}")
set(FFTW3_LIBRARIES "${FFTW3_LIBRARY}")

if(FFTW3_FOUND AND NOT TARGET FFTW3::fftw3)
  add_library(FFTW3::fftw3 UNKNOWN IMPORTED)
  set_target_properties(FFTW3::fftw3 PROPERTIES
    IMPORTED_LOCATION "${FFTW3_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${FFTW3_INCLUDE_DIR}"
  )
endif()

message(STATUS "FFTW3 found: lib='${FFTW3_LIBRARY}', include='${FFTW3_INCLUDE_DIR}'")


#[[


message(STATUS "In FindFFTW.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

if (${CHECK_FFTW_DEVEL})
  message(STATUS "Including check for fftw_devel to indicate have valid fftw")
endif()

message(STATUS "In FindFFTW3.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

set(_FFTW_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_FFTW_PREFIX "${BMAD_EXTERNAL}")
endif()

# Try CONFIG first (may fail if package is incomplete)
set(FFTW3_FOUND FALSE)
#find_package(FFTW3 QUIET CONFIG)
find_package(FFTW3 QUIET)

# If CONFIG mode failed (or is broken), locate manually
if(NOT FFTW3_FOUND)

  find_path(FFTW3_INCLUDE_DIR
    NAMES fftw3.h
    PATH_SUFFIXES include
    HINTS ${_FFTW_PREFIX}
  )

  find_library(FFTW3_LIBRARY
    NAMES fftw3
    PATH_SUFFIXES lib lib64
    HINTS ${_FFTW_PREFIX}
  )

  if(FFTW3_INCLUDE_DIR AND FFTW3_LIBRARY)
    set(FFTW3_FOUND TRUE)
    set(FFTW3_INCLUDE_DIRS "${FFTW3_INCLUDE_DIR}")
    set(FFTW3_LIBRARIES "${FFTW3_LIBRARY}")

    set(fftw_LIBRARIES "${FFTW3_INCLUDE_DIR}")
    set(fftw_INCLUDE_DIRS "${FFTW3_INCLUDE_DIR}")

  endif()
endif()

if(NOT FFTW3_FOUND)
  set(FFTW3_FOUND FALSE)
  set(FFTW3_NOT_FOUND_MESSAGE "FFTW3 not found. Set BMAD_EXTERNAL or CMAKE_PREFIX_PATH to a prefix containing fftw3.")
  message(STATUS "${FFTW3_NOT_FOUND_MESSAGE}")
  return()
endif()

# Provide an imported target (export-safe)
if(NOT TARGET FFTW3::fftw3)
  add_library(FFTW3::fftw3 UNKNOWN IMPORTED)
  set_target_properties(FFTW3::fftw3 PROPERTIES
    IMPORTED_LOCATION "${FFTW3_LIBRARIES}"
    INTERFACE_INCLUDE_DIRECTORIES "${FFTW3_INCLUDE_DIRS}"
  )
endif()

message(STATUS "FFTW3 found: lib='${FFTW3_LIBRARIES}', include='${FFTW3_INCLUDE_DIRS}'")
]]




#[[

# it looks like /usr/include comes for free
find_path(fftw_INCLUDE_DIR NAMES fftw.h fftw3.h ${CMAKE_MODULE_PATH}/include/fftw)
message(STATUS "Looking in ${fftw_SRCDIR} ${CMAKE_MODULE_PATH} for fftw library .a or .so")
#find_library(fftw_LIBRARY ${fftw_SRCDIR} fftw)
#it looks like /usr/lib/ and /usr/lib64 come for free
#find_library(fftw_LIBRARY NAMES libfftw3.so libfftw.so ${fftw_SRCDIR} ${CMAKE_MODULE_PATH}/lib /usr/lib)
find_library(fftw_LIBRARY NAMES fftw3 libfftw.so PATHS ${fftw_SRCDIR} ${CMAKE_MODULE_PATH}/lib)

if(fftw_INCLUDE_DIR)
  message (STATUS "found fftw.h or fftw3.h - in ${fftw_INCLUDE_DIR} - so now have a valid include dir")
endif()
if(fftw_LIBRARY)
  message (STATUS "found fftw.so or fftw3.so or .a - in ${fftw_LIBRARY} - so now have a valid library")
endif()

if(DEFINED fftw_INCLUDE_DIR AND DEFINED fftw_LIBRARY)

# so far so, good, now check if we need to check for fftw3

  if (${CHECK_FFTW_DEVEL})

# it looks like /usr/include comes for free    
#    find_path(fftw3_INCLUDE_DIR fftw3.h ${CMAKE_MODULE_PATH}/include /usr/include)
    find_path(fftw3_INCLUDE_DIR fftw3.h PATHS ${CMAKE_MODULE_PATH}/include)
#find_library(fftw_LIBRARY fftw)
#find_path(fftw_INCLUDE_DIR fftw.h)
#find_library(fftw_LIBRARY fftw)
    message(STATUS "Looking in ${fftw_SRCDIR} ${CMAKE_MODULE_PATH} /usr/local for fftw3 library .a or .so")
#find_library(fftw_LIBRARY ${fftw_SRCDIR} fftw)
# it looks like /usr/lib and /usr/lib64 come for free
#    find_library(fftw3_LIBRARY libfftw3.so ${fftw_SRCDIR} ${CMAKE_MODULE_PATH} /usr/lib)
    find_library(fftw3_LIBRARY libfftw3.so PATHS ${fftw_SRCDIR} ${CMAKE_MODULE_PATH})

    if(fftw3_INCLUDE_DIR)
      message (STATUS "found fftw3.h - so now have a valid include dir")
    endif()
    if(fftw3_LIBRARY)
	message (STATUS "found fftw3.so or .a -  - so now have a valid library")
    endif()

    if(fftw3_INCLUDE_DIR AND fftw3_LIBRARY)
      set(FFTW_FOUND TRUE)
      set(FFTW_FOUND TRUE PARENT_SCOPE)
      message(STATUS "All is good - have fftw and fftw-devel")
    else()
      message(FAILURE "1 Issues - Had FFTW - but could not find fftw-devel - this will be a problem")
    endif()
  else()
    message(STATUS "Had FFTW - user did not ask to check if have fftw-devel - returning success")
    set(FFTW_FOUND TRUE)
    set(FFTW_FOUND TRUE PARENT_SCOPE)
    message(STATUS "All is good - have fftw")
  endif()
else()
  message(FAILURE "Issues - missing FFTW (didn't even check for fftw-devel - trouble ahead")
endif()


if(FFTW_FOUND)
#  set (FFTW_VERSION 0.1) 
  message(STATUS "WE NOW INDICATE A VALUE FFTW package - ${FFTW_FOUND}")
  set(FFTW_LIBRARIES ${fftw_LIBRARY})
  set(FFTW_INCLUDE_DIRS ${fftw_INCLUDE_DIR})
  set(FFTW_LIBRARIES ${fftw_LIBRARY} PARENT_SCOPE)
  set(FFTW_INCLUDE_DIRS ${fftw_INCLUDE_DIR} PARENT_SCOPE)
  set(fftw_LIBRARIES ${fftw_LIBRARY})
  set(fftw_INCLUDE_DIRS ${fftw_INCLUDE_DIR})
  set(fftw_LIBRARIES ${fftw_LIBRARY} PARENT_SCOPE)
  set(fftw_INCLUDE_DIRS ${fftw_INCLUDE_DIR} PARENT_SCOPE)
else()
  message(STATUS "WE NOW INDICATE THAT FFTW Package was not found!")
endif()



]]
