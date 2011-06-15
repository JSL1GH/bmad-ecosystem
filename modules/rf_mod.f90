module rf_mod

use runge_kutta_mod

contains

!--------------------------------------------------------------------------------------------
!--------------------------------------------------------------------------------------------
!--------------------------------------------------------------------------------------------
!+
! Subroutine rf_accel_mode_adjust_phase_and_amp (ele, param)
!
! Routine to set the reference phase and amplitude of the accelerating rf field mode.
! 
! All calculations are done with a particle with the energy of the reference particle and 
! with z = 0.
!
! First: With the phase set for maximum acceleration, set the field_scale for the
! correct acceleration:
!     acceleration = ele%value(gradient$) * ele%value(l$) for lcavity elements.
!                  = ele%value(voltage$)                  for rfcavity elements.
!
! Second:
! If the element is an lcavity then the RF phase is set for maximum acceleration.
! If the element is an rcavity then the RF phase is set for zero acceleration and
! dE/dz will be negative (particles with z > 0 will be deaccelerated).
!
! Modules needed
!   use rf_mod
!
! Input:
!   ele   -- ele_struct: RF element. Either lcavity or rfcavity.
!     %rf%field(1) -- Accelerating mode.
!     %value(gradient$) -- Accelerating gradient to match to if an lcavity.
!     %value(voltage$)  -- Accelerating voltage to match to if an rfcavity.
!   param -- lat_param_struct: lattice parameters
!
! Output:
!   ele -- ele_struct: RF element.
!     %rf%field%mode(1)%theta_t0    -- RF phase
!     %rf%field%mode(1)%field_scale -- RF amplitude.
!-

subroutine rf_accel_mode_adjust_phase_and_amp (ele, param)

use super_recipes_mod
use nr, only: zbrent

implicit none

type (ele_struct), target :: ele
type (rf_field_mode_struct), pointer :: mode1
type (lat_param_struct) param

real(rp) pz, theta, pz_max, theta0, theta_max, e_tot, f_correct, design_dE
real(rp) dtheta, e_tot_start, pz_plus, pz_minus, b, c
real(rp) value_saved(n_attrib_maxx)

integer i, n_loop, tracking_method_saved

logical step_up_seen

! Init

mode1 => ele%rf%field%mode(1)

if (.not. ele%is_on) return
select case (ele%key)
case (rfcavity$)
  design_dE = ele%value(voltage$)
  e_tot_start = ele%value(e_tot$)
case (lcavity$)
  design_dE = ele%value(gradient$) * ele%value(l$)
  e_tot_start = ele%value(e_tot_start$)
case default
  call err_exit ! exit on error.
end select

n_loop = 0  ! For debug purposes.

if (design_dE == 0) then
  mode1%field_scale = 0
  return
endif

value_saved = ele%value
ele%value(phi0$) = 0
ele%value(dphi0$) = 0

tracking_method_saved = ele%tracking_method
ele%tracking_method = runge_kutta$

theta_max = mode1%theta_t0
if (ele%key == rfcavity$) theta_max = theta_max - 0.25
dtheta = 0.1

! See if %theta_t0 and %field_scale are already set correctly

pz_plus  = -neg_pz_calc(theta_max + 0.001)
pz_minus = -neg_pz_calc(theta_max - 0.001)
pz_max = -neg_pz_calc(theta_max)

call convert_pc_to ((1 + pz_max) * ele%value(p0c$), param%particle, e_tot = e_tot)
f_correct = design_dE / (e_tot - e_tot_start)

if (pz_max > pz_plus .and. pz_max > pz_minus .and. abs(f_correct - 1) < 1e-5) return

! Now adjust %field_scale for the correct acceleration at the phase for maximum accelleration. 

do

  ! Find approximately the phase for maximum acceleration.
  ! First go in +theta direction until pz decreases.

  step_up_seen = .false.
  do
    theta = theta_max + dtheta
    pz = -neg_pz_calc(theta)
    if (pz < pz_max) exit
    pz_max = pz
    theta_max = theta
    step_up_seen = .true.
  enddo

  pz_plus = pz

  ! If needed: Now go in -theta direction until pz decreases

  if (.not. step_up_seen) then
    do
      theta = theta_max - dtheta
      pz = -neg_pz_calc(theta)
      if (pz < pz_max) exit
      pz_max = pz
      theta_max = theta
    enddo
  endif

  pz_minus = pz

  ! Quadradic interpolation to get the maximum phase.
  ! Formula: pz = a + b*dt + c*dt^2 where dt = (theta-theta_max) / dtheta

  b = (pz_plus - pz_minus) / 2
  c = pz_plus - pz_max - b

  theta_max = theta_max - b * dtheta / (2 * c)
  pz_max = -neg_pz_calc(theta_max)

  ! Now scale %field_scale
  ! f_correct = dE(design) / dE (from tracking)

  call convert_pc_to ((1 + pz_max) * ele%value(p0c$), param%particle, e_tot = e_tot)
  f_correct = design_dE / (e_tot - e_tot_start)
  mode1%field_scale = mode1%field_scale * f_correct

  if (abs(f_correct - 1) < 0.01) exit

  dtheta = 0.1
  if (abs(f_correct - 1) < 0.1) dtheta = 0.05

  pz_max = -neg_pz_calc(theta_max)

enddo

! Now do a fine adjustment

!print '(i4, f12.0, 3f12.6)', n_loop, mode1%field_scale, mode1%theta_t0, &
!                              -neg_pz_calc(mode1%theta_t0), pz_max

pz_max = -super_brent (theta_max-dtheta, theta_max, theta_max+dtheta, neg_pz_calc, &
                       0.0_rp, 0.0001_rp, theta_max)
mode1%theta_t0 = modulo2 (theta_max, 0.5_rp)

call convert_pc_to ((1 + pz_max) * ele%value(p0c$), param%particle, e_tot = e_tot)
f_correct = design_dE / (e_tot - e_tot_start)
mode1%field_scale = mode1%field_scale * f_correct

! For an rfcavity now find the zero crossing with negative slope which is
! about 90deg away from max acceleration.

if (ele%key == rfcavity$) then
  dtheta = 0.1
  do
    theta = theta_max + dtheta
    pz = -neg_pz_calc(theta)
    if (pz < 0) exit
    theta_max = theta
  enddo
  mode1%theta_t0 = modulo2 (zbrent(neg_pz_calc, theta_max, theta_max+dtheta, 1d-9), 0.5_rp)
endif

! Cleanup

ele%value = value_saved
ele%tracking_method = tracking_method_saved

!print '(i4, f12.0, 3f12.6)', n_loop, mode1%field_scale, mode1%theta_t0, &
!                              -neg_pz_calc(mode1%theta_t0), pz_max

!----------------------------------------------------------------
contains

function neg_pz_calc (theta) result (neg_pz)

type (coord_struct) start, end_orb
real(rp) theta, neg_pz

! brent finds minima so need to flip the final energy

mode1%theta_t0 = theta
call track1 (start, ele, param, end_orb)
neg_pz = -end_orb%vec(6)
if (param%lost) neg_pz = 1

n_loop = n_loop + 1

end function

end subroutine rf_accel_mode_adjust_phase_and_amp

end module
