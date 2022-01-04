!+
! function set_tune_3d (lat, target_tunes, use_phase_trombone, quad_mask, z_tune_set, print_err) result (everything_ok)
!
! Wrapper for set_tune and set_z_tune together.
!
! Input:
!   lat                 -- lat_struct:
!   target_tunes(1:3)   -- real(rp): Integer + fractional tunes for a, b, z modes (rad/2pi).
!   quad_mask           -- character(*), optional: Regular expression mask for matching quads to
!                                 use in qtuneing.
!   use_phase_trombone  -- logical, optional: Default False. If true, use a match element in phase trombone mode to adjust the tunes.
!                            The match element must be the first element in the lattice. Use insert_phase_trombone to insert one.
!   z_tune_set          -- logical, optional: Default True. If false, do not try to set the synch tune.
!   print_err           -- logical, optional: Print error message if there is a problem? Default is True.
!
! Output:
!   lat                 -- lat_struct: with adjusted quads and RF to match desired tunes.
!   everything_ok       -- logical: Returns true or false if set was successful.  
!-

function set_tune_3d (lat, target_tunes, quad_mask, use_phase_trombone, z_tune_set, print_err) result (everything_ok)

use bmad
use z_tune_mod

implicit none

type(lat_struct), target :: lat
type (ele_struct), pointer :: ele
type(coord_struct), allocatable :: co(:)
real(rp) target_tunes(3)
real(rp), allocatable, save :: dk1(:)
integer n, status
logical, optional :: use_phase_trombone, z_tune_set, print_err
logical everything_ok, err

character(*), optional :: quad_mask
character(*), parameter :: r_name = 'set_tune_3d'

!

everything_ok = .false.

if (all(target_tunes < 1)) then
  call out_io (s_fatal$, r_name, 'Only fractional tunes given for target_tunes!', &
                                 'Must supply integer + fractional tunes.', &
                                 'Stopping here...')
  stop
endif

! If user has not specified one or more tunes, set target

if (target_tunes(1) < 1.e-12) target_tunes(1) = lat%ele(lat%n_ele_track)%a%phi / twopi
if (target_tunes(2) < 1.e-12) target_tunes(2) = lat%ele(lat%n_ele_track)%b%phi / twopi
if (abs(target_tunes(3)) < 1.e-12) target_tunes(3) = lat%z%tune / twopi

! Phase trombone

if (logic_option(.false., use_phase_trombone)) then
  call twiss_and_track(lat, co, status)
  ele => lat%ele(1)
  n = lat%n_ele_track
  ele%value(dphi_a$) = twopi*target_tunes(1) - lat%ele(n)%a%phi
  ele%value(dphi_b$) = twopi*target_tunes(1) - lat%ele(n)%b%phi
  call make_mat6(ele, lat%param, co(0))
  call twiss_and_track(lat, co, status)
  return
endif

!

if (.not. allocated(dk1)) then ! first call to set_tune3; allocate and find quads
  allocate(dk1(lat%n_ele_max))
  call choose_quads_for_set_tune(lat, dk1, quad_mask)
endif
everything_ok = set_tune(twopi*target_tunes(1), twopi*target_tunes(2), dk1, lat, co, print_err)

if (logic_option(.true., z_tune_set)) call set_z_tune(lat, twopi*target_tunes(3))

end function set_tune_3d
