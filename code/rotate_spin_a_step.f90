!+
! Subroutine rotate_spin_a_step (orbit, field, ele, ds)
!
! Routine to rotate the spin through an integration step.
! Note: It is assumed that the orbit coords are in the element ref frame and not the lab frame.
!
! Input:
!   orbit   -- coord_struct: Initial orbit.
!   field   -- em_field_struct: EM Field 
!   ele     -- ele_struct, Element being tracked through. 
!   ds      -- real(rp): Longitudinal step
!
! Output:
!   orbit   -- coord_struct: Orbit with rotated spin
!-

subroutine rotate_spin_a_step (orbit, field, ele, ds)

use equal_mod, dummy_except => rotate_spin_a_step

implicit none

type (ele_struct) ele
type (coord_struct) orbit
type (em_field_struct) field

real(rp) ds, omega(3)
integer sign_z_vel

!

sign_z_vel = ele%orientation * orbit%direction

if (ele%key == sbend$) then
  omega = (1 + ele%value(g$) * orbit%vec(1)) * spin_omega (field, orbit, sign_z_vel) + &
                      [0.0_rp, ele%value(g$)*sign_z_vel, 0.0_rp]
else
  omega = spin_omega (field, orbit, orbit%direction * ele%orientation)
endif

call rotate_spin (abs(ds) * omega, orbit%spin)

end subroutine rotate_spin_a_step


