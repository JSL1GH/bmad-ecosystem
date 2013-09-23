!+
! Subroutine make_mat6_bmad (ele, param, c0, c1, end_in, err)
!
! Subroutine to make the 6x6 transfer matrix for an element. 
!
! Modules needed:
!   use bmad
!
! Input:
!   ele    -- Ele_struct: Element with transfer matrix
!   param  -- lat_param_struct: Parameters are needed for some elements.
!   c0     -- Coord_struct: Coordinates at the beginning of element. 
!   end_in -- Logical, optional: If present and True then the end coords c1
!               will be taken as input. Not output as normal.
!
! Output:
!   ele    -- Ele_struct: Element with transfer matrix.
!     %vec0  -- 0th order map component
!     %mat6  -- 6x6 transfer matrix.
!   c1     -- Coord_struct: Coordinates at the end of element.
!   err    -- Logical, optional: Set True if there is an error. False otherwise.
!-

subroutine make_mat6_bmad (ele, param, c0, c1, end_in, err)

use track1_mod, dummy => make_mat6_bmad
use mad_mod, dummy1  => make_mat6_bmad

implicit none

type (ele_struct), target :: ele
type (ele_struct) :: temp_ele1, temp_ele2
type (coord_struct) :: c0, c1
type (coord_struct) :: c00, c11, c_int
type (coord_struct) orb, c0_off, c1_off
type (lat_param_struct)  param

real(rp), pointer :: mat6(:,:), v(:)

real(rp) mat6_pre(6,6), mat6_post(6,6), mat6_i(6,6)
real(rp) mat4(4,4), m2(2,2), kmat4(4,4), om_g, om, om_g2
real(rp) angle, k1, ks, length, e2, g, g_err, coef
real(rp) k2l, k3l, c2, s2, cs, del_l, beta_ref, c_min, c_plu, dc_min, dc_plu
real(rp) factor, kmat6(6,6), drift(6,6), w_inv(3,3)
real(rp) s_pos, s_pos_old, z_slice(100), dr(3), axis(3), w_mat(3,3)
real(rp) knl(0:n_pole_maxx), tilt(0:n_pole_maxx)
real(rp) c_e, c_m, gamma_old, gamma_new, voltage, sqrt_8
real(rp) arg, rel_p, rel_p2, dp_dg, dp_dg_dz1, dp_dg_dpz1
real(rp) cy, sy, k2, s_off, x_pitch, y_pitch, y_ave, k_z
real(rp) dz_x(3), dz_y(3), ddz_x(3), ddz_y(3), xp_start, yp_start
real(rp) t5_11, t5_14, t5_22, t5_23, t5_33, t5_34, t5_44
real(rp) t1_16, t1_26, t1_36, t1_46, t2_16, t2_26, t2_36, t2_46
real(rp) t3_16, t3_26, t3_36, t3_46, t4_16, t4_26, t4_36, t4_46
real(rp) lcs, lc2s2, k, L, m55, m65, m66, new_pc, new_beta
real(rp) cos_phi, sin_phi, cos_term, dcos_phi, gradient_net, e_start, e_end, e_ratio, pc, p0c
real(rp) alpha, sin_a, cos_a, f, phase0, phase, t0, dt_ref, E, pxy2, dE
real(rp) g_tot, rho, ct, st, x, px, y, py, z, pz, Dxy, Dy, px_t
real(rp) Dxy_t, dpx_t, df_dpy, df_dp, kx_1, ky_1, kx_2, ky_2
real(rp) mc2, pc_start, pc_end, pc_start_ref, pc_end_ref, gradient_max, voltage_max
real(rp) beta_start, beta_end
real(rp) dbeta1_dE1, dbeta2_dE2, dalpha_dt1, dalpha_dE1, dcoef_dt1, dcoef_dE1, z21, z22
real(rp) drp1_dr0, drp1_drp0, drp2_dr0, drp2_drp0, xp1, xp2, yp1, yp2
real(rp) dp_long_dpx, dp_long_dpy, dp_long_dpz, dalpha_dpx, dalpha_dpy, dalpha_dpz
real(rp) Dy_dpy, Dy_dpz, dpx_t_dx, dpx_t_dpx, dpx_t_dpy, dpx_t_dpz, dp_ratio
real(rp) df_dx, df_dpx, df_dpz, deps_dx, deps_dpx, deps_dpy, deps_dpz
real(rp) dbeta_dx, dbeta_dpx, dbeta_dpy, dbeta_dpz, p_long, eps, beta 
real(rp) dfactor_dx, dfactor_dpx, dfactor_dpy, dfactor_dpz, factor1, factor2, s_ent, ds_ref

integer i, n_slice, key, ix_fringe

real(rp) charge_dir, hkick, vkick, kick

logical, optional :: end_in, err
logical err_flag, has_nonzero_pole
character(16), parameter :: r_name = 'make_mat6_bmad'

!--------------------------------------------------------
! init

if (present(err)) err = .false.

mat6 => ele%mat6
v => ele%value

call mat_make_unit (mat6)
ele%vec0 = 0

length = v(l$)
rel_p = 1 + c0%vec(6) 
key = ele%key

charge_dir = param%rel_tracking_charge * ele%orientation
c00 = c0
c00%direction = +1

if (.not. logic_option (.false., end_in)) then
  if (ele%tracking_method == linear$) then
    c00%state = alive$
    call track1_bmad (c00, ele, param, c1)
  else
    call track1 (c00, ele, param, c1)
  endif
  ! If the particle has been lost in tracking this is an error.
  ! Exception: A match element with match_end set to True. 
  ! Here the problem is most likely that twiss_propagate_all has not yet 
  ! been called so ignore this case.
  if (c1%state /= alive$ .and. (ele%key /= match$ .or. v(match_end$) == 0)) then
    mat6 = 0
    if (present(err)) err = .true.
    call out_io (s_error$, r_name, 'PARTICLE LOST IN TRACKING AT: ' // ele%name)
    return
  endif
endif

c11 = c1

!--------------------------------------------------------
! Drift or element is off.

if (.not. ele%is_on .and. key /= lcavity$ .and. key /= sbend$) key = drift$

if (any (key == [drift$, capillary$])) then
  call offset_particle (ele, c00, param, set$, set_canonical = .false., set_tilt = .false.)
  call drift_mat6_calc (mat6, length, ele, param, c00)
  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)
  return
endif

!--------------------------------------------------------
! selection

if (key == sol_quad$ .and. v(k1$) == 0) key = solenoid$

select case (key)

!--------------------------------------------------------
! beam-beam interaction

case (beambeam$)

 call offset_particle (ele, c00, param, set$)
 call offset_particle (ele, c11, param, set$, ds_pos = length)

  n_slice = nint(v(n_slice$))
  if (n_slice < 1) then
    if (present(err)) err = .true.
    call out_io (s_fatal$, r_name,  'N_SLICE FOR BEAMBEAM ELEMENT IS NEGATIVE')
    call type_ele (ele, .true., 0, .false., 0, .false.)
    return
  endif

  if (v(charge$) == 0 .or. param%n_part == 0) return

  ! factor of 2 in orb%vec(5) since relative motion of the two beams is 2*c_light

  if (n_slice == 1) then
    call bbi_kick_matrix (ele, param, c00, 0.0_rp, mat6)
  else
    call bbi_slice_calc (n_slice, v(sig_z$), z_slice)

    s_pos = 0          ! start at IP
    orb = c00
    orb%vec(2) = c00%vec(2) - v(x_pitch_tot$)
    orb%vec(4) = c00%vec(4) - v(y_pitch_tot$)
    call mat_make_unit (mat4)

    do i = 1, n_slice + 1
      s_pos_old = s_pos  ! current position
      s_pos = (z_slice(i) + c00%vec(5)) / 2 ! position of slice relative to IP
      del_l = s_pos - s_pos_old
      mat4(1,1:4) = mat4(1,1:4) + del_l * mat4(2,1:4)
      mat4(3,1:4) = mat4(3,1:4) + del_l * mat4(4,1:4)
      if (i == n_slice + 1) exit
      orb%vec(1) = c00%vec(1) + s_pos * orb%vec(2)
      orb%vec(3) = c00%vec(3) + s_pos * orb%vec(4)
      call bbi_kick_matrix (ele, param, orb, s_pos, kmat6)
      mat4(2,1:4) = mat4(2,1:4) + kmat6(2,1) * mat4(1,1:4) + &
                                  kmat6(2,3) * mat4(3,1:4)
      mat4(4,1:4) = mat4(4,1:4) + kmat6(4,1) * mat4(1,1:4) + &
                                  kmat6(4,3) * mat4(3,1:4)
    enddo

    mat6(1:4,1:4) = mat4

  endif

  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! Crystal

case (crystal$, sample$, source$)

  ! Not yet implemented

!--------------------------------------------------------
! Custom

case (custom$)

  if (present(err)) err = .true.
  call out_io (s_fatal$, r_name,  'MAT6_CALC_METHOD = BMAD_STANDARD IS NOT ALLOWED FOR A CUSTOM ELEMENT: ' // ele%name)
  if (global_com%exit_on_error) call err_exit
  return

!-----------------------------------------------
! elseparator

case (elseparator$)
   
   call make_mat6_mad (ele, param, c00, c11)

!--------------------------------------------------------
! Kicker

case (kicker$, hkicker$, vkicker$, rcollimator$, &
        ecollimator$, monitor$, instrument$, pipe$)

  call offset_particle (ele, c00, param, set$, set_canonical = .false., set_hvkicks = .false.)

  charge_dir = param%rel_tracking_charge * ele%orientation

  hkick = charge_dir * v(hkick$) 
  vkick = charge_dir * v(vkick$) 
  kick  = charge_dir * v(kick$) 
  
  n_slice = max(1, nint(length / v(ds_step$)))
  if (ele%key == hkicker$) then
     c00%vec(2) = c00%vec(2) + kick / (2 * n_slice)
  elseif (ele%key == vkicker$) then
     c00%vec(4) = c00%vec(4) + kick / (2 * n_slice)
  else
     c00%vec(2) = c00%vec(2) + hkick / (2 * n_slice)
     c00%vec(4) = c00%vec(4) + vkick / (2 * n_slice)
  endif

  do i = 1, n_slice 
     call track_a_drift (c00, ele, length/n_slice)
     call drift_mat6_calc (drift, length/n_slice, ele, param, c00)
     mat6 = matmul(drift,mat6)
     if (i == n_slice) then
        if (ele%key == hkicker$) then
           c00%vec(2) = c00%vec(2) + kick / (2 * n_slice)
        elseif (ele%key == vkicker$) then
           c00%vec(4) = c00%vec(4) + kick / (2 * n_slice)
        else
           c00%vec(2) = c00%vec(2) + hkick / (2 * n_slice)
           c00%vec(4) = c00%vec(4) + vkick / (2 * n_slice)
        endif
     else 
        if (ele%key == hkicker$) then
           c00%vec(2) = c00%vec(2) + kick / n_slice
        elseif (ele%key == vkicker$) then
           c00%vec(4) = c00%vec(4) + kick / n_slice
        else
           c00%vec(2) = c00%vec(2) + hkick / n_slice
           c00%vec(4) = c00%vec(4) + vkick / n_slice
        endif
     endif
  end do

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! LCavity: Linac rf cavity.
! Modified version of the ultra-relativistic formalism from:
!       J. Rosenzweig and L. Serafini
!       Phys Rev E, Vol. 49, p. 1599, (1994)
! with b_0 = b_-1 = 1. See the Bmad manual for more details.
!
! One must keep in mind that we are NOT using good canonical coordinates since
!   the energy of the reference particle is changing.
! This means that the resulting matrix will NOT be symplectic.

case (lcavity$)

  if (length == 0) return

  !

  call offset_particle (ele, c00, param, set$, .false.)

  phase = twopi * (v(phi0$) + v(dphi0$) + &
                   v(dphi0_ref$) +  v(phi0_err$) + &
                   (particle_time (c00, ele) - rf_ref_time_offset(ele)) * v(rf_frequency$))

  ! Coupler kick

  if (v(coupler_strength$) /= 0) call mat6_coupler_kick(ele, param, first_track_edge$, phase, c00, mat6)

  ! 

  cos_phi = cos(phase)
  sin_phi = sin(phase)
  gradient_max = param%rel_tracking_charge * e_accel_field (ele, gradient$)
  gradient_net = gradient_max * cos_phi + gradient_shift_sr_wake(ele, param) 
  dE = gradient_net * length

  mc2 = mass_of(param%particle)
  pc_start_ref = v(p0c_start$) 
  pc_start = pc_start_ref * (1 + c00%vec(6))
  beta_start = c00%beta
  E_start = pc_start / beta_start
  E_end = E_start + dE
  if (E_end <= 0) then
    if (present(err)) err = .true.
    call out_io (s_error$, r_name, 'END ENERGY IS NEGATIVE AT ELEMENT: ' // ele%name)
    mat6 = 0   ! garbage.
    return 
  endif

  pc_end_ref = v(p0c$)
  call convert_total_energy_to (E_end, param%particle, pc = pc_end, beta = beta_end)
  E_end = pc_end / beta_end
  E_ratio = E_end / E_start

  om = twopi * v(rf_frequency$) / c_light
  om_g = om * gradient_max * length
  dbeta1_dE1 = mc2**2 / (pc_start * E_start**2)
  dbeta2_dE2 = mc2**2 / (pc_end * E_end**2)

  ! First convert from (x, px, y, py, z, pz) to (x, x', y, y', c(t_ref-t), E) coords 

  rel_p = 1 + c00%vec(6)
  mat6(2,:) = mat6(2,:) / rel_p - c00%vec(2) * mat6(6,:) / rel_p**2
  mat6(4,:) = mat6(4,:) / rel_p - c00%vec(4) * mat6(6,:) / rel_p**2

  m2(1,:) = [1/c00%beta, -c00%vec(5) * mc2**2 * c00%p0c / (pc_start**2 * E_start)]
  m2(2,:) = [0.0_rp, c00%p0c * c00%beta]
  mat6(5:6,:) = matmul(m2, mat6(5:6,:))

  c00%vec(2) = c00%vec(2) / rel_p
  c00%vec(4) = c00%vec(4) / rel_p
  c00%vec(5) = c00%vec(5) / c00%beta 
  c00%vec(6) = rel_p * c00%p0c / c00%beta - 1

  ! Body tracking longitudinal

  kmat6 = 0
  kmat6(6,5) = om_g * sin_phi
  kmat6(6,6) = 1

  if (abs(dE) <  1e-4*(pc_end+pc_start)) then
    dp_dg = length * (1 / beta_start - mc2**2 * dE / (2 * pc_start**3) + (mc2 * dE)**2 * E_start / (2 * pc_start**5))
    kmat6(5,5) = 1 - length * (-mc2**2 * kmat6(6,5) / (2 * pc_start**3) + mc2**2 * dE * kmat6(6,5) * E_start / pc_start**5)
    kmat6(5,6) = -length * (-dbeta1_dE1 / beta_start**2 + 2 * mc2**2 * dE / pc_start**4 + &
                    (mc2 * dE)**2 / (2 * pc_start**5) - 5 * (mc2 * dE)**2 / (2 * pc_start**5))
  else
    dp_dg = (pc_end - pc_start) / gradient_net
    kmat6(5,5) = 1 - kmat6(6,5) / (beta_end * gradient_net) + kmat6(6,5) * (pc_end - pc_start) / (gradient_net**2 * length)
    kmat6(5,6) = -1 / (beta_end * gradient_net) + 1 / (beta_start * gradient_net)
  endif

  ! Body tracking transverse

  if (is_true(ele%value(traveling_wave$))) then

    kmat6(1,1) = 1
    kmat6(1,2) = length
    kmat6(2,2) = 1

    kmat6(3,3) = 1
    kmat6(3,4) = length
    kmat6(4,4) = 1

    kmat6(5,2) = -length * c00%vec(4)
    kmat6(5,4) = -length * c00%vec(4)

    c00%vec(5) = c00%vec(5) - (c00%vec(2)**2 + c00%vec(4)**2) * dp_dg / 2

    mat6 = matmul(kmat6, mat6)

    c00%vec(1:2) = matmul(kmat6(1:2,1:2), c00%vec(1:2))
    c00%vec(3:4) = matmul(kmat6(3:4,3:4), c00%vec(3:4))
    c00%vec(5) = c00%vec(5) - (dp_dg - c_light * v(delta_ref_time$))

  else
    sqrt_8 = 2 * sqrt_2
    voltage_max = gradient_max * length

    if (abs(voltage_max * cos_phi) < 1e-5 * E_start) then
      g = voltage_max / E_start
      alpha = g * (1 + g * cos_phi / 2)  / sqrt_8
      coef = length * beta_start * (1 - voltage_max * cos_phi / (2 * E_start))
      dalpha_dt1 = g * g * om * sin_phi / (2 * sqrt_8) 
      dalpha_dE1 = -(voltage_max / E_start**2 + voltage_max**2 * cos_phi / E_start**3) / sqrt_8
      dcoef_dt1 = -length * beta_start * sin_phi * om_g / (2 * E_start)
      dcoef_dE1 = length * beta_start * voltage_max * cos_phi / (2 * E_start**2) + coef * dbeta1_dE1 / beta_start
    else
      alpha = log(E_ratio) / (sqrt_8 * cos_phi)
      coef = sqrt_8 * pc_start * sin(alpha) / gradient_max
      dalpha_dt1 = kmat6(6,5) / (E_end * sqrt_8 * cos_phi) - log(E_ratio) * om * sin_phi / (sqrt_8 * cos_phi**2)
      dalpha_dE1 = 1 / (E_end * sqrt_8 * cos_phi) - 1 / (E_start * sqrt_8 * cos_phi)
      dcoef_dt1 = sqrt_8 * pc_start * cos(alpha) * dalpha_dt1 / gradient_max
      dcoef_dE1 = coef / (beta_start * pc_start) + sqrt_8 * pc_start * cos(alpha) * dalpha_dE1 / gradient_max
    endif

    cos_a = cos(alpha)
    sin_a = sin(alpha)

    z21 = -gradient_max / (sqrt_8 * pc_end)
    z22 = pc_start / pc_end  

    c_min = cos_a - sqrt_2 * beta_start * sin_a * cos_phi
    c_plu = cos_a + sqrt_2 * beta_end * sin_a * cos_phi
    dc_min = -sin_a - sqrt_2 * beta_start * cos_a * cos_phi 
    dc_plu = -sin_a + sqrt_2 * beta_end * cos_a * cos_phi 

    cos_term = 1 + 2 * beta_start * beta_end * cos_phi**2
    dcos_phi = om * sin_phi

    kmat6(1,1) =  c_min
    kmat6(1,2) =  coef 
    kmat6(2,1) =  z21 * (sqrt_2 * (beta_start - beta_end) * cos_phi * cos_a + cos_term * sin_a)
    kmat6(2,2) =  c_plu * z22

    kmat6(1,5) = c00%vec(1) * (dc_min * dalpha_dt1 - sqrt_2 * beta_start * sin_a * dcos_phi) + & 
                 c00%vec(2) * (dcoef_dt1)

    kmat6(1,6) = c00%vec(1) * (dc_min * dalpha_dE1 - sqrt_2 * dbeta1_dE1 * sin_a * cos_phi) + &
                 c00%vec(2) * (dcoef_dE1)

    kmat6(2,5) = c00%vec(1) * z21 * (sqrt_2 * (beta_start - beta_end) * (dcos_phi * cos_a - cos_phi * sin_a * dalpha_dt1)) + &
                 c00%vec(1) * z21 * sqrt_2 * (-dbeta2_dE2 * kmat6(6,5)) * cos_phi * cos_a + &
                 c00%vec(1) * z21 * (4 * beta_start * beta_end *cos_phi * dcos_phi * sin_a + cos_term * cos_a * dalpha_dt1) + &
                 c00%vec(1) * z21 * (2 * beta_start * dbeta2_dE2 * kmat6(6,5) * sin_a) + &
                 c00%vec(1) * (-kmat6(2,1) * kmat6(6,5) / (beta_end * pc_end)) + &
                 c00%vec(2) * z22 * (dc_plu * dalpha_dt1 + sqrt_2 * sin_a * (beta_end * dcos_phi + dbeta2_dE2 * kmat6(6,5) * cos_phi)) + &
                 c00%vec(2) * z22 * (-c_plu * kmat6(6,5) / (beta_end * pc_end))

    kmat6(2,6) = c00%vec(1) * z21 * (sqrt_2 * cos_phi * ((dbeta1_dE1 - dbeta2_dE2) * cos_a - (beta_start - beta_end) * sin_a * dalpha_dE1)) + &
                 c00%vec(1) * z21 * (2 * cos_phi**2 * (dbeta1_dE1 * beta_end + beta_start * dbeta2_dE2) * sin_a + cos_term * cos_a * dalpha_dE1) + &
                 c00%vec(1) * (-kmat6(2,1) / (beta_end * pc_end)) + &
                 c00%vec(2) * z22 * (dc_plu * dalpha_dE1 + sqrt_2 * dbeta2_dE2 * sin_a * cos_phi) + &
                 c00%vec(2) * c_plu * (1 / (beta_start * pc_end) - pc_start / (beta_end * pc_end**2))

    kmat6(3:4,3:4) = kmat6(1:2,1:2)

    kmat6(3,5) = c00%vec(3) * (dc_min * dalpha_dt1 - sqrt_2 * beta_start * sin_a * dcos_phi) + & 
                 c00%vec(4) * (dcoef_dt1)

    kmat6(3,6) = c00%vec(3) * (dc_min * dalpha_dE1 - sqrt_2 * dbeta1_dE1 * sin_a * cos_phi) + &
                 c00%vec(4) * (dcoef_dE1)

    kmat6(4,5) = c00%vec(3) * z21 * (sqrt_2 * (beta_start - beta_end) * (dcos_phi * cos_a - cos_phi * sin_a * dalpha_dt1)) + &
                 c00%vec(3) * z21 * sqrt_2 * (-dbeta2_dE2 * kmat6(6,5)) * cos_phi * cos_a + &
                 c00%vec(3) * z21 * (4 * beta_start * beta_end *cos_phi * dcos_phi * sin_a + cos_term * cos_a * dalpha_dt1) + &
                 c00%vec(3) * z21 * (2 * beta_start * dbeta2_dE2 * kmat6(6,5) * sin_a) + &
                 c00%vec(3) * (-kmat6(2,1) * kmat6(6,5) / (beta_end * pc_end)) + &
                 c00%vec(4) * z22 * (dc_plu * dalpha_dt1 + sqrt_2 * sin_a * (beta_end * dcos_phi + dbeta2_dE2 * kmat6(6,5) * cos_phi)) + &
                 c00%vec(4) * z22 * (-c_plu * kmat6(6,5) / (beta_end * pc_end))

    kmat6(4,6) = c00%vec(3) * z21 * (sqrt_2 * cos_phi * ((dbeta1_dE1 - dbeta2_dE2) * cos_a - (beta_start - beta_end) * sin_a * dalpha_dE1)) + &
                 c00%vec(3) * z21 * (2 * cos_phi**2 * (dbeta1_dE1 * beta_end + beta_start * dbeta2_dE2) * sin_a + cos_term * cos_a * dalpha_dE1) + &
                 c00%vec(3) * (-kmat6(2,1) / (beta_end * pc_end)) + &
                 c00%vec(4) * z22 * (dc_plu * dalpha_dE1 + sqrt_2 * dbeta2_dE2 * sin_a * cos_phi) + &
                 c00%vec(4) * c_plu * (1 / (beta_start * pc_end) - pc_start / (beta_end * pc_end**2))


    ! Correction to z for finite x', y'
    ! Note: Corrections to kmat6(5,5) and kmat6(5,6) are ignored since these are small (quadratic
    ! in the transvers coords).

    c_plu = sqrt_2 * cos_phi * cos_a + sin_a

    drp1_dr0  = -gradient_net / (2 * E_start)
    drp1_drp0 = 1

    xp1 = drp1_dr0 * c00%vec(1) + drp1_drp0 * c00%vec(2)
    yp1 = drp1_dr0 * c00%vec(3) + drp1_drp0 * c00%vec(4)

    drp2_dr0  = (c_plu * z21)
    drp2_drp0 = (cos_a * z22)

    xp2 = drp2_dr0 * c00%vec(1) + drp2_drp0 * c00%vec(2)
    yp2 = drp2_dr0 * c00%vec(3) + drp2_drp0 * c00%vec(4)

    kmat6(5,1) = -(c00%vec(1) * (drp1_dr0**2 + drp1_dr0*drp2_dr0 + drp2_dr0**2) + &
                   c00%vec(2) * (drp1_dr0 * drp1_drp0 + drp2_dr0 * drp2_drp0 + &
                                (drp1_dr0 * drp2_drp0 + drp1_drp0 * drp2_dr0) / 2)) * dp_dg / 3

    kmat6(5,2) = -(c00%vec(2) * (drp1_drp0**2 + drp1_drp0*drp2_drp0 + drp2_drp0**2) + &
                   c00%vec(1) * (drp1_dr0 * drp1_drp0 + drp2_dr0 * drp2_drp0 + &
                                (drp1_dr0 * drp2_drp0 + drp1_drp0 * drp2_dr0) / 2)) * dp_dg / 3

    kmat6(5,3) = -(c00%vec(3) * (drp1_dr0**2 + drp1_dr0*drp2_dr0 + drp2_dr0**2) + &
                   c00%vec(4) * (drp1_dr0 * drp1_drp0 + drp2_dr0 * drp2_drp0 + &
                                (drp1_dr0 * drp2_drp0 + drp1_drp0 * drp2_dr0) / 2)) * dp_dg / 3

    kmat6(5,4) = -(c00%vec(4) * (drp1_drp0**2 + drp1_drp0*drp2_drp0 + drp2_drp0**2) + &
                   c00%vec(3) * (drp1_dr0 * drp1_drp0 + drp2_dr0 * drp2_drp0 + &
                                (drp1_dr0 * drp2_drp0 + drp1_drp0 * drp2_dr0) / 2)) * dp_dg / 3

    c00%vec(5) = c00%vec(5) - (xp1**2 + xp1*xp2 + xp2**2 + yp1**2 + yp1*yp2 + yp2**2) * dp_dg / 6

    !

    mat6 = matmul(kmat6, mat6)

    c00%vec(1:2) = matmul(kmat6(1:2,1:2), c00%vec(1:2))
    c00%vec(3:4) = matmul(kmat6(3:4,3:4), c00%vec(3:4))
    c00%vec(5) = c00%vec(5) - (dp_dg - c_light * v(delta_ref_time$))

  endif

  ! Convert back from (x, x', y, y', c(t-t_ref), E)  to (x, px, y, py, z, pz) coords
  ! Here the effective t used in calculating m2 is zero so m2(1,2) is zero.

  rel_p = pc_end / pc_end_ref
  mat6(2,:) = rel_p * mat6(2,:) + c00%vec(2) * mat6(6,:) / (pc_end_ref * beta_end)
  mat6(4,:) = rel_p * mat6(4,:) + c00%vec(4) * mat6(6,:) / (pc_end_ref * beta_end)

  m2(1,:) = [beta_end, c00%vec(5) * mc2**2 / (pc_end * E_end**2)]
  m2(2,:) = [0.0_rp, 1 / (pc_end_ref * beta_end)]

  mat6(5:6,:) = matmul(m2, mat6(5:6,:))

  c00%vec(2) = c00%vec(2) / rel_p
  c00%vec(4) = c00%vec(4) / rel_p
  c00%vec(6) = (pc_end - pc_end_ref) / pc_end_ref 
  c00%p0c = pc_end_ref
  c00%beta = beta_end

  ! Coupler kick

  if (v(coupler_strength$) /= 0) call mat6_coupler_kick(ele, param, second_track_edge$, phase, c00, mat6)

  ! multipoles and z_offset

  if (v(tilt_tot$) /= 0) call tilt_mat6 (mat6, v(tilt_tot$))

  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! Marker, branch, photon_branch, etc.

case (marker$, branch$, photon_branch$, floor_shift$, fiducial$) 
  return

!--------------------------------------------------------
! Match

case (match$)
  call match_ele_to_mat6 (ele, ele%vec0, ele%mat6, err_flag)
  if (present(err)) err = err_flag

!--------------------------------------------------------
! Mirror

case (mirror$)

  mat6(1, 1) = -1
  mat6(2, 1) =  0   ! 
  mat6(2, 2) = -1
  mat6(4, 3) =  0

  if (ele%surface%has_curvature) then
    print *, 'MIRROR CURVATURE NOT YET IMPLEMENTED!'
    call err_exit
  endif

  ! Offsets?

  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! multilayer_mirror

case (multilayer_mirror$) 

  ! Not yet implemented

!--------------------------------------------------------
! Multipole, AB_Multipole

case (multipole$, ab_multipole$)

  if (.not. ele%multipoles_on) return

  call offset_particle (ele, c00, param, set$, set_canonical = .false., set_tilt = .false.)

  call multipole_ele_to_kt (ele, param, .true., has_nonzero_pole, knl, tilt)
  call multipole_kick_mat (knl, tilt, c00%vec, 1.0_rp, ele%mat6)

  ! if knl(0) is non-zero then the reference orbit itself is bent
  ! and we need to account for this.

  if (knl(0) /= 0) then
    ele%mat6(2,6) = knl(0) * cos(tilt(0))
    ele%mat6(4,6) = knl(0) * sin(tilt(0))
    ele%mat6(5,1) = -ele%mat6(2,6)
    ele%mat6(5,3) = -ele%mat6(4,6)
  endif

  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! Octupole
! the octupole is modeled as kick-drift-kick

case (octupole$)

  call offset_particle (ele, c00, param, set$, set_canonical = .false.)

  n_slice = max(1, nint(length / v(ds_step$)))

  do i = 0, n_slice
    k3l = charge_dir * v(k3$) * length / n_slice
    if (i == 0 .or. i == n_slice) k3l = k3l / 2
    call mat4_multipole (k3l, 0.0_rp, 3, c00%vec, kmat4)
    c00%vec(2) = c00%vec(2) + k3l * (3*c00%vec(1)*c00%vec(3)**2 - c00%vec(1)**3) / 6
    c00%vec(4) = c00%vec(4) + k3l * (3*c00%vec(3)*c00%vec(1)**2 - c00%vec(3)**3) / 6
    mat6(1:4,1:6) = matmul(kmat4, mat6(1:4,1:6))
    if (i /= n_slice) then
      call drift_mat6_calc (drift, length/n_slice, ele, param, c00)
      call track_a_drift (c00, ele, length/n_slice)
      mat6 = matmul(drift,mat6)
    end if
  end do

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! Patch

case (patch$) 

  if (ele%field_calc == custom$) then
    call out_io (s_fatal$, r_name, 'MAT6_CALC_METHOD=BMAD_STANDARD CANNOT HANDLE FIELD_CALC=CUSTOM', &
                                   'FOR PATCH ELEMENT: ' // ele%name)
    if (global_com%exit_on_error) call err_exit
    return
  endif

  mc2 = mass_of(param%particle)
  c00%vec(5) = 0
  call track_a_patch (ele, c00, .false., s_ent, ds_ref, w_inv)
  dp_ratio = v(p0c_start$) / v(p0c$)
  pz = sqrt(rel_p**2 - c0%vec(2)**2 - c0%vec(4)**2)
  beta_ref = v(p0c$) / v(e_tot$)
  mat6(1,:) = [w_inv(1,1), 0.0_rp, w_inv(1,2), 0.0_rp, 0.0_rp, 0.0_rp]
  mat6(3,:) = [w_inv(2,1), 0.0_rp, w_inv(2,2), 0.0_rp, 0.0_rp, 0.0_rp]

  mat6(2,:) = [0.0_rp, dp_ratio * (w_inv(1,1) - w_inv(1,3) * c0%vec(2) / pz), &
               0.0_rp, dp_ratio * (w_inv(1,2) - w_inv(1,3) * c0%vec(4) / pz), 0.0_rp, w_inv(1,3) * rel_p * dp_ratio / pz]
  mat6(4,:) = [0.0_rp, dp_ratio * (w_inv(2,1) - w_inv(2,3) * c0%vec(2) / pz), &
               0.0_rp, dp_ratio * (w_inv(2,2) - w_inv(2,3) * c0%vec(4) / pz), 0.0_rp, w_inv(2,3) * rel_p * dp_ratio / pz]

  mat6(5,:) = [0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, 1.0_rp, &
                                      v(t_offset$) * c_light * mc2**2 * c0%beta**3 / (v(p0c_start$)**2 * rel_p**3)]
  mat6(6,:) = [0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, v(p0c_start$) / v(p0c$)]

  rel_p = 1 + c00%vec(6)
  pz = sqrt(rel_p**2 - c00%vec(2)**2 - c00%vec(4)**2)
  call drift_mat6_calc (mat6_post, -s_ent, ele, param, c00)

  mat6_post(5,6) =  -s_ent * (c00%vec(2)**2 + c00%vec(4)**2) / pz**3 + &
                            ds_ref * mc2**2 * c00%beta**3 / (rel_p**3 * v(p0c$)**2 * beta_ref)

  ! These matrix terms are due to the variation of s_ent drift length
  mat6_post(1,1) = mat6_post(1,1) + (w_inv(1,3) / w_inv(3,3)) * c00%vec(2) / pz
  mat6_post(1,3) = mat6_post(1,3) + (w_inv(2,3) / w_inv(3,3)) * c00%vec(2) / pz

  mat6_post(3,1) = mat6_post(3,1) + (w_inv(1,3) / w_inv(3,3)) * c00%vec(4) / pz
  mat6_post(3,3) = mat6_post(3,3) + (w_inv(2,3) / w_inv(3,3)) * c00%vec(4) / pz

  mat6_post(5,1) = mat6_post(5,1) - (w_inv(1,3) / w_inv(3,3)) * rel_p / pz
  mat6_post(5,3) = mat6_post(5,3) - (w_inv(2,3) / w_inv(3,3)) * rel_p / pz

  mat6 = matmul (mat6_post, mat6)

  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! quadrupole

case (quadrupole$)

  call offset_particle (ele, c00, param, set$)
  call offset_particle (ele, c11, param, set$, ds_pos = length)
  
  ix_fringe = nint(v(fringe_type$))
  k1 = v(k1$) * charge_dir / rel_p

  call quad_mat2_calc (-k1, length, mat6(1:2,1:2), dz_x, c0%vec(6), ddz_x)
  call quad_mat2_calc ( k1, length, mat6(3:4,3:4), dz_y, c0%vec(6), ddz_y)

  mat6(1,2) = mat6(1,2) / rel_p
  mat6(2,1) = mat6(2,1) * rel_p

  mat6(3,4) = mat6(3,4) / rel_p
  mat6(4,3) = mat6(4,3) * rel_p

  ! The mat6(i,6) terms are constructed so that mat6 is sympelctic

  if (ix_fringe == full_straight$ .or. ix_fringe == full_bend$) then
    c_int = c00
    call quadrupole_edge_kick (ele, first_track_edge$, c00)
    call quadrupole_edge_kick (ele, first_track_edge$, c11) ! Yes first edge since we are propagating backwards.
  endif

  if (any(c00%vec(1:4) /= 0)) then
    mat6(5,1) = 2 * c00%vec(1) * dz_x(1) +     c00%vec(2) * dz_x(2)
    mat6(5,2) =    (c00%vec(1) * dz_x(2) + 2 * c00%vec(2) * dz_x(3)) / rel_p
    mat6(5,3) = 2 * c00%vec(3) * dz_y(1) +     c00%vec(4) * dz_y(2)
    mat6(5,4) =    (c00%vec(3) * dz_y(2) + 2 * c00%vec(4) * dz_y(3)) / rel_p
    mat6(5,6) = c00%vec(1)**2 * ddz_x(1) + c00%vec(1)*c00%vec(2) * ddz_x(2) + c00%vec(2)**2 * ddz_x(3)  + &
                c00%vec(3)**2 * ddz_y(1) + c00%vec(3)*c00%vec(4) * ddz_y(2) + c00%vec(4)**2 * ddz_y(3)  
  endif

  if (any(mat6(5,1:4) /= 0)) then
    mat6(1,6) = mat6(5,2) * mat6(1,1) - mat6(5,1) * mat6(1,2)
    mat6(2,6) = mat6(5,2) * mat6(2,1) - mat6(5,1) * mat6(2,2)
    mat6(3,6) = mat6(5,4) * mat6(3,3) - mat6(5,3) * mat6(3,4)
    mat6(4,6) = mat6(5,4) * mat6(4,3) - mat6(5,3) * mat6(4,4)
  endif

  call quad_mat6_edge_effect (ele, k1, c_int, c11, mat6)

  ! tilt and multipoles

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  call add_M56_low_E_correction()
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! rbends are not allowed internally

case (rbend$)

  if (present(err)) err = .true.
  call out_io (s_fatal$, r_name,  'RBEND ELEMENTS NOT ALLOWED INTERNALLY!')
  if (global_com%exit_on_error) call err_exit
  return

!--------------------------------------------------------
! rf cavity
! Calculation Uses a 3rd order map assuming a linearized rf voltage vs time.

case (rfcavity$)

  mc2 = mass_of(param%particle)
  p0c = v(p0c$)
  beta_ref = p0c / v(e_tot$)
  n_slice = max(1, nint(length / v(ds_step$))) 
  dt_ref = length / (c_light * beta_ref)

  call offset_particle (ele, c00, param, set$, set_canonical = .false., set_tilt = .false.)

  voltage = param%rel_tracking_charge * e_accel_field (ele, voltage$)

  ! The cavity field is modeled as a standing wave symmetric wrt the center.
  ! Thus if the cavity is flipped (orientation = -1), the wave of interest, which is 
  ! always the accelerating wave, is the "backward" wave. And the phase of the backward 
  ! wave is different from the phase of the forward wave by a constant dt_ref * freq

  phase0 = twopi * (v(phi0$) + v(dphi0$) - v(dphi0_ref$) - &
                  (particle_time (c00, ele) - rf_ref_time_offset(ele)) * v(rf_frequency$))
  if (ele%orientation == -1) phase0 = phase0 + twopi * v(rf_frequency$) * dt_ref
  phase = phase0

  t0 = c00%t

  ! Track through slices.
  ! The phase of the accelerating wave traveling in the same direction as the particle is
  ! assumed to be traveling with a phase velocity the same speed as the reference velocity.

  if (v(coupler_strength$) /= 0) call mat6_coupler_kick(ele, param, first_track_edge$, phase, c00, mat6)

  do i = 0, n_slice

    factor = voltage / n_slice
    if (i == 0 .or. i == n_slice) factor = factor / 2

    dE = factor * sin(phase)
    pc = (1 + c00%vec(6)) * p0c 
    E = pc / c00%beta
    call convert_total_energy_to (E + dE, param%particle, pc = new_pc, beta = new_beta)
    f = twopi * factor * v(rf_frequency$) * cos(phase) / (p0c * new_beta * c_light)

    m2(2,1) = f / c00%beta
    m2(2,2) = c00%beta / new_beta - f * c00%vec(5) *mc2**2 * p0c / (E * pc**2) 
    m2(1,1) = new_beta / c00%beta + c00%vec(5) * (mc2**2 * p0c * m2(2,1) / (E+dE)**3) / c00%beta
    m2(1,2) = c00%vec(5) * mc2**2 * p0c * (m2(2,2) / ((E+dE)**3 * c00%beta) - new_beta / (pc**2 * E))

    mat6(5:6, :) = matmul(m2, mat6(5:6, :))
  
    c00%vec(6) = (new_pc - p0c) / p0c
    c00%vec(5) = c00%vec(5) * new_beta / c00%beta
    c00%beta   = new_beta

    if (i /= n_slice) then
      call drift_mat6_calc (drift, length/n_slice, ele, param, c00)
      call track_a_drift (c00, ele, length/n_slice)
      mat6 = matmul(drift, mat6)
      phase = phase0 + twopi * v(rf_frequency$) * ((i + 1) * dt_ref/n_slice - (c00%t - t0)) 
    endif

  enddo

  ! Coupler kick

  if (v(coupler_strength$) /= 0) call mat6_coupler_kick(ele, param, second_track_edge$, phase, c00, mat6)

  call offset_particle (ele, c00, param, unset$, set_canonical = .false., set_tilt = .false.)

  !

  if (v(tilt_tot$) /= 0) call tilt_mat6 (mat6, v(tilt_tot$))

  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! sbend

case (sbend$)

  k1 = v(k1$) * charge_dir
  k2 = v(k2$) * charge_dir
  g = v(g$)
  rho = 1 / g
  g_tot = (g + v(g_err$)) * charge_dir
  g_err = g_tot - g

  if (.not. ele%is_on) then
    g_err = 0
    g_tot = -g
    k1 = 0
    k2 = 0
  endif

  ! Reverse track here for c11 since c11 needs to be the orbit just inside the bend.
  ! Notice that kx_2 and ky_2 are not affected by reverse tracking

  ! Entrance edge kick

  call offset_particle (ele, c00, param, set$, set_canonical = .false.)
  c0_off = c00

  call bend_edge_kick (c00, ele, param, first_track_edge$, .false., mat6_pre)

  ! Exit edge kick
  
  call offset_particle (ele, c11, param, set$, set_canonical = .false., ds_pos = length)
  c1_off = c11 

  call bend_edge_kick (c11, ele, param, second_track_edge$, .false., mat6_post)

  ! If we have a sextupole component then step through in steps of length ds_step

  call multipole_ele_to_kt(ele, param, .true., has_nonzero_pole, knl, tilt)

  n_slice = 1  
  if (k2 /= 0 .or. has_nonzero_pole) n_slice = max(nint(v(l$) / v(ds_step$)), 1)
  length = length / n_slice
  knl = knl / n_slice
  k2l = charge_dir * v(k2$) * length  
  
  call transfer_ele(ele, temp_ele1, .true.)
  temp_ele1%value(l$) = length

  call transfer_ele(ele, temp_ele2, .true.)
  call zero_ele_offsets(temp_ele2)
  temp_ele2%value(l$) = length
  temp_ele2%value(k2$) = 0
  temp_ele2%value(e1$) = 0
  temp_ele2%value(e2$) = 0
  if (associated(temp_ele2%a_pole)) then
    nullify (temp_ele2%a_pole)
    nullify (temp_ele2%b_pole)
  endif

  ! Add multipole kick

  if (has_nonzero_pole) then
    call add_multipole_slice (knl, tilt, 0.5_rp, c00, mat6)
  endif

  ! 1/2 sextupole kick at the beginning.

  if (k2l /= 0) then
    call mat4_multipole (k2l/2, 0.0_rp, 2, c00%vec, kmat4)
    c00%vec(2) = c00%vec(2) + k2l/2 * (c00%vec(3)**2 - c00%vec(1)**2)/2
    c00%vec(4) = c00%vec(4) + k2l/2 * c00%vec(1) * c00%vec(3)
    mat6(1:4,1:6) = matmul(kmat4,mat6(1:4,1:6))
  end if
  
  ! And track with n_slice steps

  do i = 1, n_slice

    call mat_make_unit(mat6_i)

    if (g == 0 .or. k1 /= 0) then

      call sbend_body_with_k1_map (temp_ele1, param, 1, c00, mat6 = mat6_i)
        
    elseif (length /= 0) then

      ! Used: Eqs (12.18) from Etienne Forest: Beam Dynamics.

      x  = c00%vec(1)
      px = c00%vec(2)
      y  = c00%vec(3)
      py = c00%vec(4)
      z  = c00%vec(5)
      pz = c00%vec(6)
 
      angle = g * length
      rel_p  = 1 + pz
      rel_p2 = rel_p**2

      ct = cos(angle)
      st = sin(angle)

      pxy2 = px**2 + py**2
      if (rel_p2 < pxy2) then
        if (present(err)) err = .true.
        return
      endif

      p_long = sqrt(rel_p2 - pxy2)
      dp_long_dpx = -px/p_long
      dp_long_dpy = -py/p_long
      dp_long_dpz = rel_p/p_long
      
      ! The following was obtained by differentiating the formulas of track_a_bend.

      if (pxy2 < 1e-5) then  
         f = pxy2 / (2 * rel_p)
         f = pz - f - f*f/2 - g_err*rho - g_tot*x
         df_dx  = -g_tot
         df_dpx = -px * pxy2 / (2 * rel_p2) - px/rel_p
         df_dpy = -py * pxy2 / (2 * rel_p2) - py/rel_p
         df_dpz = 1 + pxy2**2 / (4 * rel_p**3) + pxy2 / (2 * rel_p2)
      else
         f = p_long - g_tot * (1 + x * g) / g
         df_dx  = -g_tot
         df_dpx = dp_long_dpx
         df_dpy = dp_long_dpy
         df_dpz = dp_long_dpz
      endif

      Dy  = sqrt(rel_p2 - py**2)
      Dy_dpy = -py/Dy
      Dy_dpz = rel_p/Dy

      px_t = px*ct + f*st
      dpx_t = -px*st*g + f*ct*g

      dpx_t_dx  = ct*g*df_dx
      dpx_t_dpx = -st*g + ct*g*df_dpx
      dpx_t_dpy = ct*g*df_dpy
      dpx_t_dpz = ct*g*df_dpz

      if (abs(angle) < 1e-5 .and. abs(g_tot * length) < 1e-5) then
        mat6_i(1,1) = 1
        mat6_i(1,2) = length / p_long + length * px**2 / p_long**3 - 3 * g_tot * px * (length * Dy)**2 / (2 * p_long**5) + &
                      g * length * (length *px + x * (p_long - px**2 / p_long)) / p_long**2 + &
                      g * length * px * (length * (rel_p2 + px**2 - py**2) + 2 * x * px * p_long) / p_long**4
        mat6_i(1,3) = 0
        mat6_i(1,4) = length * px *py / p_long**3 + &
                      g_tot * length**2 * (py / p_long**3 - 3 * py * Dy**2 / (2 * p_long**5)) + &
                      g * length * (-length * py - x * px * py / p_long) / p_long**2 + &
                      g * length * (length * (rel_p2 + px**2 - py**2) + 2 * x * px * p_long) * py / p_long**4
        mat6_i(1,5) = 0
        mat6_i(1,6) = -length * px * rel_p / p_long**3 + &
                      g_tot * length**2 * (3 * rel_p * Dy**2 / (2 * p_long**5) - rel_p / p_long**3) + &
                      g * length * (length * rel_p + x * px * rel_p / p_long) / p_long**2 - &
                      g * length * (length * (rel_p2 + px**2 - py**2) + 2 * x * px * p_long) * rel_p / p_long**4

      elseif (abs(g_tot) < 1e-5 * abs(g)) then
        alpha = p_long * ct - px * st
        dalpha_dpx = dp_long_dpx * ct - st
        dalpha_dpy = dp_long_dpy * ct
        dalpha_dpz = dp_long_dpz * ct
        mat6_i(1,1) = -(g_tot*st**2*(1+g*x)*Dy**2)/(g*alpha**3) + p_long/alpha &
                      +(3*g_tot**2*st**3*(1+g*x)**2*Dy**2*(ct*px+st*p_long))/(2*g**2*alpha**5)
        mat6_i(1,2) = (3*g_tot*st**2*(1+g*x)**2*Dy**2*dalpha_dpx)/(2*g**2*alpha**4) &
                      -(5*g_tot**2*st**3*(1+g*x)**3*Dy**2*(ct*px+st*p_long)*dalpha_dpx)/(2*g**3*alpha**6) &
                      -((-alpha+(1+g*x)*p_long)*dalpha_dpx)/(g*alpha**2) &
                      +(g_tot**2*st**3*(1+g*x)**3*Dy**2*(ct+st*dp_long_dpx))/(2*g**3*alpha**5) &
                      +(-dalpha_dpx+(1+g*x)*dp_long_dpx)/(g*alpha)
        mat6_i(1,4) = (3*g_tot*st**2*(1+g*x)**2*Dy**2*dalpha_dpy)/(2*g**2*alpha**4) &
                      -(5*g_tot**2*st**3*(1+g*x)**3*Dy**2*(ct*px+st*p_long)*dalpha_dpy)/(2*g**3*alpha**6) &
                      -((-alpha+(1+g*x)*p_long)*dalpha_dpy)/(g*alpha**2) &
                      +(g_tot**2*st**4*(1+g*x)**3*Dy**2*dp_long_dpy)/(2*g**3*alpha**5) &
                      +(-dalpha_dpy+(1+g*x)*dp_long_dpy)/(g*alpha) &
                      -(g_tot*st**2*(1+g*x)**2*Dy*Dy_dpy)/(g**2*alpha**3) &
                      +(g_tot**2*st**3*(1+g*x)**3*Dy*(ct*px+st*p_long)*Dy_dpy)/(g**3*alpha**5)
        mat6_i(1,6) = (3*g_tot*st**2*(1+g*x)**2*Dy**2*dalpha_dpz)/(2*g**2*alpha**4) &
                      -(5*g_tot**2*st**3*(1+g*x)**3*Dy**2*(ct*px+st*p_long)*dalpha_dpz)/(2*g**3*alpha**6) &
                      -((-alpha+(1+g*x)*p_long)*dalpha_dpz)/(g*alpha**2) &
                      +(g_tot**2*st**4*(1+g*x)**3*Dy**2*dp_long_dpz)/(2*g**3*alpha**5) &
                      +(-dalpha_dpz+(1+g*x)*dp_long_dpz)/(g*alpha) &
                      -(g_tot*st**2*(1+g*x)**2*Dy*Dy_dpz)/(g**2*alpha**3) &
                      +(g_tot**2*st**3*(1+g*x)**3*Dy*(ct*px+st*p_long)*Dy_dpz)/(g**3*alpha**5)
      else
        eps = px_t**2 + py**2
        deps_dx  = 2*px_t*st*df_dx
        deps_dpx = 2*px_t*(ct+st*df_dpx)
        deps_dpy = 2*px_t*st*df_dpy + 2*py
        deps_dpz = 2*px_t*st*df_dpz
        if (eps < 1e-5 * rel_p2 ) then  ! use small angle approximation
          eps = eps / (2 * rel_p)
          deps_dx  = deps_dx / (2 * rel_p)
          deps_dpx = deps_dpx / (2 * rel_p)
          deps_dpy = deps_dpy / (2 * rel_p)
          deps_dpz = deps_dpz / (2 * rel_p) - (px_t**2 + py**2) / (2*rel_p2) 
          mat6_i(1,1) = (-rho*dpx_t_dx+(eps/(2*rel_p)-1)*deps_dx+eps*deps_dx/(2*rel_p))/g_tot
          mat6_i(1,2) = (-rho*dpx_t_dpx+(eps/(2*rel_p)-1)*deps_dpx+eps*deps_dpx/(2*rel_p))/g_tot
          mat6_i(1,4) = (-rho*dpx_t_dpy+(eps/(2*rel_p)-1)*deps_dpy+eps*deps_dpy/(2*rel_p))/g_tot
          mat6_i(1,6) = (1-rho*dpx_t_dpz+(eps/(2*rel_p)-1)*deps_dpz+eps*(deps_dpz/(2*rel_p)-eps/(2*rel_p2)))/g_tot
        else
          mat6_i(1,1) = (-rho*dpx_t_dx-deps_dx/(2*sqrt(rel_p2-eps)))/g_tot
          mat6_i(1,2) = (-rho*dpx_t_dpx-deps_dpx/(2*sqrt(rel_p2-eps)))/g_tot
          mat6_i(1,4) = (-rho*dpx_t_dpy-deps_dpy/(2*sqrt(rel_p2-eps)))/g_tot
          mat6_i(1,6) = (-rho*dpx_t_dpz+(2*rel_p-deps_dpz)/(2*sqrt(rel_p2-eps)))/g_tot
        endif
      endif
      
      mat6_i(2,1) = -g_tot * st
      mat6_i(2,2) = ct - px * st / p_long
      mat6_i(2,4) = -py * st / p_long
      mat6_i(2,6) = rel_p * st / p_long

      if (abs(g_tot) < 1e-5 * abs(g)) then
        beta = (1 + g * x) * st / (g * alpha) - &
               g_tot * (px * ct + p_long * st) * (st * (1 + g * x))**2 / (2 * g**2 * alpha**3)
        dbeta_dx  = st/alpha - (g_tot*st**2*(1+g*x)*(ct*px+st*p_long))/(g*alpha**3)
        dbeta_dpx = -(st*(1+g*x)*dalpha_dpx)/(g*alpha**2)-(g_tot*st**2*(1+g*x)**2*(ct+st*dp_long_dpx))/(2*g**2*alpha**3)
        dbeta_dpy = -(st*(1+g*x)*dalpha_dpy)/(g*alpha**2)-(g_tot*st**3*(1+g*x)**2*dp_long_dpy)/(2*g**2*alpha**3)
        dbeta_dpz = -(st*(1+g*x)*dalpha_dpz)/(g*alpha**2)-(g_tot*st**3*(1+g*x)**2*dp_long_dpz)/(2*g**2*alpha**3)
        mat6_i(3,1) = py*dbeta_dx
        mat6_i(3,2) = py*dbeta_dpx
        mat6_i(3,4) = beta + py*dbeta_dpy
        mat6_i(3,6) = py*dbeta_dpz
        mat6_i(5,1) = -rel_p*dbeta_dx
        mat6_i(5,2) = -rel_p*dbeta_dpx
        mat6_i(5,4) = -rel_p*dbeta_dpy
        mat6_i(5,6) = -beta - rel_p*dbeta_dpz
      else
        factor = (asin(px/Dy) - asin(px_t/Dy)) / g_tot
        factor1 = sqrt(1-(px/Dy)**2)
        factor2 = sqrt(1-(px_t/Dy)**2)
        dfactor_dx  = -st*df_dx/(Dy*factor2*g_tot)
        dfactor_dpx = (1/(factor1*Dy)-(ct+st*df_dpx)/(factor2*Dy))/g_tot
        dfactor_dpy = (-px*Dy_dpy/(factor1*Dy**2)-(-px_t*Dy_dpy/Dy**2 + st*df_dpy/Dy)/factor2)/g_tot
        dfactor_dpz = (-px*Dy_dpz/(factor1*Dy**2)-(-px_t*Dy_dpz/Dy**2 + st*df_dpz/Dy)/factor2)/g_tot
        mat6_i(3,1) = py*dfactor_dx
        mat6_i(3,2) = py*dfactor_dpx
        mat6_i(3,4) = angle/g_tot + factor + py*dfactor_dpy
        mat6_i(3,6) = py*dfactor_dpz
        mat6_i(5,1) = -rel_p*dfactor_dx
        mat6_i(5,2) = -rel_p*dfactor_dpx
        mat6_i(5,4) = -rel_p*dfactor_dpy
        mat6_i(5,6) = -angle/g_tot - factor - rel_p*dfactor_dpz
      endif
      
    endif  

    mat6 = matmul(mat6_i,mat6)
    c_int = c00
    call track_a_bend (c_int, temp_ele2, param, c00)

    factor = 1
    if (i == n_slice) factor = 0.5

    if (has_nonzero_pole) then
      call add_multipole_slice (knl, tilt, factor, c00, mat6)
    endif

    if (k2l /= 0) then
      call mat4_multipole (k2l*factor, 0.0_rp, 2, c00%vec, kmat4)
      c00%vec(2) = c00%vec(2) + k2l * factor * (c00%vec(3)**2 - c00%vec(1)**2)/2
      c00%vec(4) = c00%vec(4) + k2l * factor * c00%vec(1) * c00%vec(3)
      mat6(1:4,1:6) = matmul(kmat4,mat6(1:4,1:6))
    end if

  end do

  mat6 = matmul(mat6,mat6_pre)
  mat6 = matmul(mat6_post,mat6)

  ! Roll

  if (v(roll$) /= 0) then
    ! c0_off is the coordinates *after* the roll at the entrance end
    ! So get the reverse roll matrix and take the inverse.
    dr = 0
    if (v(angle$) < 1e-20) then
      axis = [v(angle$)/2, 0.0_rp, 1.0_rp]
    else
      axis = [cos(v(angle$)) - 1, 0.0_rp, sin(v(angle$))]
    endif
    call axis_angle_to_w_mat (axis, -v(roll$), w_mat)
    call mat6_coord_transformation (mat6_pre, ele, param, c0_off, dr, w_mat)
    call mat_symp_conj(mat6_pre, mat6_pre)   ! Inverse

    ! c1_off is the coordinates before the roll so this is what is needed
    axis(1) = -axis(1)  ! Axis in exit coordinates
    call axis_angle_to_w_mat (axis, -v(roll$), w_mat)
    call mat6_coord_transformation (mat6_post, ele, param, c1_off, dr, w_mat)

    mat6 = matmul(matmul(mat6_post, mat6), mat6_pre)
  endif

  !

  if (v(ref_tilt_tot$) /= 0) call tilt_mat6 (mat6, v(ref_tilt_tot$))

  call add_multipoles_and_z_offset (.false.)
  call add_M56_low_E_correction()
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! Sextupole.
! the sextupole is modeled as kick-drift-kick

case (sextupole$)

  call offset_particle (ele, c00, param, set$, set_canonical = .false.)

  n_slice = max(1, nint(length / v(ds_step$)))
  
  do i = 0, n_slice
    k2l = charge_dir * v(k2$) * length / n_slice
    if (i == 0 .or. i == n_slice) k2l = k2l / 2
    call mat4_multipole (k2l, 0.0_rp, 2, c00%vec, kmat4)
    c00%vec(2) = c00%vec(2) + k2l * (c00%vec(3)**2 - c00%vec(1)**2)/2
    c00%vec(4) = c00%vec(4) + k2l * c00%vec(1) * c00%vec(3)
    mat6(1:4,1:6) = matmul(kmat4,mat6(1:4,1:6))
    if (i /= n_slice) then
      call drift_mat6_calc (drift, length/n_slice, ele, param, c00)
      call track_a_drift (c00, ele, length/n_slice)
      mat6 = matmul(drift,mat6)
    end if
  end do

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! solenoid

case (solenoid$)

  call offset_particle (ele, c00, param, set$)

  ks = param%rel_tracking_charge * v(ks$) / rel_p

  call solenoid_mat_calc (ks, length, mat6(1:4,1:4))

  mat6(1,2) = mat6(1,2) / rel_p
  mat6(1,4) = mat6(1,4) / rel_p

  mat6(2,1) = mat6(2,1) * rel_p
  mat6(2,3) = mat6(2,3) * rel_p

  mat6(3,2) = mat6(3,2) / rel_p
  mat6(3,4) = mat6(3,4) / rel_p

  mat6(4,1) = mat6(4,1) * rel_p
  mat6(4,3) = mat6(4,3) * rel_p


  c2 = mat6(1,1)
  s2 = mat6(1,4) * ks / 2
  cs = mat6(1,3)

  lcs = length * cs
  lc2s2 = length * (c2 - s2) / 2

  t1_16 =  lcs * ks
  t1_26 = -lc2s2 * 2
  t1_36 = -lc2s2 * ks
  t1_46 = -lcs * 2

  t2_16 =  lc2s2 * ks**2 / 2
  t2_26 =  lcs * ks
  t2_36 =  lcs * ks**2 / 2
  t2_46 = -lc2s2 * ks

  t3_16 =  lc2s2 * ks
  t3_26 =  lcs * 2
  t3_36 =  lcs * ks
  t3_46 = -lc2s2 * 2

  t4_16 = -lcs * ks**2 / 2
  t4_26 =  lc2s2 * ks
  t4_36 =  t2_16
  t4_46 =  lcs * ks

  arg = length / 2
  t5_11 = -arg * (ks/2)**2
  t5_14 =  arg * ks
  t5_22 = -arg
  t5_23 = -arg * ks
  t5_33 = -arg * (ks/2)**2
  t5_44 = -arg

  ! the mat6(i,6) terms are constructed so that mat6 is sympelctic

  mat6(5,1) =  2 * c00%vec(1) * t5_11 + c00%vec(4) * t5_14
  mat6(5,2) = (2 * c00%vec(2) * t5_22 + c00%vec(3) * t5_23) / rel_p
  mat6(5,3) =  2 * c00%vec(3) * t5_33 + c00%vec(2) * t5_23
  mat6(5,4) = (2 * c00%vec(4) * t5_44 + c00%vec(1) * t5_14) / rel_p

  mat6(1,6) = mat6(5,2) * mat6(1,1) - mat6(5,1) * mat6(1,2) + &
                  mat6(5,4) * mat6(1,3) - mat6(5,3) * mat6(1,4)
  mat6(2,6) = mat6(5,2) * mat6(2,1) - mat6(5,1) * mat6(2,2) + &
                  mat6(5,4) * mat6(2,3) - mat6(5,3) * mat6(2,4)
  mat6(3,6) = mat6(5,4) * mat6(3,3) - mat6(5,3) * mat6(3,4) + &
                  mat6(5,2) * mat6(3,1) - mat6(5,1) * mat6(3,2)
  mat6(4,6) = mat6(5,4) * mat6(4,3) - mat6(5,3) * mat6(4,4) + &
                  mat6(5,2) * mat6(4,1) - mat6(5,1) * mat6(4,2)

  ! mat6(5,6) 

  xp_start = c00%vec(2) + ks * c00%vec(3) / 2
  yp_start = c00%vec(4) - ks * c00%vec(1) / 2
  mat6(5,6) = length * (xp_start**2 + yp_start**2 ) / rel_p

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  call add_M56_low_E_correction()
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! solenoid/quad

case (sol_quad$)

  call offset_particle (ele, c00, param, set$)

  call sol_quad_mat6_calc (v(ks$) * param%rel_tracking_charge, v(k1$) * charge_dir, length, mat6, c00%vec)

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  call add_M56_low_E_correction()
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! taylor

case (taylor$)

  call make_mat6_taylor (ele, param, c0)

!--------------------------------------------------------
! wiggler

case (wiggler$, undulator$)

  call offset_particle (ele, c00, param, set$)
  call offset_particle (ele, c11, param, set$, ds_pos = length)

  call mat_make_unit (mat6)     ! make a unit matrix

  if (length == 0) then
    call add_multipoles_and_z_offset (.true.)
  call add_M56_low_E_correction()
    return
  endif

  k1 = -0.5 * charge_dir * (c_light * v(b_max$) / (v(p0c$) * rel_p))**2

  ! octuple correction to k1

  y_ave = (c00%vec(3) + c11%vec(3)) / 2
  if (v(l_pole$) == 0) then
    k_z = 0
  else
    k_z = pi / v(l_pole$)
  endif
  k1 = k1 * (1 + 2 * (k_z * y_ave)**2)

  !

  mat6(1, 1) = 1
  mat6(1, 2) = length
  mat6(2, 1) = 0
  mat6(2, 2) = 1

  call quad_mat2_calc (k1, length, mat6(3:4,3:4))

  cy = mat6(3, 3)
  sy = mat6(3, 4)

  t5_22 = -length / 2
  t5_33 =  k1 * (length - sy*cy) / 4
  t5_34 = -k1 * sy**2 / 2
  t5_44 = -(length + sy*cy) / 4

  ! the mat6(i,6) terms are constructed so that mat6 is sympelctic

  mat6(5,2) = 2 * c00%vec(2) * t5_22
  mat6(5,3) = 2 * c00%vec(3) * t5_33 +     c00%vec(4) * t5_34
  mat6(5,4) =     c00%vec(3) * t5_34 + 2 * c00%vec(4) * t5_44

  mat6(1,6) = mat6(5,2) * mat6(1,1)
  mat6(2,6) = mat6(5,2) * mat6(2,1)
  mat6(3,6) = mat6(5,4) * mat6(3,3) - mat6(5,3) * mat6(3,4)
  mat6(4,6) = mat6(5,4) * mat6(4,3) - mat6(5,3) * mat6(4,4)

  if (v(tilt_tot$) /= 0) then
    call tilt_mat6 (mat6, v(tilt_tot$))
  endif

  call add_multipoles_and_z_offset (.true.)
  call add_M56_low_E_correction()
  ele%vec0 = c1%vec - matmul(mat6, c0%vec)

!--------------------------------------------------------
! unrecognized element

case default

  if (present(err)) err = .true.
  call out_io (s_fatal$, r_name,  'UNKNOWN ELEMENT KEY: \i0\ ', &
                                  'FOR ELEMENT: ' // ele%name, i_array = [ele%key])
  if (global_com%exit_on_error) call err_exit
  return

end select

!--------------------------------------------------------
contains

subroutine add_multipole_slice (knl, tilt, factor, orb, mat6)

type (coord_struct) orb
real(rp) knl(0:n_pole_maxx), tilt(0:n_pole_maxx)
real(rp) mat6(6,6), factor, mat6_m(6,6)

!

call multipole_kick_mat (knl, tilt, orb%vec, factor, mat6_m)

mat6(2,:) = mat6(2,:) + mat6_m(2,1) * mat6(1,:) + mat6_m(2,3) * mat6(3,:)
mat6(4,:) = mat6(4,:) + mat6_m(4,1) * mat6(1,:) + mat6_m(4,3) * mat6(3,:)

call multipole_kicks (knl*factor, tilt, orb)

end subroutine

!--------------------------------------------------------
! contains

! put in multipole components

subroutine add_multipoles_and_z_offset (add_pole)

real(rp) mat6_m(6,6)
logical has_nonzero_pole, add_pole

!

if (add_pole) then
  call multipole_ele_to_kt (ele, param, .true., has_nonzero_pole, knl, tilt)
  if (has_nonzero_pole) then
    call multipole_kick_mat (knl, tilt, c0%vec, 0.5_rp, mat6_m)
    mat6(:,1) = mat6(:,1) + mat6(:,2) * mat6_m(2,1) + mat6(:,4) * mat6_m(4,1)
    mat6(:,3) = mat6(:,3) + mat6(:,2) * mat6_m(2,3) + mat6(:,4) * mat6_m(4,3)
    call multipole_kick_mat (knl, tilt, c1%vec, 0.5_rp, mat6_m)
    mat6(2,:) = mat6(2,:) + mat6_m(2,1) * mat6(1,:) + mat6_m(2,3) * mat6(3,:)
    mat6(4,:) = mat6(4,:) + mat6_m(4,1) * mat6(1,:) + mat6_m(4,3) * mat6(3,:)
  endif
endif

if (v(z_offset_tot$) /= 0) then
  s_off = v(z_offset_tot$) * ele%orientation
  mat6(1,:) = mat6(1,:) - s_off * mat6(2,:)
  mat6(3,:) = mat6(3,:) - s_off * mat6(4,:)
  mat6(:,2) = mat6(:,2) + mat6(:,1) * s_off
  mat6(:,4) = mat6(:,4) + mat6(:,3) * s_off
endif

! pitch corrections

call mat6_add_pitch (v(x_pitch_tot$), v(y_pitch_tot$), ele%orientation, ele%mat6)

end subroutine add_multipoles_and_z_offset

!----------------------------------------------------------------
! contains

subroutine add_M56_low_E_correction()

real(rp) mass, e_tot

! 1/gamma^2 m56 correction

mass = mass_of(param%particle)
e_tot = v(p0c$) * (1 + c0%vec(6)) / c0%beta
mat6(5,6) = mat6(5,6) + length * mass**2 * v(e_tot$) / e_tot**3

end subroutine add_M56_low_E_correction

end subroutine make_mat6_bmad

!----------------------------------------------------------------
!----------------------------------------------------------------
!----------------------------------------------------------------

subroutine mat6_coupler_kick(ele, param, particle_at, phase, orb, mat6)

use track1_mod

implicit none

type (ele_struct) ele
type (coord_struct) orb, old_orb
type (lat_param_struct) param
real(rp) phase, mat6(6,6), f, f2, coef, E_new
real(rp) dp_coef, dp_x, dp_y, ph, mc(6,6), E, pc, mc2, p0c
integer particle_at, physical_end

!

physical_end = physical_ele_end(particle_at, orb%direction, ele%orientation)
if (.not. at_this_ele_end (physical_end, nint(ele%value(coupler_at$)))) return

ph = phase
if (ele%key == rfcavity$) ph = pi/2 - ph
ph = ph + twopi * ele%value(coupler_phase$)

mc2 = mass_of(param%particle)
p0c = orb%p0c
pc = p0c * (1 + orb%vec(6))
E = pc / orb%beta

f = twopi * ele%value(rf_frequency$) / c_light
dp_coef = e_accel_field(ele, gradient$) * ele%value(coupler_strength$)
dp_x = dp_coef * cos(twopi * ele%value(coupler_angle$))
dp_y = dp_coef * sin(twopi * ele%value(coupler_angle$))

if (nint(ele%value(coupler_at$)) == both_ends$) then
  dp_x = dp_x / 2
  dp_y = dp_y / 2
endif

! Track

old_orb = orb
call rf_coupler_kick (ele, param, particle_at, phase, orb)

! Matrix

call mat_make_unit (mc)

mc(2,5) = dp_x * f * sin(ph) / (old_orb%beta * p0c)
mc(4,5) = dp_y * f * sin(ph) / (old_orb%beta * p0c)

mc(2,6) = -dp_x * f * sin(ph) * old_orb%vec(5) * mc2**2 / (E * pc**2)
mc(4,6) = -dp_y * f * sin(ph) * old_orb%vec(5) * mc2**2 / (E * pc**2)

coef = (dp_x * old_orb%vec(1) + dp_y * old_orb%vec(3)) * cos(ph) * f**2 
mc(6,1) = dp_x * sin(ph) * f / (orb%beta * p0c)
mc(6,3) = dp_y * sin(ph) * f / (orb%beta * p0c)
mc(6,5) = -coef / (orb%beta * old_orb%beta * p0c) 
mc(6,6) = old_orb%beta/orb%beta + coef * old_orb%vec(5) * mc2**2 / (pc**2 * E * orb%beta)

f2 = old_orb%vec(5) * mc2**2 / (pc * E**2 * p0c)
E_new = p0c * (1 + orb%vec(6)) / orb%beta

mc(5,1) = old_orb%vec(5) * mc2**2 * p0c * mc(6,1) / (old_orb%beta * E_new**3)
mc(5,3) = old_orb%vec(5) * mc2**2 * p0c * mc(6,3) / (old_orb%beta * E_new**3)
mc(5,5) = orb%beta/old_orb%beta + old_orb%vec(5) * mc2**2 * p0c * mc(6,5) / (old_orb%beta * E_new**3)
mc(5,6) = old_orb%vec(5) * mc2**2 * p0c * (mc(6,6) / (old_orb%beta * E_new**3) - &
                                     orb%beta / (old_orb%beta**2 * E**3))

mat6 = matmul(mc, mat6)

end subroutine mat6_coupler_kick

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------

subroutine lcavity_edge_kick_matrix (ele, param, grad_max, phase, orb, mat6)

use bmad_interface

implicit none

type (ele_struct)  ele
type (coord_struct)  orb
type (lat_param_struct) param

real(rp) grad_max, phase, k1, mat6(6,6)
real(rp) f, mc2, E, pc

! Note that phase space here is (x, x', y, y', -c(t-t_ref), E) 

pc = (1 + orb%vec(6)) * orb%p0c
E = pc / orb%beta
k1 = grad_max * cos(phase)
f = grad_max * sin(phase) * twopi * ele%value(rf_frequency$) / c_light
mc2 = mass_of(param%particle)

mat6(2,:) = mat6(2,:) + k1 * mat6(1,:) + f * orb%vec(1) * mat6(5,:) 
mat6(4,:) = mat6(4,:) + k1 * mat6(3,:) - f * orb%vec(3) * mat6(5,:)

orb%vec(2) = orb%vec(2) + k1 * orb%vec(1)
orb%vec(4) = orb%vec(4) + k1 * orb%vec(3)

end subroutine lcavity_edge_kick_matrix

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------

subroutine bbi_kick_matrix (ele, param, orb, s_pos, mat6)

use bmad_interface, except_dummy => bbi_kick_matrix

implicit none

type (ele_struct)  ele
type (coord_struct)  orb
type (lat_param_struct) param

real(rp) x_pos, y_pos, del, sig_x, sig_y, coef, garbage, s_pos
real(rp) ratio, k0_x, k1_x, k0_y, k1_y, mat6(6,6), beta, bbi_const

!

call mat_make_unit (mat6)

sig_x = ele%value(sig_x$)
sig_y = ele%value(sig_y$)

if (sig_x == 0 .or. sig_y == 0) return

if (s_pos /= 0 .and. ele%a%beta /= 0) then
  beta = ele%a%beta - 2 * ele%a%alpha * s_pos + ele%a%gamma * s_pos**2
  sig_x = sig_x * sqrt(beta / ele%a%beta)
  beta = ele%b%beta - 2 * ele%b%alpha * s_pos + ele%b%gamma * s_pos**2
  sig_y = sig_y * sqrt(beta / ele%b%beta)
endif

x_pos = orb%vec(1) / sig_x  ! this has offset in it
y_pos = orb%vec(3) / sig_y

del = 0.001

ratio = sig_y / sig_x
call bbi_kick (x_pos, y_pos, ratio, k0_x, k0_y)
call bbi_kick (x_pos+del, y_pos, ratio, k1_x, garbage)
call bbi_kick (x_pos, y_pos+del, ratio, garbage, k1_y)

bbi_const = -param%n_part * ele%value(charge$) * classical_radius_factor /  &
                    (2 * pi * ele%value(p0c$) * (sig_x + sig_y))

coef = bbi_const / (ele%value(n_slice$) * del * (1 + orb%vec(6)))

mat6(2,1) = coef * (k1_x - k0_x) / sig_x
mat6(4,3) = coef * (k1_y - k0_y) / sig_y

end subroutine bbi_kick_matrix
