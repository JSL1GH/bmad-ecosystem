module runge_kutta_mod

use em_field_mod
use tracking_integration_mod
use track1_mod
use wall3d_mod

integer, parameter :: outside_wall$ = 1, wall_transition$ = 2

type runge_kutta_common_struct
  logical :: check_wall_aperture = .false.
  integer :: hit_when = outside_wall$   ! or wall_transition$
end type

type (runge_kutta_common_struct), save :: runge_kutta_com

contains

!-----------------------------------------------------------
!-----------------------------------------------------------
!-----------------------------------------------------------
!+
! Subroutine odeint_bmad (orb_start, ele, param, orb_end, s1, s2, local_ref_frame, err_flag, track)
! 
! Subroutine to do Runge Kutta tracking. This routine is adapted from Numerical
! Recipes.  See the NR book for more details.
!
! Notice that this routine has an two tolerances: 
!   bmad_com%rel_tol_adaptive_trackingrel_tol 
!   bmad_com%abs_tol_adaptive_trackingrel_tol 
! %rel_tol is scalled by the step size to to able to relate it to the final accuracy.
!
! Essentually (assuming random errors) one of these conditions holds:
!      %error in tracking < rel_tol
! or
!     absolute error in tracking < abs_tol
!
! Note: For elements where the reference energy is not constant (lcavity, etc.), and 
! with particles where the velocity is energy dependent (ie non ultra-relativistic), 
! the calculation of z is off since the reference velocity is unknown in the body of 
! the element. In this case, the reference velocity is simply taken to be a 
! constant equal to the reference velocity at the exit end. 
! It is up to the calling routine to handle the correction for this.
!
! Modules needed:
!   use bmad
!
! Input: 
!   orb_start -- Coord_struct: Starting coords: (x, px, y, py, z, delta).
!   ele       -- Ele_struct: Element to track through.
!     %tracking_method -- Determines which subroutine to use to calculate the 
!                         field. Note: BMAD does no supply em_field_custom.
!                           == custom$ then use em_field_custom
!                           /= custom$ then use em_field_standard
!   param     -- lat_param_struct: Beam parameters.
!     %enegy       -- Energy in GeV
!     %particle    -- Particle type [positron$, or electron$]
!   s1        -- Real: Starting point relative to physical entrance.
!   s2        -- Real: Ending point relative physical entrance.
!   local_ref_frame 
!              -- Logical: If True then take the 
!                input and output coordinates as being with 
!                respect to the frame of referene of the element. 
!
! Output:
!   orb_end  -- Coord_struct: Ending coords: (x, px, y, py, z, delta).
!   err_flag -- Logical: Set True if there is an error. False otherwise.
!   track    -- Track_struct, optional: Structure holding the track information.
!-

subroutine odeint_bmad (orb_start, ele, param, orb_end, s1, s2, local_ref_frame, err_flag, track)

use nr, only: zbrent

implicit none

type (coord_struct), intent(in) :: orb_start
type (coord_struct), intent(out) :: orb_end
type (coord_struct) orb_save
type (ele_struct) ele
type (ele_struct), pointer :: hard_ele
type (lat_param_struct) param
type (track_struct), optional :: track

real(rp), intent(in) :: s1, s2
real(rp), parameter :: tiny = 1.0e-30_rp, ds_tiny = 1e-12_rp
real(rp) :: ds, ds_did, ds_next, s, s_sav, rel_tol_eff, abs_tol_eff, sqrt_N, ds_save
real(rp) :: dr_ds(7), r_scal(7), t, s_edge_track, s_edge_hard, direction, position(6)
real(rp) :: wall_d_radius, old_wall_d_radius = 0, s_save, t_save, ds_intersect

integer, parameter :: max_step = 10000
integer :: n_step, hard_end

logical local_ref_frame, err_flag, err, at_hard_edge, has_hit

character(*), parameter :: r_name = 'odeint_bmad'

! Init. Note:
!   rel_tol: Same as eps for odeint scalled by sqrt(ds/(s2-s1))
!                   where ds is the step size for the current step. rel_tol
!                   sets the %error of the result
!   abs_tol: Sets the absolute error of the result

err_flag = .true.
s = s1
direction = sign(1.0_rp, s2-s1)
ds_next = bmad_com%init_ds_adaptive_tracking * direction

orb_end = orb_start
orb_end%s = s1 + ele%s + ele%value(z_offset_tot$) - ele%value(l$)

! For elements where the reference energy is changing the reference energy in the body is 
! taken, by convention, to be the reference energy at the exit end.

call lcavity_reference_energy_correction (ele, param, orb_end)

! If the element is using a hard edge model then need to stop at the hard edges
! to apply the appropriate hard edge kick.

nullify (hard_ele)
call calc_next_fringe_edge (ele, orb_end%direction, s_edge_track, hard_ele, s_edge_hard, hard_end)

! Initial time

t = particle_time(orb_end, ele)

! Save initial point

if (present(track)) then
  s_sav = s - 2.0_rp * track%ds_save
  call init_saved_orbit (track, 1000)
  if ((abs(s-s_sav) > track%ds_save)) call save_a_step (track, ele, param, local_ref_frame, s, orb_end, s_sav)
endif

! now track

err = .false.

do n_step = 1, max_step

  ! Check if we we need to apply a hard edge kick.
  ! For super_slaves there may be multiple hard edges at a single s-position.

  do
    if (.not. associated(hard_ele)) exit
    if ((s-s_edge_track)*direction < -ds_tiny) exit
    call apply_hard_edge_kick (orb_end, s_edge_hard, t, hard_ele, ele, param, hard_end)
    call calc_next_fringe_edge (ele, orb_end%direction, s_edge_track, hard_ele, s_edge_hard, hard_end)
    ! Trying to take a step through a hard edge can drive Runge-Kutta nuts.
    ! So offset s a very tiny amount to avoid this
    s = s + ds_tiny * direction
  enddo

  ! Check if we are done.

  if ((s-s2)*direction > -ds_tiny) then
    if (present(track)) call save_a_step (track, ele, param, local_ref_frame, s, orb_end, s_sav)
    err_flag = .false.
    return
  end if

  ! Need to propagate a step. First calc tolerances.

  call kick_vector_calc (ele, param, s, t, orb_end, local_ref_frame, dr_ds, err)
  if (err) return

  ds = ds_next
  at_hard_edge = .false.

  if ((s+ds-s_edge_track)*direction > 0.0) then
    at_hard_edge = .true.
    ds_save = ds
    ds = s_edge_track - s - ds_tiny*direction / 2
  endif

  sqrt_N = sqrt(abs((s2-s1)/ds))  ! number of steps we would take with this ds
  rel_tol_eff = bmad_com%rel_tol_adaptive_tracking / sqrt_N
  abs_tol_eff = bmad_com%abs_tol_adaptive_tracking / sqrt_N
  r_scal(:) = abs([orb_end%vec(:), t]) + abs(ds*dr_ds(:)) + TINY

  call rk_adaptive_step (ele, param, orb_end, dr_ds, s, t, ds, &
                      rel_tol_eff, abs_tol_eff, r_scal, ds_did, ds_next, local_ref_frame, err)
  if (err) return

  ! Check if hit wall.
  ! If so, interpolate position particle at the hit point

  if (runge_kutta_com%check_wall_aperture) then
    position = [orb_end%vec(1:4), s, 1.0_rp]
    wall_d_radius = wall3d_d_radius (position, ele)
    select case (runge_kutta_com%hit_when)
    case (outside_wall$)
      has_hit = (wall_d_radius > 0)
    case (wall_transition$)
      has_hit = (wall_d_radius * old_wall_d_radius < 0 .and. n_step > 1)
      old_wall_d_radius = wall_d_radius
    case default
      call out_io (s_fatal$, r_name, 'BAD RUNGE_KUTTA_COM%HIT_WHEN SWITCH SETTING!')
      if (global_com%exit_on_error) call err_exit
    end select

    ! Cannot do anything if already hit
    if (has_hit .and. n_step == 1) then
      orb_end%state = lost$
      return
    endif

    if (has_hit) then
      ds_intersect = zbrent (wall_intersection_func, 0.0_rp, ds_did, 1d-10)
      orb_end%state = lost$
      call wall_hit_handler_custom (orb_end, ele, s, t)
      if (orb_end%state /= alive$) return
    endif

    orb_save = orb_end
    s_save = s
    t_save = t

  endif

  ! Save track

  if (present(track)) then
    if ((abs(s-s_sav) > track%ds_save)) call save_a_step (track, ele, param, local_ref_frame, s, orb_end, s_sav)
    if (ds_did == ds) then
      track%n_ok = track%n_ok + 1
    else
      track%n_bad = track%n_bad + 1
    end if
  endif

  ! Calculate next step size. If there was a hard edge then take into account the step that would have
  ! been taken if no hard edge was present.

  if (at_hard_edge .and. abs(ds_next) >= abs(ds)) then
    ds_next = max(abs(ds_save), abs(ds_next)) * direction
  endif

  if ((s + ds_next - s2) * direction > 0) then
    ds_next = s2 - s
    at_hard_edge = .true.
  endif

  if (abs(ds_next) <  bmad_com%min_ds_adaptive_tracking) ds_next = direction * bmad_com%min_ds_adaptive_tracking

  ! Check for step size smaller than minimum. If so we consider the particle lost
 
  if (.not. at_hard_edge .and. abs(ds) < bmad_com%fatal_ds_adaptive_tracking) exit

end do

! Here if step size too small or too many steps

call out_io (s_error$, r_name, 'STEP SIZE IS TOO SMALL WHILE TRACKING THROUGH: ' // ele%name, &
                               'AT S-POSITION FROM ENTRANCE: \F10.5\ ', &
                               'COULD BE DUE TO A DISCONTINUITY IN THE FIELD ', &
                               r_array = [s])

orb_end%state = lost$
err_flag = .false.

!-----------------------------------------------------------------
contains

function wall_intersection_func (ds) result (d_radius)

real(rp), intent(in) :: ds
real(rp) d_radius
real(rp) t_new, r_err(7), dr_ds(7)

!

call rk_step1 (ele, param, orb_save, dr_ds, s_save, t_save, ds, orb_end, t, r_err, local_ref_frame, err_flag)
position = [orb_end%vec(1:4), s, 1.0_rp]
wall_d_radius = wall3d_d_radius (position, ele)

s = s_save + ds
orb_end%s = s
orb_end%t = orb_save%t + (t - t_save)

end function wall_intersection_func

end subroutine odeint_bmad

!-----------------------------------------------------------------
!-----------------------------------------------------------------

subroutine rk_adaptive_step (ele, param, orb, dr_ds, s, t, ds_try, rel_tol, abs_tol, &
                                       r_scal, ds_did, ds_next, local_ref_frame, err_flag)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (coord_struct) orb, orb_new

real(rp), intent(in)    :: dr_ds(7), r_scal(7)
real(rp), intent(inout) :: s, t
real(rp), intent(in)    :: ds_try, rel_tol, abs_tol
real(rp), intent(out)   :: ds_did, ds_next

real(rp) :: err_max, ds, ds_temp, s_new, p2
real(rp) :: r_err(7), r_temp(7)
real(rp) :: rel_pc, t_new
real(rp), parameter :: safety = 0.9_rp, p_grow = -0.2_rp
real(rp), parameter :: p_shrink = -0.25_rp, err_con = 1.89e-4

logical local_ref_frame, err_flag
character(20), parameter :: r_name = 'rk_adaptive_step'

!

ds = ds_try
orb_new = orb

do

  call rk_step1 (ele, param, orb, dr_ds, s, t, ds, orb_new, t_new, r_err, local_ref_frame, err_flag)
  ! Can get errors due to step size too large 
  if (err_flag) then
    if (ds < 1d-3) THEN
      call out_io (s_fatal$, r_name, 'CANNOT COMPLETE STEP. ABORTING.')
      if (global_com%exit_on_error) call err_exit
      return
    endif
    ds_temp = ds / 10
  else
    err_max = maxval(abs(r_err(:)/(r_scal(:)*rel_tol + abs_tol)))
    if (err_max <=  1.0) exit
    ds_temp = safety * ds * (err_max**p_shrink)
  endif
  ds = sign(max(abs(ds_temp), 0.1_rp*abs(ds)), ds)
  s_new = s + ds

  if (s_new == s) then
    err_flag = .true.
    call out_io (s_fatal$, r_name, 'STEPSIZE UNDERFLOW IN ELEMENT: ' // ele%name)
    if (global_com%exit_on_error) call err_exit
    return
  endif

end do

if (err_max > err_con) then
  ds_next = safety*ds*(err_max**p_grow)
else
  ds_next = 5.0_rp * ds
end if

ds_did = ds
s = s+ds

orb_new%s = orb%s + ds
orb_new%t = orb%t + (t_new - t)

orb = orb_new
t = t_new
err_flag = .false.

end subroutine rk_adaptive_step

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------

subroutine rk_step1 (ele, param, orb, dr_ds, s, t, ds, orb_new, t_new, r_err, local_ref_frame, err)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (coord_struct) orb, orb_new, orb_temp(5)

real(rp), intent(in) :: dr_ds(7)
real(rp), intent(in) :: s, t, ds
real(rp), intent(out) :: r_err(7), t_new
real(rp) :: ak2(7), ak3(7), ak4(7), ak5(7), ak6(7), t_temp(5)
real(rp), parameter :: a2=0.2_rp, a3=0.3_rp, a4=0.6_rp, &
    a5=1.0_rp, a6=0.875_rp, b21=0.2_rp, b31=3.0_rp/40.0_rp, &
    b32=9.0_rp/40.0_rp, b41=0.3_rp, b42=-0.9_rp, b43=1.2_rp, &
    b51=-11.0_rp/54.0_rp, b52=2.5_rp, b53=-70.0_rp/27.0_rp, &
    b54=35.0_rp/27.0_rp, &
    b61=1631.0_rp/55296.0_rp, b62=175.0_rp/512.0_rp, &
    b63=575.0_rp/13824.0_rp, b64=44275.0_rp/110592.0_rp, &
    b65=253.0_rp/4096.0_rp, c1=37.0_rp/378.0_rp, &
    c3=250.0_rp/621.0_rp, c4=125.0_rp/594.0_rp, &
    c6=512.0_rp/1771.0_rp, dc1=c1-2825.0_rp/27648.0_rp, &
    dc3=c3-18575.0_rp/48384.0_rp, dc4=c4-13525.0_rp/55296.0_rp, &
    dc5=-277.0_rp/14336.0_rp, dc6=c6-0.25_rp

complex(rp) dspin1(2), dspin3(2), dspin4(2), dspin6(2)

logical local_ref_frame, err

!

call transfer_this_orbit (orb, b21*ds*dr_ds(1:6), orb_temp(1))
t_temp(1) = t + b21*ds*dr_ds(7)
call kick_vector_calc(ele, param, s + a2*ds, t_temp(1), orb_temp(1), local_ref_frame, ak2, err)
if (err) return

call transfer_this_orbit (orb, ds*(b31*dr_ds(1:6) + b32*ak2(1:6)), orb_temp(2))
t_temp(2) = t + ds*(b31*dr_ds(7) + b32*ak2(7))
call kick_vector_calc(ele, param, s + a3*ds, t_temp(2), orb_temp(2), local_ref_frame, ak3, err)
if (err) return

call transfer_this_orbit (orb, ds*(b41*dr_ds(1:6) + b42*ak2(1:6) + b43*ak3(1:6)), orb_temp(3))
t_temp(3) = t + ds*(b41*dr_ds(7) + b42*ak2(7) + b43*ak3(7))
call kick_vector_calc(ele, param, s + a4*ds, t_temp(3), orb_temp(3), local_ref_frame, ak4, err)
if (err) return

call transfer_this_orbit (orb, ds*(b51*dr_ds(1:6) + b52*ak2(1:6) + b53*ak3(1:6) + b54*ak4(1:6)), orb_temp(4))
t_temp(4) = t + ds*(b51*dr_ds(7) + b52*ak2(7) + b53*ak3(7) + b54*ak4(7))
call kick_vector_calc(ele, param, s + a5*ds, t_temp(4), orb_temp(4), local_ref_frame, ak5, err)
if (err) return

call transfer_this_orbit (orb, ds*(b61*dr_ds(1:6) + b62*ak2(1:6) + b63*ak3(1:6) + b64*ak4(1:6) + b65*ak5(1:6)), orb_temp(5))
t_temp(5) = t + ds*(b61*dr_ds(7) + b62*ak2(7) + b63*ak3(7) + b64*ak4(7) + b65*ak5(7))
call kick_vector_calc(ele, param, s + a6*ds, t_temp(5), orb_temp(5), local_ref_frame, ak6, err)
if (err) return

call transfer_this_orbit (orb, ds*(c1*dr_ds(1:6) + c3*ak3(1:6) + c4*ak4(1:6) + c6*ak6(1:6)), orb_new)
t_new = t + ds*(c1*dr_ds(7) + c3*ak3(7) + c4*ak4(7) + c6*ak6(7))
r_err=ds*(dc1*dr_ds + dc3*ak3 + dc4*ak4 + dc5*ak5 + dc6*ak6)

! Spin

if (bmad_com%spin_tracking_on .and. ele%spin_tracking_method == tracking$) then
  call dspin_dz (ele, param, s,        t,         orb,         local_ref_frame, dspin1)
  call dspin_dz (ele, param, s + a3*ds, t_temp(2), orb_temp(2), local_ref_frame, dspin3)
  call dspin_dz (ele, param, s + a4*ds, t_temp(3), orb_temp(3), local_ref_frame, dspin4)
  call dspin_dz (ele, param, s + a6*ds, t_temp(5), orb_temp(5), local_ref_frame, dspin6)

  orb_new%spin = orb%spin + ds * (c1*dspin1 + c3*dspin3 + c4*dspin4 + c6*dspin6)
endif

!----------------------------------------------------------
contains

subroutine transfer_this_orbit (orb_in, dvec, orb_out)

type (coord_struct) orb_in, orb_out
real(rp) dvec(6)

!

orb_out%vec = orb_in%vec + dvec
orb_out%p0c = orb_in%p0c 

if (dvec(6) == 0) then
  orb_out%beta = orb_in%beta
else
  call convert_pc_to (orb_out%p0c * (1 + orb_out%vec(6)), param%particle, beta = orb_out%beta)
endif

end subroutine

!----------------------------------------------------------
! contains

subroutine dspin_dz (ele, param, s, t, orb, local_ref_frame, dspin)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (coord_struct) orb
type (em_field_struct) :: field

real(rp) s, t
real(rp) :: Omega(3)

complex(rp) :: dspin(2), quaternion(2,2)

logical local_ref_frame

! this uses a modified Omega' = -Omega/v_z

Omega = spin_omega_at (field, orb, ele, param, s)
quaternion = (i_imaginary/2.0_rp)* (pauli(1)%sigma*Omega(1) + pauli(2)%sigma*Omega(2) + pauli(3)%sigma*Omega(3))

!   quaternion = normalized_quaternion (quaternion)

dspin = matmul(quaternion, orb%spin)

end subroutine dspin_dz

end subroutine rk_step1

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine kick_vector_calc (ele, param, s_rel, t_rel, orbit, local_ref_frame, dr_ds, err)
!
! Subroutine to calculate the dr/ds "kick vector" where
!     r = [x, p_x, y, p_y, z, p_z, t] 
!
! Remember: In order to simplify the calculation, in the body of any element, P0 is taken to be 
! the P0 at the exit end of the element.
!
!   dr(1)/ds = dx/dt * dt/ds
!   where:
!     dx/dt = v_x = p_x / (1 + p_z)
!     dt/ds = (1 + g*x) / v_s
!     g = 1/rho, rho = bending radius (nonzero only in a dipole)
!
!   dr(2)/ds = dP_x/dt * dt/ds / P0 + g_x * P_z
!   where:
!     dP_x/dt = EM_Force_x
!     g_x = bending in x-plane.
!
!   dr(3)/ds = dy/dt * dt/ds
!   where:
!     dy/dt = v_x 
! 
!   dr(4)/ds = dP_y/dt * ds/dt / P0 + g_y * P_z
!   where:
!     dP_y/dt = EM_Force_y
!     g_y = bending in y-plane.
!
!   dr(5)/ds = beta * c_light * [dt/ds(ref) - dt/ds] + dbeta/ds * c_light * [t(ref) - t]
!            = beta * c_light * [dt/ds(ref) - dt/ds] + dbeta/ds * vec(5) / beta
!   where:
!     dt/ds(ref) = 1 / beta(ref)
!     Note: dt/ds(ref) formula is inaccurate at low energy in an lcavity.
!
!   dr(6)/ds = (EM_Force dot v_hat) * dt/ds / P0
!   where:
!      v_hat = velocity normalized to 1. 
!
! Modules needed:
!   use bmad
!
! Input:
!   ele   -- Ele_struct: Element being tracked thorugh.
!   param -- lat_param_struct: Lattice parameters.
!   s_rel -- Real(rp): Distance from the start of the element to the particle.
!   t_rel  -- Real(rp): Time relative to the reference particle.
!   orbit -- coord_struct: Position of particle.
!   local_ref_frame 
!         -- Logical, If True then take the input coordinates 
!               as being with respect to the frame of referene of the element. 
!
! Output:
!   dr_ds(7) -- Real(rp): Kick vector.
!   err      -- Logical: Set True if there is an error.
!-

subroutine kick_vector_calc (ele, param, s_rel, t_rel, orbit, local_ref_frame, dr_ds, err)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (em_field_struct) field
type (coord_struct) orbit

real(rp), intent(in) :: s_rel, t_rel 
real(rp), intent(out) :: dr_ds(7)
real(rp) f_bend, gx_bend, gy_bend, dt_ds, dp_ds, dbeta_ds
real(rp) vel(3), E_force(3), B_force(3)
real(rp) e_tot, dt_ds_ref, p0, beta0, v2, pz_p0

logical :: local_ref_frame, err

character(24), parameter :: r_name = 'kick_vector_calc'

!

err = .true.
beta0 = ele%value(p0c$) / ele%value(e_tot$) 
dt_ds_ref = 1 / (beta0 * c_light)
p0 = ele%value(p0c$) / c_light
e_tot = orbit%p0c * (1 + orbit%vec(6)) / orbit%beta

! calculate the field

call em_field_calc (ele, param, s_rel, t_rel, orbit, local_ref_frame, field, .false., err)
if (err) return

! Bend factor

vel(1:2) = [orbit%vec(2), orbit%vec(4)] / (1 + orbit%vec(6))
v2 = vel(1)**2 + vel(2)**2
if (v2 > 1) return
vel = orbit%beta * c_light * [vel(1), vel(2), sqrt(1 - v2) * ele%orientation]
E_force = charge_of(param%particle) * param%rel_tracking_charge * field%E
B_force = charge_of(param%particle) * param%rel_tracking_charge * cross_product(vel, field%B)

f_bend = 1
gx_bend = 0; gy_bend = 0

if (ele%key == sbend$) then
  if (ele%value(ref_tilt_tot$) /= 0 .and. .not. local_ref_frame) then
    gx_bend = ele%value(g$) * cos(ele%value(ref_tilt_tot$))
    gy_bend = ele%value(g$) * sin(ele%value(ref_tilt_tot$))
  else
    gx_bend = ele%value(g$)
  endif
  f_bend = 1 + orbit%vec(1) * gx_bend + orbit%vec(3) * gy_bend
endif

dt_ds = f_bend / abs(vel(3))
dp_ds = dot_product(E_force, vel) * dt_ds / (orbit%beta * c_light)
dbeta_ds = mass_of(param%particle)**2 * dp_ds * c_light / e_tot**3
pz_p0 = (1 + orbit%vec(6)) * abs(vel(3)) / (orbit%beta * c_light)  ! Pz / P0

dr_ds(1) = vel(1) * dt_ds
dr_ds(2) = (E_force(1) + B_force(1)) * dt_ds / p0 + gx_bend * pz_p0
dr_ds(3) = vel(2) * dt_ds
dr_ds(4) = (E_force(2) + B_force(2)) * dt_ds / p0 + gy_bend * pz_p0
dr_ds(5) = orbit%beta * c_light * (dt_ds_ref - dt_ds) + dbeta_ds * orbit%vec(5) / orbit%beta
dr_ds(6) = dp_ds / p0
dr_ds(7) = dt_ds

err = .false.

end subroutine kick_vector_calc

end module
