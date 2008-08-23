!+
! Program synradv.f90
!
! Synrad command line version of CESRV.
!-

program synradv

use cesrv_struct
use cesrv_interface
use super_universe_com
use sr_mod
use synrad_plot_mod
use synrad_output_mod
use synrad_window_mod

implicit none

type (walls_struct) walls
type (universe_struct), pointer :: u
type (logic_struct),target :: logic
type (graph_struct), target :: graph

type (lat_struct) p_ring, e_ring
type (synrad_param_struct) gen_params
type (coord_struct), allocatable :: p_orb(:), e_orb(:)
type (ele_power_struct), allocatable :: e_power(:), p_power(:)
type (crotch_window_struct) window(n_windows$)

integer ios, ix, i, n, iw(n_windows$)
logical err_flag, hit
character*80 line

!----------------------------------------------------------------------------
! init

call mpm_init

allocate (super%u_(1))
u => super%u_(1)
super%logic => logic

logic%u_num = 1
logic%u_view = 1

call init_logic (logic)
call init_universe (u, logic)
call init_plotting(.true., graph, u, logic)
call init_init(u, graph, logic,'')

call plotdo('X', graph, .false., u, logic)

!

n = u%ring%n_ele_max
allocate (p_orb(0:n), e_orb(0:n))
allocate (p_power(n), e_power(n))

! Not using a gui

logic%gui = .false.

! see if there is an init file

open (unit = 10 , file = 'cesrv.in', status = 'old', iostat = ios)
if (ios == 0) then  ! opened
  logic%command_file_open = .true.
  print *, 'INIT COMMAND FILE FOUND: CESRV.IN ....'
endif
call read_outline(walls, u%ring,.true.)
call find_windows (walls%positive_x_wall, window)


!---------------------------------------------------------------------
! Command loop

main_loop: do while (.true.)

  print *
  if (.not. logic%command_file_open) then
    print '(a, $)', ' SYNRAD> '
    accept '(a)', line
  endif

  call string_trim (line, line, ix)
  call str_upcase (line, line)

  if (line(1:ix) == 'SYNRAD') then
    call do_synrad (walls, u, u%ring, gen_params, window)
  elseif (line(1:ix) == 'SEXT') then
    call sextupole_output (u)
  elseif (line(1:ix) == 'SR') then
    call do_synrad (walls, u, u%ring, gen_params, window)
  elseif (line(1:ix) == 'HARD') then
    print *, 'NOT YET IMPLEMENTED...'
  elseif (line(1:ix) == 'ROUT') then
    call ray_output (window, u%ring)
  elseif (line(1:ix) == 'RP') then
    print *, '*** Only first window selected will be plotted. ***'
    call get_window_numbers ( window, iw )
    call ray_plot (window, iw(1))
  elseif (line(1:ix) == 'RPLOT') then
    print *, '*** Only first window selected will be plotted. ***'
    call get_window_numbers ( window, iw )
    call ray_plot (window, iw(1))
  elseif (line(1:ix) == 'RAYPLOT') then
    print *, '*** Only first window selected will be plotted. ***'
    call get_window_numbers ( window, iw )
    call ray_plot (window, iw(1))
  elseif (line(1:ix) == 'BURN') then
    print *, '*** Only first window selected will be plotted. ***'
    call get_window_numbers ( window, iw )
    call burn_plot ( window, iw(1), u%ring, gen_params, logic )
  elseif (line(1:ix) == 'RO') then
    call ray_output (window, u%ring)
  elseif (line(1:ix) == 'RAYOUT') then
    call ray_output (window, u%ring)
  elseif (line(1:ix) == 'RAYOUTPUT') then
    call ray_output (window, u%ring)
  elseif (line(1:ix) == 'PR') then
    call project_from_windows ( window )
  elseif (line(1:ix) == 'PROJ') then
    call project_from_windows ( window )
  elseif (line(1:ix) == 'PROJECT') then
    call project_from_windows ( window )
  elseif (line(1:ix) == 'FW') then
    call find_windows (walls%positive_x_wall, window)
  elseif (line(1:ix) == 'FINDWIND') then
    call find_windows (walls%positive_x_wall, window)
  elseif (line(1:ix) == 'FINDWINDOW') then
    call find_windows (walls%positive_x_wall, window)
  elseif (line(1:ix) == 'FINDWINDOWS') then
    call find_windows (walls%positive_x_wall, window)

  elseif (line(1:ix) == 'CHECK') then
    call check_aperture(u, hit)

  elseif (line(1:ix) == 'IW') then
    if (.not.logic%ring_initialized) then
      print *, 'Please pick Lattice first...'
      call cesrv_command('L:', u, graph, logic, err_flag)
    endif
    call read_outline(walls,u%ring,.true.)

  elseif (line(1:ix) == 'INITWALLS') then
    if (.not.logic%ring_initialized) then
      print *, 'Please pick Lattice first...'
      call cesrv_command('L:', u, graph, logic, err_flag)
    endif
    call read_outline(walls,u%ring,.true.)

  else
    call cesrv_command(line, u, graph, logic, err_flag)
  endif

end do main_loop

end program
