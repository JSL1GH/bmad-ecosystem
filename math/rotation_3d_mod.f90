module rotation_3d_mod

use sim_utils

contains

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine w_mat_to_axis_angle (w_mat, axis, angle)
!
! Routine to find the rotation axis and rotation angle corresponding  to a given
! 3D rotation matrix.
!
! The rotation axis is choisen to have a non-negative dot production with the
! vector (1, 1, 1).
!
! The rotation angle is chosen in the range [-pi, pi].
!
! Module needed:
!   use rotation_3d_mod
!
! Input:
!   w_mat(3,3) -- real(rp): Rotation matrix
!
! Output:
!   axis(3)    -- real(rp): Rotation axis. Normalized to 1.
!   angle      -- real(rp): Rotation angle in the range [-pi, pi].
!-

subroutine w_mat_to_axis_angle (w_mat, axis, angle)

implicit none

real(rp) w_mat(3,3), axis(3), angle
real(rp) sin_ang, cos_ang

!

axis(1) = w_mat(3,2) - w_mat(2,3)
axis(2) = w_mat(1,3) - w_mat(3,1)
axis(3) = w_mat(2,1) - w_mat(1,2)

sin_ang = norm2(axis) / 2
if (sin_ang == 0) then
  axis = [1, 0, 0]
  angle = 0
  return
endif

axis = axis / (2 * sin_ang)

!

cos_ang = (w_mat(1,1) + w_mat(2,2) + w_mat(3,3) - 1) / 2
angle = atan2(sin_ang, cos_ang)

! Align to axis to point in the general direction of (1,1,1)

if (sum(axis) < 0) then
  axis = -axis 
  angle = -angle
endif

end subroutine w_mat_to_axis_angle

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine axis_angle_to_w_mat (axis, angle, w_mat)
!
! Routine to construct the 3D rotation matrix w_mat given an axis of rotation
! and a rotation angle.
!
! Module needed:
!   use rotation_3d_mod
!
! Input:
!   axis(3)    -- real(rp): Rotation axis. Does not have to be normalized.
!   angle      -- real(rp): Rotation angle in the range [-pi, pi].
!
! Output:
!   w_mat(3,3) -- real(rp): Rotation matrix
!-

subroutine axis_angle_to_w_mat (axis, angle, w_mat)

implicit none

real(rp) w_mat(3,3), axis(3), angle
real(rp) sin_a, cos_a, norm, x, y, z
character(*), parameter :: r_name = 'axis_angle_to_w_mat'
!

if (angle == 0) then
  call mat_make_unit (w_mat)
  return
endif

!

norm = norm2(axis)
if (norm == 0) then
  w_mat = 0
  call out_io (s_fatal$, r_name, 'ZERO AXIS LENGTH WITH NON-ZERO ROTATION!')
  if (global_com%exit_on_error) call err_exit
  return
endif

x = axis(1) / norm; y = axis(2) / norm; z = axis(3) / norm
cos_a = cos(angle); sin_a = sin(angle)

w_mat(1,1:3) = [x*x + (1 - x*x) * cos_a,       x*y * (1 - cos_a) - z * sin_a, x*z * (1 - cos_a) + y * sin_a]
w_mat(2,1:3) = [x*y * (1 - cos_a) + z * sin_a, y*y + (1 - y*y) * cos_a,       y*z * (1 - cos_a) - x * sin_a]
w_mat(3,1:3) = [x*z * (1 - cos_a) - y * sin_a, y*z * (1 - cos_a) + x * sin_a, z*z + (1 - z*z) * cos_a]

end subroutine axis_angle_to_w_mat

end module
