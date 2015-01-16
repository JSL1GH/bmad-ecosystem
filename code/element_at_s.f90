module element_at_s_mod

use bmad_utils_mod

!+
! Function element_at_s (lat, s, choose_max, ix_branch, err_flag, s_eff, position) result (ix_ele)
!
! Function to return the index of the element at position s.
!
! element_at_s is an overloaded name for:
!   function element_at_s_lat (lat, s, choose_max, ix_branch, err_flag, s_eff, position) result (ix_ele)
!   function element_at_s_branch (branch, s, choose_max, err_flag, s_eff, position) result (ix_ele)
!
! The differnce between these two routine is that with element_at_s_lat, the branch is given by the lat 
!   and ix_ele arguments: branch = lat%branch(ix_ele). With element_at_s_branch, the branch is an argument.
!
! Also see: pointer_to_element_at_s
!
! ix_ele is choisen such that:
! If choose_max = True: 
!     If s = branch%ele(ix_end_of_branch): ix_ele = ix_end_of_branch
!     Else: branch%ele(ix_ele-1)%s <= s < branch%ele(ix_ele)%s
! If choose_max = False:
!     If s = branch%ele(0): ix_ele = 0
!     Else: branch%ele(ix_ele-1)%s < s <= branch%ele(ix_ele)%s 
! That is, if s corresponds to an element boundary between elements with indexes ix1 and ix2 = ix1 + 1: 
!     choose_max = True  => ix_ele = ix2
!     choose_max = False => ix_ele = ix1
!
! The setting of choose_max only makes a difference when s corresponds to an element boundary. 
!
! Note: For a circular lattice, s is evaluated at the effective s which
! is modulo the branch length:
!     s_eff = s - branch_length * floor(s/branch_length)
!
! Modules needed:
!   use bmad
!
! Input:
!   lat        -- lat_struct: Lattice of elements.
!   branch     -- branch_struct: Branch to use
!   s          -- real(rp): Longitudinal position.
!   choose_max -- logical: See above
!   ix_branch  -- integer, optional: Branch index. Default is 0.
!
! Output:
!   ix_ele    -- integer: Index of element at s.
!   err_flag  -- logical, optional: Set True if s is out of bounds. False otherwise.
!   s_eff     -- real(rp), optional: Effective s. Equal to s with a open lattice. See above.
!   position  -- coord_struct: Positional information.
!     %s         -- Same as input s.
!     %ix_ele    -- Same as output ix_ele
!     %location  -- Location relative to element. Upstream_end$, downstream_end$, or inside$
!-

interface element_at_s
  module procedure element_at_s_lat
  module procedure element_at_s_branch
end interface

private element_at_s_lat, element_at_s_branch

contains

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function element_at_s_branch (branch, s, choose_max, err_flag, s_eff, position) result (ix_ele)
!
! Overloaded routine. See element_at_s for more details.
!-

function element_at_s_branch (branch, s, choose_max, err_flag, s_eff, position) result (ix_ele)

implicit none

type (branch_struct) :: branch
type (coord_struct), optional :: position

real(rp) s, ss
real(rp), optional :: s_eff

integer ix_ele, n1, n2, n3

character(16), parameter :: r_name = 'element_at_s'
logical, optional :: err_flag
logical choose_max, err

! Get translated position and check for position out-of-bounds.

ix_ele = 0
call check_if_s_in_bounds (branch, s, err, ss)
if (present(err_flag)) err_flag = err
if (err) return

! Start of branch case

if (.not. choose_max .and. s == branch%ele(0)%s) then
  if (present(s_eff)) s_eff = s
  if (present(position)) then
    position%ix_ele = ix_ele
    position%s = s
    position%location = downstream_end$
  endif
  return
endif

! Bracket solution

n1 = 0
n3 = branch%n_ele_track

do

  if (n3 == n1 + 1) exit

  n2 = (n1 + n3) / 2

  if (choose_max) then
    if (ss < branch%ele(n2)%s) then
      n3 = n2
    else
      n1 = n2
    endif
  else
    if (ss <= branch%ele(n2)%s) then
      n3 = n2
    else
      n1 = n2
    endif
  endif

enddo

! Solution is n3 except in one case.

ix_ele = n3
if (.not. choose_max .and. ss == branch%ele(n3-1)%s) ix_ele = n3-1

if (present(s_eff)) s_eff = ss

if (present(position)) then
  position%ix_ele = ix_ele
  position%s = s

  if (branch%ele(ix_ele)%value(l$) == 0) then
    if (choose_max) then
      position%location = downstream_end$
    else
      position%location = upstream_end$
    endif
  elseif (ss == branch%ele(ix_ele)%s) then
    position%location = downstream_end$
  elseif (ss == branch%ele(ix_ele-1)%s) then
    position%location = upstream_end$
  else
    position%location = inside$
  endif
endif

end function element_at_s_branch

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function element_at_s_lat (lat, s, choose_max, ix_branch, err_flag, s_eff, position) result (ix_ele)
!
! Overloaded routine. See element_at_s for more details.
!-

function element_at_s_lat (lat, s, choose_max, ix_branch, err_flag, s_eff, position) result (ix_ele)

implicit none

type (lat_struct), target :: lat
type (branch_struct), pointer :: branch
type (coord_struct), optional :: position

real(rp) s
real(rp), optional :: s_eff

integer ix_ele, ib
integer, optional :: ix_branch

logical, optional :: err_flag
logical choose_max

! 

ib = integer_option(0, ix_branch)
ix_ele = element_at_s_branch (lat%branch(ib), s, choose_max, err_flag, s_eff, position)

end function element_at_s_lat

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function pointer_to_element_at_s (branch, s, choose_max, err_flag, s_eff, position) result (ele)
!
! Function to return a pointer to the element at position s.
! That is, return ele => branch%ele(ix_ele) such that:
! If choose_max = True: 
!     If s = branch%ele(ix_end_of_branch): ix_ele = ix_end_of_branch
!     Else: branch%ele(ix_ele-1)%s <= s < branch%ele(ix_ele)%s
! If choose_max = False:
!     If s = branch%ele(0): ix_ele = 0
!     Else: branch%ele(ix_ele-1)%s < s <= branch%ele(ix_ele)%s 
! That is, if s corresponds to an element boundary between elements with indexes ix1 and ix2 = ix1 + 1: 
!     choose_max = True  => ix_ele = ix2
!     choose_max = False => ix_ele = ix1
!
! Also see: element_at_s
!
! The setting of choose_max only makes a difference when s corresponds to an element boundary. 
!
! Note: For a circular lattice, s is evaluated at the effective s which
! is modulo the branch length:
!     s_eff = s - branch_length * floor(s/branch_length)
!
! Modules needed:
!   use bmad
!
! Input:
!   branch     -- branch_struct: Branch to use
!   s          -- real(rp): Longitudinal position.
!   choose_max -- logical: See above.
!
! Output:
!   ele       -- ele_struct, pointer: Pointer to element at s.
!   err_flag  -- logical, optional: Set True if s is out of bounds. False otherwise.
!   s_eff     -- real(rp), optional: Effective s. Equal to s with a open lattice. See above.
!   position  -- coord_struct: Positional information.
!     %s         -- Same as input s.
!     %ix_ele    -- Same as output ix_ele
!     %location  -- Location relative to element. Upstream_end$, downstream_end$, or inside$
!-

function pointer_to_element_at_s (branch, s, choose_max, err_flag, s_eff, position) result (ele)

implicit none

type (branch_struct), target :: branch
type (coord_struct), optional :: position
type (ele_struct), pointer :: ele

real(rp) s
real(rp), optional :: s_eff

integer ix_ele

logical, optional :: err_flag
logical choose_max, err

!

ix_ele = element_at_s_branch (branch, s, choose_max, err, s_eff, position)
if (present(err_flag)) err_flag = err

if (err) then
  nullify(ele)
else
  ele => branch%ele(ix_ele)
endif

end function pointer_to_element_at_s

end module
