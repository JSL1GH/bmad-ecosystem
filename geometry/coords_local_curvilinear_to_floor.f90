!+
! Function coords_local_curvilinear_to_floor (local_position, ele, in_body_frame, 
!                                      w_mat, calculate_angles, relative_to_upstream) result (global_position)
!
! Given a position local to ele, return global floor coordinates.
!
! Input:
!   local_position        -- floor_position_struct: Floor position in local curvilinear coordinates,
!                              with %r = [x, y, z_local] where z_local is wrt the entrance end of the element
!                              except if relative_to_upstream = T
!   ele                   -- ele_struct: element that local_position coordinates are relative to.
!   in_body_frame         -- logical, optional: True => local_position is in ele body frame and includes misalignments.
!                              Ignored if element is a patch. Default: False. 
!   calculate_angles      -- logical, optional: calculate angles for global_position 
!                              Default: True.
!                              False returns local_position angles (%theta, %phi, %psi) = 0.
!   relative_to_upstream  -- logical, optional: Default is False. If True, local_position%r(3) is relative to the 
!                              upstream end which will not be the entrance end if ele%orientation = -1.
!                              For patch elements (which always have ele%orientation = 1), if relative_to_upstream = T, 
!                              local_position%r(1:2) transverse coords will be taken wrt the upstream coords 
!
! Output:
!   w_mat(3,3)            -- real(rp), optional: W matrix at z, to transform vectors. 
!                                      v_global     = w_mat . v_local/body
!                                      v_local/body = transpose(w_mat) . v_global
!   global_position       -- floor_position_struct: Position in global coordinates.
!-  

function coords_local_curvilinear_to_floor (local_position, ele, in_body_frame, &
                                        w_mat, calculate_angles, relative_to_upstream) result (global_position)

use bmad_interface, dummy => coords_local_curvilinear_to_floor

implicit none

type (floor_position_struct) :: local_position, global_position, p, floor0, fl
type (ele_struct), target :: ele
type (ele_struct), pointer :: ele1
real(rp) :: ds, w_mat_local(3,3), L_vec(3), S_mat(3,3), z, sm2(3,3)
real(rp), optional :: w_mat(3,3)
logical, optional :: in_body_frame
logical, optional :: calculate_angles
logical, optional :: relative_to_upstream
character(*), parameter :: r_name = 'coords_local_curvilinear_to_floor'

! If a overlay, group or multipass then just use the first slave

if (ele%key == overlay$ .or. ele%key == group$ .or. ele%lord_status == multipass_lord$) then
  ele1 => pointer_to_slave(ele, 1)
else
  ele1 => ele
endif

! Deal with ele misalignments if needed

p = floor_position_struct(local_position%r, w_unit$, 0.0_rp, 0.0_rp, 0.0_rp)
if (logic_option(.false., relative_to_upstream) .and. ele1%orientation == -1 .and. ele1%key /= patch$) p%r(3) = ele%value(l$) - p%r(3) 

if (ele1%key == patch$) then
  if (.not. logic_option(.false., relative_to_upstream)) p%r(3) = p%r(3) - ele1%value(L$)  ! Shift position to be relative to ele's exit: 
  call mat_make_unit(S_mat)

elseif (logic_option(.false., in_body_frame)) then  ! General geometry with possible misalignments
  p = coords_body_to_local(p, ele1, w_mat = S_mat)
  if (ele1%key == sbend$) then
    ds = ele1%value(L$)-p%r(3)
    p%r(3) = 0
    p = bend_shift (p, ele%value(g$), ds, sm2, ele1%value(ref_tilt_tot$))
  else
    p%r(3) = p%r(3) - ele1%value(L$)  ! Shift position to be relative to ele's exit: 
  endif
 
elseif (ele1%key == sbend$) then  ! Curved geometry, no misalignments. Get relative to ele's exit end.
  z = p%r(3)
  p%r(3) = 0
  p = bend_shift(p, ele1%value(g$), ele1%value(L$) - z, w_mat = S_mat, ref_tilt = ele1%value(ref_tilt_tot$))

else   ! Element has Cartesian geometry, and misalignments are to be ignored. 
  p%r(3) = p%r(3) - ele1%value(L$)  ! Shift position to be relative to ele's exit: 
  call mat_make_unit(S_mat)
endif 

! Get global floor coordinates

if (ele1%key == patch$) then
  if (logic_option(.false., relative_to_upstream)) then
    floor0 = ele%branch%ele(ele%ix_ele-1)%floor        ! Get floor0 from previous element
  else
    floor0 = ele%floor
  endif

else
  floor0 = ele1%floor
  ! If orient = -1 then floor0 (which by definition is always the downstream coords) is entrance end coords.
  ! But calc here is wrt exit end coords. So have to shift floor0 to exit end coords.
  if (ele%orientation == -1) then
    call ele_geometry(floor0, ele, floor0, -1.0_rp)
  endif
endif

global_position%r = matmul(floor0%w, p%r) + floor0%r
global_position%w = matmul(matmul(floor0%w, p%w), local_position%w)

! If angles are not needed, just return zeros; 

if (logic_option(.true., calculate_angles)) then
  ! Note: Only floor0%theta angle is needed for calc.
  fl = ele1%floor
  if (ele1%key == sbend$) call ele_geometry(fl, ele1, fl, -0.5_rp)
  call update_floor_angles(global_position, fl)
else
  global_position%theta = 0
  global_position%phi = 0
  global_position%psi = 0
endif 

! Optionally return w_mat used in these transformations

if (present(w_mat) ) then
  w_mat = matmul(floor0%w, p%w)
endif 

end function coords_local_curvilinear_to_floor
