message(STATUS "In FindFGSL.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

# Use BMAD_EXTERNAL as the external prefix for fgsl/gsl if provided
set(_FGSL_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_FGSL_PREFIX "${BMAD_EXTERNAL}")
endif()

#[[
#find_path(fgsl_INCLUDE_DIR NAMES fgsl.h fgsl.mod ${CMAKE_MODULE_PATH}/include/fgsl)
find_path(fgsl_INCLUDE_DIR NAMES fgsl.h fgsl.mod PATHS ${CMAKE_MODULE_PATH}/include/fgsl)

#message(STATUS "Looking in ${fgsl_SRCDIR} ${CMAKE_MODULE_PATH} for fgsl library .a or .so")
message(STATUS "Looking in ${CMAKE_MODULE_PATH} for fgsl library .a or .so or fgsl.dylib")

#find_library(fgsl_LIBRARY NAMES libfgsl.dylib ${CMAKE_MODULE_PATH}/lib)
find_library(fgsl_LIBRARY NAMES fgsl PATHS ${CMAKE_MODULE_PATH}/lib)
]]

find_path(fgsl_INCLUDE_DIR
  NAMES fgsl.h fgsl.mod
  PATH_SUFFIXES include include/fgsl
  HINTS ${_FGSL_PREFIX}
)

find_library(fgsl_LIBRARY
  NAMES fgsl
  PATH_SUFFIXES lib
  HINTS ${_FGSL_PREFIX}
)

if (APPLE)
#find_library(fgsl_LIBRARY NAMES libfgsl.so libfgsl.dylib ${fgsl_SRCDIR} ${CMAKE_MODULE_PATH}/lib)
else()
#find_library(fgsl_LIBRARY NAMES libfgsl.so libfgsl.dylib ${fgsl_SRCDIR} ${CMAKE_MODULE_PATH}/lib)
endif()

if(fgsl_INCLUDE_DIR)
  message (STATUS "found fgsl.h - so now have a valid include dir")
endif()
message(STATUS "Value of lib is ${fgsl_LIBRARY}")
if(fgsl_LIBRARY)
  message (STATUS "found fgsl.so or .a - so now have a valid library")
endif()

# also, let's check for a valid version of gsl - if not, we fail this!
set(valid_gsl 0)

set(pre_func_name_cap "GSL")
set(pre_func_name "gsl")

# need to account that user may have already installed a version of GSL in their
# own special place - Just like when we look in our outer GlobalVariables.cmake

#message(STATUS "Will look for ${pre_func_name_cap} in ${CMAKE_PREFIX_PATH}")
message(STATUS "Will look for ${pre_func_name_cap} in ${CMAKE_MODULE_PATH}")
#find_package(${pre_func_name_cap} HINTS ${CMAKE_PREFIX_PATH})

find_package(GSL)

  if(${pre_func_name_cap}_FOUND)

    set(STR1 ${${pre_func_name_cap}_VERSION})
    set(STR2 "2.6")

    message(STATUS "Version of ${pre_func_name} found is (library) ${${pre_func_name_cap}_LIBRARY} and (includes) ${${pre_func_name_cap}_INCLUDE_DIR} - VERSION is ${${pre_fu
nc_name_cap}_VERSION}")

#[[    if("${STR1}" VERSION_LESS "${STR2}")
      message(STATUS "Installed version is less than 2.6 - build GSL")
#      set(NEED_TO_BUILD_${pre_func_name_cap} 1)
    else()
      set(valid_gsl 1)
      message(STATUS "We have a valid version of ${pre_func_name} - when checking for FGSL")
      set(GSL_LIBS ${${pre_func_name_cap}_LIBRARY})
#      set(GSL_LIBS ${${pre_func_name_cap}_LIBRARY} PARENT_SCOPE)
      set(gsl_LIBS ${${pre_func_name_cap}_LIBRARY})
#      set(gsl_LIBS ${${pre_func_name_cap}_LIBRARY} PARENT_SCOPE)
      set(GSL_LIBRARIES ${${pre_func_name_cap}_LIBRARY})
#      set(GSL_LIBRARIES ${${pre_func_name_cap}_LIBRARY} PARENT_SCOPE)
      set(gsl_LIBRARIES ${${pre_func_name_cap}_LIBRARY})
#      set(gsl_LIBRARIES ${${pre_func_name_cap}_LIBRARY} PARENT_SCOPE)

#JSL      find_path(gsl_INCLUDE_DIR gsl_blas.h ${gsl_LIBS})
      set(gsl_INCLUDE_DIR "${${pre_func_name_cap}_INCLUDE_DIR}")    
  
      set(GSL_CFLAGS ${gsl_INCLUDE_DIR})
#      set(gsl_CFLAGS ${gsl_INCLUDE_DIR} PARENT_SCOPE)
    endif()
]]
if("${STR1}" VERSION_LESS "${STR2}")
  message(STATUS "Installed version is less than ${STR2} - trying external GSL under ${_FGSL_PREFIX}")

  # Try to locate external GSL explicitly under BMAD_EXTERNAL
  find_library(GSL_LIBRARY NAMES gsl PATH_SUFFIXES lib lib64 HINTS ${_FGSL_PREFIX})
  find_path(GSL_INCLUDE_DIR NAMES gsl/gsl_blas.h gsl_blas.h PATH_SUFFIXES include HINTS ${_FGSL_PREFIX})

  if(GSL_LIBRARY AND GSL_INCLUDE_DIR)
    set(valid_gsl 1)
    set(GSL_LIBRARIES "${GSL_LIBRARY}")
    set(gsl_INCLUDE_DIR "${GSL_INCLUDE_DIR}")

    # Make available to parent scope if you want to keep that behavior
#    set(GSL_LIBRARIES "${GSL_LIBRARIES}" PARENT_SCOPE)
#    set(gsl_INCLUDE_DIR "${gsl_INCLUDE_DIR}" PARENT_SCOPE)

    message(STATUS "Using external GSL: lib='${GSL_LIBRARY}', include='${GSL_INCLUDE_DIR}'")
  else()
    message(STATUS "External GSL not found under ${_FGSL_PREFIX} (need >= ${STR2})")
  endif()

else()
  set(valid_gsl 1)
  message(STATUS "We have a valid system version of ${pre_func_name} (>= ${STR2})")

  set(GSL_LIBRARIES "${${pre_func_name_cap}_LIBRARY}")
#  set(GSL_LIBRARIES "${GSL_LIBRARIES}" PARENT_SCOPE)

  set(gsl_INCLUDE_DIR "${${pre_func_name_cap}_INCLUDE_DIR}")
#  set(gsl_INCLUDE_DIR "${gsl_INCLUDE_DIR}" PARENT_SCOPE)
endif()

  else()
    message(STATUS "No version of GSL found!")
  endif()

#set(FGSL_FOUND "FALSE")
  
#if(DEFINED fgsl_INCLUDE_DIR AND DEFINED fgsl_LIBRARY AND valid_gsl)
set(FGSL_FOUND FALSE)

message(STATUS "FGSL debug: BMAD_EXTERNAL='${BMAD_EXTERNAL}', _FGSL_PREFIX='${_FGSL_PREFIX}'")
message(STATUS "FGSL debug: fgsl_INCLUDE_DIR='${fgsl_INCLUDE_DIR}'")
message(STATUS "FGSL debug: fgsl_LIBRARY='${fgsl_LIBRARY}'")
message(STATUS "FGSL debug: valid_gsl='${valid_gsl}'")
message(STATUS "FGSL debug: GSL_LIBRARY='${GSL_LIBRARY}'")
message(STATUS "FGSL debug: GSL_INCLUDE_DIR='${GSL_INCLUDE_DIR}'")
message(STATUS "FGSL debug: GSL_VERSION='${GSL_VERSION}'")

if(fgsl_INCLUDE_DIR AND fgsl_LIBRARY AND valid_gsl)

  set(FGSL_FOUND TRUE)
#  set(FGSL_FOUND TRUE PARENT_SCOPE)
  message(STATUS "All is good for having gsl/fgsl packages - continuing")
else()
  message(STATUS "Issues - missing something for fgsl/gsl packages - could be trouble ahead - but also could be we have not yet built gsl and/or fgsl - ${GSL_LIBS}")
endif()

#if(${FGSL_FOUND})
if(FGSL_FOUND)
  set(fgsl_LIBRARIES ${fgsl_LIBRARY})
  set(fgsl_INCLUDE_DIRS ${fgsl_INCLUDE_DIR})
#  set(fgsl_LIBRARIES ${fgsl_LIBRARY} PARENT_SCOPE)
#  set(fgsl_INCLUDE_DIRS ${fgsl_INCLUDE_DIR} PARENT_SCOPE)
  message(STATUS "IN FindFGSL.cmake - value of FGSL_FOUND IS ${FGSL_FOUND} - using values of ${fgsl_LIBRARY} and ${fgsl_INCLUDE_DIR}")

# -----------------------------
# Provide imported targets
# -----------------------------
if(FGSL_FOUND AND NOT TARGET FGSL::fgsl)
  add_library(FGSL::fgsl UNKNOWN IMPORTED)
  set_target_properties(FGSL::fgsl PROPERTIES
    IMPORTED_LOCATION "${fgsl_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${fgsl_INCLUDE_DIR}"
  )

  # If GSL variables were discovered, also provide an imported target for GSL
  # (Many FindGSL.cmake modules do not define GSL::gsl)
  if(DEFINED GSL_LIBRARIES AND NOT TARGET GSL::gsl)
    add_library(GSL::gsl UNKNOWN IMPORTED)
    # If GSL_LIBRARIES is a list, take the first element as the primary library
    set(_gsl_lib "${GSL_LIBRARIES}")
    if(_gsl_lib)
      # If it is a CMake list, use first item
      list(GET _gsl_lib 0 _gsl_lib0)
      set(_gsl_lib "${_gsl_lib0}")
    endif()

    set_target_properties(GSL::gsl PROPERTIES
      IMPORTED_LOCATION "${_gsl_lib}"
      INTERFACE_INCLUDE_DIRECTORIES "${${pre_func_name_cap}_INCLUDE_DIR}"
    )
  endif()

  # Make FGSL transitively depend on GSL if available
  if(TARGET GSL::gsl)
    target_link_libraries(FGSL::fgsl INTERFACE GSL::gsl)
  endif()
endif()


endif()

