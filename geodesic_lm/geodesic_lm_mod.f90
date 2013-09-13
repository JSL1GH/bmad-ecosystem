module geodesic_lm_mod

use sim_utils
use geolevmar_module !contained in leastsq.f90

type geodesic_lm_param_struct
  integer :: mode = 0           !LM damping matrix. 0->id, 1->dynamic jacob-based
  integer :: maxiter = 0        !max # of routine iterations
  integer :: maxfev = 0         !max # of func evals (0-> no limit)
  integer :: maxjev = 0         !max number of jac evals (0->no limit)
  integer :: maxaev = 0         !max number of dir second derivs (0->no limit)
  integer :: print_level = 5    !how many details to be printed (0-5) 
  integer :: print_unit = 10    !unit number details written to
  integer :: imethod = 10        !method choice for updating LM parameter
  integer :: iaccel = 1         ! use geodesic acceleration or not
  integer :: ibold = 0          ! 'boldness' in accepting uphill (0->downhill)
  integer :: ibroyden = 0       ! number of iterations using approximate jacobian

  real(rp) :: eps = 1.5E-6      !function evaluation precision
  real(rp) :: h1=1.D-6,h2=1.D-1 !controls step sizes for finite diff derivatives
                                !h1 for jacobian, h2 for dir second deriv
  !! Stopping criterion
  real(rp) :: maxlam = 1E7     !limit on damping term lambda (if <0 no limit)
  real(rp) :: artol = 1.E-3     !cos of angle between residual and tangent plane
  real(rp) :: Cgoal  = 1       !Cost lower limit (ends when falls below)
  real(rp) :: gtol  = 1.5E-8    !gradient lower limit
  real(rp) :: xtol = 1.E-10     !step size lower limit (ll)
  real(rp) :: xrtol = 1.5E-8    !relative parameter change ll
  real(rp) :: ftol = 1.5E-8     !consecutive cost difference ll
  real(rp) :: frtol = 1.5E-8    !relative consecutive cost diff ll
  !!
  real(rp) :: initialfactor = 1. !initial LM param or step size
  real(rp) :: factoraccept  = 5. !(if imethod=0 or 10) adjusts initialfactor
  real(rp) :: factorreject  = 2. !adjusts initialfactor for rejected step
  real(rp) :: avmax = 0.8         !limits geo accel w.r.t. velocity

  logical :: analytic_jac = .true.
  logical :: analytic_avv = .false.
  logical :: center_diff = .true.

  logical :: geo_hit_limit= .true.
end type 

type (geodesic_lm_param_struct), save, target ::  geodesic_lm_param

contains

!--------------------------------------------------------------------------------
!--------------------------------------------------------------------------------
!--------------------------------------------------------------------------------
!+
! Subroutine type_geodesic_lm (lines, n_lines)
!
! Routine to print or put information into a string array of the geodesic_lm parameters.
! If "lines" is not present, the information will be printed to the screen.
!
! Module needed:
!   use geodesic_lm_mod
!
! Input:
!   print_coords -- logical, optional: If True then print coordinate and  patch information.
!                     Default is True.
!
! Output:
!   lines(:)  -- character(120), optional, allocatable: Character array to hold the output.
!   n_lines   -- integer, optional: Number of lines used in lines(:)

subroutine type_geodesic_lm (lines, n_lines)

integer, optional :: n_lines
integer i, nl

character(*), allocatable, optional :: lines(:)
character(160) :: li(40)
character(20) imt, rmt, lmt

!

rmt  = '(a, 9es16.8)'
imt  = '(a, 9i8)'
lmt  = '(a, 9(l3))'

nl = 0
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%mode             =', geodesic_lm_param%mode
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%maxiter          =', geodesic_lm_param%maxiter
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%maxfev           =', geodesic_lm_param%maxfev
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%maxjev           =', geodesic_lm_param%maxjev
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%maxaev           =', geodesic_lm_param%maxaev
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%print_level      =', geodesic_lm_param%print_level
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%print_unit       =', geodesic_lm_param%print_unit
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%imethod          =', geodesic_lm_param%imethod
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%iaccel           =', geodesic_lm_param%iaccel
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%ibold            =', geodesic_lm_param%ibold
nl=nl+1; write (lines(nl), imt) 'geodesic_lm_param%ibroyden         =', geodesic_lm_param%ibroyden

nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%eps              =', geodesic_lm_param%eps
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%h1               =', geodesic_lm_param%h1
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%h2               =', geodesic_lm_param%h2
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%maxlam           =', geodesic_lm_param%maxlam
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%artol            =', geodesic_lm_param%artol
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%Cgoal            =', geodesic_lm_param%Cgoal
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%gtol             =', geodesic_lm_param%gtol
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%xtol             =', geodesic_lm_param%xtol
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%xrtol            =', geodesic_lm_param%xrtol
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%ftol             =', geodesic_lm_param%ftol
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%frtol            =', geodesic_lm_param%frtol
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%initialfactor    =', geodesic_lm_param%initialfactor
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%factoraccept     =', geodesic_lm_param%factoraccept
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%factorreject     =', geodesic_lm_param%factorreject
nl=nl+1; write (lines(nl), rmt) 'geodesic_lm_param%avmax            =', geodesic_lm_param%avmax

nl=nl+1; write (lines(nl), lmt) 'geodesic_lm_param%analytic_jac     =', geodesic_lm_param%analytic_jac
nl=nl+1; write (lines(nl), lmt) 'geodesic_lm_param%analytic_avv     =', geodesic_lm_param%analytic_avv
nl=nl+1; write (lines(nl), lmt) 'geodesic_lm_param%center_diff      =', geodesic_lm_param%center_diff

if (present(lines)) then
  call re_allocate(lines, nl, .false.)
  n_lines = nl
  lines(1:nl) = li(1:nl)
else
  do i = 1, nl
    print *, trim(li(i))
  enddo
endif

end subroutine type_geodesic_lm

!--------------------------------------------------------------------------------
!--------------------------------------------------------------------------------
!--------------------------------------------------------------------------------
!+
! Subroutine type_geodesic_lm (printit, lines, n_lines)

end module
