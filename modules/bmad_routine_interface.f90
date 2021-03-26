!+
! This file defines the interfaces for the BMAD subroutines
!-

module bmad_routine_interface

use bmad_struct

interface

function absolute_time_tracking (ele) result (is_abs_time)
  import
  implicit none
  type (ele_struct), target :: ele
  logical is_abs_time
end function

function ac_kicker_amp(ele, orbit) result (ac_amp)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct) orbit
  real(rp) ac_amp
end function

subroutine add_lattice_control_structs (ele, n_add_slave, n_add_lord, n_add_slave_field, n_add_lord_field, add_at_end)
  import
  implicit none
  type (ele_struct) ele
  integer, optional :: n_add_slave, n_add_lord, n_add_slave_field, n_add_lord_field
  logical, optional :: add_at_end
end subroutine

subroutine allocate_branch_array (lat, upper_bound)
  import
  implicit none
  type (lat_struct), target :: lat
  integer :: upper_bound
end subroutine

subroutine allocate_element_array (ele, upper_bound)
  import
  implicit none
  type (ele_struct), pointer :: ele(:)
  integer, optional :: upper_bound
end subroutine

subroutine allocate_lat_ele_array (lat, upper_bound, ix_branch)
  import
  implicit none
  type (lat_struct), target :: lat
  integer, optional :: upper_bound
  integer, optional :: ix_branch
end subroutine

subroutine aml_parser (lat_file, lat, make_mats6, digested_read_ok, use_line, err_flag)
  import
  implicit none
  character(*) lat_file
  type (lat_struct), target :: lat
  logical, optional :: make_mats6
  logical, optional :: digested_read_ok, err_flag
  character(*), optional :: use_line
end subroutine

function angle_between_polars (polar1, polar2) result (angle)
  import
  implicit none
  type (spin_polar_struct), intent(in) :: polar1, polar2
  real(rp) :: angle
end function

subroutine angle_to_canonical_coords (orbit)
  import
  implicit none
  type (coord_struct) orbit
end subroutine

subroutine apply_all_rampers (lat, err_flag)
  import
  implicit none
  type (lat_struct) lat
  logical err_flag
end subroutine

subroutine apply_element_edge_kick (orb, fringe_info, track_ele, param, track_spin, mat6, make_matrix, rf_time, apply_sol_fringe)
  import
  implicit none
  type (coord_struct) orb
  type (fringe_field_info_struct) fringe_info
  type (ele_struct) hard_ele, track_ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6), rf_time
  logical, optional :: make_matrix, apply_sol_fringe
  logical track_spin
end subroutine

subroutine apply_energy_kick (dE, orbit, ddE_dr, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  real(rp) dE, ddE_dr(2)
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine apply_ramper (slave, ramper, err_flag)
  import
  implicit none
  type (ele_struct) :: slave
  type (ele_pointer_struct) ramper(:)
  logical err_flag
end subroutine

function at_this_ele_end (now_at, where_at) result (is_at_this_end)
  import
  implicit none
  integer now_at, where_at
  logical is_at_this_end
end function

subroutine attribute_bookkeeper (ele, force_bookkeeping)
  import
  implicit none
  type (ele_struct), target :: ele
  logical, optional :: force_bookkeeping
end subroutine

subroutine attribute_set_bookkeeping (ele, attrib_name, err_flag, attrib_ptr)
  import
  implicit none
  type (ele_struct) ele
  type (all_pointer_struct), optional :: attrib_ptr
  character(*) attrib_name
  logical err_flag
end subroutine

function average_twiss (frac1, twiss1, twiss2) result (ave_twiss)
  import
  implicit none
  type (twiss_struct) twiss1, twiss2, ave_twiss
  real(rp) frac1
end function

subroutine bbi_kick (x, y, r, kx, ky)
  import
  implicit none
  real(rp) x, y, r, kx, ky
end subroutine

subroutine bbi_slice_calc (ele, n_slice, z_slice)
  import
  implicit none
  type (ele_struct) ele
  integer :: n_slice
  real(rp) z_slice(:)
end subroutine

subroutine bend_exact_multipole_field (ele, param, orbit, local_ref_frame, field, calc_dfield, calc_potential)
  import
  implicit none
  type (ele_struct), target :: ele
  type (lat_param_struct) param
  type (coord_struct) orbit
  type (em_field_struct) field
  logical local_ref_frame
  logical, optional :: calc_dfield, calc_potential
end subroutine

function bend_shift (position1, g, delta_s, w_mat, ref_tilt) result(position2)
  import
  implicit none
  type (floor_position_struct) :: position1, position2
  real(rp) :: g, delta_s, S_mat(3,3), L_vec(3), tlt, angle
  real(rp), optional :: w_mat(3,3), ref_tilt
end function bend_shift

subroutine bmad_and_xsif_parser (lat_file, lat, make_mats6, digested_read_ok, use_line, err_flag)
  import
  implicit none
  character(*) lat_file
  type (lat_struct), target :: lat
  logical, optional :: make_mats6
  logical, optional :: digested_read_ok, err_flag
  character(*), optional :: use_line
end subroutine

subroutine bmad_parser (lat_file, lat, make_mats6, digested_read_ok, use_line, err_flag)
  import
  implicit none
  character(*) lat_file
  type (lat_struct), target :: lat
  logical, optional :: make_mats6
  logical, optional :: digested_read_ok, err_flag
  character(*), optional :: use_line
end subroutine

subroutine bmad_parser2 (in_file, lat, orbit, make_mats6, err_flag, in_lat)
  import
  implicit none
  character(*) in_file
  type (lat_struct), target :: lat
  type (lat_struct), optional :: in_lat
  type (coord_struct), optional :: orbit(0:)
  logical, optional :: make_mats6, err_flag
end subroutine

function branch_name(branch) result (name)
  import
  implicit none
  type (branch_struct), target :: branch
  character(40) name
end function

function c_multi (n, m, no_n_fact, c_full) result (c_out)
  import
  implicit none
  integer, intent(in) :: n, m
  real(rp) c_out
  real(rp), optional :: c_full(0:n_pole_maxx, 0:n_pole_maxx)
  logical, optional :: no_n_fact
end function

subroutine c_to_cbar (ele, cbar_mat)
  import
  implicit none
  type (ele_struct) ele
  real(rp) cbar_mat(2,2)
end subroutine

subroutine calc_next_fringe_edge (track_ele, s_edge_body, fringe_info, orbit, init_needed, time_tracking)
  import
  type (ele_struct), target :: track_ele
  type (fringe_field_info_struct) fringe_info
  type (coord_struct) :: orbit
  real(rp) s_edge_body
  logical, optional :: init_needed, time_tracking
end subroutine

subroutine calc_super_slave_key (lord1, lord2, slave, create_jumbo_slave)
  import
  implicit none
  type (ele_struct), target :: lord1, lord2, slave
  logical, optional :: create_jumbo_slave
end subroutine

subroutine calc_z_tune (lat, ix_branch)
  import
  implicit none
  type (lat_struct) lat
  integer, optional :: ix_branch
end subroutine

subroutine canonical_to_angle_coords (orbit)
  import
  implicit none
  type (coord_struct) orbit
end subroutine

subroutine cbar_to_c (cbar_mat, a, b, c_mat)
  import
  implicit none
  real(rp) cbar_mat(2,2), c_mat(2,2)
  type (twiss_struct) a, b
end subroutine

recursive subroutine check_aperture_limit (orb, ele, particle_at, param, old_orb, check_momentum)
  import
  implicit none
  type (coord_struct) :: orb
  type (ele_struct) :: ele
  type (lat_param_struct), intent(inout) :: param
  integer particle_at
  type (coord_struct), optional :: old_orb
  logical, optional :: check_momentum
end subroutine

function classical_radius (species) result (radius)
  import
  integer species
  real(rp) radius
end function

function congruent_lattice_elements (ele1, ele2) result (is_congruent)
  import
  implicit none
  type (ele_struct) ele1, ele2
  logical is_congruent
end function

function coords_relative_to_floor (floor0, dr, theta, phi, psi) result (floor1)
  import
  implicit none
  type (floor_position_struct) floor0, floor1
  real(rp) dr(3)
  real(rp), optional :: theta, phi, psi
end function coords_relative_to_floor

function coords_floor_to_relative (floor0, global_position, calculate_angles, is_delta_position) result (local_position)
  import
  implicit none
  type (floor_position_struct) floor0, global_position, local_position
  logical, optional :: calculate_angles, is_delta_position
end function coords_floor_to_relative

function coords_floor_to_local_curvilinear (global_position, ele, status, w_mat, use_patch_entrance) result(local_position)
  import
  implicit none
  type (floor_position_struct) :: global_position, local_position
  type (ele_struct)   :: ele
  real(rp), optional :: w_mat(3,3)
  integer :: status
  logical, optional :: use_patch_entrance
end function coords_floor_to_local_curvilinear

function coords_floor_to_curvilinear (floor_coords, ele0, ele1, status, w_mat) result (local_coords)
  import
  implicit none
  type (floor_position_struct) floor_coords, local_coords
  type (ele_struct), target :: ele0
  type (ele_struct), pointer :: ele1
  integer status
  real(rp), optional :: w_mat(3,3)
end function coords_floor_to_curvilinear

function coords_local_curvilinear_to_floor (local_position, ele, in_ele_frame, &
                                        w_mat, calculate_angles, use_patch_entrance) result (global_position)
  import
  implicit none
  type (floor_position_struct) :: local_position, global_position, p, floor0
  type (ele_struct), target :: ele
  type (ele_struct), pointer :: ele1
  real(rp) :: w_mat_local(3,3), L_vec(3), S_mat(3,3), z
  real(rp), optional :: w_mat(3,3)
  logical, optional :: in_ele_frame
  logical, optional :: calculate_angles
  logical, optional :: use_patch_entrance
end function coords_local_curvilinear_to_floor

function coords_element_frame_to_local (body_position, ele, w_mat, calculate_angles) result(local_position)
  import
  implicit none
  type (floor_position_struct) :: body_position, local_position
  type (ele_struct) :: ele
  real(rp), optional :: w_mat(3,3)
  logical, optional :: calculate_angles
end function coords_element_frame_to_local

function coords_curvilinear_to_floor (xys, branch, err_flag) result (global)
  import
  implicit none
  type (branch_struct), target :: branch
  type (floor_position_struct) global, local
  real(rp) xys(3)
  logical err_flag
end function coords_curvilinear_to_floor

subroutine check_controller_controls (ele_key, contrl, name, err)
  import
  implicit none
  type (control_struct), target :: contrl(:)
  integer ele_key
  logical err
  character(*) name
end subroutine

subroutine check_if_s_in_bounds (branch, s, err_flag, translated_s)
  import
  implicit none
  type (branch_struct) branch
  real(rp) s
  real(rp), optional :: translated_s
  logical err_flag
end subroutine

subroutine choose_quads_for_set_tune (lat, dk1, regex_mask)
  import
  implicit none
  type (lat_struct) lat
  character(40), optional :: regex_mask
  real(rp), allocatable, intent(inout) :: dk1(:)
end subroutine

subroutine chrom_calc (lat, delta_e, chrom_x, chrom_y, err_flag, &
                       pz, low_E_lat, high_E_lat, low_E_orb, high_E_orb, ix_branch)
  import
  implicit none
  type (lat_struct) lat
  type (lat_struct), optional, target :: low_E_lat, high_E_lat
  type (coord_struct), allocatable, optional, target :: low_E_orb(:), high_E_orb(:)
  real(rp) delta_e
  real(rp) chrom_x
  real(rp) chrom_y
  real(rp), optional :: pz
  logical, optional, intent(out) :: err_flag
  integer, optional :: ix_branch
end subroutine

subroutine chrom_tune (lat, delta_e, chrom_x, chrom_y, err_tol, err_flag)
  import
  implicit none
  type (lat_struct) lat
  real(rp) delta_e
  real(rp) chrom_x
  real(rp) chrom_y
  real(rp) err_tol
  logical err_flag
end subroutine

subroutine clear_lat_1turn_mats (lat)
  import
  implicit none
  type (lat_struct) lat
end subroutine

subroutine closed_orbit_calc (lat, closed_orb, i_dim, direction, ix_branch, err_flag, print_err)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct), allocatable, target :: closed_orb(:)
  integer, optional :: direction, ix_branch, i_dim
  logical, optional, intent(out) :: err_flag
  logical, optional, intent(in) :: print_err
end subroutine

subroutine closed_orbit_from_tracking (lat, closed_orb, i_dim, eps_rel, eps_abs, init_guess, err_flag)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct), allocatable :: closed_orb(:)
  type (coord_struct), optional :: init_guess
  real(rp), intent(in), optional :: eps_rel(:), eps_abs(:)
  integer i_dim
  logical, optional :: err_flag
end subroutine

subroutine combine_consecutive_elements (lat)
  import
  implicit none
  type (lat_struct), target :: lat
end subroutine

subroutine control_bookkeeper (lat, ele, err_flag)
  import
  implicit none
  type (lat_struct), target :: lat
  type (ele_struct), optional :: ele
  logical, optional :: err_flag
end subroutine

subroutine convert_particle_coordinates_s_to_t (particle, s_body, orientation, dt)
  import
  implicit none
  type (coord_struct), intent(inout), target :: particle
  real(rp) s_body
  real(rp), optional :: dt
  integer :: orientation
end subroutine

subroutine convert_particle_coordinates_t_to_s (particle, dt, ele, s_body)
  import
  implicit none
  type (coord_struct), intent(inout), target :: particle
  type (ele_struct) ele
  real(rp) :: dt
  real(rp), optional :: s_body
end subroutine

subroutine convert_total_energy_to (E_tot, particle, gamma, kinetic, beta, pc, brho, beta1, err_flag)
  import
  implicit none
  real(rp), intent(in) :: E_tot
  real(rp), intent(out), optional :: pc, kinetic, beta, brho, gamma, beta1
  integer, intent(in) :: particle
  logical, optional :: err_flag
end subroutine

subroutine convert_pc_to (pc, particle, E_tot, gamma, kinetic, beta, brho, beta1, err_flag)
  import
  implicit none
  real(rp), intent(in) :: pc
  real(rp), intent(out), optional :: E_tot, kinetic, beta, brho, gamma, beta1
  integer, intent(in) :: particle
  logical, optional :: err_flag
end subroutine

subroutine convert_bend_exact_multipole (g, out_type, an, bn)
  import
  implicit none
  real(rp) g, an(0:n_pole_maxx), bn(0:n_pole_maxx)
  integer out_type
end subroutine

recursive subroutine create_element_slice (sliced_ele, ele_in, l_slice, offset, &
                             param, include_upstream_end, include_downstream_end, err_flag, old_slice)
  import
  implicit none
  type (ele_struct), target :: sliced_ele, ele_in
  type (ele_struct), optional :: old_slice
  type (lat_param_struct) param
  real(rp) l_slice, offset
  logical include_upstream_end, include_downstream_end, err_flag
end subroutine

subroutine create_field_overlap (lat, lord_name, slave_name, err_flag)
  import
  implicit none
  type (lat_struct) lat
  character(*) lord_name, slave_name
  logical err_flag
end subroutine

subroutine create_wiggler_cartesian_map (ele, cart_map)
  import
  implicit none
  type (ele_struct) ele
  type (cartesian_map_struct), target :: cart_map
end subroutine

subroutine create_girder (lat, ix_ele, con, init_ele, err_flag)
  import
  implicit none
  type (lat_struct) lat
  type (ele_struct) :: init_ele
  type (control_struct) con(:)
  integer, intent(in) :: ix_ele
  logical err_flag
end subroutine

subroutine create_group (lord, con, err)
  import
  implicit none
  type (ele_struct) lord
  type (control_struct) con(:)
  logical err
end subroutine

subroutine create_lat_ele_nametable (lat, nametable)
  import
  implicit none
  type (lat_struct), target :: lat
  type (nametable_struct) nametable
end subroutine

subroutine create_overlay (lord, contl, err)
  import
  implicit none
  type (ele_struct) lord
  type (control_struct) contl(:)
  logical err
end subroutine

subroutine create_ramper (lord, contl, err)
  import
  implicit none
  type (ele_struct) lord
  type (control_struct) contl(:)
  logical err
end subroutine

subroutine create_uniform_element_slice (ele, param, i_slice, n_slice_tot, sliced_ele, s_start, s_end)
  import
  implicit none
  type (ele_struct) ele, sliced_ele
  type (lat_param_struct) param
  integer i_slice, n_slice_tot
  real(rp), optional :: s_start, s_end
end subroutine

subroutine create_unique_ele_names (lat, key, suffix)
  import
  implicit none
  type (lat_struct), target :: lat
  integer key
  character(*) suffix
end subroutine

subroutine crystal_attribute_bookkeeper (ele)
  import
  implicit none
  type (ele_struct) ele
end subroutine

subroutine convert_coords (in_type_str, coord_in, ele, out_type_str, coord_out, err_flag)
  import
  implicit none
  character(*) in_type_str
  character(*) out_type_str
  type (coord_struct) coord_in
  type (coord_struct) coord_out
  type (ele_struct) ele
  logical, optional :: err_flag
end subroutine

subroutine deallocate_ele_array_pointers (eles)
  import
  implicit none
  type (ele_struct), pointer :: eles(:)
end subroutine

subroutine deallocate_ele_pointers (ele, nullify_only, nullify_branch, dealloc_poles)
  import
  implicit none
  type (ele_struct), target :: ele
  logical, optional, intent(in) :: nullify_only, nullify_branch, dealloc_poles
end subroutine

subroutine deallocate_lat_pointers (lat)
  import
  implicit none
  type (lat_struct) lat
end subroutine

function default_tracking_species (param) result (species)
  import
  implicit none
  type (lat_param_struct) param
  integer species
end function

function diffraction_plate_or_mask_hit_spot (ele, orbit) result (ix_section)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) orbit
  integer :: ix_section
end function

recursive function distance_to_aperture (orbit, particle_at, ele, no_aperture_here) result (dist)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  real(rp) dist
  integer particle_at
  logical no_aperture_here
end function

subroutine do_mode_flip (ele, err_flag)
  import
  implicit none
  type (ele_struct) ele
  logical, optional :: err_flag
end subroutine

function e_accel_field (ele, voltage_or_gradient) result (field)
  import
  implicit none
  type (ele_struct) ele
  real(rp) field
  integer voltage_or_gradient 
end function

recursive subroutine ele_compute_ref_energy_and_time (ele0, ele, param, err_flag)
  import
  implicit none
  type (ele_struct) ele0, ele
  type (lat_param_struct) param
  real(rp) e_tot_start, p0c_start, ref_time_start
  logical err_flag
end subroutine

recursive subroutine ele_geometry (floor_start, ele, floor_end, len_scale, ignore_patch_err)
  import
  implicit none
  type (ele_struct), target :: ele
  type (floor_position_struct), optional, target :: floor_end
  type (floor_position_struct) :: floor_start
  real(rp), optional :: len_scale
  logical, optional :: ignore_patch_err
end subroutine ele_geometry

function ele_geometry_with_misalignments (ele, len_scale) result (floor)
  import
  implicit none
  type (ele_struct), target :: ele
  type (floor_position_struct) floor
  real(rp), optional :: len_scale
end function ele_geometry_with_misalignments

function ele_has_constant_ds_dt_ref (ele) result (is_const)
  import
  implicit none
  type (ele_struct) ele
  logical is_const
end function

function ele_has_nonzero_kick (ele) result (has_kick)
  import
  implicit none
  type (ele_struct) ele
  logical has_kick
end function

function ele_has_offset (ele) result (has_offset)
  import
  implicit none
  type (ele_struct) ele
  logical has_offset
end function

function ele_loc_name (ele, show_branch0, parens) result (str)
  import
  implicit none
  type (ele_struct) ele
  logical, optional :: show_branch0
  character(2), optional :: parens
  character(10) str
end function

subroutine ele_misalignment_L_S_calc (ele, L_mis, S_mis)
  import
  implicit none
  type(ele_struct) :: ele 
  real(rp) :: L_mis(3), S_mis(3,3)
end subroutine ele_misalignment_L_S_calc

function ele_loc (ele) result (loc)
  import
  implicit none
  type (ele_struct) ele
  type (lat_ele_loc_struct) loc
end function

function ele_nametable_index(ele) result(ix_nt)
  import
  implicit none
  type (ele_struct), target :: ele
  integer ix_nt
end function

function ele_unique_name (ele, order) result (unique_name)
  import
  implicit none
  type (ele_struct) ele
  type (lat_ele_order_struct) order
  character(40) unique_name
end function ele_unique_name

subroutine ele_order_calc (lat, order)
  import
  implicit none
  type (lat_struct) lat
  type (lat_ele_order_struct) order
end subroutine

function ele_value_has_changed (ele, list, abs_tol, set_old) result (has_changed)
  import
  implicit none
  type (ele_struct) ele
  integer list(:)
  real(rp) abs_tol(:)
  logical set_old, has_changed
end function

function equivalent_taylor_attributes (ele_taylor, ele2) result (equiv)
  import
  implicit none
  type (ele_struct) :: ele_taylor, ele2
  logical equiv
end function

subroutine fibre_to_ele (ptc_fibre, branch, ix_ele, err_flag, from_mad)
  import
  implicit none
  type (fibre) ptc_fibre
  type (branch_struct) branch
  integer ix_ele
  logical err_flag
  logical, optional :: from_mad
end subroutine

subroutine find_element_ends (ele, ele1, ele2, ix_multipass)
  import
  implicit none
  type (ele_struct) ele
  type (ele_struct), pointer :: ele1, ele2
  integer, optional :: ix_multipass
end subroutine

subroutine find_matching_fieldmap (file_name, ele, t_type, match_ele, ix_field, ignore_slaves)
  import
  implicit none
  type (ele_struct), target :: ele
  type (ele_struct), pointer :: match_ele
  integer t_type, ix_field
  logical, optional :: ignore_slaves
  character(*) file_name
end subroutine

subroutine floor_angles_to_w_mat (theta, phi, psi, w_mat, w_mat_inv)
  import
  implicit none
  real(rp), optional :: w_mat(3,3), w_mat_inv(3,3)
  real(rp) theta, phi, psi
end subroutine floor_angles_to_w_mat

subroutine floor_w_mat_to_angles (w_mat, theta, phi, psi, floor0)
  import
  implicit none
  type (floor_position_struct), optional :: floor0
  real(rp) theta, phi, psi, w_mat(3,3)
end subroutine floor_w_mat_to_angles

subroutine g_bending_strength_from_em_field (ele, param, s_rel, orbit, local_ref_frame, g, dg)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
  type (coord_struct) orbit
  real(rp), intent(in) :: s_rel
  real(rp), intent(out) :: g(3)
  real(rp), optional :: dg(3,3)
  logical local_ref_frame
end subroutine

subroutine get_slave_list (lord, slaves, n_slave)
  import
  implicit none
  type (ele_struct) :: lord
  type (ele_pointer_struct), allocatable :: slaves(:)
  integer n_slave
end subroutine

function gradient_shift_sr_wake (ele, param) result (grad_shift)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp) grad_shift
end function

subroutine hdf5_read_beam (file_name, beam, error, ele, pmd_header)
  import
  implicit none
  type (beam_struct), target :: beam
  type (ele_struct), optional :: ele
  type (pmd_header_struct), optional :: pmd_header
  logical error
  character(*) file_name
end subroutine

subroutine hdf5_read_grid_field (file_name, ele, g_field, err_flag, pmd_header, combine)
  import
  implicit none
  type (grid_field_struct), pointer :: g_field(:)
  type (ele_struct) ele
  type (pmd_header_struct), optional :: pmd_header
  logical, optional :: combine
  logical err_flag
  character(*) file_name
end subroutine

subroutine hdf5_write_beam (file_name, bunches, append, error, lat)
  import
  implicit none
  type (bunch_struct), target :: bunches(:)
  type (lat_struct), optional :: lat
  logical error, append
  character(*) file_name
end subroutine

subroutine hdf5_write_grid_field (file_name, ele, g_field, err_flag)
  import
  implicit none
  type (grid_field_struct), target :: g_field(:)
  type (ele_struct) ele
  logical err_flag
  character(*) file_name
end subroutine

subroutine init_a_photon_from_a_photon_init_ele (ele, param, orbit)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
  type (coord_struct) orbit
end subroutine

subroutine init_bmad_parser_common()
  import
  implicit none
end subroutine

subroutine init_ele (ele, key, sub_key, ix_ele, branch)
  import
  implicit none
  type (ele_struct)  ele
  type (branch_struct), optional, target :: branch
  integer, optional :: key, sub_key
  integer, optional :: ix_ele
end subroutine

subroutine init_fringe_info (fringe_info, ele, orbit, leng_sign)
  import
  implicit none
  type (fringe_field_info_struct) fringe_info
  type (ele_struct) ele
  type (coord_struct), optional :: orbit
  integer, optional :: leng_sign
end subroutine

subroutine init_lat (lat, n)
  import
  implicit none
  type (lat_struct)  lat
  integer, optional :: n
end subroutine

subroutine init_wake (wake, n_sr_long, n_sr_trans, n_lr_mode, always_allocate)
  import
  implicit none
  type (wake_struct), pointer :: wake
  integer n_sr_long, n_sr_trans, n_lr_mode
  logical, optional :: always_allocate
end subroutine

subroutine insert_element (lat, insert_ele, insert_index, ix_branch, orbit)
  import
  implicit none
  type (lat_struct) lat
  type (ele_struct) insert_ele
  integer insert_index
  integer, optional :: ix_branch
  type (coord_struct), optional, allocatable :: orbit(:)
end subroutine

subroutine ion_kick (orbit, r_beam, n_beam_part, a_twiss, b_twiss, sig_ee, kick)
  import
  implicit none
  type (coord_struct) orbit
  type (twiss_struct) a_twiss, b_twiss
  real(rp) r_beam(2), n_beam_part, sig_ee, kick(3)
end subroutine

function key_name_to_key_index (key_str, abbrev_allowed) result (key_index)
  import
  implicit none
  character(*) key_str
  logical, optional :: abbrev_allowed
  integer key_index
end function

subroutine kill_ptc_layouts (lat)
  import
  implicit none
  type (lat_struct) lat
end subroutine

function knot_interpolate (x_knot, y_knot, x_pt, interpolation, err_flag) result (y_pt)
  import
  implicit none
  real(rp) x_knot(:), y_knot(:), x_pt, y_pt
  integer interpolation
  logical err_flag
end function

subroutine lat_compute_ref_energy_and_time (lat, err_flag)
  import
  implicit none
  type (lat_struct) lat
  logical err_flag
end subroutine

subroutine lat_ele_locator (loc_str, lat, eles, n_loc, err, above_ubound_is_err, ix_dflt_branch, order_by_index)
  import
  implicit none
  character(*) loc_str
  type (lat_struct) lat
  type (ele_pointer_struct), allocatable :: eles(:)
  integer n_loc
  logical, optional :: above_ubound_is_err, err, order_by_index
  integer, optional :: ix_dflt_branch
end subroutine

subroutine lat_geometry (lat)
  import
  implicit none
  type (lat_struct), target :: lat
end subroutine lat_geometry

recursive subroutine lat_make_mat6 (lat, ix_ele, ref_orb, ix_branch, err_flag)
  import
  implicit none
  type (lat_struct), target :: lat
  type (coord_struct), optional :: ref_orb(0:)
  integer, optional :: ix_ele, ix_branch
  logical, optional :: err_flag
end subroutine

subroutine lat_sanity_check (lat, err_flag)
  import
  implicit none
  type (lat_struct), target :: lat
  logical, intent(out) :: err_flag
end subroutine

subroutine lattice_bookkeeper (lat, err_flag)
  import
  implicit none
  type (lat_struct), target :: lat
  logical, optional :: err_flag
end subroutine

function lord_edge_aligned (slave, slave_edge, lord) result (is_aligned)
  import
  implicit none
  type (ele_struct), target :: slave, lord
  integer slave_edge
  logical is_aligned
end function

function low_energy_z_correction (orbit, ele, ds, mat6, make_matrix) result (dz)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  real(rp) ds, dz
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end function

subroutine make_g_mats (ele, g_mat, g_inv_mat)
  import
  implicit none
  type (ele_struct) ele
  real(rp) g_mat(4,4)
  real(rp) g_inv_mat(4,4)
end subroutine

subroutine make_g2_mats (twiss, g2_mat, g2_inv_mat)
  import
  implicit none
  type (twiss_struct) twiss
  real(rp) g2_mat(2,2), g2_inv_mat(2,2)
end subroutine

subroutine make_hybrid_lat (r_in, r_out, use_taylor, orb0_arr)
  import
  implicit none
  type (lat_struct), target :: r_in
  type (lat_struct), target :: r_out
  logical, optional :: use_taylor
  type (coord_array_struct), optional :: orb0_arr(0:)
end subroutine

recursive subroutine make_mat6 (ele, param, start_orb, end_orb, err_flag)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct), optional :: start_orb, end_orb
  type (lat_param_struct) param
  logical, optional :: err_flag
end subroutine

subroutine make_mat6_taylor (ele, param, start_orb, end_orb, err_flag)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
  logical, optional :: err_flag
end subroutine

subroutine make_mat6_bmad (ele, param, start_orb, end_orb, err)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
  logical, optional :: err
end subroutine

subroutine make_mat6_bmad_photon (ele, param, start_orb, end_orb, err)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
  logical, optional :: err
end subroutine

subroutine make_mat6_runge_kutta (ele, param, start_orb, end_orb)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
end subroutine

subroutine make_mat6_symp_lie_ptc (ele, param, start_orb, end_orb)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
end subroutine

subroutine make_mat6_tracking (ele, param, start_orb, end_orb, err_flag)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
  logical err_flag
end subroutine

subroutine make_v_mats (ele, v_mat, v_inv_mat)
  import
  implicit none
  type (ele_struct) ele
  real(rp), optional :: v_mat(4,4)
  real(rp), optional :: v_inv_mat(4,4)
end subroutine

function master_parameter_value (master_parameter, ele) result (value)
  import
  implicit none
  type (ele_struct) ele
  real(rp) value
  integer master_parameter
end function

subroutine mat6_add_offsets (ele, param)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
end subroutine

subroutine mat6_add_pitch (x_pitch_tot, y_pitch_tot, orientation, mat6)
  import
  implicit none
  real(rp) mat6(6,6), x_pitch_tot, y_pitch_tot
  integer orientation
end subroutine

subroutine mat_symp_decouple(t0, stat, U, V, Ubar, Vbar, G,  twiss1, twiss2, gamma, type_out)
  import
  implicit none
  real(rp) t0(4,4), U(4,4), V(4,4)
  integer stat
  real(rp) Ubar(4,4), Vbar(4,4), G(4,4)
  type (twiss_struct)  twiss1, twiss2
  real(rp) gamma
  logical type_out
end subroutine

subroutine mat4_multipole (knl, tilt, n, orbit, kick_mat)
  import
  implicit none
  real(rp) knl, tilt
  integer n
  type (coord_struct) orbit
  real(rp) kick_mat(4,4)
end subroutine

subroutine match_ele_to_mat6 (ele, start_orb, mat6, vec0, err_flag, twiss_ele, include_delta_time)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) start_orb
  real(rp) mat6(6,6), vec0(6)
  type (ele_struct), optional, target :: twiss_ele
  logical :: err_flag
  logical, optional :: include_delta_time
end subroutine

function mexp (x, m) result (this_exp)
  import
  implicit none
  real(rp) x, this_exp
  integer m
end function

subroutine multi_turn_tracking_analysis (track, i_dim, track0, ele, stable, growth_rate, chi, err_flag)
  import
  implicit none
  type (coord_struct), intent(in) :: track(:)
  type (coord_struct), intent(out) :: track0
  type (ele_struct) :: ele
  real(rp), intent(out) :: growth_rate, chi
  integer, intent(in) :: i_dim
  logical, intent(out) :: stable, err_flag
end subroutine

subroutine multi_turn_tracking_to_mat (track, i_dim, mat1, map0, track0, chi)
  import
  implicit none
  type (coord_struct), intent(in), target :: track(:)
  type (coord_struct), intent(out) :: track0
  real(rp), intent(out) :: mat1(:,:), map0(:)
  real(rp), intent(out) :: chi
  integer, intent(in) :: i_dim
end subroutine

subroutine multipass_all_info (lat, info)
  import
  implicit none
  type (lat_struct), target :: lat
  type (multipass_all_info_struct), target :: info
end subroutine

subroutine multipass_chain (ele, ix_pass, n_links, chain_ele, use_super_lord)
  import
  implicit none
  type (ele_struct) :: ele
  type (ele_pointer_struct), allocatable, optional :: chain_ele(:)
  integer :: n_links, ix_pass
  logical, optional :: use_super_lord
end subroutine

recursive subroutine multipole_ele_to_ab (ele, use_ele_tilt, ix_pole_max, a, b, pole_type, include_kicks, b1)
  import
  implicit none
  type (ele_struct), target :: ele
  real(rp) a(0:n_pole_maxx), b(0:n_pole_maxx)
  real(rp), optional :: b1
  integer ix_pole_max
  integer, optional :: pole_type, include_kicks
  integer include_kck
  logical use_ele_tilt
end subroutine

subroutine multipole_init (ele, who, zero)
  import
  implicit none
  type (ele_struct) ele
  integer who
  logical, optional :: zero
end subroutine

subroutine multipole_kick_mat (knl, tilt, ref_species, ele, orbit, factor, mat6)
  import
  implicit none
  real(rp) knl(0:), tilt(0:)
  integer ref_species
  type (ele_struct) ele
  type (coord_struct) orbit
  real(rp) mat6(6,6), factor
end subroutine

subroutine multipole_spin_tracking (ele, param, orbit)
  import
  implicit none
  type (ele_struct) :: ele
  type (lat_param_struct) param
  type (coord_struct) orbit
end subroutine

subroutine name_to_list (lat, ele_names)
  import
  implicit none
  type (lat_struct) lat
  character(*) ele_names(:)
end subroutine

subroutine new_control (lat, ix_ele, ele_name)
  import
  implicit none
  type (lat_struct) lat
  integer ix_ele
  character(*), optional :: ele_name
end subroutine

function num_lords (slave, lord_type) result (num)
  import
  implicit none
  type (ele_struct) slave
integer lord_type, num
end function

subroutine offset_particle (ele, param, set, coord, set_tilt, set_hvkicks, drift_to_edge, s_pos, s_out, set_spin, mat6, make_matrix)
  import
  implicit none
  type (ele_struct) :: ele
  type (lat_param_struct) param
  type (coord_struct), intent(inout) :: coord
  integer particle
  logical, intent(in) :: set
  logical, optional, intent(in) :: set_tilt, set_hvkicks, drift_to_edge, set_spin
  real(rp), optional :: s_pos, mat6(6,6), s_out
  logical, optional :: make_matrix
end subroutine

subroutine offset_photon (ele, coord, set, offset_position_only, rot_mat)
  import
  implicit none
  type (ele_struct) :: ele
  type (coord_struct) :: coord
  logical :: set
  logical, optional :: offset_position_only
  real(rp), optional :: rot_mat(3,3)
end subroutine

subroutine one_turn_mat_at_ele (ele, phi_a, phi_b, mat4)
  import
  implicit none
  type (ele_struct) ele
  real(rp) phi_a
  real(rp) phi_b
  real(rp) mat4(4,4)
end subroutine

subroutine orbit_amplitude_calc (ele, orb, amp_a, amp_b, amp_na, amp_nb)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct) orb
  real(rp), optional :: amp_a, amp_b, amp_na, amp_nb
end subroutine

function orbit_to_local_curvilinear (orbit, ele) result (local_position)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (floor_position_struct) local_position
end function

function orbit_too_large (orbit, param) result (is_too_large)
  import
  implicit none
  type (coord_struct) orbit
  type (lat_param_struct), optional :: param
  logical is_too_large
  real(rp) rel_p
end function

subroutine order_super_lord_slaves (lat, ix_lord)
  import
  implicit none
  type (lat_struct), target :: lat
  integer ix_lord
end subroutine

subroutine converter_distribution_parser (ele, delim, delim_found, err_flag)
  import
  type (ele_struct) ele
  character(*) delim
  logical delim_found, err_flag
end subroutine

function particle_is_moving_backwards (orbit) result (is_moving_backwards)
  import
  implicit none
  type (coord_struct) orbit
  logical is_moving_backwards
end function

function particle_is_moving_forward (orbit) result (is_moving_forward)
  import
  implicit none
  type (coord_struct) orbit
  logical is_moving_forward
end function

function particle_rf_time (orbit, ele, reference_active_edge, s_rel) result (time)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  real(rp), optional :: s_rel
  real(rp) time
  logical reference_active_edge
end function

function patch_flips_propagation_direction (x_pitch, y_pitch) result (is_flip)
  import
  implicit none
  real(rp) x_pitch, y_pitch
  logical is_flip
end function patch_flips_propagation_direction

function patch_length (patch, ref_coords) result (length)
  import
  implicit none
  type (ele_struct) patch
  real(rp) length
  integer, optional :: ref_coords
end function

subroutine phase_space_fit (x, xp, twiss, tune, emit, x_0, xp_0, chi, tol)
  import
  implicit none
  type (twiss_struct) twiss
  real(rp), optional :: tol
  real(rp) x(:), xp(:)
  real(rp) tune, emit
  real(rp) x_0, xp_0, chi
end subroutine

function physical_ele_end (track_end, track_direction, ele_orientation, return_stream_end) result (physical_end)
  import
  implicit none
  integer track_end, track_direction, ele_orientation, physical_end
  logical, optional :: return_stream_end
end function

subroutine pointer_to_attribute (ele, attrib_name, do_allocation, a_ptr, err_flag, err_print_flag, ix_attrib)
  import
  implicit none
  type (ele_struct), target :: ele
  type (all_pointer_struct) a_ptr
  character(*) attrib_name
  logical err_flag
  logical do_allocation
  logical, optional :: err_print_flag
  integer, optional :: ix_attrib
end subroutine

subroutine pointer_to_ele_multipole (ele, a_pole, b_pole, ksl_pole, pole_type)
  import
  implicit none
  type (ele_struct), target :: ele
  real(rp), pointer :: a_pole(:), b_pole(:), ksl_pole(:)
  integer, optional :: pole_type
end subroutine

function pointer_to_girder(ele, ix_slave_back) result (girder)
  import
  implicit none
  type (ele_struct), target :: ele
  type (ele_struct), pointer :: girder
  integer, optional :: ix_slave_back
end function

subroutine pointer_to_indexed_attribute (ele, ix_attrib, do_allocation, a_ptr, err_flag, err_print_flag)
  import
  implicit none
  type (ele_struct), target :: ele
  type (all_pointer_struct) :: a_ptr
  integer :: ix_attrib
  logical err_flag, do_allocation
  logical, optional :: err_print_flag
end subroutine

function pointer_to_lord (slave, ix_lord, control, ix_slave_back, field_overlap_ptr, ix_control, ix_ic) result (lord_ptr)
  import
  implicit none
  type (ele_struct), target :: slave
  type (control_struct), pointer, optional :: control
  type (ele_struct), pointer :: lord_ptr
  integer ix_lord
  integer, optional :: ix_slave_back, ix_control, ix_ic
  logical, optional :: field_overlap_ptr
end function

function pointer_to_multipass_lord (ele, ix_pass, super_lord) result (multi_lord)
  import
  implicit none
  type (ele_struct) ele
  integer, optional :: ix_pass
  type (ele_struct), pointer :: multi_lord
  type (ele_struct), pointer, optional :: super_lord
end function

function pointer_to_next_ele (this_ele, offset, skip_beginning, follow_fork) result (next_ele)
  import
  implicit none
  type (ele_struct), target :: this_ele
  type (ele_struct), pointer :: next_ele
  integer, optional :: offset
  logical, optional :: skip_beginning, follow_fork
end function

!function pointer_to_slave (lord, ix_slave, control, field_overlap_ptr) result (slave_ptr)
!  import
!  implicit none
!  type (ele_struct), target :: lord
!  type (control_struct), pointer, optional :: control
!  type (ele_struct), pointer :: slave_ptr
!  integer ix_slave
!  logical, optional :: field_overlap_ptr
!end function

function pointer_to_wake_ele (ele, delta_s) result (wake_ele)
  import
  implicit none
  type (ele_struct), target :: ele
  type (ele_struct), pointer :: wake_ele
  real(rp), optional :: delta_s
end function

subroutine pointers_to_attribute (lat, ele_name, attrib_name, do_allocation, &
                  ptr_array, err_flag, err_print_flag, eles, ix_attrib)
  import
  implicit none
  type (lat_struct) lat
  type (all_pointer_struct), allocatable :: ptr_array(:)
  character(*) ele_name, attrib_name
  logical err_flag
  logical do_allocation
  logical, optional :: err_print_flag
  type (ele_pointer_struct), optional, allocatable :: eles(:)
  integer, optional :: ix_attrib
end subroutine

function polar_to_spinor (polar) result (spinor)
  import
  implicit none
  type (spin_polar_struct) polar
  complex(rp) :: spinor(2)
end function

function polar_to_vec (polar) result (vec)
  import
  implicit none
  type (spin_polar_struct) polar
  real(rp) vec(3)
end function

subroutine ptc_bookkeeper (lat)
  import
  implicit none
  type (lat_struct) lat
end subroutine

subroutine ptc_ran_seed_put (iseed)
  implicit none
  integer iseed
end subroutine

subroutine ptc_read_flat_file (flat_file, err_flag, lat, create_end_marker, from_mad)
  import
  implicit none
  type (lat_struct), optional :: lat
  character(*) flat_file(:)
  logical err_flag
  logical, optional :: create_end_marker, from_mad
end subroutine

subroutine ptc_spin_matching_calc (branch, match_info)
  import
  implicit none
  type (branch_struct), target :: branch
  type (spin_matching_struct), allocatable, target :: match_info(:)
end subroutine

subroutine ptc_transfer_map_with_spin (branch, t_map, s_map, orb0, err_flag, ix1, ix2, one_turn, unit_start)
  import
  implicit none
  type (branch_struct) :: branch
  type (taylor_struct) :: t_map(6), s_map(4)
  type (coord_struct) orb0
  integer, optional :: ix1, ix2
  logical err_flag
  logical, optional :: one_turn, unit_start
end subroutine

subroutine quad_beta_ave (ele, beta_a_ave, beta_b_ave)
  import
  implicit none
  type (ele_struct) ele
  real(rp) beta_a_ave
  real(rp) beta_b_ave
end subroutine

subroutine quad_mat2_calc (k1, length, rel_p, mat2, z_coef, dz_dpz_coef)
  import
  implicit none
  real(rp) k1, length, rel_p
  real(rp) mat2(:,:)
  real(rp), optional :: z_coef(3), dz_dpz_coef(3)
end subroutine

subroutine radiation_integrals (lat, orb, mode, ix_cache, ix_branch, rad_int_by_ele)
  import
  implicit none
  type (lat_struct), target :: lat
  type (rad_int_all_ele_struct), optional :: rad_int_by_ele
  type (coord_struct), target :: orb(0:)
  type (normal_modes_struct) mode
  integer, optional :: ix_cache, ix_branch
end subroutine

subroutine re_allocate_eles (eles, n, save_old, exact)
  import
  implicit none
  type (ele_pointer_struct), allocatable :: eles(:)
  integer n
  logical, optional :: save_old, exact
end subroutine

subroutine reallocate_control (lat, n)
  import
  implicit none
  type (lat_struct) lat
  integer, intent(in) :: n
end subroutine

subroutine reallocate_expression_stack (stack, n, exact)
  import
  implicit none
  type (expression_atom_struct), allocatable :: stack(:)
  integer n
  logical, optional :: exact
end subroutine

subroutine reference_energy_correction (ele, orbit, particle_at, mat6, make_matrix)
  import
  implicit none
  type (ele_struct) :: ele
  type (coord_struct) :: orbit
  real(rp), optional :: mat6(6,6)
  integer particle_at
  logical, optional :: make_matrix
end subroutine

function rel_tracking_charge_to_mass (orbit, param) result (rel_charge)
  import
  implicit none
  type (coord_struct) orbit
  type (lat_param_struct) param
  real(rp) rel_charge
end function

subroutine remove_eles_from_lat (lat, check_sanity)
  import
  implicit none
  type (lat_struct) lat
  logical, optional :: check_sanity
end subroutine

subroutine remove_lord_slave_link (lord, slave)
  import
  implicit none
  type (ele_struct), target :: lord, slave
end subroutine

subroutine read_digested_bmad_file (in_file_name, lat, version, err_flag, parser_calling, lat_files)
  import
  implicit none
  type (lat_struct), target, intent(inout) :: lat
  integer version
  character(*) in_file_name
  logical, optional :: err_flag, parser_calling
  character(*), optional, allocatable :: lat_files(:)
end subroutine

subroutine reallocate_beam (beam, n_bunch, n_particle, save)
  import
  implicit none
  type (beam_struct) beam
  integer n_bunch
  integer, optional :: n_particle
  logical, optional :: save
end subroutine

subroutine reallocate_bunch (bunch, n_particle)
  import
  implicit none
  type (bunch_struct) bunch
  integer n_particle
end subroutine

function relative_mode_flip (ele1, ele2)
  import
  implicit none
  logical relative_mode_flip
  type (ele_struct) ele1
  type (ele_struct) ele2
end function

subroutine reverse_lat (lat_in, lat_rev, track_antiparticle)
  import
  implicit none
  type (lat_struct), target :: lat_in, lat_rev
  logical, optional :: track_antiparticle
end subroutine

subroutine rf_coupler_kick (ele, param, particle_at, phase, orbit, mat6, make_matrix)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
  type (coord_struct) orbit
  real(rp) phase
  real(rp), optional :: mat6(6,6)
  integer particle_at
  logical, optional :: make_matrix
end subroutine

function rf_is_on (branch) result (is_on)
  import
  implicit none
  type (branch_struct), target :: branch
  logical is_on
end function

function rf_ref_time_offset (ele) result (time)
  import
  implicit none
  type (ele_struct) ele
  real(rp) time
end function

subroutine rotate_spin (rot_vec, spin)
  import
  implicit none
  real(rp) :: spin(3), rot_vec(3)
end subroutine

subroutine rotate_spin_a_step (orbit, field, ele, ds)
  import
  implicit none
  type (coord_struct) orbit
  type (em_field_struct) field
  type (ele_struct) ele
  real(rp) ds
end subroutine

subroutine rotate_spin_given_field (orbit, sign_z_vel, BL, EL)
  import
  implicit none
  type (coord_struct) orbit
  real(rp), optional :: BL(3), EL(3)
  integer sign_z_vel
end subroutine

subroutine s_calc (lat)
  import
  implicit none
  type (lat_struct) lat
end subroutine

subroutine save_a_step (track, ele, param, local_ref_frame, orb, s_rel, save_field, mat6, make_matrix, rf_time)
  import
  implicit none
  type (track_struct) track
  type (ele_struct), target :: ele
  type (lat_param_struct), intent(in) :: param
  type (coord_struct) orb
  real(rp) s_rel
  real(rp), optional :: mat6(6,6), rf_time
  logical local_ref_frame
  logical, optional :: save_field, make_matrix
end subroutine

subroutine set_ele_attribute (ele, set_string, err_flag, err_print_flag)
  import
  implicit none
  type (ele_struct) ele
  logical, optional :: err_print_flag
  logical err_flag
  character(*) set_string
end subroutine

subroutine set_ele_name(ele, name)
  import
  implicit none
  type (ele_struct) ele
  character(*) name
end subroutine

subroutine set_ele_real_attribute (ele, attrib_name, value, err_flag, err_print_flag)
  import
  implicit none
  type (ele_struct) ele
  real(rp) value
  logical, optional :: err_print_flag
  logical err_flag
  character(*) attrib_name
end subroutine

recursive subroutine set_ele_status_stale (ele, status_group, set_slaves)
  import
  implicit none
  type (ele_struct), target :: ele
  integer status_group
  logical, optional :: set_slaves
end subroutine

subroutine set_fringe_on_off (fringe_at, ele_end, on_or_off) 
  import
  implicit none
  integer ele_end, on_or_off
  real(rp) fringe_at
end subroutine

recursive subroutine set_lords_status_stale (ele, stat_group, control_bookkeeping, flag)
  import
  implicit none
  type (ele_struct) ele
  integer stat_group
  logical, optional :: control_bookkeeping
  integer, optional :: flag
end subroutine

subroutine set_on_off (key, lat, switch, orb, use_ref_orb, ix_branch, saved_values, attribute)
  import
  implicit none
  type (lat_struct), target :: lat
  type (coord_struct), optional :: orb(0:)
  real(rp), optional, allocatable :: saved_values(:)
  integer :: key, switch
  integer, optional :: ix_branch
  logical, optional :: use_ref_orb
  character(*), optional :: attribute
end subroutine

subroutine set_orbit_to_zero (orbit, n1, n2, ix_noset)
  import
  implicit none
  type (coord_struct) orbit(0:)
  integer n1, n2
  integer, optional :: ix_noset
end subroutine

subroutine set_particle_from_rf_time (rf_time, ele, reference_active_edge, orbit)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct) orbit
  real(rp) rf_time
  logical reference_active_edge
end subroutine

subroutine set_status_flags (bookkeeping_state, stat)
  import
  implicit none
  type (bookkeeping_state_struct) bookkeeping_state
  integer stat
end subroutine

subroutine save_bunch_track (bunch, ele, s_travel)
  import
  implicit none
  type (bunch_struct) bunch
  type (ele_struct) ele
  real(rp) s_travel
end subroutine

subroutine sbend_body_with_k1_map (ele, k_1, param, n_step, orbit, mat6, make_matrix)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
  type (coord_struct) orbit
  integer n_step
  real(rp) k_1
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine set_on (key, lat, on_switch, orb)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct), optional :: orb(0:)
  integer key
  logical on_switch
end subroutine

subroutine set_ele_defaults (ele, do_allocate)
  import
  implicit none
  type (ele_struct) ele
  logical, optional :: do_allocate
end subroutine

subroutine set_tune (phi_a_set, phi_b_set, dk1, lat, orb, ok)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct), allocatable :: orb(:)
  real(rp) phi_a_set
  real(rp) phi_b_set
  real(rp) dk1(:)
  logical ok
end subroutine

function significant_difference (value1, value2, abs_tol, rel_tol) result (is_different)
  import
  implicit none
  real(rp), intent(in) :: value1, value2
  real(rp), intent(in), optional :: abs_tol, rel_tol
  logical is_different
end function

subroutine slice_lattice (lat, ele_list, error, do_bookkeeping)
  import
  implicit none
  type (lat_struct) lat
  character(*) ele_list
  logical error
  logical, optional :: do_bookkeeping
end subroutine

subroutine sol_quad_mat6_calc (ks, k1, s_len, ele, orbit, mat6, make_matrix)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct) orbit
  real(rp) ks, k1, s_len
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine solenoid_track_and_mat (ele, length, param, start_orb, end_orb, mat6)
  import
  implicit none
  type (ele_struct) ele
  type (lat_param_struct) param
  type (coord_struct) start_orb, end_orb
  real(rp) length
  real(rp), optional :: mat6(:,:)
end subroutine

function spin_depolarization_rate (branch, match_info, rad_int_by_ele) result (depol_rate)
  import
  type (branch_struct), target :: branch
  type (spin_matching_struct) match_info(0:)
  type (rad_int_all_ele_struct) rad_int_by_ele
  real(rp) depol_rate
end function

function spin_dn_dpz_from_mat8 (mat_1turn, dn_dpz_partial) result (dn_dpz)
  import
  implicit none
  real(rp) mat_1turn(8,8), dn_dpz(3)
  real(rp), optional :: dn_dpz_partial(3,3)
end function

function spin_dn_dpz_from_qmap (orb_mat, q_map, dn_dpz_partial) result (dn_dpz)
  import
  implicit none
  real(rp) orb_mat(6,6), q_map(0:3,0:6), dn_dpz(3)
  real(rp), optional :: dn_dpz_partial(3,3)
end function

function spin_omega (field, orbit, sign_z_vel, phase_space_coords) result (omega)
  import
  implicit none
  type (em_field_struct) :: field
  type (coord_struct) :: orbit
  integer sign_z_vel
  logical, optional :: phase_space_coords
  real(rp) omega(3)
end function

function spinor_to_polar (spinor) result (polar)
  import
  implicit none
  complex(rp) spinor(2)
  type (spin_polar_struct) ::  polar
end function

function spinor_to_vec (spinor) result (vec)
  import
  implicit none
  complex(rp) spinor(2)
  real(rp) vec(3)
end function

subroutine spline_fit_orbit (ele, start_orb, end_orb, spline_x, spline_y)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct) start_orb, end_orb
  real(rp) spline_x(0:3), spline_y(0:3)
end subroutine

subroutine split_lat (lat, s_split, ix_branch, ix_split, split_done, add_suffix, check_sanity, &
                                                 save_null_drift, err_flag, choose_max, ix_insert)
  import
  implicit none
  type (lat_struct), target :: lat
  real(rp) s_split
  integer ix_branch
  integer ix_split
  integer, optional :: ix_insert
  logical split_done
  logical, optional :: add_suffix, check_sanity, save_null_drift, err_flag, choose_max
end subroutine

function stream_ele_end (physical_end, ele_orientation) result (stream_end)
  import
  implicit none
  integer stream_end, ele_orientation, physical_end
end function

subroutine tilt_coords (tilt_val, coord, mat6, make_matrix)
  import
  implicit none
  real(rp) tilt_val
  real(rp) coord(:)
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine tilt_coords_photon (tilt_val, coord, w_mat)
  import
  implicit none
  real(rp) tilt_val, coord(:)
  real(rp), optional :: w_mat(3,3)
end subroutine

subroutine tilt_mat6 (mat6, tilt)
  import
  implicit none
  real(rp) tilt, mat6(6,6)
end subroutine

subroutine track_a_beambeam (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_bend (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_converter (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_crab_cavity (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_drift (orb, length, mat6, make_matrix, include_ref_motion)
  import
  implicit none
  type (coord_struct) orb
  real(rp) length
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix, include_ref_motion
end subroutine

subroutine track_a_drift_photon (orb, length, phase_relative_to_ref)
  import
  implicit none
  type (coord_struct) orb
  real(rp) length
  logical phase_relative_to_ref
end subroutine

subroutine track_a_lcavity (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_mask (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_match (orbit, ele, param, err_flag, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix, err_flag
end subroutine

subroutine track_a_patch (ele, orbit, drift_to_exit, s_ent, ds_ref, track_spin, mat6, make_matrix)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) orbit
  real(rp), optional :: mat6(6,6), s_ent, ds_ref
  logical, optional :: drift_to_exit, track_spin, make_matrix
end subroutine

subroutine track_a_quadrupole (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_rfcavity (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_sad_mult (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_sol_quad (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_thick_multipole (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_wiggler (orbit, ele, param, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track_a_zero_length_element (start_orb, ele, param, end_orb, err_flag, track)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct), target :: ele
  type (lat_param_struct), target :: param
  logical err_flag
  type (track_struct), optional :: track
end subroutine

subroutine track_all (lat, orbit, ix_branch, track_state, err_flag, orbit0)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct), allocatable, target :: orbit(:)
  type (coord_struct), optional, allocatable, target :: orbit0(:)
  integer, optional :: ix_branch, track_state
  logical, optional :: err_flag
end subroutine

subroutine track_bunch_time (lat, bunch, t_end, dt_step)
  import
  implicit none
  type (lat_struct), target :: lat
  type (bunch_struct) :: bunch
  real(rp) t_end
  real(rp), optional :: dt_step(:)
end subroutine

subroutine track_from_s_to_s (lat, s_start, s_end, orbit_start, orbit_end, all_orb, ix_branch, track_state)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct) orbit_start, orbit_end
  type (coord_struct), optional, allocatable :: all_orb(:)
  real(rp) s_start, s_end
  integer, optional :: ix_branch, track_state
end subroutine

subroutine track_many (lat, orbit, ix_start, ix_end, direction, ix_branch, track_state)
  import
  implicit none
  type (lat_struct)  lat
  type (coord_struct)  orbit(0:)
  integer ix_start
  integer ix_end
  integer direction
  integer, optional :: ix_branch, track_state
end subroutine

recursive subroutine track1 (start_orb, ele, param, end_orb, track, err_flag, ignore_radiation, &
                                                                           mat6, make_matrix, init_to_edge)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct)   :: ele
  type (lat_param_struct) :: param
  type (track_struct), optional :: track
  logical, optional :: err_flag, ignore_radiation, init_to_edge
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track1_bmad (start_orb, ele, param, end_orb, err_flag, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  logical, optional :: err_flag
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track1_bmad_photon (start_orb, ele, param, end_orb, err_flag)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  logical, optional :: err_flag
end subroutine

subroutine track1_bunch_e_gun_space_charge (bunch, ele, err)
  import
  implicit none
  type (bunch_struct) bunch
  type (ele_struct) :: ele
  logical err
end subroutine

subroutine track1_linear (start_orb, ele, param, end_orb)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
end subroutine

subroutine track1_runge_kutta (start_orb, ele, param, end_orb, err_flag, track, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct), target :: ele
  type (lat_param_struct), target :: param
  logical err_flag
  type (track_struct), optional :: track
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
end subroutine

subroutine track1_spin (start_orb, ele, param, end_orb, make_quaternion)
  import
  implicit none
  type (coord_struct) :: start_orb, end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  logical, optional :: make_quaternion
end subroutine

subroutine track1_spin_bmad (start_orb, ele, param, end_orb, make_quaternion)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  type (coord_struct) :: end_orb
  logical, optional :: make_quaternion
end subroutine

subroutine track1_spin_taylor (start_orb, ele, param, end_orb)
  import
  implicit none
  type (coord_struct) :: start_orb, end_orb
  type (ele_struct) ele
  type (lat_param_struct) param
end subroutine

subroutine track1_symp_lie_ptc (start_orb, ele, param, end_orb, track)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  type (track_struct), optional :: track
end subroutine

subroutine track1_taylor (start_orb, ele, param, end_orb, taylor, mat6, make_matrix)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  real(rp), optional :: mat6(6,6)
  logical, optional :: make_matrix
  type (taylor_struct), optional, target :: taylor(6)
end subroutine

subroutine track1_time_runge_kutta (start_orb, ele, param, end_orb, err_flag, track, t_end, dt_step)
  import
  implicit none
  real(rp), optional :: t_end, dt_step
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct), target :: ele
  type (lat_param_struct), target :: param
  logical err_flag
  type (track_struct), optional :: track
end subroutine

subroutine transfer_ac_kick (ac_kick_in, ac_kick_out)
  import
  implicit none
  type (ac_kicker_struct), pointer :: ac_kick_in, ac_kick_out
end subroutine transfer_ac_kick

subroutine transfer_branch (branch1, branch2)
  import
  implicit none
  type (branch_struct) :: branch1
  type (branch_struct) :: branch2
end subroutine

subroutine transfer_branch_parameters (branch_in, branch_out)
  import
  implicit none
  type (branch_struct), intent(in) :: branch_in
  type (branch_struct) :: branch_out
end subroutine

subroutine transfer_branches (branch1, branch2)
  import
  implicit none
  type (branch_struct) :: branch1(:)
  type (branch_struct) :: branch2(:)
end subroutine

subroutine transfer_ele (ele1, ele2, nullify_pointers)
  import
  implicit none
  type (ele_struct), target :: ele1
  type (ele_struct) :: ele2
  logical, optional :: nullify_pointers
end subroutine

subroutine transfer_ele_taylor (ele_in, ele_out, taylor_order)
  import
  implicit none
  type (ele_struct) ele_in, ele_out
  integer, optional :: taylor_order
end subroutine

subroutine transfer_eles (ele1, ele2)
  import
  implicit none
  type (ele_struct), intent(inout) :: ele1(:)
  type (ele_struct), intent(inout) :: ele2(:)
end subroutine

subroutine transfer_fieldmap (ele_in, ele_out, who)
  import
  implicit none
  type (ele_struct) :: ele_in, ele_out
  integer who
end subroutine

subroutine transfer_lat (lat1, lat2)
  import
  implicit none
  type (lat_struct), intent(in) :: lat1
  type (lat_struct), intent(out) :: lat2
end subroutine

subroutine transfer_lat_parameters (lat_in, lat_out)
  import
  implicit none
  type (lat_struct), intent(in) :: lat_in
  type (lat_struct) :: lat_out
end subroutine

subroutine transfer_map_calc (lat, t_map, err_flag, ix1, ix2, ref_orb, ix_branch, one_turn, unit_start, concat_if_possible)
  import
  implicit none
  type (lat_struct) lat
  type (taylor_struct) :: t_map(:)
  type (coord_struct), optional :: ref_orb
  integer, intent(in), optional :: ix1, ix2, ix_branch
  logical err_flag
  logical, optional :: one_turn, unit_start, concat_if_possible
end subroutine

subroutine transfer_mat_from_twiss (ele1, ele2, orb1, orb2, m)
  import
  implicit none
  type (ele_struct) ele1, ele2
  real(rp) orb1(6), orb2(6)
  real(rp) m(6,6)
end subroutine

subroutine transfer_mat2_from_twiss (twiss1, twiss2, mat)
  import
  implicit none
  type (twiss_struct) twiss1, twiss2
  real(rp) mat(2,2)
end subroutine

subroutine transfer_matrix_calc (lat, xfer_mat, xfer_vec, ix1, ix2, ix_branch, one_turn)
  import
  implicit none
  type (lat_struct) lat
  real(rp) :: xfer_mat(6,6)
  real(rp), optional :: xfer_vec(6)
  integer, optional :: ix1, ix2, ix_branch
  logical, optional :: one_turn
end subroutine

subroutine transfer_twiss (ele_in, ele_out, reverse)
  import
  implicit none
  type (ele_struct) ele_in, ele_out
  logical, optional :: reverse
end subroutine

subroutine transfer_wake (wake_in, wake_out)
  import
  implicit none
  type (wake_struct), pointer :: wake_in, wake_out
end subroutine

subroutine transfer_wall3d (wall3d_in, wall3d_out)
  import
  implicit none
  type (wall3d_struct), pointer :: wall3d_in(:), wall3d_out(:)
end subroutine

subroutine twiss_and_track_from_s_to_s (branch, orbit_start, s_end, orbit_end, &
                                                               ele_start, ele_end, err, compute_floor_coords)
  import
  implicit none
  type (coord_struct) :: orbit_start, orbit_end
  type (ele_struct), optional :: ele_start, ele_end
  type (branch_struct) branch
  real(rp) s_end
  logical, optional, intent(inout) :: err
  logical, optional :: compute_floor_coords
end subroutine

recursive subroutine twiss_and_track_intra_ele (ele, param, l_start, l_end, track_upstream_end, &
                 track_downstream_end, orbit_start, orbit_end, ele_start, ele_end, err, compute_floor_coords, reuse_ele_end)
  import
  implicit none
  type (coord_struct), optional :: orbit_start, orbit_end
  type (ele_struct), optional :: ele_start, ele_end
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp) l_start, l_end
  logical track_upstream_end, track_downstream_end
  logical, optional :: err, compute_floor_coords, reuse_ele_end
end subroutine

recursive subroutine twiss_at_element (ele, start_ele, end_ele, average)
  import
  implicit none
  type (ele_struct), target :: ele
  type (ele_struct), optional :: start_ele
  type (ele_struct), optional :: end_ele
  type (ele_struct), optional :: average
end subroutine

subroutine twiss_at_start (lat, status, ix_branch, type_out)
  import
  implicit none
  type (lat_struct) lat
  integer, optional, intent(in) :: ix_branch
  integer, optional, intent(out) :: status
  logical, optional :: type_out
end subroutine

subroutine twiss1_propagate (twiss1, mat2, ele_type, length, twiss2, err)
  import
  implicit none
  type (twiss_struct) twiss1, twiss2
  integer ele_type
  real(rp) mat2(2,2), length
  logical err
end subroutine

subroutine twiss_from_mat2 (mat_in, twiss, stat, type_out)
  import
  implicit none
  type (twiss_struct)  twiss
  real(rp) mat_in(:, :)
  integer stat
  logical type_out
end subroutine

subroutine twiss_from_mat6 (mat6, map0, ele, stable, growth_rate, status, type_out)
  import
  implicit none
  type (ele_struct) :: ele
  real(rp) :: mat6(:,:), map0(:)
  real(rp) :: growth_rate
  logical :: stable, type_out
  integer :: status
end subroutine

subroutine twiss_from_tracking (lat, ref_orb0, symp_err, err_flag, d_orb) 
  import
  implicit none
  type (lat_struct), intent(inout) :: lat
  type (coord_struct), intent(in) :: ref_orb0
  real(rp), intent(in), optional :: d_orb(:)   
  real(rp), intent(out) :: symp_err
  logical err_flag
end subroutine

subroutine twiss_propagate1 (ele1, ele2, err)
  import
  implicit none
  type (ele_struct) ele1
  type (ele_struct) ele2
  logical, optional :: err
end subroutine

subroutine twiss_propagate_all (lat, ix_branch, err_flag, ie_start, ie_end, zero_uncalculated)
  import
  implicit none
  type (lat_struct) lat
  integer, optional :: ix_branch, ie_start, ie_end
  logical, optional :: err_flag, zero_uncalculated
end subroutine

subroutine twiss_to_1_turn_mat (twiss, phi, mat2)
  import
  implicit none
  type (twiss_struct) twiss
  real(rp) phi, mat2(2,2)
end subroutine

subroutine type_coord (coord)
  import
  implicit none
  type (coord_struct) coord
end subroutine

subroutine type_ele (ele, type_zero_attrib, type_mat6, type_taylor, twiss_out, &
      type_control, type_wake, type_floor_coords, type_field, type_wall, lines, n_lines)
  import
  implicit none
  type (ele_struct), target :: ele
  integer, optional, intent(in) :: type_mat6
  integer, optional, intent(out) :: n_lines
  integer, optional, intent(in) :: twiss_out
  logical, optional, intent(in) :: type_control, type_taylor, type_floor_coords
  logical, optional, intent(in) :: type_zero_attrib, type_wake
  logical, optional :: type_field, type_wall
  character(*), optional, allocatable :: lines(:)
end subroutine

subroutine type_twiss (ele, frequency_units, compact_format, lines, n_lines)
  import
  implicit none
  type (ele_struct) ele
  integer, optional :: frequency_units
  integer, optional :: n_lines
  character(*), optional :: lines(:)
  logical, optional :: compact_format
end subroutine

subroutine unlink_fieldmap (cartesian_map, cylindrical_map, taylor_field, grid_field)
  import
  implicit none
  type (cartesian_map_struct), pointer, optional :: cartesian_map(:)
  type (cylindrical_map_struct), pointer, optional :: cylindrical_map(:)
  type (taylor_field_struct), pointer, optional :: taylor_field(:)
  type (grid_field_struct), pointer, optional :: grid_field(:)
end subroutine

subroutine unlink_wall3d (wall3d)
  import
  implicit none
  type (wall3d_struct), pointer :: wall3d(:)
end subroutine

subroutine update_floor_angles (floor, floor0)
  import
  implicit none
  type(floor_position_struct) :: floor
  type(floor_position_struct), optional :: floor0
end subroutine update_floor_angles

subroutine update_fibre_from_ele (ele)
  import
  implicit none
  type (ele_struct) ele
end subroutine

function valid_field_calc (ele, field_calc) result (is_valid)
  import
  implicit none
  type (ele_struct) ele
  integer field_calc
  logical is_valid
end function

function valid_fringe_type (ele, fringe_type) result (is_valid)
  import
  implicit none
  type (ele_struct) ele
  integer fringe_type
  logical is_valid
end function

function valid_mat6_calc_method (ele, species, mat6_calc_method) result (is_valid)
  import
  implicit none
  type (ele_struct) ele
  integer mat6_calc_method, species
  logical is_valid
end function

function valid_spin_tracking_method (ele, spin_tracking_method) result (is_valid)
  import
  implicit none
  type (ele_struct) ele
  integer spin_tracking_method
  logical is_valid
end function

function valid_tracking_method (ele, species, tracking_method) result (is_valid)
  import
  implicit none
  type (ele_struct), target :: ele
  integer tracking_method, species
  logical is_valid
end function

function value_of_attribute (ele, attrib_name, err_flag, err_print_flag, err_value) result (value)
  import
  implicit none
  type (ele_struct), target :: ele
  type (all_pointer_struct) a_ptr
  real(rp) value
  real(rp), optional :: err_value
  character(*) attrib_name
  logical, optional :: err_print_flag, err_flag
end function

function vec_to_polar (vec, phase) result (polar)
  import
  implicit none
  real(rp) vec(3)
  real(rp), optional :: phase
  type (spin_polar_struct) :: polar
end function

function vec_to_spinor (vec, phase) result (spinor)
  import
  implicit none
  real(rp) vec(3)
  real(rp), optional :: phase
  complex(rp) :: spinor(2)
end function

function w_mat_for_bend_angle (angle, ref_tilt, r_vec) result (w_mat)
  import
  implicit none
  real(rp) angle, ref_tilt, w_mat(3,3), t_mat(3,3)
  real(rp), optional :: r_vec(3)
end function w_mat_for_bend_angle

function w_mat_for_x_pitch (x_pitch, return_inverse) result (w_mat)
  import
  implicit none
  real(rp) x_pitch, c_ang, s_ang
  real(rp) :: w_mat(3,3)
  logical, optional :: return_inverse
end function w_mat_for_x_pitch

function w_mat_for_y_pitch (y_pitch, return_inverse) result (w_mat)
  import
  implicit none
  real(rp) y_pitch, c_ang, s_ang
  real(rp) :: w_mat(3,3)
  logical, optional :: return_inverse
end function w_mat_for_y_pitch

function w_mat_for_tilt (tilt, return_inverse) result (w_mat)
  import
  implicit none
  real(rp) tilt, c_ang, s_ang
  real(rp) :: w_mat(3,3)
  logical, optional :: return_inverse
end function w_mat_for_tilt

subroutine write_bmad_lattice_file (bmad_file, lat, err, output_form, orbit0)
  import
  implicit none
  character(*) bmad_file
  type (lat_struct), target :: lat
  logical, optional :: err
  integer, optional :: output_form
  type (coord_struct), optional :: orbit0
end subroutine

subroutine write_digested_bmad_file (digested_name, lat,  n_files, file_names, extra, err_flag)
  import
  implicit none
  type (lat_struct), target, intent(in) :: lat
  integer, intent(in), optional :: n_files
  character(*) digested_name
  character(*), optional :: file_names(:)
  type (extra_parsing_info_struct), optional :: extra
  logical, optional :: err_flag
end subroutine

subroutine write_lattice_in_foreign_format (out_type, out_file_name, lat, ref_orbit, use_matrix_model, &
                       include_apertures, dr12_drift_max, ix_start, ix_end, ix_branch, converted_lat, err)
  import
  implicit none
  type (lat_struct), target :: lat
  type (lat_struct), optional, target :: converted_lat
  type (coord_struct), allocatable, optional :: ref_orbit(:)
  real(rp), optional :: dr12_drift_max
  integer, optional :: ix_start, ix_end, ix_branch
  character(*) out_type, out_file_name
  logical, optional :: use_matrix_model, include_apertures, err
end subroutine

subroutine xsif_parser (xsif_file, lat, make_mats6, digested_read_ok, use_line, err_flag)
  import
  implicit none
  character(*) xsif_file
  character(*), optional :: use_line
  type (lat_struct), target :: lat
  logical, optional :: make_mats6
  logical, optional :: digested_read_ok, err_flag
  end subroutine

subroutine zero_ele_kicks (ele)
  import
  implicit none
  type (ele_struct) ele
end subroutine

subroutine zero_ele_offsets (ele)
  import
  implicit none
  type (ele_struct) ele
end subroutine

! Custom and hook routines

subroutine apply_element_edge_kick_hook (orb, fringe_info, track_ele, param, finished, mat6, make_matrix, rf_time)
  import
  implicit none
  type (coord_struct) orb
  type (fringe_field_info_struct) fringe_info
  type (ele_struct) track_ele
  type (lat_param_struct) param
  real(rp), optional :: mat6(6,6), rf_time
  logical, optional :: make_matrix
  logical finished
end subroutine

subroutine check_aperture_limit_custom (orb, ele, particle_at, param, err_flag)
  import
  implicit none
  type (coord_struct) :: orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  integer particle_at
  logical err_flag
end subroutine

function distance_to_aperture_custom (orbit, particle_at, ele, no_aperture_here) result (dist)
  import
  implicit none
  type (coord_struct) orbit
  type (ele_struct) ele
  real(rp) dist
  integer particle_at
  logical no_aperture_here
end function

subroutine ele_geometry_hook (floor0, ele, floor, finished, len_scale)
  import
  implicit none
  type (ele_struct) ele
  type (floor_position_struct) floor0, floor
  real(rp) len_scale
  logical finished
end subroutine ele_geometry_hook

subroutine wall_hit_handler_custom (orb, ele, s)
  import
  implicit none
  type (coord_struct) :: orb
  type (ele_struct) :: ele
  real(rp) s
end subroutine

recursive subroutine em_field_custom (ele, param, s_rel, orbit, local_ref_frame, field, calc_dfield, err_flag, &
                                                  calc_potential, use_overlap, grid_allow_s_out_of_bounds, rf_time, used_eles)
  import
  implicit none
  type (ele_struct) :: ele
  type (lat_param_struct) param
  type (coord_struct), intent(in) :: orbit
  type (ele_pointer_struct), allocatable, optional :: used_eles(:)
  real(rp), intent(in) :: s_rel
  real(rp), optional :: rf_time
  logical local_ref_frame
  type (em_field_struct) :: field
  logical, optional :: err_flag, grid_allow_s_out_of_bounds
  logical, optional :: calc_dfield, calc_potential, use_overlap
end subroutine

subroutine ele_to_fibre_hook (ele, ptc_fibre, param)
  import
  implicit none
  type (ele_struct) ele
  type (fibre) ptc_fibre
  type (lat_param_struct) param
end subroutine

subroutine radiation_integrals_custom (lat, ir, orb, rad_int1, err_flag)
  import
  implicit none
  type (lat_struct) lat
  type (coord_struct) orb(0:)
  type (rad_int1_struct) rad_int1
  integer ir
  logical err_flag
end subroutine

subroutine init_custom (ele, err_flag)
  import
  implicit none
  type (ele_struct), target :: ele
  logical err_flag
end subroutine

subroutine make_mat6_custom (ele, param, start_orb, end_orb, err_flag)
  import
  implicit none
  type (ele_struct), target :: ele
  type (coord_struct) :: start_orb, end_orb
  type (lat_param_struct) param
  logical err_flag, finished
end subroutine

subroutine time_runge_kutta_periodic_kick_hook (orbit, dt_space, ele, param, stop_time, init_needed)
  import
  type (coord_struct) orbit
  type (ele_struct) ele
  type (lat_param_struct) param
  real(rp) dt_space, stop_time
  integer :: init_needed
end subroutine

subroutine track1_bunch_hook (bunch_start, lat, ele, bunch_end, err, centroid, direction, finished)
  import
  implicit none
  type (bunch_struct) bunch_start
  type (bunch_struct) :: bunch_end
  type (lat_struct) :: lat
  type (ele_struct) ele
  type (coord_struct), optional :: centroid(0:)
  integer, optional :: direction
  logical err, finished
end subroutine

subroutine track1_custom (start_orb, ele, param, end_orb, err_flag, finished, track)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  type (track_struct), optional :: track
  logical err_flag, finished, radiation_included
end subroutine

subroutine track1_postprocess (start_orb, ele, param, end_orb)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
end subroutine

subroutine track1_preprocess (start_orb, ele, param, err_flag, finished, radiation_included, track)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  type (track_struct), optional :: track
  logical err_flag, finished, radiation_included
end subroutine

subroutine track1_spin_custom (start_orb, ele, param, end_orb, err_flag, make_quaternion)
  import
  implicit none
  type (coord_struct) :: start_orb
  type (coord_struct) :: end_orb
  type (ele_struct) :: ele
  type (lat_param_struct) :: param
  logical err_flag
  logical, optional :: make_quaternion
end subroutine

subroutine track1_wake_hook (bunch, ele, finished)
  import
  implicit none
  type (bunch_struct) bunch
  type (ele_struct) ele
  logical finished
end subroutine

end interface

! This is to suppress the ranlib "has no symbols" message
integer, private :: private_dummy

end module
