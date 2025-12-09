cmake_minimum_required(VERSION 3.18)

project(ACC)

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
    abs_time_test
    analysis_test
    aperture_test
    autoscale_test
    backwards_time_track_test
    beam_test
    bend_test
    bbu_test
    cesr_test
    closed_orbit_test
    coord_test
    csr_and_space_charge_test
    bookkeeper_test
    cathode_sc_test
    em_field_test
    field_test
    fixer_test
    fringe_test
    geometry_test
    girder_test
    hdf5_test
    mad_to_bmad_test
    mat6_calc_method_test
    match_test
    mode_flip_test
    mode3_test
    multipass_test
    multipole_test
    nonlin_test
    object_test
    parse_test
    particle_species_test
    patch_test
    photon_test
    ptc_test
    radiation_test
    reverse_test
    rf_test
    sad_test
    sim_utils_test
    slice_test
    space_charge_test
    spin_map_test
    spin_general_test
    superimpose_test
    synrad3d_test
    taylor_test
    time_runge_kutta_test
    tracking_method_test
    twiss_test
    wake_test
    wall3d_test
    write_bmad_test
    write_foreign_test
    xraylib_test
)

#program_list
# abs_time_test analysis_test aperture_test autoscale_test backwards_time_track_test beam_test bend_test bbu_test cesr_test closed_orbit_test coord_test csr_and_space_charge_test bookkeeper_test cathode_sc_test em_field_test field_test fixer_test fringe_test geometry_test girder_test hdf5_test mad_to_bmad_test mat6_calc_method_test match_test mode_flip_test mode3_test multipass_test multipole_test nonlin_test object_test parse_test particle_species_test patch_test photon_test ptc_test radiation_test reverse_test rf_test sad_test sim_utils_test slice_test space_charge_test spin_map_test spin_general_test superimpose_test synrad3d_test taylor_test time_runge_kutta_test tracking_method_test twiss_test wake_test wall3d_test write_bmad_test write_foreign_test xraylib_test

foreach(PROG ${PROGRAM_LIST})
    message(STATUS "Now building ${PROG}")
    add_subdirectory(${PROG})
endforeach()
