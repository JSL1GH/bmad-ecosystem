!+
! Module rad_int_common
!
! Module needed:
!   use rad_int_common
!-

#include "CESR_platform.inc"

module rad_int_common               

  use ptc_interface_mod
  use runge_kutta_mod

! The "cache" is for saving values for g, etc through a wiggler to speed
! up the calculation

  type g_cache_struct
    real(rp) g
    real(rp) g2
    real(rp) g_x, g_y
    real(rp) dg2_x, dg2_y
  end type

  type ele_cache_struct
    type (g_cache_struct), allocatable :: v(:)
    real(rp) ds
    integer ix_ele
  end type

  type rad_int_cache_struct
    type (ele_cache_struct), allocatable :: ele(:)
    logical :: set = .false.
  end type

! This structure stores the radiation integrals for the individual elements

  type rad_int_common_struct
    real(rp) g_x0, g_y0, k1, s1
    real(rp) eta_a(4), eta_b(4), eta_a0(4), eta_a1(4), eta_b0(4), eta_b1(4)
    real(rp) g, g2, g_x, g_y, dg2_x, dg2_y 
    real(rp), allocatable :: i1_(:) 
    real(rp), allocatable :: i2_(:) 
    real(rp), allocatable :: i3_(:) 
    real(rp), allocatable :: i4a_(:)
    real(rp), allocatable :: i4b_(:)
    real(rp), allocatable :: i5a_(:) 
    real(rp), allocatable :: i5b_(:) 
    real(rp), allocatable :: n_steps(:)      ! number of qromb steps needed
    real(rp) :: int_tot(7)
    type (ring_struct), pointer :: ring
    type (ele_struct), pointer :: ele0, ele
    type (ele_struct) runt
    type (coord_struct), pointer :: orb0, orb1
    type (runge_kutta_com_struct) :: rk_track(0:6)
    type (coord_struct) d_orb
    type (rad_int_cache_struct) cache(10)
    type (ele_cache_struct), pointer :: cache_ele
    logical use_cache
  end type

  type (rad_int_common_struct), target, save :: ric

contains

!---------------------------------------------------------------------
!---------------------------------------------------------------------
!---------------------------------------------------------------------
!+
! Subroutine qromb_rad_int(do_int, ir)
!
! Function to do integration using Romberg's method on the 7 radiation 
! integrals.
! This is a modified version of QROMB from Num. Rec.
! See the Num. Rec. book for further details
!-

subroutine qromb_rad_int (do_int, ir)

  use precision_def
  use nrtype
  use nr, only: polint

  implicit none

  integer, parameter :: jmax = 14
  integer j, j0, n, n_pts, ir

  real(rp) :: eps_int, eps_sum
  real(rp) :: ll, ds, s0, s_pos, dint, d0, d_max
  real(rp) i_sum(7), rad_int(7), int_tot(7)

  logical do_int(7), complete

  type ri_struct
    real(rp) h(0:jmax)
    real(rp) sum(0:jmax)
  end type

  type (ri_struct) ri(7)

!

  eps_int = 1e-4
  eps_sum = 1e-6

  ri(:)%h(0) = 4.0
  ri(:)%sum(0) = 0
  rad_int = 0
  
  ll = ric%ele%value(l$)

  ric%runt = ric%ele

! loop until integrals converge

  do j = 1, jmax

    ri(:)%h(j) = ri(:)%h(j-1) / 4

! This is trapzd from Num. Rec.

    if (j == 1) then
      n_pts = 2
      ds = ll
      s0 = 0
    else
      n_pts = 2**(j-2)
      ds = ll / n_pts
      s0 = ds / 2
    endif

    i_sum = 0

    do n = 1, n_pts
      s_pos = s0 + (n-1) * ds
      call propagate_part_way (s_pos)
      i_sum(1) = i_sum(1) + ric%g_x * (ric%eta_a(1) + ric%eta_b(1)) + &
                            ric%g_y * (ric%eta_a(3) + ric%eta_b(3))
      i_sum(2) = i_sum(2) + ric%g2
      i_sum(3) = i_sum(3) + ric%g2 * ric%g
      i_sum(4) = i_sum(4) + &
                ric%g2 * (ric%g_x * ric%eta_a(1) + ric%g_y * ric%eta_a(3)) + &
                         (ric%dg2_x * ric%eta_a(1) + ric%dg2_y * ric%eta_a(3)) 
      i_sum(5) = i_sum(5) + &
                ric%g2 * (ric%g_x * ric%eta_b(1) + ric%g_y * ric%eta_b(3)) + &
                         (ric%dg2_x * ric%eta_b(1) + ric%dg2_y * ric%eta_b(3))
      i_sum(6) = i_sum(6) + &
                    ric%g2 * ric%g * (ric%runt%x%gamma * ric%runt%x%eta**2 + &
                    2 * ric%runt%x%alpha * ric%runt%x%eta * ric%runt%x%etap + &
                    ric%runt%x%beta * ric%runt%x%etap**2)
      i_sum(7) = i_sum(7) + &
                    ric%g2 * ric%g * (ric%runt%y%gamma * ric%runt%y%eta**2 + &
                    2 * ric%runt%y%alpha * ric%runt%y%eta * ric%runt%y%etap + &
                    ric%runt%y%beta * ric%runt%y%etap**2)
    enddo

    ri(:)%sum(j) = (ri(:)%sum(j-1) + ds * i_sum(:)) / 2

! back to qromb

    if (j < 3) cycle
    if (ric%ele%key == wiggler$ .and. j < 4) cycle

    j0 = max(j-4, 1)

    complete = .true.
    d_max = 0

    do n = 1, 7
      if (.not. do_int(n)) cycle
      call polint (ri(n)%h(j0:j), ri(n)%sum(j0:j), 0.0_rp, rad_int(n), dint)
      d0 = eps_int * abs(rad_int(n)) + eps_sum * abs(ric%int_tot(n))
      if (abs(dint) > d0)  complete = .false.
      if (d0 /= 0) d_max = abs(dint) / d0
    enddo

    if (complete .or. j == jmax) then

      ric%n_steps(ir) = j

      ric%i1_(ir)  = ric%i1_(ir)  + rad_int(1)
      ric%i2_(ir)  = ric%i2_(ir)  + rad_int(2)
      ric%i3_(ir)  = ric%i3_(ir)  + rad_int(3)
      ric%i4a_(ir) = ric%i4a_(ir) + rad_int(4)
      ric%i4b_(ir) = ric%i4b_(ir) + rad_int(5)
      ric%i5a_(ir) = ric%i5a_(ir) + rad_int(6)
      ric%i5b_(ir) = ric%i5b_(ir) + rad_int(7)

      ric%int_tot(1) = ric%int_tot(1) + ric%i1_(ir)
      ric%int_tot(2) = ric%int_tot(2) + ric%i2_(ir)
      ric%int_tot(3) = ric%int_tot(3) + ric%i3_(ir)
      ric%int_tot(4) = ric%int_tot(4) + ric%i4a_(ir)
      ric%int_tot(5) = ric%int_tot(5) + ric%i4b_(ir)
      ric%int_tot(6) = ric%int_tot(6) + ric%i5a_(ir)
      ric%int_tot(7) = ric%int_tot(7) + ric%i5b_(ir)

    endif

    if (complete) return

  end do

! should not be here

  print *, 'QROMB_RAD_INT: Note: Radiation Integral is not converging', d_max
  print *, '     For element: ', ric%ele%name

end subroutine

!---------------------------------------------------------------------
!---------------------------------------------------------------------
!---------------------------------------------------------------------

subroutine transfer_rk_track (rk1, rk2)

  implicit none

  type (runge_kutta_com_struct) rk1, rk2

  integer n

!

  n = size(rk1%s)

  if (associated(rk2%s)) then
    if (size(rk2%s) < n) then
      deallocate (rk2%s, rk2%orb)
      allocate (rk2%s(n), rk2%orb(n))
    endif
  else
    allocate (rk2%s(n), rk2%orb(n))    
  endif

  n = rk1%n_pts

  rk2%n_pts    = rk1%n_pts
  rk2%s(1:n)   = rk1%s(1:n)
  rk2%orb(1:n) = rk1%orb(1:n)

end subroutine

!---------------------------------------------------------------------
!---------------------------------------------------------------------
!---------------------------------------------------------------------
!+
! Subroutine bracket_index (s_, s, ix)
!
! Subroutine to find the index ix so that s_(ix) <= s < s_(ix+1).
! If s <  s_(1) then ix = 0
! If s >= s_(n) then ix = n  [where n = size(s_)]
!
! This routine assumes that s_ is in assending order.
!
! Input:
!   s_(:) -- Real(rp): Sequence of real numbers.
!   s     -- Real(rp): Number to bracket.
!
! Output:
!   ix    -- Integer: Index so that s_(ix) <= s < s_(ix+1).
!-

subroutine bracket_index (s_, s, ix)

  implicit none

  real(rp) s_(:), s

  integer i, ix, n, n1, n2, n3

!

  n = size(s_)

  if (s < s_(1)) then
    ix = 0
    return
  endif

  if (s >= s_(n)) then
    ix = n
    return
  endif

!

  n1 = 1
  n3 = n

  do

    if (n3 == n1 + 1) then
      ix = n1
      return
    endif

    n2 = (n1 + n3) / 2

    if (s < s_(n2)) then
      n3 = n2
    else
      n1 = n2
    endif

  enddo

end subroutine

!---------------------------------------------------------------------
!---------------------------------------------------------------------
!---------------------------------------------------------------------

subroutine propagate_part_way (s)

  implicit none

  type (coord_struct) orb, orb_0

  real(rp) s, v(4,4), v_inv(4,4), s1, s2, error, f0, f1

  integer i, ix, n_pts

! exact calc

  if (ric%ele%exact_rad_int_calc) then

    do i = 0, 6
      n_pts = ric%rk_track(i)%n_pts
      call bracket_index (ric%rk_track(i)%s(1:n_pts), s, ix)

      if (ix == n_pts) then
        orb = ric%rk_track(i)%orb(n_pts)
      else
        s1 = s - ric%rk_track(i)%s(ix)
        s2 = ric%rk_track(i)%s(ix+1) - s
        orb%vec = (s2 * ric%rk_track(i)%orb(ix)%vec + &
                s1 * ric%rk_track(i)%orb(ix+1)%vec) / (s1 + s2)
      endif

      if (i == 0) then
        orb_0 = orb
        call calc_g_params (s, orb)
      else
        ric%runt%mat6(1:6, i) = (orb%vec - orb_0%vec) / ric%d_orb%vec(i)
      endif
    enddo

    call mat_symp_check (ric%runt%mat6, error)
    call mat_symplectify (ric%runt%mat6, ric%runt%mat6)

    call twiss_propagate1 (ric%ele0, ric%runt)

    call make_v_mats (ric%runt, v, v_inv)

    ric%eta_a = &
          matmul(v, (/ ric%runt%x%eta, ric%runt%x%etap, 0.0_rp, 0.0_rp /))
    ric%eta_b = &
          matmul(v, (/ 0.0_rp, 0.0_rp, ric%runt%y%eta, ric%runt%y%etap /))

    return
  endif

! non-exact wiggler calc

  if (ric%ele%key == wiggler$ .and. ric%ele%sub_key == map_type$) then

    f0 = (ric%ele%value(l$) - s) / ric%ele%value(l$)
    f1 = s / ric%ele%value(l$)

    orb%vec = ric%orb0%vec * f0 + ric%orb1%vec * f1
    call calc_g_params (s, orb)

    ric%eta_a = ric%eta_a0 * f0 + ric%eta_a1 * f1
    ric%eta_b = ric%eta_b0 * f0 + ric%eta_b1 * f1

    ric%runt%x%beta  = ric%ele0%x%beta  * f0 + ric%ele%x%beta  * f1
    ric%runt%x%alpha = ric%ele0%x%alpha * f0 + ric%ele%x%alpha * f1
    ric%runt%x%gamma = ric%ele0%x%gamma * f0 + ric%ele%x%gamma * f1
    ric%runt%x%eta   = ric%ele0%x%eta   * f0 + ric%ele%x%eta   * f1
    ric%runt%x%etap  = ric%ele0%x%etap  * f0 + ric%ele%x%etap  * f1

    ric%runt%y%beta  = ric%ele0%y%beta  * f0 + ric%ele%y%beta  * f1
    ric%runt%y%alpha = ric%ele0%y%alpha * f0 + ric%ele%y%alpha * f1
    ric%runt%y%gamma = ric%ele0%y%gamma * f0 + ric%ele%y%gamma * f1
    ric%runt%y%eta   = ric%ele0%y%eta   * f0 + ric%ele%y%eta   * f1
    ric%runt%y%etap  = ric%ele0%y%etap  * f0 + ric%ele%y%etap  * f1

    return
  endif

! non-exact calc

  if (s == 0) then
    ric%runt%x       = ric%ele0%x
    ric%runt%y       = ric%ele0%y
    ric%runt%c_mat   = ric%ele0%c_mat
    ric%runt%gamma_c = ric%ele0%gamma_c
    orb = ric%orb0
  elseif (s == ric%ele%value(l$)) then
    ric%runt%x       = ric%ele%x
    ric%runt%y       = ric%ele%y
    ric%runt%c_mat   = ric%ele%c_mat
    ric%runt%gamma_c = ric%ele%gamma_c
    orb = ric%orb1
  else
    ric%runt%value(l$) = s
    if (ric%ele%key == sbend$) ric%runt%value(e2$) = 0
    call track1 (ric%orb0, ric%runt, ric%ring%param, orb)
    call make_mat6 (ric%runt, ric%ring%param, ric%orb0, orb, .true.)
    call twiss_propagate1 (ric%ele0, ric%runt)
  endif

  call make_v_mats (ric%runt, v, v_inv)

  ric%eta_a = &
      matmul(v, (/ ric%runt%x%eta, ric%runt%x%etap, 0.0_rp,   0.0_rp    /))
  ric%eta_b = &
      matmul(v, (/ 0.0_rp,   0.0_rp,    ric%runt%y%eta, ric%runt%y%etap /))

  ric%g_x = ric%g_x0 + orb%vec(1) * ric%k1 + orb%vec(3) * ric%s1
  ric%g_y = ric%g_y0 - orb%vec(3) * ric%k1 + orb%vec(1) * ric%s1
                   
  ric%dg2_x = 2 * (ric%g_x * ric%k1 + ric%g_y * ric%s1)
  ric%dg2_y = 2 * (ric%g_x * ric%s1 - ric%g_y * ric%k1) 

  ric%g2 = ric%g_x**2 + ric%g_y**2
  ric%g = sqrt(ric%g2)

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------

subroutine calc_g_params (s, orb)

  implicit none

  type (coord_struct) orb
  type (g_cache_struct) v0, v1

  real(rp) dk(3,3), s, ds
  real(rp) kick_0(6), f0, f1

  integer i0, i1

! Using the cache is faster if we have one.

  if (ric%use_cache) then
    ds = ric%cache_ele%ds
    i0 = int(s/ds)
    i1 = i0 + 1
    if (i1 > ubound(ric%cache_ele%v, 1)) i1 = i0  ! can happen with roundoff
    f1 = (s - ds*i0) / ds 
    f0 = 1 - f1
    v0 = ric%cache_ele%v(i0)
    v1 = ric%cache_ele%v(i1)
    ric%g      = f0 * v0%g     + f1 * v1%g
    ric%g2     = f0 * v0%g2    + f1 * v1%g2
    ric%g_x    = f0 * v0%g_x   + f1 * v1%g_x
    ric%g_y    = f0 * v0%g_y   + f1 * v1%g_y
    ric%dg2_x  = f0 * v0%dg2_x + f1 * v1%dg2_x
    ric%dg2_y  = f0 * v0%dg2_y + f1 * v1%dg2_y
    return
  endif

! Standard non-cache calc.

  call derivs_bmad (ric%ele, ric%ring%param, s, orb%vec, kick_0, dk)

  ric%g_x = -kick_0(2)
  ric%g_y = -kick_0(4)
  ric%g2 = ric%g_x**2 + ric%g_y**2
  ric%g  = sqrt(ric%g2)

  ric%dg2_x = 2*kick_0(2)*dk(1,1) + 2*kick_0(4)*dk(2,1) 
  ric%dg2_y = 2*kick_0(2)*dk(1,2) + 2*kick_0(4)*dk(2,2) 

end subroutine

end module
