!+
! Subroutine track1_bmad (start_orb, ele, param, end_orb)
!
! Particle tracking through a single element BMAD_standard style.
! This routine is NOT meant for long term tracking since it does not get 
! all the 2nd order terms for the longitudinal motion.
!
! It is assumed that HKICK and VKICK are the kicks in the horizontal
! and vertical kicks irregardless of the value for TILT.
!
! Note: track1_bmad *never* relies on ele%mat6 for tracking excect for 
! hybrid elements.
! 
! Note: end_orb%vec(6) will be set < -1 (and param%lost will be set) if the 
! particle fails to make it through an lcavity
!
! Modules Needed:
!   use bmad
!
! Input:
!   start_orb  -- Coord_struct: Starting position
!   ele        -- Ele_struct: Element
!   param      -- lat_param_struct:
!     %particle     -- Particle type
!
! Output:
!   end_orb   -- Coord_struct: End position
!   param     -- lat_param_struct:
!     %lost       -- Set True if particle is lost. False otherwise.
!-

subroutine track1_bmad (start_orb, ele, param, end_orb)

use bmad, except_dummy => track1_bmad
use capillary_mod
use track1_photon_mod

implicit none

type (coord_struct) :: start_orb, start2_orb
type (coord_struct) :: end_orb
type (ele_struct) :: ele
type (lat_param_struct) :: param

real(rp) k1, k2, k2l, k3l, length, phase, beta_start
real(rp) beta_end, beta_start_ref, beta_end_ref
real(rp) e2, sig_x, sig_y, kx, ky, coef, bbi_const
real(rp) knl(0:n_pole_maxx), tilt(0:n_pole_maxx)
real(rp) ks, sig_x0, sig_y0, beta, mat6(6,6), mat2(2,2), mat4(4,4)
real(rp) z_slice(100), s_pos, s_pos_old, vec0(6)
real(rp) rel_pc, ff, k_z, pc_start, pc_end, dt_ref, gradient_ref, gradient_max
real(rp) x_pos, y_pos, cos_phi, gradient, e_start, e_end, e_ratio, voltage_max
real(rp) alpha, sin_a, cos_a, f, r11, r12, r21, r22, volt_ref
real(rp) x, y, z, px, py, pz, k, dE0, L, E, pxy2, xp0, xp1, yp0, yp1
real(rp) xp_start, yp_start, dz4_coef(4,4), dz_coef(3)
real(rp) dp_coupler, dp_x_coupler, dp_y_coupler, len_slice, k0l, k1l
real(rp) phase0, dphase, dcos_phi, dgradient, dpz
real(rp) mc2, dpc_start, dE_start, dE_end, dE, dp_dg, dp_dg_ref, g
real(rp) E_start_ref, E_end_ref, pc_start_ref, pc_end_ref

real(rp) p_factor, sin_alpha, cos_alpha, sin_psi, cos_psi, wavelength
real(rp) cos_g, sin_g, cos_tc, sin_tc
real(rp) k_in_norm(3), h_norm(3), k_out_norm(3), e_tot, pc
real(rp) cap_gamma, gamma_0, gamma_h, b_err, dtheta_sin_2theta, b_eff

real(rp) m_in(3,3) , m_out(3,3), y_out(3), x_out(3), k_out(3)
real(rp) test, nn, mm, temp_vec(3)

complex(rp) f0, fh, f0_g, eta, eta1, f_cmp, xi_0k, xi_hk, e_rel, e_rel2

integer i, n, n_slice, key

logical err, has_nonzero_pole

character(16) :: r_name = 'track1_bmad'

! initially set end_orb = start_orb

start2_orb = start_orb ! In case start_orb and end_orb share the same memory.

end_orb = start_orb     ! transfer start to end
end_orb%s = ele%s
end_orb%p0c = ele%value(p0c$)

length = ele%value(l$)
rel_pc = 1 + start_orb%vec(6)

!-----------------------------------------------
! Select
! If element is off looks like a drift. LCavities will still do wakefields.

key = ele%key
if (key == sol_quad$ .and. ele%value(k1$) == 0) key = solenoid$
if (.not. ele%is_on .and. key /= lcavity$) key = drift$  

select case (key)

!-----------------------------------------------
! beambeam
                        
case (beambeam$)

  if (ele%value(charge$) == 0 .or. param%n_part == 0) return

  sig_x0 = ele%value(sig_x$)
  sig_y0 = ele%value(sig_y$)
  if (sig_x0 == 0 .or. sig_y0 == 0) return

  call offset_particle (ele, param, end_orb, set$)

  n_slice = max(1, nint(ele%value(n_slice$)))
  call bbi_slice_calc (n_slice, ele%value(sig_z$), z_slice)
  s_pos = 0    ! end at the ip
  do i = 1, n_slice
    s_pos_old = s_pos
    s_pos = (end_orb%vec(5) + z_slice(i)) / 2
    end_orb%vec(1) = end_orb%vec(1) + end_orb%vec(2) * (s_pos - s_pos_old)
    end_orb%vec(3) = end_orb%vec(3) + end_orb%vec(4) * (s_pos - s_pos_old)
    if (ele%a%beta == 0) then
      sig_x = sig_x0
      sig_y = sig_y0
    else
      beta = ele%a%beta - 2 * ele%a%alpha * s_pos + ele%a%gamma * s_pos**2
      sig_x = sig_x0 * sqrt(beta / ele%a%beta)
      beta = ele%b%beta - 2 * ele%b%alpha * s_pos + ele%b%gamma * s_pos**2
      sig_y = sig_y0 * sqrt(beta / ele%b%beta)
    endif

    call bbi_kick (end_orb%vec(1)/sig_x, end_orb%vec(3)/sig_y, sig_y/sig_x,  &
                                                                kx, ky)
    bbi_const = -param%n_part * ele%value(charge$) * classical_radius_factor /  &
                    (2 * pi * ele%value(p0c$) * (sig_x + sig_y))
    coef = ele%value(bbi_const$) / (n_slice * rel_pc)
    end_orb%vec(2) = end_orb%vec(2) + kx * coef
    end_orb%vec(4) = end_orb%vec(4) + ky * coef
  enddo
  end_orb%vec(1) = end_orb%vec(1) - end_orb%vec(2) * s_pos
  end_orb%vec(3) = end_orb%vec(3) - end_orb%vec(4) * s_pos

  call offset_particle (ele, param, end_orb, unset$)  

!-----------------------------------------------
! bend_sol_quad
! This is modeled using kick-drift-kick where 
!   kick  == thin bend & quad kick
!   drift == thick solenoid

case (bend_sol_quad$)

  call offset_particle (ele, param, end_orb, set$)

  n_slice = max(1, nint(length / ele%value(ds_step$)))
  len_slice = length / n_slice
  ks = ele%value(ks$) / rel_pc 
  k0l = ele%value(g$) * len_slice
  k1l = ele%value(k1$) * len_slice

  call solenoid_mat_calc (ks, length, mat4)

  do i = 1, n_slice

    ! Kick

    end_orb%vec(2) = end_orb%vec(2)
    end_orb%vec(4) = end_orb%vec(4)

    ! Solendoid "drift"

    xp_start = end_orb%vec(2) + ks * end_orb%vec(3) / 2
    yp_start = end_orb%vec(4) - ks * end_orb%vec(1) / 2
    end_orb%vec(5) = end_orb%vec(5) - len_slice * (xp_start**2 + yp_start**2 ) / 2
    end_orb%vec(1:4) = matmul (mat4, end_orb%vec(1:4))
  enddo

  call offset_particle (ele, param, end_orb, unset$)
  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! capillary

case (capillary$) 

  call offset_photon (ele, param, end_orb, set$)
  call track_a_capillary (end_orb, ele, param%lost)
  call offset_particle (ele, param, end_orb, unset$)  

!-----------------------------------------------
! crystal

case (crystal$) 

  call offset_photon (ele, param, end_orb, set$)
  call track1_crystal (ele, param, end_orb)
  call offset_photon (ele, param, end_orb, unset$)

!-----------------------------------------------
! drift
 
case (drift$, rcollimator$, ecollimator$, monitor$, instrument$, pipe$) 

  if (ele%is_on) call offset_particle (ele, param, end_orb, set$, .false.)
  call track_a_drift (end_orb, length)
  if (ele%is_on) call offset_particle (ele, param, end_orb, unset$, .false.)

  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! kicker, separator

case (elseparator$, kicker$, hkicker$, vkicker$) 

  call offset_particle (ele, param, end_orb, set$)

  end_orb%vec(1) = end_orb%vec(1) + length * end_orb%vec(2)
  end_orb%vec(3) = end_orb%vec(3) + length * end_orb%vec(4)

  if (ele%key == kicker$) then
    end_orb%vec(1) = end_orb%vec(1) + ele%value(h_displace$)
    end_orb%vec(3) = end_orb%vec(3) + ele%value(v_displace$)
  endif

  call offset_particle (ele, param, end_orb, unset$)  
  call end_z_calc

  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! LCavity: Linac rf cavity
! Ultra-relativistic formalism from:
!       J. Rosenzweig and L. Serafini
!       Phys Rev E, Vol. 49, p. 1599, (1994)
! with b_0 = b_-1 = 1. The extra factors of beta are included to make the 
! transverse determinant equal to (beta_i*gamma_i)/(beta_f*gamma_f) which it should
! be at low energies.

case (lcavity$)

  if (length == 0) return

  if (ele%value(E_tot_start$) == 0) then
    call out_io (s_fatal$, r_name, 'E_TOT_START IS 0 FOR A LCAVITY!')
    if (bmad_status%exit_on_error) call err_exit
  endif

  E_start_ref  = ele%value(E_tot_start$)
  E_end_ref    = ele%value(E_tot$)
  gradient_ref = (E_end_ref - E_start_ref) / length
  pc_start_ref = ele%value(p0c_start$)
  pc_end_ref   = ele%value(p0c$)
  beta_start_ref = pc_start_ref / E_start_ref
  beta_end_ref   = pc_end_ref / E_end_ref

  pc_start = pc_start_ref * rel_pc
  call convert_pc_to (pc_start, param%particle, E_tot = E_start, beta = beta_start)

  dphase = twopi * (ele%value(phi0_err$) - end_orb%vec(5) * ele%value(rf_frequency$) / (beta_start_ref * c_light))
  phase0 = twopi * (ele%value(phi0$) + ele%value(dphi0$)) 
  phase = phase0 + dphase

  gradient_max = ele%value(gradient$) + ele%value(gradient_err$)

  if (.not. ele%is_on) then
    gradient_max = 0
  endif

  cos_phi = cos(phase)
  gradient = gradient_max * cos_phi + gradient_shift_sr_wake(ele, param)

  ! If the cavity is off and the reference energy does not change then
  ! the tracking is simple.

  if (gradient == 0 .and. gradient_ref == 0) then
    if (ele%is_on) call offset_particle (ele, param, end_orb, set$, .false.)
    call track_a_drift (end_orb, length)
    if (ele%is_on) call offset_particle (ele, param, end_orb, unset$, .false.)
    ! 1/gamma^2 low E correction
    end_orb%vec(5) = end_orb%vec(5) + length * end_orb%vec(6) * (1 - 3 * end_orb%vec(6) / 2) * (mass_of(param%particle) / ele%value(e_tot$))**2
    return
  endif

  E_end = E_start + gradient * length
  if (E_end <= mass_of(param%particle)) then
    param%lost = .true.
    param%plane_lost_at = z_plane$
    end_orb%vec(6) = -1.01  ! Something less than -1
    return
  endif

  call convert_total_energy_to (E_end, param%particle, pc = pc_end, beta = beta_end)
  E_ratio = E_end / E_start
  end_orb%beta = beta_end

  call offset_particle (ele, param, end_orb, set$)

  ! entrance kick

  k1 = -gradient / (2 * pc_start)
  end_orb%vec(2) = end_orb%vec(2) + k1 * end_orb%vec(1)
  end_orb%vec(4) = end_orb%vec(4) + k1 * end_orb%vec(3)

  ! coupler kick

  if (ele%value(coupler_strength$) /= 0) call coupler_kick_entrance()

  if (gradient == 0) then
    r11 = 1
    r12 = length
    r21 = 0
    r22 = 1

  else
    voltage_max = gradient_max * length
    if (abs(voltage_max * cos_phi) < 1e-5 * pc_start) then
      f = voltage_max / pc_start
      alpha = f * (1 + f * cos_phi / 2)  / (2 * sqrt_2)
    else
      alpha = log(E_ratio) / (2 * sqrt_2 * cos_phi)
    endif
    cos_a = cos(alpha)
    sin_a = sin(alpha)
    f = gradient / (2 * sqrt_2 * cos_phi)
    r11 =  cos_a
    r12 =  sin_a * beta_start * E_start / f
    r21 = -sin_a * f / (E_end * beta_end)
    r22 =  cos_a * beta_start * E_start / (E_end * beta_end)
  endif

  x_pos = end_orb%vec(1)
  y_pos = end_orb%vec(3)

  end_orb%vec(1) = r11 * x_pos + r12 * end_orb%vec(2)
  end_orb%vec(2) = r21 * x_pos + r22 * end_orb%vec(2)
  end_orb%vec(3) = r11 * y_pos + r12 * end_orb%vec(4)
  end_orb%vec(4) = r21 * y_pos + r22 * end_orb%vec(4)

  ! coupler kick

  if (ele%value(coupler_strength$) /= 0) call coupler_kick_entrance()

  ! exit kick

  k2 = gradient / (2 * pc_end) 
  end_orb%vec(2) = end_orb%vec(2) + k2 * end_orb%vec(1)
  end_orb%vec(4) = end_orb%vec(4) + k2 * end_orb%vec(3)

  ! Final momentum.

  mc2 = mass_of(param%particle)

!  dPc_start = start2_orb%vec(6) * pc_start_ref
!  dE_start = dpc_start * pc_start_ref / E_start_ref + (dPc_start * E_start_ref/ mc2)**2 / E_start_ref**3
!  dE_end = dE_start + (gradient - gradient_ref) * length 

!  if (ele%is_on .and. abs(dE_end/E_end_ref) < 1e-4) then
!    if (abs(dphase) < 1e-5) then
!      dcos_phi = -sin(phase0) * dphase - cos(phase0) * dphase**2 / 2
!      dgradient = ele%value(gradient$) * dcos_phi + ele%value(gradient_err$) * cos_phi 
!      dE_end = dE_start + dgradient * length
!    endif
!    f = dE_end / (beta_end_ref * pc_end_ref)
!    end_orb%vec(6) = f - (f * mc2 / E_end_ref)**2 / 2
!
!  else
    end_orb%vec(6) = (pc_end - pc_end_ref) / pc_end_ref 
!  endif

  call offset_particle (ele, param, end_orb, unset$)

  ! z propagation...
  ! Calculate for both particle and ref particle:
  !    dp_dg = c * Delta_t / length - 1 
  ! The "- 1" is to cancel the large constant factor.

  dE = gradient * length
  if (abs(dE/E_start) < 1e-4) then
    if (E_start > 100 * mc2) then 
      f = (mc2 / pc_start)**2 
      dp_dg = f/2 - f**2/8 + f**3/16
    else
      dp_dg = (E_start - pc_start) / pc_start
    endif
    f = (dE  / E_start)
    g = E_start / pc_start
    dp_dg = dp_dg + (mc2 / pc_start)**2 * (-f/2 + f**2 * g / 2 - f**3 * g**2 / 8)
  else
    dp_dg = (pc_end - pc_start) / dE - 1
  endif

  dE = gradient_ref * length
  if (abs(dE/E_start_ref) < 1e-4) then
    if (E_start_ref > 100 * mc2) then 
      f = (mc2 / pc_start_ref)**2 
      dp_dg_ref = f/2 - f**2/8 + f**3/16
    else
      dp_dg_ref = (E_start_ref - pc_start_ref) / pc_start_ref
    endif
    f = (dE  / E_start_ref)
    g = E_start_ref / pc_start_ref
    dp_dg_ref = dp_dg_ref + (mc2 / pc_start_ref)**2 * (-f/2 + f**2 * g / 2 - f**3 * g**2 / 8)
  else
    dp_dg_ref = (pc_end_ref - pc_start_ref) / dE - 1
  endif

  end_orb%vec(5) = end_orb%vec(5) * (beta_end / beta_start) - beta_end * length * (dp_dg - dp_dg_ref)

  ! This assumes a uniform change in slope.

  xp0 = start2_orb%vec(2) / rel_pc
  xp1 = end_orb%vec(2) / (1 + end_orb%vec(6))
  yp0 = start2_orb%vec(4) / rel_pc
  yp1 = end_orb%vec(4) / (1 + end_orb%vec(6))

  end_orb%vec(5) = end_orb%vec(5) - (length / 6) * (xp0**2 + xp1**2 + xp0*xp1 + yp0**2 + yp1**2 + yp0*yp1)

  ! Time calc
  

  f = gradient_ref * length * mc2**2 / (pc_start_ref**2 * E_start_ref)

  if (abs(f) < 1d-6) then
    end_orb%t = start2_orb%t + length * (E_start_ref / pc_start_ref) * (1 - f/2) / c_light
  else
    end_orb%t = start2_orb%t + length * (pc_end_ref - pc_start_ref) / (gradient_ref * c_light)
  endif

!-----------------------------------------------
! marker, etc.

case (marker$, branch$, photon_branch$, floor_position$)

  return

!-----------------------------------------------
! match

case (match$)

  if (ele%value(match_end_orbit$) /= 0) then
    ele%value(x0$)  = start2_orb%vec(1)
    ele%value(px0$) = start2_orb%vec(2)
    ele%value(y0$)  = start2_orb%vec(3)
    ele%value(py0$) = start2_orb%vec(4)
    ele%value(z0$)  = start2_orb%vec(5)
    ele%value(pz0$) = start2_orb%vec(6)
    end_orb%vec = [ ele%value(x1$), ele%value(px1$), &
                ele%value(y1$), ele%value(py1$), &
                ele%value(z1$), ele%value(pz1$) ]
    return
  endif

  call match_ele_to_mat6 (ele, vec0, mat6, err)
  if (err) then
    param%lost = .true.
!!    call out_io (s_error$, r_name, &
!!          'MATCH ELEMENT HAS MATCH_END SET BUT BEGINNING BETA_A0 OR BETA_B0 PARAMETERS HAVE ', &
!!          'NOT BEEN SET FROM PREVIOUS ELEMENT: ' // ele%name)
  endif

  end_orb%vec = matmul (mat6, end_orb%vec) + vec0

!-----------------------------------------------
! mirror

case (mirror$)

  call offset_photon (ele, param, end_orb, set$)

  end_orb%vec(1:4) = [ &
        -end_orb%vec(1), &
        -end_orb%vec(2), &
         end_orb%vec(3), &
         end_orb%vec(4) - 2 * end_orb%vec(3) * ele%value(g_trans$)]

  call offset_photon (ele, param, end_orb, unset$)

!-----------------------------------------------
! multilayer_mirror

case (multilayer_mirror$) 

  call offset_photon (ele, param, end_orb, set$)
  call track1_multilayer_mirror (ele, param, end_orb)
  call offset_photon (ele, param, end_orb, unset$)

!-----------------------------------------------
! multipole, ab_multipole

case (multipole$, ab_multipole$) 

  call offset_particle (ele, param, end_orb, set$, set_canonical = .false., set_multipoles = .false.)

  call multipole_ele_to_kt(ele, param%particle, .false., has_nonzero_pole, knl, tilt)
  call multipole_kicks (knl, tilt, end_orb, .true.)

  call offset_particle (ele, param, end_orb, unset$, set_canonical = .false., set_multipoles = .false.)

!-----------------------------------------------
! octupole
! The octupole is modeled using kick-drift.

case (octupole$)

  n_slice = max(1, nint(length / ele%value(ds_step$)))

  k3l = ele%value(k3$) * length / n_slice

  call offset_particle (ele, param, end_orb, set$, set_canonical = .false.)

  end_orb%vec(2) = end_orb%vec(2) + k3l *  (3*end_orb%vec(1)*end_orb%vec(3)**2 - end_orb%vec(1)**3) / 12
  end_orb%vec(4) = end_orb%vec(4) + k3l *  (3*end_orb%vec(3)*end_orb%vec(1)**2 - end_orb%vec(3)**3) / 12

  do i = 1, n_slice

    call track_a_drift (end_orb, length / n_slice)

    if (i == n_slice) then
      end_orb%vec(2) = end_orb%vec(2) + k3l *  (3*end_orb%vec(1)*end_orb%vec(3)**2 - end_orb%vec(1)**3) / 12
      end_orb%vec(4) = end_orb%vec(4) + k3l *  (3*end_orb%vec(3)*end_orb%vec(1)**2 - end_orb%vec(3)**3) / 12
    else
      end_orb%vec(2) = end_orb%vec(2) + k3l *  (3*end_orb%vec(1)*end_orb%vec(3)**2 - end_orb%vec(1)**3) / 6
      end_orb%vec(4) = end_orb%vec(4) + k3l *  (3*end_orb%vec(3)*end_orb%vec(1)**2 - end_orb%vec(3)**3) / 6
    endif

  enddo

  call offset_particle (ele, param, end_orb, unset$, set_canonical = .false.)  

  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! patch

case (patch$)

  rel_pc = 1 + end_orb%vec(6)

  end_orb%vec(2) = end_orb%vec(2) - ele%value(x_pitch$) * rel_pc
  end_orb%vec(4) = end_orb%vec(4) - ele%value(y_pitch$) * rel_pc
  end_orb%vec(5) = end_orb%vec(5) + ele%value(x_pitch$) * end_orb%vec(1) + ele%value(y_pitch$) * end_orb%vec(3) 

  if (ele%value(tilt$) /= 0) call tilt_coords (ele%value(tilt$), end_orb%vec)

  end_orb%vec(1) = end_orb%vec(1) - ele%value(x_offset$)
  end_orb%vec(3) = end_orb%vec(3) - ele%value(y_offset$)
  end_orb%vec(5) = end_orb%vec(5) - ele%value(z_offset$) + ele%value(t_offset$) * end_orb%beta * c_light
  end_orb%vec(6) = (end_orb%vec(6) * ele%value(p0c_start$) + &
                                      (ele%value(p0c_start$) - ele%value(p0c$))) / ele%value(p0c$) 

!-----------------------------------------------
! quadrupole

case (quadrupole$)

  call offset_particle (ele, param, end_orb, set$)

  k1 = ele%value(k1$) / rel_pc

  call quad_mat2_calc (-k1, length, mat2, dz_coef)
  end_orb%vec(5) = end_orb%vec(5) + dz_coef(1) * end_orb%vec(1)**2 + &
                            dz_coef(2) * end_orb%vec(1) * end_orb%vec(2) + &
                            dz_coef(3) * end_orb%vec(2)**2 

  end_orb%vec(1:2) = matmul(mat2, end_orb%vec(1:2))

  call quad_mat2_calc (k1, length, mat2, dz_coef)
  end_orb%vec(5) = end_orb%vec(5) + dz_coef(1) * end_orb%vec(3)**2 + &
                            dz_coef(2) * end_orb%vec(3) * end_orb%vec(4) + &
                            dz_coef(3) * end_orb%vec(4)**2 

  end_orb%vec(3:4) = matmul(mat2, end_orb%vec(3:4))

  call offset_particle (ele, param, end_orb, unset$)  

  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! rfcavity

case (rfcavity$)

  call offset_particle (ele, param, end_orb, set$, set_canonical = .false.)

  ! coupler kick

  if (ele%value(coupler_strength$) /= 0) call coupler_kick_entrance()

  !

  x = end_orb%vec(1)
  y = end_orb%vec(3)
  z = end_orb%vec(5)

  px = end_orb%vec(2)
  py = end_orb%vec(4)
  pz = end_orb%vec(6)

  if (ele%value(voltage$) == 0) then
    phase = 0
    k = 0
  else
    if (ele%value(RF_frequency$) == 0) then
      call out_io (s_fatal$, r_name, &
                 '"RF_FREQUENCY" ATTRIBUTE NOT SET FOR RF: ' // ele%name, &
                 'YOU NEED TO SET THIS OR THE "HARMON" ATTRIBUTE.')
      if (bmad_status%exit_on_error) call err_exit
    endif
    ff = twopi * ele%value(rf_frequency$) / c_light
    phase = twopi * (ele%value(phi0$)+ele%value(dphi0$)) + ff * z
    k  =  ff * ele%value(voltage$) * cos(phase) / ele%value(p0c$)
  endif

  dE0 =  ele%value(voltage$) * sin(phase) / ele%value(E_tot$)
  L = ele%value(l$)
  E = 1 + pz
  E2 = E**2
  pxy2 = px**2 + py**2

  !

  end_orb%vec(1) = x + px*L * (1/E - dE0/2 + pxy2*L/12 + pz*dE0 + dE0**2/3) 
  end_orb%vec(3) = y + py*L * (1/E - dE0/2 + pxy2*L/12 + pz*dE0 + dE0**2/3)
  end_orb%vec(5) = z + pxy2*L * (-1/(2*E2) + dE0/2)
  end_orb%vec(6) = pz + dE0 + k*pxy2*L * (-1/(4*E2) + dE0/6) 

  ! coupler kick

  if (ele%value(coupler_strength$) /= 0) call coupler_kick_entrance()

  call offset_particle (ele, param, end_orb, unset$, set_canonical = .false.)

  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! sbend

case (sbend$)

  call track_a_bend (start_orb, ele, param, end_orb)
  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! sextupole
! The sextupole is modeled using kick-drift.

case (sextupole$)

  n_slice = max(1, nint(length / ele%value(ds_step$)))

  k2l = ele%value(k2$) * length / n_slice

  call offset_particle (ele, param, end_orb, set$, set_canonical = .false.)

  end_orb%vec(2) = end_orb%vec(2) + k2l * (end_orb%vec(3)**2 - end_orb%vec(1)**2)/4
  end_orb%vec(4) = end_orb%vec(4) + k2l * end_orb%vec(1) * end_orb%vec(3) / 2

  do i = 1, n_slice
    call track_a_drift (end_orb, length/n_slice)
    if (i == n_slice) then
      end_orb%vec(2) = end_orb%vec(2) + k2l * (end_orb%vec(3)**2 - end_orb%vec(1)**2)/4
      end_orb%vec(4) = end_orb%vec(4) + k2l * end_orb%vec(1) * end_orb%vec(3) / 2
    else
      end_orb%vec(2) = end_orb%vec(2) + k2l * (end_orb%vec(3)**2 - end_orb%vec(1)**2)/2
      end_orb%vec(4) = end_orb%vec(4) + k2l * end_orb%vec(1) * end_orb%vec(3)
    endif
  enddo

  call offset_particle (ele, param, end_orb, unset$, set_canonical = .false.)
  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! solenoid

case (solenoid$)

  call offset_particle (ele, param, end_orb, set$)

  ks = ele%value(ks$) / rel_pc

  xp_start = end_orb%vec(2) + ks * end_orb%vec(3) / 2
  yp_start = end_orb%vec(4) - ks * end_orb%vec(1) / 2
  end_orb%vec(5) = end_orb%vec(5) - length * (xp_start**2 + yp_start**2 ) / 2

  call solenoid_mat_calc (ks, length, mat4)
  end_orb%vec(1:4) = matmul (mat4, end_orb%vec(1:4))

  call offset_particle (ele, param, end_orb, unset$)
  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! sol_quad

case (sol_quad$)

  call offset_particle (ele, param, end_orb, set$)

  ks = ele%value(ks$) / rel_pc
  k1 = ele%value(k1$) / rel_pc
  vec0 = 0
  call sol_quad_mat6_calc (ks, k1, length, mat6, vec0, dz4_coef)
  end_orb%vec(5) = end_orb%vec(5) + sum(end_orb%vec(1:4) * matmul(dz4_coef, end_orb%vec(1:4)))   
  end_orb%vec(1:4) = matmul (mat6(1:4,1:4), end_orb%vec(1:4))

  call offset_particle (ele, param, end_orb, unset$)
  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! Taylor

case (taylor$)

  call track1_taylor (start_orb, ele, param, end_orb)

!-----------------------------------------------
! wiggler:
! Only periodic type wigglers are handled here.
! In the horizontal plane the tracking looks like a drift.
! The tracking in the vertical plane is:
!   1) 1/2 the octupole kick at the entrance face.
!   2) Track as a quadrupole through the body
!   3) 1/2 the octupole kick at the exit face.

case (wiggler$)

  if (ele%sub_key == map_type$) then
    call out_io (s_fatal$, r_name, &
            'NEW STYLE WIGGLER: ' // ele%name, &
            'HAS TRACKING_METHOD = BMAD_STANDARD.', &
            'THIS IS NOT A POSSIBLE OPTION FOR THE TRACKING_METHOD.')
    if (bmad_status%exit_on_error) call err_exit
  endif

  call offset_particle (ele, param, end_orb, set$)

  if (ele%value(l_pole$) == 0) then
    k_z = 0
  else
    k_z = pi / ele%value(l_pole$)
  endif
  k1 = -0.5 * (c_light * ele%value(b_max$) / (ele%value(p0c$) * rel_pc))**2

  ! 1/2 of the octupole octupole kick at the entrance face.

  end_orb%vec(4) = end_orb%vec(4) + k1 * length * k_z**2 * end_orb%vec(3)**3 / 3

  ! Quadrupole body

  call quad_mat2_calc (k1, length, mat2)
  end_orb%vec(1) = end_orb%vec(1) + length * end_orb%vec(2)
  end_orb%vec(3:4) = matmul (mat2, end_orb%vec(3:4))

  ! 1/2 of the octupole octupole kick at the exit face.

  end_orb%vec(4) = end_orb%vec(4) + k1 * length * k_z**2 * end_orb%vec(3)**3 / 3

  call offset_particle (ele, param, end_orb, unset$)
  call end_z_calc
  call low_energy_z_correction (end_orb, ele, param)

!-----------------------------------------------
! unknown

case default

  call out_io (s_fatal$, r_name, &
          'BMAD_STANDARD TRACKING_METHOD NOT IMPLMENTED FOR: ' // key_name(ele%key), &
          'FOR ELEMENT: ' // ele%name)
  if (bmad_status%exit_on_error) call err_exit

end select

!------------------------------------------
! Time calc

if (ele%key /= lcavity$) then
  end_orb%t = start2_orb%t + (ele%value(l$) + start2_orb%vec(5) - end_orb%vec(5)) / (end_orb%beta * c_light)
endif

contains

!--------------------------------------------------------------
! Rough calculation for change in longitudinal position using:
!      dz = -L * (<x'^2> + <y'^2>)/ 2 
! where <...> means average.
! The formula below assumes a linear change in velocity between 
! the beginning and the end:

subroutine end_z_calc

implicit none

end_orb%vec(5) = end_orb%vec(5) - (length / rel_pc**2) * &
      (start2_orb%vec(2)**2 + end_orb%vec(2)**2 + start2_orb%vec(2) * end_orb%vec(2) + &
       start2_orb%vec(4)**2 + end_orb%vec(4)**2 + start2_orb%vec(4) * end_orb%vec(4)) / 6

end subroutine

!--------------------------------------------------------------
! contains

subroutine coupler_kick_entrance ()

implicit none

dp_coupler = (ele%value(gradient$) * ele%value(gradient_err$)) * &
      ele%value(coupler_strength$) * cos(phase + twopi * ele%value(coupler_phase$))
dp_x_coupler = dp_coupler * cos (twopi * ele%value(coupler_angle$))
dp_y_coupler = dp_coupler * sin (twopi * ele%value(coupler_angle$))

if (nint(ele%value(coupler_at$)) == both_ends$) then
  dp_x_coupler = dp_x_coupler / 2
  dp_y_coupler = dp_y_coupler / 2
endif

if (nint(ele%value(coupler_at$)) == entrance_end$ .or. &
    nint(ele%value(coupler_at$)) == both_ends$) then
  end_orb%vec(2) = end_orb%vec(2) + dp_x_coupler / pc_start
  end_orb%vec(4) = end_orb%vec(4) + dp_y_coupler / pc_start
endif

end subroutine

!--------------------------------------------------------------
! contains

subroutine coupler_kick_exit ()

implicit none

if (nint(ele%value(coupler_at$)) == exit_end$ .or. &
    nint(ele%value(coupler_at$)) == both_ends$) then
  end_orb%vec(2) = end_orb%vec(2) + dp_x_coupler / pc_end
  end_orb%vec(4) = end_orb%vec(4) + dp_y_coupler / pc_end
endif

end subroutine

!--------------------------------------------------------------
! contains

subroutine low_energy_z_correction (end_orb, ele, param)

implicit none

type (coord_struct) end_orb
type (ele_struct) ele
type (lat_param_struct) param

real(rp) p0c, pc, beta, beta0, mass

!

mass = mass_of(param%particle)
e_tot = ele%value(e_tot$)
p0c = ele%value(p0c$)

if (abs(end_orb%vec(6)) < 1e-6 * mass**2 * p0c / e_tot**3) then
  end_orb%vec(5) = end_orb%vec(5) + length * end_orb%vec(6) * (1 - 3 * end_orb%vec(6) / 2) * (mass / e_tot)**2
else
  pc = (1 + end_orb%vec(6)) * ele%value(p0c$)
  call convert_pc_to (pc, param%particle, beta = beta)
  beta0 = ele%value(p0c$) / ele%value(e_tot$)
  end_orb%vec(5) = end_orb%vec(5) + length * (beta - beta0) / beta0
endif

end subroutine

end subroutine
