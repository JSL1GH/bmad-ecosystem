program tracking_method_test

use bmad
use tpsa

implicit none

type (lat_struct), target :: lat

character(200) :: line(10), line_debug(10)
character(100) :: lat_file  = 'tracking_method_test.bmad'
character(46) :: out_str, fmt, track_method
integer :: nargs

logical debug_mode
 
!
!switch_bessel = .false.
global_com%exit_on_error = .false.

fmt = '(a, t49, a, 7es18.10)'
track_method = ''

debug_mode = .false.
nargs = cesr_iargc()

if (nargs > 0) then
  call cesr_getarg(1, lat_file)
  call cesr_getarg(2, track_method)
  print *, 'Using ', trim(lat_file)
  debug_mode = .true.
  fmt = '(a, t49, a, 7es14.6)'
endif

call bmad_parser (lat_file, lat, .false.)

if (debug_mode) then
  if (lat%param%geometry == open$) then
    bmad_com%convert_to_kinetic_momentum = .false.
    print *, '*** Note: wiggler end kicks not cancelled (so like PTC tracking).'
  else
    bmad_com%convert_to_kinetic_momentum = .true.
    print *, '*** Note: wiggler end kicks cancelled (so like RUNGE_KUTTA tracking).'
  endif
endif

if (any(lat%particle_start%spin /= 0)) then
  bmad_com%spin_tracking_on = .true.
endif

open (1, file = 'output.now')

if (debug_mode) then
  print '(a, t36, 7es18.10)', 'Start:', lat%particle_start%vec
  print *
  print '(a, t46, a, t64, a, t82, a, t100, a, t118, a, t136, a, t143, a)', &
                            'Name: Tracking_Method', 'x', 'px', 'y', 'py', 'z', 'pz', 'dz-d(v*(t_ref-t))'
endif

call track_it (lat, 1, 1)
if (debug_mode) stop
call track_it (lat,  1, -1)
call track_it (lat, -1,  1)
call track_it (lat, -1, -1)

close(1)

!------------------------------------------------
contains

subroutine track_it(lat, ele_o_sign, orb_dir_sign)

type (lat_struct), target :: lat
type (coord_struct) start_orb, end_orb, end_bs, end_ptc
type (ele_struct), pointer :: ele
type (branch_struct), pointer :: branch
type (track_struct) track
integer ele_o_sign, orb_dir_sign
integer ib, i, j, isn

!

do ib = 0, ubound(lat%branch, 1)
  branch => lat%branch(ib)
  if (branch%param%particle == photon$ .and. (orb_dir_sign == -1 .or. ele_o_sign == -1)) cycle

  do i = 1, branch%n_ele_max - 1
    ele => branch%ele(i)
    if (ele_o_sign == -1 .and. ele%key == e_gun$) cycle
    if (ele%key == marker$ .and. ele%name == 'END') cycle
    ele%spin_tracking_method = tracking$

    isn = 0
    do j = 1, n_methods$
      if ((j == fixed_step_runge_kutta$ .or. j == fixed_step_time_runge_kutta$)) cycle
      if (track_method /= '' .and. upcase(tracking_method_name(j)) /= upcase(track_method)) cycle
      if (.not. valid_tracking_method(ele, branch%param%particle, j)) cycle
      if (j == custom$) cycle
      if (j == mad$) cycle   ! Ignore MAD
      if (j == taylor$ .and. lat%particle_start%direction == -1) cycle
      if ((orb_dir_sign == -1 .or. ele_o_sign == -1) .and. (j == taylor$ .or. j == linear$)) cycle
      ele%tracking_method = j

      if (ele%key == e_gun$ .and. (j == runge_kutta$ .or. j == fixed_step_runge_kutta$)) cycle

      if (ele%key /= taylor$) call kill_taylor(ele%taylor)

      if (ele%tracking_method == symp_lie_ptc$) then
        ele%spin_tracking_method = symp_lie_ptc$
      else
        ele%spin_tracking_method = tracking$
      endif

      if (j == linear$) then
        ele%tracking_method = symp_lie_ptc$
        if (ele%key == ac_kicker$) ele%tracking_method = bmad_standard$
        if (lat%particle_start%direction == 1) then
          call make_mat6 (ele, branch%param, lat%particle_start)
        else  ! Can happen with a test lattice file
          call make_mat6 (ele, branch%param)
        endif
        ele%tracking_method = j
      endif

      if (ele%key /= sbend$ .and. ele%key /= lcavity$ .and. ele%key /= rfcavity$ .and. .not. debug_mode) ele%orientation = ele_o_sign

      start_orb = lat%particle_start

      if (orb_dir_sign == -1 .and. .not. debug_mode) then
        start_orb%direction = -1
        lat%absolute_time_tracking = .true.
      endif

      start_orb%species = default_tracking_species(branch%param)
      if (start_orb%direction*ele%orientation == -1) start_orb%species = antiparticle(start_orb%species)

      call init_coord (start_orb, start_orb, ele, start_end$, start_orb%species, start_orb%direction, E_photon = ele%value(p0c$) * 1.006)

      start_orb%field = [1, 2]

      if (debug_mode) then
        track%n_pt = -1  ! Reset
        call track1 (start_orb, ele, branch%param, end_orb, track = track)
      else
        call track1 (start_orb, ele, branch%param, end_orb)
      endif

      if (orb_dir_sign == 1 .and. ele_o_sign == 1) then
        out_str = trim(ele%name) // ': ' // trim(tracking_method_name(j))
      elseif (orb_dir_sign == 1 .and. ele_o_sign == -1) then
        out_str = trim(ele%name) // '-Anti_O: ' // trim(tracking_method_name(j))
      elseif (orb_dir_sign == -1 .and. ele_o_sign == 1) then
        out_str = trim(ele%name) // '-Anti_D: ' // trim(tracking_method_name(j))
      else
        out_str = trim(ele%name) // '-Anti_OD: ' // trim(tracking_method_name(j))
      endif

      if (ele%key == e_gun$) then
        write (1,fmt) quote(out_str), tolerance(out_str), end_orb%vec, c_light * (end_orb%t - start_orb%t)
        if (debug_mode) print '(a30, 3x, 7es18.10)', out_str,  end_orb%vec, c_light * (end_orb%t - start_orb%t)
      else
        write (1,fmt) quote(out_str), tolerance(out_str), end_orb%vec, (end_orb%vec(5) - start_orb%vec(5)) - &
                c_light * (end_orb%beta * (ele%ref_time - end_orb%t) - start_orb%beta * (ele%ref_time - ele%value(delta_ref_time$) - start_orb%t))
        if (debug_mode) print '(a30, 3x, 7es18.10)', out_str,  end_orb%vec, (end_orb%vec(5) - start_orb%vec(5)) - &
                c_light * (end_orb%beta * (ele%ref_time - end_orb%t) - start_orb%beta * (ele%ref_time - ele%value(delta_ref_time$) - start_orb%t))
      endif

      if (ele%key == wiggler$) then
        if (j == symp_lie_bmad$) end_bs = end_orb
      else
        if (j == bmad_standard$) end_bs = end_orb
      endif

      if (j == symp_lie_ptc$) end_ptc = end_orb

      if (j == symp_lie_ptc$ .and. .not. debug_mode) then
        bmad_com%orientation_to_ptc_design = .true.
        call track1 (start_orb, ele, branch%param, end_orb)
        bmad_com%orientation_to_ptc_design = .false.
        write (1,fmt) quote(trim(out_str) // '-OD'), 'ABS 1e-10', end_orb%vec - end_ptc%vec
      endif

      if (j == bmad_standard$ .or. j == runge_kutta$ .or. j == symp_lie_ptc$ .or. j == time_runge_kutta$ .or. j == taylor$) then
        out_str = trim(out_str) // ' dSpin'
        isn=isn+1; write (line(isn), '(a, t50, a,  3f14.9, 4x, f14.9)') '"' // trim(out_str) // '"', tolerance_spin(out_str), &
                                                                end_orb%spin-start_orb%spin, norm2(end_orb%spin) - norm2(start_orb%spin)
        if (debug_mode) write(line_debug(isn), '(a40, 3f14.9, 4x, f14.9)') out_str, end_orb%spin-start_orb%spin, norm2(end_orb%spin) - norm2(start_orb%spin)
      endif

      if (branch%param%particle == photon$) then
        write (1, '(3a, t50, a, 2es18.10)') '"', trim(ele%name), ':E_Field"', 'REL 1E-07', end_orb%field
      endif
    end do

    if (isn == 0) cycle

    if (debug_mode) print '(t46, a, t60, a, t74, a, t91, a)', 'dSpin_x', 'dSpin_y', 'dSpin_z', 'dSpin_amp'
    do j = 1, isn
      write (1, '(a)') trim(line(j))
      if (debug_mode) print '(a)', trim(line_debug(j))
    enddo

    if (debug_mode) then
      print *
      print '(a, t36, 7es18.10)', 'Diff PTC - BS:', end_ptc%vec - end_bs%vec
      print *
    endif

    write (1, *)
  end do
enddo

end subroutine track_it

!--------------------------------------------------------------------------------------
! contains

character(10) function tolerance(instr)
character(*) :: instr

! There can be differences between debug and non-debug output.

  select case (instr)
    case("SBEND4: Bmad_Standard")                      ; tolerance = 'ABS 2E-13'
    case("SBEND4: Runge_Kutta")                        ; tolerance = 'ABS 1E-12'
    case("SBEND4: Linear")                             ; tolerance = 'ABS 2E-13'
    case("SBEND4: Time_Runge_Kutta")                   ; tolerance = 'ABS 1E-12'
    case("RFCAVITY1: Time_Runge_Kutta")                ; tolerance = 'ABS 2E-12'
    case("WIGGLER_FLAT1: Runge_Kutta")                 ; tolerance = 'ABS 2E-13'
    case("WIGGLER_FLAT1: Time_Runge_Kutta")            ; tolerance = 'ABS 2E-13'

    case("WIGGLER_HELI1: Time_Runge_Kutta")            ; tolerance = 'ABS 2e-13'
    case("WIGGLER_FLAT1-Anti_D: Runge_Kutta")          ; tolerance = 'ABS 2e-13'
    case("LCAVITY1-Anti_D: Runge_Kutta")               ; tolerance = 'ABS 2e-13'
    case("SBEND4-Anti_O: Bmad_Standard")               ; tolerance = 'ABS 2e-13'
    case("SBEND4-Anti_O: Runge_Kutta")                 ; tolerance = 'ABS 1e-12'
    case("SBEND4-Anti_O: Time_Runge_Kutta")            ; tolerance = 'ABS 1e-12'
    case("WIGGLER_FLAT1-Anti_O: Runge_Kutta")          ; tolerance = 'ABS 2e-13'
    case("LCAVITY1-Anti_OD: Runge_Kutta")              ; tolerance = 'ABS 2e-13'

    case("RFCAVITY1-Anti_D: Time_Runge_Kutta")         ; tolerance = 'ABS 1E-12'
    case("RFCAVITY1-Anti_O: Time_Runge_Kutta")         ; tolerance = 'ABS 4E-10'
    case("RFCAVITY1-Anti_OD: Time_Runge_Kutta")        ; tolerance = 'ABS 1E-12'
    case("WIGGLER_FLAT1-Anti_OD: Runge_Kutta")         ; tolerance = 'ABS 2E-13'
    case("WIGGLER_HELI1-Anti_D: Runge_Kutta")          ; tolerance = 'ABS 4e-13'
    case("WIGGLER_HELI1-Anti_O: Runge_Kutta")          ; tolerance = 'ABS 4e-13'                  
    case("WIGGLER_HELI1-Anti_O: Time_Runge_Kutta")     ; tolerance = 'ABS 4e-13'                  

    case default 
      if (index(instr, 'Runge_Kutta') /= 0) then
        tolerance = 'ABS 1e-13'
      else
        tolerance = 'ABS 1e-14'
      endif
  end select

end function tolerance

!--------------------------------------------------------------------------------------
! contains
  
character(10) function tolerance_spin(instr)
character(38) :: instr

  select case (instr)
    case('WIGGLER_PERIODIC1:Runge_Kutta dSpin')  ; tolerance_spin = 'ABS 2E-7'
    case default                                 ; tolerance_spin = 'ABS 1E-8'
  end select

end function tolerance_spin
end program
