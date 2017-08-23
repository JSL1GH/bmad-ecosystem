!+
! Subroutine combine_consecutive_elements (lat)
!
! Routine to combine consecutive elements in the lattice that have the same name.
! This allows simplification, for example, of lattices where elements have been 
! split to compute the beta function at the center.
!
! Modules needed:
!   use bmad
!
! Input:
!   lat -- Lat_struct: Lattice.
!
! Output:
!   lat -- Lat_struct: Lattice with elements combined.
!-

subroutine combine_consecutive_elements (lat)

use bookkeeper_mod, except => combine_consecutive_elements

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele1, ele2

integer i, jv

character(*), parameter :: r_name = 'combine_consecutive_elements'

! loop over all elements...

ele_loop: do i = 1, lat%n_ele_track

  ele1 => lat%ele(i)
  ele2 => lat%ele(i+1)

  if (ele1%name /= ele2%name) cycle ! ignore if not a matching pair

  if (lat%ele(i-1)%name == ele1%name .and. ele2%key /= marker$) then
    call out_io (s_error$, r_name, 'TRIPLE CONSECUTIVE ELEMENTS HAVE SAME NAME! ' // ele1%name)
    if (global_com%exit_on_error) call err_exit
  endif

  if (ele1%key == sbend$) then
    if (ele1%value(e2$) /= 0 .or. ele2%value(e1$) /= 0) then
      call out_io (s_error$, r_name, 'CONSECUTIVE BENDS HAVE INTERNAL FACE ANGLES: ' // ele1%name)
      cycle
    endif
    ele1%value(e2$) = ele2%value(e2$)
    ele2%value(e1$) = ele2%value(e1$)
  endif

  do jv = 1, size(ele1%value)
    if (attribute_name(ele1, jv) == 'REF_TIME_START' .or. attribute_name(ele1, jv) == null_name$) cycle
    if (abs(ele1%value(jv) - ele2%value(jv)) > 1d-14 * (abs(ele1%value(jv)) + abs(ele2%value(jv)))) then
      call out_io (s_error$, r_name, 'ELEMENT PARAMETERS DO NOT MATCH FOR: ' // ele1%name)
      cycle ele_loop
    endif
  enddo

  if (ele1%value(x_pitch_tot$) /= 0 .or. ele1%value(y_pitch_tot$) /= 0) then
    call out_io (s_error$, r_name, 'ELEMENT HAS NON-ZERO PITCH: ' // ele1%name)
    cycle
  endif

  ele2%key = -1   ! mark for deletion

  ele1%value(l$) = 2 * ele1%value(l$)
  ele1%value(hkick$) = 2 * ele1%value(hkick$)
  ele1%value(vkick$) = 2 * ele1%value(vkick$)
  ele1%value(BL_hkick$) = 2 * ele1%value(BL_hkick$)
  ele1%value(BL_vkick$) = 2 * ele1%value(BL_vkick$)

enddo ele_loop

call remove_eles_from_lat (lat)     ! Remove all null_ele elements

end subroutine
