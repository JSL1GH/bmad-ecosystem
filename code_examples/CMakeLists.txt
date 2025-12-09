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
    spin_amplitude_dependent_tune
    ptc_layout_example
    construct_taylor_map
    dispersion_simulation
    lapack_examples ## This is broken with lapack version upgrade.
    lattice_geometry_example
    multi_turn_tracking_example
    beam_track_example
    bmad_to_opal_example
    em_field_query_example
    csr_example
    particle_track_example
    simple_bmad_program
    plot_example
    ptc_spin_orbital_normal_form
    spin_matching
)

#program_list
# spin_amplitude_dependent_tune ptc_layout_example construct_taylor_map dispersion_simulation lapack_examples lattice_geometry_example multi_turn_tracking_example beam_track_example bmad_to_opal_example em_field_query_example csr_example particle_track_example simple_bmad_program plot_example ptc_spin_orbital_normal_form spin_matching

# Only build mpi_mp if both ENABLE_OPENMP and ENABLE_MPI are set to "ON"
if("${ENABLE_OPENMP}" STREQUAL "ON" AND "${ENABLE_MPI}" STREQUAL "ON")
    set(MPI_LIST
        mpi_mp
    )
    list(APPEND PROGRAM_LIST ${MPI_LIST})
endif()

foreach(PROG ${PROGRAM_LIST})
    message(STATUS "Now building ${PROG}")
    add_subdirectory(${PROG})
endforeach()
