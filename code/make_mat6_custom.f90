!+
! Subroutine make_mat6_custom (ele, param, c0, c1)
!
! Default routine for making the 6x6 transfer matrices for:
!   1) ele%mat6_calc_method = custom$
!   2) ele%key = custom$
!
! This routine will do Runge Kutta tracking using field_rk_custom.
! You must supply field_rk_custom.
!
! Modules needed:
!   use bmad
!
! Input:
!   ele    -- Ele_struct: Element with transfer matrix
!   param  -- Param_struct: Parameters are needed for some elements.
!   c0     -- Coord_struct: Coordinates at the beginning of element. 
!
! Output:
!   ele    -- Ele_struct: Element with transfer matrix.
!     %mat6  -- 6x6 transfer matrix.
!   c1     -- Coord_struct: Coordinates at the end of element.
!+

#include "CESR_platform.inc"

subroutine make_mat6_custom (ele, param, c0, c1)

  use bmad_struct
  use bmad_interface

  implicit none

  type (ele_struct), target :: ele
  type (coord_struct) :: c0, c1
  type (param_struct)  param

  real(rp) error

  integer temp_method
  logical temp_symplectify

!

  temp_method = ele%tracking_method
  temp_symplectify = ele%symplectify

  ele%tracking_method = custom$
  ele%symplectify = .false.   ! don't do this twice.

  call transfer_mat_from_tracking (ele, param, c0, bmad_com%d_orb, c1, error)

  ele%tracking_method = temp_method
  ele%symplectify = temp_symplectify

end subroutine
