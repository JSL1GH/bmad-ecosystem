!+
! Subroutine update_hybrid_list (ring, n_in, use_ele)
!
! Subroutine to add elements to the use_ele list needed by the routine
! make_hybrid_ring.
!
! Use_ele is a list of elements that should not be hyberdized. This list
! is used by the subroutine make_hybrid_ring. If an element is to be
! used (not hyberdized) then the associated lord and slave elements need
! to be also added to the use_ele list. This routine does that bookkeeping.
! for a single element use_ele(n_in).
!
! Modules needed:
!   use bmad
!
! Input:
!   ring -- Ring_struct: Input ring structure.
!   n_in -- Integer: use_ele(n_in) is the element whose associated lord and
!             slave elements are to be added to use_ele.
!
! Output:
!   USE_ELE(:) -- Logical: list of ring elements to be not hyberdized.
!                   This is used with make_hybrid_ring.
!
! Note: If use_ele(n_in) = .false. then no updating is done
!-

#include "CESR_platform.inc"

recursive subroutine update_hybrid_list (ring, n_in, use_ele)

  use bmad_struct

  implicit none

  type (ring_struct)  ring

  logical use_ele(:)

  integer ix, n_in, i, j

! see if any work needs to be done

  if (.not. use_ele(n_in)) return

! now go through and put controlled elements in the list and make sure
! all appropriate controllers are on the list

  do i = ring%ele_(n_in)%ix1_slave, ring%ele_(n_in)%ix2_slave
    ix = ring%control_(i)%ix_slave
    if (.not. use_ele(ix)) then
      use_ele(ix) = .true.
      call update_hybrid_list (ring, ix, use_ele)
    endif
  enddo

  do i = ring%ele_(n_in)%ic1_lord, ring%ele_(n_in)%ic2_lord
    j= ring%ic_(i)
    ix = ring%control_(j)%ix_lord
    if (.not. use_ele(ix)) then
      use_ele(ix) = .true.
      call update_hybrid_list (ring, ix, use_ele)
    endif
  enddo

end subroutine
