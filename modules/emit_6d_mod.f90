! Note: A negative emittance is possible and just means that the beam is
! unstable. That is, the corresponding damping partition number is negative.

!+
! Module emit_6d_mod
!
! Module for calculating the equilibrium sigma matrix for a closed geometry lattice.
!-

module emit_6d_mod

use mode3_mod

implicit none

type rad1_map_struct
  real(rp) :: damp_mat(6,6) = 0        ! Damping part of the transfer matrix 
  real(rp) :: stoc_var_mat(6,6) = 0    ! Stochastic matrix.
end type

contains

!-------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------
!+
! Subroutine emit_6d (ele_ref, include_opening_angle, sigma_mat, emit)
!
! Routine to calculate the three normal mode emittances. Since the emattances are
! only an invariant in the limit of zero damping, the calculated emittance will
! vary depending upon the reference element.
!
! Input:
!   ele_ref               -- ele_struct: Origin of the 1-turn maps used to evaluate the emittances.
!   include_opening_angle -- logical: If True include the effect of the vertical opening angle of emitted radiation.
!                             Generally use True unless comparing against other codes.
!
! Output:
!   sigma_mat(6,6)  -- real(rp): Sigma matrix
!   emit(3)         -- real(rp): The three normal mode emittances.
!-

subroutine emit_6d (ele_ref, include_opening_angle, sigma_mat, emit)

use f95_lapack, only: dgesv_f95

type (ele_struct) ele_ref

real(rp) sigma_mat(6,6), emit(3), rf65
real(rp) damp_xfer_mat(6,6), stoc_var_mat(6,6)
real(rp) mt(21,21), v_sig(21,1)

integer i, j, k, ipev(21), info

integer, parameter :: w1(21) = [1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 6]
integer, parameter :: w2(21) = [1, 2, 3, 4, 5, 6, 2, 3, 4, 5, 6, 3, 4, 5, 6, 4, 5, 6, 5, 6, 6]
integer, parameter :: v(6,6) = reshape( &
            [1,  2,  3,  4,  5,  6,   2,  7,  8,  9, 10, 11,   3,  8, 12, 13, 14, 15, &
             4,  9, 13, 16, 17, 18,   5, 10, 14, 17, 19, 20,   6, 11, 15, 18, 20, 21], [6,6])

logical include_opening_angle, err, rf_off

! Analysis is documented in the Bmad manual.

call damping_and_stochastic_rad_mats (ele_ref, ele_ref, include_opening_angle, damp_xfer_mat, stoc_var_mat)

! If there is no RF then add a small amount to enable the calculation to proceed.
! The RF is modeled as a unit matrix with M(6,5) = 1d-4.

rf_off = (damp_xfer_mat(6,5) == 0)
if (rf_off) then
  rf65 = 1e-4
  damp_xfer_mat(6,:) = damp_xfer_mat(6,:) + rf65 * damp_xfer_mat(5,:)
  stoc_var_mat(6,:) = stoc_var_mat(6,:) + rf65 * stoc_var_mat(5,:)
  stoc_var_mat(:,6) = stoc_var_mat(:,6) + stoc_var_mat(:,5) * rf65
endif

! The 6x6 sigma matrix equation is recast as a linear 21x21 matrix equation and solved.

call mat_make_unit(mt)

do i = 1, 21
  v_sig(i,1) = stoc_var_mat(w1(i), w2(i))

  do j = 1, 6
  do k = 1, 6
    mt(i,v(j,k)) = mt(i,v(j,k)) - damp_xfer_mat(w1(i),j) * damp_xfer_mat(w2(i),k)
  enddo
  enddo
enddo

call dgesv_f95(mt, v_sig, ipev, info)

if (info /= 0) then
  sigma_mat = -1
  emit = -1
  return
endif

do j = 1, 6
do k = 1, 6
  sigma_mat(j,k) = v_sig(v(j,k), 1)
enddo
enddo

call get_emit_from_sigma_mat(sigma_mat, emit, err_flag = err)
if (rf_off) emit(3) = -1

end subroutine emit_6d

!-------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------
!+
! Subroutine damping_and_stochastic_rad_mats (ele1, ele2, include_opening_angle, damp_xfer_mat, stoc_var_mat)
!
! Routine to calculate the damping and stochastic variance matrices from exit end of ele1
! to the exit end of ele2. Use ele1 = ele2 to get 1-turn matrices.
!
! If ele2 is before ele1 the integration range if from ele1 to the branch end plus 
! from the beginning to ele2.
!
! Note: The ele%mat6 matrices will be remade. By convention, these matrices
! do not include damping.
!
! Input:
!   ele1                  -- ele_struct: Start element of integration range.
!   ele2                  -- ele_struct: End element of integration range.
!   include_opening_angle -- logical: If True include the effect of the vertical opening angle of emitted radiation.
!                             Generally use True unless comparing against other codes.
!
! Output:
!   damp_xfer_mat(6,6)   -- real(rp): Transfer matrix with damping.
!   stoc_var_mat(6,6)   -- real(rp): Stochastic variance matrix.
!-

subroutine damping_and_stochastic_rad_mats (ele1, ele2, include_opening_angle, damp_xfer_mat, stoc_var_mat)

type (ele_struct), target :: ele1, ele2
type (branch_struct), pointer :: branch
type (ele_struct), pointer :: ele1_track, ele2_track, ele3
type (bmad_common_struct) bmad_com_save
type (rad1_map_struct), allocatable :: ds(:)
type (coord_struct), allocatable :: closed_orb(:)

real(rp) sig_mat(6,6)
real(rp) damp_xfer_mat(6,6), stoc_var_mat(6,6), mt(6,6)
real(rp) :: g2_ave, g3_ave, tol
integer ie

logical include_opening_angle, err_flag

!

call find_element_ends(ele1, ele3, ele1_track)
call find_element_ends(ele2, ele3, ele2_track)

branch => ele1_track%branch
allocate (ds(branch%n_ele_track))

bmad_com_save = bmad_com
bmad_com%radiation_fluctuations_on = .false.

if (rf_is_on(branch)) then
  bmad_com%radiation_damping_on = .true.
  call closed_orbit_calc(branch%lat, closed_orb, 6, +1, branch%ix_branch, err_flag)
else
  bmad_com%radiation_damping_on = .false.
  call closed_orbit_calc(branch%lat, closed_orb, 4, +1, branch%ix_branch, err_flag)
endif

bmad_com = bmad_com_save
if (err_flag) return

call lat_make_mat6 (ele1_track%branch%lat, -1, closed_orb, branch%ix_branch, err_flag)
if (err_flag) return

! Calc typical radiation values to get an error tolerance.

g2_ave = 0; g3_ave = 0
do ie = 1, branch%n_ele_track
  ele3 => branch%ele(ie)
  if (ele3%key /= sbend$) cycle
  g2_ave = g2_ave + ele3%value(l$) * ele3%value(g$)**2
  g3_ave = g3_ave + ele3%value(l$) * ele3%value(g$)**3
enddo

! Calculate element-by-element damping and stochastic mats.

tol = 1d-4 / branch%param%total_length
do ie = 1, branch%n_ele_track
  call qromb_rad_mat_int(branch%ele(ie), include_opening_angle, closed_orb(ie-1), closed_orb(ie), ds(ie), tol*g2_ave, tol*g3_ave)
enddo

!

call mat_make_unit(damp_xfer_mat)
stoc_var_mat = 0

ie = ele1_track%ix_ele
do 
  ie = ie + 1
  if (ie > branch%n_ele_track) ie = 0
  if (ie /= 0) then
    ele3 => branch%ele(ie)
    mt = ds(ie)%damp_mat + ele3%mat6
    damp_xfer_mat = matmul(mt, damp_xfer_mat)
    stoc_var_mat = matmul(matmul(mt, stoc_var_mat), transpose(mt)) + ds(ie)%stoc_var_mat
  endif
  if (ie == ele2%ix_ele) exit
enddo

end subroutine damping_and_stochastic_rad_mats

!---------------------------------------------------------------------------------
!---------------------------------------------------------------------------------
!---------------------------------------------------------------------------------

! This is adapted from qromb and trapzd from Numerical Recipes.

subroutine qromb_rad_mat_int (ele, include_opening_angle, orb_in, orb_out, ds, damp_abs_tol, stoc_abs_tol)

use super_recipes_mod, only: super_polint

!

type qromb_pt1_struct
  real(rp) xmat(6,6)  ! Transfer map without damping from beginning of element
end type

type qromb_int_struct
  real(rp) h
  real(rp) damp_mat(6,6)  
  real(rp) stoc_var_mat(6,6) 
end type

type (ele_struct) ele
type (coord_struct) orb_in, orb_out, orb0, orb1, orb_end
type (rad1_map_struct) :: ds
type (fringe_field_info_struct) fringe_info
type (qromb_pt1_struct) pt1(0:16)
type (qromb_int_struct) qi(0:4)
type (bmad_common_struct) bmad_com_save

real(rp) damp_mat1(6,6), stoc_var_mat1(6,6), damp_abs_tol, stoc_abs_tol, gamma
real(rp) mat0(6,6), mat1(6,6), ddamp(6,6), dstoc(6,6), damp_mat_sum(6,6), stoc_var_mat_sum(6,6), mat0_inv(6,6)
real(rp) del_z, l_ref, rel_tol, eps_damp, eps_stoc, z_pos, d_max, mat_end(6,6)
real(rp) kd_coef, kf_coef, radi
real(rp), parameter :: cd = 2.0_rp / 3.0_rp, cf = 55.0_rp * h_bar_planck * c_light / (24.0_rp * sqrt_3)

integer j, j1, i1, i2, n, j_min_test, ll, n_pts
integer :: j_max = 10

logical include_opening_angle, save_orb_mat

! No radiation cases

if (ele%value(l$) == 0 .or. (orb_out%vec(2) == orb_in%vec(2) .and. &
                         orb_out%vec(4) == orb_in%vec(4) .and. ele%key /= sbend$)) then
  ds%damp_mat = 0
  ds%stoc_var_mat = 0
  return
endif

!

bmad_com_save = bmad_com
bmad_com%radiation_fluctuations_on = .false.
bmad_com%radiation_damping_on = .false.

! Offsets and fringes at upstream end.

orb0 = orb_in

call mat_make_unit(mat0)
call offset_particle (ele, set$, orb0, set_hvkicks = .false., mat6 = mat0, make_matrix = .true.)
call init_fringe_info (fringe_info, ele)
if (fringe_info%has_fringe) then
  fringe_info%particle_at = first_track_edge$
  call apply_element_edge_kick(orb0, fringe_info, ele, ele%branch%param, .false., mat0, .true.)
endif

! Integrate through body.

qi(0)%h = 4
qi(0)%damp_mat = 0
qi(0)%stoc_var_mat = 0

call convert_pc_to (ele%value(p0c$), ele%ref_species, gamma = gamma)
radi = classical_radius(ele%ref_species)
kd_coef = cd * radi * gamma**3
kf_coef = cf * radi * gamma**5 / mass_of(ele%ref_species)

eps_damp = kd_coef * damp_abs_tol * ele%value(l$)
eps_stoc = kf_coef * stoc_abs_tol * ele%value(l$)

j_min_test = 3
if (ele%key == wiggler$ .or. ele%key == undulator$) then
  j_min_test = 5
endif

do j = 1, j_max
  if (j == 1) then
    n_pts = 2
    del_z = ele%value(l$)
    l_ref = 0
  else
    n_pts = 2**(j-2)
    del_z = ele%value(l$) / n_pts
    l_ref = del_z / 2
  endif

  damp_mat_sum = 0
  stoc_var_mat_sum = 0

  do n = 1, n_pts
    z_pos = l_ref + (n-1) * del_z
    save_orb_mat = (j == 1 .and. n == 1)  ! Save if z-position at end of element
    call calc_rad_at_pt(ele, include_opening_angle, orb0, z_pos, damp_mat1, stoc_var_mat1, save_orb_mat, orb_end, mat_end)
    damp_mat_sum = damp_mat_sum + damp_mat1 
    stoc_var_mat_sum = stoc_var_mat_sum + stoc_var_mat1 
  enddo

  j1 = min(j, 4)
  if (j > 4) qi(0:3) = qi(1:4)
  qi(j1)%h = 0.25_rp * qi(j1-1)%h
  qi(j1)%damp_mat = 0.5_rp * (qi(j1-1)%damp_mat + del_z * damp_mat_sum)
  qi(j1)%stoc_var_mat = 0.5_rp * (qi(j1-1)%stoc_var_mat + del_z * stoc_var_mat_sum)

  if (j < j_min_test) cycle

  do i1 = 1, 6
    do i2 = 1, 6
      call super_polint(qi(1:j1)%h, qi(1:j1)%damp_mat(i1,i2), 0.0_rp, damp_mat1(i1,i2), ddamp(i1,i2))
      call super_polint(qi(1:j1)%h, qi(1:j1)%stoc_var_mat(i1,i2), 0.0_rp, stoc_var_mat1(i1,i2), dstoc(i1,i2))
    enddo
  enddo
  d_max = max(eps_damp*maxval(abs(ddamp)), eps_stoc*maxval(abs(dstoc)))
  if (d_max < 1) exit
enddo

! Add bend edge if needed

if (ele%key == sbend$) then
  if (ele%orientation == 1) then
    call add_bend_edge_to_damp_mat(damp_mat1, ele, ele%value(e1$), orb0)
    call add_bend_edge_to_damp_mat(damp_mat1, ele, ele%value(e2$), orb_end, mat_end)
  else
    call add_bend_edge_to_damp_mat(damp_mat1, ele, ele%value(e2$), orb0)
    call add_bend_edge_to_damp_mat(damp_mat1, ele, ele%value(e1$), orb_end, mat_end)
  endif
endif

! Reference position for matrices are the element exit end

mat0_inv = mat_symp_conj(mat0)   ! mat0 is transport matrix through the upstream edge
ds%damp_mat = matmul(matmul(matmul(ele%mat6, mat0_inv), damp_mat1), mat0)

ds%stoc_var_mat = matmul(matmul(mat0_inv, stoc_var_mat1), transpose(mat0_inv))
ds%stoc_var_mat = matmul(matmul(ele%mat6, stoc_var_mat1), transpose(ele%mat6))

bmad_com = bmad_com_save

!---------------------------------------------------------------------------------
contains

subroutine calc_rad_at_pt (ele, include_opening_angle, orb0, z_pos, damp_mat1, stoc_var_mat1, save_orb_mat, orb_save, mat_save)

type (ele_struct) ele, runt
type (coord_struct) orb0, orbz, orb_save  ! Orbit at start, orbit at z.

real(rp) z_pos, damp_mat1(6,6), stoc_var_mat1(6,6), g(3), dg(3,3), g2, dg2_dx, dg2_dy
real(rp) mb(6,6), mb_inv(6,6), kf, kv, rel_p, v(6), mat_save(6,6)

integer i, j

logical include_opening_angle, save_orb_mat, err_flag

! Note: g from g_bending_strength_from_em_field is g of the actual particle and not the ref particle
! so g has a factor of 1/(1 + pz) in it.

call create_element_slice (runt, ele, z_pos, 0.0_rp, ele%branch%param, .false., .false., err_flag, pointer_to_next_ele(ele, -1))
call track1(orb0, runt, ele%branch%param, orbz)
call make_mat6(runt, ele%branch%param, orb0, orbz)
if (save_orb_mat) then
  orb_save = orbz
  mat_save = runt%mat6
endif

mb = mat_symp_conj(runt%mat6)   ! matrix from z_pos back to 0

call g_bending_strength_from_em_field (ele, ele%branch%param, z_pos, orbz, .true., g, dg)
v = orbz%vec
rel_p = 1 + v(6)
g = g * rel_p
dg = dg * rel_p

g2 = sum(g*g)
dg2_dx = 2 * dot_product(g, dg(:,1))
dg2_dy = 2 * dot_product(g, dg(:,2))

if (ele%key == sbend$) then
  g2 = g2 * (1 + ele%value(g$) * orb0%vec(1))  ! Variation in path length effect
  dg2_dx = dg2_dx * (1 + ele%value(g$) * orb0%vec(1)) + g2*ele%value(g$)
endif

! Damping matrix

damp_mat1(:,1) = -kd_coef * (mb(:,2)*dg2_dx*v(2)*rel_p + mb(:,4)*dg2_dx*v(4)*rel_p + mb(:,6)*dg2_dx*rel_p**2)
damp_mat1(:,2) = -kd_coef * (mb(:,2)*g2*rel_p) 
damp_mat1(:,3) = -kd_coef * (mb(:,2)*dg2_dy*v(2)*rel_p + mb(:,4)*dg2_dy*v(4)*rel_p + mb(:,6)*dg2_dy*rel_p**2)
damp_mat1(:,4) = -kd_coef * (mb(:,4)*g2*rel_p)
damp_mat1(:,5) =  0
damp_mat1(:,6) = -kd_coef * (mb(:,2)*g2*v(2) + mb(:,4)*g2*v(4) + mb(:,6)*2*g2*rel_p)

damp_mat1 = matmul(damp_mat1, mat_symp_conj(mb))

! Stochastic matrix

kf = kf_coef * rel_p**2 * sqrt(g2)**3
forall (i = 1:6)
  stoc_var_mat1(i,:) = kf * (rel_p**2 * mb(i,6)*mb(:,6) + v(2)**2 * mb(i,2)*mb(:,2) + v(4)**2 * mb(i,4)*mb(:,4) + &
                                rel_p * v(2) * (mb(i,2) * mb(:,6) + mb(i,6) * mb(:,2)) + &
                                rel_p * v(4) * (mb(i,4) * mb(:,6) + mb(i,6) * mb(:,4)) + &
                                v(2) * v(4) * (mb(i,2) * mb(:,4) + mb(i,4) * mb(:,2)))
end forall

if (include_opening_angle) then
  kv = kf_coef * 13.0_rp * sqrt(g2) / (55.0_rp * gamma**2)
  forall (i = 1:6)
    stoc_var_mat1(i,:) = stoc_var_mat1(i,:) + kv * (g(2)**2 * mb(i,2)*mb(:,2) + g(1)**2 * mb(i,4)*mb(:,4) - &
                                  g(1) * g(2) * (mb(i,2) * mb(:,4) + mb(i,4) * mb(:,2)))
  end forall
endif

end subroutine calc_rad_at_pt

!---------------------------------------------------------------------------------
! contains

subroutine add_bend_edge_to_damp_mat(damp_mat, ele, e_edge, orb, mat)

type (ele_struct) ele
type (coord_struct) orb
real(rp) damp_mat(6,6), e_edge, dm(6,6), dg2_dx, rel_p
real(rp), optional :: mat(6,6)

!

if (e_edge == 0) return

dg2_dx = -tan(e_edge) * (ele%value(g$) + ele%value(dg$))**2
rel_p = 1 + orb%vec(6)

dm = 0
dm(2,1:3) = -kd_coef * [dg2_dx * orb%vec(2) * rel_p, 0.0_rp, -dg2_dx * orb%vec(2) * rel_p]
dm(4,1:3) = -kd_coef * [dg2_dx * orb%vec(4) * rel_p, 0.0_rp, -dg2_dx * orb%vec(4) * rel_p]
dm(6,1:3) = -kd_coef * [dg2_dx * rel_p**2,           0.0_rp, -dg2_dx * rel_p**2]

if (present(mat)) then
  dm = matmul(matmul(mat_symp_conj(mat), dm), mat)
endif

damp_mat = damp_mat + dm

end subroutine add_bend_edge_to_damp_mat

end subroutine qromb_rad_mat_int

end module
