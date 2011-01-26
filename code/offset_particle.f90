!+
! Subroutine offset_particle (ele, param, coord, set, set_canonical, 
!                               set_tilt, set_multipoles, set_hvkicks, s_pos)
! Subroutine to effectively offset an element by instead offsetting
! the particle position to correspond to the local element coordinates.
! 
! set = set$ assumes the particle is at the entrance end of the element.
! set = unset$ assumes the particle is at the exit end of the element.
! However: This can be overridden by using the s_pos argument.
!
! Options:
!   Using the element tilt in the offset.
!   Using the HV kicks.
!   Using the multipoles.
!   Conversion between canonical momenta: 
!       (p_x, p_y) = (P_x/P0, P_y/P0)
!   And "angle" coords:
!       (P_x/P, P_y/P) = (x', y') * (1 + g*x) 
!   where g = 1/R is the inverse bending radius of the reference orbit.
!
! Modules Needed:
!   use bmad
!
! Input:
!   ele       -- Ele_struct: Element
!     %value(x_offset$) -- Horizontal offset of element.
!     %value(x_pitch$)  -- Horizontal roll of element.
!     %value(tilt$)     -- tilt of element.
!   coord     -- Coord_struct: Coordinates of the particle.
!     %vec(6)            -- Energy deviation dE/E. 
!                          Used to modify %vec(2) and %vec(4)
!   param     -- lat_param_struct:
!     %particle   -- What kind of particle (for elseparator elements).
!   set       -- Logical: 
!                   T (= set$)   -> Translate from lab coords to the local 
!                                     element coords.
!                   F (= unset$) -> Translate back to lab coords.
!   set_canonical  -- Logical, optional: Default is True.
!                   T -> Convert between (p_x, p_y) and angle coords also.
!                   F -> No conversion between (p_x, p_y) and angle coords.
!   set_tilt       -- Logical, optional: Default is True.
!                   T -> Rotate using ele%value(tilt$) and 
!                            ele%value(roll$) for sbends.
!                   F -> Do not rotate
!   set_multipoles -- Logical, optional: Default is True.
!                   T -> 1/2 of the multipole is applied.
!   set_hvkicks    -- Logical, optional: Default is True.
!                   T -> Apply 1/2 any hkick or vkick.
!   s_pos          -- Real(rp), optional: Longitudinal position of the
!                   particle. If not present then s_pos = 0 is assumed when
!                   set = T and s_pos = ele%value(l$) when set = F
!                                               
! Output:
!     coord -- Coord_struct: Coordinates of particle.
!-

subroutine offset_particle (ele, param, coord, set, set_canonical, &
                              set_tilt, set_multipoles, set_hvkicks, s_pos)

use bmad_interface, except_dummy => offset_particle
use multipole_mod, only: multipole_ele_to_kt, multipole_kicks
use track1_mod, only: track_a_drift

implicit none

type (ele_struct) :: ele
type (lat_param_struct), intent(in) :: param
type (coord_struct), intent(inout) :: coord

real(rp), optional, intent(in) :: s_pos
real(rp) E_rel, knl(0:n_pole_maxx), tilt(0:n_pole_maxx)
real(rp), save :: old_angle = 0, old_roll = 0
real(rp), save :: del_x_vel = 0, del_y_vel = 0
real(rp) angle, s_here, xp, yp

integer n

logical, intent(in) :: set
logical, optional, intent(in) :: set_canonical, set_tilt, set_multipoles
logical, optional, intent(in) :: set_hvkicks
logical set_canon, set_multi, set_hv, set_t, set_hv1, set_hv2

!---------------------------------------------------------------         
! E_rel               

E_rel = (1 + coord%vec(6))

! Bmad routines assume input canonical coords. 
! The output of this routine must be what the calling subroutine thinks it
!  is setting at.
! Therefore: If bmad_com%canonical_coords = F, so that the input coords
!   are not canonical, the sense of set_canon must be inverted to get 
!   the right output

set_canon = logic_option(.true., set_canonical)
if (.not. bmad_com%canonical_coords) set_canon = .not. set_canon

set_multi = logic_option (.true., set_multipoles)
set_hv    = logic_option (.true., set_hvkicks) .and. ele%is_on .and. &
                   (has_kick_attributes(ele%key) .or. has_hkick_attributes(ele%key))
set_t     = logic_option (.true., set_tilt) .and. has_orientation_attributes(ele%key)

if (set_hv) then
  select case (ele%key)
  case (elseparator$, kicker$, hkicker$, vkicker$)
    set_hv1 = .false.
    set_hv2 = .true.
  case default
    set_hv1 = .true.
    set_hv2 = .false.
  end select
else
  set_hv1 = .false.
  set_hv2 = .false.
endif

if (set_t .and. ele%key == sbend$) then
  angle = ele%value(l$) * ele%value(g$)
  if (angle /= old_angle .or. ele%value(roll$) /= old_roll) then
    if (ele%value(roll$) == 0) then
      del_x_vel = 0
      del_y_vel = 0
    else if (abs(ele%value(roll$)) < 0.001) then
      del_x_vel = angle * ele%value(roll$)**2 / 4
      del_y_vel = -angle * sin(ele%value(roll$)) / 2
    else
      del_x_vel = angle * (1 - cos(ele%value(roll$))) / 2
      del_y_vel = -angle * sin(ele%value(roll$)) / 2
    endif
    old_angle = angle
    old_roll = ele%value(roll$)
  endif
endif

!----------------------------------------------------------------
! Set...

if (set) then

  ! Set s_offset

  if (ele%value(s_offset_tot$) /= 0) &
                    call track_a_drift (coord%vec, ele%value(s_offset_tot$), ele, param)

  ! Set: Offset and pitch

  if (has_orientation_attributes(ele%key)) then
    if (ele%value(x_offset_tot$) /= 0 .or. ele%value(y_offset_tot$) /= 0 .or. &
              ele%value(x_pitch_tot$) /= 0 .or. ele%value(y_pitch_tot$) /= 0) then
      if (present(s_pos)) then
        s_here = s_pos - ele%value(l$) / 2  ! position relative to center.
      else
        s_here = -ele%value(l$) / 2
      endif
      xp = ele%value(x_pitch_tot$)
      yp = ele%value(y_pitch_tot$)
      coord%vec(1) = coord%vec(1) - ele%value(x_offset_tot$) - xp * s_here
      coord%vec(2) = coord%vec(2) - xp * E_rel
      coord%vec(3) = coord%vec(3) - ele%value(y_offset_tot$) - yp * s_here
      coord%vec(4) = coord%vec(4) - yp * E_rel
      coord%vec(5) = coord%vec(5) + xp * coord%vec(1) + yp * coord%vec(3) - &
                                    (xp**2 + yp**2) * ele%value(l$) / 4
    endif
  endif

  ! Set: HV kicks for quads, etc. but not hkicker, vkicker, elsep and kicker elements.
  ! HV kicks must come after s_offset but before any tilts are applied.
  ! Note: Change in %vel is NOT dependent upon energy since we are using
  ! canonical momentum.
  ! Note: Since this is applied before tilt_coords, kicks are independent of any tilt.

  if (set_hv1) then
    coord%vec(2) = coord%vec(2) + ele%value(hkick$) / 2
    coord%vec(4) = coord%vec(4) + ele%value(vkick$) / 2
  endif

  ! Set: Multipoles

  if (set_multi .and. associated(ele%a_pole)) then
    call multipole_ele_to_kt(ele, param%particle, knl, tilt, .true.)
    knl = knl / 2
    call multipole_kicks (knl, tilt, coord)
  endif

  ! Set: Tilt
  ! A non-zero roll has a zeroth order effect that must be included  

  if (set_t) then

    if (ele%key == sbend$) then
      if (ele%value(roll$) /= 0) then
        coord%vec(2) = coord%vec(2) + del_x_vel
        coord%vec(4) = coord%vec(4) + del_y_vel
      endif
      call tilt_coords (ele%value(tilt_tot$)+ele%value(roll$), coord%vec)
    else
      call tilt_coords (ele%value(tilt_tot$), coord%vec)
    endif

  endif

  ! Set: HV kicks for kickers and separators only.
  ! Note: Since this is applied after tilt_coords, kicks are dependent on any tilt.

  if (set_hv2) then
    if (ele%key == elseparator$ .and. param%particle < 0) then
      coord%vec(2) = coord%vec(2) - ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) - ele%value(vkick$) / 2
    elseif (ele%key == hkicker$) then
      coord%vec(2) = coord%vec(2) + ele%value(kick$) / 2
    elseif (ele%key == vkicker$) then
      coord%vec(4) = coord%vec(4) + ele%value(kick$) / 2
    else
      coord%vec(2) = coord%vec(2) + ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + ele%value(vkick$) / 2
    endif
  endif

  ! Set: (p_x, p_y) -> (P_x/P, P_y/P)  

  if (set_canon .and. coord%vec(6) /= 0) then
    coord%vec(2) = coord%vec(2) / E_rel
    coord%vec(4) = coord%vec(4) / E_rel
  endif

!----------------------------------------------------------------
! Unset... 

else

  ! Unset: (P_x/P, P_y/P) -> (p_x, p_y) 

  if (set_canon .and. coord%vec(6) /= 0) then
    coord%vec(2) = coord%vec(2) * E_rel
    coord%vec(4) = coord%vec(4) * E_rel
  endif

  ! Unset: HV kicks for kickers and separators only.

  if (set_hv2) then
    if (ele%key == elseparator$ .and. param%particle < 0) then
      coord%vec(2) = coord%vec(2) - ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) - ele%value(vkick$) / 2
    elseif (ele%key == hkicker$) then
      coord%vec(2) = coord%vec(2) + ele%value(kick$) / 2
    elseif (ele%key == vkicker$) then
      coord%vec(4) = coord%vec(4) + ele%value(kick$) / 2
    else
      coord%vec(2) = coord%vec(2) + ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + ele%value(vkick$) / 2
    endif
  endif

  ! Unset: Tilt

  if (set_t) then

    if (ele%key == sbend$) then
      call tilt_coords (-(ele%value(tilt_tot$)+ele%value(roll$)), coord%vec) 
      if (ele%value(roll$) /= 0) then  
        coord%vec(2) = coord%vec(2) + del_x_vel
        coord%vec(4) = coord%vec(4) + del_y_vel
      endif
    else
      call tilt_coords (-ele%value(tilt_tot$), coord%vec)   
    endif

  endif

  ! Unset: Multipoles

  if (set_multi .and. associated(ele%a_pole)) then
    call multipole_kicks (knl, tilt, coord)
  endif

  ! UnSet: HV kicks for quads, etc. but not hkicker, vkicker, elsep and kicker elements.
  ! HV kicks must come after s_offset but before any tilts are applied.
  ! Note: Change in %vel is NOT dependent upon energy since we are using
  ! canonical momentum.

  if (set_hv1) then
    coord%vec(2) = coord%vec(2) + ele%value(hkick$) / 2
    coord%vec(4) = coord%vec(4) + ele%value(vkick$) / 2
  endif

  ! Unset: Offset and pitch

  if (has_orientation_attributes(ele%key)) then
    if (ele%value(x_offset_tot$) /= 0 .or. ele%value(y_offset_tot$) /= 0 .or. &
              ele%value(x_pitch_tot$) /= 0 .or. ele%value(y_pitch_tot$) /= 0) then
      if (present(s_pos)) then
        s_here = s_pos - ele%value(l$) / 2  ! position relative to center.
      else
        s_here = ele%value(l$) / 2
      endif
      xp = ele%value(x_pitch_tot$)
      yp = ele%value(y_pitch_tot$)
      coord%vec(5) = coord%vec(5) - xp * coord%vec(1) - yp * coord%vec(3) - &
                                    (xp**2 + yp**2) * ele%value(l$) / 4
      coord%vec(1) = coord%vec(1) + ele%value(x_offset_tot$) + xp * s_here
      coord%vec(2) = coord%vec(2) + xp * E_rel
      coord%vec(3) = coord%vec(3) + ele%value(y_offset_tot$) + yp * s_here
      coord%vec(4) = coord%vec(4) + yp * E_rel
    endif
  endif

  if (ele%value(s_offset_tot$) /= 0) &
                    call track_a_drift (coord%vec, -ele%value(s_offset_tot$), ele, param)

endif

end subroutine
                          

