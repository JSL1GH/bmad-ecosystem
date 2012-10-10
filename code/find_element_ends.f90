!+
! Subroutine find_element_ends (lat, ele, ele1, ele2)
!
! Subroutine to find the end points of an element in the tracking part of the 
! lattice.
!
! Modules Needed:
!   use bmad
!
! Input:
!   lat  -- lat_struct: Lat holding the lattice
!   ele  -- Ele_struct: Element to find the ends for.
!
! Output:
!   ele1 -- Ele_struct, pointer:  Pointer to element just before ele. 
!   ele2 -- Ele_struct, pointer:  Pointer to ele itself or the last sub-element within ele.
!
! Note: ele1 and ele2 will be nullified if ele is in the lord 
!       part of the lattice and does not have any slaves.
!
! Note: For an element in the tracking part of the lattice:
!       ele1%ix_ele = ele%ix_ele - 1
!       ele2        => ele
!-

subroutine find_element_ends (lat, ele, ele1, ele2)

use nr, only: indexx
use lat_ele_loc_mod, except_dummy => find_element_ends

implicit none
                                                       
type (lat_struct), target :: lat
type (ele_struct), target :: ele
type (ele_struct), pointer :: ele1, ele2

integer ix_start, ix_end, ix_start_branch, ix_end_branch
integer ix1, ix2, n, n_end, n_slave, ix_slave, ix_branch
integer, allocatable :: ix_slave_array(:), ix_branch_array(:)

!

if (ele%n_slave == 0) then

  if (ele%ix_ele > lat%branch(ele%ix_branch)%n_ele_track) then
    nullify (ele1, ele2)
  elseif (ele%ix_ele == 0) then
    ele1 => ele
    ele2 => ele
  else
    ele1 => pointer_to_ele (lat, ele%ix_ele-1, ele%ix_branch)
    ele2 => ele
  endif

elseif (ele%lord_status == super_lord$) then
  ele1 => pointer_to_slave(ele, 1)
  ele1 => pointer_to_ele (lat, ele1%ix_ele-1, ele1%ix_branch)
  ele2 => pointer_to_slave(ele, ele%n_slave)

! For overlays and groups: The idea is to look at all the slave elements in the tracking 
! part of the lattice and find the minimum and maximum element indexes.
! An element with a greater %ix_branch is always considered to be greater independent of %ix_ele.
! The small complication is that overlays or groups lords can control other overlays or 
! groups, etc.
! So we must "recursively" follow the slave tree.
! ix_slave_array/ix_branch_array holds the list of slaves we need to look at.

else  ! overlay_lord$, group_lord$, multipass_lord$

  ix_start = 1000000
  ix_start_branch = ubound(lat%branch, 1) + 1

  ix_end = 0
  ix_end_branch = -1

  ix1 = ele%ix1_slave
  ix2 = ele%ix2_slave

  n = 0       ! Index in ix_slave_array
  n_slave = ele%n_slave
  call re_allocate(ix_slave_array, n_slave)
  call re_allocate(ix_branch_array, n_slave)
  ix_slave_array(1:n_slave) = lat%control(ix1:ix2)%ix_slave
  ix_branch_array(1:n_slave) = lat%control(ix1:ix2)%ix_branch
  n_end = n_slave

  do 
    n = n + 1
    if (n > n_end) exit
    ix_slave = ix_slave_array(n)
    ix_branch = ix_branch_array(n)
    ! If the slave itself has slaves then add the sub-slaves to the list
    if (ix_slave > lat%n_ele_track .and. ix_branch == 0) then
      n_slave = lat%ele(ix_slave)%n_slave
      ix1 = lat%ele(ix_slave)%ix1_slave
      ix2 = lat%ele(ix_slave)%ix2_slave
      call re_allocate(ix_slave_array, n_slave+n_end)
      call re_allocate(ix_branch_array, n_slave+n_end)
      ix_slave_array(n_end+1:n_end+n_slave) = lat%control(ix1:ix2)%ix_slave
      ix_branch_array(n_end+1:n_end+n_slave) = lat%control(ix1:ix2)%ix_branch
      n_end = n_end + n_slave
    ! Else this slave is in the tracking part of the lattice...
    else
      if (ix_branch < ix_start_branch .or. &
            (ix_branch == ix_start_branch .and. ix_slave - 1 < ix_start)) then
        ix_start = ix_slave - 1
        ix_start_branch = ix_branch
      endif
      if (ix_branch > ix_end_branch .or. &
            (ix_branch == ix_end_branch .and. ix_slave > ix_end)) then
        ix_end = ix_slave 
        ix_end_branch = ix_branch
      endif
    endif
  enddo

  ele1 => pointer_to_ele (lat, ix_start, ix_start_branch)
  ele2 => pointer_to_ele (lat, ix_end, ix_end_branch)

endif

end subroutine
