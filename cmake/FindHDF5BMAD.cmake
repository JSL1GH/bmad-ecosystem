#Create bmad-ecosystem/cmake/FindHDF5BMAD.cmake with this (Linux + macOS, external-first, no Homebrew hijack)

message(STATUS "In FindHDF5BMAD.cmake - checking package ${CMAKE_FIND_PACKAGE_NAME}")

set(_HDF5_PREFIX "")
if(DEFINED BMAD_EXTERNAL AND NOT BMAD_EXTERNAL STREQUAL "")
  set(_HDF5_PREFIX "${BMAD_EXTERNAL}")
endif()

# We will provide this target:
#   HDF5BMAD::HL_Fortran
#
# Policy:
#   1) If BMAD_EXTERNAL is set and contains HDF5 libs, use those.
#   2) Otherwise, fall back to system HDF5.

# -----------------------------
# 1) Prefer BMAD_EXTERNAL
# -----------------------------
set(_use_external FALSE)
if(_HDF5_PREFIX)
  if(EXISTS "${_HDF5_PREFIX}/lib/libhdf5_fortran.so" OR
     EXISTS "${_HDF5_PREFIX}/lib/libhdf5_fortran.dylib" OR
     EXISTS "${_HDF5_PREFIX}/lib/libhdf5_fortran.a" OR
     EXISTS "${_HDF5_PREFIX}/lib64/libhdf5_fortran.so")
    set(_use_external TRUE)
  endif()
endif()

if(_use_external)
  message(STATUS "HDF5BMAD: using external HDF5 under BMAD_EXTERNAL='${_HDF5_PREFIX}'")

  # Determine libdir + suffix
  set(_libdir "${_HDF5_PREFIX}/lib")
  if(EXISTS "${_HDF5_PREFIX}/lib64")
    # Prefer lib if it contains hdf5_fortran; else use lib64
    if(NOT EXISTS "${_HDF5_PREFIX}/lib/libhdf5_fortran.so" AND
       NOT EXISTS "${_HDF5_PREFIX}/lib/libhdf5_fortran.dylib" AND
       NOT EXISTS "${_HDF5_PREFIX}/lib/libhdf5_fortran.a")
      set(_libdir "${_HDF5_PREFIX}/lib64")
    endif()
  endif()

  if(APPLE)
    set(_suf "dylib")
  else()
    set(_suf "so")
  endif()

  # Helper to pick .a if .so/.dylib isn't there
  function(_hdf5_pick out name)
    set(_p1 "${_libdir}/lib${name}.${_suf}")
    set(_p2 "${_libdir}/lib${name}.a")
    if(EXISTS "${_p1}")
      set(${out} "${_p1}" PARENT_SCOPE)
    elseif(EXISTS "${_p2}")
      set(${out} "${_p2}" PARENT_SCOPE)
    else()
      set(${out} "" PARENT_SCOPE)
    endif()
  endfunction()

  _hdf5_pick(_HDF5_C          hdf5)
  _hdf5_pick(_HDF5_HL         hdf5_hl)
  _hdf5_pick(_HDF5_Fortran    hdf5_fortran)
  _hdf5_pick(_HDF5_HL_Fortran hdf5_hl_fortran)
  _hdf5_pick(_HDF5_F90CStub   hdf5_hl_f90cstub)

  if(NOT _HDF5_C OR NOT _HDF5_HL OR NOT _HDF5_Fortran OR NOT _HDF5_HL_Fortran OR NOT _HDF5_F90CStub)
    message(FATAL_ERROR
      "HDF5BMAD: External HDF5 under '${_HDF5_PREFIX}' is missing one or more required libs:\n"
      "  hdf5='${_HDF5_C}'\n"
      "  hdf5_hl='${_HDF5_HL}'\n"
      "  hdf5_fortran='${_HDF5_Fortran}'\n"
      "  hdf5_hl_fortran='${_HDF5_HL_Fortran}'\n"
      "  hdf5_hl_f90cstub='${_HDF5_F90CStub}'\n"
    )
  endif()

  # Import targets (internal to this Find module)
  add_library(HDF5BMAD::C UNKNOWN IMPORTED)
  set_target_properties(HDF5BMAD::C PROPERTIES
    IMPORTED_LOCATION "${_HDF5_C}"
    INTERFACE_INCLUDE_DIRECTORIES "${_HDF5_PREFIX}/include"
  )

  add_library(HDF5BMAD::HL UNKNOWN IMPORTED)
  set_target_properties(HDF5BMAD::HL PROPERTIES
    IMPORTED_LOCATION "${_HDF5_HL}"
    INTERFACE_INCLUDE_DIRECTORIES "${_HDF5_PREFIX}/include"
  )
  target_link_libraries(HDF5BMAD::HL INTERFACE HDF5BMAD::C)

  add_library(HDF5BMAD::Fortran UNKNOWN IMPORTED)
  set_target_properties(HDF5BMAD::Fortran PROPERTIES
    IMPORTED_LOCATION "${_HDF5_Fortran}"
    INTERFACE_INCLUDE_DIRECTORIES "${_HDF5_PREFIX}/include"
  )
  target_link_libraries(HDF5BMAD::Fortran INTERFACE HDF5BMAD::C)

  add_library(HDF5BMAD::HL_F90CStub UNKNOWN IMPORTED)
  set_target_properties(HDF5BMAD::HL_F90CStub PROPERTIES
    IMPORTED_LOCATION "${_HDF5_F90CStub}"
    INTERFACE_INCLUDE_DIRECTORIES "${_HDF5_PREFIX}/include"
  )
  target_link_libraries(HDF5BMAD::HL_F90CStub INTERFACE HDF5BMAD::HL)

  add_library(HDF5BMAD::HL_Fortran UNKNOWN IMPORTED)
  set_target_properties(HDF5BMAD::HL_Fortran PROPERTIES
    IMPORTED_LOCATION "${_HDF5_HL_Fortran}"
    INTERFACE_INCLUDE_DIRECTORIES "${_HDF5_PREFIX}/include"
  )
  target_link_libraries(HDF5BMAD::HL_Fortran INTERFACE
    HDF5BMAD::HL_F90CStub
    HDF5BMAD::Fortran
  )

  set(HDF5BMAD_FOUND TRUE)

else()
  # -----------------------------
  # 2) Fall back to system HDF5
  # -----------------------------
  message(STATUS "HDF5BMAD: using system HDF5 (BMAD_EXTERNAL not set or no external HDF5 found)")
  find_package(HDF5 REQUIRED COMPONENTS Fortran HL)

  # Create our stable facade target and attach whatever HDF5 provided.
  # Different distros expose different targets/variables, so we handle both.
  if(NOT TARGET HDF5BMAD::HL_Fortran)
    add_library(HDF5BMAD::HL_Fortran INTERFACE IMPORTED)
  endif()

  # Prefer official targets if they exist
  if(TARGET hdf5::hdf5_fortran AND TARGET hdf5::hdf5_hl_fortran)
    target_link_libraries(HDF5BMAD::HL_Fortran INTERFACE hdf5::hdf5_hl_fortran hdf5::hdf5_fortran)
  elseif(TARGET HDF5::Fortran AND TARGET HDF5::HL_Fortran)
    target_link_libraries(HDF5BMAD::HL_Fortran INTERFACE HDF5::HL_Fortran HDF5::Fortran)
  else()
    # Fallback to variables (module mode often sets these)
    target_include_directories(HDF5BMAD::HL_Fortran INTERFACE ${HDF5_INCLUDE_DIRS})
    target_link_libraries(HDF5BMAD::HL_Fortran INTERFACE ${HDF5_LIBRARIES})
  endif()

  set(HDF5BMAD_FOUND TRUE)
endif()
