module equality_mod

use bmad_struct

interface operator (==)
  module procedure eq_coord, eq_twiss, eq_xy_disp, eq_floor_position
  module procedure eq_taylor_term, eq_taylor, eq_wig_term
  module procedure eq_sr_table_wake, eq_sr_mode_wake, eq_lr_wake
  module procedure eq_rf_wake, eq_rf_field_mode, eq_rf_field
  module procedure eq_modes, eq_bmad_com, eq_em_field, eq_ele, eq_mode_info
  module procedure eq_lat, eq_wall3d, eq_control, eq_param, eq_amode, eq_linac_mode
end interface

contains

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_coord (f1, f2) result (is_eq)

implicit none

type (coord_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (all(f1%vec == f2%vec) .and. all(f1%spin == f2%spin)) .and. &
        (f1%e_field_x == f2%e_field_x) .and. (f1%e_field_y == f2%e_field_y) .and. &
        (f1%phase_x == f2%phase_x) .and. (f1%phase_y == f2%phase_y)

end function eq_coord

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_twiss (f1, f2) result (is_eq)

implicit none

type (twiss_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%beta == f2%beta) .and. (f1%alpha == f2%alpha) .and. &
          (f1%gamma == f2%gamma) .and. (f1%phi == f2%phi) .and. &
          (f1%eta == f2%eta) .and. (f1%etap == f2%etap) .and. &
          (f1%sigma == f2%sigma) .and. (f1%emit == f2%emit) .and. &
          (f1%norm_emit == f2%norm_emit)

end function eq_twiss

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_xy_disp (f1, f2) result (is_eq)

implicit none

type (xy_disp_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%eta == f2%eta) .and. (f1%etap == f2%etap)

end function eq_xy_disp

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_floor_position (f1, f2) result (is_eq)

implicit none

type (floor_position_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%x == f2%x) .and. (f1%y == f2%y) .and. &
          (f1%z == f2%z) .and. (f1%theta == f2%theta) .and. &
          (f1%phi == f2%phi) .and. (f1%psi == f2%psi)

end function eq_floor_position

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_wig_term (f1, f2) result (is_eq)

implicit none

type (wig_term_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%coef == f2%coef) .and. (f1%kx == f2%kx) .and. &
          (f1%ky == f2%ky) .and. (f1%kz == f2%kz) .and. &
          (f1%phi_z == f2%phi_z) .and. (f1%type == f2%type)

end function eq_wig_term

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_taylor_term (f1, f2) result (is_eq)

implicit none

type (taylor_term_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%coef == f2%coef) .and. all(f1%expn == f2%expn)

end function eq_taylor_term

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_taylor (f1, f2) result (is_eq)

implicit none

type (taylor_struct), intent(in) :: f1, f2
logical is_eq
integer i

!

is_eq = (f1%ref == f2%ref) .and. (associated(f1%term) .eqv. associated(f1%term))

if (associated(f1%term)) then
  is_eq = is_eq .and. (size(f1%term) == size(f2%term))
  if (.not. is_eq) return
  do i = 1, size(f1%term)
    is_eq = is_eq .and. (f1%term(i) == f2%term(i))
  enddo
endif

end function eq_taylor

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_sr_table_wake (f1, f2) result (is_eq)

implicit none

type (rf_wake_sr_table_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%z == f2%z) .and. (f1%long == f2%long) .and. (f1%trans == f2%trans)

end function eq_sr_table_wake

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_sr_mode_wake (f1, f2) result (is_eq)

implicit none

type (rf_wake_sr_mode_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%amp == f2%amp) .and. (f1%damp == f2%damp) .and. &
        (f1%k == f2%k) .and. (f1%phi == f2%phi) .and. &
        (f1%b_sin == f2%b_sin) .and. (f1%b_cos == f2%b_cos) .and. &
        (f1%a_sin == f2%a_sin) .and. (f1%a_cos == f2%a_cos)

end function eq_sr_mode_wake

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_lr_wake (f1, f2) result (is_eq)

implicit none

type (rf_wake_lr_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%freq == f2%freq) .and. (f1%r_over_q == f2%r_over_q) .and. &
        (f1%freq_in == f2%freq_in) .and. (f1%Q == f2%Q) .and. &
        (f1%m == f2%m) .and. (f1%b_sin == f2%b_sin) .and. &
        (f1%b_cos == f2%b_cos) .and. (f1%a_sin == f2%a_sin) .and. &
        (f1%a_cos == f2%a_cos) .and. (f1%t_ref == f2%t_ref) .and. &
        (f1%m == f2%m) .and. (f1%angle == f2%angle) .and. &
        (f1%polarized .eqv. f2%polarized)

end function eq_lr_wake

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_rf_field_mode (f1, f2) result (is_eq)

implicit none

type (rf_field_mode_struct), intent(in) :: f1, f2
integer i
logical is_eq

!

is_eq = (f1%freq == f2%freq) .and. (f1%f_damp == f2%f_damp) .and. (f1%theta_t0 == f2%theta_t0) .and. &
        (f1%stored_energy == f2%stored_energy) .and. (f1%m == f2%m) .and. (f1%phi_0 == f2%phi_0) .and. &
        (f1%dz == f2%dz) .and. (f1%f_scale == f2%f_scale)
if (.not. is_eq) return

is_eq  = (allocated(f1%term) .eqv. allocated(f2%term))
if (.not. is_eq) return

if (allocated(f1%term)) is_eq = is_eq .and. (size(f1%term) == size(f2%term))
if (.not. is_eq) return

if (allocated(f1%term)) then
  do i = 1, size(f1%term)
    is_eq = (f1%term(i)%e == f2%term(i)%e) .and. (f1%term(i)%b == f2%term(i)%b) 
    if (.not. is_eq) return
  enddo
endif

end function eq_rf_field_mode

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_rf_field (f1, f2) result (is_eq)

implicit none

type (rf_field_struct), intent(in) :: f1, f2
integer i
logical is_eq

!

is_eq  = (allocated(f1%mode) .eqv. allocated(f2%mode)) ! .and. &
         !   (allocated(f1%t_ref) .eqv. allocated(f2%t_ref)) .and. &
         !   (allocated(f1%e_tot_ref) .eqv. allocated(f2%e_tot_ref)) .and. &
if (.not. is_eq) return

if (allocated(f1%mode)) then
  is_eq = (size(f1%mode) == size(f2%mode))
  if (.not. is_eq) return

  do i = 1, size(f1%mode)
    is_eq = (f1%mode(i) == f2%mode(i))
    if (.not. is_eq) return
  enddo
endif

! if (allocated(f1%t_ref)) is_eq = is_eq .and. (size(f1%t_ref) == size(f2%t_ref))
! if (allocated(f1%e_tot_ref)) is_eq = is_eq .and. (size(f1%e_tot_ref) == size(f2%e_tot_ref))
! if (.not. is_eq) return

! if (allocated(f1%t_ref)) is_eq = is_eq .and. all(f1%t_ref == f2%t_ref)
! if (allocated(f1%e_tot_ref)) is_eq = is_eq .and. all(f1%e_tot_ref == f2%e_tot_ref)

end function eq_rf_field

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_rf_wake (f1, f2) result (is_eq)

implicit none

type (rf_wake_struct), intent(in) :: f1, f2
integer i
logical is_eq

!

is_eq = (f1%sr_file == f2%sr_file) .and. (f1%lr_file == f2%lr_file) .and. &
     (size(f1%sr_table) == size(f2%sr_table)) .and. (size(f2%sr_mode_long) == size(f2%sr_mode_long)) .and. &
     (size(f1%sr_mode_trans) == size(f2%sr_mode_trans)) .and. (size(f1%lr) == size(f2%lr)) .and. &
     (f1%z_sr_mode_max == f2%z_sr_mode_max)
if (.not. is_eq) return

do i = lbound(f1%sr_table, 1), ubound(f1%sr_table, 1)
  is_eq = is_eq .and. (f1%sr_table(i) == f2%sr_table(i)) 
enddo

do i = lbound(f1%sr_mode_long, 1), ubound(f1%sr_mode_long, 1)
  is_eq = is_eq .and. (f1%sr_mode_long(i) == f2%sr_mode_long(i)) 
enddo

do i = lbound(f1%sr_mode_trans, 1), ubound(f1%sr_mode_trans, 1)
  is_eq = is_eq .and. (f1%sr_mode_trans(i) == f2%sr_mode_trans(i)) 
enddo

do i = lbound(f1%lr, 1), ubound(f1%lr, 1)
  is_eq = is_eq .and. (f1%lr(i) == f2%lr(i)) 
enddo

end function eq_rf_wake

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_control (f1, f2) result (is_eq)

implicit none

type (control_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%coef == f2%coef) .and. (f1%ix_lord == f2%ix_lord) .and. &
        (f1%ix_slave == f2%ix_slave) .and. (f1%ix_attrib == f2%ix_attrib)

end function eq_control

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_param (f1, f2) result (is_eq)

implicit none

type (lat_param_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%n_part == f2%n_part) .and. (f1%total_length == f2%total_length) .and. &
     (f1%unstable_factor == f2%unstable_factor) .and. &
     all(f1%t1_with_RF == f2%t1_with_RF) .and. &
     all(f1%t1_no_RF == f2%t1_no_RF) .and. &
     (f1%particle == f2%particle) .and. (f1%ix_lost == f2%ix_lost) .and. &
     (f1%end_lost_at == f2%end_lost_at) .and. &
     (f1%lattice_type == f2%lattice_type) .and. & 
     (f1%ixx == f2%ixx) .and. (f1%stable .eqv. f2%stable) .and. &
     (f1%aperture_limit_on .eqv. f2%aperture_limit_on) .and. (f1%lost .eqv. f2%lost) 

end function eq_param

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_amode (f1, f2) result (is_eq)

implicit none

type (anormal_mode_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%emittance == f2%emittance) .and. &
         all(f1%synch_int == f2%synch_int) .and. &
         (f1%j_damp == f2%j_damp) .and. (f1%alpha_damp == f2%alpha_damp) .and. &
         (f1%chrom == f2%chrom) .and. (f1%tune == f2%tune)

end function eq_amode

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_linac_mode (f1, f2) result (is_eq)

implicit none

type (linac_normal_mode_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%i2_E4 == f2%i2_E4) .and. (f1%i3_E7 == f2%i3_E7) .and. &
         (f1%i5a_E6 == f2%i5a_E6) .and. (f1%i5b_E6 == f2%i5b_E6) .and. &
         (f1%a_emittance_end == f2%a_emittance_end) .and. &
         (f1%b_emittance_end == f2%b_emittance_end)

end function eq_linac_mode

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_modes (f1, f2) result (is_eq)

implicit none

type (normal_modes_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = all(f1%synch_int == f2%synch_int) .and. (f1%sige_e == f2%sige_e) .and. &
 (f1%sig_z == f2%sig_z) .and. (f1%e_loss == f2%e_loss) .and. &
 (f1%pz_aperture == f2%pz_aperture) .and. (f1%a == f2%a) .and. &
 (f1%b == f2%b) .and. (f1%z == f2%z) .and. (f1%lin == f2%lin)

end function eq_modes

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_bmad_com (f1, f2) result (is_eq)

implicit none

type (bmad_common_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = all(f1%d_orb == f2%d_orb) .and. &
      (f1%max_aperture_limit == f2%max_aperture_limit) .and. &
      (f1%grad_loss_sr_wake == f2%grad_loss_sr_wake) .and. &
      (f1%rel_tolerance == f2%rel_tolerance) .and. &
      (f1%abs_tolerance == f2%abs_tolerance) .and. &
      (f1%taylor_order == f2%taylor_order) .and. &
      (f1%default_integ_order == f2%default_integ_order) .and. &
      (f1%default_ds_step == f2%default_ds_step) .and.  &
      (f1%canonical_coords .eqv. f2%canonical_coords) .and. &
      (f1%significant_longitudinal_length  == f2%significant_longitudinal_length) .and. &
      (f1%sr_wakes_on .eqv. f2%sr_wakes_on) .and.  &
      (f1%lr_wakes_on .eqv. f2%lr_wakes_on) .and.  &
      (f1%mat6_track_symmetric .eqv.  f2%mat6_track_symmetric) .and. &
      (f1%auto_bookkeeper .eqv. f2%auto_bookkeeper) .and. &
      (f1%space_charge_on .eqv. f2%space_charge_on) .and. &
      (f1%coherent_synch_rad_on .eqv. f2%coherent_synch_rad_on) .and. &
      (f1%radiation_damping_on .eqv. f2%radiation_damping_on) .and. &
      (f1%radiation_fluctuations_on .eqv. f2%radiation_fluctuations_on) .and. &
      (f1%compute_ref_energy .eqv. f2%compute_ref_energy) .and. &
      (f1%conserve_taylor_maps .eqv. f2%conserve_taylor_maps)

end function eq_bmad_com

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_em_field (f1, f2) result (is_eq)

implicit none

type (em_field_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = all(f1%E == f2%E) .and. all(f1%b == f2%b) .and. &
    all(f1%dE == f2%dE) .and. all(f1%dB == f2%dB) 

end function eq_em_field

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_ele (f1, f2) result (is_eq)

implicit none

type (ele_struct), intent(in) :: f1, f2
logical is_eq
integer i, j

!

is_eq = (f1%name == f2%name) .and. (f1%type == f2%type) .and. &
    (f1%alias == f2%alias) .and. &
    (f1%component_name == f2%component_name) .and. (f1%a == f2%a) .and. &
    (f1%b == f2%b) .and. &
    (f1%z == f2%z) .and. (f1%floor == f2%floor) .and. all(f1%value == f2%value) .and. &
    all(f1%gen0 == f2%gen0) .and. all(f1%vec0 == f2%vec0) .and. &
    all(f1%mat6 == f2%mat6) .and. all(f1%c_mat == f2%c_mat) .and. &
    (f1%gamma_c == f2%gamma_c) .and. (f1%s == f2%s) .and. &
    (f1%key == f2%key) .and. (f1%sub_key == f2%sub_key) .and. &
    (f1%lord_status == f2%lord_status) .and. (f1%slave_status == f2%slave_status) .and. &
    (f1%ix_value == f2%ix_value) .and. &
    (f1%n_slave == f2%n_slave) .and. (f1%ix1_slave == f2%ix1_slave) .and. &
    (f1%ix2_slave == f2%ix2_slave) .and. (f1%n_lord == f2%n_lord) .and. &
    (f1%ic1_lord == f2%ic1_lord) .and. (f1%ic2_lord == f2%ic2_lord) .and. &
    (f1%ix_pointer == f2%ix_pointer) .and. (f1%ixx == f2%ixx) .and. &
    (f1%ix_ele == f2%ix_ele) .and. (f1%mat6_calc_method == f2%mat6_calc_method) .and. &
    (f1%tracking_method == f2%tracking_method) .and. &
    (f1%field_calc == f2%field_calc) .and. (f1%aperture_type == f2%aperture_type) .and. &
    (f1%ref_orbit == f2%ref_orbit) .and. (f1%taylor_order == f2%taylor_order) .and. &
    (f1%attribute_status == f2%attribute_status) .and. &
    (f1%aperture_at == f2%aperture_at) .and. (f1%symplectify .eqv. f2%symplectify) .and. &
    (f1%mode_flip .eqv. f2%mode_flip) .and. (f1%multipoles_on .eqv. f2%multipoles_on) .and. &
    (f1%map_with_offsets .eqv. f2%map_with_offsets) .and. &
    (f1%field_master .eqv. f2%field_master) .and. &
    (f1%is_on .eqv. f2%is_on) .and. (f1%old_is_on .eqv. f2%old_is_on) .and. &
    (f1%logic .eqv. f2%logic) .and. (f1%on_a_girder .eqv. f2%on_a_girder) .and. &
    (f1%csr_calc_on .eqv. f2%csr_calc_on) .and. (f1%ref_time == f2%ref_time)

is_eq = is_eq .and. (associated(f1%gen_field) .eqv. associated(f2%gen_field)) .and. &
    (associated(f1%a_pole) .eqv. associated(f2%a_pole)) .and. &
    (associated(f1%const) .eqv. associated(f2%const)) .and. &
    (associated(f1%r) .eqv. associated(f2%r)) .and. &
    (associated(f1%descrip) .eqv. associated(f2%descrip)) .and. &
    (associated(f1%wig_term) .eqv. associated(f2%wig_term)) .and. &
    (associated(f1%rf%wake) .eqv. associated(f2%rf%wake))

if (.not. is_eq) return
is_eq = .false.

if (associated(f1%a_pole)) then
  if (any(f1%a_pole /= f2%a_pole) .or. any(f1%b_pole /= f2%b_pole)) return
endif

if (associated(f1%const)) then
  if (any(f1%const /= f2%const)) return
endif

if (associated(f1%r)) then
  if (any(lbound(f1%r) /= lbound(f2%r)) .or. any(ubound(f1%r) /= ubound(f2%r))) return
  if (any(f1%r /= f2%r)) return
endif

if (associated(f1%descrip)) then
  if (f1%descrip /= f2%descrip) return
endif

if (associated(f1%wig_term)) then
  if (size(f1%wig_term) /= size(f2%wig_term)) return
  if (.not. all(f1%wig_term == f2%wig_term)) return
endif

do i = 1, size(f1%taylor)
  if (.not. (f1%taylor(i) == f2%taylor(i))) return
enddo

if (associated(f1%rf%wake)) then
  if (.not. (f1%rf%wake == f2%rf%wake)) return
endif

if (associated(f1%gen_field)) then
  if (.not. associated(f1%gen_field, f2%gen_field)) return
endif

if (.not. f1%wall3d == f2%wall3d) return

is_eq = .true.

end function eq_ele

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_wall3d (f1, f2) result (is_eq)

implicit none

type (wall3d_struct), intent(in) :: f1, f2
logical is_eq
integer i

!

is_eq = .false.

if (associated(f1%section)) then
  if (.not. associated(f2%section)) return
  if (size(f1%section) /= size(f2%section)) return
  do i = 1, size(f1%section)
    if (f1%section(i)%s               /= f2%section(i)%s) return
    if (any(f1%section(i)%s_spline /= f2%section(i)%s_spline)) return
    if (f1%section(i)%n_slice_spline  /= f2%section(i)%n_slice_spline) return
    if (f1%section(i)%type            /= f2%section(i)%type) return
    if (size(f1%section(i)%v) /= size(f2%section(i)%v)) return
    if (any(f1%section(i)%v%x /= f2%section(i)%v%x)) return
    if (any(f1%section(i)%v%y /= f2%section(i)%v%y)) return
    if (any(f1%section(i)%v%radius_x /= f2%section(i)%v%radius_x)) return
    if (any(f1%section(i)%v%radius_y /= f2%section(i)%v%radius_y)) return
    if (any(f1%section(i)%v%tilt /= f2%section(i)%v%tilt)) return
    if (any(f1%section(i)%v%angle /= f2%section(i)%v%angle)) return
    if (any(f1%section(i)%v%x0 /= f2%section(i)%v%x0)) return
    if (any(f1%section(i)%v%y0 /= f2%section(i)%v%y0)) return
  enddo
endif

is_eq = .true.

end function eq_wall3d

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
subroutine print_eq_ele (f1, f2)

implicit none

type (ele_struct), intent(in) :: f1, f2
integer i, j
character(40) :: fmt = '(2x, a, 100f6.0)'
!

print *
print *, 'Fortran side:'
print *, 'names:      ', (f1%name == f2%name) .and. (f1%type == f2%type) .and. &
    (f1%alias == f2%alias) .and. (f1%component_name == f2%component_name)
print *, 'ints:       ', (f1%gamma_c == f2%gamma_c) .and. (f1%s == f2%s) .and. &
    (f1%key == f2%key) .and. (f1%sub_key == f2%sub_key) .and. &
    (f1%lord_status == f2%lord_status) .and. (f1%slave_status == f2%slave_status) .and. &
    (f1%ix_value == f2%ix_value) .and. &
    (f1%n_slave == f2%n_slave) .and. (f1%ix1_slave == f2%ix1_slave) .and. &
    (f1%ix2_slave == f2%ix2_slave) .and. (f1%n_lord == f2%n_lord) .and. &
    (f1%ic1_lord == f2%ic1_lord) .and. (f1%ic2_lord == f2%ic2_lord) .and. &
    (f1%ix_pointer == f2%ix_pointer) .and. (f1%ixx == f2%ixx) .and. &
    (f1%ix_ele == f2%ix_ele) .and. (f1%ref_time == f2%ref_time)
print *, 'logic:      ', (f1%mat6_calc_method == f2%mat6_calc_method) .and. &
    (f1%tracking_method == f2%tracking_method) .and. &
    (f1%field_calc == f2%field_calc) .and. (f1%aperture_type == f2%aperture_type) .and. &
    (f1%ref_orbit == f2%ref_orbit) .and. (f1%taylor_order == f2%taylor_order) .and. &
    (f1%aperture_at == f2%aperture_at) .and. (f1%symplectify .eqv. f2%symplectify) .and. &
    (f1%mode_flip .eqv. f2%mode_flip) .and. (f1%multipoles_on .eqv. f2%multipoles_on) .and. &
    (f1%map_with_offsets .eqv. f2%map_with_offsets) .and. &
    (f1%field_master .eqv. f2%field_master) .and. &
    (f1%is_on .eqv. f2%is_on) .and. (f1%old_is_on .eqv. f2%old_is_on) .and. &
    (f1%logic .eqv. f2%logic) .and. (f1%on_a_girder .eqv. f2%on_a_girder)

print *, 'xyz:        ', (f1%a == f2%a) .and. (f1%b == f2%b) .and. (f1%z == f2%z) 
print *, 'floor:      ', (f1%floor == f2%floor)
!print fmt, ' floor1:', f1%floor
!print fmt, ' floor2:', f2%floor
print *, 'value:      ', all(f1%value == f2%value) 
!print fmt, ' value1:', f1%value
!print fmt, ' value2:', f2%value
print *, 'gen0:       ', all(f1%gen0 == f2%gen0)
print *, 'vec0:       ', all(f1%vec0 == f2%vec0) 
print *, 'mat6:       ', all(f1%mat6 == f2%mat6)
print *, 'c_mat:      ', all(f1%c_mat == f2%c_mat)
print *, 'Associated: ', (associated(f1%a_pole) .eqv. associated(f2%a_pole)) .and. &
    (associated(f1%const) .eqv. associated(f2%const)) .and. &
    (associated(f1%descrip) .eqv. associated(f2%descrip))
print *, 'A wig:      ', (associated(f1%wig_term) .eqv. associated(f2%wig_term))
print *, 'A wake:     ', (associated(f1%rf%wake) .eqv. associated(f2%rf%wake))
print *, 'A gen_field:', (associated(f1%gen_field) .eqv. associated(f2%gen_field))
print *, 'A r:        ', (associated(f1%r) .eqv. associated(f2%r))

if (associated(f1%a_pole) .and. associated(f2%a_pole)) then
  print *, 'ab:       ', all(f1%a_pole == f2%a_pole) .and. all(f1%b_pole == f2%b_pole)
endif

if (associated(f1%const) .and. associated(f2%const)) then
  print *, 'const:    ', all(f1%const == f2%const)
  !print fmt, ' const1:', f1%const
  !print fmt, ' const2:', f2%const
endif

if (associated(f1%r) .and. associated(f2%r)) then
  print *, 'r bounds: ', &
            (all(lbound(f1%r) == lbound(f2%r)) .or. all(ubound(f1%r) == ubound(f2%r))) 
  print *, 'r:        ', all(f1%r == f2%r)
endif

if (associated(f1%descrip) .and. associated(f2%descrip)) then
  print *, 'descrip:  ', f1%descrip == f2%descrip
  !print *, ' descrip1: ', trim(f1%descrip), '#'
  !print *, ' descrip2: ', trim(f2%descrip), '#'
endif

if (associated(f1%wig_term) .and. associated(f2%wig_term)) then
  print *, 'wig size: ', size(f1%wig_term) == size(f2%wig_term)
  print *, 'wig:      ', all(f1%wig_term == f2%wig_term)
endif

if (associated(f1%gen_field)) then
  print *, 'gen_field:', associated(f1%gen_field, f2%gen_field)
endif

do i = 1, size(f1%taylor)
  print *, 'taylor:   ', i, (f1%taylor(i) == f2%taylor(i))
enddo

if (associated(f1%rf%wake) .and. associated(f2%rf%wake)) then
  print *, 'wake:     ', (f1%rf%wake == f2%rf%wake)
endif

end subroutine

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_mode_info (f1, f2) result (is_eq)

implicit none

type (mode_info_struct), intent(in) :: f1, f2
logical is_eq

!

is_eq = (f1%tune == f2%tune) .and. (f1%emit == f2%emit) .and. (f1%chrom == f2%chrom)

end function eq_mode_info

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------

elemental function eq_lat (f1, f2) result (is_eq)

implicit none

type (lat_struct), intent(in) :: f1, f2
logical is_eq
integer i

!

is_eq = (f1%name == f2%name) 
is_eq = is_eq .and. (f1%lattice == f2%lattice) 
is_eq = is_eq .and. (f1%input_file_name == f2%input_file_name) 
is_eq = is_eq .and. (f1%title == f2%title) 
is_eq = is_eq .and. (f1%a == f2%a) 
is_eq = is_eq .and. (f1%b == f2%b) 
is_eq = is_eq .and. (f1%z == f2%z) 
is_eq = is_eq .and. (f1%param == f2%param) 
is_eq = is_eq .and. (f1%version == f2%version) 
is_eq = is_eq .and. (f1%n_ele_track == f2%n_ele_track) 
is_eq = is_eq .and. (f1%n_ele_max == f2%n_ele_max) 
is_eq = is_eq .and. (f1%n_control_max == f2%n_control_max) 
is_eq = is_eq .and. (f1%n_ic_max == f2%n_ic_max) 
is_eq = is_eq .and. (f1%input_taylor_order == f2%input_taylor_order) 
is_eq = is_eq .and. (f1%ele_init == f2%ele_init) 
is_eq = is_eq .and. (size(f1%ele) == size(f2%ele)) 
is_eq = is_eq .and. (size(f1%control) == size(f2%control)) 
is_eq = is_eq .and. (size(f1%ic) == size(f2%ic)) 
is_eq = is_eq .and. (f1%wall3d == f2%wall3d)

if (.not. is_eq) return

do i = 0, f1%n_ele_max
  is_eq = is_eq .and. (f1%ele(i) == f2%ele(i))
enddo

do i = 1, size(f1%control)
  is_eq = is_eq .and. (f1%control(i) == f2%control(i))
enddo

do i = 1, size(f1%ic)
  is_eq = is_eq .and. (f1%ic(i) == f2%ic(i))
enddo

end function eq_lat

end module

