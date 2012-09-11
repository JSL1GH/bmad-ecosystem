!+
! Function element_at_s (lat, s, choose_max, ix_branch, err_flag, s_eff, position) result (ix_ele)
!
! Function to return the index of the element at position s.
! That is, ix_ele is choisen such that:
! If choose_max = True: 
!     If s = branch%ele(ix_end_of_branch): ix_ele = ix_end_of_branch
!     Else: branch%ele(ix_ele-1)%s <= s < branch%ele(ix_ele)%s
! If choose_max = False:
!     If s = branch%ele(0): ix_ele = 0
!     Else: branch%ele(ix_ele-1)%s < s <= branch%ele(ix_ele)%s 
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
!   s          -- Real(rp): Longitudinal position.
!   choose_max -- Logical: If s corresponds to an element boundary between elements with 
!                   indexes ix1 and ix2 = ix1 + 1, choose_max = True ix_ele = ix2 and
!                   choose_max = False returns ix_ele = ix1
!   ix_branch  -- Integer, optional: Branch index. Default is 0.
!
! Output:
!   ix_ele    -- Integer: Index of element at s.
!   err_flag  -- logical, optional: Set True if s is out of bounds. False otherwise.
!   s_eff     -- Real(rp), optional: Effective s. Equal to s with a linear lattice.
!   position  -- coord_struct: Positional information.
!     %s         -- Same as input s.
!     %ix_ele    -- Same as output ix_ele
!     %location  -- Location relative to element.
!-

function element_at_s (lat, s, choose_max, ix_branch, err_flag, s_eff, position) result (ix_ele)

use bmad, except_dummy => element_at_s

implicit none

type (lat_struct), target :: lat
type (branch_struct), pointer :: branch
type (coord_struct), optional :: position

real(rp) s, ss
real(rp), optional :: s_eff

integer ix_ele, n1, n2, n3
integer, optional :: ix_branch

character(16), parameter :: r_name = 'element_at_s'
logical, optional :: err_flag
logical choose_max, err

! Get translated position and check for position out-of-bounds.

branch => lat%branch(integer_option(0, ix_branch))
call check_if_s_in_bounds (branch, s, err, ss)
if (present(err_flag)) err_flag = err
if (err) return

! Start of branch case

if (.not. choose_max .and. s == branch%ele(0)%s) then
  ix_ele = 0
  if (present(s_eff)) s_eff = s
  if (present(position)) then
    position%ix_ele = ix_ele
    position%s = s
    position%location = exit_end$
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
if (.not. choose_max .and. ss == branch%ele(n2)%s) ix_ele = n2

if (present(s_eff)) s_eff = ss

if (present(position)) then
  position%ix_ele = ix_ele
  position%s = s

  if (branch%ele(ix_ele)%value(l$) == 0) then
    if (choose_max) then
      position%location = exit_end$
    else
      position%location = entrance_end$
    endif
  elseif (ss == branch%ele(ix_ele)%s) then
    position%location = exit_end$
  elseif (ss == branch%ele(ix_ele-1)%s) then
    position%location = entrance_end$
  else
    position%location = inside$
  endif
endif

end function
