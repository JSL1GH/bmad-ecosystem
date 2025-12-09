cmake_minimum_required(VERSION 3.18)

project(ACC)

set(EXECUTABLE_NAME )

if("${CONDA_BUILD}" STREQUAL "ON")
    set(INC_DIRS
        ${CONDA_BUILD_PATH}/include/
        ${CONDA_BUILD_PATH}/include/xraylib/
    )
else()
    set(INC_DIRS
    )
endif()

include_directories(${BMAD_EXTERNAL} ${INC_DIRS})

enable_language( Fortran )

set(PROGRAM_LIST
    beam_file_translate_format
    controller_response_plot
    ptc_to_bmad
    wake_fit
    wake_plot
    bmad_to_astra
    bmad_to_blender
    bmad_to_csrtrack
    bmad_to_gpt
    bmad_to_scibmad
    bmad_to_mad_sad_elegant
    bmad_to_merlin
    bmad_to_slicktrack
    compare_tracking_methods_plot
    compare_tracking_methods_text
    element_attributes
    generalized_gradient_fit
    lattice_cleaner
    errors_mad_to_bmad
    mais_ripken
    photon_init_plot
    photon_surface_data
    ptc_profiler
    sad_to_bmad_postprocess
    cartesian_map_fit
)

#program_list
# beam_file_translate_format controller_response_plot ptc_to_bmad wake_fit wake_plot bmad_to_astra bmad_to_blender bmad_to_csrtrack bmad_to_gpt bmad_to_scibmad bmad_to_mad_sad_elegant bmad_to_merlin bmad_to_slicktrack compare_tracking_methods_plot compare_tracking_methods_text element_attributes generalized_gradient_fit lattice_cleaner errors_mad_to_bmad mais_ripken photon_init_plot photon_surface_data ptc_profiler sad_to_bmad_postprocess cartesian_map_fit
#message(STATUS "VALUE OF BUILD_TEST IS ${BUILD_TEST}")

if ("${BUILD_TEST}" STREQUAL "ON")
    set(BUILD_TESTS
#        converter_simulation
        converter_fitter
    )
    list(APPEND PROGRAM_LIST ${BUILD_TESTS})
endif ()

#program_list
# converter_simulation converter_fitter


foreach(PROG ${PROGRAM_LIST})
    message(STATUS "Now building ${PROG}")
    add_subdirectory(${PROG})
endforeach()
