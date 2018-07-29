module photon_init_mod

use bmad_interface

! An init_spectrum_struct holds an array of spline fits of E_rel of gamma_phi vs 
! integrated probability r over a certain range. Each spline section is fit to 
! one of two forms:
! 
! The gen_poly_spline$ type is of the form:
! [See the code how which form is chosen.]
!   fit_value = c0 + c1 * t + c2 * t^c3      
! or
!   fit_value = c0 + c1 * t + c2 * t^2 + c3 * t^3
!
! The end_spline$ type is of the form:
!   fit_value = c0 + c1 * t + c2 * t^2 / (1 - t/c3)
!
! where t is in the range [0, 1].
!   t = 0 at the start of the spline section.
!   t = 1 at the end of the spline section.

type photon_init_spline_pt_struct
  real(rp) c0, c1, c2, c3
end type

type photon_init_spline_struct
  real(rp) del_x    ! Spacing between spline points
  real(rp) x_min    ! Lower bound
  real(rp) x_max    ! Upper bound of Region of validity of this spline fit.
                    ! The lower bound is given by the upper bound of the previos struct.
  type (photon_init_spline_pt_struct), allocatable :: pt(:)
  integer spline_type
end type

type photon_init_spline2_struct
  real(rp) del_y    ! Spacing between spline arrayss
  real(rp) y_min    ! Lower bound
  real(rp) y_max    ! Upper bound
  type (photon_init_spline_struct), allocatable :: int_prob(:)
end type

integer, parameter :: gen_poly_spline$ = 1, end_spline$ = 2

private photon_init_spline_fit, photon_init_spline_coef_calc

contains

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine absolute_photon_position (e_orb, photon_orb)
! 
! Routine to calculate the photon phase space coordinates given:
!   1) The phase space coords of the emitting charged particle and
!   2) The photon phase space coords relative to the emitting particle.
!      The photon (x, y, z) position is ignored (it is assumed the photon is emitted at
!      the charged particle position) and only the photon's (vx, vy, vz) velocity matters.
!
! Input:
!   e_orb      -- coord_struct: charged particle position.
!   photon_orb -- coord_struct: Photon position relative to e_orb.
!
! Output:
!   photon_orb -- coord_struct: Absolute photon position.
!-

subroutine absolute_photon_position (e_orb, photon_orb)

implicit none

type (coord_struct) photon_orb, e_orb
real(rp) e_vec(3), w_mat(3,3), theta

! Remember: Phase space description for charged particle is different from photons.

photon_orb%vec(1) = e_orb%vec(1)
photon_orb%vec(3) = e_orb%vec(3)

e_vec(1:2) = e_orb%vec(2:4:2) / (e_orb%p0c * (1 + e_orb%vec(6)))
theta = asin(norm2(e_vec(1:2)))
if (theta == 0) return
call axis_angle_to_w_mat ([-e_vec(2), e_vec(1), 0.0_rp], theta, w_mat)
photon_orb%vec(2:6:2) = matmul(w_mat, photon_orb%vec(2:6:2))

end subroutine absolute_photon_position

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine bend_photon_init (g_bend_x, g_bend_y, gamma, orbit, E_min, E_max, E_integ_prob,
!                                         vert_angle_min, vert_angle_max, vert_angle_symmetric, emit_probability)
!
! Routine to initalize a photon for dipole bends and wigglers (but not undulators).
! The photon is initialized using the standard formulas for bending radiation.
!
! The energy of the photon is calculated in one of two ways:
!
!   1) If E_integ_prob is present and non-negative, the photon energy E will be such that the integrated 
!       probability  [E_min, E] relative to the integrated probability in the range [E_min, E_max] is E_integ_prob. 
!       That is, E_integ_prob can be used to to give a set of photon energies equally spaced in terms of the 
!       integrated probability distribution.
!
!   2) If E_integ_prob is not present, or is negative, the photon energy is chosen at random in 
!       the range [E_min, E_max].
!
! An E_integ_prob of zero means that the generated photon will have energy E_min.
! An E_integ_prob of one means that the generated photon will have energy E_max.
!
! The photon's polarization, will have unit amplitude.
!
! This routine assumes that the emitting charged particle is on-axis and moving in 
! the forward direction. To correct for the actual charged particle postion use the routine
!   absolute_photon_position
!
! Input:
!   g_bend_x             -- real(rp): Bending 1/rho component in horizontal plane.
!   g_bend_y             -- real(rp): Bending 1/rho component in vertical plane.
!   gamma                -- real(rp): Relativistic gamma factor of generating charged particle.
!   E_min                -- real(rp), optional: Minimum photon energy. Default is zero. Ignored if negative.
!   E_max                -- real(rp), optional: Maximum photon energy.  Default is Infinity. Ignored if negative.
!                            If non-positive then E_max will be taken to be Infinity.
!   E_integ_prob         -- real(rp):, optional :: integrated energy probability. See above.
!                            If E_integ_prob is non-negative, it must be in the range [0, 1].
!   vert_angle_min       -- real(rp), optional: Minimum vertical angle to emit a photon. 
!                           -pi/2 is used if argument not present or if argument is less than -pi/2.
!   vert_angle_max       -- real(rp), optional: Maximum vertical angle to emit a photon. 
!                           pi/2 is used if argument not present or if argument is greater than pi/2.
!   vert_angle_symmetric -- logical, optional: Default is False. If True, photons will be emitted
!                             in the range [-vert_angle_max, -vert_angle_min] as well as the range
!                             [vert_angle_min, vert_angle_max]. In this case vert_angle_min/max must be positive.
!   emit_probability     -- real(rp), optional: Probability of emitting a photon in the range [E_min, E_max] or 
!                             in the vertical angular range given. The probability is normalized so that the 
!                             probability of emitting if no ranges are given is 1.
!
! Output:
!   orbit            -- coord_struct: Initialized photon.
!-

subroutine bend_photon_init (g_bend_x, g_bend_y, gamma, orbit, E_min, E_max, E_integ_prob, &
                                         vert_angle_min, vert_angle_max, vert_angle_symmetric, emit_probability)


implicit none

type (coord_struct) orbit
real(rp), optional :: E_min, E_max, E_integ_prob, emit_probability, vert_angle_min, vert_angle_max
real(rp) g_bend_x, g_bend_y, g_bend, gamma, phi
real(rp) E_rel, E_photon, r_min, r_max, r, f, phi_min, phi_max
integer sgn
logical, optional :: vert_angle_symmetric

! Photon energy

g_bend = sqrt(g_bend_x**2 + g_bend_y**2)

r_min = 0
r_max = 1

if (real_option(0.0_rp, E_min) > 0) r_min = bend_photon_energy_integ_prob(E_min, g_bend, gamma)
if (real_option(0.0_rp, E_max) > 0) r_max = bend_photon_energy_integ_prob(E_max, g_bend, gamma)
if (present(emit_probability)) emit_probability = r_max - r_min

r = real_option(-1.0_rp, E_integ_prob)
if (r < 0) call ran_uniform(r)

r = r_min + r * (r_max - r_min)
E_rel = bend_photon_energy_init (r)

E_photon = E_rel * E_crit_photon(gamma, g_bend)

! Photon vertical angle

phi_min = real_option(-pi/2, vert_angle_min)
r_min = bend_vert_angle_integ_prob(phi_min, E_rel, gamma)

phi_max = real_option(pi/2, vert_angle_max)
r_max = bend_vert_angle_integ_prob(phi_max, E_rel, gamma)

call ran_uniform(r)
if (logic_option(.false., vert_angle_symmetric)) then
  f = 2
  if (r > 0.5_rp) then
    sgn = 1
    r = 2 * (r - 0.5_rp)
  else
    sgn = -1
    r = 2 * r
  endif
else
  f = 1
  sgn = 1
endif

r = r_min + r * (r_max - r_min)
phi = sgn * bend_photon_vert_angle_init (E_rel, gamma, r)

if (present(emit_probability)) emit_probability = emit_probability + f * (r_max - r_min)

orbit%vec = 0
orbit%vec(2) =  g_bend_y * sin(phi) / g_bend
orbit%vec(4) = -g_bend_x * sin(phi) / g_bend
orbit%vec(6) = cos(phi)

call init_coord (orbit, orbit%vec, particle = photon$, E_photon = E_photon)

! Polaraization

call bend_photon_polarization_init(g_bend_x, g_bend_y, E_rel, gamma*phi, orbit)

end subroutine bend_photon_init

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Function bend_photon_energy_integ_prob (E_photon, g_bend, gamma) result (integ_prob)
!
! Routine to find the integrated probability corresponding to emitting a photon
! from a bend in the range [0, E_photon].
!
! Input:
!   E_photon -- real(rp): Photon energy.
!   g_bend   -- real(rp): 1/rho bending strength.
!   gamma    -- Real(rp): Relativistic gamma factor of generating charged particle.
!
! Output:
!   integ_prob -- real(rp): Integrated probability. Will be in the range [0, 1].
!-

function bend_photon_energy_integ_prob (E_photon, g_bend, gamma) result (integ_prob)

use nr

implicit none

real(rp) E_photon, g_bend, gamma, integ_prob, E1, E_rel_target

! Easy cases. photon_energy_init gives a finite energy at integ_prob = 1 (in theory 
! should be infinity) so return 1.0 if E_photon > E (upper bound).

if (E_photon == 0) then
  integ_prob = 0
  return
endif

E_rel_target = E_photon / E_crit_photon(gamma, g_bend)

E1 = bend_photon_energy_init (1.0_rp)
if (E_rel_target >= E1) then
  integ_prob = 1
  return
endif

! bend_photon_energy_init calculates photon energy given the integrated probability
! so invert using the NR routine zbrent.

integ_prob = zbrent(energy_func, 0.0_rp, 1.0_rp, 1d-10)

!----------------------------------------------------------------------------------------
contains

function energy_func(integ_prob) result (dE)

real(rp), intent(in) :: integ_prob
real(rp) dE, E_rel

E_rel = bend_photon_energy_init(integ_prob)
dE = E_rel - E_rel_target

end function energy_func

end function bend_photon_energy_integ_prob

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Function bend_vert_angle_integ_prob (vert_angle, E_rel, gamma) result (integ_prob)
!
! Routine to find the integrated probability corresponding to emitting a photon
! from a bend and with relative energy E_rel in the vertical angle range [-pi/2, vert_angle/2].
!
! Note: vert_angle is allowed to be out of the range [-pi/2, pi/2]. In this case, integ_prob
! will be set to 0 or 1 as appropriate.
!
! Input:
!   vert_angle  -- real(rp): Vertical angle.
!   E_rel       -- real(rp): Relative photon energy E/E_crit. 
!   gamma       -- real(rp): Relativistic gamma factor of generating charged particle.
!
! Output:
!   integ_prob  -- real(rp): Integrated probability. Will be in the range [0, 1].
!-

function bend_vert_angle_integ_prob (vert_angle, E_rel, gamma) result (integ_prob)

use nr

implicit none

real(rp) vert_angle, E_rel, gamma, integ_prob

! Easy cases.

if (vert_angle <= -pi/2) then
  integ_prob = 0
  return
endif

if (vert_angle >= pi/2) then
  integ_prob = 1
  return
endif

! If angle is so large that bend_photon_vert_angle_init is inaccurate, just round off to 0 or 1.

if (bend_photon_vert_angle_init(E_rel, gamma, 0.0_rp) >= vert_angle) then
  integ_prob = 0
  return
endif

if (bend_photon_vert_angle_init(E_rel, gamma, 1.0_rp) <= vert_angle) then
  integ_prob = 1
  return
endif

! Invert using the NR routine zbrent.

integ_prob = zbrent(vert_angle_func, 0.0_rp, 1.0_rp, 1d-10)

!----------------------------------------------------------------------------------------
contains

function vert_angle_func(integ_prob) result (d_angle)

real(rp), intent(in) :: integ_prob
real(rp) angle, d_angle

angle = bend_photon_vert_angle_init(E_rel, gamma, integ_prob)
d_angle = angle - vert_angle

end function vert_angle_func

end function bend_vert_angle_integ_prob

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine bend_photon_polarization_init (g_bend_x, g_bend_y, E_rel, gamma_phi, orbit)
!
! Routine to set a photon's polarization.
! The photon's polarization will be either in the plane of the bend or out of the plane and
! the magnitude will be 1.
!
! Module needed:
!   use photon_init_mod
!
! Input:
!   g_bend_x  -- Real(rp): Bending 1/rho component in horizontal plane.
!   g_bend_y  -- Real(rp): Bending 1/rho component in vertical plane.
!   E_rel     -- Real(rp): Relative photon energy E/E_crit. 
!   gamma_phi -- Real(rp): gamma * phi where gamma is the beam relativistic factor and
!                  phi is the vertical photon angle (in radians).
! 
! Output:
!   orbit        -- coord_struct: Photon coords
!     %field(2)     -- (x,y) polaraization. Will have unit magnitude
!     %phase(2)     -- (x,y) phases. Will be [0, pi/2].
!-

subroutine bend_photon_polarization_init (g_bend_x, g_bend_y, E_rel, gamma_phi, orbit)

implicit none

type (coord_struct) :: orbit
real(rp) g_bend_x, g_bend_y, g_bend, gamma_phi
real(rp) gp2, xi, dum1, dum2, dum3, k_23, k_13, pol_x, pol_y
real(rp) E_rel, E_photon

!

g_bend = sqrt(g_bend_x**2 + g_bend_y**2)
gp2 = (gamma_phi)**2
xi = E_rel * sqrt(1+gp2)**3 / 2

call bessik(xi, 1.0_rp/3, dum1, k_13, dum2, dum3)
call bessik(xi, 2.0_rp/3, dum1, k_23, dum2, dum3)

pol_x = k_23
pol_y = k_13 * sqrt(gp2 / (1 + gp2))

orbit%field = [pol_x, sign(pol_y, gamma_phi)] / sqrt(pol_x**2 + pol_y**2)
orbit%phase = [0.0_rp, pi/2]

end subroutine bend_photon_polarization_init

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Function bend_photon_vert_angle_init (E_rel, gamma, r_in) result (phi)
!
! Routine to convert a "random" number in the interval [0,1] to a photon vertical emission 
! angle for a simple bend.
!
! Module needed:
!   use photon_init_mod
!
! Input:
!   E_rel -- real(rp): Relative photon energy E/E_crit. 
!		gamma -- real(rp): beam relativistic factor 
!   r_in  -- real(rp), optional: number in the range [0,1].
!             If not present, a random number will be used.
! 
! Output:
!   phi   -- real(rp): The vertical photon angle (in radians).
!                  Note: phi is an increasing monotonic function of r_in.
!-

function bend_photon_vert_angle_init (E_rel, gamma, r_in) result (phi)

implicit none

type (photon_init_spline2_struct), target, save :: p(2), dp(2)
type (photon_init_spline_struct), save :: spline

real(rp), optional :: r_in
real(rp) phi, e_rel, gamma, gamma_phi, p_perp, sig, log_E_rel, x0, xp0
real(rp) rr, r, ss, x, log_E, frac, rro, drr, log_E_min, log_E_max, del_log_E
real(rp) x1, xp1, v, vp

integer i, j, n, ip, ix, sign_phi
logical, save :: init_needed = .true.

! Init

if (init_needed) then

  p%y_min = [0.0, 0.90 ]
  p%y_max = [0.9, 0.99 ]
  p%del_y = [0.1, 0.01 ]

  dp%y_min = p%y_min
  dp%y_max = p%y_max
  dp%del_y = p%del_y

  allocate (spline%pt(0:1))

  do i = 1, size(p)

    allocate (p(i)%int_prob(0:9))
    allocate (dp(i)%int_prob(0:9))

    do j = 0, ubound(p(i)%int_prob, 1)

      allocate (p(i)%int_prob(j)%pt(0:5), dp(i)%int_prob(j)%pt(0:5))

      p(i)%int_prob(j)%spline_type  = gen_poly_spline$
      dp(i)%int_prob(j)%spline_type = gen_poly_spline$

      p(i)%int_prob(j)%x_min = -3   ! min log_E_rel of spline fit
      p(i)%int_prob(j)%x_max =  2   ! max log_E_rel of spline fit
      p(i)%int_prob(j)%del_x =  1   ! delta log_E_rel of spline fit

      dp(i)%int_prob(j)%x_min = -3
      dp(i)%int_prob(j)%x_max =  2
      dp(i)%int_prob(j)%del_x =  1

    enddo

  enddo

  p(1)%int_prob(0)%pt%c0 = 0
  p(1)%int_prob(1)%pt%c0 = [0.213077, 0.209797, 0.197551, 0.172532, 0.159164, 0.157629 ]
  p(1)%int_prob(2)%pt%c0 = [0.41684, 0.411585, 0.391252, 0.346399, 0.3208, 0.317791 ]
  p(1)%int_prob(3)%pt%c0 = [0.607859, 0.602204, 0.579339, 0.523204, 0.487668, 0.483317 ]
  p(1)%int_prob(4)%pt%c0 = [0.788241, 0.783377, 0.762758, 0.705161, 0.663198, 0.657732 ]
  p(1)%int_prob(5)%pt%c0 = [0.962935, 0.959643, 0.944795, 0.895588, 0.852122, 0.845915 ]
  p(1)%int_prob(6)%pt%c0 = [1.13857, 1.13739, 1.13097, 1.09987, 1.06173, 1.05541 ]
  p(1)%int_prob(7)%pt%c0 = [1.32443, 1.32584, 1.33026, 1.32768, 1.3048, 1.2995 ]
  p(1)%int_prob(8)%pt%c0 = [1.53718, 1.5418, 1.5601, 1.59954, 1.60838, 1.60643 ]
  p(1)%int_prob(9)%pt%c0 = [1.82222, 1.83133, 1.86944, 1.97602, 2.05286, 2.06088 ]

  p(1)%int_prob(0)%pt%c1 = 0
  p(1)%int_prob(1)%pt%c1 = [-0.00144017, -0.00616179, -0.0199551, -0.0239961, -0.00429677, -0.000326423 ]
  p(1)%int_prob(2)%pt%c1 = [-0.00228913, -0.00994776, -0.0340395, -0.0449884, -0.00840142, -0.000641762 ]
  p(1)%int_prob(3)%pt%c1 = [-0.002441, -0.010802, -0.039611, -0.0602353, -0.0120918, -0.000932808 ]
  p(1)%int_prob(4)%pt%c1 = [-0.00207945, -0.00937684, -0.0370852, -0.0673929, -0.0150743, -0.00118121 ]
  p(1)%int_prob(5)%pt%c1 = [-0.00139017, -0.00642462, -0.0280016, -0.0644311, -0.0169119, -0.00135801 ]
  p(1)%int_prob(6)%pt%c1 = [-0.000477501, -0.00239835, -0.013628, -0.0492536, -0.016872, -0.00141169 ]
  p(1)%int_prob(7)%pt%c1 = [0.000632962, 0.00258251,   0.00566825, -0.0188059, -0.013547, -0.00123701 ]
  p(1)%int_prob(8)%pt%c1 = [0.00200317,   0.00879492, 0.0310633, 0.0333115, -0.00364551, -0.000570791 ]
  p(1)%int_prob(9)%pt%c1 = [0.00391001, 0.0175067, 0.0680914, 0.12689, 0.023931, 0.00155287 ]


  p(2)%int_prob(0)%pt%c0 = [1.82222, 1.83133, 1.86944, 1.97602, 2.05286, 2.06088 ]
  p(2)%int_prob(1)%pt%c0 = [1.85968, 1.86938, 1.91015, 2.02619, 2.11413, 2.12405 ]
  p(2)%int_prob(2)%pt%c0 = [1.90013, 1.91048, 1.95413, 2.08052, 2.18098, 2.19314 ]
  p(2)%int_prob(3)%pt%c0 = [1.94432, 1.95538, 2.00218, 2.14002, 2.25481, 2.26962 ]
  p(2)%int_prob(4)%pt%c0 = [1.99333, 2.00516, 2.05547, 2.20616, 2.3376, 2.35564 ]
  p(2)%int_prob(5)%pt%c0 = [2.04878, 2.0615, 2.11577, 2.28118, 2.43241, 2.45448 ]
  p(2)%int_prob(6)%pt%c0 = [2.11333, 2.12709, 2.18599, 2.36873, 2.54422, 2.57151 ]
  p(2)%int_prob(7)%pt%c0 = [2.19184, 2.20684, 2.27137, 2.47544, 2.68217, 2.7166 ]
  p(2)%int_prob(8)%pt%c0 = [2.2948, 2.31143, 2.38333, 2.6157, 2.8661, 2.91133 ]
  p(2)%int_prob(9)%pt%c0 = [2.45393, 2.47307, 2.55635, 2.83301, 3.15652, 3.22186 ]

  p(2)%int_prob(0)%pt%c1 = [0.00391001, 0.0175067, 0.0680914, 0.12689, 0.023931, 0.00155287 ]
  p(2)%int_prob(1)%pt%c1 = [0.00416291, 0.0186658, 0.0731002, 0.140798, 0.0290337, 0.00197257 ]
  p(2)%int_prob(2)%pt%c1 = [0.00443623, 0.0199192, 0.0785332, 0.156168, 0.0349716, 0.00246967 ]
  p(2)%int_prob(3)%pt%c1 = [0.00473494, 0.0212899, 0.0844925, 0.173348, 0.0419805, 0.00306785 ]
  p(2)%int_prob(4)%pt%c1 = [0.00506619, 0.0228108, 0.0911251, 0.192841, 0.050408, 0.00380271 ]
  p(2)%int_prob(5)%pt%c1 = [0.00544082, 0.0245318, 0.0986538, 0.21541, 0.0607979, 0.00473099 ]
  p(2)%int_prob(6)%pt%c1 = [0.00587652, 0.0265346, 0.107443, 0.242307, 0.0740684, 0.00595081 ]
  p(2)%int_prob(7)%pt%c1 = [0.00640543, 0.0289673, 0.118154, 0.275817, 0.0919565, 0.00765291 ]
  p(2)%int_prob(8)%pt%c1 = [0.00709691, 0.0321499, 0.132216, 0.320901, 0.1184, 0.0102849 ]
  p(2)%int_prob(9)%pt%c1 = [0.00816008, 0.0370469, 0.153944, 0.392638, 0.166096, 0.0153642 ]

  dp(1)%int_prob(0)%pt%c0 = [2.1491, 2.11355, 1.98278, 1.72319, 1.58761, 1.57217 ]
  dp(1)%int_prob(1)%pt%c0 = [2.09573, 2.06807, 1.96143, 1.72964, 1.59974, 1.58459 ]
  dp(1)%int_prob(2)%pt%c0 = [1.97406, 1.96255, 1.90957, 1.75031, 1.63752, 1.6233 ]
  dp(1)%int_prob(3)%pt%c0 = [1.85037, 1.85313, 1.85384, 1.78942, 1.70547, 1.69299 ]
  dp(1)%int_prob(4)%pt%c0 = [1.7657, 1.77807, 1.82005, 1.8551, 1.81284, 1.80325 ]
  dp(1)%int_prob(5)%pt%c0 = [1.73909, 1.75775, 1.82971, 1.9621, 1.97737, 1.97254 ]
  dp(1)%int_prob(6)%pt%c0 = [1.7884, 1.81187, 1.90804, 2.13883, 2.23489, 2.23823 ]
  dp(1)%int_prob(7)%pt%c0 = [1.95429, 1.98284, 2.10435, 2.44847, 2.66746, 2.68623 ]
  dp(1)%int_prob(8)%pt%c0 = [2.36249, 2.39907, 2.55887, 3.07053, 3.51229, 3.56615 ]
  dp(1)%int_prob(9)%pt%c0 = [3.61504, 3.67255, 3.92872, 4.83658, 5.88372, 6.05988 ]

  dp(1)%int_prob(0)%pt%c1 = [-0.0156567, -0.0665479, -0.210823, -0.245065, -0.0432786, -0.00328204 ]
  dp(1)%int_prob(1)%pt%c1 = [-0.0120549, -0.0523352, -0.177843, -0.229804, -0.0423414, -0.00322828 ]
  dp(1)%int_prob(2)%pt%c1 = [-0.00480825, -0.0226506, -0.0995454, -0.185447, -0.0393877, -0.00305697 ]
  dp(1)%int_prob(3)%pt%c1 = [0.00141279, 0.00427155, -0.0129626, -0.115597, -0.0339413, -0.00273419 ]
  dp(1)%int_prob(4)%pt%c1 = [0.00549944, 0.0229272, 0.0606838, -0.024231, -0.0250039, -0.00218733 ]
  dp(1)%int_prob(5)%pt%c1 = [0.00811466, 0.0353651, 0.118791, 0.0868289, -0.0105808, -0.00126711 ]
  dp(1)%int_prob(6)%pt%c1 = [0.010096, 0.0449573, 0.167992, 0.22149, 0.0135693, 0.000355742 ]
  dp(1)%int_prob(7)%pt%c1 = [0.0122038, 0.0550616, 0.219601, 0.397048, 0.0578117, 0.0035227 ]
  dp(1)%int_prob(8)%pt%c1 = [0.0155698, 0.0708746, 0.295621, 0.671762, 0.154618, 0.0110212 ]
  dp(1)%int_prob(9)%pt%c1 = [0.0243979, 0.11179, 0.482324, 1.32675, 0.474496, 0.0386947 ]

  dp(2)%int_prob(0)%pt%c0 = [3.61504, 3.67255, 3.92872, 4.83658, 5.88372, 6.05988 ]
  dp(2)%int_prob(1)%pt%c0 = [3.88478, 3.94666, 4.22274, 5.21077, 6.3868, 6.59219 ]
  dp(2)%int_prob(2)%pt%c0 = [4.21748, 4.2847, 4.58521, 5.67121, 7.00664, 7.24929 ]
  dp(2)%int_prob(3)%pt%c0 = [4.6385, 4.71247, 5.04371, 6.25269, 7.79078, 8.08234 ]
  dp(2)%int_prob(4)%pt%c0 = [5.18941, 5.27217, 5.64343, 7.01222, 8.81726, 9.17548 ]
  dp(2)%int_prob(5)%pt%c0 = [5.94354, 6.03829, 6.46406, 8.05031, 10.2241, 10.6779 ]
  dp(2)%int_prob(6)%pt%c0 = [7.04412, 7.1563, 7.6613, 9.56334, 12.2819, 12.883 ]
  dp(2)%int_prob(7)%pt%c0 = [8.81611, 8.95623, 9.58825, 11.9967, 15.6067, 16.4608 ]
  dp(2)%int_prob(8)%pt%c0 = [12.1997, 12.3929, 13.2664, 16.6389, 21.9895, 23.3684 ]
  dp(2)%int_prob(9)%pt%c0 = [21.6485, 21.9891, 23.5329, 29.5915, 39.9738, 43.0058 ]

  dp(2)%int_prob(0)%pt%c1 = [0.0243979, 0.11179, 0.482324, 1.32675, 0.474496, 0.0386947 ]
  dp(2)%int_prob(1)%pt%c1 = [0.0262411, 0.120306, 0.520659, 1.45904, 0.548779, 0.0455162 ]
  dp(2)%int_prob(2)%pt%c1 = [0.0285039, 0.130756, 0.567609, 1.62067, 0.642666, 0.0542909 ]
  dp(2)%int_prob(3)%pt%c1 = [0.0313552, 0.143918, 0.626653, 1.82358, 0.764771, 0.0659247 ]
  dp(2)%int_prob(4)%pt%c1 = [0.0350713, 0.161068, 0.703478, 2.08733, 0.929534, 0.0819626 ]
  dp(2)%int_prob(5)%pt%c1 = [0.0401387, 0.184448, 0.808106, 2.44651, 1.16311, 0.105256 ]
  dp(2)%int_prob(6)%pt%c1 = [0.0475064, 0.218436, 0.960088, 2.96879, 1.51815, 0.141676 ]
  dp(2)%int_prob(7)%pt%c1 = [0.059322, 0.272936, 1.2037, 3.80805, 2.11831, 0.205381 ]
  dp(2)%int_prob(8)%pt%c1 = [0.0817827, 0.376533, 1.66676, 5.4108, 3.33731, 0.340647 ]
  dp(2)%int_prob(9)%pt%c1 = [0.144122, 0.664085, 2.95279, 9.90065, 7.05788, 0.782273 ]

  do i = 1, 2
    do j = 0, ubound(p(i)%int_prob, 1)
      call photon_init_spline_coef_calc (p(i)%int_prob(j))
      call photon_init_spline_coef_calc (dp(i)%int_prob(j))
    enddo
  enddo

  init_needed = .false.
endif

!----------------------------------------------------
! Integrated probability number to use.

if (present(r_in)) then
  rr = r_in
else
  call ran_uniform(rr)
endif

! The spline fit is only for positive phi.
! So make phi negative if rr < 0.5

if (rr > 0.5) then
  rr = 2 * rr - 1
  sign_phi = 1
else
  rr = 1 - 2 * rr
  sign_phi = -1
endif

! gamma_phi is a function of E_rel and rr.
! gamma_phi is calculated by first finding the spline coefficients for the given E_rel

log_E_rel = log10(max(E_rel, 1e-3_rp))

! In the range above rr = 0.99 we use an extrapolation that matches gamma_phi and
! it's first two derivatives at rr = 0.99.

if (rr >= p(2)%y_max) then

  spline%x_min = p(2)%y_max
  spline%x_max = 1.00000001
  spline%del_x = 1 - p(2)%y_max
  spline%spline_type = end_spline$

  n = ubound(p(2)%int_prob, 1)
  x1  = photon_init_spline_fit (p(2)%int_prob(n), log_E_rel)
  xp1 = photon_init_spline_fit (dp(2)%int_prob(n), log_E_rel) * spline%del_x

  x0  = photon_init_spline_fit (p(2)%int_prob(n-1), log_E_rel)
  xp0 = photon_init_spline_fit (dp(2)%int_prob(n-1), log_E_rel) * spline%del_x

  v = x1 - x0 - xp0
  vp = xp1 - xp0

  spline%pt(0)%c0 = x1
  spline%pt(0)%c1 = xp1 
  spline%pt(0)%c2 = max(vp/2, 2*vp - 3*v) 
  spline%pt(0)%c3 = 1.1

  gamma_phi = photon_init_spline_fit (spline, rr)

else
  
  do ip = 1, 2
    if (rr > p(ip)%y_max) cycle
    r = (rr - p(ip)%y_min) / p(ip)%del_y
    i = int (r)

    spline%pt(0)%c0 = photon_init_spline_fit (p(ip)%int_prob(i),  log_E_rel)
    spline%pt(0)%c1 = photon_init_spline_fit (dp(ip)%int_prob(i), log_E_rel)

    if (i == ubound(p(ip)%int_prob, 1)) then  ! Can happen due to roundoff errors.
      gamma_phi = spline%pt(0)%c0
      exit            ! This prevents an array out-of-bounds problem
    endif

    spline%pt(1)%c0 = photon_init_spline_fit (p(ip)%int_prob(i+1),  log_E_rel)
    spline%pt(1)%c1 = photon_init_spline_fit (dp(ip)%int_prob(i+1), log_E_rel)

    spline%x_min = i * p(ip)%del_y + p(ip)%y_min
    spline%x_max = spline%x_min + p(ip)%del_y 
    spline%del_x = p(ip)%del_y
    spline%spline_type = gen_poly_spline$

    call photon_init_spline_coef_calc (spline)
    gamma_phi = photon_init_spline_fit (spline, rr)
    exit

  enddo

endif

! Scale result by the sigma of the spectrum at fixed E_rel

if (E_rel < 0.1) then
  sig = 0.597803 * max(E_rel, 1e-6_rp)**(-0.336351)
else
  sig = 0.451268 * E_rel**(-0.469377)
endif

phi = gamma_phi * sig * sign_phi / gamma
if (phi > pi/2) phi = pi/2
if (phi < -pi/2) phi = -phi/2

end function bend_photon_vert_angle_init

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Function bend_photon_energy_init (r_in) result (E_rel)
!
! Routine to convert a random number in the interval [0,1] to a photon energy.
! The photon probability spectrum is:
!   P(E_rel) = 0.19098593171 * Integral_{E_rel}^{Infty} K_{5/3}(x) dx
! Where
!   P(E_rel)) = Probability of finding a photon at relative energy E_rel.
!   E_rel     = Relative photon energy: E / E_crit, E_crit = Critical energy.
!   K_{5/3}   = Modified Bessel function.
!
! Notice that the P(E) is not the same as the distribution radiation energy since
! the photons must be energy weighted.
!
! There is a cut-off built into the calculation so that E_rel will be in the 
! range [0, ~17]. The error in neglecting photons with E_rel > ~17 is very small. 
! If r_in is present: 
!   r_in = 0 => E_rel = 0 
!   r_in = 1 => E_rel = ~30
!
! Module needed:
!   use photon_init_mod
!
! Input:
!   r_in  -- Real(rp), optional: Integrated probability in the range [0,1].
!             If not present, a random number will be used.
!
! Output:
!   E_rel -- Real(rp): Relative photon energy E/E_crit. 
!-

function bend_photon_energy_init (r_in) result (E_rel)

implicit none

! Four spline fit arrays are used. 
! Each fit array has a different del_x and range of validity.

type (photon_init_spline_struct), save :: spline(7) 

real(rp) E_rel
real(rp), optional :: r_in
real(rp) rr, rr1

integer is

logical, save :: init_needed = .true.
character(*), parameter :: r_name = 'bend_photon_energy_init'

! Check for r_in

if (present(r_in)) then
  rr = r_in
  if (rr < 0  .or. rr > 1) then
    call out_io (s_fatal$, r_name, 'R_IN IS OUT OF RANGE: \es12.4\ ', rr)
    stop
  endif
else
  call ran_uniform(rr)
endif

! Init. 
! The values for c0 and c1 were obtained from a Mathematica calculation See:
!   bmad/calculations/bend_radiation_distribution_spline.nb

if (init_needed) then

  spline(:)%del_x = [0.02_rp, 0.01_rp, 0.001_rp, 0.0001_rp, 0.00001_rp, 0.000001_rp, 0.000001_rp]
  spline(:)%x_min = [0.0_rp,  0.80_rp, 0.990_rp, 0.9990_rp, 0.99990_rp, 0.999990_rp, 0.999990_rp]
  spline(:)%x_max = [0.8_rp,  0.99_rp, 0.999_rp, 0.9999_rp, 0.99999_rp, 0.999999_rp, 0.999999_rp]
  spline(:)%spline_type = gen_poly_spline$

  allocate (spline(1)%pt(0:40), spline(2)%pt(0:19), spline(3)%pt(0:9), spline(4)%pt(0:9))
  allocate (spline(5)%pt(0:9), spline(6)%pt(0:9), spline(7)%pt(0:9))

  spline(1)%pt(:)%c0 = [0.0, 4.2834064e-6, 0.000034290156, 0.00011585842, 0.00027505747, &
              0.00053830686, 0.00093250004, 0.0014851341, 0.0022244473, 0.0031795668, 0.0043806678, &
              0.005859148, 0.0076478195, 0.0097811211, 0.012295356, 0.015228961, 0.018622804, &
              0.022520536, 0.026968982, 0.032018597, 0.037723996, 0.044144571, 0.051345214, &
              0.059397173, 0.06837907, 0.078378116, 0.08949158, 0.10182857, 0.11551222, &
              0.13068237, 0.14749895, 0.1661462, 0.18683808, 0.20982519, 0.23540392, &
              0.26392847, 0.29582721, 0.33162503, 0.37197493, 0.41770346, 0.46987814]

  spline(1)%pt(:)%c1 = [0.0, 0.00064260631, 0.00257329, 0.0058006813, 0.010339284, &
              0.016209659, 0.023438687, 0.032059915, 0.042114002, 0.05364926, 0.066722326, &
              0.081398955, 0.097754987, 0.11587748, 0.13586608, 0.15783464, 0.18191312, &
              0.20824993, 0.23701467, 0.26840143, 0.30263281, 0.33996474, 0.38069245, &
              0.42515766, 0.4737576, 0.52695612, 0.58529771, 0.64942516, 0.72010211, &
              0.79824218, 0.88494687, 0.98155565, 1.0897128, 1.2114583, 1.3493529, &
              1.5066541, 1.687568, 1.8976188, 2.1442047, 2.4374605, 2.7916424]

  spline(2)%pt(:)%c0 = [0.46987814, 0.49880667, 0.52991104, 0.56344857, 0.59972426, 0.63910329, &
              0.68202787, 0.72904042, 0.78081609, 0.83820971, 0.90232524, 0.97462245, 1.0570871, &
              1.1525166, 1.2650292, 1.401046, 1.5713927, 1.7965129, 2.1227067, 2.6994536]

  spline(2)%pt(:)%c1 = [2.7916424, 2.9977025, 3.2274448, 3.485124, 3.7760729, 4.1070657, &
              4.4868378, 4.9268475, 5.4424214, 6.0545297, 6.7926343, 7.6994506, 8.8393066, &
              10.313721, 12.292676, 15.083696, 19.305339, 26.41041, 40.792302, 84.662418]

  spline(3)%pt(:)%c0 = [2.6994536, 2.7888604, 2.8892809, 3.0037015, 3.1365059, &
              3.2945089, 3.4891605, 3.7420006, 4.1015906, 4.7237837]

  spline(3)%pt(:)%c1 = [84.662418, 94.500558, 106.82986, 122.72601, 143.98575, &
              173.85088, 218.82271, 294.11918, 445.57461, 903.65004]

  spline(4)%pt(:)%c0 = [4.7237837, 4.8190811, 4.9258192, 5.0470809, &
              5.1873871, 5.3537566, 5.5579673, 5.8221404, 6.1960561, 6.8390833]

  spline(4)%pt(:)%c1 = [903.65004, 1005.9104, 1133.9035, 1298.7019, 1518.7818, &
              1827.444, 2291.3909, 3066.5401, 4621.6998, 9308.5914]

  spline(5)%pt(:)%c0 = [6.8390833, 6.9372066, 7.0470098, 7.1716317, 7.3156733, &
              7.4862732, 7.6954033, 7.9655326, 8.3471796, 9.001882]

  spline(5)%pt(:)%c1 = [9308.5914, 10352.865, 11659.208, 13340.208, 15583.647, &
              18727.809, 23449.897, 31331.837, 47126.191, 94645.923]

  spline(6)%pt(:)%c0 = [9.001882, 9.1016308, 9.2132088, 9.3397903, 9.486028, &
              9.6591381, 9.8712192, 10.144967, 10.531391, 11.193479]

  spline(6)%pt(:)%c1 = [94645.923, 105223.63, 118452.33, 135469.88, 158173.89, &
              189981.63, 237732.48, 317396.37, 476931.1, 956469.26]

  spline(7)%pt(:)%c0 = [11.193479, 11.294278, 11.407001, 11.534857, 11.682527, &
              11.857289, 12.07133, 12.347659, 12.737582, 13.403243]

  spline(7)%pt(:)%c1 = [956469.26, 1.0631543E6, 1.1965692E6, 1.3681661E6, 1.5970427E6, &
              1.9176469E6, 2.3987897E6, 3.2018487E6, 4.8099726E6, 9.6282849E6]

  ! Fill in rest of the spline fit coefs.

  do is = 1, ubound(spline, 1)
    call photon_init_spline_coef_calc (spline(is))
  enddo

  init_needed = .false.
endif

! Spline fit

do is = 1, ubound(spline, 1)
  if (rr > spline(is)%x_max) cycle
  E_rel = photon_init_spline_fit (spline(is), rr)
  return
enddo

! In the range above rr = 0.999999 use the approximation that P(x) ~ e^-x / Sqrt[x]

rr1 = 1 - rr
if (rr1 < 1d-14) then
  E_rel = 31.4_rp
  return
endif

E_rel = inverse(p_func, rr1, 13.4_rp, 31.4_rp, 1e-10_rp) 

!---------------------------------------------------------------------------
contains

function p_func(x) result(rr1)
real(rp) :: x, rr1, alpha = 2.42414961421056
rr1 = alpha * exp(-x) / Sqrt(x)
end function p_func

end function bend_photon_energy_init

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine photon_init_spline_coef_calc (spline)
!
!-

subroutine photon_init_spline_coef_calc (spline)

implicit none

type (photon_init_spline_struct) spline
integer i, ns
real(rp) v, vp

!

select case (spline%spline_type)

case (gen_poly_spline$)
  spline%pt(:)%c1 = spline%pt(:)%c1 * spline%del_x
  ns = ubound(spline%pt, 1) 

  do i = 0, ns-1
    v  = spline%pt(i+1)%c0 - spline%pt(i)%c0 - spline%pt(i)%c1
    vp = spline%pt(i+1)%c1 - spline%pt(i)%c1
    if (v * vp > 0 .and. abs(vp) > abs(3 * v)) then   ! c0 + c1 x + c2 * x^c3 spline
      spline%pt(i)%c2 = v
      spline%pt(i)%c3 = vp / v
    else    ! Cubic spline
      spline%pt(i)%c2 = 3 * v - vp 
      spline%pt(i)%c3 = vp - 2 * v
    endif
  enddo

  spline%pt(ns)%c2 = 0  ! Need to set this due to roundoff errors
  spline%pt(ns)%c3 = 0  ! Need to set this due to roundoff errors

end select

end subroutine photon_init_spline_coef_calc

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Function photon_init_spline_fit (spline, rr) result (fit_val)
!
! Function to evaluate a spline fit at rr.
! 
! Module needed:
!   use photon_init_mod
!
! Input:
!   spline    -- photon_init_spline_struct: spline section.
!   rr        -- real(rp): Value to evaluate the fit at.
!
! Output:
!   fit_val -- real(rp): Spline fit evaluated at rr  .
!               Note: if rr is out of range, fit_val will be 
!               set to the value at the edge of the spline range.
!-

function photon_init_spline_fit (spline, rr) result (fit_val)

implicit none

type (photon_init_spline_struct) spline
real(rp) rr, r_rel, x, fit_val, v, vp
integer i, ix, np

! Find in which spline section rr is in

r_rel = (rr - spline%x_min) / spline%del_x
i = int(r_rel)   ! Index of which spline section to use.
x = r_rel - i    ! Notice that x will be in the range [0, 1].

! If out of range then adjust point to be at the edge of the range

if (i < 0) then
  i = 0
  x = 0
endif

np = ubound(spline%pt, 1)
if (i > np - 1) then 
  i = np - 1
  x = 1
endif

select case (spline%spline_type)

case (gen_poly_spline$)

  if (i == ubound(spline%pt, 1)) then
    fit_val = spline%pt(i)%c0
    return
  endif

  v  = spline%pt(i+1)%c0 - spline%pt(i)%c0 - spline%pt(i)%c1
  vp = spline%pt(i+1)%c1 - spline%pt(i)%c1

  if (v * vp > 0 .and. abs(vp) > abs(3 * v)) then   ! c0 + c1 x + c2 * x^c3 spline
    fit_val = spline%pt(i)%c0 + spline%pt(i)%c1 * x + spline%pt(i)%c2 * x**spline%pt(i)%c3
  else    ! Cubic spline
    fit_val = spline%pt(i)%c0 + spline%pt(i)%c1 * x + spline%pt(i)%c2 * x**2 + spline%pt(i)%c3 * x**3
  endif

case (end_spline$)

  fit_val = spline%pt(i)%c0 + spline%pt(i)%c1 * x + spline%pt(i)%c2 * x**2 / (1 - x/spline%pt(i)%c3)

! Coding error if here.

case default
  if (global_com%exit_on_error) call err_exit

end select

end function photon_init_spline_fit

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Function E_crit_photon (gamma, g_bend) result (E_crit)
!
! Routine to calculate the photon critical energy in a bend.
!
! Input:
!   gamma   -- real(rp): Gamma factor of charged particle emitting photon.
!   g_bend  -- real(rp): 1/radius bending strength.
!
! Output:
!   E_crit  -- real(rp): Critical photon energy.
!-

function E_crit_photon (gamma, g_bend) result (E_crit)

real(rp) gamma, g_bend, E_crit
real(rp), parameter :: e_factor = 3.0_rp * h_bar_planck * c_light / 2.0_rp

!

E_crit = e_factor * gamma**3 * g_bend

end function E_crit_photon

end module
