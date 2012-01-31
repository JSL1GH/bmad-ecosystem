module ptc_interface_mod

use bmad_struct
use bmad_interface
use multipole_mod
use bookkeeper_mod

interface assignment (=)
  module procedure real_8_equal_taylor
  module procedure taylor_equal_real_8
  module procedure universal_equal_universal
end interface

interface operator (+)
  module procedure taylor_plus_taylor
end interface

interface operator (-)
  module procedure taylor_minus_taylor
end interface

type ptc_common_struct
  integer :: real_8_map_init               ! See PTC doc.
  integer :: taylor_order_ptc = 0          ! 0 -> not yet set 
  logical :: taylor_order_set = .false.    ! Used by set_taylor_order
end type

type (ptc_common_struct), private, save :: ptc_com

contains

!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
!+
! Function taylor_plus_taylor (taylor1, taylor2) result (taylor3)
!
! Routine to add two taylor maps.
!
! Input:
!   taylor1 -- Taylor_struct:
!   taylor2 -- Taylor_struct:
!
! Output:
!   taylor3 -- Taylor_struct:
!-

function taylor_plus_taylor (taylor1, taylor2) result (taylor3)

use polymorphic_taylor, only: kill, operator(+), real_8

implicit none

type (taylor_struct), intent(in) :: taylor1(:), taylor2(:)
type (taylor_struct) taylor3(size(taylor1))
type (real_8) y1(size(taylor1)), y2(size(taylor1)), y3(size(taylor1))

integer i

! set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

!

call real_8_init(y1)
call real_8_init(y2)
call real_8_init(y3)

y1 = taylor1
y2 = taylor2

do i = 1, size(taylor1)
  y3(i) = y1(i) + y2(i)
enddo

taylor3 = y3

call kill (y1)
call kill (y2)
call kill (y3)

end function taylor_plus_taylor

!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
!+
! Function taylor_minus_taylor (taylor1, taylor2) result (taylor3)
!
! Routine to add two taylor maps.
!
! Input:
!   taylor1 -- Taylor_struct:
!   taylor2 -- Taylor_struct:
!
! Output:
!   taylor3 -- Taylor_struct:
!-

function taylor_minus_taylor (taylor1, taylor2) result (taylor3)

use polymorphic_taylor, only: kill, operator(-), real_8

implicit none

type (taylor_struct), intent(in) :: taylor1(:), taylor2(:)
type (taylor_struct) taylor3(size(taylor1))
type (real_8) y1(size(taylor1)), y2(size(taylor1)), y3(size(taylor1))

integer i

! set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

!

call real_8_init(y1)
call real_8_init(y2)
call real_8_init(y3)

y1 = taylor1
y2 = taylor2

do i = 1, size(taylor1)
  y3(i) = y1(i) - y2(i)
enddo

taylor3 = y3

call kill (y1)
call kill (y2)
call kill (y3)

end function taylor_minus_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine set_taylor_order (order, override_flag)
!
! Subroutine to set the taylor order for the Taylor maps.
!
! Note: override_flag = .false. is generally only used by bmad_parser so that
! if the taylor order has been previously set then the setting in the 
! lattice file will not override it.
!
! Note: Calling this routine after calling bmad_parser will not reset any
! taylor maps made by bmad_parser. Thus when in doubt, call this routine
! before calling bmad_parser.
!
! Note: This routine does not call any of Etienne's PTC routines since this
! routine may be called before PTC has been initialized. This routine
! just sets a global variable and returns.
!
! Modules needed:
!   use bmad
!
! Input:
!   order         -- Integer: Taylor order.
!                     If order = 0. then nothing is done.
!   override_flag -- Logical, optional: If False then if the taylor order 
!                     has been previously set do not reset. Default is True.
!-

subroutine set_taylor_order (order, override_flag)

implicit none

integer, intent(in) :: order
logical, optional :: override_flag

! do nothing if order = 0

if (order == 0) return

if (order < 0 .or. order > 100) then
  print *, 'ERROR IN SET_TAYLOR_ORDER: ORDER OUT OF BOUNDS:', order
  if (bmad_status%exit_on_error) call err_exit
endif

! check for override_flag and do nothing if the taylor order has been set

if (.not. logic_option(.true., override_flag) .and. ptc_com%taylor_order_set) return

! set the taylor order.

bmad_com%taylor_order = order
ptc_com%taylor_order_set = .true.    

end subroutine set_taylor_order

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Function map_coef(y, i, j, k, l)
!
! Function to return the coefficient of the map y(:) up to 3rd order.
! Example: 
!   In 4-dimensional space with
!      X = (x_1, x_2, x_3, x_4)
!   And if y(:) is the map of X(in) to X(out) then
!      map_coef(y, 2, 1, 4)
!   Gives the coefficient for
!     x_2(out) = ... + coef * x_1(in) * x_4(in) + ...
!
! Notice that map_coef(y, i, j) just gives the linear (matrix) part of the map.
!
! Modules Needed:                    
!   use ptc_interface_mod
!
! Input:
!   y(:)  -- Real_8: Taylor Map.
!   i     -- Integer: output index.
!   j     -- Integer, optional: 1st input index, needed for 1st order and above.
!   k     -- Integer, optional: 2nd input index, needed for 2nd order and above.
!   l     -- Integer, optional: 3rd input index, needed for 3rd order.
!
! Output:
!   map_coef -- Real(8): Coefficient.
!-

function map_coef (y, i, j, k, l) result (m_coef)

use polymorphic_taylor, only: operator (.sub.), operator(*), real_8

implicit none

type (real_8) y(:)


real(8) m_coef

integer i
integer, optional :: j, k, l
integer arr(40), n_max, sgn, ii

character str*40
character, parameter :: str1(4) = (/ '1', '2', '3', '4' /)

logical use_bmad

!

arr = 0
sgn = 1
str = '0000000000000000000000000000000000000000'
n_max = 1

call map_index(j)
call map_index(k)
call map_index(l)

call map_index(i, ii)
m_coef = sgn * y(ii)%t .sub. str(1:n_max)

!--------------------------------------------------------------
contains

subroutine map_index (iz, i_in)

integer, optional :: iz, i_in
integer n0

!

if (.not. present(iz)) return

  n0 = iz

  if (use_bmad) then
    if (iz == 5) then
      n0 = 6
      sgn = -sgn
    elseif (iz == 6) then
      n0 = 5
    endif
  endif

! i_in is present only with the input index.

  if (present(i_in)) then
    i_in = n0
    return
  endif

  arr(n0) = arr(n0) + 1
  str(n0:n0) = str1(arr(n0))

  n_max = max(n_max, n0)

end subroutine map_index

end function map_coef

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine type_layout (lay)
!
! Subroutine to print the global information in a layout
!
! Modules Needed:
!   use ptc_interface_mod
!
! Input:
!   lay - layout: layout to use.
!+

subroutine type_layout (lay)

use s_def_all_kinds, only: layout

implicit none

type (layout) lay

!

if (.not. associated(lay%start)) then
  print *, 'Warning from TYPE_LAYOUT: Layout NOT Associated'
  return
endif

print *, 'Name:         ', lay%name
print *, 'N:            ', lay%N,        '  ! Number of Elements'
print *, 'LatPos:       ', lay%lastpos,  '  ! Last position'

end subroutine type_layout

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine lat_to_layout (lat, ptc_layout)
!
! Subroutine to create a PTC layout from a BMAD lat.
! Note: If ptc_layout has been already used then you should first do a 
!           call kill(ptc_layout)
! This deallocates the pointers in the layout
!
! Note: Before you call this routine you need to first call:
!    call set_ptc (...)
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   lat -- lat_struct: 
!
! Output:
!   ptc_layout -- Layout:
!-

subroutine lat_to_layout (lat, ptc_layout)

use s_fibre_bundle, only: ring_l, append, lp, layout, fibre
use mad_like, only: set_up, kill

implicit none

type (lat_struct), intent(in) :: lat
type (layout), intent(inout) :: ptc_layout
type (fibre), pointer :: fib

integer i

! setup

call set_up (ptc_layout)

! transfer elements.

do i = 1, lat%n_ele_track
  allocate (fib)
  call ele_to_fibre (lat%ele(i), fib, lat%param, .true.)
  call append (ptc_layout, fib)
  call kill (fib)
enddo

! circular or not?

if (lat%param%lattice_type == circular_lattice$) then
  ptc_layout%closed = .true.
  call ring_l (ptc_layout, .true._lp)
else
  ptc_layout%closed = .false.
endif

end subroutine lat_to_layout

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine type_map1 (y, type0, n_dim)
!
! Subroutine to type the transfer map up to first order.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   y(:)  -- Real_8: 
!   type0 -- Logical: Type zeroth order map
!   n_dim -- Integer: Number of dimensions to type: 4 or 6
!-

subroutine type_map1 (y, type0, n_dim)

use definition, only: real_8

implicit none

type (real_8), intent(in) :: y(:)

integer, intent(in) :: n_dim
integer :: i, j

logical, intent(in) :: type0

!

if (type0) then
  print *, '0th Order Map:'
  print '(6f11.5)', (map_coef(y(:), i), i = 1, n_dim)
  print *
endif

print *, '1st Order Map:'
do i = 1, n_dim
  print '(6f11.5)', (map_coef(y(:), i, j), j = 1, n_dim)
enddo

end subroutine type_map1

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! function kind_name (this_kind)
!
! function to return the name of a PTC kind.
!
! Input:
!   this_kind -- Integer: 
!
! Output:
!   kind_name -- Character(20): 
!-

function kind_name (this_kind)

use s_status, only: kind0, kind1, kind2, kind3, kind4, kind5, kind6, kind7, kind8, kind9, kind10

implicit none

integer this_kind
character(20) kind_name

!

select case (this_kind)
case (kind0); kind_name  = 'KIND0'
case (kind1); kind_name  = 'DRIFT1'
case (kind2); kind_name  = 'DKD2 (Gen Element)' 
case (kind3); kind_name  = 'KICKT3 (Thin Ele)'
case (kind4); kind_name  = 'CAV4 (RF Cavity)'
case (kind5); kind_name  = 'SOL5 (Solenoid)'
case (kind6); kind_name  = 'KTK (Slow Thick)'
case (kind7); kind_name  = 'TKTF (Fast Thick)'
case (kind8); kind_name  = 'NSMI (Normal SMI)'
case (kind9); kind_name  = 'SSMI (Skew SMI)'
case (kind10); kind_name = 'TEAPOT (Sector Bend)'
case default; write (kind_name, '(a, i5)') 'UNKNOWN KIND!', this_kind 
end select

end function kind_name

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine type_fibre (fib)
!
! Subroutine to print the global information in a fibre
!
! Modules Needed:
!   use ptc_interface_mod
!
! Input:
!   fib - fibre: fibre to use.
!-

subroutine type_fibre (fib)

use s_status, only: kind4, kind5, kind2, fibre

implicit none

type (fibre), intent(in) :: fib

integer i

!

if (.not. associated (fib%mag)) then
  print *, 'Warning from TYPE_FIBRE: Fibre NOT associated with anything.'
  return
endif

print *, 'Name:        ', fib%mag%name
print *, 'Vorname:     ', fib%mag%vorname
print *, 'Kind:        ', kind_name(fib%mag%kind)
print *, 'Knob:        ', fib%magp%knob
print *, 'L:           ', fib%mag%l

if (fib%mag%kind == kind4) then
  print *, 'Voltage:  ', fib%mag%volt
  print *, 'Frequency:', fib%mag%freq
  print *, 'Voltage:  ', fib%mag%volt
  print *, 'Phase:    ', fib%mag%phas
  print *, 'Delta_e:  ', fib%mag%delta_e
  print *, 'Thin: ', fib%mag%thin
endif

if (fib%mag%kind == kind5) then
  print *, 'KS:       ', fib%mag%b_sol
  print *, 'Thin:     ', fib%mag%thin
endif

if (fib%mag%kind == kind2 .and. fib%mag%p%b0 /= 0) then
  print *, 'E1:       ', fib%mag%p%edge(1)
  print *, 'E2:       ', fib%mag%p%edge(2)
  print *, 'Rho:      ', fib%mag%p%b0
  print *, 'L_chord:  ', fib%mag%p%lc
endif

print *, 'Integration Order: ', fib%mag%p%method
print *, 'Integration Steps: ', fib%mag%p%nst


do i = lbound(fib%mag%bn, 1), ubound(fib%mag%bn, 1)
  if (fib%mag%bn(i) /= 0) print '(a, i2, a, 5x, 1pd12.3)', ' BN(', i, '):', fib%mag%bn(i)
enddo  
do i = lbound(fib%mag%an, 1), ubound(fib%mag%an, 1)
  if (fib%mag%an(i) /= 0) print '(a, i2, a, 5x, 1pd12.3)', ' AN(', i, '):', fib%mag%an(i)
enddo  


end subroutine type_fibre

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine set_ptc (e_tot, particle, taylor_order, integ_order, &
!                               n_step, no_cavity, exact_calc, exact_misalign)
!
! Subroutine to initialize PTC.
! Note: At some point before you use PTC to compute Taylor maps etc.
!   you have to call set_ptc with both e_tot and particle args
!   present. Always supply both of these args together or not at all. 
! Note: If you just want to use FPP without PTC then call init directly.
! Note: This subroutine cannot be used if you want to have "knobs" (in the PTC sense).
! This subroutine replaces:
!     make_states
!     set_mad
!     init
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   e_tot  -- Real(rp), optional: Energy in eV.
!   particle     -- Integer, optional: Type of particle:
!                     electron$, proton$, etc.
!   taylor_order -- Integer, optional: Maximum order of the taylor polynomials.
!   integ_order  -- Integer, optional: Default Order for the drift-kick-drift 
!                     sympletic integrator. Possibilities are: 2, 4, or 6
!                     Default = 2
!   n_step       -- Integer, optional: Default Number of integration steps.
!                     Default = 1
!   no_cavity    -- Logical, optional: No RF Cavity exists? 
!                     Default = False.
!                     Corresponds to the nocavity option of the PTC init routine.
!                     Do not set this unless you know what you are doing.
!   exact_calc   -- logical, optional: Sets the PTC EXACT_MODEL variable.
!                     Default = False.
!                     See the PTC guide for more details.
!   exact_misalign -- logical, optional: Sets the PTC ALWAYS_EXACTMIS variable.
!                     Default = true.
!                     See the PTC guide for more details.
!-

subroutine set_ptc (e_tot, particle, taylor_order, integ_order, &
                                  n_step, no_cavity, exact_calc, exact_misalign) 

use mad_like, only: make_states, exact_model, always_exactmis, &
              assignment(=), nocavity, default, operator(+), &
              berz, init, set_madx, lp, superkill, TIME0, PHASE0
use madx_ptc_module, only: ptc_ini_no_append, append_empty_layout, set_up, m_u

implicit none

integer, optional :: integ_order, particle, n_step, taylor_order
integer this_method, this_steps
integer nd2

real(rp), optional :: e_tot
real(rp), save :: old_e_tot = 0
real(dp) this_energy

logical, optional :: no_cavity, exact_calc, exact_misalign
logical, save :: init_needed = .true.
logical params_present

character(16) :: r_name = 'set_ptc'

! ptc cannot be used with photons

if (present(particle)) then
  if (particle == photon$) return
endif

! do not call set_mad

params_present = present(e_tot) .and. present(particle)

if (init_needed .and. params_present) then
  if (particle == positron$ .or. particle == electron$) then
    call make_states(.true._lp)
  else
    call make_states(.false._lp)
  endif
  EXACT_MODEL = .false.
  ALWAYS_EXACTMIS = .true.
  ! Use PTC time tracking
  DEFAULT = DEFAULT + TIME0
  PHASE0 = 0
endif

if (present (exact_calc))     EXACT_MODEL = exact_calc
if (present (exact_misalign)) ALWAYS_EXACTMIS = exact_misalign
  
if (present(no_cavity)) DEFAULT = DEFAULT+NOCAVITY

if (present (integ_order)) then
  this_method = integ_order
  bmad_com%default_integ_order = integ_order
else
  this_method = bmad_com%default_integ_order
endif

if (present (n_step)) then
  this_steps = n_step
else
  this_steps = 10
endif

if (params_present) then
  if (init_needed .or. old_e_tot /= e_tot .or. present(integ_order) .or. present(n_step)) then
    this_energy = 1e-9 * e_tot
    if (this_energy == 0) then
      call out_io (s_fatal$, r_name, 'E_TOT IS 0.')
      if (bmad_status%exit_on_error) call err_exit
    endif
    call set_madx (energy = this_energy, method = this_method, step = this_steps)
    old_e_tot  = e_tot
    ! Only do this once
    if (init_needed) then
      call ptc_ini_no_append 
      call append_empty_layout(m_u)
      call set_up(m_u%end)
    endif
    init_needed = .false.
  endif
endif

! Do not call init before the call to make_states

if (present(taylor_order)) then  
  if (init_needed) then                   ! make_states has not been called
    bmad_com%taylor_order = taylor_order  ! store the order for next time
  elseif (ptc_com%taylor_order_ptc /= taylor_order) then
    call init (DEFAULT, taylor_order, 0, berz, nd2, ptc_com%real_8_map_init)
    ptc_com%taylor_order_ptc = taylor_order
    bmad_com%taylor_order     = taylor_order
  endif
endif

! Superkill tells PTC to do a through cleanup when killing a fibre.

superkill = .true.

end subroutine set_ptc

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine taylor_equal_real_8 (bmad_taylor, y8)
!
! Subroutine to convert from a real_8 taylor map in Etienne's PTC 
! to a taylor map in BMAD. This does not do any
! conversion between Bmad units (z, dp/p0) and PTC units (dE/p0, c*t).
!
! Subroutine overloads "=" in expressions
!       bmad_taylor = y8
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   y8(:) -- real_8: PTC Taylor map.
!
! Output:
!   bmad_taylor(:) -- Taylor_struct: Input taylor map.
!-

subroutine taylor_equal_real_8 (bmad_taylor, y8)

use polymorphic_taylor, only: assignment (=), universal_taylor, real_8
use definition, only: real_8

implicit none

type (real_8), intent(in) :: y8(:)
type (taylor_struct), intent(inout) :: bmad_taylor(:)
type (universal_taylor) :: u_t(6)

integer i

!

do i = 1, 6
  u_t(i) = 0  ! nullify
  u_t(i) = y8(i)%t
enddo

call universal_to_bmad_taylor (u_t, bmad_taylor)

do i = 1, 6
  u_t(i) = -1  ! deallocate
enddo

end subroutine taylor_equal_real_8

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine real_8_equal_taylor (y8, bmad_taylor)
!
! Subroutine to convert from a taylor map in BMAD to a
! real_8 taylor map in Etienne's PTC. This does not do any
! conversion between Bmad units (z, dp/p0) and PTC units (dE/p0, c*t).
! To convert coordinates, use the taylor_to_real_8 routine.
!
! Subroutine overloads "=" in expressions
!       y8 = bmad_taylor
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   bmad_taylor(:) -- Taylor_struct: Input taylor map.
!
! Output:
!   y8(:) -- real_8: PTC Taylor map.
!-

subroutine real_8_equal_taylor (y8, bmad_taylor)

use polymorphic_taylor, only: kill, assignment(=), real_8, universal_taylor

implicit none

type (real_8), intent(inout) :: y8(:)
type (taylor_struct), intent(in) :: bmad_taylor(:)
type (universal_taylor) :: u_t

integer i, j, n

logical switch

! init

call kill (y8)
call real_8_init (y8, .true.)

!

do i = 1, 6

  switch = .true.

  n = size(bmad_taylor(i)%term)
  allocate (u_t%n, u_t%nv, u_t%c(n), u_t%j(n,6))
  u_t%n = n
  u_t%nv = 6

  do j = 1, n
    u_t%j(j,:) = bmad_taylor(i)%term(j)%expn(:)
    u_t%c(j) = bmad_taylor(i)%term(j)%coef
  enddo

  y8(i) = u_t
  u_t = -1   ! deallocate
      
enddo

end subroutine real_8_equal_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine taylor_to_real_8 (bmad_taylor, beta0, y8)
!
! Routine to convert a Bmad Taylor map to PTC real_8 map.
! The conversion includes the conversion between Bmad and PTC time coordinate systems.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   bmad_taylor(:) -- Taylor_struct: Input taylor map.
!   beta0 -- real(8): Reference particle velocity
!
! Output:
!   y8(:) -- real_8: PTC Taylor map.
!-

subroutine taylor_to_real_8 (bmad_taylor, beta0, y8)

use s_fibre_bundle

implicit none

type (taylor_struct) :: bmad_taylor(:)
type (real_8) y8(:)
type (damap) bm, id, s, si
type (taylor) bet

real(dp) beta0, fix0(6), fix1(6)

!

call alloc(bm, id, s, si)
call alloc(bet)

fix0 = 0.0d0
y8 = bm
call real_8_equal_taylor (y8, bmad_taylor)
fix1 = bm
bm = fix0
id = 1
s = 1
si = 1
s%v(6) = (2.d0*id%v(5)/beta0+id%v(5)**2)/(sqrt(1.d0+2.d0*id%v(5)/beta0+id%v(5)**2)+1.d0)
bet = (1.d0+s%v(6))/(1.d0/beta0+id%v(5))
s%v(5) = -bet*id%v(6)
si%v(5) = (id%v(6)**2+2.d0*id%v(6))/(1.d0/beta0+sqrt( 1.d0/beta0**2+id%v(6)**2+2.d0*id%v(6)) )
bet = (1.d0+id%v(6))/(1.d0/beta0+si%v(5))
si%v(6) = -id%v(5)/bet
bm = si*bm*s
fix0 = fix1
fix0(5) = (fix1(6)**2+2.d0*fix1(6))/(1.d0/beta0+sqrt( 1.d0/beta0**2+fix1(6)**2+2.d0*fix1(6)) )
fix0(6) = -fix1(5)/((1.d0+fix1(6))/(1.d0/beta0+fix0(5)))
bm = fix0
y8 = bm

call kill(bm, id, s, si)
call kill(bet)

end subroutine taylor_to_real_8

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine real_8_to_taylor (y8, beta0, bmad_taylor)
!
! Routine to convert a PTC real_8 map to a Bmad Taylor map.
! The conversion includes the conversion between Bmad and PTC time coordinate systems.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   y8(:) -- real_8: PTC Taylor map.
!   beta0 -- real(8): Reference particle velocity
!
! Output:
!   bmad_taylor(:) -- Taylor_struct: Bmad Taylor map.
!-

subroutine real_8_to_taylor (y8, beta0, bmad_taylor)

use s_fibre_bundle

implicit none

type (taylor_struct) :: bmad_taylor(:)
type (real_8) y8(:)
type (damap) bm, id, s, si
type (taylor) bet

real(rp) beta0, fix0(6), fix1(6)

!

call alloc(bm, id, s, si)
call alloc(bet)

fix0 = 0.d0
bm = y8
fix1 = bm
bm = fix0
id = 1
s = 1
si = 1
s%v(6) = (2.d0*id%v(5)/beta0+id%v(5)**2)/(sqrt(1.d0+2.d0*id%v(5)/beta0+id%v(5)**2)+1.d0)
bet = (1.d0+s%v(6))/(1.d0/beta0+id%v(5))
s%v(5) = -bet*id%v(6)
si%v(5) = (id%v(6)**2+2.d0*id%v(6))/(1.d0/beta0+sqrt( 1.d0/beta0**2+id%v(6)**2+2.d0*id%v(6)) )
bet = (1.d0+id%v(6))/(1.d0/beta0+si%v(5))
si%v(6) = -id%v(5)/bet
bm = s*bm*si
fix0 = fix1
fix0(6) = (2.d0*fix1(5)/beta0+fix1(5)**2)/(sqrt(1.d0+2.d0*fix1(5)/beta0+fix1(5)**2)+1.d0)
fix0(5) = -fix1(6)*((1.d0+fix0(6))/(1.d0/beta0+fix1(5)))
bm = fix0
y8 = bm
call taylor_equal_real_8 (bmad_taylor, y8)

call kill(bm, id, s, si)
call kill(bet)

end subroutine real_8_to_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine taylor_ref_energy_correct (taylor, p0c_rel)
!
! Routine to correct a Bmad Taylor map due to a reference energy shift.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   taylor(6)   -- taylor_struct: Bmad Taylor map
!   p0c_rel     -- real(rp): Relative momentum: p0c[New ref] / p0c[Old ref].
!
! Output:
!   taylor(6)   -- taylor_struct: Corrected Bmad Taylor map
!-

subroutine taylor_ref_energy_correct (taylor, p0c_rel)

implicit none

type (taylor_struct) taylor(6)
type (taylor_struct), save :: taylor_temp
real(rp) p0c_rel

!

taylor(2)%term(:)%coef = taylor(2)%term(:)%coef / p0c_rel
taylor(4)%term(:)%coef = taylor(4)%term(:)%coef / p0c_rel
taylor(6)%term(:)%coef = taylor(6)%term(:)%coef / p0c_rel
call add_taylor_term(taylor(6), 1/p0c_rel - 1, [0, 0, 0, 0, 0, 0])

end subroutine taylor_ref_energy_correct

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine vec_bmad_to_ptc (vec_bmad, beta0, vec_ptc)
!
! Routine to convert a Bmad vector map to PTC vector,
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   vec_bmad(6) -- real(rp): Bmad coordinates.
!   beta0       -- real(rp): Reference particle velocity
!   particle    -- Integer: Particle type. positron$, etc.
!
! Output:
!   vec_ptc(6)  -- real(rp): PTC coordinates.
!-

subroutine vec_bmad_to_ptc (vec_bmad, beta0, vec_ptc)

implicit none

real(rp) vec_bmad(:), vec_ptc(:)
real(rp) beta0

!

vec_ptc = vec_bmad
vec_ptc(5) = (vec_bmad(6)**2+2.d0*vec_bmad(6))/(1.d0/beta0+sqrt( 1.d0/beta0**2+vec_bmad(6)**2+2.d0*vec_bmad(6)) )
vec_ptc(6) = -vec_bmad(5)/((1.d0+vec_bmad(6))/(1.d0/beta0+vec_ptc(5)))

end subroutine vec_bmad_to_ptc 

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine vec_ptc_to_bmad (vec_ptc, beta0, vec_bmad)
!
! Routine to convert a PTC real_8 map to a Bmad Taylor map.
! The conversion includes the conversion between Bmad and PTC time coordinate systems.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   vec_bmad(6) -- real(rp): Bmad coordinates.
!   beta0       -- real(rp): Reference particle velocity
!
! Output:
!   vec_ptc(6)  -- real(rp): PTC coordinates.
!-

subroutine vec_ptc_to_bmad (vec_ptc, beta0, vec_bmad)

implicit none

real(rp) vec_bmad(:), vec_ptc(:)
real(rp) beta0

!

vec_bmad = vec_ptc
vec_bmad(6) = (2.d0*vec_ptc(5)/beta0+vec_ptc(5)**2)/(sqrt(1.d0+2.d0*vec_ptc(5)/beta0+vec_ptc(5)**2)+1.d0)
vec_bmad(5) = -vec_ptc(6)*((1.d0+vec_bmad(6))/(1.d0/beta0+vec_ptc(5)))

end subroutine vec_ptc_to_bmad 

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine vec_bmad_ref_energy_correct (vec_bmad, p0c_rel)
!
! Routine to correct a Bmad coordinate vector due to reference energy shift.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   vec_bmad(6) -- real(rp): Bmad coordinates.
!   p0c_rel     -- real(rp): Relative momentum: p0c[New ref] / p0c[Old ref].
!
! Output:
!   vec_bmad(6) -- real(rp): Corrected Bmad coordinates.
!-

subroutine vec_bmad_ref_energy_correct (vec_bmad, p0c_rel)

implicit none

real(rp) vec_bmad(6), p0c_rel

!

vec_bmad(2) = vec_bmad(2) / p0c_rel
vec_bmad(4) = vec_bmad(4) / p0c_rel
vec_bmad(6) = (1 + vec_bmad(6)) / p0c_rel - 1

end subroutine vec_bmad_ref_energy_correct

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Elemental subroutine universal_equal_universal (ut1, ut2)
!
! Subroutine to transfer the values in one universal taylor variable to
! another. Note: ut1 needs to have been initialized.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   ut2 -- Universal_taylor:
!
! Output:
!   ut1 -- Universal_taylor:
!-

elemental subroutine universal_equal_universal (ut1, ut2)

use definition, only: universal_taylor

implicit none

type (universal_taylor), intent(inout) :: ut1
type (universal_taylor), intent(in)    :: ut2

!

if (associated (ut1%n)) deallocate (ut1%n, ut1%nv, ut1%c, ut1%j)
allocate (ut1%n, ut1%nv, ut1%c(ut2%n), ut1%j(ut2%n, ut2%nv))

ut1%n  = ut2%n
ut1%nv = ut2%nv
ut1%c  = ut2%c
ut1%j  = ut2%j

end subroutine

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine real_8_init (y, set_taylor)
!
! Subroutine to allocate a PTC real_8 variable.
! The internal kind parameter will be set to 0.
!
! Note: If this variable has been used before, make sure you have 
! deallocated using:
!   call kill(y)
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   y(6)       -- Real_8: 
!   set_taylor -- Logical, optional :: If present and True then make
!                   y the identity taylor series (kind = 2).
!
! Output:
!   y(6) -- Real_8: Identity map.
!-

subroutine real_8_init (y, set_taylor)

use s_fibre_bundle, only: assignment(=), alloc, real_8

implicit none

type (real_8) :: y(:)
real(dp) :: x(6) = (/ 0, 0, 0, 0, 0, 0 /)

logical, optional :: set_taylor

!

call alloc(y)
y = ptc_com%real_8_map_init

if (present(set_taylor)) then
  if (set_taylor) y = x   ! converts y to taylor (kind = 2)
endif

end subroutine real_8_init

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine universal_to_bmad_taylor (u_taylor, bmad_taylor)
!
! Subroutine to convert from a universal_taylor map in Etienne's PTC 
! to a taylor map in BMAD.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   u_taylor(6) -- Universal_taylor: Universal_taylor map.
!
! Output:
!   bmad_taylor(6)   -- Taylor_struct:
!-

Subroutine universal_to_bmad_taylor (u_taylor, bmad_taylor)

use definition, only: universal_taylor

implicit none

type (universal_taylor), intent(in) :: u_taylor(:)
type (taylor_struct) :: bmad_taylor(:)

integer i, j, k, n

! Remember to suppress any terms that have a zero coef.  

do i = 1, 6

  if (associated(bmad_taylor(i)%term)) deallocate(bmad_taylor(i)%term)

  n = count(u_taylor(i)%c(:) /= 0)
  allocate(bmad_taylor(i)%term(n))

  k = 0
  do j = 1, u_taylor(i)%n
    if (u_taylor(i)%c(j) == 0) cycle
    k = k + 1
    bmad_taylor(i)%term(k)%expn  = u_taylor(i)%j(j,:)
    bmad_taylor(i)%term(k)%coef = u_taylor(i)%c(j)
  enddo

enddo

end subroutine universal_to_bmad_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine concat_real_8 (y1, y2, y3)
!
! Subroutine to concatinate two real_8 taylor maps.
!       y3 = y2(y1)
! This subroutine assumes that y1, y2, and y3 have been allocated.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   y1(6) -- real_8: First Input map.
!   y2(6) -- real_8: Second Input map.
!
! Output
!   y3(6) -- real_8: Concatinated map.
!-

subroutine concat_real_8 (y1, y2, y3)

use s_fitting, only: alloc, assignment(=), kill, damap, operator(.o.), real_8

implicit none

type (real_8), intent(in) :: y1(:), y2(:)
type (real_8), intent(inout) :: y3(:)
type (damap) da1, da2, da3

! set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

! Allocate temp vars

call alloc(da1)
call alloc(da2)
call alloc(da3)

! concat

da1 = y1
da2 = y2

da3 = da2 .o. da1  ! concat with constant terms

y3 = da3

! kill temp vars

call kill (da1)
call kill (da2)
call kill (da3)

end subroutine concat_real_8

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine taylor_to_genfield (bmad_taylor, ptc_genfield, c0)
!
! Subroutine to construct a genfield (partially inverted map) from a taylor
! map.
! Note: The constant terms of the taylor map are removed in the process.
! Note: The genfield uses PTC coordinates.
!
! Moudules needed:
!   use ptc_interface_mod
!
! Input:
!   bmad_taylor(6) -- Taylor_struct: Input taylor map.
!
! Output:
!   ptc_genfield      -- Genfield: Output partially inverted map.
!   c0(6)          -- Real(rp): The constant part of the bmad_taylor map
!-

subroutine taylor_to_genfield (bmad_taylor, ptc_genfield, c0)

use s_fitting, only: alloc, kill, assignment(=), damap, real_8

implicit none

type (taylor_struct), intent(in) :: bmad_taylor(6)
type (genfield), intent(inout) :: ptc_genfield
type (taylor_struct) taylor(6)
type (damap) da_map
type (real_8) y(6)

real(rp), intent(out) :: c0(6)

! set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

! Remove constant terms from the taylor map first. This is probably
! not needed but we do it to make sure everything is alright.
! Also remove terms that have higher order then bmad_com%taylor_order

call remove_constant_taylor (bmad_taylor, taylor, c0, .true.)

! allocate pointers

call alloc (ptc_genfield)
call alloc (da_map)
call alloc (y)

! calculate the ptc_genfield

y = taylor
da_map = y
ptc_genfield = da_map

! cleanup

call kill (da_map)
call kill (y)
call kill_taylor (taylor)

end subroutine taylor_to_genfield

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine remove_constant_taylor (taylor_in, taylor_out, c0, remove_higher_order_terms)
!
! Subroutine to remove the constant part of a taylor map.
! Optionally terms that are higher order than bmad_com%taylor_order can
! be removed.
!
! Note: It is assumed that taylor_out has been deallocated before the call to
! this routine. Calling this routine with the first two actual arguments the
! same is prohibited.
!
! Moudules needed:
!   use ptc_interface_mod
!
! Input:
!  taylor_in(6) -- Taylor_struct: Input taylor map.
!  remove_higher_order_terms -- Logical: If True then terms that are higher
!                               order than bmad_com%taylor_order are removed.
!
! Output:
!   taylor_out(6)  -- Taylor_struct: Taylor with constant terms removed.
!   c0(6)          -- Real(rp): The constant part of the taylor map
!-

subroutine remove_constant_taylor (taylor_in, taylor_out, c0, remove_higher_order_terms)

implicit none

type (taylor_struct), intent(in) :: taylor_in(:)
type (taylor_struct) taylor_out(:)

real(rp), intent(out) :: c0(:)

integer i, j, n, nn, ss

logical, intent(in) :: remove_higher_order_terms

!

c0 = 0

do i = 1, 6

  n = size(taylor_in(i)%term)

  do j = 1, size(taylor_in(i)%term)
    if (all(taylor_in(i)%term(j)%expn == 0)) then
      n = n - 1
      c0(i) = taylor_in(i)%term(j)%coef
    endif
    if (remove_higher_order_terms) then
      if (sum(taylor_in(i)%term(j)%expn) > bmad_com%taylor_order) n = n - 1
    endif
  enddo

  if (associated(taylor_out(i)%term)) then
    if (size(taylor_out(i)%term) /= n) deallocate(taylor_out(i)%term)
  endif
  if (.not. associated(taylor_out(i)%term)) allocate (taylor_out(i)%term(n))

  nn = 0
  do j = 1, size(taylor_in(i)%term)
    ss = sum(taylor_in(i)%term(j)%expn)
    if (ss == 0 .or. (remove_higher_order_terms .and. ss > bmad_com%taylor_order)) cycle
    nn = nn + 1
    taylor_out(i)%term(nn) = taylor_in(i)%term(j)
  enddo

enddo

end subroutine remove_constant_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine taylor_inverse (taylor_in, taylor_inv, err, ref_pt)
!
! Subroutine to invert a taylor map. Since the inverse map is truncated, it
! is not exact and the reference point about which it is computed matters.
!
! Moudules needed:
!   use ptc_interface_mod
!
! Input:
!   taylor_in(6)  -- Taylor_struct: Input taylor map.
!   ref_pt(6)     -- Real(rp), optional: Reference point about which the 
!                     inverse is taken. Default is zero.
!
! Output:
!   taylor_inv(6) -- Taylor_struct: Inverted taylor map.
!   err           -- Logical, optional: Set True if there is no inverse.
!                     If not present then print an error message.
!-

subroutine taylor_inverse (taylor_in, taylor_inv, err, ref_pt)

use s_fitting, only: assignment(=), alloc, kill, operator(**), damap, real_8

implicit none

type (taylor_struct) :: taylor_in(:)
type (taylor_struct) :: taylor_inv(:)
type (taylor_struct) tlr(6), tlr2(6)
type (real_8) y(6), yc(6)
type (damap) da

real(rp), optional :: ref_pt(:)
real(rp) c0(6)

integer i, expn(6)

real(dp) c8(6), c_ref(6)

logical, optional :: err

character(16) :: r_name = 'taylor_inverse'

! Set the taylor order in PTC if not already done so.

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

call alloc(da)
call alloc(y)

! If ref_pt is present then shift the map to the new reference point.
! Also the inverse operation of PTC ignores constant terms so we have 
! to take them out and then put them back in.

if (present(ref_pt)) then
  y = taylor_in
  call real_8_init(yc)
  c_ref = ref_pt
  yc = c_ref
  call concat_real_8 (yc, y, y)
  tlr2 = y
  call kill (yc)
  call kill (y)
  call remove_constant_taylor (tlr2, tlr, c0, .true.)
  call kill_taylor (tlr2)
else
  call remove_constant_taylor (taylor_in, tlr, c0, .true.)
endif

! Each taylor_in(i) must have at least one term for an inverse to exist.

do i = 1, 6
  if (size(tlr(i)%term) == 0) then
    if (present(err)) then
      err = .true.
    else
      call out_io (s_error$, r_name, 'Taylor map does not have an inverse.')
    endif
    return
  endif
enddo

! Compute inverse.

y = tlr
da = y
da = da**(-1)
y = da

! Put constant terms back in.
! If the Map is written as:
!   R_out = T * R_in + C
! Then inverting:
!   R_in = T_inv * (R_out - C) = T_inv * (I - C) * R_out

if (any(c0 /= 0)) then
  call real_8_init(yc)
  c8 = c0
  yc = -c8                       ! Convert this to taylor map: I - c8
  call concat_real_8 (yc, y, y) 
  call kill (yc)
  taylor_inv%ref = c0
endif

! Transfer inverse to taylor_inv.

taylor_inv = y

! Take out the ref_pt offset if needed

if (present(ref_pt)) then
  do i = 1, 6
    call add_taylor_term (taylor_inv(i), ref_pt(i))
  enddo
endif

! Clean up

call kill (da)
call kill (y)
call kill (yc)
call kill_taylor (tlr)

if (present(err)) err = .false.

end subroutine taylor_inverse

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine concat_taylor (taylor1, taylor2, taylor3)
! 
! Subroutine to concatinate two taylor maps:
!   taylor3[x] = taylor2(taylor1[x])
!
! Note: In general, if taylor2 is a component of an ele_struct, use
! concat_ele_taylor instead.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   taylor1(6) -- Taylor_struct: Taylor map.
!   taylor2(6) -- Taylor_struct: Taylor map.
!
! Output
!   taylor3(6) -- Taylor_struct: Concatinated map
!-

subroutine concat_taylor (taylor1, taylor2, taylor3)

use s_fitting, only: assignment(=), kill, real_8

implicit none

type (taylor_struct) :: taylor1(:), taylor2(:)
type (taylor_struct) :: taylor3(:)
type (real_8) y1(6), y2(6), y3(6)

! Set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

! Allocate temp vars

call real_8_init (y1)
call real_8_init (y2)
call real_8_init (y3)

! Concat

y1 = taylor1
y2 = taylor2

call concat_real_8 (y1, y2, y3)

taylor3 = y3
taylor3(:)%ref = taylor1(:)%ref

! Cleanup

call kill (y1)
call kill (y2)
call kill (y3)

end subroutine concat_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine concat_ele_taylor (taylor1, ele, taylor3)
!
! Routine to concatinate two taylor maps:
!   taylor3[x] = ele_taylor(taylor1[x])
! If ele%map_with_offset = True:  ele_taylor == ele%taylor 
! If ele%map_with_offset = False: ele_taylor == ele%taylor + offset corrections. 
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   taylor1(6) -- Taylor_struct: Taylor map.
!   ele        -- ele_struct: Element containing the taylor map.
!
! Output
!   taylor3(6) -- Taylor_struct: Concatinated map
!-

Subroutine concat_ele_taylor (taylor1, ele, taylor3)

use s_tracking, only: mis_fib, alloc, kill, dtiltd, assignment(=), default, real_8, fibre

implicit none

type (ele_struct) ele
type (taylor_struct) taylor1(:), taylor3(:)
type (lat_param_struct) param
type (real_8) x_ele(6), x_body(6), x1(6), x3(6)
type (fibre), pointer :: fib

real(rp) beta0
real(8) x_dp(6)

! Patch and Match elements are not implemented in PTC so just use the matrix.

if (ele%key == patch$ .or. ele%key == match$ .or. ele%key == lcavity$ .or. ele%key == rfcavity$) then
  call mat6_to_taylor (ele%vec0, ele%mat6, ele%taylor)
  call concat_taylor (taylor1, ele%taylor, taylor3)
  return
endif

! ele%map_with_offset = T means that misalignment effects are already included 
! in ele%taylor.

if (ele%map_with_offsets .or. ele%key == taylor$) then
  call concat_taylor (taylor1, ele%taylor, taylor3)
  return
endif

! Here when we need to include the misalignment effects.
! First set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

! Init

call real_8_init(x_ele)
call real_8_init(x_body)
call real_8_init(x1)
call real_8_init(x3)

beta0 = ele%value(p0c$)/ele%value(e_tot$)

! Create a PTC fibre that holds the misalignment info
! and create map corresponding to ele%taylor.

param%particle = positron$  ! Actually this does not matter to the calculation
call ele_to_fibre (ele, fib, param, use_offsets = .true.)

x_dp = 0
x_ele = x_dp  ! x_ele = Identity map 

call dtiltd (1, ele%value(tilt_tot$), 1, x_ele)
call mis_fib (fib, x_ele, DEFAULT, .true., entering = .true.)

call taylor_to_real_8 (ele%taylor, beta0, x_body)

call concat_real_8 (x_ele, x_body, x_ele)
call mis_fib (fib, x_ele, DEFAULT, .true., entering = .false.)
call dtiltd (1, ele%value(tilt_tot$), 2, x_ele)

! Concat with taylor1

call taylor_to_real_8 (taylor1, beta0, x1)
call concat_real_8 (x1, x_ele, x3)

! convert x3 to final result taylor3

call real_8_to_taylor(x3, beta0, taylor3)
taylor3(:)%ref = taylor1(:)%ref

if (.not. ele_has_constant_reference_energy(ele)) &
      call taylor_ref_energy_correct(taylor3, ele%value(p0c$) / ele%value(p0c_start$))

! Cleanup

call kill(x_ele)
call kill(x_body)
call kill(x1)
call kill(x3)

end subroutine concat_ele_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine taylor_propagate1 (bmad_taylor, ele, param)
!
! Subroutine to track (symplectic integration) a taylor map through an element.
! The alternative routine, if ele has a taylor map, is concat_taylor.
!
! This routine will fail if there is no corresponding ptc fibre for this
! element. In general, the transfer_map_calc routine should be used instead.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   bmad_taylor(6) -- Taylor_struct: Map to be tracked
!   ele            -- Ele_struct: Element to track through
!   param          -- lat_param_struct: 
!
! Output:
!   bmad_taylor(6)  -- Taylor_struct: Map through element
!-

subroutine taylor_propagate1 (bmad_taylor, ele, param)

use s_tracking
use mad_like, only: real_8, fibre, ptc_track => track

implicit none

type (taylor_struct) bmad_taylor(:)
type (real_8), save :: ptc_tlr(6)
type (ele_struct) ele
type (lat_param_struct) param
type (fibre), pointer, save :: a_fibre

real(rp) beta0, m2_rel

! set the taylor order in PTC if not already done so

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) call set_ptc (taylor_order = bmad_com%taylor_order)

! Init ptc map with bmad map

beta0 = ele%value(p0c$) / ele%value(e_tot$)

call real_8_init (ptc_tlr)
call taylor_to_real_8 (bmad_taylor, beta0, ptc_tlr)

! Init ptc "element" (fibre)

call ele_to_fibre (ele, a_fibre, param, .true.)

! Track map through the fibre

call ptc_track (a_fibre, ptc_tlr, default)  ! "track" in PTC

! transfer ptc map back to bmad map

call real_8_to_taylor(ptc_tlr, beta0, bmad_taylor)

if (.not. ele_has_constant_reference_energy(ele)) &
      call taylor_ref_energy_correct(bmad_taylor, ele%value(p0c$) / ele%value(p0c_start$))

! cleanup

call kill (ptc_tlr)

! Correct wiggler z_patch if needed

if (ele%key == wiggler$) then
  call add_taylor_term (bmad_taylor(5), -ele%value(z_patch$))
endif


end subroutine taylor_propagate1

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine ele_to_taylor (ele, param, orb0, map_with_offsets)
!
! Subroutine to make a taylor map for an element. 
! The order of the map is set by set_ptc
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   ele   -- Element_struct: 
!     %valueintegrator_order$)  -- Order for the symplectic integrator: 2, 4, or 6.
!     %value(ds_step$)          -- Integrater step size.
!     %map_with_offsets         -- Make Taylor map with element offsets, pitches, and tilt?
!   orb0  -- Coord_struct, optional: Starting coords around which the Taylor map 
!              is evaluated.
!   param -- lat_param_struct: 
!     %e_tot -- Needed for wigglers.
!   map_with_offsets -- Logical, optional: If present then overrides 
!                         ele%map_with_offsets.
!
! Output:
!   ele -- Element_struct:
!     %taylor(6)  -- Taylor maps.
!-

subroutine ele_to_taylor (ele, param, orb0, map_with_offsets)

use s_tracking
use mad_like, only: real_8, fibre, ptc_track => track

implicit none

type (ele_struct), intent(inout) :: ele
type (lat_param_struct) :: param
type (coord_struct), optional, intent(in) :: orb0
type (coord_struct) start0, end0, c0

type (fibre), pointer, save :: a_fibre
type (real_8) y(6), y2(6)

real(dp) x(6), beta0

integer i

logical, optional :: map_with_offsets
logical :: warning_given = .false.
logical use_offsets

character(16) :: r_name = 'ele_to_taylor'

! Init

if (ptc_com%taylor_order_ptc /= bmad_com%taylor_order) then
  call set_ptc (taylor_order = bmad_com%taylor_order)
endif

ele%status%attributes = stale$
call attribute_bookkeeper (ele, param)

! Patch and Match elements are not implemented in PTC so just use the matrix.
! Also Taylor elements already have a taylor map.

if (ele%key == taylor$) return

if (ele%key == match$ .or. ele%key == patch$ .or. ele%key == lcavity$ .or. ele%key == rfcavity$) then
  c0%vec = 0
  call make_mat6_bmad (ele, param, c0, c0, .true.)
  call mat6_to_taylor (ele%vec0, ele%mat6, ele%taylor)
  if (.not. warning_given) then
    call out_io (s_warn$, r_name, &
      'Note: Taylor maps for Match, and Patch elements are always 1st order!')
    warning_given = .true.
  endif
  return
endif

! Track with offset

use_offsets = logic_option(ele%map_with_offsets, map_with_offsets)
call ele_to_fibre (ele, a_fibre, param, use_offsets)
 
if (present(orb0)) then
  ele%taylor(:)%ref = orb0%vec
  if (ele_has_constant_reference_energy(ele)) then
    call vec_bmad_to_ptc (orb0%vec, ele%value(p0c$)/ele%value(e_tot$), x)
  else
    call vec_bmad_to_ptc (orb0%vec, ele%value(p0c_start$)/ele%value(e_tot_start$), x)
  endif
else
  ele%taylor(:)%ref = 0
  x = 0
endif

call real_8_init(y)
y = x   ! y = IdentityMap + x
call ptc_track (a_fibre, y, default) ! "track" in PTC

! take out the offset

if (any(x /= 0)) then
  call real_8_init(y2)
  y2 = -x  ! y2 = IdentityMap - x
  call concat_real_8 (y2, y, y)
  call kill(y2)
endif

! convert to bmad_taylor  

beta0 = ele%value(p0c$) / ele%value(e_tot$)

call real_8_to_taylor (y, beta0, ele%taylor)

if (.not. ele_has_constant_reference_energy(ele)) &
      call taylor_ref_energy_correct(ele%taylor, ele%value(p0c$) / ele%value(p0c_start$))

call kill(y)

if (associated (ele%ptc_genfield)) call kill_ptc_genfield (ele%ptc_genfield)

! For wigglers there is a z_patch to take out the non-zero z offset that an
! on axis particle gets.

if (ele%key == wiggler$) then

  if (ele%value(z_patch$) == 0) then
    call out_io (s_fatal$, r_name, 'WIGGLER Z_PATCH VALUE HAS NOT BEEN COMPUTED!')
    if (bmad_status%exit_on_error) call err_exit 
  endif

  call add_taylor_term (ele%taylor(5), -ele%value(z_patch$))

endif

ele%status%mat6 = stale$

end subroutine ele_to_taylor

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine type_real_8_taylors (y)
!
! Subroutine to type out the taylor map from a real_8 array.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input
!   y(6)     -- Real_8: 6 taylor map: 
!-

subroutine type_real_8_taylors (y)

use definition, only: real_8

implicit none

type (real_8) y(:)
type (taylor_struct) b_taylor(6)

!

b_taylor = y
call type_taylors (b_taylor)
call kill_taylor (b_taylor)

end subroutine type_real_8_taylors

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine sort_universal_terms (ut_in, ut_sorted)
!
! Subroutine to sort the taylor terms from "lowest" to "highest".
! This subroutine is needed since what comes out of PTC is not sorted.
!
! The number associated with a taylor_term that is used for the sort is:
!     number = sum(exp(i))*10^6 + exp(6)*10^5 + ... + exp(1)*10^0
! Where exp(1) is the exponent for x, exp(2) is the exponent for P_x, etc.
!
! Note: ut_sorted needs to have been initialized.
! Note: ut_sorted cannot be ut_in. That is it is not legal to write:
!           call sort_universal_terms (this_ut, this_ut)
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   ut_in     -- Universal_taylor: Unsorted taylor series.
!
! Output:
!   ut_sorted -- Universal_taylor: Sorted taylor series.
!-

subroutine sort_universal_terms (ut_in, ut_sorted)

use nr
use definition, only: universal_taylor

implicit none

type (universal_taylor), intent(in)  :: ut_in
type (universal_taylor) :: ut_sorted

integer, allocatable :: ix(:), ord(:)
integer i, n, nv, expn(6)

! init

n = ut_in%n
nv = ut_in%nv

if (nv /= 6) then
  print *, 'ERROR IN SORT_UNIVERSAL_TERMS: I AM NOT SET UP FOR NV /= 6'
  if (bmad_status%exit_on_error) call err_exit
endif

if (associated(ut_sorted%n)) deallocate(ut_sorted%n, ut_sorted%nv, ut_sorted%c, ut_sorted%j)
allocate(ut_sorted%n, ut_sorted%nv, ut_sorted%c(n), ut_sorted%j(n,nv), ix(n), ord(n))

ut_sorted%n = n
ut_sorted%nv = nv

!

do i = 1, n
  expn = ut_in%j(i,:)
  ord(i) = sum(expn)*10**6 + expn(6)*10**5 + expn(5)*10**4 + &
              expn(4)*10**3 + expn(3)*10**2 + expn(2)*10**1 + expn(1)
enddo

call indexx (ord, ix)

do i = 1, n
  ut_sorted%c(i)= ut_in%c(ix(i))
  ut_sorted%j(i,:)= ut_in%j(ix(i),:)
enddo

deallocate(ord, ix)

end subroutine sort_universal_terms

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine type_map (y)
!
! Subroutine to type the transfer maps of a real_8 array.
!
! Modules needed:
!   use ptc_interface_mod
!
! Input:
!   y(:)  -- Real_8: 
!-

subroutine type_map (y)

use s_fitting, only: assignment(=), real_8, universal_taylor

implicit none

type (real_8), intent(in) :: y(:)
type (universal_taylor) ut

integer :: i, j, k

!

do i = 1, size(y)
  ut = 0
  ut = y(i)%t
  print *, '!-----------------'
  print *, '! Term:', i
  print *, 'Order            Coef    Exponents'
  do j = 1, ut%n
    print '(i6, f18.14, 20i3)', sum(ut%j(j,:)), ut%c(j), (ut%j(j,k), k = 1, ut%nv)
  enddo
  ut = -1
enddo

end subroutine type_map

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+                                
! Subroutine ele_to_fibre (ele, fiber, param, use_offsets, integ_order, steps)
!
! Subroutine to convert a Bmad element to a PTC fibre element.
! This subroutine allocates fresh storage for the fibre so after calling
! this routine you need to deallocate at some point with:
!       call kill (fiber)
!
! Note: You need to call set_ptc before using this routine.
!
! Modules Needed:
!   use ptc_interface_mod
!
! Input:
!   ele    -- Ele_struct: Bmad element.
!     %map_with_offsets -- If False then the values for x_pitch, x_offset, 
!                           tilt, etc. for the  fiber element will be zero.
!   param       -- lat_param_struct: 
!     %particle     -- Particle type. Needed for elsep elements.
!   use_offsets -- Logical: Does fiber include element offsets, pitches and tilt?
!   integ_order -- Integer, optional: Order for the 
!                    sympletic integrator. Possibilities are: 2, 4, or 6
!                    Overrides ele%value(integrator_order$).
!                    default = 2 (if not set with set_ptc).
!   steps       -- Integer, optional: Number of integration steps.
!                    Overrides ele%value(ds_step$).
!
! Output:
!   fiber -- Fibre: PTC fibre element.
!+

subroutine ele_to_fibre (ele, fiber, param, use_offsets, integ_order, steps)

use madx_ptc_module

implicit none
 
type (ele_struct), target :: ele
type (ele_struct), pointer :: field_ele, ele2
type (fibre), pointer :: fiber
type (keywords) ptc_key
type (lat_param_struct) :: param
type (ele_pointer_struct), allocatable, save :: field_eles(:)
type (work) energy_work


real(dp) mis_rot(6), beta
real(dp) omega(3), basis(3,3), angle(3)

real(rp) an0(0:n_pole_maxx), bn0(0:n_pole_maxx)
real(rp) cos_t, sin_t, leng, hk, vk, x_off, y_off, x_pitch, y_pitch, s_rel

integer i, n, key, n_term, exception, n_field
integer, optional :: integ_order, steps

logical kick_here, use_offsets, doneit

character(16) :: r_name = 'ele_to_fibre'

!

call zero_key(ptc_key)  ! init key
ptc_key%model = 'MATRIX_KICK'

leng = ele%value(l$)

ptc_key%list%name = ele%name
ptc_key%list%l    = leng

if (use_offsets) then
  ptc_key%tiltd = ele%value(tilt_tot$)
else
  ptc_key%tiltd = 0
endif

if (present(steps)) then
  ptc_key%nstep = steps
elseif (leng == 0) then
  ptc_key%nstep = 1
else
  if (ele%value(ds_step$) == 0) then
    call out_io (s_fatal$, r_name, 'DS_STEP IS ZERO FOR ELEMENT: ' // ele%name)
    if (bmad_status%exit_on_error) call err_exit
  endif
  ptc_key%nstep = nint(abs(leng) / ele%value(ds_step$))
  if (ptc_key%nstep == 0) ptc_key%nstep = 1
endif

ptc_key%method = nint(ele%value(integrator_order$))
if (ptc_key%method == 0) ptc_key%method = bmad_com%default_integ_order 
if (present(integ_order)) ptc_key%method = integ_order

!

key = ele%key
if (.not. ele%is_on) key = drift$

select case (key)

case (drift$, rcollimator$, ecollimator$, monitor$, instrument$, pipe$) 
  ptc_key%magnet = 'drift'

case (quadrupole$) 
  ptc_key%magnet = 'quadrupole'
  ptc_key%list%k(2) = ele%value(k1$)

case (sbend$) 
  ptc_key%magnet = 'sbend'
  ptc_key%list%b0   = ele%value(g$) * leng ! Yep this is correct. 
  ptc_key%list%t1   = ele%value(e1$)
  ptc_key%list%t2   = ele%value(e2$)
  ptc_key%list%k(1) = ele%value(g_err$)
  ptc_key%list%k(2) = ele%value(k1$)
  ptc_key%list%k(3) = ele%value(k2$) / 2

case (sextupole$)
  ptc_key%magnet = 'sextupole'
  ptc_key%list%k(3) = ele%value(k2$) / 2

case (octupole$)
  ptc_key%magnet = 'octupole'
  ptc_key%list%k(4) = ele%value(k3$) / 6

case (solenoid$)
  ptc_key%magnet = 'solenoid'
  ptc_key%list%bsol = ele%value(ks$)

case (sol_quad$)
  ptc_key%magnet = 'solenoid'
  ptc_key%list%bsol = ele%value(ks$)
  ptc_key%list%k(2) = ele%value(k1$)

case (marker$, branch$, photon_branch$, init_ele$)
  ptc_key%magnet = 'marker'

case (kicker$, hkicker$, vkicker$)
  ptc_key%magnet = 'kicker'

! 

case (rfcavity$, lcavity$)
  beta = ele%value(p0c$) / ele%value(e_tot$)
  ptc_key%magnet = 'rfcavity'
  ptc_key%list%freq0 = ele%value(rf_frequency$)
  ptc_key%list%lag = twopi * (ele%value(phi0$) + ele%value(dphi0$) + ele%value(phi0_err$) + &
        ele%value(dphi0_ref$)) ! + pi * ptc_key%list%freq0 * leng / (beta * c_light) 
  if (ele%key == lcavity$) then
    ptc_key%list%lag = ptc_key%list%lag + pi / 2
    ptc_key%list%volt = 2e-6 * ele%value(l$) * &
                            (ele%value(gradient$) + ele%value(gradient_err$)) * ele%value(field_scale$)
  else
    ptc_key%list%volt = 2e-6 * ele%value(voltage$) * ele%value(field_scale$)
  endif

  ptc_key%list%delta_e = 0     ! For radiation calc.
  ptc_key%list%n_bessel = -1   ! Triggers Bmad compatible cavity.
  ptc_key%list%cavity_totalpath = 1  ! 
  ptc_key%list%permfringe = .true.

case (elseparator$)
  ptc_key%magnet = 'elseparator'
  hk = ele%value(hkick$) / leng
  vk = ele%value(vkick$) / leng
  if (hk == 0 .and. vk == 0) then
    ptc_key%tiltd = 0
  else
    if (param%particle < 0) then
      hk = -hk
      vk = -vk
    endif
    ptc_key%tiltd = -atan2 (hk, vk) + ele%value(tilt_tot$)
  endif
  ptc_key%list%volt = 1e-6 * ele%value(e_tot$) * sqrt(hk**2 + vk**2)
  call multipole_ele_to_ab (ele, +1, an0, bn0, .false.) 
  if (any(an0 /= 0) .or. any(bn0 /= 0)) then
    print *, 'ERROR IN ELE_TO_FIBRE: ', 'MULTIPOLES IN AN ELSEPARATOR NOT SUPPORTED IN A FIBRE.'
    if (bmad_status%exit_on_error) call err_exit
  endif

case (ab_multipole$, multipole$)
  ptc_key%magnet = 'multipole'

case (beambeam$)
  ptc_key%magnet = 'beambeam'
  print *, 'ERROR IN ELE_TO_FIBRE: BEAMBEAM ELEMENT NOT YET IMPLEMENTED!'
  if (bmad_status%exit_on_error) call err_exit

case (wiggler$)
  ptc_key%magnet = 'wiggler'

case default
  print *, 'ERROR IN ELE_TO_FIBRE: UNKNOWN ELEMENT CLASS: ', key_name(ele%key)
  print *, '      FOR ELEMENT: ', trim(ele%name)
  if (bmad_status%exit_on_error) call err_exit

end select

! multipole components
! bmad an and bn are integrated fields. PTC uses just the field.

if (ele%key /= elseparator$) then
  kick_here = .false.
  if (ele%key == hkicker$ .or. ele%key == vkicker$) then
    hk = 0; vk = 0
    if (ele%key == hkicker$) hk = ele%value(kick$) 
    if (ele%key == vkicker$) vk = ele%value(kick$) 
    kick_here = .true.
  elseif (ele%key == kicker$) then
    hk = ele%value(hkick$)
    vk = ele%value(vkick$)
    kick_here = .true.
  elseif (ele%value(hkick$) /= 0 .or. ele%value(vkick$) /= 0) then
    hk = ele%value(hkick$) / leng
    vk = ele%value(vkick$) / leng
    kick_here = .true.
  endif
  if (kick_here) then
    cos_t = cos(ele%value(tilt_tot$))
    sin_t = sin(ele%value(tilt_tot$))
    ptc_key%list%k(1)  = ptc_key%list%k(1) - hk * cos_t - vk * sin_t
    ptc_key%list%ks(1) =                   - hk * sin_t + vk * cos_t
  endif

  call multipole_ele_to_ab (ele, param%particle, an0, bn0, .false.)
  if (leng /= 0) then
    an0 = an0 / leng
    bn0 = bn0 / leng
  endif

  n = min(n_pole_maxx+1, size(ptc_key%list%k))
  if (n-1 < n_pole_maxx) then
    if (any(an0(n:n_pole_maxx) /= 0) .or. any(bn0(n:n_pole_maxx) /= 0)) then
      print *, 'WARNING IN ELE_TO_FIBRE: MULTIPOLE NOT TRANSFERED TO FIBRE'
      print *, '        FOR: ', ele%name
    endif
  endif
 
  ptc_key%list%ks(1:n) = ptc_key%list%ks(1:n) + an0(0:n-1)
  ptc_key%list%k(1:n) = ptc_key%list%k(1:n) + bn0(0:n-1)

  do n = nmax, 1, -1
    if (ptc_key%list%ks(n) /= 0 .or. ptc_key%list%k(n) /= 0) exit
  enddo
  ptc_key%list%nmul  = n
endif

!!call create_fibre (fiber, ptc_key, EXCEPTION, .true.)   ! ptc routine
n = lielib_print(12)
lielib_print(12) = 0  ! No printing info messages

call create_fibre_append (.false., m_u, ptc_key, EXCEPTION)   ! ptc routine
fiber => m_u%end%start

! 

m_u%end%closed=.true.

doneit=.true.
call ring_l(m_u%end,doneit)

call survey(m_u%end)
call MAKE_NODE_LAYOUT( m_u%end)

!

lielib_print(12) = n

energy_work = 0
if (ele_has_constant_reference_energy(ele)) then
  call find_energy (energy_work, p0c = 1d-9 * ele%value(p0c$))
else
  call find_energy (energy_work, p0c =  1d-9 * ele%value(p0c_start$))
endif
fiber = energy_work

! wiggler

if (key == wiggler$) then

  call get_field_ele_list (ele, field_eles, n_field)
  do i = 1, n_field
    ele2 => field_eles(i)%ele
    if (ele2%key == wiggler$) exit
  enddo

  s_rel = ele2%value(ds_field_offset$)

  if (hyper_x$ /= hyperbolic_xdollar .or. hyper_y$ /= hyperbolic_ydollar .or. &
                                        hyper_xy$ /= hyperbolic_xydollar) then
    print *, 'ERROR IN ELE_TO_FIBRE: WIGGLER FORM/TYPE MISMATCH!'
    print *, '     ', hyper_y$, hyper_xy$, hyper_x$
    print *, '     ', hyperbolic_ydollar, hyperbolic_xydollar, hyperbolic_xdollar
    if (bmad_status%exit_on_error) call err_exit
  endif

  n_term = size(ele2%wig%term)
  call init_sagan_pointers (fiber%mag%wi%w, n_term)   

  fiber%mag%wi%w%a(1:n_term) = c_light * ele2%value(polarity$) * ele2%wig%term%coef / ele%value(e_tot$)
  fiber%mag%wi%w%k(1,1:n_term)  = ele2%wig%term%kx
  fiber%mag%wi%w%k(2,1:n_term)  = ele2%wig%term%ky
  fiber%mag%wi%w%k(3,1:n_term)  = ele2%wig%term%kz
  fiber%mag%wi%w%f(1:n_term)    = ele2%wig%term%phi_z + s_rel * ele2%wig%term%kz
  fiber%mag%wi%w%form(1:n_term) = ele2%wig%term%type

  call copy (fiber%mag, fiber%magp)
endif

! Misalignments:
! in PTC the reference point for the offsets is the beginning of the element.
! In Bmad the reference point is the center of the element..

if (use_offsets) then
  x_off = ele%value(x_offset_tot$)
  y_off = ele%value(y_offset_tot$)
  x_pitch = ele%value(x_pitch_tot$)
  y_pitch = ele%value(y_pitch_tot$)

  if (x_off /= 0 .or. y_off /= 0 .or. x_pitch /= 0 .or. y_pitch /= 0) then
    mis_rot = (/ x_off, y_off, 0.0_rp, -y_pitch, -x_pitch,  0.0_rp /)
    angle = 0
    angle(3) = -fiber%mag%p%tiltd
    omega = fiber%chart%f%o
    basis = fiber%chart%f%mid
    call geo_rot(basis, angle, 1, basis)                 ! PTC call
    call misalign_fibre (fiber, mis_rot, omega, basis)   ! PTC call
  endif
endif

end subroutine ele_to_fibre

end module
