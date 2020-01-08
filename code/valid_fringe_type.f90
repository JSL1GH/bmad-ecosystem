!+
! Function valid_fringe_type (ele, fringe_type) result (is_valid)
!
! Routine to return whether a given fringe_type method is valid for a given element.
!
! Input:
!   ele         -- ele_struct: Lattice element.
!   fringe_type  -- integer: bmad_standard$, etc.
!
! Output:
!   is_valid    -- logical: True if a valid method. False otherwise.
!-

function valid_fringe_type (ele, fringe_type) result (is_valid)

use bmad_struct

implicit none

type (ele_struct) ele
integer fringe_type
logical is_valid

! 

is_valid = .false.

select case (ele%key)

case (sbend$, rbend$)
  select case (fringe_type)
  case (none$, soft_edge_only$, hard_edge_only$, full$, sad_full$, linear_edge$, basic_bend$)
    is_valid = .true.
  end select

case default
  select case (fringe_type)
  case (none$, soft_edge_only$, hard_edge_only$, full$)
    is_valid = .true.
  end select
end select

end function valid_fringe_type 

