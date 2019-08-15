module tao_set_mod

use tao_interface
use tao_data_and_eval_mod
use tao_lattice_calc_mod

implicit none

contains

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
! Subroutine tao_set_key_cmd (key_str, cmd_str)
!
! Associates a command with a key press for single mode.
!
! Input:
!   key_str   -- character(*): keyboard key.
!   cmd_str   -- character(*): Command associated with key.
!-

subroutine tao_set_key_cmd (key_str, cmd_str)

integer i, n
character(*) key_str, cmd_str
character(*), parameter :: r_name = 'tao_set_key_cmd'

!

do i = 1, size(s%com%key)
  if (s%com%key(i)%name /= '' .and. s%com%key(i)%name /= key_str) cycle

  if (cmd_str == 'default') then
    if (s%com%key(i)%name /= key_str) then
      call out_io (s_error$, r_name, 'Key has not been set to begin with. Nothing to do.')
      return
    endif
    n = size(s%com%key)
    s%com%key(i:n) = [s%com%key(i+1:n), tao_alias_struct()]
  else
    s%com%key(i) = tao_alias_struct(key_str, cmd_str)
  endif

  return
enddo

call out_io (s_error$, r_name, 'KEY TABLE ARRAY OVERFLOW! PLEASE GET HELP!')

end subroutine tao_set_key_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
! Subroutine tao_set_ran_state_cmd (state_string)
!
! Sets the random number generator state.
!
! Input:
!   state_string -- Character(*): Encoded random number state.
!-

subroutine tao_set_ran_state_cmd (state_string)

implicit none

type (random_state_struct) ran_state
character(*) state_string
character(100) state_str
character(30) :: r_name = 'tao_set_ran_state_cmd'
integer ix, ios

!

call ran_default_state (get_state = ran_state)

call string_trim(state_string, state_str, ix)
read (state_str, *, iostat = ios) ran_state%ix 
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT READ FIRST RAN_STATE COMPONENT')
  return
endif

call string_trim(state_str(ix+1:), state_str, ix)
read (state_str, *, iostat = ios) ran_state%iy 
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT READ SECOND RAN_STATE COMPONENT')
  return
endif

call string_trim(state_str(ix+1:), state_str, ix)
read (state_str, *, iostat = ios) ran_state%number_stored 
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT READ THIRD RAN_STATE COMPONENT')
  return
endif

call string_trim(state_str(ix+1:), state_str, ix)
read (state_str, *, iostat = ios) ran_state%h_saved
if (ios /= 0 .or. ix == 0) then
  call out_io (s_error$, r_name, 'CANNOT READ FOURTH RAN_STATE COMPONENT')
  return
endif

call ran_default_state (set_state = ran_state)

end subroutine tao_set_ran_state_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
! Subroutine tao_set_lattice_cmd (dest_lat, source_lat)
!
! Sets a lattice equal to another. This will also update the data structs
!
! Input:
!   dest_lat -- Character(*): Maybe: 'model', 'design', or 'base' with 
!                     optional '@n' at beginning to indicate the universe
!   source_lat  -- Character(*): Maybe: 'model', 'design', or 'base' 
!
!  Output:
!    s%u(n) -- lat_struct: changes specified lattice in specified universe 
!-

subroutine tao_set_lattice_cmd (dest_lat, source_lat)

implicit none

character(*) dest_lat, source_lat
character(16) dest1_name
character(20) :: r_name = 'tao_set_lattice_cmd'

real(rp) source_val

integer i, j

logical, allocatable :: this_u(:)
logical err

! Lattice transfer

call tao_pick_universe (dest_lat, dest1_name, this_u, err)
if (err) return

do i = lbound(s%u, 1), ubound(s%u, 1)
  if (.not. this_u(i)) cycle
  call set_lat (s%u(i))
  if (err) return
enddo

call tao_var_repoint()

! Variable transfer for those variables which vary parameters of the affected universe(s).
! This only needs to be done when dest_lat is a model lattice.

if (dest1_name == 'model') then
  do i = 1, s%n_var_used

    do j = 1, size(s%var(i)%slave)
      if (.not. this_u(s%var(i)%slave(j)%ix_uni)) cycle

      select case (source_lat)
      case ('model')
        source_val = s%var(i)%slave(j)%model_value
      case ('base')
        source_val = s%var(i)%slave(j)%base_value
      case ('design')
        source_val = s%var(i)%design_value
      end select

      call tao_set_var_model_value (s%var(i), source_val)
      exit
    enddo

  enddo
endif

!-------------------------------------------
contains

subroutine set_lat (u)

implicit none

type (tao_universe_struct), target :: u
type (tao_lattice_struct), pointer :: dest1_lat
type (tao_lattice_struct), pointer :: source1_lat
real(rp), pointer :: dest_data(:), source_data(:)
logical, pointer :: dest_good(:), source_good(:)
logical calc_ok

integer j, ib

!

err = .false.

select case (dest1_name)
case ('model')
  u%calc%lattice = .true.
  dest1_lat => u%model
  dest_data => u%data%model_value
  dest_good => u%data%good_model
case ('base')
  dest1_lat => u%base
  dest_data => u%data%base_value
  dest_good => u%data%good_base
case default
  call out_io (s_error$, r_name, 'BAD NAME: ' // dest_lat)
  err = .true.
  return
end select

select case (source_lat)
case ('model')
  ! make sure model data is up to date
  call tao_lattice_calc (calc_ok)
  source1_lat => u%model
  source_data => u%data%model_value
  source_good => u%data%good_model
case ('base')
  source1_lat => u%base
  source_data => u%data%base_value
  source_good => u%data%good_base
case ('design')
  source1_lat => u%design
  source_data => u%data%design_value
  source_good => u%data%good_design
case default
  call out_io (s_error$, r_name, 'BAD NAME: ' // source_lat)
  err = .true.
  return
end select

! dest_lat = source_lat will not mess up the pointers in s%var since both lattices have the same
! number of elements and therefore no reallocation needs to be done.

dest1_lat%lat          = source1_lat%lat
dest1_lat%tao_branch   = source1_lat%tao_branch

do ib = 0, ubound(dest1_lat%tao_branch, 1)
  do j = lbound(dest1_lat%tao_branch(ib)%bunch_params, 1), ubound(dest1_lat%tao_branch(ib)%bunch_params, 1)
    dest1_lat%tao_branch(ib)%bunch_params(j) = source1_lat%tao_branch(ib)%bunch_params(j)
  enddo
enddo

! Transfer the data

dest_data = source_data
dest_good = source_good

end subroutine set_lat

end subroutine tao_set_lattice_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_global_cmd (who, value_str)
!
! Routine to set global variables
! 
! Input:
!   who       -- Character(*): which global variable to set
!   value_str -- Character(*): Value to set to.
!
! Output:
!    s%global  -- Global variables structure.
!-

subroutine tao_set_global_cmd (who, value_str)

use bookkeeper_mod, only: set_on_off

implicit none

type (tao_global_struct) global, old_global
type (tao_universe_struct), pointer :: u

character(*) who, value_str
character(20) :: r_name = 'tao_set_global_cmd'

integer iu, ios, iuni, i, ix
logical err, needs_quotes

namelist / params / global

! Special cases

if (who == 'phase_units') then
  call match_word (value_str, angle_units_name, ix)
  if (ix  == 0) then
    call out_io (s_error$, r_name, 'BAD COMPONENT')
    return
  endif
  s%global%phase_units = ix
  return
endif

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

needs_quotes = .false.
select case (who)
case ('random_engine', 'random_gauss_converter', 'track_type', &
      'prompt_string', 'optimizer', 'print_command', 'var_out_file')
  needs_quotes = .true.
case default
  ! Surprisingly enough, a namelist read will ignore a blank value field so catch this problem here.
  if (value_str == '') then
    call out_io (s_error$, r_name, 'SET VALUE IS BLANK!')
    return
  endif

end select
if (value_str(1:1) == "'" .or. value_str(1:1) == '"') needs_quotes = .false.

write (iu, '(a)') '&params'
if (needs_quotes) then
  write (iu, '(a)') ' global%' // trim(who) // ' = "' // trim(value_str) // '"'
else
  write (iu, '(a)') ' global%' // trim(who) // ' = ' // trim(value_str)
endif
write (iu, '(a)') '/'
write (iu, *)
rewind (iu)
global = s%global  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
  return
endif

call tao_data_check (err)
if (err) return

select case (who)
case ('prompt_color')
  call upcase_string(global%prompt_color)
case ('random_seed')
  call ran_seed_put (global%random_seed)
case ('random_engine')
  call ran_engine (global%random_engine)
case ('random_gauss_converter', 'random_sigma_cutoff')
 call ran_gauss_converter (global%random_gauss_converter, global%random_sigma_cutoff)
case ('rf_on')
  do iuni = lbound(s%u, 1), ubound(s%u, 1)
    u => s%u(iuni)
    if (global%rf_on) then
      call set_on_off (rfcavity$, u%model%lat, on$)
    else
      call set_on_off (rfcavity$, u%model%lat, off$)
    endif
  enddo
  s%u%calc%lattice = .true.
case ('silent_run')
  call tao_silent_run_set(s%global%silent_run)
case ('track_type')
  if (value_str /= 'single' .and. value_str /= 'beam') then
    call out_io (s_error$, r_name, 'BAD VALUE. MUST BE "single" OR "beam".')
    return
  endif
  s%u%calc%lattice = .true.
end select

s%global = global

end subroutine tao_set_global_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_csr_param_cmd (who, value_str)
!
! Routine to set csr_param variables
! 
! Input:
!   who       -- Character(*): which csr_param variable to set
!   value_str -- Character(*): Value to set to.
!
! Output:
!    csr_param  -- Csr_param variables structure.
!-

subroutine tao_set_csr_param_cmd (who, value_str)

implicit none

type (csr_parameter_struct) local_csr_param

character(*) who, value_str
character(20) :: r_name = 'tao_set_csr_param_cmd'

integer iu, ios
logical err

namelist / params / local_csr_param

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
write (iu, '(a)') ' local_csr_param%' // trim(who) // ' = ' // trim(value_str)
write (iu, '(a)') '/'
rewind (iu)
local_csr_param = csr_param  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
  return
endif

csr_param = local_csr_param
s%u%calc%lattice = .true.

end subroutine tao_set_csr_param_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_bmad_com_cmd (who, value_str)
!
! Routine to set bmad_com variables
! 
! Input:
!   who       -- Character(*): which bmad_com variable to set
!   value_str -- Character(*): Value to set to.
!-

subroutine tao_set_bmad_com_cmd (who, value_str)

implicit none

type (bmad_common_struct) this_bmad_com

character(*) who, value_str
character(20) :: r_name = 'tao_set_bmad_com_cmd'

integer iu, ios
logical err

namelist / params / this_bmad_com

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
write (iu, '(a)') ' this_bmad_com%' // trim(who) // ' = ' // trim(value_str)
write (iu, '(a)') '/'
rewind (iu)
this_bmad_com = bmad_com  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

call tao_data_check (err)
if (err) return

if (ios == 0) then
  bmad_com = this_bmad_com
  s%u%calc%lattice = .true.
else
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
endif

end subroutine tao_set_bmad_com_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_geodesic_lm_cmd (who, value_str)
!
! Routine to set geodesic_lm variables
! 
! Input:
!   who       -- Character(*): which geodesic_lm variable to set
!   value_str -- Character(*): Value to set to.
!-

subroutine tao_set_geodesic_lm_cmd (who, value_str)

use geodesic_lm

implicit none

type (geodesic_lm_param_struct) this_geodesic_lm

character(*) who, value_str
character(20) :: r_name = 'tao_set_geodesic_lm_cmd'

integer iu, ios
logical err

namelist / params / this_geodesic_lm

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
write (iu, '(a)') ' this_geodesic_lm%' // trim(who) // ' = ' // trim(value_str)
write (iu, '(a)') '/'
rewind (iu)
this_geodesic_lm = geodesic_lm_param  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

call tao_data_check (err)
if (err) return

if (ios == 0) then
  geodesic_lm_param = this_geodesic_lm
else
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
endif

end subroutine tao_set_geodesic_lm_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_opti_de_param_cmd (who, value_str)
!
! Routine to set opti_de_param variables
! 
! Input:
!   who       -- Character(*): which opti_de_param variable to set
!   value_str -- Character(*): Value to set to.
!-

subroutine tao_set_opti_de_param_cmd (who, value_str)

use opti_de_mod, only: opti_de_param

implicit none

character(*) who, value_str
character(20) :: r_name = 'tao_set_opti_de_param_cmd'

integer iu, ios
logical err

namelist / params / opti_de_param

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
write (iu, '(a)') ' opti_de_param%' // trim(who) // ' = ' // trim(value_str)
write (iu, '(a)') '/'
rewind (iu)
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
endif

end subroutine tao_set_opti_de_param_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_wave_cmd (who, value_str, err)
!
! Routine to set wave variables
! 
! Input:
!   who       -- Character(*): which wave variable to set
!   value_str -- Character(*): Value to set to.
!
! Output:
!    err     -- logical: Set True if there is an error. False otherwise.
!    s%wave  -- Wave variables structure.
!-

subroutine tao_set_wave_cmd (who, value_str, err)

implicit none

type (tao_wave_struct) wave

character(*) who, value_str
character(20) :: r_name = 'tao_set_wave_cmd'

real(rp) ix_a(2), ix_b(2)

integer iu, ios
logical err

namelist / params / ix_a, ix_b

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

err = .true.

ix_a = [s%wave%ix_a1, s%wave%ix_a2]
ix_b = [s%wave%ix_b1, s%wave%ix_b2]

write (iu, '(a)') '&params'
write (iu, '(a)') trim(who) // ' = ' // trim(value_str)
write (iu, '(a)') '/'
rewind (iu)
wave = s%wave  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
  return
endif

s%wave%ix_a1 = ix_a(1)
s%wave%ix_a2 = ix_a(2)
s%wave%ix_b1 = ix_b(1)
s%wave%ix_b2 = ix_b(2)

err = .false.

end subroutine tao_set_wave_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_beam_cmd (who, value_str, err)
!
! Routine to set various beam parameters.
! 
! Input:
!   who       -- Character(*): which parameter to set.
!   value_str -- Character(*): Value to set to.
!
! Output:
!    err      -- logical: Set True if there is an error. False otherwise.
!-

subroutine tao_set_beam_cmd (who, value_str)

type (tao_universe_struct), pointer :: u
type (ele_pointer_struct), allocatable, save, target :: eles(:)
type (ele_struct), pointer :: ele
type (beam_struct), pointer :: beam

integer ix, iu, n_loc, ie

logical, allocatable :: this_u(:)
logical err, logic

character(*) who, value_str
character(20) switch, who2
character(*), parameter :: r_name = 'tao_set_beam_cmd'

!

call tao_pick_universe (remove_quotes(who), who2, this_u, err); if (err) return

call match_word (who2, [character(32):: 'track_start', 'track_end', 'all_file', 'saved_at', &
                    'beam_track_start', 'beam_track_end', 'beam_all_file', 'beam_init_file_name', 'beam_saved_at', &
                    'beginning', 'not_saved_at', 'beam_init_position_file'], ix, matched_name=switch)

do iu = lbound(s%u, 1), ubound(s%u, 1)
  if (.not. this_u(iu)) cycle
  u => s%u(iu)

  select case (switch)
  case ('beginning')
    call tao_locate_elements (value_str, u%ix_uni, eles, err, multiple_eles_is_err = .true.)
    ele => eles(1)%ele
    beam => u%uni_branch(ele%ix_branch)%ele(ele%ix_ele)%beam
    if (.not. allocated(beam%bunch)) then
      call out_io (s_error$, r_name, 'BEAM NOT SAVED AT: ' // who, 'NOTHING DONE.')
      err = .true.
      return
    endif
    u%beam%beam_at_start = beam
    u%calc%lattice = .true.

  case ('track_start', 'beam_track_start')
    call set_this_track(u%beam%track_start, u%beam%ix_track_start)

  case ('track_end', 'beam_track_end')
    call set_this_track(u%beam%track_end, u%beam%ix_track_end)

  case ('all_file', 'beam_all_file')
    u%beam%all_file = value_str

  case ('beam_init_file_name')
    call out_io (s_warn$, r_name, 'Note: "beam_init_file_name" has been renamed to "beam_init_position_file".')
    u%beam%beam_init%position_file = value_str
    u%beam%init_starting_distribution = .true.

  case ('beam_init_position_file')
    u%beam%beam_init%position_file = value_str
    u%beam%init_starting_distribution = .true.

  case ('saved_at', 'beam_saved_at')
    call tao_locate_elements (value_str, u%ix_uni, eles, err)
    if (err) then
      call out_io (s_error$, r_name, 'BAD BEAM_SAVED_AT STRING: ' // value_str)
      return
    endif
    u%beam%saved_at = value_str

    do ix = 0, ubound(u%uni_branch, 1)
      u%uni_branch(ix)%ele(:)%save_beam = .false.
    enddo

    ! Note: Beam will automatically be saved at fork elements and at the ends of the beam tracking.
    do ix = 1, size(eles)
      ele => eles(ix)%ele
      u%uni_branch(ele%ix_branch)%ele(ele%ix_ele)%save_beam = .true.
    enddo

  case ('add_saved_at', 'subtract_saved_at')
    call tao_locate_elements (value_str, u%ix_uni, eles, err)
    if (err) then
      call out_io (s_error$, r_name, 'BAD BEAM_SAVED_AT STRING: ' // value_str)
      return
    endif

    logic = (switch == 'add_saved_at')
    do ix = 1, size(eles)
      ele => eles(ix)%ele
      u%uni_branch(ele%ix_branch)%ele(ele%ix_ele)%save_beam = logic
    enddo

  case default
    call out_io (s_fatal$, r_name, 'PARAMETER NOT RECOGNIZED: ' // who2)
    return
  end select
enddo

!-------------------------------------------------------------
contains

subroutine set_this_track (track_ele, ix_track_ele)

type (ele_pointer_struct), allocatable, save, target :: eles(:)
integer ix_track_ele, n_loc
character(*) track_ele

!

call lat_ele_locator (value_str, u%design%lat, eles, n_loc, err)
if (err .or. n_loc == 0) then
  call out_io (s_fatal$, r_name, 'ELEMENT NOT FOUND: ' // value_str)
  call err_exit
endif
if (n_loc > 1) then
  call out_io (s_fatal$, r_name, 'MULTIPLE ELEMENTS FOUND: ' // value_str)
  call err_exit
endif

track_ele = value_str
ix_track_ele = eles(1)%ele%ix_ele

end subroutine set_this_track

end subroutine tao_set_beam_cmd 

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_particle_start_cmd (who, value_str)
!
! Routine to set particle_start variables.
! 
! Input:
!   who       -- Character(*): which particle_start variable to set
!   value_str -- Character(*): Value to set to.
!
! Output:
!    s%particle_start  -- Beam_start variables structure.
!-

subroutine tao_set_particle_start_cmd (who, value_str)

type (tao_universe_struct), pointer :: u
type (all_pointer_struct), allocatable :: a_ptr(:)
type (tao_d2_data_array_struct), allocatable :: d2_array(:)
type (tao_expression_info_struct), allocatable :: info(:)

real(rp), allocatable :: set_val(:)

integer ix, iu

character(*) who, value_str
character(40) who2, name

character(*), parameter :: r_name = 'tao_set_particle_start_cmd'

logical, allocatable :: this_u(:)
logical err, free

! Find set_val

call tao_evaluate_expression (value_str, 1, .false., set_val, info, err); if (err) return

!

call tao_pick_universe (who, who2, this_u, err); if (err) return
call string_trim (upcase(who2), who2, ix)

do iu = lbound(s%u, 1), ubound(s%u, 1)
  if (.not. this_u(iu)) cycle
  u => s%u(iu)

  call pointers_to_attribute (u%model%lat, 'PARTICLE_START', who2, .true., a_ptr, err, .true.)
  if (err) return

  if (u%model%lat%param%geometry == closed$) then
    free = .false.
    write (name, '(i0, a)') iu, '@multi_turn_orbit'
    call tao_find_data (err, name, d2_array, print_err = .false.)
    if (size(d2_array) > 0) free = .true.
    if (who2 == 'PZ' .and. .not. s%global%rf_on) free = .true.
    if (.not. free) then
      call out_io (s_error$, r_name, 'ATTRIBUTE NOT FREE TO VARY. NOTHING DONE.')
      return
    endif
  endif

  ! Set value

  a_ptr(1)%r = set_val(1)
  call tao_set_flags_for_changed_attribute (u, 'PARTICLE_START')
enddo

end subroutine tao_set_particle_start_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_beam_init_cmd (who, value_str)
!
! Routine to set beam_init variables
! 
! Input:
!   who       -- Character(*): which beam_init variable to set
!   value_str -- Character(*): Value to set to.
!
! Output:
!    s%beam_init  -- Beam_init variables structure.
!-

subroutine tao_set_beam_init_cmd (who, value_str)

implicit none

type (beam_init_struct) beam_init
type (tao_universe_struct), pointer :: u
type (ele_pointer_struct), allocatable :: eles(:)
type (ele_struct), pointer :: ele

character(*) who, value_str
character(40) who2
character(*), parameter :: r_name = 'tao_set_beam_init_cmd'

integer i, iu, ios, ib, n_loc
logical err
logical, allocatable :: picked_uni(:)
character(40) name

namelist / params / beam_init

! get universe

call tao_pick_universe (who, who2, picked_uni, err)

! Special cases not associated with the beam_init structure

select case (who2)
case ('beam_track_start', 'beam_track_end')
  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (.not. picked_uni(i)) cycle
    u => s%u(i)
    call lat_ele_locator (value_str, u%design%lat, eles, n_loc, err)
    if (err .or. n_loc == 0) then
      call out_io (s_fatal$, r_name, 'ELEMENT NOT FOUND: ' // value_str)
      return
    endif
    if (n_loc > 1) then
      call out_io (s_fatal$, r_name, 'MULTIPLE ELEMENTS FOUND FOR: ' // value_str)
      return
    endif
    ele => eles(1)%ele

    select case (who2)
    case ('beam_track_start')
      u%beam%track_start = value_str
      u%beam%ix_track_start = ele%ix_ele
    case ('beam_track_end')
      u%beam%track_end = value_str
      u%beam%ix_track_end = ele%ix_ele
    end select
  enddo

  return
end select

! open a scratch file for a namelist read

if (who2 == 'sig_e') who2 = 'sig_pz'
iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
write (iu, '(a)') ' beam_init%' // trim(who2) // ' = ' // trim(value_str)
write (iu, '(a)') '/'

!

do i = lbound(s%u, 1), ubound(s%u, 1)
  if (.not. picked_uni(i)) cycle

  rewind (iu)
  u => s%u(i)
  beam_init = u%beam%beam_init  ! set defaults
  read (iu, nml = params, iostat = ios)

  call tao_data_check (err)
  if (err) exit

  if (ios == 0) then
    u%beam%beam_init = beam_init
    u%beam%init_starting_distribution = .true.  ! Force reinit
    if (u%beam%beam_init%use_particle_start_for_center) u%beam%beam_init%center = u%model%lat%particle_start%vec
    u%calc%lattice = .true.
  else
    call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
    exit
  endif

enddo

close (iu, status = 'delete') 
deallocate (picked_uni)

end subroutine tao_set_beam_init_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
! Subroutine tao_set_plot_page_cmd (component, value_str, value_str2)
!
!  Set various aspects of the plotting window
!
! Input:
!   component     -- Character(*): Which component to set.
!   value_str     -- Character(*): What value to set to.
!   value_str2    -- Character(*): 2nd value if component is an array.
!
!  Output:
!    s%plot       -- tao_plotting_struct:
!-

subroutine tao_set_plot_page_cmd (component, value_str, value_str2)

use tao_input_struct, only: tao_plot_page_input, tao_set_plotting

implicit none

type (tao_plot_page_input) plot_page

character(*) component, value_str
character(*), optional :: value_str2
character(24) :: r_name = 'tao_set_plot_page_cmd'

real(rp) x, y
integer iu, ios
logical err


namelist / params / plot_page

! Special cases

select case (component)

case ('title')
  s%plot_page%title(1)%string = trim(value_str)
  return

case ('subtitle')
  s%plot_page%title(2)%string = trim(value_str)
  s%plot_page%title(2)%draw_it = .true.
  return

case ('subtitle_loc')

  if (.not. present(value_str2)) then
    call out_io(s_info$, r_name, "subtitle_loc requires two numbers.")
    return
  endif

  read(value_str, '(f15.10)') x
  read(value_str2, '(f15.10)') y
  s%plot_page%title(2)%x = x
  s%plot_page%title(2)%y = y
  return

end select

! For everything else...
! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
write (iu, '(a)') ' plot_page%' // trim(component) // ' = ' // trim(value_str)
write (iu, '(a)') '/'
rewind (iu)

call tao_set_plotting (plot_page, s%plot_page, .false., .true.)

read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
  return
endif

call tao_set_plotting (plot_page, s%plot_page, .false.)

end subroutine tao_set_plot_page_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_curve_cmd (curve_name, component, value_str)
!
! Routine to set var values.
!
! Input:
!   curve_name -- Character(*): Which curve to set.
!   component  -- Character(*): Which component to set.
!   value_str  -- Character(*): What value to set it to.
!-

subroutine tao_set_curve_cmd (curve_name, component, value_str)

implicit none

type (tao_curve_array_struct), allocatable, save :: curve(:)
type (tao_graph_array_struct), allocatable, save :: graph(:)
type (lat_struct), pointer :: lat

integer i, j, ios, i_uni
integer, allocatable, save :: ix_ele(:)

character(*) curve_name, component, value_str
character(20) :: r_name = 'tao_set_curve_cmd'

logical err

!

call tao_find_plots (err, curve_name, 'BOTH', curve = curve, always_allocate = .true.)
if (err) return

if (.not. allocated(curve) .or. size(curve) == 0) then
  call out_io (s_error$, r_name, 'CURVE OR GRAPH NOT SPECIFIED')
  return
else
  do i = 1, size(curve)
    call set_this_curve (curve(i)%c)
  enddo
endif

!---------------------------------------------
contains

subroutine set_this_curve (this_curve)

type (tao_curve_struct) this_curve
type (tao_graph_struct), pointer :: this_graph
type (tao_universe_struct), pointer :: u
type (tao_universe_branch_struct), pointer :: uni_branch
type (ele_pointer_struct), allocatable :: eles(:)

integer ix, i_branch
logical err
character(40) name, comp

!

i_branch = this_curve%ix_branch
i_uni = tao_universe_number(tao_curve_ix_uni(this_curve))

this_graph => this_curve%g

! if the universe is changed then need to check ele_ref

comp = component
ix = index(comp, '.')
if (ix /= 0) comp(ix:ix) = '%'
select case (comp)

case ('ele_ref_name')
  call tao_locate_elements (value_str, i_uni, eles, err, ignore_blank = .true.)
  if (size(eles) == 0) return
  this_curve%ele_ref_name = upcase(value_str)
  this_curve%ix_ele_ref = eles(1)%ele%ix_ele
  this_curve%ix_branch  = eles(1)%ele%ix_branch
  call tao_ele_to_ele_track (i_uni, i_branch, this_curve%ix_ele_ref, this_curve%ix_ele_ref_track)

case ('name')
  this_curve%name = value_str
  
case ('ix_ele_ref')
  call tao_set_integer_value (this_curve%ix_ele_ref, component, &
                    value_str, err, 0, s%u(i_uni)%model%lat%branch(i_branch)%n_ele_max)
  this_curve%ele_ref_name = s%u(i_uni)%model%lat%ele(this_curve%ix_ele_ref)%name
  call tao_ele_to_ele_track (tao_curve_ix_uni(this_curve), i_branch, &
                                this_curve%ix_ele_ref, this_curve%ix_ele_ref_track)

case ('ix_universe')
  call tao_set_integer_value (this_curve%ix_universe, component, value_str, err, -2, ubound(s%u, 1))
  if (err) return
  call tao_locate_elements (this_curve%ele_ref_name, tao_curve_ix_uni(this_curve), eles, err, ignore_blank = .true.)
  if (size(eles) == 0) return
  this_curve%ix_ele_ref = eles(1)%ele%ix_ele
  this_curve%ix_branch  = eles(1)%ele%ix_branch
  call tao_ele_to_ele_track (tao_curve_ix_uni(this_curve), this_curve%ix_branch, &
                                     this_curve%ix_ele_ref, this_curve%ix_ele_ref_track)

case ('ix_branch') 
  call tao_set_integer_value (this_curve%ix_branch, component, value_str, err, 0, ubound(s%u(i_uni)%model%lat%branch, 1))

case ('ix_bunch')
  u => tao_pointer_to_universe (tao_curve_ix_uni(this_curve))
  if (.not. associated(u)) return
  call tao_set_integer_value (this_curve%ix_bunch, component, value_str, err, 0, u%beam%beam_init%n_bunch)

case ('symbol_every')
  call tao_set_integer_value (this_curve%symbol_every, component, value_str, err, 0, 1000000)

case ('symbol_size')
  call tao_set_real_value (this_curve%symbol%height, component, value_str, err)

case ('symbol_color', 'symbol%color')
  call tao_set_switch_value (ix, component, value_str, qp_color_name, lbound(qp_color_name,1), err, this_curve%symbol%color)

case ('symbol_type', 'symbol%type')
  call tao_set_switch_value (ix, component, value_str, qp_symbol_type_name, lbound(qp_symbol_type_name,1), err, this_curve%symbol%type)

case ('symbol_fill_pattern', 'symbol%fill_pattern')
  call tao_set_switch_value (ix, component, value_str, qp_symbol_fill_pattern_name, &
                                                              lbound(qp_symbol_fill_pattern_name,1), err, this_curve%symbol%fill_pattern)

case ('symbol_height', 'symbol%height')
  call tao_set_real_value (this_curve%symbol%height, component, value_str, err)

case ('symbol_line_width', 'symbol%line_width')
  call tao_set_integer_value (this_curve%symbol%line_width, component, value_str, err)

case ('smooth_line_calc')
  call tao_set_logical_value (this_curve%smooth_line_calc, component, value_str, err)

case ('line_color', 'line%color')
  call tao_set_switch_value (ix, component, value_str, qp_color_name, lbound(qp_color_name,1), err, this_curve%line%color)

case ('line_width', 'line%width')
  call tao_set_integer_value (this_curve%line%width, component, value_str, err)

case ('line_pattern', 'line%pattern')
  call tao_set_switch_value (ix, component, value_str, qp_line_pattern_name, lbound(qp_line_pattern_name,1), err, this_curve%line%pattern)

case ('component')
  this_curve%component = remove_quotes(value_str)

case ('draw_line')
  call tao_set_logical_value (this_curve%draw_line, component, value_str, err)

case ('draw_symbols')
  call tao_set_logical_value (this_curve%draw_symbols, component, value_str, err)

case ('draw_symbol_index')
  call tao_set_logical_value (this_curve%draw_symbol_index, component, value_str, err)

case ('use_y2')
  call tao_set_logical_value (this_curve%use_y2, component, value_str, err)

case ('use_z_color')
  call tao_set_logical_value (this_curve%use_z_color, component, value_str, err)
  
case ('autoscale_z_color')
  call tao_set_logical_value (this_curve%autoscale_z_color, component, value_str, err)  

case ('data_source')
  this_curve%data_source = value_str

case ('data_index')
  this_curve%data_index = value_str

case ('data_type')
  this_curve%data_type = value_str

case ('data_type_x')
  this_curve%data_type_x = value_str

case ('data_type_z')
  this_curve%data_type_z = value_str

case ('legend_text')
  this_curve%legend_text = value_str

case ('units')
  this_curve%units = value_str

case ('z_color0')
  call tao_set_real_value (this_curve%z_color0, component, value_str, err, dflt_uni = i_uni)

case ('z_color1')
  call tao_set_real_value (this_curve%z_color1, component, value_str, err, dflt_uni = i_uni) 

case ('hist%number')
  this_curve%hist%width = 0
  call tao_set_integer_value (this_curve%hist%number, component, value_str, err, min_val = 0)

case ('hist%density_normalized')
  call tao_set_logical_value (this_curve%hist%density_normalized, component, value_str, err)
  
case ('hist%weight_by_charge')
  call tao_set_logical_value (this_curve%hist%weight_by_charge, component, value_str, err)
  
case ('hist%center')  
  call tao_set_real_value (this_curve%hist%center, component, value_str, err, dflt_uni = i_uni)
  
case ('hist%width')  
  this_curve%hist%number = 0
  call tao_set_real_value (this_curve%hist%width, component, value_str, err, dflt_uni = i_uni)  
  
case ('y_axis_scale_factor')
  call tao_set_real_value (this_curve%y_axis_scale_factor, component, value_str, err, dflt_uni = i_uni)

case default
  call out_io (s_error$, r_name, "BAD CURVE COMPONENT")
  return

end select

! Set ix_ele_ref_track if necessary

select case (component)
case ('ele_ref_name', 'ix_ele_ref', 'ix_universe')

end select

! Enable

if (this_graph%type == 'phase_space') then
  uni_branch => s%u(i_uni)%uni_branch(i_branch)
  if (.not. uni_branch%ele(this_curve%ix_ele_ref)%save_beam) then
    s%u(i_uni)%calc%lattice = .true.
    uni_branch%ele(this_curve%ix_ele_ref)%save_beam = .true.
  endif
endif

end subroutine set_this_curve

end subroutine tao_set_curve_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_plot_cmd (plot_name, component, value_str)
!
! Routine to set var values.
!
! Input:
!   plot_name --  Character(*): Which plot to set.
!   component  -- Character(*): Which component to set.
!   value_str  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_plot_cmd (plot_name, component, value_str)

implicit none

type (tao_plot_array_struct), allocatable, save :: plot(:)
type (tao_universe_struct), pointer :: u

character(*) plot_name, component, value_str
character(40) comp, sub_comp
character(*), parameter :: r_name = 'tao_set_plot_cmd'

integer iset, iw, iu
integer i, j, ix, ios
logical err_flag, found

!

call tao_find_plots (err_flag, plot_name, 'BOTH', plot = plot)
if (err_flag) return

if (.not. allocated(plot)) then
  call out_io (s_error$, r_name, 'PLOT OR PLOT NOT SPECIFIED')
  return
endif

! And set

comp = component
ix = index(component, '%')
if (ix /= 0) then
  comp = component(:ix-1)
  sub_comp = component(ix+1:)
endif

found = .false.

do i = 1, size(plot)

  select case (comp)

    case ('autoscale_x')
      call tao_set_logical_value (plot(i)%p%autoscale_x, component, value_str, err_flag)

    case ('autoscale_y')
      call tao_set_logical_value (plot(i)%p%autoscale_y, component, value_str, err_flag)

    case ('autoscale_gang_x')
      call tao_set_logical_value (plot(i)%p%autoscale_gang_x, component, value_str, err_flag)

    case ('autoscale_gang_y')
      call tao_set_logical_value (plot(i)%p%autoscale_gang_y, component, value_str, err_flag)

    case ('description')
      plot(i)%p%description = value_str

    case ('component')
      do j = 1, size(plot(i)%p%graph)
        plot(i)%p%graph(j)%component = remove_quotes(value_str)
      enddo

    case ('n_curve_pts')
      call tao_set_integer_value (plot(i)%p%n_curve_pts, component, value_str, err_flag)

    case ('name')
      plot(i)%p%name = value_str

    case ('visible')
      if (.not. associated(plot(i)%p%r)) cycle
      call tao_set_logical_value (plot(i)%p%r%visible, component, value_str, err_flag)
      call tao_turn_on_special_calcs_if_needed_for_plotting()
      found = .true.

    case ('x')
      call tao_set_qp_axis_struct('x', sub_comp, plot(i)%p%x, value_str, err_flag)
      if (allocated(plot(i)%p%graph)) then
        do j = 1, size(plot(i)%p%graph)
          plot(i)%p%graph(i)%x = plot(i)%p%x
        enddo
      endif

    case ('x_axis_type')
      call tao_set_switch_value (ix, component, value_str, x_axis_type_name, lbound(x_axis_type_name,1), err_flag)
      if (.not. err_flag) plot(i)%p%x_axis_type = x_axis_type_name(ix)

    case default
      call out_io (s_error$, r_name, "BAD PLOT COMPONENT: " // component)
      return
      
  end select

enddo

!

if (comp == 'visible' .and. .not. found) then
  call out_io (s_error$, r_name, 'NO PLOT ASSOCIATED WITH: ' // plot_name)
endif

end subroutine tao_set_plot_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_graph_cmd (graph_name, component, value_str)
!
! Routine to set var values.
!
! Input:
!   graph_name -- Character(*): Which graph to set.
!   component  -- Character(*): Which component to set.
!   value_str  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_graph_cmd (graph_name, component, value_str)

implicit none

type (tao_plot_array_struct), allocatable, save :: plot(:)
type (tao_graph_array_struct), allocatable, save :: graph(:)

character(*) graph_name, component, value_str
character(20) :: r_name = 'tao_set_graph_cmd'

integer i, j, ios
logical err

! 'BOTH' was 'REGION'. Not sure why.

call tao_find_plots (err, graph_name, 'BOTH', plot = plot, graph = graph)
if (err) return

if (allocated(graph)) then
  do i = 1, size(graph)
    call set_this_graph (graph(i)%g)
  enddo
elseif (allocated(plot)) then
  do i = 1, size(plot)
    do j = 1, size(plot(i)%p%graph)
      call set_this_graph (plot(i)%p%graph(j))
    enddo
  enddo
else
  call out_io (s_error$, r_name, 'GRAPH OR PLOT NOT SPECIFIED')
  return
endif

!---------------------------------------------
contains

subroutine set_this_graph (this_graph)

type (tao_graph_struct) this_graph
type (tao_universe_struct), pointer :: u
character(40) comp, sub_comp
character(200) value
integer iset, iw, ix
logical logic, error

!

value = remove_quotes(value_str)

comp = component
ix = max(index(comp, '%'), index(comp, '.'))
if (ix /= 0) then
  sub_comp = comp(ix+1:)
  comp = comp(:ix-1)
endif

u => tao_pointer_to_universe(this_graph%ix_universe)

select case (comp)

case ('component')
  this_graph%component = value_str
case ('clip')
  call tao_set_logical_value (this_graph%clip, component, value, error)
case ('correct_xy_distortion')
  call tao_set_logical_value(this_graph%correct_xy_distortion, component, value, error)
case ('curve_legend_origin')
  call tao_set_qp_point_struct (comp, sub_comp, this_graph%curve_legend_origin, value, error, u%ix_uni)
case ('draw_axes')
  call tao_set_logical_value (this_graph%draw_axes, component, value, error)
case ('draw_grid')
  call tao_set_logical_value (this_graph%draw_grid, component, value, error)
case ('draw_only_good_user_data_or_vars')
  call tao_set_logical_value (this_graph%draw_only_good_user_data_or_vars, component, value, error)
case ('floor_plan_size_is_absolute')
  call tao_set_logical_value(this_graph%floor_plan_size_is_absolute, component, value, error)
case ('floor_plan_draw_only_first_pass')
  call tao_set_logical_value(this_graph%floor_plan_draw_only_first_pass, component, value, error)
case ('floor_plan_flip_label_side')
  call tao_set_logical_value(this_graph%floor_plan_flip_label_side, component, value, error)
case ('floor_plan_rotation')
  call tao_set_real_value(this_graph%floor_plan_rotation, component, value, error, dflt_uni = u%ix_uni)
case ('floor_plan_orbit_scale')
  call tao_set_real_value(this_graph%floor_plan_orbit_scale, component, value, error, dflt_uni = u%ix_uni)
case ('floor_plan_orbit_color')
  this_graph%floor_plan_orbit_color = value
case ('floor_plan_view')
  if (.not. any(value == floor_plan_view_name)) then
    call out_io(s_info$, r_name, "Valid floor_plan_view settings are: 'xy', 'zx', etc.")
    return
  endif
  this_graph%floor_plan_view = value
case ('ix_universe')
  call tao_set_integer_value (this_graph%ix_universe, component, value, error, -2, ubound(s%u, 1))
case ('ix_branch')
  call tao_set_integer_value (this_graph%ix_branch, component, value, error, 0, ubound(u%model%lat%branch, 1))
case ('margin')
  call tao_set_qp_rect_struct (comp, sub_comp, this_graph%margin, value, error, u%ix_uni)
case ('name')
  this_graph%name = value_str
case ('scale_margin')
  call tao_set_qp_rect_struct (comp, sub_comp, this_graph%scale_margin, value, error, u%ix_uni)
case ('x')
  call tao_set_qp_axis_struct (comp, sub_comp, this_graph%x, value, error, u%ix_uni)
case ('y')
  call tao_set_qp_axis_struct (comp, sub_comp, this_graph%y, value, error, u%ix_uni)
case ('x2')
  call tao_set_qp_axis_struct (comp, sub_comp, this_graph%x2, value, error, u%ix_uni)
case ('y2')
  call tao_set_qp_axis_struct (comp, sub_comp, this_graph%y2, value, error, u%ix_uni)
case ('x_axis_scale_factor')
  call tao_set_real_value(this_graph%x_axis_scale_factor, component, value, error, dflt_uni = u%ix_uni)
case ('text_legend_origin')
  call tao_set_qp_point_struct (comp, sub_comp, this_graph%text_legend_origin, value, error, u%ix_uni)
case ('symbol_size_scale')
  call tao_set_real_value(this_graph%symbol_size_scale, component, value, error, dflt_uni = u%ix_uni)
case ('title')
  this_graph%title = value
case ('type')
  this_graph%type = value
case ('y2_mirrors_y')
  call tao_set_logical_value (this_graph%y2_mirrors_y, component, value, error)

case default
  call out_io (s_error$, r_name, "BAD GRAPH COMPONENT: " // component)
  return
end select

u%calc%lattice = .true.

end subroutine set_this_graph

end subroutine tao_set_graph_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_var_cmd (var_str, value_str)
!
! Routine to set var values.
!
! Input:
!   var_str  -- Character(*): Which var name to set.
!   value_str  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_var_cmd (var_str, value_str)

implicit none

type (tao_v1_var_struct), pointer :: v1_ptr
type (tao_real_pointer_struct), allocatable, save    :: r_var(:), r_set(:)
type (tao_logical_array_struct), allocatable, save :: l_var(:), l_set(:)
type (tao_var_array_struct), allocatable, save, target :: v_var(:)
type (tao_string_array_struct), allocatable, save :: s_var(:), s_set(:)
type (tao_expression_info_struct), allocatable, save :: info(:)
type (tao_universe_struct), pointer :: u
type (ele_pointer_struct), allocatable :: eles(:)
type (all_pointer_struct) a_ptr
type (tao_var_struct), pointer :: v_ptr

real(rp), allocatable, save :: r_value(:)
real(rp) value

integer i, j, ix, np, n_loc
integer, allocatable :: u_pick(:)

character(*) var_str, value_str
character(*), parameter :: r_name = 'tao_set_var_cmd'
character(20) set_is, component
character(40) ele_name, attrib_name
character(len(value_str)) val

logical err, l_value, err_flag

! Decode variable component to set.

call tao_find_var (err, var_str, v_array = v_var, re_array=r_var, log_array=l_var, &
                                                 str_array = s_var, component = component)
if (err) return

select case (component)
case ('base')
  call out_io (s_error$, r_name, &
        'VARIABLES IN THE BASE LATTICE ARE NOT ALLOWED TO BE SET DIRECTLY SINCE DEPENDENT', &
        'PARAMETERS (LIKE THE TWISS PARAMETERS) IN THE BASE LATTICE ARE NEVER COMPUTED.', &
        'USE THE "SET LATTICE BASE = ..." COMMAND INSTEAD.')
  return

case ('ele_name', 'attrib_name', 'model', 'design', 'old', 'model_value', 'base_value', &
      'design_value', 'old_value', 'merit', 'delta_merit', 'exists', 'good_var', 'useit_opt', &
      'useit_plot')
  call out_io (s_error$, r_name, 'VARIABLE ATTRIBUTE NOT SETTABLE: ' // component)
  return
end select

! A logical value_str is either a logical or an array of datum values.

if (size(l_var) > 0) then
  if (is_logical(value_str)) then
    read (value_str, *) l_value
    do i = 1, size(l_var)
      l_var(i)%l = l_value
    enddo

  else
    call tao_find_var (err, value_str, log_array=l_set)
    if (size(l_set) /= size(l_var)) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif
    do i = 1, size(l_var)
      l_var(i)%l = l_set(i)%l
    enddo
  endif

! A string set
! If value_str has "|" then it must be a datum array

elseif (size(s_var) /= 0) then
  if (index(var_str, '|merit_type') /= 0) then
    if (index(value_str, '|') == 0) then
      if (all (value_str /= var_merit_type_name)) then
        call out_io (s_error$, r_name, 'BAD VARIABLE MERIT_TYPE NAME:' // value_str)
        return
      endif
      do i = 1, size(s_var)
        s_var(i)%s = value_str
      enddo

    else
      call tao_find_var (err, value_str, str_array=s_set)
      if (size(l_set) /= size(l_var)) then
        call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
        return
      endif
      do i = 1, size(s_var)
        s_var(i)%s = s_set(i)%s
      enddo
    endif
  endif

! Only possibility left is real. The value_str might be a number or it might 
! be a mathematical expression involving datum values or array of values.

elseif (size(r_var) /= 0) then
  call tao_evaluate_expression (value_str, size(r_var),  .false., r_value, info, err, dflt_source = 'var')
  if (err) then
    call out_io (s_error$, r_name, 'BAD SET VALUE ' // value_str)
    return
  endif

  do i = 1, size(r_var)
    if (component == 'model') then
      call tao_set_var_model_value (v_var(i)%v, r_value(i))
    else
      r_var(i)%r = r_value(i)
    endif
  enddo

! Else must be an error

else
  call out_io (s_error$, r_name, 'NOTHING TO SET!')
  return

endif

call tao_set_var_useit_opt()
call tao_setup_key_table ()

end subroutine tao_set_var_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_branch_cmd (branch_str, component_str, value_str)
!
! Routine to set lattice branch values.
!
! Input:
!   branch_str      -- character(*): Which branch to set.
!   component_str   -- character(*): Which branch parameter to set.
!   value_str       -- character(*): What value to set it to.
!-

subroutine tao_set_branch_cmd (branch_str, component_str, value_str)

implicit none

integer i
logical, allocatable :: this_u(:)
logical err

character(*) branch_str, component_str, value_str
character(*), parameter :: r_name = 'tao_set_branch_cmd'
character(40) b_str

!

call tao_pick_universe (branch_str, b_str, this_u, err)
if (err) return

do i = lbound(s%u, 1), ubound(s%u, 1)
  if (.not. this_u(i)) cycle
  call set_this_branch(s%u(i), err)
  s%u(i)%calc%lattice = .true.
  if (err) return
enddo

!--------------------------------------------
contains

subroutine set_this_branch(u, err)

type (tao_universe_struct), target :: u
type (branch_struct), pointer :: branch
integer ix
logical err
character(40) c_str

!

err = .true.

branch => pointer_to_branch(b_str, u%model%lat)
if (.not. associated(branch)) then
  call out_io (s_error$, r_name, 'BAD BRANCH NAME OR INDEX: ' // b_str)
  return
endif

!

call match_word (component_str, [character(28):: 'particle', 'default_tracking_species', 'geometry', 'live_branch'], &
                                                                                                    ix, matched_name = c_str)
if (ix < 1) THEN
  call out_io (s_error$, r_name, 'BAD BRANCH COMPONENT NAME: ' // component_str)
  return
endif

select case (c_str)
case ('particle')
  ix = species_id(value_str)
  if (ix == invalid$ .or. ix == ref_particle$ .or. ix == anti_ref_particle$) then
    call out_io (s_error$, r_name, 'INVALID REFERENCE PARTICLE SPECIES: ' // value_str)
    return
  endif
  branch%param%particle = ix

case ('default_tracking_species')
  ix = species_id(value_str)
  if (ix == invalid$) then
    call out_io (s_error$, r_name, 'INVALID DEFAULT TRACKING SPECIES: ' // value_str)
    return
  endif
  branch%param%default_tracking_species = ix

case ('geometry')
  call tao_set_switch_value (ix, c_str, value_str, geometry_name(1:), 1, err)
  if (err) return
  branch%param%geometry = ix

case ('live_branch')
  call tao_set_logical_value (branch%param%live_branch, c_str, value_str, err)
  if (err) return

end select

err = .false.

end subroutine set_this_branch

end subroutine tao_set_branch_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_data_cmd (who_str, value_str)
!
! Routine to set data values.
!
! Input:
!   who_str   -- Character(*): Which data component(s) to set.
!   value_str -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_data_cmd (who_str, value_str)

implicit none

type (tao_data_array_struct), allocatable    :: d_dat(:)
type (tao_real_pointer_struct), allocatable  :: r_dat(:)
type (tao_integer_array_struct), allocatable :: int_dat(:), int_value(:)
type (tao_logical_array_struct), allocatable :: l_dat(:), l_value(:)
type (tao_string_array_struct), allocatable :: s_dat(:), s_value(:)
type (tao_universe_struct), pointer :: u
type (tao_data_struct), pointer :: d
type (branch_struct), pointer :: branch
type (ele_pointer_struct), allocatable :: eles(:)
type (tao_expression_info_struct), allocatable :: info(:)

real(rp), allocatable :: r_value(:)

integer i, ix, i1, n_loc, ib, ie
integer, allocatable :: int_save(:)

character(*) who_str, value_str
character(20) component
character(20) :: r_name = 'tao_set_data_cmd'
character(200) :: tmpstr, why_invalid
character, allocatable :: s_save(:)

logical err, l1


! Decode data component to set.

call tao_find_data (err, who_str, d_array = d_dat, re_array=r_dat, &
          log_array=l_dat, str_array = s_dat, int_array = int_dat, component = component)
if (err) return

select case (component)
  case ('model', 'base', 'design', 'old', 'model_value', 'base_value', 'design_value', &
             'old_value', 'invalid', 'delta_merit', 'merit', 'exists', 'good_base ', &
             'useit_opt ', 'useit_plot', 'ix_ele', 'ix_ele_start', 'ix_ele_ref', 'ix_d1', &
             'ix_uni', 'ele_name', 'ele_start_name', 'ele_ref_name', 'name')
  call out_io (s_error$, r_name, 'DATUM ATTRIBUTE NOT SETTABLE: ' // component)
  return
end select

!------------------------
! A logical value_str is either a logical or an array of datum values.

if (size(l_dat) /= 0) then
  if (is_logical(value_str)) then
    read (value_str, *) l1
    do i = 1, size(l_dat)
      l_dat(i)%l = l1
    enddo

  else
    call tao_find_data (err, value_str, log_array=l_value)
    if (size(l_value) /= size(l_dat) .and. size(l_value) /= 1) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif
    do i = 1, size(l_dat)
      if (size(l_value) == 1) then
        l_dat(i)%l = l_value(1)%l
      else
        l_dat(i)%l = l_value(i)%l
      endif
    enddo
  endif

!------------------------
! An integer value_str is either an integer or an array of datum values.

elseif (size(int_dat) /= 0) then

  allocate (int_save(size(int_dat)))  ! Used to save old values in case of error

  if (is_integer(value_str)) then
    read (value_str, *) i1
    do i = 1, size(int_dat)
      int_save(i) = int_dat(i)%i
      int_dat(i)%i = i1
    enddo

  elseif (component == 'eval_point' .and. index(value_str, '|') == 0) then
    call match_word (value_str, anchor_pt_name(1:), i1, can_abbreviate = .false.)
    if (i1 == 0) then
      call out_io (s_error$, r_name, 'eval_point setting is "beginning", "center", or "end".')
      return
    endif
    do i = 1, size(int_dat)
      int_save(i) = int_dat(i)%i
      int_dat(i)%i = i1
    enddo

  else
    call tao_find_data (err, value_str, int_array=int_value)
    if (size(int_value) /= size(int_dat) .and. size(int_dat) /= 1) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif
    do i = 1, size(int_dat)
      if (size(int_dat) == 1) then
        int_save(i) = int_dat(1)%i
        int_dat(i)%i = int_value(1)%i
      else
        int_save(i) = int_dat(i)%i
        int_dat(i)%i = int_value(i)%i
      endif
    enddo
  endif

  if (component == 'ix_ele' .or. component == 'ix_ele_start' .or. component == 'ix_ele_ref') then
    do i = 1, size(int_dat)
      u => s%u(d_dat(i)%d%d1%d2%ix_universe)
      branch => u%design%lat%branch(d_dat(i)%d%ix_branch)
      ie = int_dat(i)%i

      if (ie < 0 .or. ie > branch%n_ele_max) then
        int_dat(i)%i = int_save(i)
        call out_io (s_error$, r_name, 'ELEMENT INDEX OUT OF RANGE.')
        return
      endif

      if (component == 'ix_ele') then
        tmpstr = branch%ele(ie)%name
        d_dat(i)%d%ele_name = upcase(tmpstr)   ! Use temp due to bug on Windows
      elseif (component == 'ix_ele_start') then
        tmpstr = branch%ele(ie)%name
        d_dat(i)%d%ele_start_name = upcase(tmpstr)   ! Use temp due to bug on Windows
      else
        tmpstr = branch%ele(ie)%name
        d_dat(i)%d%ele_ref_name = upcase(tmpstr)   ! Use temp due to bug on Windows
      endif
    enddo

  elseif (component == 'ix_branch') then
    do i = 1, size(int_dat)
      u => s%u(d_dat(i)%d%d1%d2%ix_universe)
      ib = int_dat(i)%i
      if (ib < 0 .or. ib > ubound(u%design%lat%branch, 1)) then
        int_dat(i)%i = int_save(i)
        call out_io (s_error$, r_name, 'ELEMENT INDEX OUT OF RANGE.')
        return
      endif
      d_dat(i)%d%ele_name = ''
      d_dat(i)%d%ix_ele = -1
      d_dat(i)%d%ele_ref_name = ''
      d_dat(i)%d%ix_ele_ref = -1
      d_dat(i)%d%ele_start_name = ''
      d_dat(i)%d%ix_ele_start = -1
    enddo
  endif

!------------------------
! A string:

elseif (size(s_dat) /= 0) then

  allocate (s_save(size(s_dat)))  ! Used to save old values in case of error

  ! If value_string has "|" then it must be a datum array

  if (index(value_str, '|') /= 0) then
    call tao_find_data (err, value_str, str_array=s_value)
    if (size(s_value) /= size(s_dat) .and. size(s_value) /= 1) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif

    do i = 1, size(s_dat)
      tmpstr = s_value(i)%s
      s_save(i) = tmpstr
      s_dat(i)%s = tmpstr   ! Use temp due to bug on Windows
    enddo

  else
    if (component == 'merit_type' .and. all(value_str /= data_merit_type_name)) then
      call out_io (s_error$, r_name, 'BAD DATA MERIT_TYPE NAME:' // value_str)
      return
    endif

    do i = 1, size(s_dat)
      tmpstr = value_str
      s_save(i) = tmpstr
      s_dat(i)%s = tmpstr   ! Use temp due to bug on Windows
    enddo
  endif

  !

  if (component == 'ele_name' .or. component == 'ele_start_name' .or. component == 'ele_ref_name') then
    do i = 1, size(d_dat)
      u => s%u(d_dat(i)%d%d1%d2%ix_universe)
      call upcase_string (s_dat(i)%s)
      call lat_ele_locator (s_dat(i)%s, u%design%lat, eles, n_loc)

      if (n_loc == 0) then
        call out_io (s_error$, r_name, 'ELEMENT NOT LOCATED: ' // s_dat(i)%s)
        s_dat(i)%s = s_save(i)
        return
      endif

      if (n_loc > 1) then
        call out_io (s_error$, r_name, 'MULTIPLE ELEMENT OF THE SAME NAME EXIST: ' // s_dat(i)%s)
        s_dat(i)%s = s_save(i)
        return
      endif

      if (component == 'ele_name') then
        d_dat(i)%d%ix_ele    = eles(1)%ele%ix_ele
        if (d_dat(i)%d%ix_branch /= eles(1)%ele%ix_branch) then
          d_dat(i)%d%ele_ref_name = ''
          d_dat(i)%d%ix_ele_ref = -1
          d_dat(i)%d%ele_start_name = ''
          d_dat(i)%d%ix_ele_start = -1
        endif
        d_dat(i)%d%ix_branch = eles(1)%ele%ix_branch
      elseif (component == 'ele_start_name') then
        if (d_dat(i)%d%ix_branch /= eles(1)%ele%ix_branch) then
          s_dat(i)%s = s_save(i)
          call out_io (s_error$, r_name, 'START_ELEMENT IS IN DIFFERENT BRANCH FROM ELEMENT.')
          return
        endif
        d_dat(i)%d%ix_ele_start = eles(1)%ele%ix_ele
      else
        if (d_dat(i)%d%ix_branch /= eles(1)%ele%ix_branch) then
          s_dat(i)%s = s_save(i)
          call out_io (s_error$, r_name, 'REF_ELEMENT IS IN DIFFERENT BRANCH FROM ELEMENT.')
          return
        endif
        d_dat(i)%d%ix_ele_ref = eles(1)%ele%ix_ele
      endif
    enddo
  endif

!------------------------
! Only possibility left is real. The value_str might be a number or it might 
! be a mathematical expression involving datum values or array of values.

elseif (size(r_dat) /= 0) then
  call tao_evaluate_expression (value_str, size(r_dat), .false., r_value, info, err, dflt_source = 'data')
  if (err) then
    call out_io (s_error$, r_name, 'BAD SET VALUE ' // value_str)
    return
  endif

  do i = 1, size(r_dat)
    r_dat(i)%r = r_value(i)
    if (component == 'meas') d_dat(i)%d%good_meas = .true.
    if (component == 'ref')  d_dat(i)%d%good_ref = .true.
    if (component == 'base') d_dat(i)%d%good_base = .true.
  enddo

else
  call out_io (s_error$, r_name, 'LEFT HAND SIDE MUST POINT TO A SCALAR OR ARRAY OF DATA COMPONENTS.')
  return
endif

!----------------------
! If the "exists" component has been set (used by gui interface) check if the datum is truely valid.

if (component == 'exists') then
  do i = 1, size(d_dat)
    d => d_dat(i)%d
    if (.not. d%exists) cycle

    d%exists = tao_data_sanity_check(d, .true.)
    if (.not. d%exists) cycle

    u => s%u(d%d1%d2%ix_universe) 
    call tao_evaluate_a_datum (d, u, u%model, d%model_value, d%good_model, why_invalid)
    if (.not. d%good_model) then
      call out_io (s_error$, r_name, 'Datum is not valid since: ' // why_invalid)
    endif
    if (d%good_model) call tao_evaluate_a_datum (d, u, u%design, d%design_value, d%good_design, why_invalid)
  enddo
endif

! End stuff

call tao_set_data_useit_opt()

end subroutine tao_set_data_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_default_cmd (who_str, value_str)
!
! Routine to set default values.
!
! Input:
!   who_str   -- Character(*): Which default component(s) to set.
!   value_str -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_default_cmd (who_str, value_str)

implicit none

type (tao_universe_struct), pointer :: u
integer ix, iu
logical err

character(*) who_str, value_str
character(16) switch
character(*), parameter :: r_name = 'tao_set_default_cmd'
!

call match_word (who_str, ['universe', 'branch  '], ix, matched_name=switch)
if (ix < 1) then
  call out_io (s_error$, r_name, 'BAD DEFAULT NAME: ' // who_str)
  return
endif

select case (switch)
case ('universe')
  call tao_set_integer_value (s%com%default_universe, 'UNIVERSE', value_str, &
                                                                     err, lbound(s%u, 1), ubound(s%u, 1))
  if (err) return
  call tao_turn_on_special_calcs_if_needed_for_plotting()

case ('branch')
  u => tao_pointer_to_universe(-1)
  call tao_set_integer_value (s%com%default_branch, 'BRANCH', value_str, err, 0, ubound(u%model%lat%branch, 1))
  if (err) return

end select


end subroutine tao_set_default_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_universe_cmd (uni, who, what)
!
! Sets a universe on or off, or sets the recalculate or twiss_calc logicals, etc.
!
! Input:
!   uni     -- Character(*): which universe; 0 => current viewed universe
!   who     -- Character(*): "on", "off", "recalculate", "dynamic_aperture_calc", "one_turn_map_calc", or "twiss_calc"
!   what    -- Character(*): "on" or "off" for who = "dynamic_aperture_calc", "one_turn_map_calc" or "twiss_calc".
!-

subroutine tao_set_universe_cmd (uni, who, what)

implicit none

integer i, n_uni

character(*) uni, who, what
character(20) :: r_name = "tao_set_universe_cmd"

logical is_on, err, mat6_toggle


! Pick universe

if (uni /= '*') then
  call tao_to_int (uni, n_uni, err)
  if (err) return
  if (n_uni < -1 .or. n_uni > ubound(s%u, 1)) then
    call out_io (s_warn$, r_name, "Invalid Universe specifier")
    return 
  endif
  n_uni = tao_universe_number (n_uni)
endif

! Twiss calc.
! "mat6_recalc" is old style

if (index('twiss_calc', trim(who)) == 1 .or. index('mat6_recalc', trim(who)) == 1) then
  if (what == 'on') then
    is_on = .true.
  elseif (what == 'off') then
    is_on = .false.
  else
    call out_io (s_error$, r_name, 'Syntax is: "set universe <uni_num> twiss_calc on/off"')
    return
  endif
  if (uni == '*') then
    s%u(:)%calc%twiss = is_on
    if (is_on) s%u(:)%calc%lattice = .true.
  else
    s%u(n_uni)%calc%twiss = is_on
    if (is_on) s%u(n_uni)%calc%lattice = .true.
  endif
  return
endif

! Track calc
! "track_recalc" is old style.

if (index('track_calc', trim(who)) == 1 .or. index('track_recalc', trim(who)) == 1) then
  if (what == 'on') then
    is_on = .true.
  elseif (what == 'off') then
    is_on = .false.
  else
    call out_io (s_error$, r_name, 'Syntax is: "set universe <uni_num> track_calc on/off"')
    return
  endif

  if (uni == '*') then
    s%u(:)%calc%track = is_on
    if (is_on) s%u(:)%calc%lattice = .true.
  else
    s%u(n_uni)%calc%track = is_on
    if (is_on) s%u(n_uni)%calc%lattice = .true.
  endif
  return
endif

! Dynamic aperture calc.

if (index('dynamic_aperture_calc', trim(who)) == 1) then
  if (what == 'on') then
    is_on = .true.
  elseif (what == 'off') then
    is_on = .false.
  else
    call out_io (s_error$, r_name, 'Syntax is: "set universe <uni_num> dynamic_aperture_calc on/off"')
    return
  endif

  if (uni == '*') then
    s%u(:)%calc%dynamic_aperture = is_on
    if (is_on) s%u(:)%calc%lattice = .true.
  else
    s%u(n_uni)%calc%dynamic_aperture = is_on
    if (is_on) s%u(n_uni)%calc%lattice = .true.
  endif
  return
endif  

! One turn map calc.

if ('one_turn_map_calc' == trim(who)) then
  if (what == 'on') then
    is_on = .true.
  elseif (what == 'off') then
    is_on = .false.
  else
    call out_io (s_error$, r_name, 'Syntax is: "set universe <uni_num> one_turn_map_calc on/off"')
    return
  endif
  if (uni == '*') then
    s%u(:)%calc%one_turn_map = is_on
    if (is_on) s%u(:)%calc%lattice = .true.
  else
    s%u(n_uni)%calc%one_turn_map = is_on
    if (is_on) s%u(n_uni)%calc%lattice = .true.
  endif
  return
endif  
  
! Recalc.

if (what /= '') then
  call out_io (s_error$, r_name, 'Extra stuff on line. Nothing done.')
  return
endif

if (index('recalculate', trim(who)) == 1) then
  if (uni == '*') then
    s%u(:)%calc%lattice = .true.
  else
    s%u(n_uni)%calc%lattice = .true.
  endif
  return
endif

!

if (who == 'on') then
  is_on = .true.
elseif (who == 'off') then
  is_on = .false.
else
  call out_io (s_error$, r_name, "Choices are: 'on', 'off', 'recalculate', 'track_recalc', 'twiss_calc', etc.")
  return
endif

if (uni == '*') then
  call out_io (s_blank$, r_name, "Setting all universes to: " // on_off_logic(is_on))
  s%u(:)%is_on = is_on
else
  s%u(n_uni)%is_on = is_on
  call out_io (s_blank$, r_name, "Setting universe \i0\ to: " // on_off_logic(is_on), n_uni)
endif

call tao_set_data_useit_opt()
  
end subroutine tao_set_universe_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_elements_cmd (ele_list, attribute, value)
!
! Sets element parameters.
!
! Input:
!   ele_list   -- Character(*): which elements.
!   attribute  -- Character(*): Attribute to set.
!   value      -- Character(*): Value to set.
!-

subroutine tao_set_elements_cmd (ele_list, attribute, value)

use attribute_mod, only: attribute_type
use set_ele_attribute_mod, only: set_ele_attribute

implicit none

type (ele_pointer_struct), allocatable :: eles(:), v_eles(:)
type (tao_universe_struct), pointer :: u
type (all_pointer_struct) a_ptr
type (tao_expression_info_struct), allocatable :: info(:)
type (tao_lattice_struct), pointer :: tao_lat

real(rp), allocatable :: set_val(:)
integer i, j, ix, ix2, n_uni, n_set, n_eles, lat_type

character(*) ele_list, attribute, value
character(*), parameter :: r_name = "tao_set_elements_cmd"
character(100) val_str

logical is_on, err, mat6_toggle

! Find elements

call tao_locate_all_elements (ele_list, eles, err)
if (err) return
if (size(eles) == 0) then
  call out_io (s_error$, r_name, 'CANNOT FIND ANY ELEMENTS CORRESPONDING TO: ' // ele_list)
  return
endif

!-----------
! The first complication is that what is being set can be a logical, switch (like an element's tracking_method), etc.
! So use set_ele_attribute to do the set.
! But set_ele_attribute does not know about Tao syntax so it may have problems evaluateing the value string.
! And set_ele_attribute cannot handle the situation where there is an array of set values.
! How to handle this depends upon what type of attribute it is.

! If a real attribute then use tao_evaluate_expression to evaluate

if (attribute_type(upcase(attribute), eles(1)%ele) == is_real$) then
  ! Important to use "size(eles)" as 2nd arg instead of "0" since if value is something like "ran()" then
  ! want a an array of set_val values with each value different.
  call tao_evaluate_expression (value, size(eles), .false., set_val, info, err)
  if (err) return

  if (size(eles) /= size(set_val)) then
    call out_io (s_error$, r_name, 'SIZE OF VALUE ARRAY NOT EQUAL TO THE SIZE OF THE ELEMENTS TO BE SET.', &
                                   'NOTHING DONE.')
    return
  endif

  do i = 1, size(eles)
    call pointer_to_attribute(eles(i)%ele, attribute, .true., a_ptr, err)
    if (err) return
    if (.not. associated(a_ptr%r)) then
      call out_io (s_error$, r_name, 'STRANGE ERROR: PLEASE CONTACT HELP.')
      return
    endif
    a_ptr%r = set_val(i)
    call tao_set_flags_for_changed_attribute (s%u(eles(i)%id), eles(i)%ele%name, eles(i)%ele, a_ptr%r)
  enddo

  do i = lbound(s%u, 1), ubound(s%u, 1)
    u => s%u(i)
    if (.not. u%calc%lattice) cycle
    call lattice_bookkeeper (u%model%lat)
  enddo

  return

! If there is a "ele::" construct in the value string...

elseif (index(value, 'ele::') /= 0) then

  val_str = value
  u => tao_pointer_to_universe(val_str)

  if (val_str(1:5) /= 'ele::') then
    call out_io (s_error$, r_name, 'CANNOT PARSE SET VALUE: ' // value, &
                                   'PLEASE CONTACT BMAD MAINTAINER DAVID SAGAN.')
    return
  endif
  val_str = val_str(6:)

  lat_type = model$
  if (index(val_str, '|model') /= 0) then
    lat_type = model$
  elseif (index(val_str, '|design') /= 0) then
    lat_type = design$
  elseif (index(val_str, '|base') /= 0) then
    lat_type = base$
  elseif (index(val_str, '|') /= 0) then
    call out_io (s_error$, r_name, 'BAD SET VALUE: ' // value)
    return
  endif

  ix = index(val_str, '|')
  if (ix /= 0) val_str = val_str(:ix-1)
  tao_lat => tao_pointer_to_tao_lat(u, lat_type)

  ix = index(val_str, '[')
  if (ix == 0) then
    call out_io (s_error$, r_name, 'BAD SET VALUE: ' // value)
    return
  endif

  call lat_ele_locator (val_str(:ix-1), tao_lat%lat, v_eles, n_eles, err); if (err) return
  ix2 = len_trim(val_str)
  call pointer_to_attribute (v_eles(1)%ele, val_str(ix+1:ix2-1), .false., a_ptr, err); if (err) return
  val_str = all_pointer_to_string (a_ptr, err = err)
  if (err) then
    call out_io (s_error$, r_name, 'STRANGE SET VALUE: ' // value)
    return
  endif

! If the value string does not have "ele::" then just 
! assume that set_ele_attribute will be able to evaluate the value string.

else
  val_str = value
endif

! When a wild card is used so there are multiple elements involved, an error
! generated by some, but not all elements is not considered a true error.
! For example: "set ele * csr_calc_on = t" is not valid for markers.

n_set = 0
do i = 1, size(eles)
  u => s%u(eles(i)%id)
  call set_ele_attribute (eles(i)%ele, trim(attribute) // '=' // trim(val_str), err, .false.)
  call tao_set_flags_for_changed_attribute (u, eles(i)%ele%name, eles(i)%ele)
  if (.not. err) n_set = n_set + 1
enddo

! If there is a true error then generate an error message

if (n_set == 0) then
  u => s%u(eles(1)%id)
  call set_ele_attribute (eles(1)%ele, trim(attribute) // '=' // trim(val_str),  err)
  return
endif

! End stuff

if (n_set /= size(eles)) then
  call out_io (s_info$, r_name, 'Set successful for \i0\ elements out of \i0\ ', i_array = [n_set, size(eles)])
endif

do i = lbound(s%u, 1), ubound(s%u, 1)
  u => s%u(i)
  if (.not. u%calc%lattice) cycle
  call lattice_bookkeeper (u%model%lat)
enddo

end subroutine tao_set_elements_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_logical_value (var, var_str, value_str, error)
!
! Subroutine to read and set the value of an logical varialbe.
!
! If the value is out of the range [min_val, max_val] then an error message will
! be generated and the variable will not be set.
!
! Input:
!   var_str   -- Character(*): Used for error messages.
!   value_str -- Character(*): String with encoded value.
!
! Output:
!   var   -- Logical: Variable to set.
!   error -- Logical: Set True on an error. False otherwise.
!-

subroutine tao_set_logical_value (var, var_str, value_str, error)

implicit none

logical var, ix
integer ios

character(*) var_str, value_str
character(*), parameter :: r_name = 'tao_set_logical_value'
logical error

!

error = .true.
read (value_str, '(l)', iostat = ios) ix

if (ios /= 0 .or. len_trim(value_str) == 0) then
  call out_io (s_error$, r_name, 'BAD ' // trim(var_str) // ' VALUE.')
  return
endif

var = ix      
error = .false.

end subroutine tao_set_logical_value 

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_integer_value (var, var_str, value_str, error, min_val, max_val, print_err)
!
! Subroutine to read and set the value of an integer varialbe.
!
! If the value is out of the range [min_val, max_val] then an error message will
! be generated and the variable will not be set.
!
! Input:
!   var_str   -- Character(*): Used for error messages.
!   value_str -- Character(*): String with encoded value.
!   min_val   -- Integer, optional: Minimum value. 
!   max_val   -- Integer, optional: Maximum value.
!   print_err -- logical, optional: If True, print error message. Default is true
!
! Output:
!   var   -- Integer: Variable to set.
!   error -- Logical: Set True on an error. False otherwise.
!-

subroutine tao_set_integer_value (var, var_str, value_str, error, min_val, max_val, print_err)

implicit none

integer var
integer, optional :: min_val, max_val
integer ios, ix

character(*) var_str, value_str
character(*), parameter :: r_name = 'tao_set_integer_value'
logical error
logical, optional :: print_err

!

error = .true.
read (value_str, *, iostat = ios) ix

if (ios /= 0 .or. len_trim(value_str) == 0) then
  if (logic_option(.true., print_err)) call out_io (s_error$, r_name, 'BAD ' // trim(var_str) // ' VALUE.')
  return
endif

if (present(min_val)) then
  if (ix < min_val) then
  if (logic_option(.true., print_err)) call out_io (s_error$, r_name, trim(var_str) // ' VALUE TOO SMALL.')
    return 
  endif
endif

if (present(max_val)) then
  if (ix > max_val) then
  if (logic_option(.true., print_err)) call out_io (s_error$, r_name, trim(var_str) // ' VALUE TOO LARGE.')
    return 
  endif
endif

var = ix
error = .false.

end subroutine tao_set_integer_value

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_switch_value (switch_val, err_str, value_str, name_list, l_bound, error, switch_str)
!
! Routine to set the value of an integer switch.
!
! If the value is out of the range [min_val, max_val] then an error message will
! be generated and the switch will not be set.
!
! Input:
!   err_str       -- character(*): Used for error messages.
!   value_str     -- character(*): String with encoded value.
!   name_list(:)  -- character(*): Names to match to.
!   l_bound       -- integer: Lower bound to name_list(:) array.
!
! Output:
!   switch_val  -- integer: Parameter to set. Not set if there is an error.
!   error       -- logical: Set True on an error. False otherwise.
!   switch_str  -- character(*), optional: Set to the string representation of switch_val. 
!                   Not set if there is an error.
!-

subroutine tao_set_switch_value (switch_val, err_str, value_str, name_list, l_bound, error, switch_str)

implicit none

integer switch_val, l_bound
integer ios, ix

character(*) err_str, value_str
character(*) name_list(l_bound:)
character(*), optional :: switch_str
character(*), parameter :: r_name = 'tao_set_switch_value'
logical error

!

error = .true.

call match_word(value_str, name_list, ix, .false., .true.)

if (ix == 0) then
  call out_io (s_error$, r_name, trim(err_str) // ' IS UNKNOWN.')
  return 
endif

if (ix < 0) then
  call out_io (s_error$, r_name, trim(err_str) // ' ABBREVIATION MATCHES MULTIPLE NAMES.')
  return 
endif

switch_val = ix + (l_bound - 1)
if (present(switch_str)) switch_str = downcase(name_list(ix))

error = .false.

end subroutine tao_set_switch_value

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_real_value (var, var_str, value_str, error, min_val, max_val, dflt_uni)
!
! Subroutine to read and set the value of a real variable.
!
! If the value is out of the range [min_val, max_val] then an error message will
! be generated and the variable will not be set.
!
! Input:
!   var_str   -- Character(*): Used for error messages.
!   value_str -- Character(*): String with encoded value.
!   min_val   -- real(rp), optional: Minimum value. 
!   max_val   -- real(rp), optional: Maximum value.
!   dflt_uni  -- integer, optional: Default universe used to evaluate parameters.
!
! Output:
!   var   -- real(rp): Variable to set.
!   error -- Logical: Set True on an error. False otherwise.
!-

subroutine tao_set_real_value (var, var_str, value_str, error, min_val, max_val, dflt_uni)

implicit none

type (tao_expression_info_struct), allocatable :: info(:)

real(rp) var, var_value
real(rp), allocatable :: var_array(:)
real(rp), optional :: min_val, max_val
integer, optional :: dflt_uni
integer ios

character(*) var_str, value_str
character(20) :: r_name = 'tao_set_real_value'
logical error

!

call tao_evaluate_expression (value_str, 1, .false., var_array, info, error, .true., dflt_uni = dflt_uni)
if (error) return

var_value = var_array(1)
error = .true.

if (present(min_val)) then
  if (var_value < min_val) then
    call out_io (s_error$, r_name, trim(var_str) // ' VALUE OUT OF RANGE.')
    return
  endif
endif

if (present(max_val)) then
  if (var_value > max_val) then
    call out_io (s_error$, r_name, trim(var_str) // ' VALUE OUT OF RANGE.')
    return
  endif
endif

var = var_value
error = .false.

end subroutine tao_set_real_value

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_drawing_cmd (drawing, component, value_str)
!
! Routine to set floor_plan and lat_layout parameters.
! 
! Input:
!   component -- Character(*): Which drawing component to set.
!   value_str -- Character(*): Value to set to.
!
! Output:
!    s%shape  -- Shape variables structure.
!-

subroutine tao_set_drawing_cmd (drawing, component, value_str)

implicit none

type (tao_drawing_struct) drawing
type (tao_ele_shape_struct), target :: ele_shape(50)
type (tao_ele_shape_struct), pointer :: s

character(*) component, value_str
character(20) :: r_name = 'tao_set_drawing_cmd'

integer i, ix, n, iu, ios

logical err, needs_quotes

namelist / params / ele_shape

! Init

n = size(drawing%ele_shape)
ele_shape(1:n) = drawing%ele_shape

! Setup

needs_quotes = .false.
ix = index(component, '%')

if (ix /= 0) then
  select case (component(ix+1:))
  case ('shape', 'color', 'label', 'ele_name')
    needs_quotes = .true.
  end select
  if (value_str(1:1) == "'" .or. value_str(1:1) == '"') needs_quotes = .false.
endif

! open a scratch file for a namelist read

iu = tao_open_scratch_file (err);  if (err) return

write (iu, '(a)') '&params'
if (needs_quotes) then
  write (iu, '(a)') trim(component) // ' = "' // trim(value_str) // '"'
else
  write (iu, '(a)') trim(component) // ' = ' // trim(value_str)
endif
write (iu, '(a)') '/'
write (iu, *)
rewind (iu)
read (iu, nml = params, iostat = ios)
close (iu, status = 'delete')

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
  return
endif

! Cleanup

do i = 1, n
  s => ele_shape(i)
  if (s%ele_id(1:6) /= 'data::' .and. s%ele_id(1:5) /= 'var::' .and. &
      s%ele_id(1:5) /= 'lat::' .and. s%ele_id(1:15) /= 'building_wall::') call str_upcase (s%ele_id, s%ele_id)
  call str_upcase (s%shape,    s%shape)
  call str_upcase (s%color,    s%color)
  call downcase_string (s%label)
  call tao_string_to_element_id (s%ele_id, s%ix_ele_key, s%name_ele, err, .true.)
  if (err) return
enddo

n = size(drawing%ele_shape)
drawing%ele_shape = ele_shape(1:n)

end subroutine tao_set_drawing_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_symbolic_number_cmd (sym_str, num_str)
!
! Associates a given symbol with a given number.
!
! Input:
!   sym_str     -- character(*): Symbol.
!   num_str     -- character(*): Number.
!-

subroutine tao_set_symbolic_number_cmd (sym_str, num_str)

type (tao_expression_info_struct), allocatable :: info(:)
type (named_number_struct), allocatable :: sym_temp(:)

integer i, n
real(rp), allocatable :: value(:)
logical err

character(*) sym_str, num_str
character(*), parameter :: r_name = 'tao_set_symbolic_number_cmd'

!

do i = 1, size(physical_const_list)
  if (sym_str == physical_const_list(i)%name) then
    call out_io (s_error$, r_name, 'NAME MATCHES NAME OF A PHYSICAL CONSTANT. SET IGNORED.')
    return
  endif
enddo

call tao_evaluate_expression (num_str, 1, .false., value, info, err); if (err) return

!

if (allocated(s%com%symbolic_num)) then
  n = size(s%com%symbolic_num)
  do i = 1, n
    if (sym_str == s%com%symbolic_num(i)%name) exit
  enddo

  if (i == n + 1) then
    call move_alloc (s%com%symbolic_num, sym_temp)
    allocate (s%com%symbolic_num(n+1))
    s%com%symbolic_num(1:n) = sym_temp
  endif

  s%com%symbolic_num(i)%name = sym_str
  s%com%symbolic_num(i)%value = value(1)

else
  allocate (s%com%symbolic_num(1)) 
  s%com%symbolic_num(1)%name = sym_str
  s%com%symbolic_num(1)%value = value(1)
endif

end subroutine tao_set_symbolic_number_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_qp_rect_struct (qp_rect_name, component, qp_rect, value, error, ix_uni)
!
! Routine to set qp_rect_names of a qp_rect_struct.
!
! Input:
!   qp_rect_name    -- character(*): qp_rect name. Used for error messages.
!   component       -- character(*): qp_rect component name.
!   qp_rect         -- qp_rect_struct: qp_rect_struct with component to modify
!   value           -- character(*): Component value.
!
! Output:
!   qp_rect         -- qp_rect_struct: qp_rect_struct with changed component value.
!   error           -- logical: Set true if there is an error. False otherwise.
!   ix_uni          -- integer, optional: Tao universe number in case the value depends upon
!                       a parameter of a particular universe.
!-

subroutine tao_set_qp_rect_struct (qp_rect_name, component, qp_rect, value, error, ix_uni)

type (qp_rect_struct) qp_rect
integer, optional :: ix_uni
character(*) qp_rect_name, component, value
character(*), parameter :: r_name = 'tao_set_qp_rect_struct '
logical error

!

select case (component)
case ('x1')
  call tao_set_real_value(qp_rect%x1, component, value, error, dflt_uni = ix_uni)
case ('x2')
  call tao_set_real_value(qp_rect%x2, component, value, error, dflt_uni = ix_uni)
case ('y1')
  call tao_set_real_value(qp_rect%y1, component, value, error, dflt_uni = ix_uni)
case ('y2')
  call tao_set_real_value(qp_rect%y2, component, value, error, dflt_uni = ix_uni)
case default
  call out_io (s_error$, r_name, "BAD QP_RECT COMPONENT: " // component)
  error = .true.
  return
end select

end subroutine tao_set_qp_rect_struct

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_qp_axis_struct (qp_axis_name, component, qp_axis, value, error, ix_uni)
!
! Routine to set qp_axis_names of a qp_axis_struct.
!
! Input:
!   qp_axis_name    -- character(*): qp_axis name. Used for error messages.
!   component       -- character(*): qp_axis component name.
!   qp_axis         -- qp_axis_struct: qp_axis_struct with component to modify
!   value           -- character(*): Component value.
!
! Output:
!   qp_axis         -- qp_axis_struct: qp_axis_struct with changed component value.
!   error           -- logical: Set true if there is an error. False otherwise.
!   ix_uni          -- integer, optional: Tao universe number in case the value depends upon
!                       a parameter of a particular universe.
!-

subroutine tao_set_qp_axis_struct (qp_axis_name, component, qp_axis, value, error, ix_uni)

use quick_plot, only: qp_string_to_enum

type (qp_axis_struct) qp_axis
character(*) component, value, qp_axis_name
character(*), parameter :: r_name = 'tao_set_qp_axis_struct '
integer, optional :: ix_uni
integer indx
logical error

!

select case (component)
case ('min')
  call tao_set_real_value (qp_axis%min, qp_axis_name, value, error, dflt_uni = ix_uni)
case ('max')
  call tao_set_real_value (qp_axis%max, qp_axis_name, value, error, dflt_uni = ix_uni)
case ('number_offset')
  call tao_set_real_value (qp_axis%number_offset, qp_axis_name, value, error, dflt_uni = ix_uni)
case ('label_offset')
  call tao_set_real_value (qp_axis%label_offset, qp_axis_name, value, error, dflt_uni = ix_uni)
case ('major_tick_len')
  call tao_set_real_value (qp_axis%major_tick_len, qp_axis_name, value, error, dflt_uni = ix_uni)
case ('minor_tick_len')
  call tao_set_real_value (qp_axis%minor_tick_len, qp_axis_name, value, error, dflt_uni = ix_uni)

case ('label_color')
  indx = qp_string_to_enum(value, 'color', -1)
  if (indx < 1) then
    call out_io (s_error$, r_name, 'BAD COLOR NAME: ' // value)
    error = .true.
  else
    qp_axis%label_color = indx
    error = .false.
  endif

case ('major_div')
  call tao_set_integer_value (qp_axis%major_div, qp_axis_name, value, error, 1)
  if (.not. error) qp_axis%major_div_nominal = qp_axis%major_div

case ('major_div_nominal')
  call tao_set_integer_value (qp_axis%major_div_nominal, qp_axis_name, value, error, 1)
case ('minor_div')
  call tao_set_integer_value (qp_axis%minor_div, qp_axis_name, value, error, 0)
case ('minor_div_max')
  call tao_set_integer_value (qp_axis%minor_div_max, qp_axis_name, value, error, 1)
case ('places')
  call tao_set_integer_value (qp_axis%places, qp_axis_name, value, error)
case ('tick_side')
  call tao_set_integer_value (qp_axis%tick_side, qp_axis_name, value, error, -1, 1)
case ('number_side')
  call tao_set_integer_value (qp_axis%number_side, qp_axis_name, value, error, -1, 1)

case ('label')
  qp_axis%label = value
  error = .false.
case ('type')
  qp_axis%type = value
  error = .false.
case ('bounds')
  qp_axis%bounds = value
  error = .false.

case ('draw_label')
  call tao_set_logical_value (qp_axis%draw_label, qp_axis_name, value, error)

case ('draw_numbers')
  call tao_set_logical_value (qp_axis%draw_numbers, qp_axis_name, value, error)

case default
  call out_io (s_error$, r_name, "BAD QP_AXIS COMPONENT " // component)
  error = .true.
  return
end select

end subroutine tao_set_qp_axis_struct

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_qp_point_struct (qp_point_name, component, qp_point, value, error, ix_uni)
!
! Routine to set qp_point_names of a qp_point_struct.
!
! Input:
!   qp_point_name   -- character(*): qp_point name. Used for error messages.
!   component       -- character(*): qp_point component name.
!   qp_point        -- qp_point_struct: qp_point_struct with component to modify
!   value           -- character(*): Component value.
!
! Output:
!   qp_point        -- qp_point_struct: qp_point_struct with changed component value.
!   error           -- logical: Set true if there is an error. False otherwise.
!   ix_uni          -- integer, optional: Tao universe number in case the value depends upon
!                       a parameter of a particular universe.
!-

subroutine tao_set_qp_point_struct (qp_point_name, component, qp_point, value, error, ix_uni)

type (qp_point_struct) qp_point
character(*) component, value, qp_point_name
character(*), parameter :: r_name = 'tao_set_qp_point_struct '
integer, optional :: ix_uni
logical error

!

select case (component)
case ('x')
  call tao_set_real_value(qp_point%x, qp_point_name, value, error, dflt_uni = ix_uni)
case ('y')
  call tao_set_real_value(qp_point%y, qp_point_name, value, error, dflt_uni = ix_uni)
case ('units')
  qp_point%units = value
  error = .false.
case default
  call out_io (s_error$, r_name, "BAD GRAPH QP_POINT COMPONENT " // component)
  error = .true.
  return
end select

end subroutine tao_set_qp_point_struct

end module tao_set_mod
