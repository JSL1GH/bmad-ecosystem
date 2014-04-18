module time_tracker_mod

use bmad_struct
use beam_def_struct
use em_field_mod
use wall3d_mod
use lat_geometry_mod
use runge_kutta_mod ! for common struct only

contains

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine odeint_bmad_time (orb, ele, param, s1, s2, t_rel, &
!                             dt1, local_ref_frame, err_flag, track)
! 
! Subroutine to do Runge Kutta tracking in time. This routine is adapted from Numerical
! Recipes.  See the NR book for more details.
!
!
! Modules needed:
!   use bmad
!
! Input: 
!   orb   -- Coord_struct: Starting coords: (x, px, y, py, s, ps) [t-based]
!   ele     -- Ele_struct: Element to track through.
!     %tracking_method -- Determines which subroutine to use to calculate the 
!                         field. Note: BMAD does no supply em_field_custom.
!                           == custom$ then use em_field_custom
!                           /= custom$ then use em_field_standard
!   param   -- lat_param_struct: Beam parameters.
!     %enegy       -- Energy in GeV
!     %particle    -- Particle type [positron$, or electron$]
!   s1      -- Real: Starting point.
!   s2      -- Real: Ending point.
!   t_rel   -- Real: time relative to entering reference time
!   dt1      -- Real: Initial guess for a time step size.
!   local_ref_frame 
!           -- Logical: If True then take the 
!                input and output coordinates as being with 
!                respect to the frame of referene of the element. 
!
!   track   -- Track_struct: Structure holding the track information.
!     %save_track -- Logical: Set True if track is to be saved.
!
! Output:
!   orb      -- Coord_struct: Ending coords: (x, px, y, py, s, ps) [t-based]
!   err_flag -- Logical: Set True if there is an error. False otherwise.
!   track    -- Track_struct: Structure holding the track information.
!
!-

subroutine odeint_bmad_time (orb, ele, param, s1, s2, t_rel, &
                                dt1, local_ref_frame, err_flag, track)

use nr, only: zbrent

implicit none

type (coord_struct), intent(inout), target :: orb
type (coord_struct), target :: orb_old
type (coord_struct) :: orb_save
type (ele_struct), target :: ele
type (lat_param_struct), target ::  param
type (em_field_struct) :: saved_field
type (track_struct), optional :: track

real(rp), intent(in) :: s1, s2, dt1
real(rp), target :: t_rel, t_old, dt_tol
real(rp) :: dt, dt_did, dt_next, ds_safe, t_save, dt_save, s_save
real(rp), target  :: dvec_dt(6), vec_err(6), s_target 
real(rp) :: wall_d_radius, old_wall_d_radius = 0

integer, parameter :: max_step = 100000
integer :: n_step, n_pt

logical, target :: local_ref_frame
logical :: exit_flag, err_flag, err, zbrent_needed, add_ds_safe, has_hit

character(30), parameter :: r_name = 'odeint_bmad_time'

! init
ds_safe = bmad_com%significant_length / 10
dt_next = dt1

! local s coordinates for vec(5)
orb%vec(5) = orb%s - (ele%s + ele%value(z_offset_tot$) - ele%value(l$))

! Allocate track arrays

!n_pt = max_step
if ( present(track) ) then
   dt_save = track%ds_save/c_light
   t_save = t_rel
endif 

! Now Track

exit_flag = .false.
err_flag = .true.
has_hit = .false. 

do n_step = 1, max_step

  ! Single Runge-Kutta step. Updates orb% vec(6), s, and t 

  dt = dt_next
  orb_old = orb
  t_old = t_rel
  call rk_adaptive_time_step (ele, param, orb, t_rel, dt, dt_did, dt_next, local_ref_frame, err)

  ! Check entrance and exit faces
  if ((orb%vec(5) < s1 + ds_safe .and. orb%vec(6) < 0)  &
       .or. (orb%vec(5) > s2 - ds_safe .and. orb%vec(6) > 0)) then
    zbrent_needed = .true.
    add_ds_safe = .true.

    if (orb%vec(5) < s1 + ds_safe) then 
      orb%location = upstream_end$
      s_target = s1
      if (orb%vec(5) > s1 - ds_safe) zbrent_needed = .false.
      if (s1 == 0) add_ds_safe = .false.
    else
      orb%location = downstream_end$
      s_target = s2
      if (orb%vec(5) < s2 + ds_safe) zbrent_needed = .false.
      if (abs(s2 - ele%value(l$)) < ds_safe) add_ds_safe = .false.
    endif

    exit_flag = .true.

    !---
    dt_tol = ds_safe / (orb%beta * c_light)
    if (zbrent_needed) then
      ! Save old_orb, and reinstate after zbrent so that the wall check can still work. 
      orb_save = orb_old
      dt = zbrent (delta_s_target, 0.0_rp, dt_did, dt_tol)
      orb_old = orb_save
    endif
    ! Trying to take a step through a hard edge can drive Runge-Kutta nuts.
    ! So offset s a very tiny amount to avoid this
    orb%vec(5) = s_target 
    if (add_ds_safe) orb%vec(5) = orb%vec(5) + sign(ds_safe, orb%vec(6))
    orb%s = orb%vec(5) + ele%s - ele%value(l$)
  endif

  ! Wall check
  ! Adapted from runge_kutta_mod's odeint_bmad:
  ! Check if hit wall.
  ! If so, interpolate position particle at the hit point

  if (runge_kutta_com%check_wall_aperture) then
    wall_d_radius = wall3d_d_radius (orb%vec, ele)
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
      orb%state = lost$
    endif

    if (has_hit) then
      dt_tol = ds_safe / (orb%beta * c_light) 
      if (.not. exit_flag) dt = zbrent (wall_intersection_func, 0.0_rp, dt_did, dt_tol)
      orb%state = lost$
      ! Convert for wall handler
      call convert_particle_coordinates_t_to_s(orb, ele%ref_time)
      call wall_hit_handler_custom (orb, ele, orb%s, orb%t)
      call convert_particle_coordinates_s_to_t(orb)
      ! Restore vec(5) to relative s 
      orb%vec(5) = orb%s - (ele%s + ele%value(z_offset_tot$) - ele%value(l$))
    endif
  endif

 
  if (orb%state /= alive$) exit_flag = .true.
  
  
  !Save track
  if ( present(track) ) then
    !Check if we are past a save time, or if exited
    if (t_rel >= t_save .or. exit_flag) then
      !TODO: Set local_ref_frame=.true., and make sure offset_particle does the right thing
      call save_a_step (track, ele, param, .false., orb%vec(5), orb, s_save)
    
      !track%n_pt = track%n_pt + 1
      !n_pt = track%n_pt
      !track%orb(n_pt) = orb
      !track%orb(n_pt)%ix_ele => ele%ix_ele
      !Query the local field to save
      call em_field_calc (ele, param, orb%vec(5), t_rel, orb, local_ref_frame, saved_field, .false., err_flag)
      if (err_flag) return
      track%field(track%n_pt) = saved_field
       !Set next save time 
       t_save = t_rel + dt_save
    end if
  endif

  ! Exit when the particle hits surface s1 or s2, or hits wall
  if (exit_flag) then
    err_flag = .false. 
    return
  endif

end do

if (global_com%type_out) then
  call out_io (s_warn$, r_name, 'STEPS EXCEEDED MAX_STEP FOR ELE: '//ele%name )
  orb%location = inside$
  return
end if

if (global_com%exit_on_error) call err_exit




contains

  !------------------------------------------------------------------------------------------------
  ! function for zbrent to calculate timestep to exit face surface

  function delta_s_target (this_dt)
  
  real(rp), intent(in)  :: this_dt
  real(rp) :: delta_s_target
  logical err_flag
  !
  call rk_time_step1 (ele, param, orb_old, t_old, this_dt, &
	 				  orb, vec_err, local_ref_frame, err_flag = err_flag)
  delta_s_target = orb%vec(5) - s_target
  t_rel = t_old + this_dt
	
  end function delta_s_target

  !------------------------------------------------------------------------------------------------
  function wall_intersection_func (this_dt) result (d_radius)

  real(rp), intent(in) :: this_dt
  real(rp) d_radius
  logical err_flag
  !
  call rk_time_step1 (ele, param, orb_old, t_old, this_dt, &
  	 				  orb, vec_err, local_ref_frame, err_flag = err_flag)
	 				  	 				  
  d_radius = wall3d_d_radius (orb%vec, ele)
  t_rel = t_old + this_dt
  end function wall_intersection_func

end subroutine odeint_bmad_time

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------

subroutine rk_adaptive_time_step (ele, param, orb, t, dt_try, dt_did, dt_next, local_ref_frame, err_flag)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (coord_struct) orb, orb_new

real(rp), intent(inout) :: t
real(rp), intent(in)    :: dt_try
real(rp), intent(out)   :: dt_did, dt_next

real(rp) :: sqrt_n, err_max, dt, dt_temp, t_new, p2, rel_pc
real(rp) :: r_err(6), r_temp(6), dr_dt(6)
real(rp) :: r_scal(6), rel_tol, abs_tol
real(rp), parameter :: safety = 0.9_rp, p_grow = -0.2_rp
real(rp), parameter :: p_shrink = -0.25_rp, err_con = 1.89e-4
real(rp), parameter :: tiny = 1.0e-30_rp

logical local_ref_frame, err_flag
character(24), parameter :: r_name = 'rk_adaptive_time_step'

! Calc tolerances
! Note that s is in the element frame

call em_field_kick_vector_time (ele, param, t, orb, local_ref_frame, dr_dt, err_flag) 
if (err_flag) return

sqrt_N = sqrt(abs(1/(c_light*dt_try)))  ! number of steps we would take to cover 1 meter
rel_tol = bmad_com%rel_tol_adaptive_tracking / sqrt_N
abs_tol = bmad_com%abs_tol_adaptive_tracking / sqrt_N

!

dt = dt_try
orb_new = orb

do

  call rk_time_step1 (ele, param, orb, t, dt, orb_new, r_err, local_ref_frame, dr_dt, err_flag)
  ! Can get errors due to step size too large 
  if (err_flag) then
    if (dt < 1d-3/c_light) then
      call out_io (s_fatal$, r_name, 'CANNOT COMPLETE TIME STEP. ABORTING.')
      if (global_com%exit_on_error) call err_exit
      return
    endif
    dt_temp = dt / 10
  else
    r_scal(:) = abs(orb%vec) + abs(orb_new%vec) + TINY
    r_scal(1:5:2) = r_scal(1:5:2) + [0.01_rp, 0.01_rp, ele%value(L$)]
    !Note that cp is in eV, so 1.0_rp is 1 eV
    r_scal(2:6:2) = r_scal(2:6:2) + 1.0_rp + 1d-4* (abs(orb%vec(2))+abs(orb%vec(4))+abs(orb%vec(6)))
    err_max = maxval(abs(r_err(:)/(r_scal(:)*rel_tol + abs_tol)))
    if (err_max <=  1.0) exit
    dt_temp = safety * dt * (err_max**p_shrink)
  endif
  dt = sign(max(abs(dt_temp), 0.1_rp*abs(dt)), dt)
  t_new = t + dt

  if (t_new == t) then
    err_flag = .true.
    call out_io (s_fatal$, r_name, 'STEPSIZE UNDERFLOW IN ELEMENT: ' // ele%name)
    if (global_com%exit_on_error) call err_exit
    return
  endif

end do

if (err_max > err_con) then
  dt_next = safety*dt*(err_max**p_grow)
else
  dt_next = 5.0_rp * dt
end if

! Increase step size, limited by an estimated next step ds = L/4

if (abs(dr_dt(5)*dt_next) > ele%value(L$)/4.0_rp) then
  dt_next = abs(ele%value(L$)/8.0_rp / dr_dt(5))
endif

! finish

dt_did = dt
t = t+dt

orb = orb_new

end subroutine rk_adaptive_time_step

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
subroutine rk_time_step1 (ele, param, orb, t, dt, orb_new, r_err, local_ref_frame, dr_dt, err_flag)

!Very similar to rk_step1_bmad, except that em_field_kick_vector_time is called
!  and orb_new%s and %t are updated to the global values

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (coord_struct) orb, orb_new, orb_temp

real(rp), optional, intent(in) :: dr_dt(6)
real(rp), intent(in) :: t, dt
real(rp), intent(out) :: r_err(6)
real(rp) :: dr_dt1(6), dr_dt2(6), dr_dt3(6), dr_dt4(6), dr_dt5(6), dr_dt6(6), r_temp(6), pc
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

logical local_ref_frame, err_flag

!

if (present(dr_dt)) then
  dr_dt1 = dr_dt
else
  call em_field_kick_vector_time(ele, param, t, orb, local_ref_frame, dr_dt1, err_flag)
  if (err_flag) return
endif

orb_temp%vec = orb%vec + b21*dt*dr_dt1
call em_field_kick_vector_time(ele, param, t+a2*dt, orb_temp, local_ref_frame, dr_dt2, err_flag)
if (err_flag) return

orb_temp%vec = orb%vec + dt*(b31*dr_dt1+b32*dr_dt2)
call em_field_kick_vector_time(ele, param, t+a3*dt, orb_temp, local_ref_frame, dr_dt3, err_flag) 
if (err_flag) return

orb_temp%vec = orb%vec + dt*(b41*dr_dt1+b42*dr_dt2+b43*dr_dt3)
call em_field_kick_vector_time(ele, param, t+a4*dt, orb_temp, local_ref_frame, dr_dt4, err_flag)
if (err_flag) return

orb_temp%vec = orb%vec + dt*(b51*dr_dt1+b52*dr_dt2+b53*dr_dt3+b54*dr_dt4)
call em_field_kick_vector_time(ele, param, t+a5*dt, orb_temp, local_ref_frame, dr_dt5, err_flag)
if (err_flag) return

orb_temp%vec = orb%vec + dt*(b61*dr_dt1+b62*dr_dt2+b63*dr_dt3+b64*dr_dt4+b65*dr_dt5)
call em_field_kick_vector_time(ele, param, t+a6*dt, orb_temp, local_ref_frame, dr_dt6, err_flag)
if (err_flag) return

!Output new orb and error vector

orb_new%vec = orb%vec +dt*(c1*dr_dt1+c3*dr_dt3+c4*dr_dt4+c6*dr_dt6)
orb_new%t = orb%t + dt
orb_new%s = orb%s + orb_new%vec(5) - orb%vec(5)
pc = sqrt(orb_new%vec(2)**2 +orb_new%vec(4)**2 + orb_new%vec(6)**2)
call convert_pc_to (pc, param%particle, beta = orb_new%beta)

r_err = dt*(dc1*dr_dt1+dc3*dr_dt3+dc4*dr_dt4+dc5*dr_dt5+dc6*dr_dt6)

end subroutine rk_time_step1



!------------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------------
!+
! Subroutine em_field_kick_vector_time (ele, param, t_rel, orbit, local_ref_frame, dvec_dt, err_flag)
!
! Subroutine to convert particle coordinates from t-based to s-based system. 
!
! Modules needed:
!   use bmad
!
! Input:
!   ele             -- coord_struct: input particle
!   param           -- real: Reference momentum. The sign indicates direction of p_s. 
!   t_rel           -- real: element coordinate system: t
!   orbit           -- coord_struct:
!                    %vec(1:6)  in t-based system
!   local_ref_frame --
!   err_flag        -- logical: Set True if there is an error. False otherwise.
! Output:
!    dvec_dt(6)  -- real(rp): Derivatives.
!-

subroutine em_field_kick_vector_time (ele, param, t_rel, orbit, local_ref_frame, dvec_dt, err_flag)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
type (em_field_struct) field

type (coord_struct), intent(in) :: orbit

real(rp), intent(in) :: t_rel    
real(rp), intent(out) :: dvec_dt(6)

real(rp) f_bend, kappa_x, kappa_y
real(rp) vel(3), force(3)
real(rp) :: pc, e_tot, mc2, gamma, charge, beta, p0, h

logical :: local_ref_frame, err_flag

character(28), parameter :: r_name = 'em_field_kick_vector_time'

! calculate the field. 
! Note that only orbit%vec(1) = x and orbit%vec(3) = y are used in em_field_calc,
!	and they coincide in both coordinate systems, so we can use the 'normal' routine:

call em_field_calc (ele, param, orbit%vec(5), t_rel, orbit, local_ref_frame, field, .false., err_flag)
if (err_flag) return

! Get e_tot from momentum
! velocities v_x, v_y, v_s:  c*[c*p_x, c*p_y, c*p_s]/e_tot

mc2 = mass_of(param%particle) ! Note: mc2 is in eV
charge = charge_of(param%particle) ! Note: charge is in units of |e_charge|

e_tot = sqrt( orbit%vec(2)**2 +  orbit%vec(4)**2 +  orbit%vec(6) **2 + mc2**2) 
vel(1:3) = c_light*[  orbit%vec(2),  orbit%vec(4),  orbit%vec(6) ]/ e_tot 

! Computation for dr/dt where r(t) = [x, c*p_x, y, c*p_y, s, c*p_s]
! 
! p_x = m c \beta_x \gamma
! p_y = m c \beta_y \gamma
! p_s = m c h \beta_s \gamma 
!
! Note: v_s = (ds/dt) h, so ds/dt = v_s / h in the equations below
!
! h = 1 + \kappa_x * x + \kappa_y * y
!
! dx/dt   = v_x 
! dcp_x/dt = cp_s * v_s * \kappa_x / h + c*charge * ( Ex + v_y * Bs - v_s * By )
! dy/dt   = v_y
! dcp_y/dt = cp_s * v_s * \kappa_y / h + c*charge * ( Ey + * Bx - v_x * Bs )
! ds/dt = v_s / h 
! dcp_s/dt = -(1/h) * cp_s * ( v_x * \kappa_x + v_y * \kappa_y ) + c*charge * ( Es + v_x By - v_y Bx )

! Straight coordinate systems have a simple Lorentz force

force = charge * (field%E + cross_product(vel, field%B))
dvec_dt(1) = vel(1)
dvec_dt(2) = c_light*force(1)
dvec_dt(3) = vel(2)
dvec_dt(4) = c_light*force(2)
dvec_dt(5) = vel(3)
dvec_dt(6) = c_light*force(3)

! Curvilinear coordinates have added terms

if (ele%key == sbend$) then   
  if (ele%value(ref_tilt_tot$) /= 0 .and. .not. local_ref_frame) then
    kappa_x = ele%value(g$) * cos(ele%value(ref_tilt_tot$))
    kappa_y = ele%value(g$) * sin(ele%value(ref_tilt_tot$))
  else
    kappa_x = ele%value(g$)
    kappa_y = 0
  endif
  h = 1 + kappa_x * orbit%vec(1) + kappa_y * orbit%vec(3) ! h = 1 + \kappa_x * x + \kappa_y * y

  dvec_dt(2) = dvec_dt(2) + orbit%vec(6) * vel(3) * kappa_x / h
  dvec_dt(4) = dvec_dt(4) + orbit%vec(6) * vel(3) * kappa_y / h
  dvec_dt(5) = vel(3) / h
  dvec_dt(6) = dvec_dt(6) - orbit%vec(6) * (vel(1)*kappa_x + vel(2)*kappa_y) / h
endif

end subroutine em_field_kick_vector_time
  
  

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Function particle_in_new_frame_time(orb, ele) 
!  result (orb_in_ele)
! 
! Takes a particle in time coordinates, and returns a particle in the local frame of ele.
!   If the particle's s position is not within the bounds of ele, the function will 
!   step to adjacent elements until a containing element is found. 
!   Note that this function requires that there is an associated(ele%branch)
!
! Modules needed:
!   use bmad
!   use capillary_mod
!
! Input
!   orb        -- coord_struct: Particle in [t-based] coordinates relative to
!                               orb%ix_ele
!   ele        -- ele_struct: Element to 
!
! Output
!   orb_in_ele -- coord_struct: Particle in [t-based] coordinates, relative to 
!                               orb_in_ele%ix_ele
!           
!
!-
  
function particle_in_new_frame_time(orb, ele) result (orb_in_ele)

implicit none

type (coord_struct) :: orb, orb_in_ele
type (floor_position_struct) :: position0, position1
type (ele_struct), target :: ele
type (ele_struct), pointer :: ele1
type (branch_struct), pointer :: branch
real(rp) :: ww_mat(3,3)

integer :: ix_ele, status
logical :: err

character(30), parameter :: r_name = 'particle_in_new_frame_time'

!

! Check that ele is in fact a different ele than orb%ix_ele
if (orb%ix_ele == ele%ix_ele) then
  orb_in_ele = orb
  return
endif

!Multipass elements need to choose the correct wall

! Make sure ele has a branch
if (.not. associated (ele%branch) ) then
      call out_io (s_fatal$, r_name, 'ELE HAS NO ASSOCIATED BRANCH')
      if (global_com%exit_on_error) call err_exit
endif


branch => ele%branch

!set [x, y, z]_0
position0%r = orb%vec(1:5:2)
position0%theta = 0.0_rp
position0%phi = 0.0_rp
position0%psi = 0.0_rp

! Find [x, y, s]_1
call switch_local_positions (position0, branch%ele(orb%ix_ele), ele, position1, ele1, ww_mat)

! Assign [x, y, s]
orb_in_ele%vec(1:5:2) = position1%r

! Use ww_mat to rotate momenta
orb_in_ele%vec(2:6:2) =  matmul(ww_mat, orb%vec(2:6:2) )

! Set other things
orb_in_ele%location = inside$
orb_in_ele%ix_ele = ele1%ix_ele
orb_in_ele%s = orb_in_ele%vec(5) + ele1%s - ele1%value(L$)

end function particle_in_new_frame_time

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function particle_in_global_frame (orb, in_time_coordinates, w_mat_out) result (particle) 
!
! Returns the particle in global time coordinates given is coordinates orb in lattice lat.
!   
!
! Module needed:
!   lat_geometry_mod
!
! Input:
!   orb                 -- Coord_struct: particle in s-coordinates
!   branch              -- branch_struct: branch that contains branch%ele(orb%ix_ele)
!   in_time_coordinates -- Logical (optional): Default is false. If true, orb
!                            will taken as in time coordinates.    
!
! Result:
!   particle            -- Coord_struct: particle in global time coordinates
!
!-

function particle_in_global_frame (orb, branch, in_time_coordinates, w_mat_out) result (particle)

implicit none

type (coord_struct) :: orb, particle
type (branch_struct) :: branch
type (floor_position_struct) :: floor_at_particle, global_position
type (ele_struct), pointer :: ele
real(rp) :: w_mat(3,3)
real(rp), optional :: w_mat_out(3,3)

logical, optional :: in_time_coordinates
logical :: in_t_coord

character(28), parameter :: r_name = 'particle_in_global_frame'

! optional argument 
in_t_coord =  logic_option( .false., in_time_coordinates)

!Get last tracked element  
ele =>  branch%ele(orb%ix_ele)

!Convert to time coordinates
particle = orb;
if (.not. in_t_coord) then
  call convert_particle_coordinates_s_to_t (particle)
  ! Set vec(5) to be relative to entrance of ele 
  particle%vec(5) =  particle%vec(5) - (ele%s - ele%value(L$))
endif

!Set for position_in_global_frame
floor_at_particle%r = particle%vec(1:5:2)
floor_at_particle%theta = 0.0_rp
floor_at_particle%phi = 0.0_rp
floor_at_particle%psi = 0.0_rp
! Get [X,Y,Z] and w_mat for momenta rotation below
global_position = position_in_global_frame (floor_at_particle, ele, w_mat)

!Set x, y, z
particle%vec(1:5:2) = global_position%r

!Rotate momenta 
particle%vec(2:6:2) = matmul(w_mat, particle%vec(2:6:2))

if (present(w_mat_out)) w_mat_out = w_mat

end function particle_in_global_frame

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine convert_particle_coordinates_t_to_s (particle, tref)
!
! Subroutine to convert particle coordinates from t-based to s-based system. 
!
! Modules needed:
!   use bmad
!
! Input:
!   particle   -- coord_struct: input particle coordinates
!   tref       -- real: reference time for z coordinate
!
! Output:
!   particle   -- coord_struct: output particle 
!-

subroutine convert_particle_coordinates_t_to_s (particle, tref)

!use bmad_struct

implicit none

type (coord_struct), intent(inout), target ::particle
real(rp) :: p0c
real(rp), intent(in) :: tref

real(rp) :: pctot

real(rp), pointer :: vec(:)
vec => particle%vec
p0c = particle%p0c

! Convert t to s
pctot = sqrt (vec(2)**2 + vec(4)**2 + vec(6)**2)
! vec(1) = vec(1)   !this is unchanged
vec(2) = vec(2)/p0c
! vec(3) = vec(3)   !this is unchanged
vec(4) = vec(4)/p0c
! z \equiv -c \beta(s)  (t(s) - t_0(s))
vec(5) = -c_light * (pctot/sqrt(pctot**2 + mass_of(particle%species)**2)) *  (particle%t - tref) 
vec(6) = pctot/p0c - 1.0_rp

end subroutine convert_particle_coordinates_t_to_s

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine convert_particle_coordinates_s_to_t (particle)
!
! Subroutine to convert particle coordinates from s-based to t-based system. 
!
! Note: t coordinates are:            
!     vec(1) = x                              [m]
!     vec(2) = c*p_x = m c^2 \gamma \beta_x   [eV]
!     vec(3) = y                              [m]
!     vec(4) = c*p_y = m c^2 \gamma beta_y    [eV]
!     vec(5) = s                              [m]
!     vec(6) = c*p_s = m c^2 \gamma \beta_s   [eV]
!
! Modules needed:
!   use bmad
!
! Input:
!   particle   -- coord_struct: input particle
!                       %vec(2), %vec(4), %vec(6)
!                       %s, %p0c
! Output:
!    particle   -- coord_struct: output particle 
!-

subroutine convert_particle_coordinates_s_to_t (particle)

implicit none

type (coord_struct), intent(inout), target :: particle
real(rp), pointer :: vec(:)

vec => particle%vec

! Convert s to t
vec(6) = particle%direction * particle%p0c * sqrt( ((1+vec(6)))**2 - vec(2)**2 -vec(4)**2 )
! vec(1) = vec(1) !this is unchanged
vec(2) = vec(2) * particle%p0c
! vec(3) = vec(3) !this is unchanged
vec(4) = vec(4) * particle%p0c
vec(5) = particle%s

end subroutine convert_particle_coordinates_s_to_t

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine drift_orbit_time(orbit, mc2, delta_s)
!
! Simple routine to drift a particle orbit in time-based coordinates by a distance delta_s
!   If the particle has zero longitudinal velocity, then the particle is not drifted
!   and a warning is printed.  
!
! Modules Needed:
!   use bmad_struct
!
! Input:
!   orbit      -- coord_struct: particle orbit in time-based coordinates
!   mc2        -- real(rp): particle mass in eV
!   delta_s    -- real(rp): s-coordinate distance to drift particle
!                  .
!
! Output:
!   orbit      -- coord_struct: particle orbit in time-based coordinates
!                                     
!-
subroutine drift_orbit_time(orbit, mc2, delta_s)
use bmad_struct
  
implicit none
  
type (coord_struct) :: orbit
real(rp) :: mc2, delta_s, delta_t, v_s, e_tot, vel(3)

character(28), parameter :: r_name = 'drift_orbit_time'
  
! Get e_tot from momentum

e_tot = sqrt( orbit%vec(2)**2 + orbit%vec(4)**2 +  orbit%vec(6)**2 + mc2**2) 

! velocities v_x, v_y, v_s:  c*[c*p_x, c*p_y, c*p_s]/e_tot

vel(1:3) = c_light*[  orbit%vec(2), orbit%vec(4), orbit%vec(6) ]/ e_tot 

if( vel(3) == 0 )then
   ! Do not drift
   call out_io (s_warn$, r_name, 'v_s == 0, will not drift')
   return
endif 
  
delta_t = delta_s / vel(3)

! Drift x, y, s
orbit%vec(1) = orbit%vec(1) + vel(1)*delta_t  !x
orbit%vec(3) = orbit%vec(3) + vel(2)*delta_t  !y
orbit%vec(5) = orbit%vec(5) + vel(3)*delta_t  !s
orbit%s =  orbit%s + delta_s
orbit%t =  orbit%t + delta_t 

end subroutine drift_orbit_time





!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+ 
! Subroutine write_time_particle_distribution  (time_file_unit, bunch, style, branch, err)
!
! Subroutine to write a time-based bunch from a standard Bmad bunch
! 
! Note: 'BMAD' style (absolute curvilinear coordinates): 
!       n_particles_alive 
!       x/m  m*c^2 \beta_x*\gamma/eV y/m m*c^2\beta_y*\gamma/eV s/m m*c^2\beta_z*\gamma/eV time/s charge/C
!      
!       'OPAL' style (absolute curvilinear coordinates): 
!       n_particles_alive
!       x/m  \beta_x*\gamma  y/m \beta_y*\gamma s/m \beta_s*\gamma
!
!       'ASTRA' style (global Cartesian coordinates, first line is the reference particle used for z, pz, and t calculation):
!       x/m y/m  z/m  m*c^2 \beta_x*\gamma/eV m*c^2 \beta_y*\gamma/eV m*c^2 \beta_z*\gamma/eV time/ns charge/nC species status
!       
!
! Input:
!   time_file_unit -- Integer: unit number to write to, if > 0
!   bunch          -- bunch_struct: bunch to be written.
!                            Particles are drifted to bmad_bunch%t_center for output
!   style          -- character(16), optional: Style of output file:
!                            'BMAD' (default), 'OPAL', 'ASTRA'
!   branch         -- branch_struct, optional: Required for 'ASTRA' style
!
! Output:          
!   err            -- Logical, optional: Set True if, say a file could not be opened.
!-



subroutine write_time_particle_distribution (time_file_unit, bunch, style, branch, err)

implicit none

integer			    :: time_file_unit
type (bunch_struct) :: bunch
type (branch_struct), optional :: branch



type (coord_struct) :: orb, orb_ref
real(rp)        :: dt, pc, gmc, gammabeta(3), charge_alive

character(10)   ::  rfmt 
integer :: n_alive
integer :: i, i_style, a_particle_index, a_status
integer, parameter :: bmad$ = 1, opal$ = 2, astra$ = 3
logical, optional   :: err

character(*), optional  :: style 
character(16) :: style_names(3) = ['BMAD        ', &
								   'OPAL        ', &
								   'ASTRA       ']
character(40)	:: r_name = 'write_time_particle_distribution'

!

if (present(style)) then
  call match_word (style, style_names, i_style)
  if (i_style == 0) then
    call out_io (s_error$, r_name, 'Invalid style: '//trim(style))
  endif
else
  i_style = bmad$
endif

if (present(err)) err = .true.

!Format for numbers
  rfmt = 'es13.5'

! Number of alive particles
n_alive = count(bunch%particle(:)%state == alive$)

! First line
select case (i_style)
  case (bmad$, opal$)
    ! Number of particles
    write(time_file_unit, '(i8)') n_alive !was: size(bunch%particle)
  case (astra$)
    ! Reference particle is the average of all particles
    if (.not. present(branch)) call out_io (s_error$, r_name, 'Branch must be specified for ASTRA style')
    charge_alive = sum(bunch%particle(:)%charge, mask = (bunch%particle%state == alive$))
    if (charge_alive == 0) then
      call out_io (s_warn$, r_name, 'Zero alive charge in bunch, nothing written to file')
      return
    endif
    do i = 1, 6
      orb_ref%vec(i) = sum( bunch%particle(:)%vec(i) *  bunch%particle(:)%charge, mask = (bunch%particle(:)%state == alive$)) / charge_alive
    enddo  
    ! For now just use the first particle as a reference. 
    orb = bunch%particle(1)
    orb_ref%t = branch%ele(bunch%ix_ele)%ref_time
    orb_ref%ix_ele = bunch%ix_ele
    orb_ref%p0c = orb%p0c
    orb_ref%species = orb%species
    a_particle_index = astra_particle_index(orb_ref%species)
    orb_ref = particle_in_global_frame (orb_ref,  branch)
    if (orb_ref%p0c == 0) then
      a_status = -1 ! Starting at cathode
    else 
      a_status = 5
    endif
    write(time_file_unit, '(8'//rfmt//', 2i8)') orb_ref%vec(1:5:2), orb_ref%vec(2:6:2), &
                     1e9_rp*orb_ref%t, 1e9_rp*orb_ref%charge, a_particle_index, a_status
end select

! All particles
do i = 1, size(bunch%particle) 
  orb = bunch%particle(i)
  
  ! Only write live particles
  if (orb%state /= alive$) cycle
  
  !Get time to track backwards by
  dt = orb%t - bunch%t_center
  
  !Get pc before conversion
  pc = (1+orb%vec(6)) * orb%p0c 
  
  !convert to time coordinates
  call convert_particle_coordinates_s_to_t (orb)
  
  !get \gamma m c
  gmc = sqrt(pc**2 + mass_of(orb%species)**2) / c_light
  
  !'track' particles backwards in time and write to file
  ! (x, y, s) - dt mc2 \beta_x \gamma / \gamma m c
  orb%vec(1) = orb%vec(1) - dt*orb%vec(2)/gmc
  orb%vec(3) = orb%vec(3) - dt*orb%vec(2)/gmc
  orb%vec(5) = orb%vec(5) - dt*orb%vec(2)/gmc
  orb%t = orb%t - dt
  
  ! 
  select case (i_style)
  case (bmad$) 
    write(time_file_unit, '(8'//rfmt//')')  orb%vec(1:6), bunch%t_center, bunch%particle(i)%charge 
  
  case (opal$)  
    gammabeta =  orb%vec(2:6:2) / mass_of(orb%species)
     ! OPAL has a problem with zero beta_s
    if ( gammabeta(3) == 0 ) gammabeta(3) = 1e-30 
    write(time_file_unit, '(6'//rfmt//')')  orb%vec(1), gammabeta(1), &
										    orb%vec(3), gammabeta(2), &
											orb%vec(5), gammabeta(3)
  case (astra$)
     orb = particle_in_global_frame (orb,  branch, in_time_coordinates = .true.)
     a_particle_index = astra_particle_index(orb_ref%species)
     ! The reference particle is used for z, pz, and t
     write(time_file_unit, '(8'//rfmt//', 2i8)') orb%vec(1), &
	    	 									 orb%vec(3), &
	    	 									 orb%vec(5) - orb_ref%vec(5), &
	    	 									 orb%vec(2), &
	    	 									 orb%vec(4), &
	    	 									 orb%vec(6) - orb_ref%vec(6), &
                                                 1e9_rp*(orb%t - orb_ref%t), &
                                                 1e9_rp*orb%charge, &
                                                 a_particle_index, &
                                                 a_status
  
  end select

end do 

if (present(err)) err = .false.

contains

function astra_particle_index(species) result (index)
implicit none
integer :: species, index
select case (species)
      case (electron$)
        index = 1
      case (positron$)
        index = 2
      case default
        call out_io (s_warn$, r_name, 'Only electrons or positrons allowed for Astra. Setting index to -1')
        index = -1
end select
end function

end subroutine  write_time_particle_distribution


end module
