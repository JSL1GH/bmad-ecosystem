!+
! Subroutine type_ele (ele, type_zero_attrib, type_mat6, type_taylor, 
!                                             twiss_out, type_control, ring)
!
! Subroutine to type out information on an element. 
! See also the subroutine type2_ele.
!
! Modules needed:
!   use bmad
!
! Input:
!   ele              -- Ele_struct: Element
!   type_zero_attrib -- Logical: If true then type all attributes even if the
!                          attribute value is 0.
!   type_mat6      -- Integer:
!                          TYPE_MAT6 = 0   => Do not type ELE%MAT6
!                          TYPE_MAT6 = 4   => Type 4X4 XY submatrix
!                          TYPE_MAT6 = 6   => Type full 6x6 matrix
!   type_taylor    -- Logical: Type out taylor series?
!                       if ele%taylor is not allocated then this is ignored.
!   twiss_out      -- Integer: Type the Twiss parameters at
!                       the end of the element?
!                       = 0  => Do not type the Twiss parameters
!                       = radians$  => Type Twiss, use radians for phi.
!                       = degrees$  => Type Twiss, use degrees for phi.
!                       = cycles$   => Type Twiss, use cycles (1 = 2pi) units.
!   type_control   -- Logical: If true then type control status.
!   ring           -- Ring_struct, Optional: Needed for control typeout.
!
!-

#include "CESR_platform.inc"

subroutine type_ele (ele, type_zero_attrib, type_mat6, type_taylor,  &
                                         twiss_out, type_control, ring)

  use bmad_struct
  use bmad_interface, only: type2_ele

  implicit none

  type (ele_struct)  ele
  type (ring_struct), optional :: ring

  integer type_mat6, n_lines, i, twiss_out
  
  logical type_control, type_zero_attrib, type_taylor

  character*80, pointer :: lines(:) 

!

  nullify (lines)

  call type2_ele (ele, type_zero_attrib, type_mat6, type_taylor, twiss_out, &
                                          type_control, lines, n_lines, ring)

  do i = 1, n_lines
    print '(1x, a)', trim(lines(i))
  enddo

  deallocate (lines)

end subroutine
