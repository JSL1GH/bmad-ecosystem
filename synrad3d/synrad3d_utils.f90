module synrad3d_utils

use synrad3d_struct
use random_mod
use photon_init_mod
use capillary_mod

private sr3d_wall_pt_params

contains

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine sr3d_init_and_check_wall (wall_file, lat, wall)
!
! Routine to check the vacuum chamber wall for problematic values.
! Also compute some wall parameters
!
! Input:
!   wall_file -- character(*): Name of the wall file.
!   lat       -- lat_struct: lattice
!
! Output:
!   wall -- sr3d_wall_struct: Wall structure with computed parameters.
!-

subroutine sr3d_init_and_check_wall (wall_file, lat, wall)

implicit none

type (sr3d_wall_struct), target :: wall
type (lat_struct) lat
type (sr3d_wall_pt_struct), pointer :: pt, pt0
type (sr3d_wall_pt_input) section
type (wall3d_vertex_struct) v(100)
type (wall3d_section_struct), pointer :: wall3d_section

real(rp) ix_vertex_ante(2), ix_vertex_ante2(2)

integer i, n, iu, n_wall_pt_max, ios, n_shape_max, ix_gen_shape

character(28), parameter :: r_name = 'sr3d_init_and_check_wall'
character(40) name
character(*) wall_file

logical err

namelist / wall_def / section, name
namelist / gen_shape_def / ix_gen_shape, v, ix_vertex_ante, ix_vertex_ante2


! Get wall info
! First count the cross-section number

iu = lunget()
open (iu, file = wall_file, status = 'old')
n_wall_pt_max = -1
do
  read (iu, nml = wall_def, iostat = ios)
  if (ios > 0) then ! error
    rewind (iu)
    do
      read (iu, nml = wall_def) ! will bomb program with error message
    enddo  
  endif
  if (ios < 0) exit   ! End of file reached
  n_wall_pt_max = n_wall_pt_max + 1
enddo

print *, 'number of wall cross-sections read:', n_wall_pt_max + 1
if (n_wall_pt_max < 1) then
  print *, 'NO WALL SPECIFIED. WILL STOP HERE.'
  stop
endif

allocate (wall%pt(0:n_wall_pt_max))
wall%n_pt_max = n_wall_pt_max

! Now transfer info from the file to the wall%pt array

n_shape_max = -1
rewind (iu)
do i = 0, n_wall_pt_max
  section%basic_shape = ''
  section%ante_height2_plus = -1
  section%ante_height2_minus = -1
  section%width2_plus = -1
  section%width2_minus = -1
  name = ''
  read (iu, nml = wall_def)

  wall%pt(i) = sr3d_wall_pt_struct(name, &
          section%s, section%basic_shape, section%width2, section%height2, &
          section%width2_plus, section%ante_height2_plus, &
          section%width2_minus, section%ante_height2_minus, &
          -1.0_rp, -1.0_rp, -1.0_rp, -1.0_rp, null())
  if (wall%pt(i)%basic_shape(1:9) == 'gen_shape') then
    n_shape_max = max (n_shape_max, nint(wall%pt(i)%width2))
  endif
enddo

! Get the gen_shape info

if (n_shape_max > 0) then
  rewind(iu)
  allocate (wall%gen_shape(n_shape_max))
  do
    ix_gen_shape = 0
    ix_vertex_ante = 0
    ix_vertex_ante2 = 0
    v = wall3d_vertex_struct(0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp)
    read (iu, nml = gen_shape_def, iostat = ios)
    if (ios > 0) then ! If error
      print *, 'ERROR READING GEN_SHAPE_DEF NAMELIST.'
      rewind (iu)
      do
        read (iu, nml = gen_shape_def) ! Generate error message
      enddo
    endif
    if (ios < 0) exit  ! End of file
    if (ix_gen_shape > n_shape_max) cycle  ! Allow shape defs that are not used.
    if (ix_gen_shape < 1) then
      print *, 'BAD IX_GEN_SHAPE VALUE IN WALL FILE: ', ix_gen_shape
      call err_exit
    endif

    ! Count number of vertices and calc angles.

    wall3d_section => wall%gen_shape(ix_gen_shape)%wall3d_section
    do n = 1, size(v)
      if (v(n)%x == 0 .and. v(n)%y == 0 .and. v(n)%radius_x == 0) exit
    enddo

    if (any(v(n:)%x /= 0) .or. any(v(n:)%y /= 0) .or. &
        any(v(n:)%radius_x /= 0) .or. any(v(n:)%radius_y /= 0)) then
      print *, 'MALFORMED GEN_SHAPE. NUMBER:', ix_gen_shape
      call err_exit
    endif

    if (allocated(wall3d_section%v)) then
      print *, 'ERROR: DUPLICATE IX_GEN_SHAPE =', ix_gen_shape
      call err_exit
    endif

    allocate(wall3d_section%v(n-1))
    wall3d_section%v = v(1:n-1)
    wall3d_section%n_vertex_input = n-1    

    call wall3d_section_initializer (wall3d_section, err)
    if (err) then
      print *, 'ERROR AT IX_GEN_SHAPE =', ix_gen_shape
      call err_exit
    endif

    wall%gen_shape(ix_gen_shape)%ix_vertex_ante = ix_vertex_ante
    if (ix_vertex_ante(1) > 0 .or. ix_vertex_ante(2) > 0) then
      if (ix_vertex_ante(1) < 1 .or. ix_vertex_ante(1) > size(wall3d_section%v) .or. &
          ix_vertex_ante(2) < 1 .or. ix_vertex_ante(2) > size(wall3d_section%v)) then
        print *, 'ERROR IN IX_VERTEX_ANTE:', ix_vertex_ante
        print *, '      FOR GEN_SHAPE =', ix_gen_shape
        call err_exit
      endif
    endif

    wall%gen_shape(ix_gen_shape)%ix_vertex_ante2 = ix_vertex_ante2
    if (ix_vertex_ante2(1) > 0 .or. ix_vertex_ante2(2) > 0) then
      if (ix_vertex_ante2(1) < 1 .or. ix_vertex_ante2(1) > size(wall3d_section%v) .or. &
          ix_vertex_ante2(2) < 1 .or. ix_vertex_ante2(2) > size(wall3d_section%v)) then
        print *, 'ERROR IN IX_VERTEX_ANTE2:', ix_vertex_ante2
        print *, '      FOR GEN_SHAPE =', ix_gen_shape
        call err_exit
      endif
    endif

  enddo
endif

close (iu)

! point to gen_shapes

do i = 0, n_wall_pt_max
  if (wall%pt(i)%basic_shape(1:9) == 'gen_shape') then
    wall%pt(i)%gen_shape => wall%gen_shape(nint(wall%pt(i)%width2))
  endif
enddo

! 

wall%pt(wall%n_pt_max)%s = lat%ele(lat%n_ele_track)%s
wall%geometry = lat%param%geometry

do i = 0, wall%n_pt_max
  pt => wall%pt(i)

  ! Check s ordering

  if (i > 0) then
    if (pt%s <= wall%pt(i-1)%s) then
      call out_io (s_fatal$, r_name, &
                'WALL%PT(i)%S: \f0.4\ ', &
                '    IS LESS THAN PT(i-1)%S: \f0.4\ ', &
                '    FOR I = \i0\ ', &
                r_array = [pt%s, wall%pt(i-1)%s], i_array = [i])
      call err_exit
    endif
  endif

  ! Check %basic_shape

  if (.not. any(pt%basic_shape == ['elliptical    ', 'rectangular   ', 'gen_shape     ', 'gen_shape_mesh'])) then
    call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(i)%BASIC_SHAPE: ' // pt%basic_shape, &
              '    FOR I = \i0\ ', i_array = [i])
    call err_exit
  endif

  ! Gen_shape and gen_shape_mesh checks

  if (pt%basic_shape == 'gen_shape' .or. pt%basic_shape == 'gen_shape_mesh') then
    if (.not. associated (pt%gen_shape)) then
      call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(I)%IX_GEN_SHAPE SECTION NUMBER \i0\ ', i_array = [i])
      call err_exit
    endif
    if (pt%basic_shape == 'gen_shape') cycle
    if (i == 0) cycle

    pt0 => wall%pt(i-1)
    if (pt0%basic_shape /= 'gen_shape' .and. pt0%basic_shape /= 'gen_shape_mesh') then
      call out_io (s_fatal$, r_name, &
              'BASIC_SHAPE FOR SECTION PRECEEDING "gen_shape_mesh" SECTION MUST BE ', &
              '"gen_shape" OR "gen_shape_mesh" SECTION NUMBER \i0\ ', i_array = [i])
      call err_exit
    endif

    if (size(pt0%gen_shape%wall3d_section%v) /= size(pt%gen_shape%wall3d_section%v)) then
      call out_io (s_fatal$, r_name, &
              '"gen_shape_mesh" CONSTRUCT MUST HAVE THE SAME NUMBER OF VERTEX POINTS ON', &
              'SUCCESIVE CROSS-SECTIONS  \2i0\ ', i_array = [i-1, i])
      call err_exit
    endif

    cycle
  endif

  ! Checks for everything else

  if (pt%width2 <= 0) then
    call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(i)%WIDTH2: \f0.4\ ', &
              '    FOR I = \i0\ ', r_array = [pt%width2], i_array = [i])
    call err_exit
  endif

  if (pt%width2 <= 0) then
    call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(i)%HEIGHT2: \f0.4\ ', &
              '    FOR I = \i0\ ', r_array = [pt%height2], i_array = [i])
    call err_exit
  endif

  ! +x side check

  if (pt%ante_height2_plus < 0 .and.pt%width2_plus > 0) then
    if (pt%width2_plus > pt%width2) then
      call out_io (s_fatal$, r_name, &
              'WITHOUT AN ANTECHAMBER: WALL%PT(i)%WIDTH2_PLUS \f0.4\ ', &
              '    MUST BE LESS THEN WIDTH2 \f0.4\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_plus, pt%width2], i_array = [i])
      call err_exit
    endif
  endif

  ! -x side check

  if (pt%ante_height2_minus < 0 .and. pt%width2_minus > 0) then
    if (pt%width2_minus > pt%width2) then
      call out_io (s_fatal$, r_name, &
              'WITHOUT AN ANTECHAMBER: WALL%PT(i)%WIDTH2_MINUS \f0.4\ ', &
              '    MUST BE LESS THEN WIDTH2 \f0.4\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_minus, pt%width2], i_array = [i])
      call err_exit
    endif
  endif

enddo

! If circular lattice then start and end shapes must match

if (wall%geometry == closed$) then
  pt0 => wall%pt(0)
  pt  => wall%pt(wall%n_pt_max)
  if (pt0%basic_shape /= pt%basic_shape .or. pt0%width2 /= pt%width2 .or. pt0%height2 /= pt%height2 .or. &
        pt0%ante_height2_plus /= pt%ante_height2_plus .or. pt0%width2_plus /= pt%width2_plus .or. &
        pt0%ante_height2_minus /= pt%ante_height2_minus .or. pt0%width2_minus /= pt%width2_minus) then
      call out_io (s_fatal$, r_name, &
              'FOR A "CLOSED" LATTICE THE LAST WALL CROSS-SECTION MUST BE THE SAME AS THE FIRST.')
      call err_exit
  endif
endif

! computations

do i = 0, wall%n_pt_max
  pt => wall%pt(i)

  ! +x side computation...
  ! If ante_height2_plus > 0 --> Has +x antechamber

  if (pt%ante_height2_plus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%ante_x0_plus = pt%width2 * sqrt (1 - (pt%ante_height2_plus / pt%height2)**2)
    else
      pt%ante_x0_plus = pt%width2
    endif

    if (pt%width2_plus <= pt%ante_x0_plus) then
      call out_io (s_fatal$, r_name, &
              'WITH AN ANTECHAMBER: WALL%PT(i)%WIDTH2_PLUS \f0.4\ ', &
              '    MUST BE GREATER THEN: \f0.4\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_plus, pt%ante_x0_plus], i_array = [i])
      call err_exit
    endif

  ! if width2_plus > 0 (and ante_height2_plus < 0) --> beam stop

  elseif (pt%width2_plus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%y0_plus = pt%height2 * sqrt (1 - (pt%width2_plus / pt%width2)**2)
    else
      pt%y0_plus = pt%height2
    endif
  endif

  ! -x side computation

  if (pt%ante_height2_minus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%ante_x0_minus = pt%width2 * sqrt (1 - (pt%ante_height2_minus / pt%height2)**2)
    else
      pt%ante_x0_minus = pt%width2
    endif

    if (pt%width2_minus <= pt%ante_x0_minus) then
      call out_io (s_fatal$, r_name, &
              'WITH AN ANTECHAMBER: WALL%PT(i)%WIDTH2_MINUS \f0.4\ ', &
              '    MUST BE GREATER THEN: \f0.4\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_minus, pt%ante_x0_minus], i_array = [i])

      call err_exit
    endif

  elseif (pt%width2_minus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%y0_minus = pt%height2 * sqrt (1 - (pt%width2_minus / pt%width2)**2)
    else
      pt%y0_minus = pt%height2
    endif
  endif

enddo

end subroutine sr3d_init_and_check_wall 

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine sr3d_get_emission_pt_params (lat, orb, ix_ele, s_offset, ele_here, orb_here, gx, gy)
!
! Routine to get the parameters at a photon emission point.
!
! Modules needed:
!   use synrad3d_utils
!
! Input:
!   lat       -- lat_struct with twiss propagated and mat6s made.
!   orb(0:*)  -- coord_struct: orbit of particles to use as source of ray.
!   ix_ele    -- integer: index of lat element to start ray from.
!   s_offset  -- real(rp): Distance from beginning of element to the point where the photon is emitted.
!
! Output:
!   ele_here  -- ele_struct: Twiss parameters at emission point.
!   orb_here  -- coord_struct: Beam center coords at emission point.
!   gx        -- Real(rp): Horizontal 1/bending_radius.
!   gy        -- Real(rp): Vertical 1/bending_radius.
!-

subroutine sr3d_get_emission_pt_params (lat, orb, ix_ele, s_offset, ele_here, orb_here, gx, gy)

use em_field_mod

implicit none

type (lat_struct), target :: lat
type (coord_struct) :: orb(0:), orb_here, orb1
type (ele_struct), pointer :: ele
type (ele_struct) ele_here
type (sr3d_photon_coord_struct) :: photon
type (em_field_struct) :: field

real(rp) s_offset, k_wig, g_max, l_small, gx, gy
real(rp), save :: s_old_offset = 0

integer ix_ele

logical err
logical, save :: init_needed = .true.

! Init

if (init_needed) then
  call init_ele (ele_here)
  init_needed = .false.
endif

ele  => lat%ele(ix_ele)

! Calc the photon's initial twiss values.
! Tracking through a wiggler can take time so use twiss_and_track_intra_ele to
!   minimize the length over which we track.

if (ele_here%ix_ele /= ele%ix_ele .or. ele_here%ix_branch /= ele%ix_branch .or. s_old_offset > s_offset) then
  ele_here = lat%ele(ix_ele-1)
  ele_here%ix_ele = ele%ix_ele
  ele_here%ix_branch = ele%ix_branch
  orb_here = orb(ix_ele-1)
  s_old_offset = 0
endif

call twiss_and_track_intra_ele (ele, lat%param, s_old_offset, s_offset, .true., .true., &
                                            orb_here, orb_here, ele_here, ele_here, err)
if (err) call err_exit
s_old_offset = s_offset

! Calc the photon's g_bend value (inverse bending radius at src pt) 

select case (ele%key)
case (sbend$)  

  ! sbends are easy
  gx = 1 / ele%value(rho$)
  gy = 0
  if (ele%value(roll$) /= 0) then
    gy = gx * sin(ele%value(roll$))
    gx = gx * cos(ele%value(roll$))
  endif

case (quadrupole$, sol_quad$, elseparator$)

  ! for quads or sol_quads, get the bending radius
  ! from the change in x' and y' over a small 
  ! distance in the element

  l_small = 1e-2      ! something small
  ele_here%value(l$) = l_small
  call make_mat6 (ele_here, lat%param, orb_here, orb_here, .true.)
  call track1 (orb_here, ele_here, lat%param, orb1)
  orb1%vec = orb1%vec - orb_here%vec
  gx = orb1%vec(2) / l_small
  gy = orb1%vec(4) / l_small

case (wiggler$)

  if (ele%sub_key == periodic_type$) then

    ! for periodic wigglers, get the max g_bend from 
    ! the max B field of the wiggler, then scale it 
    ! by the cos of the position along the poles

    k_wig = twopi * ele%value(n_pole$) / (2 * ele%value(l$))
    g_max = c_light * ele%value(b_max$) / (ele%value(p0c$))
    gx = g_max * sin (k_wig * s_offset)
    gy = 0
    orb_here%vec(1) = (g_max / k_wig) * sin (k_wig * s_offset)
    orb_here%vec(2) = (g_max / k_wig) * cos (k_wig * s_offset)

  else

    ! for mapped wigglers, find the B field at the source point
    ! Note: assumes particles are relativistic!!

    call em_field_calc (ele_here, lat%param, ele_here%value(l$), 0.0_rp, orb_here, .false., field)
    gx = field%b(2) * c_light / ele%value(p0c$)
    gy = field%b(1) * c_light / ele%value(p0c$)

  endif

case default

  print *, 'ERROR: UNKNOWN ELEMENT HERE ', ele%name

end select

end subroutine sr3d_get_emission_pt_params 


!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine sr3d_emit_photon (ele_here, orb_here, gx, gy, emit_a, emit_b, sig_e, photon_direction, photon)
!
! subroutine sr3d_to initialize a new photon
!
! Modules needed:
!   use synrad3d_utils
!
! Input:
!   ele_here  -- Ele_struct: Element emitting the photon. Emission is at the exit end of the element.
!   orb_here  -- coord_struct: orbit of particles emitting the photon.
!   gx, gy    -- Real(rp): Horizontal and vertical bending strengths.
!   emit_a    -- Real(rp): Emittance of the a-mode.
!   emit_b    -- Real(rp): Emittance of the b-mode.
!   photon_direction 
!             -- Integer: +1 In the direction of increasing s.
!                         -1 In the direction of decreasing s.
!
! Output:
!   photon    -- photon_coord_struct: Generated photon.
!-

subroutine sr3d_emit_photon (ele_here, orb_here, gx, gy, emit_a, emit_b, sig_e, photon_direction, p_orb)

implicit none

type (ele_struct), target :: ele_here
type (coord_struct) :: orb_here
type (sr3d_photon_coord_struct) :: p_orb
type (twiss_struct), pointer :: t

real(rp) emit_a, emit_b, sig_e, gx, gy, g_tot, gamma
real(rp) orb(6), r(3), vec(4), v_mat(4,4)

integer photon_direction

! Get photon energy and "vertical angle".

g_tot = sqrt(gx**2 + gy**2)
call convert_total_energy_to (ele_here%value(E_tot$), electron$, gamma) 
call photon_init (g_tot, gamma, orb)
p_orb%energy = orb(6)
p_orb%vec = 0
p_orb%vec(4) = orb(4) / sqrt(orb(4)**2 + 1)

! rotate photon if gy is non-zero

if (gy /= 0) then
  p_orb%vec(2) = gy * p_orb%vec(4) / g_tot
  p_orb%vec(4) = gx * p_orb%vec(4) / g_tot
endif

! Offset due to finite beam size

call ran_gauss(r)
t => ele_here%a
vec(1:2) = (/ sqrt(t%beta*emit_a) * r(1)                    + t%eta  * sig_e * r(3), &
              sqrt(emit_a/t%beta) * (r(2) + t%alpha * r(1)) + t%etap * sig_e * r(3) /)

call ran_gauss(r)
t => ele_here%b
vec(3:4) = (/ sqrt(t%beta*emit_b) * r(1)                    + t%eta  * sig_e * r(3), &
              sqrt(emit_b/t%beta) * (r(2) + t%alpha * r(1)) + t%etap * sig_e * r(3) /)

call make_v_mats (ele_here, v_mat)

p_orb%vec(1:4) = p_orb%vec(1:4) + matmul(v_mat, vec)

! Offset due to non-zero orbit.

p_orb%vec(1:4) = p_orb%vec(1:4) + orb_here%vec(1:4)

! Longitudinal position

p_orb%vec(5) = ele_here%s

! Note: phase space coords here are different from the normal beam and photon coords.
! Here vec(2)^2 + vec(4)^2 + vec(6)^2 = 1

p_orb%vec(6) = photon_direction * sqrt(1 - p_orb%vec(2)**2 - p_orb%vec(4)**2)

end subroutine sr3d_emit_photon

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine sr3d_photon_d_radius (p_orb, wall, d_radius, lat, dw_perp, in_antechamber)
!
! Routine to calculate the (transverse) radius of the photon  relative to the wall.
! Optionally can also caluclate the outwrd normal vector perpendicular to the wall.
!
! Modules needed:
!   use photon_utils
!
! Input:
!   wall -- sr3d_wall_struct: Wall
!   s    -- Real(rp): Longitudinal position.
!   lat  -- Lat_struct, optional: Lattice. Only needed when dw_perp is calculated.
!
! Output:
!   d_radius       -- real(rp): r_photon - r_wall
!   dw_perp(3)     -- real(rp), optional: Outward normal vector perpendicular to the wall.
!   in_antechamber -- Logical, optional: At antechamber wall?
!-

Subroutine sr3d_photon_d_radius (p_orb, wall, d_radius, lat, dw_perp, in_antechamber)

implicit none

type (sr3d_wall_struct), target :: wall
type (sr3d_photon_coord_struct), target :: p_orb
type (lat_struct), optional, target :: lat
type (ele_struct), pointer :: ele

real(rp) d_radius
real(rp), optional :: dw_perp(3)
real(rp) radius0, radius1, f, cos_ang, sin_ang, r_photon, disp
real(rp) dr0_dtheta, dr1_dtheta, pt0(3), pt1(3), pt2(3), dp1(3), dp2(3)

integer ix, ix_ele

logical, optional :: in_antechamber
logical in_ante0, in_ante1

!

call sr3d_get_wall_index (p_orb, wall, ix)

! gen_shape_mesh calc.
! The wall outward normal is just given by the cross product: (pt1-pt0) x (pt2-pt2)

if (wall%pt(ix+1)%basic_shape == 'gen_shape_mesh') then
  if (present(in_antechamber)) in_antechamber = .false.
  if (.not. present(dw_perp)) return
  call sr3d_get_mesh_wall_triangle_pts (wall%pt(ix), wall%pt(ix+1), p_orb%ix_triangle, pt0, pt1, pt2)
  dp1 = pt1 - pt0
  dp2 = pt2 - pt0
  dw_perp = [dp1(2)*dp2(3) - dp1(3)*dp2(2), dp1(3)*dp2(1) - dp1(1)*dp2(3), dp1(1)*dp2(2) - dp1(2)*dp2(1)]

! Not gen_shape_mesh calc.

else
  ! Get the parameters at the defined cross-sections to either side of the photon position.

  if (p_orb%vec(1) == 0 .and. p_orb%vec(3) == 0) then
    r_photon = 0
    cos_ang = 1
    sin_ang = 0
  else
    r_photon = sqrt(p_orb%vec(1)**2 + p_orb%vec(3)**2)
    cos_ang = p_orb%vec(1) / r_photon
    sin_ang = p_orb%vec(3) / r_photon
  endif

  call sr3d_wall_pt_params (wall%pt(ix),   cos_ang, sin_ang, radius0, dr0_dtheta, in_ante0)
  call sr3d_wall_pt_params (wall%pt(ix+1), cos_ang, sin_ang, radius1, dr1_dtheta, in_ante1)

  f = (p_orb%vec(5) - wall%pt(ix)%s) / (wall%pt(ix+1)%s - wall%pt(ix)%s)

  d_radius = r_photon - ((1 - f) * radius0 + f * radius1)

  if (present (dw_perp)) then
    dw_perp(1:2) = [cos_ang, sin_ang] - [-sin_ang, cos_ang] * &
                              ((1 - f) * dr0_dtheta + f * dr1_dtheta) / r_photon
    dw_perp(3) = (radius0 - radius1) / (wall%pt(ix+1)%s - wall%pt(ix)%s)
  endif

  if (present(in_antechamber)) in_antechamber = (in_ante0 .and. in_ante1)

endif

! In a bend dw_perp must be corrected since the true longitudinal "length" at the particle
! is, for a horizontal bend, ds * (1 + x/rho) where ds is the length along the reference 
! trajectory, x is the transverse displacement, and rho is the bend radius.

! Also dw_perp needs to be normalized to 1.

if (present(dw_perp)) then
  ix_ele = element_at_s (lat, p_orb%vec(5), .true.)
  ele => lat%ele(ix_ele)
  if (ele%key == sbend$) then
    if (ele%value(tilt_tot$) == 0) then
      disp = p_orb%vec(1) 
    else
      disp = p_orb%vec(1) * cos(ele%value(tilt_tot$)) + p_orb%vec(3) * sin(ele%value(tilt_tot$))
    endif
    dw_perp(3) = dw_perp(3) / (1 + disp * ele%value(g$))
  endif

  dw_perp = dw_perp / sqrt(sum(dw_perp**2))  ! Normalize
endif

end subroutine sr3d_photon_d_radius

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine sr3d_get_wall_index (p_orb, wall, ix_wall)
!
! Routine to get the wall index such that 
! For p_orb%vec(6) > 0 (forward motion):
!   wall%pt(ix_wall)%s < p_orb%vec(5) <= wall%pt(ix_wall+1)%s
! For p_orb%vec(6) < 0 (backward motion):
!   wall%pt(ix_wall)%s <= p_orb%vec(5) < wall%pt(ix_wall+1)%s
! Exceptions:
!   If p_orb%vec(5) == wall%pt(0)%s (= 0)       -> ix_wall = 0
!   If p_orb%vec(5) == wall%pt(wall%n_pt_max)%s -> ix_wall = wall%n_pt_max - 1
!
! Input:
!   p_orb  -- sr3d_photon_coord_struct: Photon position.
!   wall   -- sr3d_wall_struct: Wall structure
!
! Output:
!   ix_wall -- Integer: Wall index
!-

subroutine sr3d_get_wall_index (p_orb, wall, ix_wall)

implicit none

type (sr3d_photon_coord_struct) :: p_orb
type (sr3d_wall_struct), target :: wall

integer ix_wall
integer, save :: ix_wall_old = 0

! 

ix_wall = ix_wall_old
if (p_orb%vec(5) < wall%pt(ix_wall)%s .or. p_orb%vec(5) > wall%pt(ix_wall+1)%s) then
  call bracket_index (wall%pt%s, 0, wall%n_pt_max, p_orb%vec(5), ix_wall)
  if (ix_wall == wall%n_pt_max) ix_wall = wall%n_pt_max - 1
endif

! vec(5) at boundary cases

if (p_orb%vec(5) == wall%pt(ix_wall)%s   .and. p_orb%vec(6) > 0 .and. ix_wall /= 0)               ix_wall = ix_wall - 1
if (p_orb%vec(5) == wall%pt(ix_wall+1)%s .and. p_orb%vec(6) < 0 .and. ix_wall /= wall%n_pt_max-1) ix_wall = ix_wall + 1

p_orb%ix_wall = ix_wall
ix_wall_old = ix_wall

end subroutine sr3d_get_wall_index

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine sr3d_get_mesh_wall_triangle_pts (pt1, pt2, ix_tri, tri_vert0, tri_vert1, tri_vert2)
!
! Routine to return the three vertex points for a triangular wall surface element between
! two cross-sections.
!
! Input:
!   pt1 -- sr3d_wall_pt_struct: A gen_shape or gen_shape_mesh cross-section.
!   pt2 -- sr3d_wall_pt_struct: Second cross-section. Should be gen_shape_mesh.
!   ix_tr  -- Integer: Triangle index. Must be between 1 and 2*size(pt1%gen_shape%wall3d_section%v).
!               [Note: size(pt1%gen_shape%wall3d_section%v) = size(pt2%gen_shape%wall3d_section%v)]
!
! Output:
!   tri_vert0(3), tri_vert1(3), tri_vert2(3)
!         -- Real(rp): (x, y, s) vertex points for the triangle.
!             Looking from the outside, the points are in counter-clockwise order.
!             This is important in determining the outward normal vector
!-

subroutine sr3d_get_mesh_wall_triangle_pts (pt1, pt2, ix_tri, tri_vert0, tri_vert1, tri_vert2)

implicit none

type (sr3d_wall_pt_struct) pt1, pt2

integer ix_tri
integer ix1, ix2

real(rp) tri_vert0(3), tri_vert1(3), tri_vert2(3)

! 

ix1 = (ix_tri + 1) / 2
ix2 = ix1 + 1
if (ix2 > size(pt1%gen_shape%wall3d_section%v)) ix2 = 1

if (odd(ix_tri)) then
  tri_vert0 = [pt1%gen_shape%wall3d_section%v(ix1)%x, pt1%gen_shape%wall3d_section%v(ix1)%y, pt1%s]
  tri_vert1 = [pt1%gen_shape%wall3d_section%v(ix2)%x, pt1%gen_shape%wall3d_section%v(ix2)%y, pt1%s]
  tri_vert2 = [pt2%gen_shape%wall3d_section%v(ix1)%x, pt2%gen_shape%wall3d_section%v(ix1)%y, pt2%s]
else
  tri_vert0 = [pt1%gen_shape%wall3d_section%v(ix2)%x, pt1%gen_shape%wall3d_section%v(ix2)%y, pt1%s]
  tri_vert1 = [pt2%gen_shape%wall3d_section%v(ix2)%x, pt2%gen_shape%wall3d_section%v(ix2)%y, pt2%s]
  tri_vert2 = [pt2%gen_shape%wall3d_section%v(ix1)%x, pt2%gen_shape%wall3d_section%v(ix1)%y, pt2%s]
endif

end subroutine sr3d_get_mesh_wall_triangle_pts

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine sr3d_wall_pt_params (wall_pt, cos_photon, sin_photon, r_wall, dr_dtheta, in_antechamber, wall)
!
! Routine to compute parameters needed by sr3d_photon_d_radius routine.
!
! Input:
!   wall_pt -- sr3d_wall_pt_struct: Wall outline at a particular longitudinal location.
!   cos_photon -- Real(rp): Cosine of the photon transverse position.
!   sin_photon -- Real(rp): Sine of the photon transverse position.
!   wall       -- sr3d_wall_struct: Needed to determine the basic_shape.
!
! Output:
!   r_wall         -- Real(rp): Radius of the wall
!   dr_dtheta      -- Real(rp): Transverse directional derivatives: d(r_wall)/d(theta)
!   in_antechamber -- Logical: Set true of particle is in antechamber
!-

subroutine sr3d_wall_pt_params (wall_pt, cos_photon, sin_photon, r_wall, dr_dtheta, in_antechamber)

implicit none

type (sr3d_wall_pt_struct) wall_pt, pt
type (wall3d_vertex_struct), pointer :: v(:)

real(rp) dr_dtheta, cos_photon, sin_photon 
real(rp) r_wall

integer ix, ix_vertex, ixv(2)

logical in_antechamber

! Init

in_antechamber = .false.

! general shape

if (wall_pt%basic_shape == 'gen_shape') then
  call calc_wall_radius (wall_pt%gen_shape%wall3d_section%v, cos_photon, sin_photon, r_wall, dr_dtheta, ix_vertex)

  ixv = wall_pt%gen_shape%ix_vertex_ante
  if (ixv(1) > 0) then
    if (ixv(2) > ixv(1)) then
      if (ix_vertex >= ixv(1) .and. ix_vertex < ixv(2)) in_antechamber = .true.
    else
      if (ix_vertex >= ixv(1) .or. ix_vertex < ixv(2)) in_antechamber = .true.
    endif
  endif

  ixv = wall_pt%gen_shape%ix_vertex_ante2
  if (ixv(1) > 0) then
    if (ixv(2) > ixv(1)) then
      if (ix_vertex >= ixv(1) .and. ix_vertex < ixv(2)) in_antechamber = .true.
    else
      if (ix_vertex >= ixv(1) .or. ix_vertex < ixv(2)) in_antechamber = .true.
    endif
  endif

  return
endif


! general shape: Should not be here

if (wall_pt%basic_shape == 'gen_shape_mesh') then
  call err_exit
endif

! Check for antechamber or beam stop...
! If the line extending from the origin through the photon intersects the
! antechamber or beam stop then pretend the chamber is rectangular with the 
! antechamber or beam stop dimensions.

! Positive x side check.

pt = wall_pt

if (cos_photon > 0) then

  ! If there is an antechamber...
  if (pt%ante_height2_plus > 0) then

    if (abs(sin_photon/cos_photon) < pt%ante_height2_plus/pt%ante_x0_plus) then  
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_plus
      pt%height2 = pt%ante_height2_plus
      if (cos_photon >= pt%ante_x0_plus) in_antechamber = .true.
    endif

  ! If there is a beam stop...
  elseif (pt%width2_plus > 0) then
    if (abs(sin_photon/cos_photon) < pt%y0_plus/pt%width2_plus) then 
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_plus
    endif

  endif

! Negative x side check

elseif (cos_photon < 0) then

  ! If there is an antechamber...
  if (pt%ante_height2_minus > 0) then

    if (abs(sin_photon/cos_photon) < pt%ante_height2_minus/pt%ante_x0_minus) then  
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_minus
      pt%height2 = pt%ante_height2_minus
      if (cos_photon >= pt%ante_x0_minus) in_antechamber = .true.
    endif

  ! If there is a beam stop...
  elseif (pt%width2_minus > 0) then
    if (abs(sin_photon / cos_photon) < pt%y0_minus/pt%width2_minus) then 
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_minus
    endif

  endif

endif

! Compute parameters

if (pt%basic_shape == 'rectangular') then
  if (abs(cos_photon/pt%width2) > abs(sin_photon/pt%height2)) then
    r_wall = pt%width2 / abs(cos_photon)
    dr_dtheta = r_wall * sin_photon / cos_photon
  else
    r_wall = pt%height2 / abs(sin_photon)
    dr_dtheta = -r_wall * cos_photon / sin_photon
  endif

elseif (pt%basic_shape == 'elliptical') then
  r_wall = 1 / sqrt((cos_photon/pt%width2)**2 + (sin_photon/pt%height2)**2)
  dr_dtheta = r_wall**3 * cos_photon * sin_photon * (1/pt%width2**2 - 1/pt%height2**2)
endif

end subroutine sr3d_wall_pt_params

end module
