module capillary_mod

use bmad_struct
use bmad_interface

type photon_coord_struct
  type (coord_struct) orb       ! Phase space: orb%vec = (x, vx/c, y, vy/c, s, vs/c)
  real(rp) energy
  real(rp) track_len
  integer ix_section            ! Cross section index
end type

type photon_track_struct
  type (photon_coord_struct) old, now
end type

! This is for passing info to the photon_hit_func routine used by zbrent

type (photon_track_struct), pointer, private, save :: photon_com
type (photon_track_struct), private, save :: photon1_com
type (ele_struct), private, pointer, save :: ele_com

private photon_hit_func

contains

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine track_a_capillary (orb, ele, lost)
!
! Routine to track through a capillary.
!
! Input:
!   orb -- Coord_struct: Input coordinates.
!   ele -- ele_struct: Capillary element
!
! Output:
!   orb  -- Coord_struct: Output coordinates.
!   lost -- Logical: Set true if particle is lost. False otherwise.
!-

subroutine track_a_capillary (orb, ele, lost)

implicit none

type (ele_struct) ele
type (coord_struct) orb
type (photon_track_struct) photon

real(rp) pz

integer at_end

logical lost

! Calculate maximum step size

! Setup photon coords

photon%now%orb = orb
photon%now%orb%vec(5) = 0
photon%now%orb%vec(6) = sqrt(1 - orb%vec(2)**2 - orb%vec(4)**2)
photon%now%energy = ele%value(e_tot$) * (1 + orb%vec(6))
photon%now%track_len = 0
photon%now%ix_section = 1

! Loop over all bounces

lost = .true.
at_end = 0

do
  call capillary_track_photon_to_wall (photon, ele, at_end)
  if (at_end == entrance_end$) return  ! Reflected backwards
  if (at_end == exit_end$) exit      ! And done
  call capillary_reflect_photon (photon, ele, lost)
  if (lost) return
enddo

! Correct z by distance traveled by reference particle.

pz = orb%vec(6)
orb = photon%now%orb
orb%vec(5) =  ele%value(l$) - photon%now%track_len
orb%vec(6) = pz

lost = .false.

end subroutine track_a_capillary

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine capillary_track_photon_to_wall (photon, ele, at_end)
!
! Routine to track through a capillary.
!
! Input:
!   photon -- photon_track_struct: Input coordinates.
!   ele    -- ele_struct: Capillary element
!
! Output:
!   photon -- Photon_struct: Output coordinates.
!   at_end -- Integer: Set to entrance_end$, or exit_end$ if at an end.
!-

subroutine capillary_track_photon_to_wall (photon, ele, at_end)

implicit none

type (ele_struct), target :: ele
type (photon_track_struct), target :: photon
type (wall3d_section_struct), pointer :: section

real(rp) dr_max, ds_max, p_max, dlen
real(rp), pointer :: vec(:)

integer at_end

character(40) :: r_name = 'capillary_track_photon_to_wall'

! 

do

  section => ele%wall3d%section(photon%now%ix_section)
  vec => photon%now%orb%vec

  ! Calculate a resonable step size

  if (size(section%v) == 1) then
    dr_max = 2 * max(section%v(1)%radius_x, section%v(1)%radius_y)
  else
    dr_max = 2 * max(maxval(abs(section%v%x)), maxval(abs(section%v%y)))
  endif

  ds_max = 2 * ele%s
  p_max = max(abs(vec(2)), abs(vec(4)))
 
  if (dr_max * abs(vec(6)) > ds_max * p_max) then
    dlen = ds_max / abs(vec(6))
  else
    dlen = dr_max / p_max
  endif

  ! Propagate and see if there is a hit

  call capillary_propagate_photon_a_step (photon, ele, dlen, .true.)

  if (capillary_photon_d_radius (photon%now, ele) > 0) then
    call capillary_photon_hit_spot_calc (photon, ele)
    return
  endif

  if (vec(5) == 0) then
    at_end = entrance_end$
    return
  endif

  if (vec(5) == ele%s) then
    at_end = exit_end$
    return
  endif

enddo

end subroutine capillary_track_photon_to_wall 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine capillary_propagate_photon_a_step (photon, ele, dlen, stop_at_boundary)
!
! Routine to track a photon a step of a given length
!
! Input:
!   photon -- photon_track_struct: Input coordinates.
!   ele    -- ele_struct: Capillary element
!   dlen   -- Real(rp): Length to propagate a photon. The actual propagation length
!               may be less if stop_at_boundary is True.
!
! Output:
!   photon -- Photon_struct: Output coordinates.
!   stop_at_boundary -- Logical: If True then stop at cross-section boundary.
!-

subroutine capillary_propagate_photon_a_step (photon, ele, dlen, stop_at_boundary)

implicit none

type (ele_struct), target :: ele
type (photon_track_struct), target :: photon
type (wall3d_section_struct), pointer :: section(:)

real(rp) dlen, dl, s_stop 
real(rp), pointer :: vec(:)

integer ix, ixc

logical stop_at_boundary

!

photon%old = photon%now
vec => photon%now%orb%vec

! If we do not have to stop at a boundary then propagation is easy.

if (.not. stop_at_boundary) then
  vec(1) = vec(1) + dlen * vec(2)
  vec(3) = vec(3) + dlen * vec(4)
  vec(5) = vec(5) + dlen * vec(6)
  photon%now%track_len = photon%now%track_len + dlen
  return
endif

! Here if stopping at a boundary plane is to be done...
! First see where we need to stop.

section => ele%wall3d%section
call bracket_index(section%s, 1, size(section), vec(5), ixc)

if (vec(6) > 0) then   ! Forward going photon
  if (section(ixc)%n_slice_spline > 1) then
    ix = int(section(ixc)%n_slice_spline * (vec(5) - section(ixc)%s) / (section(ixc+1)%s - section(ixc)%s))
    s_stop = section(ixc)%s + (ix+1) * (section(ixc+1)%s - section(ixc)%s)
  else
    s_stop = section(ixc+1)%s
  endif
else   ! Backward going photon
  if (section(ixc)%n_slice_spline > 1) then
    ix = int(section(ixc)%n_slice_spline * (vec(5) - section(ixc)%s) / (section(ixc+1)%s - section(ixc)%s))
    s_stop = section(ixc)%s + ix * (section(ixc+1)%s - section(ixc)%s)
  else
    s_stop = section(ixc)%s
  endif
endif

! Now calculate the distance to track

if (abs(vec(6)) * dlen > abs(s_stop - vec(5))) then
  dl = (s_stop - vec(5)) / vec(6)
else
  dl = dlen
endif

! And track to the stopping point.

vec(1) = vec(1) + dl * vec(2)
vec(3) = vec(3) + dl * vec(4)
vec(5) = vec(5) + dl * vec(6)
photon%now%track_len = photon%now%track_len + dl

end subroutine capillary_propagate_photon_a_step

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine capillary_photon_hit_spot_calc (photon, ele)
!
! Routine to interpolate to where the photon has hit the capillary.
!
! Input:
!   photon -- photon_track_struct: Input coordinates.
!   ele    -- ele_struct: Capillary element
!
! Output:
!   photon -- photon_track_struct: Photon at capillary wall
!-

subroutine capillary_photon_hit_spot_calc (photon, ele)

use nr, only: zbrent

implicit none

type (ele_struct), target :: ele
type (photon_track_struct), target :: photon

real(rp) d_rad, track_len0, track_len

integer i

character(40) :: r_name = 'capillary_photon_hit_spot_calc'

! Bracket the hit point. 
! Note: After the first reflection, the photon will start at the wall so
! if photon%old is at the wall we must avoid bracketing this point.

photon1_com = photon
photon_com => photon
ele_com => ele

track_len0 = (photon%now%track_len + photon%old%track_len) / 2
do i = 1, 30
  d_rad = photon_hit_func(track_len0)
  if (d_rad < 0) exit
  track_len0 = (track_len0 + photon%old%track_len) / 2
  if (i == 30) then
    call out_io (s_abort$, r_name, 'ERROR: CANNOT FIND HIT SPOT REGION LOWER BOUND!')
    call err_exit
  endif
enddo

! Find where the photon hits.

track_len = zbrent (photon_hit_func, track_len0, photon%now%track_len, 1d-10)

! Cleanup

photon%now = photon%old
call capillary_propagate_photon_a_step (photon, ele, track_len-photon%now%track_len, .false.)

end subroutine capillary_photon_hit_spot_calc

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function photon_hit_func (track_len) result (d_radius)
! 
! Routine to be used as an argument in zbrent in the capillary_photon_hit_spot_calc.
!
! Input:
!   track_len -- Real(rp): Place to position the photon.
!
! Output:
!   d_radius -- Real(rp): r_photon - r_wall

function photon_hit_func (track_len) result (d_radius)

real(rp), intent(in) :: track_len
real(rp) :: d_radius
real(rp) radius, d_track

! Easy case

if (track_len == photon_com%now%track_len) then
  d_radius = capillary_photon_d_radius (photon_com%now, ele_com)
  return
endif

! Track starting from the present position (photon1_com%now) if track_length > photon1_com%now%track_len.
! Otherwise, track starting from the beginning of the region (photon%old).

if (track_len < photon1_com%now%track_len) then
  photon1_com = photon_com
  photon1_com%now = photon_com%old
endif

! And track

d_track = track_len - photon1_com%now%track_len
call capillary_propagate_photon_a_step (photon1_com, ele_com, d_track, .false.)
d_radius = capillary_photon_d_radius (photon1_com%now, ele_com) 

end function photon_hit_func

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine capillary_reflect_photon (photon, ele, absorbed)
!
! Routine to reflect a photon from the capillary wall.
!
! Input:
!   photon -- photon_track_struct: Input coordinates.
!   ele    -- ele_struct: Capillary element
!
! Output:
!   photon   -- Photon_struct: Output coordinates.
!   absorbed -- Logical: If true the photon has been absorbed.
!-

subroutine capillary_reflect_photon (photon, ele, absorbed)

implicit none

type (ele_struct), target :: ele
type (photon_track_struct), target :: photon

real(rp) perp(3), r, graze_angle, cos_perp
real(rp), pointer :: vec(:)

logical absorbed

! perp is a vector perpendicular to the surface tangent plane

photon%old = photon%now
r = capillary_photon_d_radius (photon%now, ele, perp)

! The component of the photon velocity that is perpendicular to the surface 
! tangent gets reflected.

vec => photon%now%orb%vec
cos_perp = dot_product (vec(2:6:2), perp)
vec(2:6:2) = vec(2:6:2) - 2 * cos_perp * perp

! Check for absorbtion if the graze angle is too large.

absorbed = .false.
graze_angle = pi/2 - acos(cos_perp)
if (graze_angle > ele%value(critical_angle_factor$) / photon%now%energy) absorbed = .true.

end subroutine capillary_reflect_photon

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function capillary_photon_d_radius (p_orb, ele, perp) result (d_radius)
!
! Routine to calculate the normalized radius = photon_radius / wall_radius.
!
! Input:
!   p_orb   -- photon_coord_struct: Input coordinates.
!   ele     -- ele_struct: Capillary element
!
! Output:
!   d_radius -- Real(rp), Normalized radius: r_photon - r_wall
!   perp(3) -- Real(rp), optional: Perpendicular normal to the wall.
!-

function capillary_photon_d_radius (p_orb, ele, perp) result (d_radius)

implicit none

type (ele_struct), target :: ele
type (photon_coord_struct), target :: p_orb
type (wall3d_section_struct), pointer :: sec0, sec1

real(rp) d_radius, s00, s11, r_photon, f, spline, r00_wall, r11_wall, cos_theta, sin_theta
real(rp) r0_wall, r1_wall, dr0_dtheta, dr1_dtheta, f_eff, ds_spline
real(rp), optional :: perp(3)
real(rp), pointer :: vec(:)

integer ix, n_slice

! The outward normal vector is discontinuous at the wall points.
! If at a wall point, use the correct part of the wall.

vec => p_orb%orb%vec

call bracket_index (ele%wall3d%section%s, 1, size(ele%wall3d%section), vec(5), ix)
if (ix == size(ele%wall3d%section)) ix = size(ele%wall3d%section) - 1
if (vec(5) == ele%wall3d%section(ix)%s .and. vec(6) > 0 .and. ix /= 0) ix = ix - 1
p_orb%ix_section = ix

! sec0 and sec1 are the cross-sections to either side of the photon.

sec0 => ele%wall3d%section(ix)
sec1 => ele%wall3d%section(ix+1)

if (vec(1) == 0 .and. vec(3) == 0) then
  r_photon = 0
  cos_theta = 1
  sin_theta = 0
else
  r_photon = sqrt(vec(1)**2 + vec(3)**2)
  cos_theta = vec(1) / r_photon
  sin_theta = vec(3) / r_photon
endif

! Calculate the radius values at the cross-sections.

call calc_wall_radius (sec0%v, cos_theta, sin_theta, r0_wall, dr0_dtheta)
call calc_wall_radius (sec1%v, cos_theta, sin_theta, r1_wall, dr1_dtheta)

! Phantom slices

n_slice = nint(sec0%n_slice_spline)
if (n_slice > 1) then
  ix = min(int(f * n_slice), n_slice - 1)

  s00 = float(ix) / n_slice
  spline = sec0%s_spline(1) * s00 + sec0%s_spline(2) * s00**2 + sec0%s_spline(3) * s00**3
  r00_wall = (1 - spline) * r0_wall + spline * r1_wall

  s11 = float(ix+1) / n_slice
  spline = sec0%s_spline(1) * s11 + sec0%s_spline(2) * s11**2 + sec0%s_spline(3) * s11**3
  r11_wall = (1 - spline) * r0_wall + spline * r1_wall

else
  s00 = sec0%s
  s11 = sec1%s
  r00_wall = r0_wall
  r11_wall = r1_wall
endif

! Interpolate to get d_radius

f = (vec(5) - s00) / (s11 - s00)

if (n_slice == 0) then
  f_eff = sec0%s_spline(1) * f + sec0%s_spline(2) * f**2 + sec0%s_spline(3) * f**3
else
  f_eff = f
  ds_spline = s11 - s00
endif

d_radius = r_photon - ((1 - f_eff) * r00_wall + f_eff * r11_wall)

! Calculate the surface normal vector

if (present (perp)) then
  perp(1:2) = [cos_theta, sin_theta] - [-sin_theta, cos_theta] * &
                        ((1 - f_eff) * dr0_dtheta + f_eff * dr1_dtheta) / r_photon
  perp(3)   = -(r11_wall - r00_wall) / ds_spline
  perp = perp / sqrt(sum(perp**2))  ! Normalize vector length to 1.
endif

end function capillary_photon_d_radius

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine calc_wall_radius (v, cos_ang, sin_ang, r_wall, dr_dtheta)
!
! Routine to calculate the wall radius at a given angle for a given cross-section
! Additionally, the transverse directional derivative is calculated.
!
! Module needed:
!   use capillary_mod
!
! Input:
!   v(:)         -- wall3d_vertex_struct: Array of vertices that make up the cross-section.
!   cos_ang      -- Real(rp): cosine of the transverse photon position.
!   sin_ang      -- Real(rp): sine of the transverse photon position.
!
! Output:
!   r_wall      -- Real(rp): Wall radius at given angle.
!   dr_dtheta   -- Real(rp): derivative of r_wall.
!-

subroutine calc_wall_radius (v, cos_ang, sin_ang, r_wall, dr_dtheta)

implicit none

type (wall3d_vertex_struct), target :: v(:)
type (wall3d_vertex_struct), pointer :: v1, v2


real(rp) r_wall, dr_dtheta, rx, ry, da, db, angle
real(rp) numer, denom, ct, st, x0, y0, a, b, c
real(rp) cos_ang, sin_ang, radx, cos_a, sin_a, det
real(rp) r_x, r_y, dr_x, dr_y, cos_phi, sin_phi

integer ix

! Bracket index if there is more than one vertex
! If there is only one vertex then must be an ellipse or circle

angle = atan2(sin_ang, cos_ang)

if (size(v) == 1) then
  v2 => v(1)
else
  if (angle < v(1)%angle) angle = ceiling((v(1)%angle-angle)/twopi) * twopi + angle
  call bracket_index (v%angle, 1, size(v), angle, ix)

  v1 => v(ix)
  if (ix == size(v)) then
    v2 => v(1)
  else
    v2 => v(ix+1)
  endif
endif

! Straight line case

if (v2%radius_x == 0) then
  numer = (v1%x * v2%y - v1%y * v2%x)
  denom = (cos_ang * (v2%y - v1%y) - sin_ang * (v2%x - v1%x))
  r_wall = numer / denom
  dr_dtheta = numer * (sin_ang * (v2%y - v1%y) + cos_ang * (v2%x - v1%x)) / denom**2
  return
endif


! If ellipse...

if (v2%radius_y /= 0) then

  ! Convert into unrotated frame if tilted ellipse
  if (v2%tilt /= 0) then
    ct = cos(v2%tilt); st = sin(v2%tilt)
    x0 =  ct * v2%x0 + st * v2%y0
    y0 = -st * v2%x0 + ct * v2%y0
    cos_a = cos_ang * ct + sin_ang * st
    sin_a = sin_ang * ct - cos_ang * st
  else
    ct = 1; st = 0
    x0 = v2%x0; y0 = v2%y0
    cos_a = cos_ang; sin_a = sin_ang
  endif

  rx = v2%radius_x; ry = v2%radius_y
  a = (cos_a/rx)**2 + (sin_a/ry)**2
  b = -2 * (cos_a * x0 / rx**2 + sin_a * y0 / ry**2)
  c = (x0/rx)**2 + (y0/ry)**2 - 1
  radx = sqrt(b**2 - 4 * a * c)

  r_wall = (-b + radx) / (2 * a)

  ! dr/dtheta comes from the equations:
  !   /x\  =  /rad_x * cos(tilt)  -rad_y * sin(tilt)\  /cos(phi)\  +  /x0\
  !   \y/     \rad_x * sin(tilt)   rad_y * cos(tilt)/  \sin(phi)/     \y0/
  !   r = sqrt(x^2 + y^2)
  !   Tan(theta) = y/x
 
  r_x = r_wall * cos_ang; r_y = r_wall * sin_ang
  cos_phi = ( ct * (r_x - x0) + st * (r_y - y0)) / v2%radius_x
  sin_phi = (-st * (r_x - x0) + ct * (r_y - y0)) / v2%radius_y
  dr_x = -v2%radius_x * ct * sin_phi - v2%radius_y * st * cos_phi
  dr_y = -v2%radius_x * st * sin_phi + v2%radius_y * ct * cos_phi
  dr_dtheta = r_wall * (r_x * dr_x + r_y * dr_y) / (r_x * dr_y - r_y * dr_x)

  return
endif

! Else must be a circle.
! Solve for r_wall: (r_wall * cos_a - x0)^2 + (r_wall * sin_a - y0)^2 = radius^2
! dr/dtheta comes from the equations:
!   x = x0 + radius * cos(phi)
!   y = y0 + radius * sin(phi)
!   r = sqrt(x^2 + y^2)
!   Tan(theta) = y/x
! Then
!   dr_vec = (dx, dy) = (-radius * sin(phi), radius * cos(phi)) * dphi
!   dr/dtheta = r * (r_vec dot dr_vec) / (r_vec cross dr_vec)

x0 = v2%x0; y0 = v2%y0

a = 1
b = -2 * (cos_ang * x0 + sin_ang * y0)
c = x0**2 + y0**2 - v2%radius_x**2
radx = sqrt(b**2 - 4 * a * c)

r_wall = (-b + radx) / (2 * a)

r_x = r_wall * cos_ang; r_y = r_wall * sin_ang
dr_x = -(r_y - y0);    dr_y = r_x - x0

dr_dtheta = r_wall * (r_x * dr_x + r_y * dr_y) / (r_x * dr_y - r_y * dr_x)

end subroutine calc_wall_radius

end module
