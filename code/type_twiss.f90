!+
! Subroutine type_twiss (ele, frequency_units)
!
! Subroutine to type the Twiss information contained in an element.
! See also the subroutine: type_twiss.
!
! Modules needed:
!   use bmad
!
! Input:
!   ele          -- Ele_struct: Element containing the Twiss parameters.
!   frequency_units 
!                -- Integer: Units for phi:
!                       = radians$  => Type Twiss, use radians for phi.
!                       = degrees$  => Type Twiss, use degrees for phi.
!                       = cycles$   => Type Twiss, use cycles (1 = 2pi) units.
!-

#include "CESR_platform.inc"

subroutine type_twiss (ele, frequency_units)

  use bmad_struct
  use bmad_interface

  implicit none

  type (ele_struct)  ele

  integer frequency_units, n, n_lines

  character*80 lines(5)

!

  call type2_twiss (ele, frequency_units, lines, n_lines)

  do n = 1, n_lines
    print *, trim(lines(n))
  enddo

end subroutine
