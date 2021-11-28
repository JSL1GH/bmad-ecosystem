!+
! Subroutine tao_command (command_line, err, err_is_fatal)
!
! Interface to all standard (non hook) tao commands. 
! This routine esentially breaks the command line into words
! and then calls the appropriate routine.
! Commands are case sensitive.
!
! Input:
!   command_line  -- character(*): command line
!
! Output:
!  err            -- logical: Set True on error. False otherwise.
!  err_is_fatal   -- logical: Set True on non-recoverable error. False otherwise
!-

subroutine tao_command (command_line, err, err_is_fatal)

use tao_set_mod, dummy2 => tao_command
use tao_change_mod, only: tao_change_var, tao_change_ele, tao_dmodel_dvar_calc
use tao_command_mod, only: tao_cmd_split, tao_re_execute
use tao_data_and_eval_mod, only: tao_to_real
use tao_misalign_mod, only: tao_misalign
use tao_scale_mod, only: tao_scale_cmd
use tao_wave_mod, only: tao_wave_cmd
use tao_x_scale_mod, only: tao_x_scale_cmd
use tao_plot_window_mod, only: tao_destroy_plot_window

! MPI use tao_mpi_mod

implicit none

type (tao_universe_struct), pointer :: u
type (lat_struct), pointer :: lat

integer i, j, n, iu, ios, n_word, n_eq, stat
integer ix, ix_line, ix_cmd, which
integer int1, int2, uni, wrt, n_level

real(rp) value1, value2, time

character(*) :: command_line
character(len(command_line)) cmd_line
character(20) :: r_name = 'tao_command'
character(300) :: cmd_word(12)
character(40) gang_str, switch, word, except
character(16) cmd_name, set_word, axis_name

character(16) :: cmd_names(41) = [ &
    'quit         ', 'exit         ', 'show         ', 'plot         ', 'place        ', &
    'clip         ', 'scale        ', 'veto         ', 'use          ', 'restore      ', &
    'run_optimizer', 'flatten      ', 'change       ', 'set          ', 'cut_ring     ', &
    'call         ', 'ptc          ', 'alias        ', 'help         ', 'single_mode  ', &
    're_execute   ', 'reinitialize ', 'x_scale      ', 'x_axis       ', 'derivative   ', &
    'spawn        ', 'xy_scale     ', 'read         ', 'misalign     ', 'end_file     ', &
    'pause        ', 'continue     ', 'wave         ', 'timer        ', 'write        ', &
    'python       ', 'json         ', 'quiet        ', 'ls           ', 'taper        ', &
    'clear        ']

character(16) :: cmd_names_old(6) = [&
    'x-scale      ', 'xy-scale     ', 'single-mode  ', 'x-axis       ', 'end-file     ', &
    'output       ']

logical quit_tao, err, err_is_fatal, silent, gang, abort, err_flag, ok
logical include_wall, update, exact, include_this

! blank line => nothing to do

err_is_fatal = .false.
err = .false.

call string_trim (command_line, cmd_line, ix_line)
if (ix_line == 0 .or. cmd_line(1:1) == '!') return

! '/' denotes an option so put a space before it so it does not look like part of the command.

ix = index(cmd_line(1:ix_line), '/')
if (ix /= 0) then
  cmd_line = cmd_line(1:ix-1) // ' ' // trim(cmd_line(ix:))
  ix_line = ix - 1
endif

! strip the command line of comments

ix = index(cmd_line, '!')
if (ix /= 0) cmd_line = cmd_line(:ix-1)        ! strip off comments

! match first word to a command name

call match_word (cmd_line, cmd_names, ix_cmd, .true., matched_name = cmd_name)

if (ix_cmd == 0) then  ! Accept old-style names with "-" instead of "_".
  call match_word (cmd_line, cmd_names_old, ix_cmd, .true., matched_name = cmd_name)
  ix = index(cmd_name, '-')
  if (ix /= 0) cmd_name(ix:ix) = '_'
  if (cmd_name == 'output') cmd_name = 'write'
endif

if (ix_cmd == 0) then
  call out_io (s_error$, r_name, 'UNRECOGNIZED COMMAND: ' // cmd_line)
  call tao_abort_command_file()
  return
elseif (ix_cmd < 0) then
  call out_io (s_error$, r_name, 'AMBIGUOUS COMMAND')
  call tao_abort_command_file()
  return
endif

! Strip off command name from cmd_line 

call string_trim (cmd_line(ix_line+1:), cmd_line, ix_line)

! Something like "set global%rf_on" gets translated to "set global rf_on"

if (cmd_name == 'set') then
  ix = index(cmd_line, '%')
  if (ix /= 0) cmd_line(ix:ix) = ' '
endif

! select the appropriate command.

select case (cmd_name)

!--------------------------------
! ALIAS

case ('alias')

  call tao_cmd_split(cmd_line, 2, cmd_word, .false., err); if (err) return
  call tao_alias_cmd (cmd_word(1), cmd_word(2))
  return

!--------------------------------
! CALL

case ('call')

  call tao_cmd_split(cmd_line, 10, cmd_word, .true., err); if (err) goto 9000
  call tao_call_cmd (cmd_word(1), cmd_word(2:10))
  return

!--------------------------------
! CHANGE

case ('change')

  call tao_cmd_split (cmd_line, 2, cmd_word, .false., err); if (err) goto 9000

  silent = .false.
  update = .false.
  do
    if (len_trim(cmd_word(1)) == 1) exit

    if (index('-silent', trim(cmd_word(1))) == 1) then
      silent = .true.
      call tao_cmd_split (cmd_word(2), 2, cmd_word, .false., err); if (err) goto 9000
    elseif (index('-update', trim(cmd_word(1))) == 1) then
      update = .true.
      call tao_cmd_split (cmd_word(2), 2, cmd_word, .false., err); if (err) goto 9000
    else
      exit
    endif
  enddo

  if (index ('variable', trim(cmd_word(1))) == 1) then
    call tao_cmd_split (cmd_word(2), 2, cmd_word, .false., err); if (err) goto 9000
    call tao_change_var (cmd_word(1), cmd_word(2), silent)
  elseif (index('element', trim(cmd_word(1))) == 1) then
    if (index('-update', trim(cmd_word(1))) == 1) then
      update = .true.
      call tao_cmd_split (cmd_word(2), 2, cmd_word, .false., err); if (err) goto 9000
    endif
    call tao_cmd_split (cmd_word(2), 3, cmd_word, .false., err); if (err) goto 9000
    call tao_change_ele (cmd_word(1), cmd_word(2), cmd_word(3), update)
  elseif (index(trim(cmd_word(1)), 'particle_start') /= 0) then     ! Could be "2@particle_start"
    word = cmd_word(1)
    call tao_cmd_split (cmd_word(2), 2, cmd_word, .false., err); if (err) goto 9000
    call tao_change_ele (word, cmd_word(1), cmd_word(2), .false.)
  else
    call out_io (s_error$, r_name, 'Change who? (should be: "element", "particle_start", or "variable")')
  endif

!--------------------------------
! CLEAR

case ('clear')

  call tao_clear_cmd(cmd_line)

!--------------------------------
! CLIP

case ('clip')

  call tao_cmd_split (cmd_line, 4, cmd_word, .true., err); if (err) return

  gang = .false.
  if (index('-gang', trim(cmd_word(1))) == 1 .and. len_trim(cmd_word(1)) > 1) then
    gang = .true.
    cmd_word(1:3) = cmd_word(2:4)
  endif

  if (cmd_word(2) == ' ') then
    call tao_clip_cmd (gang, cmd_word(1), 0.0_rp, 0.0_rp) 
  else
    call tao_to_real (cmd_word(2), value1, err);  if (err) return
    if (cmd_word(3) /= ' ') then
      call tao_to_real (cmd_word(3), value2, err);  if (err) return
    else
      value2 = value1
      value1 = -value1
    endif
    call tao_clip_cmd (gang, cmd_word(1), value1, value2)
  endif

!--------------------------------
! CONTINUE

case ('continue')

  n_level = s%com%cmd_file_level
  if (s%com%cmd_file(n_level)%paused) then
    s%com%cmd_file(n_level)%paused = .false.
  else
    call out_io (s_error$, r_name, 'NO PAUSED COMMAND FILE HERE.')
  endif

  return

!--------------------------------
! CUT_RING

case ('cut_ring')

  u => tao_pointer_to_universe(-1)
  lat => u%model%lat

  lat%param%geometry = open$
  u%calc%lattice = .true.
  u%model%lat%particle_start%vec = 0
  call tao_lattice_calc (ok)

  return

!--------------------------------
! DERIVATIVE

case ('derivative')

  call tao_dmodel_dvar_calc(.true., err_flag)
  call out_io (s_blank$, r_name, 'Derivative calculated')

  return

!--------------------------------
! END_FILE

case ('end_file')

  n_level = s%com%cmd_file_level
  if (n_level == 0) then
    call out_io (s_error$, r_name, 'END_FILE COMMAND ONLY ALLOWED IN A COMMAND FILE!')
    return
  endif

  call tao_close_command_file()

  if (s%com%cmd_file(n_level-1)%paused) then
    call out_io (s_info$, r_name, 'To continue the paused command file type "continue".')
  endif

  return

!--------------------------------
! EXIT/QUIT

case ('exit', 'quit')

  call string_trim (command_line, cmd_line, ix)
  if (ix < 3) then
    call out_io (s_error$, r_name, &
            'SAFETY FEATURE: YOU NEED TO TYPE AT LEAST THREE CHARACTERS TO QUIT.')
    return
  endif

  if (s%global%plot_on) call tao_destroy_plot_window
  call out_io (s_dinfo$, r_name, "Stopping.")
  !MPI !Finalize MPI if it is on
  !MPI if (s%mpi%on) call tao_mpi_finalize()
  stop
 
!--------------------------------
! HELP

case ('help')

  call tao_cmd_split (cmd_line, 2, cmd_word, .true., err); if (err) return
  call tao_help (cmd_word(1), cmd_word(2))
  return

!--------------------------------
! LS

case ('ls')
  call system_command ('ls ' // cmd_line, err)
  if (err) call tao_abort_command_file()
  return



!--------------------------------
! JSON
! This is experimental. Removal is a possibility if not developed.

case ('json')

  call tao_json_cmd (cmd_line)
  return

!--------------------------------
! MISALIGN

case ('misalign')

  call tao_cmd_split (cmd_line, 5, cmd_word, .true., err); if (err) goto 9000
  call tao_misalign (cmd_word(1), cmd_word(2), cmd_word(3), cmd_word(4), cmd_word(5))

!--------------------------------
! PAUSE

case ('pause')

  time = 0
  call tao_cmd_split (cmd_line, 1, cmd_word, .true., err); if (err) return
  if (cmd_word(1) /= '') then
    read (cmd_word(1), *, iostat = ios) time
    if (ios /= 0) then
      call out_io (s_error$, r_name, 'TIME IS NOT A NUMBER.')
      return
    endif
  endif

  call tao_pause_cmd (time)
  return

!--------------------------------
! PLACE

case ('place')

  call tao_cmd_split (cmd_line, 3, cmd_word, .true., err); if (err) return

  if (index('-no_buffer', trim(cmd_word(1))) == 1) then
    call tao_place_cmd (cmd_word(2), cmd_word(3), .true.)

  else
    if (cmd_word(3) /= ' ') then
      call out_io (s_error$, r_name, 'BAD PLACE COMMAND: ' // command_line)
      return
    endif
    call tao_place_cmd (cmd_word(1), cmd_word(2))
  endif

!--------------------------------
! PLOT
! NOTE: THIS COMMAND IS DEPRECATED 8/2021.

case ('plot')

  call out_io (s_error$, r_name, 'The "plot" command has been replaced by the "set plot <plot_name> component = ..." command.')
  return

!--------------------------------
! PTC

case ('ptc')

  call tao_cmd_split (cmd_line, 2, cmd_word, .false., err); if (err) goto 9000

  call tao_ptc_cmd (cmd_word(1), cmd_word(2))
  return

!--------------------------------
! PYTHON

case ('python')

  call tao_python_cmd (cmd_line)
  return

!--------------------------------
! QUIET

case ('quiet')

if (s%com%cmd_file_level == 0) then 
  call out_io (s_error$, r_name, 'The "quiet" command has been replaced by the "set global quiet = <action>" command.')
  return
endif

!--------------------------------
! RE_EXECUTE

case ('re_execute')

  call tao_re_execute (cmd_line, err)
  return

!--------------------------------
! READ

case ('read')

  silent = .false.
  call tao_cmd_split (cmd_line, 5, cmd_word, .true., err); if (err) goto 9000
  word = ''
  do i = 1, 5
    if (cmd_word(i) == '') exit
    call match_word (cmd_word(i), [character(16):: '-universe', '-silent'], ix, .true., matched_name=switch)
    select case (switch)
    case ('-silent')
      silent = .true.
    case ('-universe')
      word = cmd_word(i+1)
      cmd_word(i:i+1) = cmd_word(i+2:i+3)
      exit
    end select
  enddo

  call tao_read_cmd (cmd_word(1), word, cmd_word(2), silent)

!--------------------------------
! RESTORE, USE, VETO

case ('restore', 'use', 'veto')

  call tao_cmd_split(cmd_line, 2, cmd_word, .true., err);  if (err) goto 9000
  
  call match_word (cmd_word(1), [character(8) :: "data", "variable"], which, .true., matched_name = switch)

  select case (switch)
  case ('data')
    call tao_use_data (cmd_name, cmd_word(2))
  case ('variable')
    call tao_use_var (cmd_name, cmd_word(2))
  case default
    call out_io (s_error$, r_name, "Use/veto/restore what? data or variable?")
    return
  end select

!--------------------------------
! REINITIALIZE

case ('reinitialize')

  call tao_cmd_split(cmd_line, 2, cmd_word, .false., err);  if (err) goto 9000

  call match_word (cmd_word(1), ['data', 'tao ', 'beam'], ix, .true., matched_name=word)

  select case (word)

  case ('beam') 
    do i = lbound(s%u, 1), ubound(s%u, 1)
      s%u(i)%model_branch(:)%beam%init_starting_distribution = .true.
      s%u(i)%calc%lattice = .true.
    enddo

  case ('data') 
    s%u(:)%calc%lattice = .true.

  case ('tao') 
    call tao_parse_command_args (err, cmd_word(2));  if (err) goto 9000

    if (s%init%init_file_arg /= '') call out_io (s_info$, r_name, 'Reinitializing with: ' // s%init%init_file_arg)
    call tao_init (err_is_fatal)
    return

  case default
    call out_io (s_error$, r_name, 'Reinit what? Choices are: "beam", "data", or "tao".')
    return
    
  end select

!--------------------------------
! RUN, FLATTEN

case ('run_optimizer', 'flatten')

  call tao_cmd_split (cmd_line, 1, cmd_word, .true., err); if (err) goto 9000
  call tao_run_cmd (cmd_word(1), abort)

!--------------------------------
! SCALE

case ('scale')

  call tao_cmd_split (cmd_line, 7, cmd_word, .true., err); if (err) return

  axis_name = ''
  gang_str = ''
  include_wall = .false.
  exact = .false.

  i = 1
  do
    if (cmd_word(i) == '') exit
    call match_word (cmd_word(i), [character(16):: '-y', '-y2', '-nogang', '-gang', '-include_wall', '-exact'], &
                                                                                     ix, .true., matched_name=switch)

    select case (switch)
    case ('-exact');            exact = .true.
    case ('-y', '-y2');         axis_name = switch(2:)
    case ('-gang', '-nogang');  gang_str = switch(2:)
    case ('-include_wall');     include_wall = .true.
    case default;               i = i + 1;  cycle
    end select

    cmd_word(i:i+6) = cmd_word(i+1:i+7)
  enddo

  if (cmd_word(2) == ' ') then
    call tao_scale_cmd (cmd_word(1), 0.0_rp, 0.0_rp, axis_name, include_wall, gang_str)
  else
    call tao_to_real (cmd_word(2), value1, err);  if (err) return
    if (cmd_word(3) /= ' ') then
      call tao_to_real (cmd_word(3), value2, err);  if (err) return
    else
      value2 = value1
      value1 = -value1
    endif
    call tao_scale_cmd (cmd_word(1), value1, value2, axis_name, include_wall, gang_str, exact)
  endif

!--------------------------------
! SET

case ('set')
  update = .false.

  call tao_cmd_split (cmd_line, 2, cmd_word, .false., err, '=')
  if (index('-update', trim(cmd_word(1))) == 1 .and. len_trim(cmd_word(1)) > 1) then
    update = .true.
    cmd_line = cmd_word(2)
    call tao_cmd_split (cmd_line, 2, cmd_word, .false., err, '=')
  endif

  call match_word (cmd_word(1), [character(20) :: 'branch', 'data', 'var', 'lattice', 'global', &
    'universe', 'curve', 'graph', 'beam_init', 'wave', 'plot', 'bmad_com', 'element', 'opti_de_param', &
    'csr_param', 'floor_plan', 'lat_layout', 'geodesic_lm', 'default', 'key', 'particle_start', &
    'plot_page', 'ran_state', 'symbolic_number', 'beam', 'beam_start', 'dynamic_aperture', &
    'region', 'calculate'], ix, .true., matched_name = set_word)
  if (ix < 1) then
    call out_io (s_error$, r_name, 'NOT RECOGNIZED OR AMBIGUOUS: ' // cmd_word(1))
    goto 9000
  endif

  cmd_line = cmd_word(2)
  select case (set_word)
  case ('ran_state'); n_word = 2; n_eq = 1
  case ('beam', 'beam_init', 'bmad_com', 'csr_param', 'data', 'global', 'lattice', 'default', &
        'opti_de_param', 'wave', 'floor_plan', 'lat_layout', 'geodesic_lm', 'key', 'symbolic_number', &
        'var', 'beam_start', 'particle_start', 'dynamic_aperture'); n_word = 3; n_eq = 2
  case ('universe'); n_word = 4; n_eq = 3
  case ('plot_page'); n_word = 4; n_eq = 2
  case ('branch', 'curve', 'element', 'graph', 'plot', 'region'); n_word = 4; n_eq = 3
  case ('calculate'); n_word = 1; n_eq = 0
  end select

  ! Split command line into words. Translate "set ele q[k1]" -> "set ele q k1"

  call tao_cmd_split (cmd_line, n_word, cmd_word, .false., err, '=')

  if  (set_word == 'element' .and. index('-update', trim(cmd_word(1))) == 1 .and. len_trim(cmd_word(1)) > 1) then
    update = .true.
    call tao_cmd_split (cmd_line, 5, cmd_word, .false., err, '=')
    cmd_word(1:4) = cmd_word(2:5)
  endif

  if (set_word == 'element' .and. index(cmd_word(1), '[') /= 0) then
    n = len_trim(cmd_word(1)) 
    if (cmd_word(1)(n:n) /= ']') then
      call out_io (s_error$, r_name, 'CANNOT DECODE: ' // cmd_word(1))
      goto 9000
    endif
    ix = index(cmd_word(1), '[') 
    cmd_word(3:5) = cmd_word(2:4)
    cmd_word(2) = cmd_word(1)(ix+1:n-1)
    cmd_word(1) = cmd_word(1)(1:ix-1)
  endif

  !

  if (set_word == 'universe' .and. cmd_word(3) /= '=') then  ! Old syntax
    cmd_word(4) = cmd_word(3)
    cmd_word(3) = '='
  endif

  if (n_eq > 0) then
    if (cmd_word(n_eq) /= '=') then
      call out_io (s_error$, r_name, 'SYNTAX PROBLEM. "=" NOT IN CORRECT PLACE.')
      goto 9000
    endif
  endif

  select case (set_word)
  case ('beam')
    call tao_set_beam_cmd (cmd_word(1), cmd_word(3))
  case ('beam_init')
    call tao_set_beam_init_cmd (cmd_word(1), cmd_word(3))
  case ('beam_start', 'particle_start')
    if (set_word == 'beam_start') call out_io (s_warn$, r_name, 'Note: "beam_start" is now named "particle_start".')
    call tao_set_particle_start_cmd (cmd_word(1), cmd_word(3))
  case ('bmad_com')
    call tao_set_bmad_com_cmd (cmd_word(1), cmd_word(3))
  case ('branch')
    call tao_set_branch_cmd (cmd_word(1), cmd_word(2), cmd_word(4)) 
  case ('calculate')
    call tao_set_calculate_cmd (cmd_word(1))
  case ('csr_param')
    call tao_set_csr_param_cmd (cmd_word(1), cmd_word(3))
  case ('curve')
    call tao_set_curve_cmd (cmd_word(1), cmd_word(2), cmd_word(4)) 
  case ('data')
    call tao_set_data_cmd (cmd_word(1), cmd_word(3))
  case ('default')
    call tao_set_default_cmd (cmd_word(1), cmd_word(3))
  case ('dynamic_aperture')
    call tao_set_dynamic_aperture_cmd (cmd_word(1), cmd_word(3))
  case ('element')
    call tao_set_elements_cmd (cmd_word(1), cmd_word(2), cmd_word(4), update)
  case ('geodesic_lm')
    call tao_set_geodesic_lm_cmd (cmd_word(1), cmd_word(3))
  case ('global')
    call tao_set_global_cmd (cmd_word(1), cmd_word(3))
  case ('graph')
    call tao_set_graph_cmd (cmd_word(1), cmd_word(2), cmd_word(4))
  case ('key')
    call tao_set_key_cmd (cmd_word(1), cmd_word(3))    
  case ('lattice')
    call tao_set_lattice_cmd (cmd_word(1), cmd_word(3))
  case ('opti_de_param')
    call tao_set_opti_de_param_cmd (cmd_word(1), cmd_word(3))
  case ('plot ')
    call tao_set_plot_cmd (cmd_word(1), cmd_word(2), cmd_word(4))
  case ('plot_page')
    call tao_set_plot_page_cmd (cmd_word(1), cmd_word(3), cmd_word(4))
  case ('ran_state')
    call tao_set_ran_state_cmd (cmd_word(2))
  case ('region')
    call tao_set_region_cmd (cmd_word(1), cmd_word(2), cmd_word(4))
  case ('symbolic_number')
    call tao_set_symbolic_number_cmd(cmd_word(1), cmd_word(3))
  case ('floor_plan')
    call tao_set_drawing_cmd (s%plot_page%floor_plan, cmd_word(1), cmd_word(3))
  case ('lat_layout')
    call tao_set_drawing_cmd (s%plot_page%lat_layout, cmd_word(1), cmd_word(3))
  case ('universe')    
    call tao_set_universe_cmd (cmd_word(1), cmd_word(2), cmd_word(4))
  case ('var')
    call tao_set_var_cmd (cmd_word(1), cmd_word(3))
  case ('wave')
    call tao_set_wave_cmd (cmd_word(1), cmd_word(3), err);  if (err) goto 9000
    call tao_cmd_end_calc
    call tao_show_cmd ('wave')
  end select

!--------------------------------
! SHOW

case ('show')

  call tao_show_cmd (cmd_line)
  return

!--------------------------------
! SINGLE-MODE

case ('single_mode')

  if (cmd_line /= '') then
    call out_io (s_error$, r_name, 'Extra stuff on line: ' // cmd_line)
    return
  endif

  s%com%single_mode = .true.
  call out_io (s_blank$, r_name, 'Entering Single Mode...')
  return

!--------------------------------
! SPAWN

case ('spawn')

  call system_command (cmd_line, err)
  if (err) call tao_abort_command_file()
  return

!--------------------------------
! taper

case ('taper')

  except = ''
  word = ''

  call tao_cmd_split (cmd_line, 4, cmd_word, .true., err); if (err) return

  i = 0
  do
    i = i + 1
    if (cmd_word(i) == '') exit
    call match_word (cmd_word(i), [character(20):: '-universe', '-except'], ix, .true., matched_name=switch)

    select case (switch)
    case ('-except')
      i = i + 1
      except = cmd_word(i)
    case ('-universe')
      i = i + 1
      word = cmd_word(i)
    case default
      call out_io (s_error$, r_name, 'UNKNOWN SWITCH: ' // cmd_word(1))
      return
    end select
  enddo

  call tao_taper_cmd(except, word)
  call tao_cmd_end_calc
  return

!--------------------------------
! timer

case ('timer')

  call tao_timer (cmd_line)
  return

!--------------------------------
! WAVE

case ('wave')

  call tao_cmd_split (cmd_line, 2, cmd_word, .true., err); if (err) return
  call tao_wave_cmd (cmd_word(1), cmd_word(2), err); if (err) return
  call tao_cmd_end_calc
  call tao_show_cmd ('wave')
  return

!--------------------------------
! write

case ('write')

  call tao_write_cmd (cmd_line)
  return

!--------------------------------
! X_AXIS

case ('x_axis')

  call tao_cmd_split (cmd_line, 2, cmd_word, .true., err); if (err) return
  call tao_x_axis_cmd (cmd_word(1), cmd_word(2))

!--------------------------------
! X_SCALE

case ('x_scale')

  call tao_cmd_split (cmd_line, 5, cmd_word, .true., err); if (err) return

  gang_str = ''
  include_wall = .false.
  exact = .false.

  i = 1
  do
    if (cmd_word(i) == '') exit
    call match_word (cmd_word(i), [character(16):: '-nogang', '-gang', '-include_wall', '-exact'], &
                                                                               ix, .true., matched_name=switch)

    select case (switch)
    case ('-exact');            exact = .true.
    case ('-gang', '-nogang');  gang_str = switch(2:)
    case ('-include_wall');     include_wall = .true.
    case default;               i = i + 1;  cycle
    end select

    cmd_word(i:i+5) = cmd_word(i+1:i+6)
  enddo

  if (cmd_word(2) == ' ') then
    call tao_x_scale_cmd (cmd_word(1), 0.0_rp, 0.0_rp, err, include_wall, gang_str)
  else
    call tao_to_real (cmd_word(2), value1, err); if (err) return
    call tao_to_real (cmd_word(3), value2, err); if (err) return
    call tao_x_scale_cmd (cmd_word(1), value1, value2, err, include_wall, gang_str, exact)
  endif

!--------------------------------
! XY_SCALE

case ('xy_scale')

  call tao_cmd_split (cmd_line, 5, cmd_word, .true., err); if (err) return

  include_wall = .false.
  exact = .false.

  i = 1
  do
    if (cmd_word(i) == '') exit
    call match_word (cmd_word(i), [character(16):: '-include_wall', '-exact'], ix, .true., matched_name=switch)

    select case (switch)
    case ('-exact');            exact = .true.
    case ('-include_wall');     include_wall = .true.
    case default;               i = i + 1;  cycle
    end select

    cmd_word(i:i+5) = cmd_word(i+1:i+6)
  enddo


  if (cmd_word(2) == ' ') then
    call tao_x_scale_cmd (cmd_word(1), 0.0_rp, 0.0_rp, err, include_wall = include_wall)
    call tao_scale_cmd (cmd_word(1), 0.0_rp, 0.0_rp, include_wall = include_wall) 
  else
    call tao_to_real (cmd_word(2), value1, err);  if (err) return
    if (cmd_word(3) /= ' ') then
      call tao_to_real (cmd_word(3), value2, err);  if (err) return
    else
      value2 = value1
      value1 = -value1
    endif
    call tao_x_scale_cmd (cmd_word(1), value1, value2, err, include_wall = include_wall, exact = exact)
    call tao_scale_cmd (cmd_word(1), value1, value2, include_wall = include_wall, exact = exact)
  endif

!--------------------------------
! DEFAULT

case default

  call out_io (s_error$, r_name, 'INTERNAL COMMAND PARSING ERROR!')
  call err_exit

end select

!------------------------------------------------------------------------
! Do the standard calculations and plotting after command
! Note: wave command bypasses this.

call tao_cmd_end_calc
return

!------------------------------------------------------------------------
! Error:

9000 continue
call tao_abort_command_file()

end subroutine tao_command




