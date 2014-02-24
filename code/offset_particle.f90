!+
! Subroutine offset_particle (ele, param, set, coord, 
!                               set_tilt, set_multipoles, set_hvkicks, set_z_offset, ds_pos)
!
! Routine to transform a particles's coordinates between laboratory and element coordinates
! at the entrance or exit ends of the element. Additionally, this routine will:
!   a) Apply the half kicks due to multipole and kick attributes.
!   b) Add drift transform to the coordinates due to nonzero %value(z_offset_tot$).
!
! set = set$:
!    Transforms from lab to element coords. 
!    Assumes the particle is at the upstream (-S) end of the element if coord%direction = +1. 
!    Assumes the particle is at the downstream (+S) end of the elment if coord%direction = -1.
!
! set = unset$:
!    Transforms from element to lab coords.
!    Assumes the particle is at the downstream (+S) end of the element if coord%direction = +1.
!    Assumes the particle is at the upstream (-S) end of the elment if coord%direction = -1.
!
! Note: the assumption of where the particle is can be overridden by using the ds_pos argument.
!
! Options:
!   Using the element tilt in the offset.
!   Using the HV kicks.
!   Using the multipoles.
!
! Modules Needed:
!   use bmad
!
! Input:
!   ele            -- Ele_struct: Element
!     %value(x_offset$) -- Horizontal offset of element.
!     %value(x_pitch$)  -- Horizontal pitch of element.
!     %value(tilt$)     -- tilt of element.
!   param          -- lat_param_strcut: 
!     %particle             -- Reference particle
!     %rel_track_ing_charge -- Charge tracked particle / referece charge
!   set            -- Logical: 
!                    T (= set$)   -> Translate from lab coords to the local 
!                                      element coords.
!                    F (= unset$) -> Translate back from element to lab coords.
!   coord          -- Coord_struct: Coordinates of the particle.
!   set_tilt       -- Logical, optional: Default is True.
!                    T -> Rotate using ele%value(tilt$) and 
!                             ele%value(roll$) for sbends.
!                    F -> Do not rotate
!   set_multipoles -- Logical, optional: Default is True.
!                    T -> 1/2 of the multipole is applied.
!   set_hvkicks    -- Logical, optional: Default is True.
!                    T -> Apply 1/2 any hkick or vkick.
!   set_z_offset   -- Logical, optional: Default is True.
!                    T -> Particle will be translated by ele%value(z_offset$) to propagate between the nominal
!                           edge of the element and the true physical edge of the element.
!                    F -> Do no translate. Used by save_a_step routine.
!   ds_pos         -- Real(rp), optional: Longitudinal particle position relative to entrance end. 
!                    If not present then ds_pos = 0 is assumed when set = T and 
!                    ds_pos = ele%value(l$) when set = F.
!                                               
! Output:
!     coord -- Coord_struct: Coordinates of particle.
!-

subroutine offset_particle (ele, param, set, coord, &
                              set_tilt, set_multipoles, set_hvkicks, set_z_offset, ds_pos)

use bmad_interface, except_dummy => offset_particle
use multipole_mod, only: multipole_ele_to_kt, multipole_kicks
use track1_mod, only: track_a_drift
use rotation_3d_mod

implicit none

type (ele_struct) :: ele
type (lat_param_struct) param
type (coord_struct), intent(inout) :: coord

real(rp), optional, intent(in) :: ds_pos
real(rp) E_rel, knl(0:n_pole_maxx), tilt(0:n_pole_maxx), dx
real(rp) angle, z_here, xp, yp, x_off, y_off, z_off, off(3), m_trans(3,3)
real(rp) cos_a, sin_a, cos_t, sin_t, beta, charge_dir, dz, pvec(3), cos_r, sin_r
real(rp) rot(3), dr(3)

integer particle, sign_z_vel
integer n

logical, intent(in) :: set
logical, optional, intent(in) :: set_tilt, set_multipoles
logical, optional, intent(in) :: set_hvkicks, set_z_offset
logical set_multi, set_hv, set_t, set_hv1, set_hv2, set_s
logical has_nonzero_pole

!---------------------------------------------------------------         

E_rel = (1 + coord%vec(6))

set_multi = logic_option (.true., set_multipoles)
set_hv    = logic_option (.true., set_hvkicks) .and. ele%is_on .and. &
                   (has_kick_attributes(ele%key) .or. has_hkick_attributes(ele%key))
set_t     = logic_option (.true., set_tilt) .and. has_orientation_attributes(ele)
set_s     = logic_option (.true., set_z_offset) .and. has_orientation_attributes(ele)
sign_z_vel = ele%orientation * coord%direction

charge_dir = param%rel_tracking_charge * sign_z_vel 

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

!----------------------------------------------------------------
! Set...

if (set) then

  ! Set: Offset and pitch

  if (has_orientation_attributes(ele)) then

    if (present(ds_pos)) then
      z_here = ele%orientation * (ds_pos - ele%value(l$)/2)   ! position relative to center.
    else
      z_here = -ele%orientation * ele%value(l$) / 2
    endif

    x_off = ele%value(x_offset_tot$)
    y_off = ele%value(y_offset_tot$)
    z_off = ele%value(z_offset_tot$)
    xp    = ele%value(x_pitch_tot$)
    yp    = ele%value(y_pitch_tot$)

    if (x_off /= 0 .or. y_off /= 0 .or. z_off /= 0 .or. xp /= 0 .or. yp /= 0) then

      ! If a bend then must rotate the offsets from the coordinates at the center of the bend
      ! to the entrance coordinates. This rotation is just the coordinate transformation for the
      ! whole bend except with half the bending angle.

      if (ele%key == sbend$ .and. ele%value(g$) /= 0) then
        angle = ele%value(g$) * z_here  ! Notice that this is generally negative
        cos_a = cos(angle); sin_a = sin(angle)
        dr = [2 * sin(angle/2)**2 / ele%value(g$), 0.0_rp, sin_a / ele%value(g$)]

        if (ele%value(ref_tilt_tot$) == 0) then
          off = [cos_a * x_off + sin_a * z_off, y_off, -sin_a * x_off + cos_a * z_off]
          rot = [-cos_a * yp, xp, sin_a * yp]
        else
          cos_t = cos(ele%value(ref_tilt_tot$));    sin_t = sin(ele%value(ref_tilt_tot$))
          m_trans(1,:) = [cos_a * cos_t**2 + sin_t**2, (cos_a - 1) * cos_t * sin_t, cos_t * sin_a]
          m_trans(2,:) = [(cos_a - 1) * cos_t * sin_t, cos_a * sin_t**2 + cos_t**2, sin_a * sin_t]
          m_trans(3,:) = [-cos_t * sin_a, -sin_a * sin_t, cos_a]
          off = matmul(m_trans, [x_off, y_off, z_off])
          rot = matmul(m_trans, [-yp, xp, 0.0_rp])
          dr = [cos_t * dr(1) - sin_t * dr(2), sin_t * dr(1) + cos_t * dr(2), dr(3)]
        endif

        if (any(rot /= 0)) then
          call axis_angle_to_w_mat (rot, norm2(rot), m_trans)
          off = off + matmul(m_trans, dr) - dr
        endif

        coord%vec(5) = coord%vec(5) + sign_z_vel * (rot(2) * coord%vec(1) - rot(1) * coord%vec(3))
        coord%vec(1) = coord%vec(1) - off(1)
        coord%vec(2) = coord%vec(2) - sign_z_vel * rot(2) * E_rel
        coord%vec(3) = coord%vec(3) - off(2)
        coord%vec(4) = coord%vec(4) + sign_z_vel * rot(1) * E_rel

        if (off(3) /= 0 .and. set_s) then
          call track_a_drift (coord, ele, sign_z_vel*off(3))
          coord%vec(5) = coord%vec(5) - sign_z_vel*off(3)  ! Correction due to reference particle is also offset.
        endif

      ! Else not a bend

      else

        if (z_off /= 0 .and. set_s) then
          call track_a_drift (coord, ele, sign_z_vel*z_off)
          coord%vec(5) = coord%vec(5) - sign_z_vel*z_off  ! Correction due to reference particle is also offset.
        endif

        coord%vec(1) = coord%vec(1) - x_off - xp * z_here
        coord%vec(2) = coord%vec(2) - sign_z_vel * xp * E_rel
        coord%vec(3) = coord%vec(3) - y_off - yp * z_here
        coord%vec(4) = coord%vec(4) - sign_z_vel * yp * E_rel
        dz = sign_z_vel * (xp * coord%vec(1) + yp * coord%vec(3) + (xp**2 + yp**2) * z_here / 2)
        coord%vec(5) = coord%vec(5) + dz
        coord%t = coord%t - dz / (coord%beta * c_light) 
      endif

    endif   ! has oeientation attributes

  endif

  ! Set: HV kicks for quads, etc. but not hkicker, vkicker, elsep and kicker elements.
  ! HV kicks must come after z_offset but before any tilts are applied.
  ! Note: Change in %vel is NOT dependent upon energy since we are using
  ! canonical momentum.
  ! Note: Since this is applied before tilt_coords, kicks are independent of any tilt.

  if (set_hv1) then
    if (ele%key == elseparator$) then
      coord%vec(2) = coord%vec(2) + param%rel_tracking_charge * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + param%rel_tracking_charge * ele%value(vkick$) / 2
      if (param%particle < 0) then
        coord%vec(2) = -coord%vec(2)
        coord%vec(4) = -coord%vec(4)
      endif
    else
      coord%vec(2) = coord%vec(2) + charge_dir * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + charge_dir * ele%value(vkick$) / 2
    endif
  endif

  ! Set: Multipoles

  if (set_multi) then
    call multipole_ele_to_kt(ele, param, .true., has_nonzero_pole, knl, tilt)
    if (has_nonzero_pole) then
      knl = knl / 2
      call multipole_kicks (knl, tilt, coord)
    endif
  endif

  ! Set: Tilt & Roll

  if (set_t) then

    if (ele%key == sbend$) then
      call tilt_coords (ele%value(ref_tilt_tot$), coord%vec)
    else
      call tilt_coords (ele%value(tilt_tot$), coord%vec)
    endif

    if (ele%key == sbend$ .and. ele%value(roll_tot$) /= 0) then
      angle = -ele%value(g$) * z_here
      off = [coord%vec(1), coord%vec(3), 0.0_rp]

      sin_r = sin(ele%value(roll$)); cos_r = cos(ele%value(roll$))
      sin_a = sin(angle);            cos_a = cos(angle)

      m_trans(1,:) = [cos_r * cos_a**2 + sin_a**2, cos_a * sin_r, (cos_r - 1) * cos_a * sin_a]
      m_trans(2,:) = [-cos_a * sin_r,              cos_r,         -sin_r * sin_a]
      m_trans(3,:) = [(cos_r - 1) * cos_a * sin_a, sin_r * sin_a, cos_r * sin_a**2 + cos_a**2]
      off = matmul(m_trans, off)
      pvec = matmul(m_trans, [coord%vec(2), coord%vec(4), sqrt(E_rel**2 - coord%vec(2)**2 - coord%vec(4)**2)])

      ! If ds_pos is present then the transformation is not at the end of the bend.
      ! In this case there is an offset from the coordinate system and the roll axis of rotation

      if (present(ds_pos)) then
        dx = cos_a - cos(ele%value(angle$)/2)
        off = off + dx * [cos_a * sin_r, cos_r - 1, sin_a * sin_r]
      endif

      ! Drift - off(3) but remember the ref particle is not moving.
      coord%vec(1) = off(1) - off(3) * pvec(1) / pvec(3)
      coord%vec(2) = pvec(1)
      coord%vec(3) = off(2) - off(3) * pvec(2) / pvec(3)
      coord%vec(4) = pvec(2)
      coord%vec(5) = coord%vec(5) + off(3) * E_rel / pvec(3) 
      coord%t = coord%t - off(3) * E_rel / (pvec(3) * c_light * coord%beta)

    endif

  endif

  ! Set: HV kicks for kickers and separators only.
  ! Note: Since this is applied after tilt_coords, kicks are dependent on any tilt.

  if (set_hv2) then
    if (ele%key == elseparator$ ) then
      coord%vec(2) = coord%vec(2) + charge_of(param%particle) * param%rel_tracking_charge * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + charge_of(param%particle) * param%rel_tracking_charge * ele%value(vkick$) / 2
    elseif (ele%key == hkicker$) then
      coord%vec(2) = coord%vec(2) + charge_dir * ele%value(kick$) / 2
    elseif (ele%key == vkicker$) then
      coord%vec(4) = coord%vec(4) + charge_dir * ele%value(kick$) / 2
    else
      coord%vec(2) = coord%vec(2) + charge_dir * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + charge_dir * ele%value(vkick$) / 2
    endif
  endif

!----------------------------------------------------------------
! Unset... 

else

  ! Unset: HV kicks for kickers and separators only.

  if (set_hv2) then
    if (ele%key == elseparator$) then
      coord%vec(2) = coord%vec(2) + charge_of(param%particle) * param%rel_tracking_charge * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + charge_of(param%particle) * param%rel_tracking_charge * ele%value(vkick$) / 2
    elseif (ele%key == hkicker$) then
      coord%vec(2) = coord%vec(2) + charge_dir * ele%value(kick$) / 2
    elseif (ele%key == vkicker$) then
      coord%vec(4) = coord%vec(4) + charge_dir * ele%value(kick$) / 2
    else
      coord%vec(2) = coord%vec(2) + charge_dir * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + charge_dir * ele%value(vkick$) / 2
    endif
  endif

  ! Unset: Tilt & Roll

  if (set_t) then

    if (ele%key == sbend$ .and. ele%value(roll_tot$) /= 0) then
      sin_r = sin(ele%value(roll$));    cos_r = cos(ele%value(roll$))
      sin_a = sin(ele%value(angle$)/2); cos_a = cos(ele%value(angle$)/2)
      m_trans(1,:) = [cos_r * cos_a**2 + sin_a**2, -cos_a * sin_r, (1 - cos_r) * cos_a * sin_a]
      m_trans(2,:) = [cos_a * sin_r,               cos_r,          -sin_r * sin_a]
      m_trans(3,:) = [(1 - cos_r) * cos_a * sin_a, sin_r * sin_a,  cos_r * sin_a**2 + cos_a**2]
      off =  matmul(m_trans, [coord%vec(1), coord%vec(3), 0.0_rp])
      pvec = matmul(m_trans, [coord%vec(2), coord%vec(4), sqrt(E_rel**2 - coord%vec(2)**2 - coord%vec(4)**2)])
      coord%vec(1) = off(1); coord%vec(3) = off(2)
      coord%vec(2) = pvec(1); coord%vec(4) = pvec(2)

      ! If ds_pos is present then the transformation is not at the end of the bend.
      ! In this case there is an offset from the coordinate system and the roll axis of rotation

      if (present(ds_pos)) then
        dx = cos_a - cos(ele%value(angle$)/2)
        off = off + dx * [-cos_a * sin_r, cos_r - 1, sin_a * sin_r]
      endif

      ! Drift - off(3) but remember the ref particle is not moving.
      coord%vec(1) = off(1) - off(3) * pvec(1) / pvec(3)
      coord%vec(2) = pvec(1)
      coord%vec(3) = off(2) - off(3) * pvec(2) / pvec(3)
      coord%vec(4) = pvec(2)
      coord%vec(5) = coord%vec(5) + off(3) * E_rel / pvec(3) 
      coord%t = coord%t - off(3) * E_rel / (pvec(3) * c_light * coord%beta)

    endif

    if (ele%key == sbend$) then
      call tilt_coords (-ele%value(ref_tilt_tot$), coord%vec)
    else
      call tilt_coords (-ele%value(tilt_tot$), coord%vec)
    endif

  endif

  ! Unset: Multipoles

  if (set_multi) then
    call multipole_ele_to_kt(ele, param, .true., has_nonzero_pole, knl, tilt)
    if (has_nonzero_pole) then
      knl = knl / 2
      call multipole_kicks (knl, tilt, coord)
    endif
  endif

  ! UnSet: HV kicks for quads, etc. but not hkicker, vkicker, elsep and kicker elements.
  ! HV kicks must come after z_offset but before any tilts are applied.
  ! Note: Change in %vel is NOT dependent upon energy since we are using
  ! canonical momentum.

  if (set_hv1) then
    if (ele%key == elseparator$) then
      coord%vec(2) = coord%vec(2) + param%rel_tracking_charge * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + param%rel_tracking_charge * ele%value(vkick$) / 2
    else
      coord%vec(2) = coord%vec(2) + charge_dir * ele%value(hkick$) / 2
      coord%vec(4) = coord%vec(4) + charge_dir * ele%value(vkick$) / 2
    endif
  endif

  ! Unset: Offset and pitch

  if (has_orientation_attributes(ele)) then

    ! If a bend then must rotate the offsets from the coordinates at the center of the bend
    ! to the exit coordinates. This rotation is just the coordinate transformation for the
    ! whole bend except with half the bending angle.

    if (present(ds_pos)) then
      z_here = ele%orientation * (ds_pos - ele%value(l$)/2)  ! position relative to center.
    else
      z_here = ele%orientation * ele%value(l$) / 2
    endif

    x_off = ele%value(x_offset_tot$)
    y_off = ele%value(y_offset_tot$)
    z_off = ele%value(z_offset_tot$)
    xp    = ele%value(x_pitch_tot$)
    yp    = ele%value(y_pitch_tot$)

    if (x_off /= 0 .or. y_off /= 0 .or. z_off /= 0 .or. xp /= 0 .or. yp /= 0) then

      if (ele%key == sbend$ .and. ele%value(g$) /= 0) then
        angle = ele%value(g$) * z_here 
        cos_a = cos(angle); sin_a = sin(angle)
        dr = [2 * sin(angle/2)**2 / ele%value(g$), 0.0_rp, sin_a / ele%value(g$)]

        if (ele%value(ref_tilt_tot$) == 0) then
          off = [cos_a * x_off + sin_a * z_off, y_off, -sin_a * x_off + cos_a * z_off]
          rot = [-cos_a * yp, xp, sin_a * yp]
        else
          cos_t = cos(ele%value(ref_tilt_tot$));    sin_t = sin(ele%value(ref_tilt_tot$))
          m_trans(1,:) = [cos_a * cos_t**2 + sin_t**2, (cos_a - 1) * cos_t * sin_t, cos_t * sin_a]
          m_trans(2,:) = [(cos_a - 1) * cos_t * sin_t, cos_a * sin_t**2 + cos_t**2, sin_a * sin_t]
          m_trans(3,:) = [-cos_t * sin_a, -sin_a * sin_t, cos_a]
          off = matmul(m_trans, [x_off, y_off, z_off])
          rot = matmul(m_trans, [-yp, xp, 0.0_rp])
          dr = [cos_t * dr(1) - sin_t * dr(2), sin_t * dr(1) + cos_t * dr(2), dr(3)]
        endif

        if (any(rot /= 0)) then
          call axis_angle_to_w_mat (rot, norm2(rot), m_trans)
          off = off + matmul(m_trans, dr) - dr
        endif

        coord%vec(5) = coord%vec(5) - sign_z_vel * (rot(2) * coord%vec(1) - rot(1) * coord%vec(3))
        coord%vec(1) = coord%vec(1) + off(1)
        coord%vec(2) = coord%vec(2) + sign_z_vel * rot(2) * E_rel
        coord%vec(3) = coord%vec(3) + off(2)
        coord%vec(4) = coord%vec(4) - sign_z_vel * rot(1) * E_rel
        z_off = off(3)

      ! Else not a bend

      else
        dz = -sign_z_vel * (xp * coord%vec(1) + yp * coord%vec(3) + (xp**2 + yp**2) * z_here / 2)
        coord%t = coord%t - dz / (coord%beta * c_light) 
        coord%vec(5) = coord%vec(5) + dz
        coord%vec(1) = coord%vec(1) + x_off + xp * z_here
        coord%vec(2) = coord%vec(2) + sign_z_vel * xp * E_rel
        coord%vec(3) = coord%vec(3) + y_off + yp * z_here
        coord%vec(4) = coord%vec(4) + sign_z_vel * yp * E_rel
      endif

      if (z_off /= 0 .and. set_s) then
        call track_a_drift (coord, ele, -sign_z_vel*z_off)
        coord%vec(5) = coord%vec(5) + sign_z_vel*z_off  ! Correction due to reference particle is also offset.
      endif
    endif

  endif   ! Has orientation attributes

endif

end subroutine
                          

