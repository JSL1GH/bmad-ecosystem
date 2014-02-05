PROGRAM ibs_ring

USE bmad
USE mode3_mod
USE ibs_mod
!$ USE omp_lib  !note conditional compilation only when openmp enabled
USE sim_utils_interface
USE mode3_mod
USE longitudinal_profile_mod

IMPLICIT none

TYPE ibs_data_struct
  REAL(rp) current
  REAL(rp) a_emittance
  REAL(rp) b_emittance
  REAL(rp) sigE_E
  REAL(rp) sigma_x
  REAL(rp) sigma_y
  REAL(rp) sigma_z
END TYPE ibs_data_struct

TYPE(ibs_data_struct), ALLOCATABLE :: ibs_data(:)

REAL(rp) current
REAL(rp) mA_per_bunch
REAL(rp) :: b_emit = -1.0
REAL(rp) :: a_emit = -1.0
REAL(rp) :: energy_spread = -1.0
REAL(rp) ratio
REAL(rp) view_sigma_x, view_sigma_y, view_sigma_z
REAL(rp) dnpart, delta_mA, stop_mA
REAL(rp) granularity
REAL(rp) npart0
REAL(rp) inductance
REAL(rp) resistance
REAL(rp) eta_set, etap_set
REAL(rp) Ta, Tb, Tz
REAL(rp) t6(6,6)
REAL(rp) Mpwd(6,6)
REAL(rp) Vpwd
REAL(rp) sigma_mat(6,6)

LOGICAL error, ok, do_pwd, insane
LOGICAL set_dispersion

CHARACTER(50) in_file
CHARACTER(4) ibs_formula
CHARACTER(3) eqb_method
CHARACTER(130) lat_file

INTEGER x_view, y_view, z_view
INTEGER omp_i, omp_n
INTEGER i, j, n_steps
INTEGER radcache
INTEGER stdoutlun, dotinlun
INTEGER emitlun
INTEGER rateslun
INTEGER clog_to_use

TYPE(ibs_struct) rates
TYPE(normal_modes_struct) mode
TYPE(normal_modes_struct) mode0
TYPE(lat_struct) :: lat
TYPE(ibs_sim_param_struct) ibs_sim_params
TYPE(coord_struct), TARGET, ALLOCATABLE :: orb(:)

TYPE(lat_struct), ALLOCATABLE :: omp_lat(:)

NAMELIST /parameters/ lat_file, &        ! Lattice file in BMAD format.
                      b_emit, &          ! Zero current vertical emittance.  Set to -1 for rad int calc.
                      a_emit, &          ! Zero current horizontal emittance.  Set to -1 for rad int calc.
                      energy_spread, &   ! Zero current energy spread.  Set to -1 for rad int calc.
                      mA_per_bunch, &    ! Largest current per bunch in mA.
                      delta_mA, &        ! mA step size.
                      stop_mA, &         ! Smallest current per bunch in mA.
                      ibs_formula, &     ! 'cimp', 'bjmt', 'bane', 'mpzt', 'mpxx', 'kubo'
                      ratio, &           ! "Coupling parameter r" hack for including coupling.
                      x_view, &          ! index of element where projection is taken for horizontal beam size calculation.
                      y_view, &          ! index of element where projection is taken for vertical beam size calculation.
                      z_view, &          ! index of element where projection is taken for longitudinal beam size calculation.
                      do_pwd, &          ! .true. or .false., whether to do PWD calculation.
                      granularity, &     ! Step size along lattice in meters.  Set to -1 for element-by-element.
                      resistance, &      ! Resistive inductance for PWD calc.  Currently not used. 
                      inductance, &      ! Longitudinal inductance for PWD calc.  Effects bunch length vs. current.
                      clog_to_use, &     ! 1=classic, no tail cut.  2=Raubenheimer.  3=Oide, 4=Bane.  See multi_coulomb_log in ibs_mod.f90
                      eqb_method, &      ! 'der' for derivatives.  'rlx' for relaxation approach.  Use 'der'.
                      eta_set, &         ! Used only if ibs_formula set to 'kubo'.  Applies x-pz coupling to each element of lattice when calculating IBS rates.
                      etap_set, &        ! Used only if ibs_formula set to 'kubo'.  Applies px-pz coupling to each element of lattice when calculating IBS rates.
                      set_dispersion     ! If true, then apply eta_set and etap_set.  If false, then do not.


!-Set bogus values for namelist parameters, so we can check that they were
!-set by the .in file.
lat_file      = ''
b_emit        = -99.0
a_emit        = -99.0
energy_spread = -99.0
mA_per_bunch  = -99.0
ibs_formula   = ''
ratio         = -99.0
delta_mA      = -99.0
stop_mA       = -99.0
x_view        = 0
y_view        = 0
z_view        = 0
granularity   = -1.0
inductance    = -99.0
resistance    = -99.0
clog_to_use   = -99
eqb_method    = ''
set_dispersion = .false.
do_pwd = .true.

dotinlun = LUNGET()
CALL getarg(1,in_file)
OPEN(dotinlun,FILE=in_file,STATUS='OLD')
READ(dotinlun,NML=parameters)
CLOSE(dotinlun)

!-Check if any parameters were missing from the .in file.
IF( lat_file == '' ) CALL param_bomb('lat_file')
IF( b_emit .lt. -90 ) CALL param_bomb('b_emit')
IF( a_emit .lt. -90 ) CALL param_bomb('a_emit')
IF( energy_spread .lt. -90 ) CALL param_bomb('energy_spread')
IF( mA_per_bunch .lt. -90 ) CALL param_bomb('mA_per_bunch')
IF( ibs_formula == '' ) CALL param_bomb('ibs_formula')
IF( ratio .lt. -90 ) CALL param_bomb('ratio')
IF( delta_mA .lt. -90 ) CALL param_bomb('delta_mA')
IF( stop_mA .lt. -90 ) CALL param_bomb('stop_mA')
IF( x_view .lt. -90 ) CALL param_bomb('x_view')
IF( y_view .lt. -90 ) CALL param_bomb('y_view')
IF( z_view .lt. -90 ) CALL param_bomb('z_view')
IF( granularity .lt. -90 ) CALL param_bomb('granularity')
IF( inductance .lt. -90 ) CALL param_bomb('inductance')
IF( resistance .lt. -90 ) CALL param_bomb('resistance')
IF( clog_to_use .lt. -90 ) CALL param_bomb('clog_to_use')
IF( eqb_method == '' ) CALL param_bomb('eqb_method')

stdoutlun = LUNGET()
OPEN(stdoutlun,FILE='std.out.snip')

WRITE(*,*) "Preparing lattice..."

CALL bmad_parser(lat_file, lat)
CALL set_on_off(rfcavity$, lat, on$)

CALL closed_orbit_calc(lat,orb,6)
call lat_make_mat6(lat, -1, orb)
CALL twiss_at_start(lat)
CALL twiss_propagate_all(lat)
radcache = 0
CALL radiation_integrals(lat, orb, mode, radcache)
CALL calc_z_tune(lat)

WRITE(*,*) "Lattice preparation complete..."

!ibs_sim_params%co => orb

IF( b_emit .gt. 0.0 ) THEN
  mode%b%emittance = b_emit
ENDIF
IF( a_emit .gt. 0.0 ) THEN
  mode%a%emittance = a_emit
ENDIF
IF( energy_spread .gt. 0.0 ) THEN
  mode%sigE_E = energy_spread
ENDIF

DO i=6,stdoutlun,stdoutlun-6
  WRITE(i,*) "Beam distribution parameters before IBS:"
  WRITE(i,*) "   emit_a      : ", mode%a%emittance
  WRITE(i,*) "   emit_b      : ", mode%b%emittance
  WRITE(i,*) "   sigmaE_E    : ", mode%sigE_E
  WRITE(i,*) "   sigma_z     : ", mode%sig_z
  WRITE(i,*)
ENDDO

!compute the SR betatron damping time
ibs_sim_params%tau_a = lat%param%total_length / c_light / mode%a%alpha_damp
ibs_sim_params%clog_to_use = clog_to_use
ibs_sim_params%set_dispersion = set_dispersion
ibs_sim_params%eta_set = eta_set
ibs_sim_params%etap_set = etap_set
ibs_sim_params%inductance = inductance
ibs_sim_params%resistance = resistance
ibs_sim_params%do_pwd = do_pwd
ibs_sim_params%formula = ibs_formula

mode0=mode
npart0 = mA_per_bunch*0.001_rp*(lat%param%total_length/c_light)/e_charge
lat%param%n_part = npart0

IF(eqb_method == 'rlx') THEN
  CALL ibs_equib_rlx(lat,ibs_sim_params,mode0,mode,ratio,8.0_rp,granularity)  !relaxation method
ELSEIF(eqb_method == 'der') THEN
  CALL ibs_equib_der(lat,ibs_sim_params,mode0,mode,granularity)  !derivatives method
ELSE
  WRITE(*,*) "ERROR: Unrecognized setting for eqb_method: ", eqb_method
  WRITE(*,*) "TERMINATING EXECUTION"
  STOP
ENDIF

DO i=6,stdoutlun,stdoutlun-6
  WRITE(i,*) "Beam distribution parameters after IBS:"
  WRITE(i,*) "   emit_a      : ", mode%a%emittance
  WRITE(i,*) "   emit_b      : ", mode%b%emittance
  WRITE(i,*) "   sigmaE_E    : ", mode%sigE_E
  WRITE(i,*) "   sigma_z     : ", mode%sig_z
  WRITE(i,*)
ENDDO

WRITE(*,*) "Original Tunes:"
WRITE(*,*) "   a tune: ", lat%ele(lat%n_ele_track)%a%phi/twopi
WRITE(*,*) "   b tune: ", lat%ele(lat%n_ele_track)%b%phi/twopi
WRITE(*,*) "   z tune: ", lat%z%tune/twopi

n_steps = CEILING( (mA_per_bunch-stop_mA) / delta_mA)
n_steps = MAX(1,n_steps)
ALLOCATE(ibs_data(1:n_steps))
IF(n_steps .gt. 1) THEN
  dnpart = (mA_per_bunch-stop_mA)/(n_steps-1) * 0.001_rp*(lat%param%total_length/c_light)/e_charge
ELSE
  dnpart = 0.0d0
ENDIF

omp_n = 1  !used when omp not enabled
!$ omp_n = omp_get_max_threads()
ALLOCATE(omp_lat(omp_n))
!$ WRITE(*,*) "Copying lattice for this many OMP threads: ", omp_n
DO i=1,omp_n
  omp_lat(i) = lat
ENDDO

DO i=1,omp_n
  CALL lat_sanity_check(omp_lat(i), insane)
  IF (insane) THEN
    WRITE(*,*) "Lattice ", i, " failed sanity check!"
  ENDIF
ENDDO

!$OMP PARALLEL DO &
!$OMP DEFAULT(PRIVATE), &
!$OMP SHARED(omp_lat,ibs_data), &    !these are indexed such that multiple threads will never write to same memory location at same time
!$OMP SHARED(n_steps,npart0,dnpart,mode0,ratio,granularity,eqb_method), &             !these are read only, so it is ok to share
!$OMP SHARED(ibs_sim_params), & !read only
!$OMP SHARED(x_view, y_view, z_view), &
!$OMP PRIVATE(current,mode), &
!$OMP PRIVATE(view_sigma_x,view_sigma_y,view_sigma_z), &  !these are working space for each thread
!$OMP PRIVATE(t6,Vpwd,Mpwd,sigma_mat, error)     !these are working space for each thread
DO i=1,n_steps
  omp_i = 1   !used when omp not enabled
  !$ omp_i = omp_get_thread_num()+1
  omp_lat(omp_i)%param%n_part = npart0 - dnpart*(i-1)
  current = omp_lat(omp_i)%param%n_part*e_charge/(omp_lat(omp_i)%param%total_length/c_light)

  if(eqb_method == 'rlx') THEN
    CALL ibs_equib_rlx(omp_lat(omp_i),ibs_sim_params,mode0,mode,ratio,8.0_rp,granularity)  !relaxation method
  ELSEIF(eqb_method == 'der') THEN
    CALL ibs_equib_der(omp_lat(omp_i),ibs_sim_params,mode0,mode,granularity)  !derivatives method
  ELSE
    WRITE(*,*) "ERROR: Unrecognized setting for eqb_method: ", eqb_method
    WRITE(*,*) "TERMINATING EXECUTION"
    STOP
  ENDIF

  CALL transfer_matrix_calc (omp_lat(omp_i), .true., t6, ix1=x_view, one_turn=.TRUE.)
  CALL pwd_mat(omp_lat(omp_i), t6, t6, ibs_sim_params%inductance, mode%sig_z)
  CALL make_smat_from_abc(t6, mode, sigma_mat, error)
  view_sigma_x = SQRT(sigma_mat(1,1))

  CALL transfer_matrix_calc (omp_lat(omp_i), .true., t6, ix1=y_view, one_turn=.TRUE.)
  CALL pwd_mat(omp_lat(omp_i), t6, t6, ibs_sim_params%inductance, mode%sig_z)
  CALL make_smat_from_abc(t6, mode, sigma_mat, error)
  view_sigma_y = SQRT(sigma_mat(3,3))

  CALL transfer_matrix_calc (omp_lat(omp_i), .true., t6, ix1=z_view, one_turn=.TRUE.)
  CALL pwd_mat(omp_lat(omp_i), t6, t6, ibs_sim_params%inductance, mode%sig_z)
  CALL make_smat_from_abc(t6, mode, sigma_mat, error)
  view_sigma_z = SQRT(sigma_mat(5,5))

!  CALL project_emit_to_xyz(omp_lat(omp_i), x_view, mode, view_sigma_x, xview_sigma_y, view_sigma_z)
!  CALL project_emit_to_xyz(omp_lat(omp_i), y_view, mode, yview_sigma_x, view_sigma_y, yview_sigma_z)

  ibs_data(i) = ibs_data_struct(current,mode%a%emittance,mode%b%emittance,mode%sigE_E, view_sigma_x, view_sigma_y, view_sigma_z)

  WRITE(*,'(A,I10,A,I10,A)') "Step ", i, " of ", n_steps, " complete!"
ENDDO
!$OMP END PARALLEL DO

rateslun = LUNGET()
OPEN(rateslun,FILE='ibs_rates.out')
WRITE(rateslun,'(A)') "# ele ix, s, inv_Ta, inv_Tb, inv_Tz"
lat%param%n_part = npart0
CALL ibs_equib_der(lat,ibs_sim_params,mode0,mode,-1.0_rp)
DO j=1, lat%n_ele_track
  IF(lat%ele(j)%value(l$) .GT. 0.0) THEN
    lat%ele(j)%a%emit = mode%a%emittance
    lat%ele(j)%b%emit = mode%b%emittance
    lat%ele(j)%z%sigma = mode%sig_z
    lat%ele(j)%z%sigma_p = mode%sigE_E
    lat%ele(j)%z%emit = mode%sig_z * mode%sigE_E

    CALL ibs1(lat,ibs_sim_params,rates,j)
    WRITE(rateslun,'(I0,F11.3,3ES14.4)') j, lat%ele(j)%s, rates%inv_Ta, rates%inv_Tb, rates%inv_Tz
  ENDIF
ENDDO
CLOSE(rateslun)

emitlun = LUNGET()
OPEN(emitlun, FILE='emittance.dat',STATUS='REPLACE')
WRITE(emitlun,'(A,I0,"   ",A)') "# sigma_x calculated at ", x_view, lat%ele(x_view)%name
WRITE(emitlun,'(A,I0,"   ",A)') "# sigma_y calculated at ", y_view, lat%ele(y_view)%name
WRITE(emitlun,'(A,I0,"   ",A)') "# sigma_z calculated at ", z_view, lat%ele(y_view)%name
WRITE(emitlun,'(A14,6A18)') "# current", "emit_a", "emit_b", "sigE/E", "sigma_x", "sigma_y", "sigmz_z"
DO i=1,n_steps
  WRITE(emitlun,"(ES18.8,'   ',ES15.8,'   ',ES15.8,'   ',ES15.8,'   ',ES15.8,'   ',ES15.8,'   ',ES15.8)") ibs_data(i)
ENDDO
CLOSE(emitlun)

CLOSE(stdoutlun)

DEALLOCATE(omp_lat)
IF( ALLOCATED(orb) ) DEALLOCATE(orb)
DEALLOCATE(ibs_data)

END PROGRAM ibs_ring

SUBROUTINE param_bomb(parameter)
  CHARACTER(*) parameter
  WRITE(*,*) "ERROR: parameter '", parameter, "' is missing from the .in file."
  WRITE(*,*) "TERMINATING EXECUTION"
  STOP
END SUBROUTINE param_bomb


