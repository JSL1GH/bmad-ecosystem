module wall3d_mod

use bmad_struct
use bmad_interface
use lat_geometry_mod
use rotation_3d_mod

!

interface re_allocate
  module procedure re_allocate_wall3d_section_array
end interface

interface re_allocate
  module procedure re_allocate_wall3d_vertex_array
end interface

contains

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine re_allocate_wall3d_vertex_array (v, n, exact)
!
! Routine to reallocate an array of vertex structures.
! Overloaded by re_allocate.
!
! Modules needed:
!   use wall3d_mod
!
! Input:
!   v(:)  -- wall3d_vertex_struct, allocatable: Array of vertices
!   n     -- Integer: Minimum size needed for array.
!   exact -- Logical, optional: If present and False then the size of
!                    the output array is permitted to be larger than n.
!                    Default is True.
!
! Output:
!   v(:)  -- Wall3d_vertex_struct: Allocated array.
!-

subroutine re_allocate_wall3d_vertex_array (v, n, exact)

implicit none

type (wall3d_vertex_struct), allocatable :: v(:), temp_v(:)

integer, intent(in) :: n
integer n_save, n_old

logical, optional :: exact

!

if (allocated(v)) then
  n_old = size(v)
  if (n == n_old) return
  if (.not. logic_option(.true., exact) .and. n < n_old) return
  n_save = min(n, n_old)
  allocate (temp_v(n_save))
  temp_v = v(1:n_save)
  deallocate (v)
  allocate (v(n))
  v(1:n_save) = temp_v
  deallocate (temp_v)
else
  allocate (v(n))
endif

end subroutine re_allocate_wall3d_vertex_array

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine re_allocate_wall3d_section_array (section, n, exact)
!
! Routine to reallocate an array of wall3d%section(:).
! Overloaded by re_allocate.
!
! Modules needed:
!   use wall3d_mod
!
! Input:
!   section(:) -- wall3d_section_struct, pointer: Array of vertices
!   n        -- Integer: Minimum size needed for array.
!   exact    -- Logical, optional: If present and False then the size of
!                    the output array is permitted to be larger than n.
!                    Default is True.
!
! Output:
!   section(:) -- Wall3d_section_struct, pointer: Allocated array.
!-

subroutine re_allocate_wall3d_section_array (section, n, exact)

implicit none

type (wall3d_section_struct), allocatable :: section(:), temp_section(:)

integer, intent(in) :: n
integer n_save, n_old

logical, optional :: exact

!

if (n == 0) then
  if (.not. allocated(section)) return
  deallocate(section)

elseif (allocated(section)) then
  n_old = size(section)
  if (n == n_old) return
  if (.not. logic_option(.true., exact) .and. n < n_old) return
  n_save = min(n, n_old)
  allocate (temp_section(n_old))
  temp_section = section 
  deallocate(section)
  allocate (section(n))
  section(1:n_save) = temp_section
  deallocate (temp_section)

else
  allocate (section(n))
endif

end subroutine re_allocate_wall3d_section_array


!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine wall3d_initializer (wall3d, err)
!
! Routine to initialize a wall3d_struct
!   1) Add vertex points if there is symmetry.
!   2) Compute circular and elliptical centers.
!   3) Compute spline coefficients, etc.
!
! Modules needed:
!   use wall3d_mod
!
! Input:
!   wall3d -- wall3d_struct: Wall.
!   
! Output:
!   wall3d -- wall3d_struct: Initialized wall.
!   err    -- Logical: Set true if there is a problem.
!-

subroutine wall3d_initializer (wall3d, err)

implicit none

type (wall3d_struct), target :: wall3d
type (wall3d_section_struct), pointer :: s1, s2

real(rp) r1_ave, r2_ave, cos_ang, sin_ang, r, ds, dr_dtheta, a1, a2

integer i, j, n_ave

logical err

! initialize the cross-sections

do i = 1, size(wall3d%section)
  call wall3d_section_initializer(wall3d%section(i), err)
  if (err) return
enddo

! Calculate p0 and p1 spline coefs 

do i = 1, size(wall3d%section) - 1
  s1 => wall3d%section(i)
  s2 => wall3d%section(i+1)

  ! Only do the calc if dr_ds has been set on both sections.
  if (s1%dr_ds == real_garbage$ .or. s2%dr_ds == real_garbage$) cycle

  ! calc average radius
  
  r1_ave = 0; r2_ave = 0
  n_ave = 100
  do j = 1, n_ave
    cos_ang = cos(j * twopi / n_ave)
    sin_ang = sin(j * twopi / n_ave)
    call calc_wall_radius(s1%v, cos_ang, sin_ang, r, dr_dtheta)
    r1_ave = r1_ave + r / n_ave
    call calc_wall_radius(s2%v, cos_ang, sin_ang, r, dr_dtheta)
    r2_ave = r2_ave + r / n_ave
  enddo

  ! Calc coefficients

  ds = s2%s - s1%s
  a1 = 0; a2 = 0
  a1 = s1%dr_ds * ds - (r2_ave - r1_ave)  
  a2 = s2%dr_ds * ds - (r2_ave - r1_ave)  

  s1%p1_coef = [a1, -2*a1-a2, a1+a2] / (2 * r1_ave)
  s1%p2_coef = [a1, -2*a1-a2, a1+a2] / (2 * r2_ave)

enddo

end subroutine wall3d_initializer

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine wall3d_section_initializer (section, err)
!
! Routine to initialize a wall3d_section_struct:
!   1) Add vertex points if there is symmetry.
!   2) Compute circular and elliptical centers.
!
! Modules needed:
!   use wall3d_mod
!
! Input:
!   section  -- Wall3d_section_struct: Wall3d section.
!   
! Output:
!   section  -- Wall3d_section_struct: Initialized section-section.
!   err    -- Logical: Set true if there is a problem.
!-

subroutine wall3d_section_initializer (section, err)

implicit none

type (wall3d_section_struct), target :: section
type (wall3d_vertex_struct), pointer :: v(:)

integer i, n, nn

logical err

character(40) :: r_name = 'wall3d_section_initializer'

! Init

err = .true.
v => section%v
n = section%n_vertex_input

! Single vertex is special.

if (n == 1 .and. v(1)%radius_x /= 0) then
  v(1)%x0 = v(1)%x; v(1)%y0 = v(1)%y
  err = .false.
  return
endif

! Compute angle

do i = 1, n
  v(i)%angle = atan2(v(i)%y, v(i)%x)
  if (i == 1) cycle
  if (v(i)%angle <= v(i-1)%angle) v(i)%angle = v(i)%angle + twopi

  if (v(i)%angle >= v(i-1)%angle + pi .or. v(i)%angle <= v(i-1)%angle) then
    call out_io (s_error$, r_name, 'WALL SECTION VERTEX NOT IN CLOCKWISE ORDER: (\2F10.5\)', &
                 r_array = [v(i)%x, v(i)%y])
    return
  endif

  if (v(i)%radius_x == 0 .and. v(i)%radius_y /= 0) then
    call out_io (s_error$, r_name, 'WALL SECTION VERTEX HAS RADIUS_X = 0 BUT RADIUS_Y != 0 (\2F10.5\)', &
                 r_array = [v(i)%radius_x, v(i)%radius_y])
  endif

  if (v(i)%radius_x * v(i)%radius_y < 0) then
    call out_io (s_error$, r_name, 'WALL SECTION VERTEX HAS RADIUS_X OF DIFFERENT SIGN FROM RADIUS_Y (\2F10.5\)', &
                 r_array = [v(i)%radius_x, v(i)%radius_y])
  endif

enddo

if (v(n)%angle - v(1)%angle >= twopi) then
  call out_io (s_error$, r_name, 'WALL SECTION WINDS BY MORE THAN 2PI!')
  return
endif

! If all (x, y) are in the first quadrent then assume left/right symmetry and 
! propagate vertices to the second quadrent.
! Also radius and tilt info must be moved to the correct vertex.

if (all(v(1:n)%x >= 0) .and. all(v(1:n)%y >= 0)) then
  if (v(n)%x == 0) then
    nn = 2*n - 1
    call re_allocate(section%v, nn, .false.); v => section%v
    v(n+1:nn) = v(n-1:1:-1)
  else
    nn = 2*n
    call re_allocate(section%v, nn, .false.); v => section%v
    v(n+1:nn) = v(n:1:-1)
    v(n+1)%radius_x = 0; v(n+1)%radius_y = 0; v(n+1)%tilt = 0
  endif
  v(n+1:nn)%x           = -v(n+1:nn)%x
  v(n+1:nn)%angle       = pi - v(n+1:nn)%angle
  v(nn-n+2:nn)%radius_x = v(n:2:-1)%radius_x
  v(nn-n+2:nn)%radius_y = v(n:2:-1)%radius_y
  v(nn-n+2:nn)%tilt     = -v(n:2:-1)%tilt

  n = nn

endif

! If everything is in the upper half plane assume up/down symmetry and
! propagate vertices to the bottom half.

if (all(v(1:n)%y >= 0)) then
  if (v(n)%y == 0) then  ! Do not duplicate v(n) vertex
    nn = 2*n - 1
    call re_allocate(section%v, nn, .false.); v => section%v
    v(n+1:nn) = v(n-1:1:-1)
  else
    nn = 2*n ! Total number of vetices
    call re_allocate(section%v, nn, .false.); v => section%v
    v(n+1:nn) = v(n:1:-1)
    v(n+1)%radius_x = 0; v(n+1)%radius_y = 0; v(n+1)%tilt = 0
  endif

  v(n+1:nn)%y           = -v(n+1:nn)%y
  v(n+1:nn)%angle       = twopi - v(n+1:nn)%angle
  v(nn-n+2:nn)%radius_x = v(n:2:-1)%radius_x
  v(nn-n+2:nn)%radius_y = v(n:2:-1)%radius_y
  v(nn-n+2:nn)%tilt     = -v(n:2:-1)%tilt

  if (v(1)%y == 0) then ! Do not duplicate v(1) vertex
    v(nn)%angle = v(1)%angle
    v(1) = v(nn)
    nn = nn - 1
  endif

  n = nn
  call re_allocate(section%v, n, .true.); v => section%v

! If everything is in the right half plane assume right/left symmetry and
! propagate vertices to the left half.

elseif (all(v(1:n)%x >= 0)) then
  if (v(n)%x == 0) then  ! Do not duplicate v(n) vertex
    nn = 2*n - 1
    call re_allocate(section%v, nn, .false.); v => section%v
    v(n+1:nn) = v(n-1:1:-1)
  else
    nn = 2*n ! Total number of vetices
    call re_allocate(section%v, nn, .false.); v => section%v
    v(n+1:nn) = v(n:1:-1)
    v(n+1)%radius_x = 0; v(n+1)%radius_y = 0; v(n+1)%tilt = 0
  endif

  v(n+1:nn)%x           = -v(n+1:nn)%x
  v(n+1:nn)%angle       = pi - v(n+1:nn)%angle
  v(nn-n+2:nn)%radius_x = v(n:2:-1)%radius_x
  v(nn-n+2:nn)%radius_y = v(n:2:-1)%radius_y
  v(nn-n+2:nn)%tilt     = -v(n:2:-1)%tilt

  if (v(1)%x == 0) then ! Do not duplicate v(1) vertex
    v(nn)%angle = v(1)%angle
    v(1) = v(nn)
    nn = nn - 1
  endif

  n = nn
  call re_allocate(section%v, n, .true.); v => section%v

endif

! Calculate center of circle/ellipses...

err = .false.

do i = 1, n-1
  call calc_vertex_center (v(i), v(i+1), err)
  if (err) return
enddo
call calc_vertex_center (v(n), v(1), err)

!----------------------------------------------------------------------------
contains

subroutine calc_vertex_center (v1, v2, err)

type (wall3d_vertex_struct) v1, v2

real(rp) x1, y1, x2, y2, x, y
real(rp) x_mid, y_mid, dx, dy
real(rp) a, a2, ct, st

logical err

! If straight line nothing to be done
if (v2%radius_x == 0) return

! Convert (x, y) into unrotated frame if tilted ellipse

x1 = v1%x; y1 = v1%y
x2 = v2%x; y2 = v2%y

if (v2%tilt /= 0) then
  ct = cos(v2%tilt); st = sin(v2%tilt)
  x1 =  ct * v1%x + st * v1%y
  y1 = -st * v1%x + ct * v1%y
  x2 =  ct * v2%x + st * v2%y
  y2 = -st * v2%x + ct * v2%y
endif

! If ellipse then shrink y-axis

if (v2%radius_y /= 0) then
  y1 = y1 * v2%radius_x / v2%radius_y
  y2 = y2 * v2%radius_x / v2%radius_y
endif

! Find center of circle

x_mid = (x1 + x2)/2; y_mid = (y1 + y2)/2
dx    = (x2 - x1)/2; dy    = (y2 - y1)/2

! Find center

a2 = (v2%radius_x**2 - dx**2 - dy**2) / (dx**2 + dy**2)
if (a2 < 0) then
  call out_io (s_error$, r_name, 'WALL SECTION VERTEX POINTS TOO FAR APART FOR CIRCLE OR ELLIPSE')
  err = .true.
  return
endif

a = sqrt(a2)
if (x_mid * dy > y_mid * dx) a = -a
if (v2%radius_x < 0) a = -a
v2%x0 = x_mid + a * dy
v2%y0 = y_mid - a * dx

! Scale back if radius_y /= 0

if (v2%radius_y /= 0) then
  v2%y0 = v2%y0 * v2%radius_y / v2%radius_x
endif

! Rotate back if tilt /= 0

if (v2%tilt /= 0) then
  x = v2%x0; y = v2%y0
  v2%x0 = ct * x - st * y
  v2%y0 = st * x + ct * y
endif

end subroutine calc_vertex_center

end subroutine wall3d_section_initializer

!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------
!+
! Subroutine calc_wall_radius (v, cos_ang, sin_ang, r_wall, dr_dtheta, ix_vertex)
!
! Routine to calculate the wall radius at a given angle for a given cross-section
! Additionally, the transverse directional derivative is calculated.
!
! Module needed:
!   use wall3d_mod
!
! Input:
!   v(:)         -- wall3d_vertex_struct: Array of vertices that make up the cross-section.
!   cos_ang      -- Real(rp): cosine of the transverse photon position.
!   sin_ang      -- Real(rp): sine of the transverse photon position.
!
! Output:
!   r_wall      -- Real(rp): Wall radius at given angle.
!   dr_dtheta   -- Real(rp): derivative of r_wall.
!   ix_vertex   -- Integer, optional: Wall at given angle is between v(ix_vertex) and
!                    either v(ix_vertex+1) or v(1) if ix_vertex = size(v).
!-

subroutine calc_wall_radius (v, cos_ang, sin_ang, r_wall, dr_dtheta, ix_vertex)

implicit none

type (wall3d_vertex_struct), target :: v(:)
type (wall3d_vertex_struct), pointer :: v1, v2

real(rp) r_wall, dr_dtheta, rx, ry, da, db, angle
real(rp) numer, denom, ct, st, x0, y0, a, b, c
real(rp) cos_ang, sin_ang, radx, cos_a, sin_a, det
real(rp) r_x, r_y, dr_x, dr_y, cos_phi, sin_phi

integer, optional :: ix_vertex
integer ix

! Bracket index if there is more than one vertex
! If there is only one vertex then must be an ellipse or circle

angle = atan2(sin_ang, cos_ang)

if (size(v) == 1) then
  v2 => v(1)
  if (present(ix_vertex)) ix_vertex = 1
else
  if (angle < v(1)%angle) angle = ceiling((v(1)%angle-angle)/twopi) * twopi + angle
  call bracket_index (v%angle, 1, size(v), angle, ix)

  v1 => v(ix)
  if (present(ix_vertex)) ix_vertex = ix

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
    x0 = v2%x0; y0 = v2%y0
    cos_a = cos_ang; sin_a = sin_ang
  endif

  rx = v2%radius_x; ry = v2%radius_y
  a = (cos_a/rx)**2 + (sin_a/ry)**2
  b = -2 * (cos_a * x0 / rx**2 + sin_a * y0 / ry**2)
  c = (x0/rx)**2 + (y0/ry)**2 - 1
  radx = sqrt(b**2 - 4 * a * c)

  if (rx > 0) then
    r_wall = (-b + radx) / (2 * a)
  else
    r_wall = (-b - radx) / (2 * a)
  endif

  ! dr/dtheta comes from the equations:
  !   x  = rad_x * cos(phi) + x0
  !   y  = rad_y * sin(phi) + y0
  !   r = sqrt(x^2 + y^2)
  !   Tan(theta) = y/x
 
  r_x = r_wall * cos_a; r_y = r_wall * sin_a
  dr_x = -v2%radius_x * (r_y - y0) / v2%radius_y 
  dr_y =  v2%radius_y * (r_x - x0) / v2%radius_x 
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

if (v2%radius_x > 0) then
  r_wall = (-b + radx) / (2 * a)
else
  r_wall = (-b - radx) / (2 * a)
endif

r_x = r_wall * cos_ang; r_y = r_wall * sin_ang
dr_x = -(r_y - y0);    dr_y = r_x - x0

dr_dtheta = r_wall * (r_x * dr_x + r_y * dr_y) / (r_x * dr_y - r_y * dr_x)

end subroutine calc_wall_radius

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function wall3d_d_radius (position, ele, perp, ix_section, err_flag) result (d_radius)
!
! Routine to calculate the normalized radius = particle_radius - wall_radius.
! The radius is measured from the line connecting the section centers and not 
! the (x,y) = (0,0) origin
!
! Note: If the longitudinal position is at a trunk section, the results are not well defined.
! Solution: Always make sure the particle's position is at a trunk section. 
!
! Module needed:
!   use wall3d_mod
!
! Input:
!   position(6)  -- real(rp): Particle position
!                     [position(1), position(3)] = [x, y] transverse coords.
!                     position(5)                = Longitudinal position relative to beginning of element.
!                     position(6)                = Longitudinal velocity (only +/- sign matters).
!   ele          -- ele_struct: Element with wall
!
! Output:
!   d_radius   -- real(rp), Normalized radius: r_particle - r_wall
!   perp(3)    -- real(rp), optional: Perpendicular normal to the wall.
!   ix_section -- integer, optional: Set to wall slice section particle is in. 
!                  That is between ix_section and ix_section+1.
!   origin(3)  -- real(rp), optional: (x, y, s) origin with respect to the radius is measured.
!                   Uses the same coords as position.
!   err_flag   -- Logical, optional: Set True if error (for example no wall), false otherwise.
!-

function wall3d_d_radius (position, ele, perp, ix_section, origin, err_flag) result (d_radius)

implicit none

type (ele_struct), target :: ele
type (wall3d_section_struct), pointer :: sec1, sec2
type (wall3d_struct), pointer :: wall3d
type (wall3d_vertex_struct), allocatable :: v(:)
type (ele_struct), pointer :: ele1, ele2
type (floor_position_struct) floor_particle, floor1_0, floor2_0
type (floor_position_struct) floor1_w, floor2_w, floor1_dw, floor2_dw, floor1_p, floor2_p
type (floor_position_struct) loc_p, loc_1_0, loc_2_0, floor

real(rp), intent(in) :: position(:)
real(rp), optional :: perp(3), origin(3)

real(rp), pointer :: vec(:), value(:)
real(rp) d_radius, r_particle, r_norm, s_rel, spline, cos_theta, sin_theta
real(rp) r1_wall, r2_wall, dr1_dtheta, dr2_dtheta, f_eff, ds
real(rp) p1, p2, dp1, dp2, s_particle, dz_offset, x, y, x0, y0, f
real(rp) r(3), r0(3), rw(3), drw(3), dr0(3), dr(3), drp(3)
real(rp) dtheta_dphi, alpha, dalpha, beta, dx, dy, w_mat(3,3)
real(rp) s1, s2, r_p(3)

integer i, ix_w, n_slice, n_sec
integer, optional :: ix_section

logical, optional :: err_flag
logical err, is_branch_wall, wrapped

character(32), parameter :: r_name = 'wall3d_d_radius' 

! Find the wall definition

if (present(err_flag)) err_flag = .true.
d_radius = -1

wall3d => pointer_to_wall3d (ele, dz_offset, is_branch_wall)
if (.not. associated(wall3d)) return

!------------------
! Init

s_particle = position(5) + dz_offset
n_sec = size(wall3d%section)

! The outward normal vector is discontinuous at the wall points.
! If the particle is at a wall point, use the correct interval.
! If moving in +s direction then the correct interval is whith %section(ix_w+1)%s = particle position.

! Case where particle is outside the wall region. 
! In this case wrap if it is a chamber wall with a branch with closed geometry.
! Otherwise assume a constant cross-section.

if (s_particle < wall3d%section(1)%s .or. (s_particle == wall3d%section(1)%s .and. position(6) > 0)) then
  if (wrap_wall()) then
    sec1 => wall3d%section(n_sec)
    sec2 => wall3d%section(1)
    if (present(ix_section)) ix_section = n_sec
    wrapped = .true.
  else
    call d_radius_at_section(wall3d%section(1))
    return
  endif

elseif (s_particle > wall3d%section(n_sec)%s .or. (s_particle == wall3d%section(n_sec)%s .and. position(6) < 0)) then
  if (wrap_wall()) then
    sec1 => wall3d%section(n_sec)
    sec2 => wall3d%section(1)
    if (present(ix_section)) ix_section = n_sec
    wrapped = .true.
  else
    call d_radius_at_section(wall3d%section(n_sec))
    return
  endif

else

  ! Find the wall points (defined cross-sections) to either side of the particle.
  ! That is, the particle is in the interval [%section(ix_w)%s, %section(ix_w+1)%s].

  call bracket_index (wall3d%section%s, 1, size(wall3d%section), s_particle, ix_w)
  if (s_particle == wall3d%section(ix_w)%s .and. position(6) > 0) ix_w = ix_w - 1

  ! sec1 and sec2 are the cross-sections to either side of the particle.
  ! Calculate the radius values at the cross-sections.

  sec1 => wall3d%section(ix_w)
  sec2 => wall3d%section(ix_w+1)
  if (present(ix_section)) ix_section = ix_w
  wrapped = .false.

endif

! Crotch

if (sec1%type /= normal$ .and. sec2%type /= normal$) then

  select case (sec1%type)
  case (leg1$)
    if (sec2%type /= trunk1$) sec2 => wall3d%section(ix_w+2)
  case (leg2$)
    if (sec2%type /= trunk2$) sec2 => wall3d%section(ix_w+2)
  end select

  select case (sec2%type)
  case (leg1$)
    if (sec1%type /= trunk1$) sec1 => wall3d%section(ix_w-1)
  case (leg2$)
    if (sec1%type /= trunk2$) sec1 => wall3d%section(ix_w-1)
  end select

endif

!----------------------------
! If we are in a patch element then the geometry is more complicated since the section planes
! may not be perpendicular to the z-axis

cos_theta = 1  ! Default if r_particle == 0
sin_theta = 0

if (ele%key == patch$) then
  ! ele1 and ele2 are lattice elements of sec1 and sec2
  ele1 => pointer_to_ele (ele%branch%lat, sec1%ix_ele, sec1%ix_branch)
  ele2 => pointer_to_ele (ele%branch%lat, sec2%ix_ele, sec2%ix_branch)

  ! floor_particle is coordinates of particle in global reference frame
  ! floor1_0 is sec1 origin in global ref frame
  ! floor2_0 is sec2 origin in global ref frame
  floor_particle = local_to_floor (ele%floor, [position(1), position(3), position(5) - ele%value(l$)])
  floor1_0 = local_to_floor (ele1%floor, [sec1%x0, sec1%y0, sec1%s - ele1%s])
  floor2_0 = local_to_floor (ele2%floor, [sec2%x0, sec2%y0, sec2%s - ele2%s])

  ! loc_p  is coordinates of particle in ele1 ref frame
  ! loc_1_0 is coordinates of sec1 origin in ele1 ref frame
  ! loc_2_0 is coordinates of sec2 origin in ele1 ref frame
  loc_p = floor_to_local (ele1%floor, floor_particle, .false.)
  loc_1_0%r = [sec1%x0, sec1%y0, sec1%s - ele1%s]
  loc_2_0 = floor_to_local (ele1%floor, floor2_0, .false.)

  ! Find wall radius for sec1.
  dr0 = loc_2_0%r - loc_1_0%r
  dr0 = dr0 / norm2(dr0)
  drp = loc_p%r - loc_1_0%r
  s1 = drp(3) / dr0(3)
  dr = drp - s1 * dr0  ! should have dr(3) = 0
  r_norm = norm2(dr(1:2))
  if (r_norm /= 0) then
    cos_theta = dr(1) / r_norm
    sin_theta = dr(2) / r_norm
  endif
  call calc_wall_radius (sec1%v, cos_theta, sin_theta, r1_wall, dr1_dtheta)

  ! floor1_p is the particle coords projected onto the sec1 plane in global ref frame
  ! floor1_w  is sec1 wall pt in global reference frame

  alpha = drp(3) / dr0(3)
  floor1_p%r = loc_p%r - alpha * dr0 
  floor1_p = local_to_floor (ele1%floor, floor1_p%r)

  r = loc_1_0%r + r1_wall * [cos_theta, sin_theta, 0.0_rp]
  floor1_w = local_to_floor (ele1%floor, r)

  ! floor1_dw is sec1 wall pt derivative with respect to theta in global reference frame. 
  ! dtheta_dphi is change in local sec1 angle (theta) with respect to global angle (phi).

  if (present(perp)) then
    beta = sqrt( (dr0(2)**2 + dr0(3)**2) / (dr0(1)**2 + dr0(3)**2) )
    dtheta_dphi = (beta**2 * sin_theta**2 + cos_theta**2) / beta
    r = dtheta_dphi * (dr1_dtheta * [cos_theta, sin_theta, 0.0_rp] + r1_wall * [-sin_theta, cos_theta, 0.0_rp])
    floor1_dw = local_to_floor (ele1%floor, r)
    floor1_dw%r = floor1_dw%r - ele1%floor%r
  endif

  ! loc_p  is coordinates of particle in ele2 ref frame
  ! loc_1_0 is coordinates of sec1 origin in ele2 ref frame
  ! loc_2_0 is coordinates of sec2 origin in ele2 ref frame
  loc_p = floor_to_local (ele2%floor, floor_particle, .false.)
  loc_1_0 = floor_to_local (ele2%floor, floor1_0, .false.)
  loc_2_0%r = [sec2%x0, sec2%y0, sec2%s - ele2%s]

  ! Find wall radius for sec2.
  dr0 = loc_1_0%r - loc_2_0%r
  dr0 = dr0 / norm2(dr0)
  drp = loc_p%r - loc_2_0%r
  s2 = drp(3) / dr0(3)
  dr = drp - s2 * dr0
  r_norm = norm2(dr(1:2))
  if (r_norm /= 0) then
    cos_theta = dr(1) / r_norm
    sin_theta = dr(2) / r_norm
  endif
  call calc_wall_radius (sec2%v, cos_theta, sin_theta, r2_wall, dr2_dtheta)

  ! floor2_p is the particle coords projected onto the sec2 plane in global ref frame
  ! floor2_w  is sec2 wall pt in global reference frame

  alpha = drp(3) / dr0(3)
  floor2_p%r = loc_p%r - alpha * dr0 
  floor2_p = local_to_floor (ele2%floor, floor2_p%r)

  r = loc_2_0%r + r2_wall * [cos_theta, sin_theta, 0.0_rp]
  floor2_w = local_to_floor (ele2%floor, r)

  ! floor2_dw is sec2 wall pt derivative with respect to theta in global reference frame
  ! dtheta_dphi is change in local sec1 angle (theta) with respect to global angle (phi).

  if (present(perp)) then
    beta = sqrt( (dr0(2)**2 + dr0(3)**2) / (dr0(1)**2 + dr0(3)**2) )
    dtheta_dphi = (beta**2 * sin_theta**2 + cos_theta**2) / beta
    r = dtheta_dphi * (dr2_dtheta * [cos_theta, sin_theta, 0.0_rp] + r2_wall * [-sin_theta, cos_theta, 0.0_rp])
    floor2_dw = local_to_floor (ele2%floor, r)
    floor2_dw%r = floor2_dw%r - ele2%floor%r
  endif
  
  ! Interpolate to get r0 which is on the line between the section origins
  ! and rp which is on the line between floor1_p and floor2_p. 
  ! Note: If there is no spline then rp is the particle position.

  s_rel = s1 / (s1 + s2)
  p1 = 1 - s_rel + sec1%p1_coef(1)*s_rel + sec1%p1_coef(2)*s_rel**2 + sec1%p1_coef(3)*s_rel**3
  p2 =     s_rel + sec1%p2_coef(1)*s_rel + sec1%p2_coef(2)*s_rel**2 + sec1%p2_coef(3)*s_rel**3

  r0  = p1 * floor1_0%r + p2 * floor2_0%r
  r_p = p1 * floor1_p%r + p2 * floor2_p%r

  ! Calculate rw which is the point on the wall that intersects the line through r0 & r_p

  f = norm2(cross_product(r_p - r0, floor2_w%r - floor1_w%r))
  if (f == 0) then  ! At origin so give something approximate
    d_radius = -norm2(p1 * floor1_w%r + p2 * floor2_w%r - r0)
  else
    alpha = norm2(cross_product(floor1_w%r - r0, floor2_w%r - floor1_w%r)) / f
    rw = r0 + alpha * (r_p - r0)
    d_radius = norm2(r_p - r0) - norm2(rw - r0)
  endif

  if (present(origin)) then
    floor%r = r0
    floor = floor_to_local (ele%floor, floor, .false.) 
    origin = floor%r
    origin(3) = origin(3) + ele%value(l$)
  endif

  ! Calculate the surface normal vector

  if (present (perp)) then
    p1 = norm2(rw - floor2_w%r)
    p2 = norm2(rw - floor1_w%r)
    drw = p1 * floor1_dw%r + p2 * floor2_dw%r
    floor%r = cross_product(drw, floor2_w%r - floor1_w%r)
    floor = floor_to_local (ele%floor, floor, .false., .true.)  ! To patch coords
    perp = floor%r / norm2(floor%r)  ! Normalize vector length to 1.
    
  endif

!----------------------------
! non-patch element

else
  ds = sec2%s - sec1%s

  if (ds == 0) then
    if (position(6) > 0) then
      call d_radius_at_section(sec1)
    else
      call d_radius_at_section(sec2)
    endif
    return
  endif

  if (wrapped) ds = ds + ele%branch%param%total_length
  s_rel = (s_particle - sec1%s) / ds

  x0 = (1 - s_rel) * sec1%x0 + s_rel * sec2%x0
  y0 = (1 - s_rel) * sec1%y0 + s_rel * sec2%y0
  x = position(1) - x0; y = position(3) - y0
  r_particle = sqrt(x**2 + y**2)
  if (r_particle /= 0) then
    cos_theta = x / r_particle
    sin_theta = y / r_particle
  endif

  call calc_wall_radius (sec1%v, cos_theta, sin_theta, r1_wall, dr1_dtheta)
  call calc_wall_radius (sec2%v, cos_theta, sin_theta, r2_wall, dr2_dtheta)

  ! Interpolate to get d_radius

  p1 = 1 - s_rel + sec1%p1_coef(1)*s_rel + sec1%p1_coef(2)*s_rel**2 + sec1%p1_coef(3)*s_rel**3
  p2 =     s_rel + sec1%p2_coef(1)*s_rel + sec1%p2_coef(2)*s_rel**2 + sec1%p2_coef(3)*s_rel**3

  d_radius = r_particle - (p1 * r1_wall + p2 * r2_wall)

  ! Calculate the surface normal vector

  if (present(origin)) origin = [x0, y0, position(5)]

  if (present (perp)) then
    perp(1:2) = [cos_theta, sin_theta] - [-sin_theta, cos_theta] * &
                          (p1 * dr1_dtheta + p2 * dr2_dtheta) / r_particle
    dp1 = -1 + sec1%p1_coef(1) + 2 * sec1%p1_coef(2)*s_rel + 3 * sec1%p1_coef(3)*s_rel**2
    dp2 =  1 + sec1%p2_coef(1) + 2 * sec1%p2_coef(2)*s_rel + 3 * sec1%p2_coef(3)*s_rel**2
    perp(3)   = -(dp1 * r1_wall + dp2 * r2_wall) / ds
    perp = perp / norm2(perp)  ! Normalize vector length to 1.
    ! If section origin line is not aligned with the z-axis then the wall has a "shear"
    ! and the perpendicular vector must be corrected.
    dx = sec2%x0 - sec1%x0
    dy = sec2%y0 - sec1%y0
    if (dx /= 0 .or. dy /= 0) then
      perp(3) = perp(3) - (perp(1) * dx + perp(2) * dy) / ds
      perp = perp / norm2(perp)
    endif
  endif

endif

if (present(err_flag)) err_flag = .false.

!---------------------------------------------------------------------------
contains

subroutine d_radius_at_section (this_sec)

type (wall3d_section_struct) this_sec

!

x = position(1) - this_sec%x0; y = position(3) - this_sec%y0
r_particle = sqrt(x**2 + y**2)
if (r_particle == 0) then
  cos_theta = 1
  sin_theta = 0
else
  cos_theta = x / r_particle
  sin_theta = y / r_particle
endif

call calc_wall_radius (this_sec%v, cos_theta, sin_theta, r1_wall, dr1_dtheta)
d_radius = r_particle - r1_wall
if (present(perp)) perp = [cos_theta, sin_theta, 0.0_rp] - &
                          [-sin_theta, cos_theta, 0.0_rp] * dr1_dtheta / r_particle
if (present(origin)) origin = [this_sec%x0, this_sec%y0, position(5)]
if (present(err_flag)) err_flag = .false.

end subroutine d_radius_at_section

!---------------------------------------------------------------------------
! contains

function wrap_wall() result (yes_wrap)

logical yes_wrap

!

yes_wrap = .false.
if (.not. is_branch_wall) return
if (ele%branch%param%geometry == open$) return
yes_wrap = .true.

end function wrap_wall

end function wall3d_d_radius

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_wall3d (ele, ds_offset, is_branch_wall) result (wall3d)
!
! Function to return a pointer to the wall3d structure associated
! with a given lattice element. 
!
! Note: The wall associated with a the vacuum chamber is the branch%wall3d.
!
! Input:
!   ele            -- Ele_struct: lattice element.
!
! Output:
!   wall3d         -- wall3d_struct, pointer: Pointer to the associated wall structure.
!                       Will be nullified if there is no associated wall.
!   ds_offset      -- real(rp): Element offset: s(beginning of ele) - s(beginning of wall3d)
!   is_branch_wall -- logical, optional: Set True if wall3d points to branch%wall3d.
!-

function pointer_to_wall3d (ele, ds_offset, is_branch_wall) result (wall3d)

implicit none

character(32), parameter :: r_name = 'pointer_to_wall3d'

type (ele_struct), target :: ele
type (wall3d_struct), pointer :: wall3d

real(rp) ds_offset
logical, optional :: is_branch_wall

! 

if (ele%key /= capillary$ .and. ele%key /= diffraction_plate$ .and. associated (ele%branch)) then
  wall3d => ele%branch%wall3d
  ds_offset = ele%s - ele%value(l$) - ele%branch%ele(0)%s
  if (present(is_branch_wall)) is_branch_wall = .true.
  return
endif

if (present(is_branch_wall)) is_branch_wall = .false.

wall3d => ele%wall3d
if (.not. associated(wall3d)) return

select case (wall3d%ele_anchor_pt)
case (anchor_beginning$); ds_offset = -ele%value(l$)
case (anchor_center$);    ds_offset = -ele%value(l$) / 2
case (anchor_end$);       ds_offset = 0 
end select

end function pointer_to_wall3d

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine create_concatenated_wall3d (lat)
!
! Routine to concatinate lat%branch(i)ele(:)%wall3d%section(:) arrays into
! one lat%branch(i)%wall3d%section(:) array.
!
! Exceptions: capillary and aperture elements do not have their walls included.
!
! Module needed:
!   use wall3d_mod
!
! Input:
!   lat      -- lat_struct: lattice
!
! Output:
!   lat      -- lat_struct: Lattice
!   err_flag -- logical: Set True if there is an error, false otherwise.
!-

Subroutine create_concatenated_wall3d (lat, err)

implicit none

type section_ptr_struct
  type (wall3d_section_struct), pointer :: sec
  type (ele_struct), pointer :: ele
  real(rp) s
end type

type (lat_struct), target :: lat
type (branch_struct), pointer :: branch
type (ele_struct), pointer :: ele, ele1, ele2
type (section_ptr_struct), allocatable :: sp(:)
type (wall3d_section_struct), pointer :: ws

real(rp) s_min, s_max, s_temp

integer i, j, k, n, n_wall
logical err

character(*), parameter :: r_name = 'create_concatenated_wall3d'

! Count number of sections. This may be an overcount if there is superimpose.

err = .false.

do i = 0, ubound(lat%branch, 1)
  branch => lat%branch(i)

  s_min = branch%ele(0)%s
  s_max = branch%ele(branch%n_ele_track)%s

  n_wall = 0
  do j = 0, branch%n_ele_max
    ele => branch%ele(j)
    if (.not. associated(ele%wall3d)) cycle
    if (ele%key == capillary$) cycle
    if (ele%key == diffraction_plate$) cycle
    if (ele%lord_status == multipass_lord$) cycle  ! wall info also in slaves
    n_wall = n_wall + size(ele%wall3d%section)
  enddo

  if (n_wall == 0) then
    if (associated (branch%wall3d)) deallocate (branch%wall3d)
    cycle
  endif

  ! Aggragate vacuum chamber wall info for a branch to branch%wall3d structure
  ! First work on non-superimpose element

  if (allocated(sp)) deallocate (sp)
  allocate (sp(n_wall))

  n_wall = 0
  do j = 0, branch%n_ele_max
    ele => branch%ele(j)
    if (.not. associated(ele%wall3d)) cycle
    if (ele%key == capillary$) cycle
    if (ele%key == diffraction_plate$) cycle
    if (ele%wall3d%superimpose) cycle
    if (ele%lord_status == multipass_lord$) cycle
    call add_in_ele_wall_sections (ele, ele) ; if (err) return
  enddo

  ! Add superposition sections

  do j = 0, branch%n_ele_max
    ele => branch%ele(j)
    if (.not. associated(ele%wall3d)) cycle
    if (ele%key == capillary$) cycle
    if (ele%key == diffraction_plate$) cycle
    if (.not. ele%wall3d%superimpose) cycle
    if (ele%lord_status == multipass_lord$) cycle
    call superimpose_this_wall (ele, ele) ; if (err) return
  enddo

  ! Check for consistancy
  ! If there is an overlap but within significant_length then switch s-positions

  do j = 1, n_wall-1
    if (sp(j)%s > sp(j+1)%s) then
      if (sp(j)%s < sp(j+1)%s + bmad_com%significant_length) then
        s_temp = sp(j)%s
        sp(j)%s = sp(j+1)%s
        sp(j+1)%s = s_temp
      else
        call out_io (s_error$, r_name, 'WALL SECTIONS LONGITUDINALLY OUT-OF-ORDER', &
                     'SECTION AT: \es20.8\ FROM ELEMENT: ' // trim(sp(j)%ele%name) // ' (\i0\)', &
                     'NEXT SECTION AT: \es20.8\ FROM ELEMENT: ' // trim(sp(j+1)%ele%name) // ' (\i0\)', &
                     i_array = [sp(j)%ele%ix_ele, sp(j+1)%ele%ix_ele], r_array = [sp(j)%s, sp(j+1)%s])
        err = .true.
        return
      endif
    endif
  enddo

  ! Transfer info from sp to branch%wall3d
  ! branch%wall3d is never mutiply linked.

  if (.not. associated(branch%wall3d)) allocate (branch%wall3d)
  call re_allocate(branch%wall3d%section, n_wall)

  do j = 1, n_wall
    ws => branch%wall3d%section(j)
    call re_allocate(ws%v, size(sp(j)%sec%v))
    ws = sp(j)%sec
    ws%s = sp(j)%s
    ws%ix_ele = sp(j)%ele%ix_ele
    ws%ix_branch = sp(j)%ele%ix_branch
  enddo

enddo

!-----------------------------------------------------------------------------------------------
contains

subroutine add_in_ele_wall_sections (wall_ele, fiducial_ele)

type (ele_struct), target :: wall_ele, fiducial_ele
type (wall3d_struct), pointer :: wall
real(rp) s_ref, s
integer ii, k, ixw, nw, n, ix_wrap1, ix_wrap2

!

wall => wall_ele%wall3d
nw = size(wall%section)

select case (wall%ele_anchor_pt)
case (anchor_beginning$); s_ref = fiducial_ele%s - fiducial_ele%value(l$)
case (anchor_center$);    s_ref = fiducial_ele%s - fiducial_ele%value(l$) / 2
case (anchor_end$);       s_ref = fiducial_ele%s 
end select

! If the element wall has more than one section (so the wall has a finite length), add
! significant_length/10 to s to avoid a roundoff bug.

s = wall%section(1)%s + s_ref
if (size(wall%section) /= 1) s = s + bmad_com%significant_length/10
call bracket_index (sp%s, 1, n_wall, s, ixw)

if (ixw > 1 .and. ixw < n_wall) then
  if (sp(ixw-1)%ele%ix_ele == sp(ixw+1)%ele%ix_ele) then
    call print_overlap_error (section_ptr_struct(wall%section(1), ele, s), sp(ixw+1))
    return
  endif
endif

! Move existing sections if needed to make room for the sections of wall_ele.

if (ixw < n_wall) then
  sp(ixw+1+nw:n_wall+nw) = sp(ixw+1:n_wall)
endif

ix_wrap1 = 0; ix_wrap2 = 0
do ii = 1, nw
  k = ii + ixw
  sp(k)%sec => wall%section(ii)
  sp(k)%s = wall%section(ii)%s + s_ref
  sp(k)%ele => wall_ele

  if (sp(k)%s < s_min)                     ix_wrap1 = k
  if (sp(k)%s > s_max .and. ix_wrap2 == 0) ix_wrap2 = k
enddo

n_wall = n_wall + nw

n = nw+ixw

! If there is an overlap but within significant_length then switch s-positions.

if (n < n_wall) then
  if (sp(n)%s > sp(n+1)%s) then
    if (sp(n)%s < sp(n+1)%s + bmad_com%significant_length) then
      s = sp(n)%s
      sp(n)%s = sp(n+1)%s
      sp(n+1)%s = s
    else
      call print_overlap_error (sp(n), sp(n+1))
      return
    endif
  endif
endif

! Wrap sections if needed

if (ix_wrap1 /= 0 .and. branch%param%geometry == closed$) then
  sp(1:ix_wrap1)%s = sp(1:ix_wrap1)%s + (s_max - s_min)
  sp(1:n_wall) = [sp(ix_wrap1+1:n_wall), sp(1:ix_wrap1)]
endif

if (ix_wrap2 /= 0 .and. branch%param%geometry == closed$) then
  sp(ix_wrap2:n_wall)%s = sp(ix_wrap2:n_wall)%s - (s_max - s_min)
  sp(1:n_wall) = [sp(ix_wrap2:n_wall), sp(1:ix_wrap2)]
endif

end subroutine add_in_ele_wall_sections

!-----------------------------------------------------------------------------------------------
! contains

subroutine print_overlap_error (sp1, sp2)

type (section_ptr_struct) sp1, sp2

!

call out_io (s_error$, r_name, 'WALLS OVERLAP LONGITUDINALLY BETWEEN', &
           'ELEMENT: ' // trim(sp1%ele%name) // ' (\i0\) Section S = \f14.6\ ', &
           'AND ELEMENT: ' // trim(sp2%ele%name) // ' (\i0\) Section S = \f14.6\ ', &
           i_array = [sp1%ele%ix_ele, sp2%ele%ix_ele], r_array = [sp1%s, sp2%s])
err = .true.

end subroutine print_overlap_error

!-----------------------------------------------------------------------------------------------
! contains

subroutine superimpose_this_wall (wall_ele, fiducial_ele)

type (ele_struct), target :: wall_ele, fiducial_ele
type (wall3d_struct), pointer :: wall
real(rp) s_ref, s
integer ii, ixw1, ixw2, nw, n_del, ix_wrap1, ix_wrap2

!

wall => wall_ele%wall3d
nw = size(wall%section)

select case (wall%ele_anchor_pt)
case (anchor_beginning$); s_ref = fiducial_ele%s - fiducial_ele%value(l$)
case (anchor_center$);    s_ref = fiducial_ele%s - fiducial_ele%value(l$) / 2
case (anchor_end$);       s_ref = fiducial_ele%s 
end select

! If the element wall has more than one section (so the wall has a finite length), add
! significant_length/10 to s to avoid a roundoff bug.

s = wall%section(1)%s + s_ref
if (size(wall%section) /= 1) s = s + bmad_com%significant_length/10
call bracket_index (sp%s, 1, n_wall, s, ixw1)

s = wall%section(nw)%s + s_ref
if (size(wall%section) /= 1) s = s - bmad_com%significant_length/10
call bracket_index (sp%s, 1, n_wall, s, ixw2)

!

n_del = nw - (ixw2 - ixw1)  ! net number of sections added.

if (ixw2 < n_wall) then
  sp(ixw2+1+n_del:n_wall+n_del) = sp(ixw2+1:n_wall)
endif

ix_wrap1 = 0; ix_wrap2 = 0

do ii = 1, nw
  k = ii + ixw1
  sp(k)%sec => wall%section(ii)
  sp(k)%s = wall%section(ii)%s + s_ref
  sp(k)%ele => wall_ele

  if (sp(k)%s < s_min)                     ix_wrap1 = k
  if (sp(k)%s > s_max .and. ix_wrap2 == 0) ix_wrap2 = k
enddo

n_wall = n_wall + n_del

! Wrap sections if needed.
! Remember to discard any sections in the overlap region.

if (ix_wrap1 /= 0 .and. branch%param%geometry == closed$) then
  sp(1:ix_wrap1)%s = sp(1:ix_wrap1)%s + (s_max - s_min)
  do ii = ix_wrap1+1, n_wall
    if (sp(ii)%s <= sp(1)%s) cycle
    n_wall = ii - 1
    exit
  enddo    
  sp(1:n_wall) = [sp(ix_wrap1+1:n_wall), sp(1:ix_wrap1)]
endif

if (ix_wrap2 /= 0 .and. branch%param%geometry == closed$) then
  sp(ix_wrap2:n_wall)%s = sp(ix_wrap2:n_wall)%s - (s_max - s_min)
  do ii = ix_wrap2-1, 1, -1
    if (sp(ii)%s >= sp(n_wall)%s) cycle
    sp(1:n_wall-ii) = sp(ii+1:n_wall)
    n_wall = n_wall - ii
    ix_wrap2 = ix_wrap2 - ii
    exit
  enddo    
  sp(1:n_wall) = [sp(ix_wrap2:n_wall), sp(1:ix_wrap2)]
endif

end subroutine superimpose_this_wall 

end subroutine create_concatenated_wall3d

end module
