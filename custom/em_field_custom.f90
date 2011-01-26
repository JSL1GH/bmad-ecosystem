!+
! Subroutine em_field_custom (ele, param, s, here, local_ref_frame, field, calc_dfield)
!
! Dummy routine. Will generate an error if called.
! A valid em_field_custom is needed only if the em_field routine is being used.
!
! Input:
!   ele         -- Ele_struct: Custom element.
!   param       -- lat_param_struct: Lattice parameters.
!   s           -- Real(rp): Longitudinal position of the reference particle.
!   here        -- Coord_struct: Coords with respect to the reference particle.
!   local_ref_frame 
!               -- Logical, If True then take the 
!                     input coordinates and output fields as being with 
!                     respect to the frame of referene of the element. 
!   calc_dfield -- Logical, optional: If present and True then the field 
!                     derivative matrix is wanted by the calling program.
!
! Output:
!   field -- Em_field_struct: Structure hoding the field values.
!-

subroutine em_field_custom (ele, param, s, orb, local_ref_frame, field, calc_dfield)

use bmad_struct

implicit none

type (ele_struct) :: ele
type (lat_param_struct) param
type (coord_struct), intent(in) :: orb
real(rp), intent(in) :: s
logical local_ref_frame
type (em_field_struct), intent(out) :: field
logical, optional :: calc_dfield

!

print *, 'ERROR IN EM_FIELD_CUSTOM: THIS DUMMY ROUTINE SHOULD NOT HAVE'
print *, '      BEEN CALLED IN THE FIRST PLACE.'
call err_exit

field%E = 0   ! so compiler will not complain

end subroutine
