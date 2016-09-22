module tao_set_mod

use tao_mod
use tao_data_and_eval_mod
use tao_lattice_calc_mod
use tao_input_struct
use geodesic_lm

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

logical, allocatable, save :: this_u(:)
logical err

! Lattice transfer

call tao_pick_universe (dest_lat, dest1_name, this_u, err)
if (err) return

do i = lbound(s%u, 1), ubound(s%u, 1)
  if (.not. this_u(i)) cycle
  call set_lat (s%u(i))
  if (err) return
enddo

! Variable transfer for those variables which vary parameters of the affected universe(s).
! This only needs to be done when dest_lat is a model lattice.

if (dest1_name == 'model') then
  do i = 1, s%n_var_used

    do j = 1, size(s%var(i)%this)
      if (.not. this_u(s%var(i)%this(j)%ix_uni)) cycle

      select case (source_lat)
      case ('model')
        source_val = s%var(i)%this(j)%model_value
      case ('base')
        source_val = s%var(i)%this(j)%base_value
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
dest1_lat%lat_branch   = source1_lat%lat_branch
dest1_lat%modes        = source1_lat%modes
dest1_lat%a            = source1_lat%a
dest1_lat%b            = source1_lat%b
dest1_lat%rad_int      = source1_lat%rad_int

do ib = 0, ubound(dest1_lat%lat_branch, 1)
  do j = lbound(dest1_lat%lat_branch(ib)%bunch_params, 1), ubound(dest1_lat%lat_branch(ib)%bunch_params, 1)
    dest1_lat%lat_branch(ib)%bunch_params(j) = source1_lat%lat_branch(ib)%bunch_params(j)
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
! Subroutine tao_set_global_cmd (who, set_value)
!
! Routine to set global variables
! 
! Input:
!   who       -- Character(*): which global variable to set
!   set_value -- Character(*): Value to set to.
!
! Output:
!    s%global  -- Global variables structure.
!-

subroutine tao_set_global_cmd (who, set_value)

implicit none

type (tao_global_struct) global, old_global
type (tao_universe_struct), pointer :: u

character(*) who, set_value
character(20) :: r_name = 'tao_set_global_cmd'

integer iu, ios, iuni
logical err, needs_quotes

namelist / params / global

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

needs_quotes = .false.
select case (who)
case ('random_engine', 'random_gauss_converter', 'track_type', &
      'prompt_string', 'optimizer', 'print_command', 'var_out_file')
  needs_quotes = .true.
end select
if (set_value(1:1) == "'" .or. set_value(1:1) == '"') needs_quotes = .false.

write (iu, *) '&params'
if (needs_quotes) then
  write (iu, *) ' global%' // trim(who) // ' = "' // trim(set_value) // '"'
else
  write (iu, *) ' global%' // trim(who) // ' = ' // trim(set_value)
endif
write (iu, *) '/'
write (iu, *)
rewind (iu)
global = s%global  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu)

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
case ('track_type')
  if (set_value /= 'single' .and. set_value /= 'beam') then
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
! Subroutine tao_set_csr_param_cmd (who, set_value)
!
! Routine to set csr_param variables
! 
! Input:
!   who       -- Character(*): which csr_param variable to set
!   set_value -- Character(*): Value to set to.
!
! Output:
!    csr_param  -- Csr_param variables structure.
!-

subroutine tao_set_csr_param_cmd (who, set_value)

use beam_def_struct, only: csr_parameter_struct, csr_param

implicit none

type (csr_parameter_struct) local_csr_param

character(*) who, set_value
character(20) :: r_name = 'tao_set_csr_param_cmd'

integer iu, ios
logical err

namelist / params / local_csr_param

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
write (iu, *) ' local_csr_param%' // trim(who) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)
local_csr_param = csr_param  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu)

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
! Subroutine tao_set_bmad_com_cmd (who, set_value)
!
! Routine to set bmad_com variables
! 
! Input:
!   who       -- Character(*): which bmad_com variable to set
!   set_value -- Character(*): Value to set to.
!-

subroutine tao_set_bmad_com_cmd (who, set_value)

implicit none

type (bmad_common_struct) this_bmad_com

character(*) who, set_value
character(20) :: r_name = 'tao_set_bmad_com_cmd'

integer iu, ios
logical err

namelist / params / this_bmad_com

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
write (iu, *) ' this_bmad_com%' // trim(who) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)
this_bmad_com = bmad_com  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu)

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
! Subroutine tao_set_geodesic_lm_cmd (who, set_value)
!
! Routine to set geodesic_lm variables
! 
! Input:
!   who       -- Character(*): which geodesic_lm variable to set
!   set_value -- Character(*): Value to set to.
!-

subroutine tao_set_geodesic_lm_cmd (who, set_value)

implicit none

type (geodesic_lm_param_struct) this_geodesic_lm

character(*) who, set_value
character(20) :: r_name = 'tao_set_geodesic_lm_cmd'

integer iu, ios
logical err

namelist / params / this_geodesic_lm

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
write (iu, *) ' this_geodesic_lm%' // trim(who) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)
this_geodesic_lm = geodesic_lm_param  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu)

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
! Subroutine tao_set_opti_de_param_cmd (who, set_value)
!
! Routine to set opti_de_param variables
! 
! Input:
!   who       -- Character(*): which opti_de_param variable to set
!   set_value -- Character(*): Value to set to.
!-

subroutine tao_set_opti_de_param_cmd (who, set_value)

use opti_de_mod, only: opti_de_param

implicit none

character(*) who, set_value
character(20) :: r_name = 'tao_set_opti_de_param_cmd'

integer iu, ios
logical err

namelist / params / opti_de_param

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
write (iu, *) ' opti_de_param%' // trim(who) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)
read (iu, nml = params, iostat = ios)
close (iu)

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
endif

end subroutine tao_set_opti_de_param_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_wave_cmd (who, set_value, err)
!
! Routine to set wave variables
! 
! Input:
!   who       -- Character(*): which wave variable to set
!   set_value -- Character(*): Value to set to.
!
! Output:
!    s%wave  -- Wave variables structure.
!-

subroutine tao_set_wave_cmd (who, set_value, err)

implicit none

type (tao_wave_struct) wave

character(*) who, set_value
character(20) :: r_name = 'tao_set_wave_cmd'

real(rp) ix_a(2), ix_b(2)

integer iu, ios
logical err

namelist / params / ix_a, ix_b

! open a scratch file for a namelist read

err = .true.

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

ix_a = [s%wave%ix_a1, s%wave%ix_a2]
ix_b = [s%wave%ix_b1, s%wave%ix_b2]

write (iu, *) '&params'
write (iu, *) trim(who) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)
wave = s%wave  ! set defaults
read (iu, nml = params, iostat = ios)
close (iu)

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
! Subroutine tao_set_beam_init_cmd (who, set_value)
!
! Routine to set beam_init variables
! 
! Input:
!   who       -- Character(*): which beam_init variable to set
!   set_value -- Character(*): Value to set to.
!
! Output:
!    s%beam_init  -- Beam_init variables structure.
!-

subroutine tao_set_beam_init_cmd (who, set_value)

implicit none

type (beam_init_struct) beam_init
type (tao_universe_struct), pointer :: u
character(*) who, set_value
character(40) who2
character(20) :: r_name = 'tao_set_beam_init_cmd'

integer i, iu, ios
logical err
logical, allocatable :: picked_uni(:)

namelist / params / beam_init

! get universe

call tao_pick_universe (who, who2, picked_uni, err)

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
write (iu, *) ' beam_init%' // trim(who2) // ' = ' // trim(set_value)
write (iu, *) '/'

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
    u%beam%init_beam0 = .true.  ! Force reinit
    u%model%lat%beam_start%vec = u%beam%beam_init%center
    u%calc%lattice = .true.
  else
    call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
    exit
  endif

enddo

close (iu)
deallocate (picked_uni)

end subroutine tao_set_beam_init_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
! Subroutine tao_set_plot_page_cmd (component, set_value, set_value2)
!
!  Set various aspects of the plotting window
!
! Input:
!   component     -- Character(*): Which component to set.
!   set_value     -- Character(*): What value to set to.
!   set_value2    -- Character(*): 2nd value if component is an array.
!
!  Output:
!    s%plot       -- tao_plotting_struct:
!-

subroutine tao_set_plot_page_cmd (component, set_value, set_value2)

implicit none

type (tao_plot_page_input) plot_page

character(*) component, set_value
character(*), optional :: set_value2
character(24) :: r_name = 'tao_set_plot_page_cmd'

real(rp) x, y
integer iu, ios
logical error


namelist / params / plot_page

! Special cases

select case (component)

case ('title')
  s%plot_page%title(1)%title = trim(set_value)
  return

case ('subtitle')
  s%plot_page%title(2)%title = trim(set_value)
  s%plot_page%title(2)%draw_it = .true.
  return

case ('subtitle_loc')

  if (.not. present(set_value2)) then
    call out_io(s_info$, r_name, "subtitle_loc requires two numbers.")
    return
  endif

  read(set_value, '(f15.10)') x
  read(set_value2, '(f15.10)') y
  s%plot_page%title(2)%x = x
  s%plot_page%title(2)%y = y
  return

end select

! For everything else...
! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
write (iu, *) ' plot_page%' // trim(component) // ' = ' // trim(set_value)
write (iu, *) '/'
rewind (iu)

call tao_set_plotting (plot_page, s%plot_page, .false., .true.)

read (iu, nml = params, iostat = ios)
close (iu)

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
! Subroutine tao_set_curve_cmd (curve_name, component, set_value)
!
! Routine to set var values.
!
! Input:
!   curve_name -- Character(*): Which curve to set.
!   component  -- Character(*): Which component to set.
!   set_value  -- Character(*): What value to set it to.
!-

subroutine tao_set_curve_cmd (curve_name, component, set_value)

implicit none

type (tao_curve_array_struct), allocatable, save :: curve(:)
type (tao_graph_array_struct), allocatable, save :: graph(:)
type (lat_struct), pointer :: lat

integer i, j, ios, i_uni
integer, allocatable, save :: ix_ele(:)

character(*) curve_name, component, set_value
character(20) :: r_name = 'tao_set_curve_cmd'

logical err

!

call tao_find_plots (err, curve_name, 'REGION', curve = curve, always_allocate = .true.)
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
logical error

!

i_branch = this_curve%ix_branch
i_uni = tao_universe_number(this_curve%ix_universe)

this_graph => this_curve%g

! if the universe is changed then need to check ele_ref

select case (component)

case ('ele_ref_name')
  this_curve%ele_ref_name = set_value
  call tao_locate_elements (this_curve%ele_ref_name, i_uni, eles, error, ignore_blank = .true.)
  if (size(eles) == 0) return
  this_curve%ix_ele_ref = eles(1)%ele%ix_ele
  this_curve%ix_branch  = eles(1)%ele%ix_branch
  call tao_ele_to_ele_track (i_uni, i_branch, this_curve%ix_ele_ref, this_curve%ix_ele_ref_track)
  
case ('ix_ele_ref')
  call tao_integer_set_value (this_curve%ix_ele_ref, component, &
                    set_value, error, 0, s%u(i_uni)%model%lat%branch(i_branch)%n_ele_max)
  this_curve%ele_ref_name = s%u(i_uni)%model%lat%ele(this_curve%ix_ele_ref)%name
  call tao_ele_to_ele_track (this_curve%ix_universe, i_branch, &
                                this_curve%ix_ele_ref, this_curve%ix_ele_ref_track)

case ('ix_universe')
  call tao_integer_set_value (this_curve%ix_universe, component, &
                                            set_value, error, 0, ubound(s%u, 1))
  if (error) return
  call tao_locate_elements (this_curve%ele_ref_name, this_curve%ix_universe, eles, error, ignore_blank = .true.)
  if (size(eles) == 0) return
  this_curve%ix_ele_ref = eles(1)%ele%ix_ele
  this_curve%ix_branch  = eles(1)%ele%ix_branch
  call tao_ele_to_ele_track (this_curve%ix_universe, this_curve%ix_branch, &
                                     this_curve%ix_ele_ref, this_curve%ix_ele_ref_track)

case ('ix_branch') 
  call tao_integer_set_value (this_curve%ix_branch, component, set_value, error)

case ('ix_bunch')
  u => tao_pointer_to_universe (this_curve%ix_universe)
  if (.not. associated(u)) return
  call tao_integer_set_value (this_curve%ix_bunch, component, &
                        set_value, error, -1, u%beam%beam_init%n_bunch)

case ('symbol_every')
  call tao_integer_set_value (this_curve%symbol_every, component, set_value, error, 0, 1000000)

case ('draw_line')
  call tao_logical_set_value (this_curve%draw_line, component, set_value, error)

case ('draw_symbols')
  call tao_logical_set_value (this_curve%draw_symbols, component, set_value, error)

case ('draw_symbol_index')
  call tao_logical_set_value (this_curve%draw_symbol_index, component, set_value, error)

case ('smooth_line_calc')
  call tao_logical_set_value (this_curve%smooth_line_calc, component, set_value, error)

case ('use_y2')
  call tao_logical_set_value (this_curve%use_y2, component, set_value, error)

case ('use_z_color')
  call tao_logical_set_value (this_curve%use_z_color, component, set_value, error)

case ('data_source')
  this_curve%data_source = set_value

case ('data_index')
  this_curve%data_index = set_value

case ('data_type')
  this_curve%data_type = set_value

case ('data_type_x')
  this_curve%data_type_x = set_value

case ('data_type_z')
  this_curve%data_type_z = set_value

case ('z_color0')
  call tao_real_set_value (this_curve%z_color0, component, set_value, error)  

case ('z_color1')
  call tao_real_set_value (this_curve%z_color1, component, set_value, error)  

case ('hist%number')
  this_curve%hist%width = 0
  call tao_integer_set_value (this_curve%hist%number, component, set_value, error, min_val = 0)

case ('hist%density_normalized')
  call tao_logical_set_value (this_curve%hist%density_normalized, component, set_value, error)
  
case ('hist%weight_by_charge')
  call tao_logical_set_value (this_curve%hist%weight_by_charge, component, set_value, error)
  
case ('hist%center')  
  call tao_real_set_value (this_curve%hist%center, component, set_value, error)
  
case ('hist%width')  
  this_curve%hist%number = 0
  call tao_real_set_value (this_curve%hist%width, component, set_value, error)  
  
case ('y_axis_scale_factor')
  call tao_real_set_value (this_curve%y_axis_scale_factor, component, set_value, error)

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
! Subroutine tao_set_plot_cmd (plot_name, component, set_value)
!
! Routine to set var values.
!
! Input:
!   plot_name --  Character(*): Which plot to set.
!   component  -- Character(*): Which component to set.
!   set_value  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_plot_cmd (plot_name, component, set_value)

implicit none

type (tao_plot_array_struct), allocatable, save :: plot(:)
type (tao_universe_struct), pointer :: u

character(*) plot_name, component, set_value
character(20) :: r_name = 'tao_set_plot_cmd'

integer iset, iw, ix
integer i, j, ios
logical err
logical logic, error

!

call tao_find_plots (err, plot_name, 'REGION', plot = plot)
if (err) return

if (.not. allocated(plot)) then
  call out_io (s_error$, r_name, 'PLOT OR PLOT NOT SPECIFIED')
  return
endif

! And set

do i = 1, size(plot)

  select case (component)

    case ('autoscale_x')
      call tao_logical_set_value (plot(i)%p%autoscale_x, component, set_value, error)

    case ('autoscale_y')
      call tao_logical_set_value (plot(i)%p%autoscale_y, component, set_value, error)

    case default
      call out_io (s_error$, r_name, "BAD PLOT COMPONENT: " // component)
      return
      
  end select

enddo

end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_graph_cmd (graph_name, component, set_value)
!
! Routine to set var values.
!
! Input:
!   graph_name -- Character(*): Which graph to set.
!   component  -- Character(*): Which component to set.
!   set_value  -- Character(*): What value to set it to.
!
!  Output:
!-

subroutine tao_set_graph_cmd (graph_name, component, set_value)

implicit none

type (tao_plot_array_struct), allocatable, save :: plot(:)
type (tao_graph_array_struct), allocatable, save :: graph(:)

character(*) graph_name, component, set_value
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
character(40) comp
character(200) value
integer iset, iw, ix
logical logic, error

!

comp = component
value = remove_quotes(set_value)

select case (comp)

  case ('component')
    this_graph%component = set_value
  case ('clip')
    call tao_logical_set_value (this_graph%clip, comp, value, error)
  case ('draw_axes')
    call tao_logical_set_value (this_graph%draw_axes, comp, value, error)
  case ('draw_grid')
    call tao_logical_set_value (this_graph%draw_grid, comp, value, error)
  case ('draw_only_good_user_data_or_vars')
    call tao_logical_set_value (this_graph%draw_only_good_user_data_or_vars, comp, value, error)
  case ('ix_universe')
    call tao_integer_set_value (this_graph%ix_universe, comp, value, error, 1, ubound(s%u, 1))
  case ('margin%x1')
    call tao_real_set_value(this_graph%margin%x1, comp, value, error)
  case ('margin%x2')
    call tao_real_set_value(this_graph%margin%x2, comp, value, error)
  case ('margin%y1')
    call tao_real_set_value(this_graph%margin%y1, comp, value, error)
  case ('margin%y2')
    call tao_real_set_value(this_graph%margin%y2, comp, value, error)
  case ('floor_plan_size_is_absolute')
    call tao_logical_set_value(this_graph%floor_plan_size_is_absolute, comp, value, error)
  case ('floor_plan_draw_only_first_pass')
    call tao_logical_set_value(this_graph%floor_plan_draw_only_first_pass, comp, value, error)
  case ('floor_plan_rotation')
    call tao_real_set_value(this_graph%floor_plan_rotation, comp, value, error)
  case ('floor_plan_orbit_scale')
    call tao_real_set_value(this_graph%floor_plan_orbit_scale, comp, value, error)
  case ('floor_plan_orbit_color')
    this_graph%floor_plan_orbit_color = value
  case ('scale_margin%x1')
    call tao_real_set_value(this_graph%scale_margin%x1, comp, value, error)
  case ('scale_margin%x2')
    call tao_real_set_value(this_graph%scale_margin%x2, comp, value, error)
  case ('scale_margin%y1')
    call tao_real_set_value(this_graph%scale_margin%y1, comp, value, error)
  case ('scale_margin%y2')
    call tao_real_set_value(this_graph%scale_margin%y2, comp, value, error)
  case ('title')
    this_graph%title = value
  case ('y2_mirrors_y')
    call tao_logical_set_value (this_graph%y2_mirrors_y, comp, value, error)
  case ('floor_plan_view')
    select case (value)
    case ('xy', 'xz', 'yx', 'yz', 'zx', 'zy')
    case default
      call out_io(s_info$, r_name, "Valid floor_plan_view settings are: 'xy', 'zx', etc.")
      return
    end select
    this_graph%floor_plan_view = upcase(value)

  case default
    call out_io (s_error$, r_name, "BAD GRAPH COMPONENT: " // component)
    return
    
end select

u => tao_pointer_to_universe(this_graph%ix_universe)
u%calc%lattice = .true.

end subroutine
end subroutine

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
type (tao_var_array_struct), allocatable, save     :: v_var(:)
type (tao_string_array_struct), allocatable, save :: s_var(:), s_set(:)
type (tao_expression_info_struct), allocatable, save :: info(:)

real(rp), allocatable, save :: r_value(:)
real(rp) value
integer i, j

character(*) var_str, value_str
character(20) :: r_name = 'tao_set_var_cmd'
character(20) set_is, component
character(40) :: merit_type_names(2) = (/ 'target ', 'limit  ' /)

logical err, l_value, err_flag

! Decode variable component to set.

call tao_find_var (err, var_str, v_array = v_var, re_array=r_var, &
                   log_array=l_var, str_array = s_var, component = component)

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

! Must be merit_type for a string.
! If value_string has "|" then it must be a datum array

elseif (size(s_var) /= 0) then
  if (index(value_str, '|') == 0) then
    if (all (value_str /= merit_type_names)) then
      call out_io (s_error$, r_name, 'BAD MERIT_TYPE NAME:' // value_str)
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

! Only possibility left is real/ The value_str might be a number or it might 
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

type (tao_real_pointer_struct), allocatable, save    :: r_dat(:), r_set(:)
type (tao_data_array_struct), allocatable, save    :: d_dat(:)
type (tao_integer_array_struct), allocatable, save :: int_dat(:), int_set(:)
type (tao_logical_array_struct), allocatable, save :: l_dat(:), l_set(:)
type (tao_string_array_struct), allocatable, save :: s_dat(:), s_set(:)
type (tao_universe_struct), pointer :: u
type (branch_struct), pointer :: branch
type (ele_pointer_struct), allocatable :: eles(:)
type (tao_expression_info_struct), allocatable, save :: info(:)

real(rp), allocatable, save :: r_value(:)
integer i, ix, int_value, n_loc

integer, allocatable :: i_save(:)

character(*) who_str, value_str
character(20) component
character(20) :: r_name = 'tao_set_data_cmd'
character(40) :: merit_type_names(5) = &
              (/ 'target ', 'min    ', 'max    ', 'abs_min', 'abs_max' /)
character(40), target :: dummy
logical err, l_value, valid_value

character(40) :: tmpstr

! Decode data component to set.

call tao_find_data (err, who_str, d_array = d_dat, re_array=r_dat, &
          log_array=l_dat, str_array = s_dat, int_array = int_dat, component = component)
if (err) return

! A logical value_str is either a logical or an array of datum values.

if (size(l_dat) /= 0) then
  if (is_logical(value_str)) then
    read (value_str, *) l_value
    do i = 1, size(l_dat)
      l_dat(i)%l = l_value
    enddo

  else
    call tao_find_data (err, value_str, log_array=l_set)
    if (size(l_set) /= size(l_dat)) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif
    do i = 1, size(l_dat)
      l_dat(i)%l = l_set(i)%l
    enddo
  endif

! An integer value_str is either an integer or an array of datum values.

elseif (size(int_dat) /= 0) then

  allocate (i_save(size(int_dat)))

  if (is_integer(value_str)) then
    read (value_str, *) int_value
    do i = 1, size(int_dat)
      i_save(i) = int_dat(i)%i
      int_dat(i)%i = int_value
    enddo

  else
    call tao_find_data (err, value_str, int_array=int_set)
    if (size(int_set) /= size(int_dat)) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif
    do i = 1, size(int_dat)
      i_save(i) = int_dat(i)%i
      int_dat(i)%i = int_set(i)%i
    enddo
  endif

  if (component == 'ix_ele' .or. component == 'ix_ele_start' .or. component == 'ix_ele_ref') then
    do i = 1, size(int_dat)
      u => s%u(d_dat(i)%d%d1%d2%ix_uni)
      branch => u%design%lat%branch(d_dat(i)%d%ix_branch)
      if (int_dat(i)%i < 0 .or. int_dat(i)%i > branch%n_ele_max) then
        int_dat(i)%i = i_save(i)
      else
        if (component == 'ix_ele') then
          tmpstr = branch%ele(int_dat(i)%i)%name
          d_dat(i)%d%ele_name = tmpstr
          ! d_dat(i)%d%ele_name = branch%ele(int_dat(i)%i)%name
        elseif (component == 'ix_ele_start') then
          tmpstr = branch%ele(int_dat(i)%i)%name
          d_dat(i)%d%ele_start_name = tmpstr
          ! d_dat(i)%d%ele_start_name = branch%ele(int_dat(i)%i)%name
        else
          tmpstr = branch%ele(int_dat(i)%i)%name
          d_dat(i)%d%ele_ref_name = tmpstr
          ! d_dat(i)%d%ele_ref_name = branch%ele(int_dat(i)%i)%name
        endif
      endif
    enddo
  endif

  deallocate (i_save)

! A string:

elseif (size(s_dat) /= 0) then

  ! If value_string has "|" then it must be a datum array

  if (index(value_str, '|') == 0) then
    if (all (component == 'merit_type' .and. value_str /= merit_type_names)) then
      call out_io (s_error$, r_name, 'BAD MERIT_TYPE NAME:' // value_str)
      return
    endif
    if (allocated(s_set)) deallocate(s_set)
    allocate(s_set(1))
    s_set(1)%s => dummy
    s_set(1)%s = value_str

  else
    call tao_find_data (err, value_str, str_array=s_set)
    if (size(s_set) /= size(s_dat) .and. size(s_set) /= 1) then
      call out_io (s_error$, r_name, 'ARRAY SIZES ARE NOT THE SAME')
      return
    endif
  endif

  if (component == 'ele_name' .or. component == 'ele_start_name' .or. component == 'ele_ref_name') then
    do i = 1, size(d_dat)
      u => s%u(d_dat(i)%d%d1%d2%ix_uni)
      if (size(s_set) > 1) dummy = s_set(i)%s
      call lat_ele_locator (dummy, u%design%lat, eles, n_loc)
      if (n_loc == 0) then
        call out_io (s_error$, r_name, 'ELEMENT NOT LOCATED: ' // dummy)
        return
      endif
      if (component == 'ele_name') then
        d_dat(i)%d%ix_ele    = eles(1)%ele%ix_ele
        d_dat(i)%d%ix_branch = eles(1)%ele%ix_branch
      elseif (component == 'ele_start_name') then
        d_dat(i)%d%ix_ele_start = eles(1)%ele%ix_ele
      else
        d_dat(i)%d%ix_ele_ref = eles(1)%ele%ix_ele
      endif
    enddo
  endif

  do i = 1, size(s_dat)
    if (size(s_set) == 1) then
      tmpstr = s_set(1)%s
      s_dat(i)%s = tmpstr
      ! s_dat(i)%s = s_set(1)%s
    else
      tmpstr = s_set(i)%s
      s_dat(i)%s = tmpstr
      ! s_dat(i)%s = s_set(i)%s
    endif
  enddo

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

endif

do i = 1, size(d_dat)
  if (.not. d_dat(i)%d%exists) cycle
  u => s%u(d_dat(i)%d%d1%d2%ix_uni)  
  call tao_evaluate_a_datum (d_dat(i)%d, u, u%model, d_dat(i)%d%model_value, valid_value)
enddo

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
  call tao_integer_set_value (s%com%default_universe, 'UNIVERSE', value_str, &
                                                                     err, lbound(s%u, 1), ubound(s%u, 1))
  if (err) return
  call tao_turn_on_chrom_or_rad_int_calcs_if_needed_for_plotting()

case ('branch')
  u => tao_pointer_to_universe(-1)
  call tao_integer_set_value (s%com%default_branch, 'BRANCH', value_str, err, 0, ubound(u%model%lat%branch, 1))
  if (err) return

end select


end subroutine tao_set_default_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_universe_cmd (uni, who, what)
!
! Sets a universe on or off, or sets the recalculate or mat6_recalc logicals, etc.
!
! Input:
!   uni     -- Character(*): which universe; 0 => current viewed universe
!   who     -- Character(*): "on", "off", "recalculate", "dynamic_aperture_calc", "one_turn_map_calc", or "mat6_recalc"
!   what    -- Character(*): "on" or "off" for who = "dynamic_aperture_calc", "one_turn_map_calc" or "mat6_recalc".
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

!

if (index('mat6_recalc', trim(who)) == 1) then
  if (what == 'on') then
    is_on = .true.
  elseif (what == 'off') then
    is_on = .false.
  else
    call out_io (s_error$, r_name, 'Syntax is: "set universe <uni_num> mat6_recalc on/off"')
    return
  endif
  if (uni == '*') then
    s%u(:)%calc%mat6 = is_on
    if (is_on) s%u(:)%calc%lattice = .true.
  else
    s%u(n_uni)%calc%mat6 = is_on
    if (is_on) s%u(n_uni)%calc%lattice = .true.
  endif
  return
endif
  
if (index('track_recalc', trim(who)) == 1) then
  if (what == 'on') then
    is_on = .true.
  elseif (what == 'off') then
    is_on = .false.
  else
    call out_io (s_error$, r_name, 'Syntax is: "set universe <uni_num> track_recalc on/off"')
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
  
!

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

if (who == 'on') then
  is_on = .true.
elseif (who == 'off') then
  is_on = .false.
else
  call out_io (s_error$, r_name, "Choices are: 'on', 'off', 'recalculate', 'track_recalc', or 'mat6_recalc")
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
! Subroutine tao_set_element_cmd (ele_list, attribute, value)
!
! Sets a universe on or off, or sets the recalculate or mat6_recalc logicals
!
! Input:
!   ele_list   -- Character(*): which elements.
!   attribute  -- Character(*): Attribute to set.
!   value      -- Character(*): Value to set.
!-

subroutine tao_set_elements_cmd (ele_list, attribute, value)

implicit none

type (ele_pointer_struct), allocatable, save :: eles(:)
type (tao_universe_struct), pointer :: u

integer i, j, n_uni, n_set

character(*) ele_list, attribute, value
character(*), parameter :: r_name = "tao_set_elements_cmd"

logical is_on, err, mat6_toggle

! Find elements

call tao_locate_all_elements (ele_list, eles, err)
if (err) return

! Set attribute.
! When a wild card is used so there are multiple elements involved, an error
! generated by some, but not all elements is not considered a true error.
! For example: "set ele * csr_calc_on = t" is not valid for markers.

n_set = 0
do i = 1, size(eles)
  u => s%u(eles(i)%id)
  call set_ele_attribute (eles(i)%ele, trim(attribute) // '=' // trim(value), u%model%lat, err, .false.)
  u%calc%lattice = .true.
  if (.not. err) n_set = n_set + 1
enddo

! If there is a true error then generate an error message

if (n_set == 0) then
  u => s%u(eles(1)%id)
  call set_ele_attribute (eles(1)%ele, trim(attribute) // '=' // trim(value),  u%model%lat, err)
  u%calc%lattice = .true.
  return
endif

if (n_set /= size(eles)) then
  call out_io (s_info$, r_name, 'Set successful for \i0\ elements out of \i0\ ', i_array = [n_set, size(eles)])
endif

do i = lbound(s%u, 1), ubound(s%u, 1)
  u => s%u(i)
  if (.not. u%calc%lattice) cycle
  call lattice_bookkeeper (u%model%lat)
  do j = 0, ubound(u%model%lat%branch, 1)
    call lat_make_mat6 (u%model%lat, -1, u%model%lat_branch(j)%orbit, j)
  enddo
enddo

end subroutine tao_set_elements_cmd

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_logical_set_value (var, var_str, value_str, error)
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

subroutine tao_logical_set_value (var, var_str, value_str, error)

implicit none

logical var, ix
integer ios

character(*) var_str, value_str
character(*), parameter :: r_name = 'tao_logical_set_value'
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

end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_integer_set_value (var, var_str, value_str, error, min_val, max_val)
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
!
! Output:
!   var   -- Integer: Variable to set.
!   error -- Logical: Set True on an error. False otherwise.
!-

subroutine tao_integer_set_value (var, var_str, value_str, error, min_val, max_val)

implicit none

integer var
integer, optional :: min_val, max_val
integer ios, ix

character(*) var_str, value_str
character(*), parameter :: r_name = 'tao_integer_set_value'
logical error

!

error = .true.
read (value_str, *, iostat = ios) ix

if (ios /= 0 .or. len_trim(value_str) == 0) then
  call out_io (s_error$, r_name, 'BAD ' // trim(var_str) // ' VALUE.')
  return
endif

if (present(min_val)) then
  if (ix < min_val) then
    call out_io (s_error$, r_name, var_str // ' VALUE TOO SMALL.')
    return 
  endif
endif

if (present(max_val)) then
  if (ix > max_val) then
    call out_io (s_error$, r_name, var_str // ' VALUE TO LARGE.')
    return 
  endif
endif


var = ix      
error = .false.

end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_real_set_value (var, var_str, value_str, error, min_val, max_val)
!
! Subroutine to read and set the value of a real varialbe.
!
! If the value is out of the range [min_val, max_val] then an error message will
! be generated and the variable will not be set.
!
! Input:
!   var_str   -- Character(*): Used for error messages.
!   value_str -- Character(*): String with encoded value.
!   min_val   -- real(rp), optional: Minimum value. 
!   max_val   -- real(rp), optional: Maximum value.
!
! Output:
!   var   -- real(rp): Variable to set.
!   error -- Logical: Set True on an error. False otherwise.
!-

subroutine tao_real_set_value (var, var_str, value_str, error, min_val, max_val)

implicit none

real(rp) var, var_value
real(rp), optional :: min_val, max_val
integer ios

character(*) var_str, value_str
character(20) :: r_name = 'tao_real_set_value'
logical error

!

error = .true.
read (value_str, *, iostat = ios) var_value

if (ios /= 0 .or. len_trim(var_str) == 0) then
  call out_io (s_error$, r_name, 'BAD ' // trim(var_str) // ' VALUE.')
  return
endif

if (present(min_val)) then
  if (var_value < min_val) then
    call out_io (s_error$, r_name, var_str // ' VALUE OUT OF RANGE.')
    return
  endif
endif

if (present(max_val)) then
  if (var_value > max_val) then
    call out_io (s_error$, r_name, var_str // ' VALUE OUT OF RANGE.')
    return
  endif
endif

var = var_value
error = .false.

end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_set_drawing_cmd (drawing, component, set_value)
!
! Routine to set floor_plan and lat_layout parameters.
! 
! Input:
!   component -- Character(*): Which drawing component to set.
!   set_value -- Character(*): Value to set to.
!
! Output:
!    s%shape  -- Shape variables structure.
!-

subroutine tao_set_drawing_cmd (drawing, component, set_value)

implicit none

type (tao_drawing_struct) drawing
type (tao_ele_shape_struct) shape(50)

character(*) component, set_value
character(60) str
character(20) :: r_name = 'tao_set_drawing_cmd'

integer i, ix, n, iu, ios

logical err, needs_quotes

namelist / params / shape

! Init

n = size(drawing%ele_shape)
shape(1:n) = drawing%ele_shape

! Setup

needs_quotes = .false.
ix = index(component, '%')

if (ix /= 0) then
  str = 'shape(' // component(6:ix-1) // ')%' // component(ix+1:)
  select case (component(ix+1:))
  case ('shape', 'color', 'label', 'ele_name')
    needs_quotes = .true.
  end select
  if (set_value(1:1) == "'" .or. set_value(1:1) == '"') needs_quotes = .false.

else
  str = component
endif

! open a scratch file for a namelist read

iu = lunget()
open (iu, status = 'scratch', iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN A SCRATCH FILE!')
  return
endif

write (iu, *) '&params'
if (needs_quotes) then
  write (iu, *) trim(str) // ' = "' // trim(set_value) // '"'
else
  write (iu, *) trim(str) // ' = ' // trim(set_value)
endif
write (iu, *) '/'
write (iu, *)
rewind (iu)
read (iu, nml = params, iostat = ios)
close (iu)

if (ios /= 0) then
  call out_io (s_error$, r_name, 'BAD COMPONENT OR NUMBER')
  return
endif

! Cleanup

do i = 1, n
  call str_upcase (shape(i)%ele_id,   shape(i)%ele_id)
  call str_upcase (shape(i)%shape,    shape(i)%shape)
  call str_upcase (shape(i)%color,    shape(i)%color)
  call downcase_string (shape(i)%label)
  call tao_string_to_element_id (shape(i)%ele_id, shape(i)%ix_ele_key, shape(i)%name_ele, err, .true.)
  if (err) return
enddo

n = size(drawing%ele_shape)
drawing%ele_shape(1:n) = shape

end subroutine tao_set_drawing_cmd

end module tao_set_mod
