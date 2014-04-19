!+
! Actually this module is more properly named constants since
! it evolved to define more than just physical constants.
!-

module physical_constants

use precision_def

real(rp), parameter :: pi = 3.14159265358979d0
real(rp), parameter :: twopi = 2 * pi
real(rp), parameter :: fourpi = 4 * pi
real(rp), parameter :: sqrt_2 = 1.41421356237310d0
real(rp), parameter :: sqrt_3 = 1.73205080757d0

real(rp), parameter :: e_mass = 0.510998910d-3           ! DO NOT USE   ! In GeV
real(rp), parameter :: p_mass   = 0.938272046d0          ! DO NOT USE   ! In GeV

real(rp), parameter :: m_electron = 0.510998910d6        ! Mass [eV]
real(rp), parameter :: m_proton   = 0.938272046d9        ! Mass [eV]
real(rp), parameter :: m_muon     = 105.65836668d6       ! Mass [eV]

real(rp), parameter :: c_light = 2.99792458d8            ! speed of light
real(rp), parameter :: r_e = 2.8179402894d-15            ! classical electron radius
real(rp), parameter :: r_p = r_e * m_electron / m_proton ! proton radius
real(rp), parameter :: e_charge = 1.6021892d-19          ! electron charge [Coul]
real(rp), parameter :: h_planck = 4.13566733d-15         ! Planck's constant [eV*sec]
real(rp), parameter :: h_bar_planck = 6.58211899d-16     ! h_planck/twopi [eV*sec]

real(rp), parameter :: mu_0_vac = fourpi * 1d-7                     ! Permeability of free space
real(rp), parameter :: eps_0_vac = 1 / (c_light*c_light * mu_0_vac) ! Permittivity of free space

! Radiation constants

real(rp), parameter :: classical_radius_factor = 1.439964416d-9  ! e^2 / (4 pi eps_0) [m*eV]
                                                                 !  = classical_radius * mass * c^2. 
                                                                 ! Is same for all particles of charge +/- 1.
! Chemistry

real(rp), parameter :: N_avogadro = 6.02214129d23    ! Number / mole

! Anomalous magnetic moment

real(rp), parameter :: anomalous_mag_moment_electron = 0.001159652193
real(rp), parameter :: anomalous_mag_moment_proton   = 1.79285

complex(rp), parameter :: i_imaginary = (0.0d0, 1.0d0)
  
! real_garbage$ and int_garbage$ can be used, for example, to identify
! variable that have not been set.

integer, parameter :: int_garbage$ = -987654
real(rp), parameter :: real_garbage$ = -987654.3

! lf$ (the line feed or LF character) can be used to encode a multiline string.
! EG: string = 'First Line' // lf$ // 'Second Line'

character(1), parameter :: lf$ = achar(10)

! True and false

integer, parameter :: true$ = 1, false$ = 0

! This is to suppress the ranlib "has no symbols" message

integer, private :: private_dummy

end module
