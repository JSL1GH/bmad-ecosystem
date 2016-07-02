!+
! Module longitudinal_profile_mod
!
! This module is for finding the bunch length taking RF and potential well distortion into account.
! It is a solver for equation 11 from "Bunch Lengthening Via Vlassov Theory" by M. G. Billing, CBN 79-32
!-
MODULE longitudinal_profile_mod

USE bmad
USE fgsl
USE, INTRINSIC :: iso_c_binding

IMPLICIT none

INTEGER(fgsl_size_t), PARAMETER :: limit = 1000_fgsl_size_t

CONTAINS

!+
! Function psi_prime(t, p, dpdt, params) RETURN (fgsl_success)
!
! This is equation 11 from CBN 79-32.  It is a dpsi/dt, where psi is the height of the 
! longitudinal profile and t is time.
!
! This function returns fgsl_success.
!
! Parameters (parama):
!  A = args(1)      ! Energy/(sigma_E^2)/(alpha_compaction/(T_ring_period)
!  Vrf = args(2)    !RF Voltage
!  Q = args(3)      !Total bunch charge in Coulombs
!  omega = args(4)  !RF Frequency
!  phi = args(5)    !Phase of bunch center relative to RF
!  R = args(6)      !Resistive part of impedance
!  L = args(7)      !Inductive part of impedance
!  U0 = args(8)     !Energy lost per turn per particle
!
! Input:
!   t            -- REAL(rp): time relative to RF bucket
!   p            -- REAL(rp): psi(t)
!   params       -- TYPE(c_ptr), VALUE: pointer to parameters and constants of DEQ
! Output:
!   dpdt         -- REAL(c_double), DIMENSION(*): dpsi_dt
!-
FUNCTION psi_prime(t, p, dpdt, params) BIND(c)
  IMPLICIT none

  REAL(c_double), VALUE :: t
  REAL(c_double), DIMENSION(*), INTENT(IN) :: p
  REAL(c_double), DIMENSION(*) :: dpdt
  TYPE(c_ptr), VALUE :: params
  INTEGER(c_int) :: psi_prime

  REAL(c_double), POINTER :: args(:)
  REAL(c_double) A, Vrf, Q, omega, phi, R, L, U0

  CALL c_f_pointer(params,args,[8])
  A = args(1)
  Vrf = args(2)
  Q = args(3)
  omega = args(4)
  phi = args(5)
  R = args(6)
  L = args(7)
  U0 = args(8)
  dpdt(1) = -A*p(1)*((Vrf*COS(omega*t+phi) + Q*R*p(1) - U0)/(1 + A*Q*L*p(1)))

  psi_prime = fgsl_success  !always return success
END FUNCTION psi_prime

!+
! Subroutine psi_prime_sca(t, p, dpdt, args)
!
! This wraps the array-valued psi_prime function as a scalar.
!
! See psi_prime comments for details.
!
! Input:
!   t         -- REAL(rp): time relative to RF bucket
!   p         -- REAL(rp): psi(t)
!   args(1:8) -- REAL(rp): parameters and constants of DEQ
! Output:
!   dpdt      -- REAL(rp): dpsi_dt
!   
!-
SUBROUTINE psi_prime_sca(t, p, dpdt, args)
  IMPLICIT NONE

  REAL(rp) t, p, dpdt
  REAL(rp), TARGET :: args(1:8)
  REAL(c_double) pa(1), dpdta(1)
  TYPE(c_ptr) ptr

  INTEGER status

  ptr = c_loc(args)

  pa(1) = p
  status = psi_prime(t, pa, dpdta, ptr)
  dpdt = dpdta(1)
END SUBROUTINE psi_prime_sca

!+
! Function jac(t, p, dfdp, dfdt, params)
!
! Where f = dpsi/dt, this returns df/dp and df/dt.
!
! Input:
!   t       -- REAL(c_double), VALUE: time relative to RF
!   p       -- REAL(c_double), DIMENSION(*): psi(t)
!   params  -- TYPE(c_ptr), VALUE: parameters.  See psi_prime comments for details.
! Output:
!   dfdp    -- REAL(c_double), DIMENSION(*): d(dpsi/dt)/dp
!   dfdt    -- REAL(c_double), DIMENSION(*): d(dpsi/dt)/dt
!-
FUNCTION jac(t, p, dfdp, dfdt, params) BIND(c)
  IMPLICIT none
  REAL(c_double), VALUE :: t
  REAL(c_double), DIMENSION(*), INTENT(IN) :: p
  REAL(c_double), DIMENSION(*) :: dfdp
  REAL(c_double), DIMENSION(*) :: dfdt
  TYPE(c_ptr), VALUE :: params
  INTEGER(c_int) :: jac

  REAL(c_double), POINTER :: args(:)
  REAL(c_double) A, Vrf, Q, omega, phi, R, L, U0

  CALL c_f_pointer(params,args,[8])
  A = args(1)
  Vrf = args(2)
  Q = args(3)
  omega = args(4)
  phi = args(5)
  R = args(6)
  L = args(7)
  U0 = args(8)

  dfdp(1) = -A*((Vrf*COS(omega*t+phi) - U0 + Q*R*p(1)*(2.0_rp + A*L*Q*p(1))) / ((1.0_rp + A*L*Q*p(1))**2))

  dfdt(1) = A*Vrf*p(1)*omega*SIN(omega*t + phi) / (1.0_rp + A*L*Q*p(1))

  jac = fgsl_success
END FUNCTION jac

!+
! Subroutine solve_psi_adaptive(t0,t1,p0,args,p1)
!
! Solve dpsi/dt for psi(t1) using adaptive steps and method:
!   "Implicit Bulirsch-Stoer method of Bader and Deuflhard."
!
! The boundary condition p0 is psi(t0)
!
! Input:
!   t0        -- REAL(fgsl_double), VALUE: initial time
!   t1        -- REAL(fgsl_double), VALUE: final time
!   p0        -- REAL(rp): Boundary condition psi(t0)
!   args(1:8) -- REAL(rp): Parameters.  See psi_prime comments for details.
! Output:
!   p1        -- REAL(rp): psi(t1)
!-
SUBROUTINE solve_psi_adaptive(t0,t1,p0,args,p1)
  IMPLICIT none
  
  REAL(fgsl_double), VALUE :: t0  ! fgsl_odeiv2_driver_* fails without VALUE
  REAL(fgsl_double) t1
  REAL(rp) p0
  REAL(rp), TARGET :: args(1:8)
  REAL(rp) p1
  type(fgsl_odeiv2_system) :: ode_system
  TYPE(fgsl_odeiv2_driver) :: ode_drv
  TYPE(c_ptr) ptr

  INTEGER status
  REAL(fgsl_double) y(1)
  REAL(fgsl_double) default_step
  REAL(fgsl_double), PARAMETER :: abs_err_goal = 0.0_fgsl_double
  REAL(fgsl_double), PARAMETER :: rel_err_goal = 1.0d-8

  default_step = (t1-t0)/100.d0

  ptr = c_loc(args)
  ode_system = fgsl_odeiv2_system_init(psi_prime, 1_c_size_t, ptr, jac)
  ode_drv = fgsl_odeiv2_driver_alloc_y_new(ode_system, fgsl_odeiv2_step_bsimp, default_step, abs_err_goal, rel_err_goal)

  y(1) = p0

  status = fgsl_odeiv2_driver_apply(ode_drv, t0, t1, y)

  IF(status /= fgsl_success) THEN
    WRITE(*,'(A)') "ERROR: fgsl_odeiv2_driver_apply failed during bunch length calculation."
    WRITE(*,'(A,2I6)') "fgsl_odeiv2_driver_apply returned (success is zero): ", status
    STOP
  ENDIF

  p1 = y(1)
  
  CALL fgsl_odeiv2_system_free(ode_system)
  CALL fgsl_odeiv2_driver_free(ode_drv)
END SUBROUTINE solve_psi_adaptive

!+
! Subroutine solve_psi_fixed_steps(t0,t1,p0,args,t,p)
!
! Solve dpsi/dt for psi(t1) using fixed steps and method:
!   "Implicit Bulirsch-Stoer method of Bader and Deuflhard."
!
! The boundary condition p0 is psi(t0).
!
! Number of steps is determined by SIZE(p).
!
! Input:
!   t0        -- REAL(fgsl_double), VALUE: initial time
!   t1        -- REAL(fgsl_double), VALUE: final time
!   p0        -- REAL(rp): Boundary condition psi(t0)
!   args(1:8) -- REAL(rp): Parameters.  See psi_prime comments for details.
! Output:
!   t(:)      -- REAL(rp): Array of times from t0 to t1
!   p(:)      -- REAL(rp): Array of psi evaluated at t(:)
!-
SUBROUTINE solve_psi_fixed_steps(t0,t1,p0,args,t,p)
  IMPLICIT none
  
  REAL(rp) t0
  REAL(rp) t1
  REAL(rp) p0
  REAL(rp), TARGET :: args(1:8)
  REAL(rp) t(:)
  REAL(rp) p(:)
  type(fgsl_odeiv2_system) :: ode_system
  TYPE(fgsl_odeiv2_driver) :: ode_drv
  TYPE(c_ptr) ptr

  INTEGER i
  INTEGER n
  INTEGER status
  REAL(fgsl_double) y(1)
  REAL(fgsl_double) tcur
  REAL(fgsl_double) step_size

  n = SIZE(p)
  step_size = (t1-t0)/(n-1)

  ptr = c_loc(args)
  ode_system = fgsl_odeiv2_system_init(psi_prime, 1_c_size_t, ptr, jac)
  ode_drv = fgsl_odeiv2_driver_alloc_y_new(ode_system, fgsl_odeiv2_step_bsimp, 1.0e-6_fgsl_double, 0.0_fgsl_double, 1.0E-7_fgsl_double)

  tcur = t0
  y(1) = p0

  t(1) = t0
  p(1) = p0

  DO i=2,n
    status = fgsl_odeiv2_driver_apply_fixed_step(ode_drv, tcur, step_size, 1_fgsl_long, y)

    IF(status /= fgsl_success) THEN
      WRITE(*,'(A)') "ERROR: fgsl_odeiv2_driver_apply_fixed_step failed during bunch length calculation."
      WRITE(*,'(A,2I6)') "fgsl_odeiv2_driver_apply_fixed_step returned ", status, fgsl_success
      STOP
    ENDIF

    t(i) = tcur
    p(i) = y(1)
  ENDDO
  
  CALL fgsl_odeiv2_system_free(ode_system)
  CALL fgsl_odeiv2_driver_free(ode_drv)
END SUBROUTINE solve_psi_fixed_steps

!+
! Subroutine integrate_psi(bound,p0,args,result)
!
! Integrate psi(t) from -bound to +bound.  The integration is done in two parts.  First from 0 to -bound, then from
! 0 to +bound.
!
! Input:
!   bound      -- REAL(rp): integration bound
!   p0         -- REAL(rp): psi(0).  Boundary condition.
!   args(1:8)  -- REAL(rp): Parameters and constants of DEQ.  See psi_prime comments for details.
! Output:
!   result     -- REAL(rp): Integral of psi from -bound to +bound.
!-
SUBROUTINE integrate_psi(bound,p0,args,result)
  REAL(rp) bound
  REAL(rp) p0
  INTEGER npts
  REAL(rp) args(1:8)
  REAL(rp) result

  INTEGER i

  REAL(rp), ALLOCATABLE :: t(:)
  REAL(rp), ALLOCATABLE :: tminus(:)
  REAL(rp), ALLOCATABLE :: tplus(:)
  REAL(rp), ALLOCATABLE :: p(:)
  REAL(rp), ALLOCATABLE :: pminus(:)
  REAL(rp), ALLOCATABLE :: pplus(:)

  npts = 100

  ALLOCATE(tplus(1:npts))
  ALLOCATE(tminus(1:npts))
  ALLOCATE(t(1:2*npts-1))
  ALLOCATE(pplus(1:npts))
  ALLOCATE(pminus(1:npts))
  ALLOCATE(p(1:2*npts-1))

  CALL solve_psi_fixed_steps(0.0_rp,-bound,p0,args,tminus,pminus)
  CALL solve_psi_fixed_steps(0.0_rp,bound,p0,args,tplus,pplus)

  DO i=1,npts
    t(i) = tminus(npts-i+1)
    p(i) = pminus(npts-i+1)
  ENDDO
  t(npts+1:2*npts-1) = tplus(2:npts)
  p(npts+1:2*npts-1) = pplus(2:npts)

  result = 0.0d0
  DO i=1,2*npts-2
    result = result + (t(i+1)-t(i))*(p(i+1)+p(i))/2.0d0
  ENDDO

  result = result - 1.0d0

  DEALLOCATE(tplus)
  DEALLOCATE(tminus)
  DEALLOCATE(t)
  DEALLOCATE(pplus)
  DEALLOCATE(pminus)
  DEALLOCATE(p)

END SUBROUTINE integrate_psi

!+
! Subroutine find_normalization(bound,p0,args,pnrml)
!
! Finds value for boundary condition psi(0) that results in integral
! of psi(t) from -bound to +bound to be 1.0.  This is done with the secant method.
! Repeadedly calls integrate_psi with different values for psi(0).
!
! Input:
!   bound     -- REAL(rp): -bound and +bound are integration boundaries
!   p0        -- REAL(rp): Boundary condition psi(0)
!   args(1:8) -- REAL(rp): Parameters and constants of DEQ.  See psi_prime comments for details.
! Output:
!   pnrml     -- REAL(rp): Value for psi(0) that results in integral of psi(t) from -bound to +bound being equal to 1.0
!-
SUBROUTINE find_normalization(bound,p0,args,pnrml)
  !Secant Method
  REAL(rp) bound
  REAL(rp) p0
  REAL(rp) args(1:8)
  REAL(rp) pnrml

  REAL(rp) f(1:3) !f(1) is f(n), f(2) is f(n-1), f(3) is f(n-2)
  REAL(rp) x(1:3) !x(1) is x(n), x(2) is x(n-1), x(3) is x(n-2)

  x(3) = p0*0.95d0
  CALL integrate_psi(bound,x(3),args,f(3))

  x(2) = p0*1.05d0
  DO WHILE(.true.)
    CALL integrate_psi(bound,x(2),args,f(2))
    x(1) = x(2) - f(2)*(x(2)-x(3))/(f(2)-f(3))

    IF(ABS((x(1)-x(2))/x(2)) .lt. 1.0d-7) EXIT

    x(3) = x(2)
    x(2) = x(1)
    f(3) = f(2)
  ENDDO

  pnrml = x(1)
END SUBROUTINE find_normalization

!+
! Subroutine find_fwhm(bound,args,fwhm)
!
! Finds the full width at half max of psi(t).  fwhm * c_light / TwoRtTwoLnTwo is taken as the bunch length.
!
! Steps followed:
!   Find value for p(0) that normalizes the solution to dpsi/dt.
!   Find max value of p(t) for the value of p(0) found in the previous step.
!   Find find tlower, tlower < 0, such that p(tlower) = pmax/2.
!   Find find tupper, tupper > 0, such that p(tupper) = pmax/2.
!   fwhm is tupper-tlower
!
! Input:
!   bound      -- REAL(rp): -bound and +bound is integration bound.
!   args(1:8)  -- REAL(rp): Parameters and constants of dpsi/dt.  See comments of psi_prime for details.
! Output:
!   fwhm       -- REAL(rp): Full width at half max of psi(t)
!-
SUBROUTINE find_fwhm(bound,args,fwhm)
  IMPLICIT NONE

  REAL(rp) bound
  REAL(rp) args(1:8)
  REAL(rp) fwhm
  REAL(rp) p0
  REAL(rp) pnrml
  REAL(rp) ta(1:2)
  REAL(rp) pa(1:2)
  REAL(rp) p2
  REAL(rp) half_max_psi
  REAL(rp) lower_value
  REAL(rp) upper_value
  REAL(rp) xmax, xmin, xnew
  REAL(rp) fnew, dpdt
  REAL(rp) f(1:3)
  REAL(rp) x(1:3)

  REAL(rp) max_time, max_psi

  INTEGER status

  !-
  !- Step 1: Find Max
  !-
  !- Secant method not guaranteed to converge ... using bisection instead
  p0 = 1.0d9 !initial guess for normalization
  CALL find_normalization(bound,p0,args,pnrml)

  xmax = 0.0d0
  xmin = -bound

  DO WHILE(.true.)
    xnew = xmin+(xmax-xmin)/2.0d0
    CALL solve_psi_adaptive(0.0d0,xnew,pnrml,args,fnew)
    CALL psi_prime_sca(xnew, fnew, dpdt, args)

    IF( dpdt .gt. 0.0d0 ) THEN
      xmin = xnew
    ELSE
      xmax = xnew
    ENDIF

    IF(ABS((xmax-xmin)/xmax) .lt. 1.0d-8) EXIT
  ENDDO

  max_time = xnew
  max_psi = fnew
  half_max_psi = max_psi / 2.0d0

  !-
  !- Step 2: Find Lower Value
  !-
  x(3) = -bound
  CALL solve_psi_adaptive(0.0d0,x(3),pnrml,args,f(3))
  f(3) = f(3) - half_max_psi

  x(2) = max_time
 
  DO WHILE(.true.)
    CALL solve_psi_adaptive(0.0d0,x(2),pnrml,args,f(2))
    f(2) = f(2) - half_max_psi

    x(1) = x(2) - f(2) * (x(2)-x(3)) / (f(2)-f(3))
    x(1) = MIN(x(1), max_time)

    IF( ABS((x(1)-x(2))/x(1)) .lt. 1.0d-8 ) EXIT

    x(3) = x(2)
    f(3) = f(2)
    x(2) = x(1)
  ENDDO

  lower_value = x(1)

  !-
  !- Step 3: Find Upper Value
  !-
  x(3) = bound
  CALL solve_psi_adaptive(0.0d0,x(3),pnrml,args,f(3))
  f(3) = f(3) - half_max_psi

  x(2) = max_time
 
  DO WHILE(.true.)
    CALL solve_psi_adaptive(0.0d0,x(2),pnrml,args,f(2))
    f(2) = f(2) - half_max_psi

    x(1) = x(2) - f(2) * (x(2)-x(3)) / (f(2)-f(3))
    x(1) = MAX(x(1), max_time)

    IF( ABS((x(1)-x(2))/x(1)) .lt. 1.0d-7 ) EXIT

    x(3) = x(2)
    f(3) = f(2)
    x(2) = x(1)
  ENDDO

  upper_value = x(1)

  fwhm = upper_value - lower_value

END SUBROUTINE find_fwhm

!+
! Subroutine get_bl_from_fwhm(bound,args,sigma)
!
! Calculate bunch length as fwhm * c_light / TwoRtTwoLnTwo.
! Where fwhm is full width at half max of solution to dpsi/dt.
!
! Input:
!   bound     -- REAL(rp): -bound and +bound are lower and upper integration bound.
!   args(1:8) -- REAL(rp): Parameters and constants of dpsi/dt.  See comments of psi_prime for details.
! Output:
!   sigma     -- REAL(rp): Bunch length
!-
SUBROUTINE get_bl_from_fwhm(bound,args,sigma)
  IMPLICIT none

  REAL(rp) bound
  REAL(rp) args(1:8)
  REAL(rp) sigma
  REAL(rp) fwhm
  REAL(rp), PARAMETER :: TwoRtTwoLnTwo = 2.354820045030949

  CALL find_fwhm(bound,args,fwhm)

  sigma = fwhm * c_light / TwoRtTwoLnTwo
END SUBROUTINE get_bl_from_fwhm

!+
! Function pwd_mat(t6, inductance, sig_z) result (t6_pwd)
!
! Calculates potential well distortion as RF defocusing.  Calculates t6_pwd=t6.Mpwd,
! where Mpwd is identity with 65 element proportional to the inductance.
!
! Vpwd = -inductance * lat%param%n_part * e_charge * c_light**3 / SQRT(twopi) / sig_z**3 / omega_RF  !effective RF voltage from PWD
! Mpwd(6,5) = omega_RF * Vpwd / c_light / lat%ele(0)%value(E_TOT$) * branch%ele(i)%value(l$) / lat%param%total_length
!
! Input:
!   lat                      -- TYPE(lat_struct)
!      %param%n_part         -- real(rp): Bunch current in # per bunch
!      %ele(0)%value(E_TOT$) -- real(rp): Beam energy
!   t6(6,6)                  -- real(rp): 1-turn transfer matrix
!   inductance               -- real(rp): Longitudinal inductance in Henrys.  Something on the order of nH.
!   sig_z                    -- real(rp): Bunch length.
!
! Output:
!   t6_pwd(6,6)              -- real(rp): 1-turn transfer matrix with PWD defocusing applied
!-

FUNCTION pwd_mat(lat, t6, inductance, sig_z) result (t6_pwd)
  TYPE(lat_struct) lat
  REAL(rp) t6(6,6)
  REAL(rp) t6_pwd(6,6)
  REAL(rp) inductance
  REAL(rp) sig_z

  real(rp) Mpwd(6,6)
  real(rp) Vpwd

  Mpwd = 0
  Mpwd(1,1) = 1
  Mpwd(2,2) = 1
  Mpwd(3,3) = 1
  Mpwd(4,4) = 1
  Mpwd(5,5) = 1
  Mpwd(6,6) = 1
  Mpwd(6,5) = -inductance * lat%param%n_part * e_charge * c_light**2 / SQRT(twopi) / sig_z**3 / lat%ele(0)%value(E_TOT$)

  t6_pwd = MATMUL(Mpwd,t6)
END FUNCTION pwd_mat

END MODULE longitudinal_profile_mod










