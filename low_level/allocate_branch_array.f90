!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
!+
! Subroutine allocate_branch_array (lat, upper_bound)
!
! Subroutine to allocate or re-allocate an branch array.
! The old information is saved.
! The lower bound is always 0.
!
! Input:
!   lat         -- Lat_struct: 
!     %branch(:)  -- Branch array to be allocated.
!   upper_bound -- Integer: Desired upper bound.
! 
! Output:
!   lat         -- Lat_struct: 
!     %branch(:)  -- Allocated branch array.
!-

subroutine allocate_branch_array (lat, upper_bound)

use equal_mod, dummy => allocate_branch_array

implicit none

type (lat_struct), target :: lat
type (branch_struct), pointer :: branch
type (branch_struct), pointer :: temp_branch(:)

integer :: upper_bound
integer curr_ub, ub, i, j

character(20) :: r_name = 'allocate_branch_array'

!  save branch if present

ub = upper_bound
if (allocated (lat%branch)) then
  if (ub == ubound(lat%branch, 1)) return
  curr_ub = min(ub, ubound(lat%branch, 1))
  allocate (temp_branch(0:curr_ub))
  call transfer_branches (lat%branch(0:curr_ub), temp_branch)
  do i = curr_ub+1, ubound(lat%branch, 1)
    call deallocate_ele_array_pointers(lat%branch(i)%ele)
    deallocate(lat%branch(i)%n_ele_track)
    deallocate(lat%branch(i)%n_ele_max)
  enddo
  deallocate (lat%branch)
  allocate(lat%branch(0:ub))
  call transfer_branches (temp_branch(0:curr_ub), lat%branch(0:curr_ub))
  deallocate (temp_branch)
else
  curr_ub = -1
  allocate(lat%branch(0:ub))
  lat%branch(0)%ele            => lat%ele
  lat%branch(0)%param          => lat%param
  lat%branch(0)%a              => lat%a
  lat%branch(0)%b              => lat%b
  lat%branch(0)%z              => lat%z
  lat%branch(0)%n_ele_track    => lat%n_ele_track
  lat%branch(0)%n_ele_max      => lat%n_ele_max
  if (associated(lat%ele)) then
    do i = 0, ubound(lat%ele, 1)
      lat%ele(i)%branch => lat%branch(0)
    enddo
  endif
endif

! 

do i = curr_ub+1, ub
  branch => lat%branch(i)
  branch%lat => lat
  branch%name = ''
  branch%ix_branch = i
  branch%ix_from_branch = -1
  branch%ix_from_ele = -1
  if (i == 0) cycle
  allocate(branch%n_ele_track)
  allocate(branch%n_ele_max)
  allocate(branch%param)
  allocate(branch%a, branch%b, branch%z)
  !!!! branch%param = lat%param
  call set_status_flags (branch%param%bookkeeping_state, stale$)
end do

do i = 0, ub
  branch => lat%branch(i)
  if (.not. associated (branch%ele)) cycle
  do j = 0, ubound(branch%ele, 1)
    branch%ele(j)%branch => branch
  enddo
enddo

end subroutine allocate_branch_array

