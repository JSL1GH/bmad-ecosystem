module ptc_map_with_radiation_mod

! Etienne wanted the "zhe" stuff to be standalone and so duplicated structures in 

use ptc_layout_mod
use duan_zhe_map, only: tree_element_zhe => tree_element, probe_zhe => probe, track_tree_probe_complex_zhe, zhe_ini

type ptc_map_with_rad_struct
  type (tree_element_zhe) sub_map(3)
  character(200) lattice_file     ! Name of the lattice file
  integer map_order
  logical radiation_damping_on
  integer ix_branch
  integer ix_ele_start            ! Start point for making the map
  integer ix_ele_end              ! End point for making the map
end type

contains

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine ptc_setup_map_with_radiation (map_with_rad, ele1, ele2, orbit1, map_order, map_with_damping, err_flag)
!
! Routine to construct a map including radiation damping and excitation.
! Note: The setting of bmad_com%radiation_damping_on will determine if damping is included in the map.
!
! ele1/ele2 must have an associated PTC layout (which can be constructed by calling lat_to_ptc_layout).
!
! To track after calling this routine track by calling ptc_track_with_radiation.
! To cleanup memory after using, call ptc_kill_map_with_radiation.
! To save a map call ptc_write_map_with_radiation.
! To read a saved map call ptc_read_map_with_radiation.
!
! Input:
!   ele1              -- ele_struct: The map starts at the exit end of ele1.
!   ele2              -- ele_struct, optional: The map ends at the exit end of ele2. If not present, the 
!                          1-turn map will be constructed.
!   orbit1            -- coord_struct, optional: Orbit at ele1 about which the map is constructed.
!                          If not present then the orbit will be computed using PTC tracking.
!   map_order         -- integer, optional: Order of the map. 
!                          If not present or less than 1, the currently set order is used.
!   map_with_damping  -- logical, optional: If True (the default), the map will be constructed with radiation damping included.
!                          If False, the map will not be constructed with radiation dampling included. 
!                          Since radiation damping can always be turned off when tracking, if you are only concerned about
!                          the orbital motion, there is no reason to create a map without damping. 
!                          However, the spin map is constructed about the closed orbit so the spin map will be affected
!                          by whether damping is on or not. 
!                          To the extent that the damping is small the shift in the spin map will be small.
!
! Output:
!   map_with_rad    -- ptc_map_with_rad_struct: Transport map.
!   err_flag        -- logical, optional: Set True if there is an error such as not associated PTC layout.
!-

subroutine ptc_setup_map_with_radiation (map_with_rad, ele1, ele2, map_order, map_with_damping, orbit1, err_flag)

use pointer_lattice

implicit none

type (ptc_map_with_rad_struct) map_with_rad
type (ele_struct) ele1
type (ele_struct), optional :: ele2
type (coord_struct), optional :: orbit1
type (layout), pointer :: ptc_layout
type (internal_state) state, state0
type (branch_struct), pointer :: branch
type (fibre), pointer :: f1, f2
type (tree_element) tree_map(3)

real(rp) orb(6), orb0(6)

integer, optional :: map_order
integer val_save

logical, optional :: err_flag, map_with_damping

character(*), parameter :: r_name = 'ptc_setup_map_with_radiation'

!

if (present(err_flag)) err_flag = .true.

call zhe_ini(bmad_com%spin_tracking_on)
use_bmad_units = .true.

if (logic_option(.true., map_with_damping)) then
  state = default + radiation0 + envelope0
  map_with_rad%radiation_damping_on = .true.
else
  state = default + envelope0
  map_with_rad%radiation_damping_on = .false.
endif
state0 = default

if (bmad_com%spin_tracking_on) state = state + spin0
if (.not. rf_is_on(ele1%branch)) state = state + nocavity0

map_with_rad%map_order = integer_option(ptc_com%taylor_order_ptc, map_order)
if (map_with_rad%map_order < 1) map_with_rad%map_order = ptc_com%taylor_order_ptc

call init_all(state, map_with_rad%map_order, 0)

branch => pointer_to_branch(ele1)
ptc_layout => branch%ptc%m_t_layout
map_with_rad%ix_branch = branch%ix_branch
map_with_rad%lattice_file = branch%lat%input_file_name

if (.not. associated(ptc_layout)) then
  call out_io (s_fatal$, r_name, 'NO ASSOCIATED PTC LAYOUT PRESENT!')
  if (global_com%exit_on_error) call err_exit
  return
endif

f1 => pointer_to_ptc_ref_fibre(ele1)
map_with_rad%ix_ele_start = ele1%ix_ele

if (present(ele2)) then
  f2 => pointer_to_ptc_ref_fibre(ele2)
  map_with_rad%ix_ele_end = ele2%ix_ele
else
  f2 => f1
  map_with_rad%ix_ele_end = ele1%ix_ele
endif

if (present(orbit1)) then
  orb = orbit1%vec
else
  orb = 0
  call find_orbit_x(orb, STATE, 1.0d-8, fibre1 = f1)
  orb0 = 0
  call find_orbit_x(orb0, STATE0, 1.0d-8, fibre1 = f1)
endif

call set_ptc_quiet(0, set$, val_save)
!!call fill_tree_element_line_zhe(state, f1, f2, order, orb, stochprec = 1d-10, sagan_tree = tree_map)
call fill_tree_element_line_zhe0(state0, state, f1, f2, map_with_rad%map_order, orb0, orb, stochprec = 1d-10, sagan_tree = tree_map)
call set_ptc_quiet(0, unset$, val_save)

call copy_this_tree (tree_map, map_with_rad%sub_map)

use_bmad_units = .false. ! Since Zhe stuff is standalone this will not affect the use of map_with_rad.
if (present(err_flag)) err_flag = .false.

!----------------------------------------------------------------------------------
contains

subroutine copy_this_tree(t, u)

implicit none
type(tree_element) :: t(3)
type(tree_element_zhe) :: u(3)
integer i

do i = 1, 3
  u(i)%cc         => t(i)%cc
  u(i)%jl         => t(i)%jl
  u(i)%jv         => t(i)%jv
  u(i)%n          => t(i)%n
  u(i)%np         => t(i)%np
  u(i)%no         => t(i)%no
  u(i)%fixr       => t(i)%fixr
  u(i)%ds         => t(i)%ds
  u(i)%beta0      => t(i)%beta0
  u(i)%fix        => t(i)%fix
  u(i)%fix0       => t(i)%fix0
  u(i)%e_ij       => t(i)%e_ij
  u(i)%rad        => t(i)%rad
  u(i)%eps        => t(i)%eps
  u(i)%symptrack  => t(i)%symptrack
  u(i)%usenonsymp => t(i)%usenonsymp
  u(i)%factored   => t(i)%factored
enddo

end subroutine copy_this_tree

end subroutine ptc_setup_map_with_radiation

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine ptc_track_map_with_radiation (orbit, map_with_rad, rad_damp, rad_fluct)
!
! Routine to track through a map that includes radiation.
! To construct the map, use the routine ptc_setup_map_with_radiation.
! To cleanup memory after using, call ptc_kill_map_with_radiation.
! To save a map call ptc_write_map_with_radiation.
! To read a saved map call ptc_read_map_with_radiation.
!
! Input:
!   orbit            -- coord_struct: Starting orbit.
!   map_with_rad     -- ptc_map_with_rad_struct: Map with radiation included.
!   rad_damp         -- logical, optional: Override the setting of bmad_com%radiation_damping_on
!   rad_fluct        -- logical, optional: Override the setting of bmad_com%radiation_fluctuations_on
!   
! Output:
!   orbit            -- coord_struct: Ending orbit after tracking through the map.
!     %state            -- Set to lost$ if there is a problem.
!-

subroutine ptc_track_map_with_radiation (orbit, map_with_rad, rad_damp, rad_fluct)

use rotation_3d_mod
use duan_zhe_map, only: assignment(=), C_VERBOSE_ZHE

implicit none

type (coord_struct) orbit
type (ptc_map_with_rad_struct) map_with_rad
type (probe_zhe) z_probe

logical, optional :: rad_damp, rad_fluct
logical damp, fluct

!

damp   = logic_option(bmad_com%radiation_damping_on, rad_damp)
fluct = logic_option(bmad_com%radiation_fluctuations_on, rad_fluct)
C_VERBOSE_ZHE = .false.

!

z_probe = orbit%vec
z_probe%q%x = [1, 0, 0, 0]

call track_tree_probe_complex_zhe (map_with_rad%sub_map, z_probe, bmad_com%spin_tracking_on, damp, fluct)
if (z_probe%u) orbit%state = lost$   ! %u = T => "unstable".

orbit%vec = z_probe%x
if (bmad_com%spin_tracking_on) then
  orbit%spin = rotate_vec_given_quat(z_probe%q%x, orbit%spin)
endif

end subroutine ptc_track_map_with_radiation

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine ptc_write_map_with_radiation(file_name, map_with_rad)
!
! Routine to create a binary file containing a ptc_map_with_rad_struct map
!
! Input:
!   file_name        -- character(*): Name of binary file.
!   map_with_rad     -- ptc_map_with_rad_struct: Map with radiation included.
!-

subroutine ptc_write_map_with_radiation(file_name, map_with_rad)

type (ptc_map_with_rad_struct), target :: map_with_rad
type (tree_element_zhe), pointer :: t

integer i, j, k, iu
character(*) file_name

!

iu = lunget()
open (iu, file = file_name, form = 'unformatted')

write (iu) map_with_rad%lattice_file
write (iu) map_with_rad%map_order, map_with_rad%radiation_damping_on, &
            map_with_rad%ix_branch, map_with_rad%ix_ele_start, map_with_rad%ix_ele_end

do k = 1, 3
  t => map_with_rad%sub_map(k)
  call write_real1(t%cc)
  call write_real1(t%fixr)
  call write_real1(t%fix)
  call write_real1(t%fix0)
  call write_int1(t%jl)
  call write_int1(t%jv)
  call write_int0(t%n)
  call write_int0(t%np)
  call write_int0(t%no)
  call write_real2(t%e_ij)
  call write_real2(t%rad)
  call write_real0(t%ds)
  call write_real0(t%beta0)
  call write_real0(t%eps)
  call write_logic0(t%symptrack)
  call write_logic0(t%usenonsymp)
  call write_logic0(t%factored)
enddo

close(iu)

!-------------------------------------------------------------------
contains

subroutine write_real0(rr)
real(rp), pointer :: rr
write (iu) rr
end subroutine write_real0

subroutine write_real1(rr)
real(rp), pointer :: rr(:)
write (iu) size(rr)
write (iu) rr
end subroutine write_real1

subroutine write_real2(rr)
real(rp), pointer :: rr(:,:)
write (iu) size(rr, 1), size(rr, 2)
write (iu) rr
end subroutine write_real2

subroutine write_int0(rr)
integer, pointer :: rr
write (iu) rr
end subroutine write_int0

subroutine write_int1(rr)
integer, pointer :: rr(:)
write (iu) size(rr)
write (iu) rr
end subroutine write_int1

subroutine write_logic0(rr)
logical, pointer :: rr
write (iu) rr
end subroutine write_logic0

end subroutine ptc_write_map_with_radiation

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine ptc_read_map_with_radiation(file_name, map_with_rad)
!
! Routine to read a binary file containing a ptc_map_with_rad_struct map
!
! Input:
!   file_name        -- character(*): Name of binary file.
!
! Output:
!   map_with_rad     -- ptc_map_with_rad_struct: Map with radiation included.
!-

subroutine ptc_read_map_with_radiation(file_name, map_with_rad)

type (ptc_map_with_rad_struct), target :: map_with_rad
type (tree_element_zhe), pointer :: t

integer i, j, k, iu
character(*) file_name

!

iu = lunget()
open (iu, file = file_name, form = 'unformatted', status = 'old')

read (iu) map_with_rad%lattice_file
read (iu) map_with_rad%map_order, map_with_rad%radiation_damping_on, &
            map_with_rad%ix_branch, map_with_rad%ix_ele_start, map_with_rad%ix_ele_end

do k = 1, 3
  t => map_with_rad%sub_map(k)
  call read_real1(t%cc)
  call read_real1(t%fixr)
  call read_real1(t%fix)
  call read_real1(t%fix0)
  call read_int1(t%jl)
  call read_int1(t%jv)
  call read_int0(t%n)
  call read_int0(t%np)
  call read_int0(t%no)
  call read_real2(t%e_ij)
  call read_real2(t%rad)
  call read_real0(t%ds)
  call read_real0(t%beta0)
  call read_real0(t%eps)
  call read_logic0(t%symptrack)
  call read_logic0(t%usenonsymp)
  call read_logic0(t%factored)
enddo

close(iu)

call zhe_ini(bmad_com%spin_tracking_on)

!-------------------------------------------------------------------
contains

subroutine read_real0(rr)
real(rp), pointer :: rr
allocate(rr)
read (iu) rr
end subroutine read_real0

subroutine read_real1(rr)
real(rp), pointer :: rr(:)
integer n
read (iu) n
allocate(rr(n))
read (iu) rr
end subroutine read_real1

subroutine read_real2(rr)
real(rp), pointer :: rr(:,:)
integer n1, n2
read (iu) n1, n2
allocate(rr(n1,n2))
read (iu) rr
end subroutine read_real2

subroutine read_int0(rr)
integer, pointer :: rr
allocate(rr)
read (iu) rr
end subroutine read_int0

subroutine read_int1(rr)
integer, pointer :: rr(:)
integer n
read (iu) n
allocate(rr(n))
read (iu) rr
end subroutine read_int1

subroutine read_logic0(rr)
logical, pointer :: rr
allocate(rr)
read (iu) rr
end subroutine read_logic0

end subroutine ptc_read_map_with_radiation

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine ptc_kill_map_with_radiation(map_with_rad)
!
! Routine to kill a binary file containing a ptc_map_with_rad_struct map
!
! Input:
!   map_with_rad     -- ptc_map_with_rad_struct: Map with radiation included.
!
! Output:
!   map_with_rad     -- ptc_map_with_rad_struct: Deallocated map.
!-

subroutine ptc_kill_map_with_radiation(map_with_rad)

type (ptc_map_with_rad_struct), target :: map_with_rad
type (tree_element_zhe), pointer :: t
integer k

!

do k = 1, 3
  t => map_with_rad%sub_map(k)
  deallocate(t%cc)
  deallocate(t%fixr)
  deallocate(t%fix)
  deallocate(t%fix0)
  deallocate(t%jl)
  deallocate(t%jv)
  deallocate(t%n)
  deallocate(t%np)
  deallocate(t%no)
  deallocate(t%e_ij)
  deallocate(t%rad)
  deallocate(t%ds)
  deallocate(t%beta0)
  deallocate(t%eps)
  deallocate(t%symptrack)
  deallocate(t%usenonsymp)
  deallocate(t%factored)
enddo

end subroutine ptc_kill_map_with_radiation

end module
