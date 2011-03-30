module basic_bmad_mod

use sim_utils
use precision_def
use output_mod

integer, parameter :: n_pole_maxx = 20  ! maximum multipole order

contains

!--------------------------------------------------------------------
!--------------------------------------------------------------------
!--------------------------------------------------------------------
!+
! Function R_bessel(m, arg) result (r_out)
!
! Function to return the bessel function:
!   J_bessel(m, arg)   arg > 0
!   I_bessel(m, -arg)  arg < 0
!
! Modules needed:
!   use basic_bmad_mod
!
! Input:
!   m    -- Integer: Bessel order.
!   arg  -- Real(rp): Bessel argument.
!
! Output:
!   r_out -- Real(rp): Bessel value.
!-

function R_bessel(m, arg) result (r_out)

use nr

integer m
real(rp) arg, r_out

!

select case(m)
case (0)
  if (arg > 0) then
    r_out = bessi0(arg)
  else
    r_out = bessj0(-arg)
  endif

case (1)
  if (arg > 0) then
    r_out = bessi1(arg)
  else
    r_out = bessj1(-arg)
  endif

case default
  if (arg > 0) then
    r_out = bessi(m, arg)
  else
    r_out = bessj(m, -arg)
  endif
end select

end function r_bessel

!--------------------------------------------------------------------
!--------------------------------------------------------------------
!--------------------------------------------------------------------
!+
! Function field_interpolate_3d (position, field_mesh, deltas, position0) result (field)
!
! Function to interpolate a 3d field.
! The interpolation is such that the derivative is continuous.
!
! Note: For "interpolation" outside of the region covered by the field_mesh
! it is assumed that the field is constant, Equal to the field at the
! boundary.
!
! Modules needed:
!
! Input:
!   position(3)       -- Real(rp): (x, y, z) position.
!   field_mesh(:,:,:) -- Real(rp): Grid of field points.
!   deltas(3)         -- Real(rp): (dx, dy, dz) distances between mesh points.
!   position0(3)      -- Real(rp), optional:  position at (ix0, iy0, iz0) where
!                            (ix0, iy0, iz0) is the lower bound of the
!                            filed_mesh(i, j, k) array. If not present then
!                            position0 is taken to be (0.0, 0.0, 0.0)
! Output:
!   field -- Real(rp): interpolated field.
!-

function field_interpolate_3d (position, field_mesh, deltas, position0) result (field)

implicit none

real(rp), optional, intent(in) :: position0(3)
real(rp), intent(in) :: position(3), field_mesh(0:,0:,0:), deltas(3)
real(rp) field

real(rp) r(3), f(-1:2), g(-1:2), h(-1:2), r_frac(3)

integer i0(3), ix, iy, iz, iix, iiy, iiz

!

if (present(position0)) then
  r = (position - position0) / deltas
else
  r = position / deltas
endif

i0 = int(r)
r_frac = r - i0

do ix = -1, 2
 iix = min(max(ix + i0(1), 0), ubound(field_mesh, 1))
 do iy = -1, 2
    iiy = min(max(iy + i0(2), 0), ubound(field_mesh, 2))
    do iz = -1, 2
      iiz = min(max(iz + i0(3), 0), ubound(field_mesh, 3))
      f(iz) = field_mesh(iix, iiy, iiz)
    enddo
    g(iy) = interpolate_1d (r_frac(3), f)
  enddo
  h(ix) = interpolate_1d (r_frac(2), g)
enddo
field = interpolate_1d (r_frac(1), h)

!---------------------------------------------------------------

contains

! interpolation in 1 dimension using 4 equally spaced points: P1, P2, P3, P4.
!   x = interpolation point.
!           x = 0 -> point is at P2.
!           x = 1 -> point is at P3.
! Interpolation is done so that the derivative is continuous.
! The interpolation uses a cubic polynomial

function interpolate_1d (x, field1_in) result (field1)

implicit none

real(rp) field1, x, field1_in(4), df_2, df_3
real(rp) c0, c1, c2, c3

!

df_2 = (field1_in(3) - field1_in(1)) / 2   ! derivative at P2
df_3 = (field1_in(4) - field1_in(2)) / 2   ! derivative at P3

c0 = field1_in(2)
c1 = df_2
c2 = 3 * field1_in(3) - df_3 - 3 * field1_in(2) - 2 * df_2
c3 = df_3 - 2 * field1_in(3) + 2 * field1_in(2) + df_2

field1 = c0 + c1 * x + c2 * x**2 + c3 * x**3

end function interpolate_1d

end function field_interpolate_3d 

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine compute_even_steps (ds_in, length, ds_default, ds_out, n_step)
!
! Subroutine to compute a step size ds_out, close to ds_in, so that an 
! integer number of steps spans the length:
!   length = ds_out * n_step
!
! Modules needed:
!   use bmad
!
! Input:
!   ds_in      -- Real(rp): Input step size.
!   length     -- Real(rp): Total length.
!   ds_default -- Real(rp): Default to use if ds_in = 0.
!
! Output:
!   ds_out    -- Real(rp): Step size to use.
!   n_step    -- Integer: Number of steps needed.
!-

subroutine compute_even_steps (ds_in, length, ds_default, ds_out, n_step)

implicit none

real(rp) ds_in, length, ds_default, ds_out
integer n_step

!

ds_out = ds_in
if (ds_out == 0) ds_out = ds_default
n_step = nint(length / ds_out)
if (n_step == 0) n_step = 1
ds_out = length / n_step  

end subroutine compute_even_steps

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Function c_multi (n, m, no_n_fact) result (c_out)
!
! Subroutine to compute multipole factors:
!          c_multi(n, m) =  +/- ("n choose m")/n!
! This is used in calculating multipoles.
!
! Input:
!   n,m       -- Integer: For n choose m
!   no_n_fact -- Logical, optional: If present and true then
!                 c_out = +/- "n choose m".
!
! Output:
!   c_out  -- Real(rp): Multipole factor.
!-

function c_multi (n, m, no_n_fact) result (c_out)

implicit none

integer, intent(in) :: n, m
integer in, im

real(rp) c_out
real(rp), save :: n_factorial(0:n_pole_maxx)
real(rp), save :: c(0:n_pole_maxx, 0:n_pole_maxx)

logical, save :: init_needed = .true.
logical, optional :: no_n_fact

! The magnitude of c(n, m) is number of combinations normalized by n!

if (init_needed) then

  c(0, 0) = 1

  do in = 1, n_pole_maxx
    c(in, 0) = 1
    c(in, in) = 1
    do im = 1, in-1
      c(in, im) = c(in-1, im-1) + c(in-1, im)
    enddo
  enddo

  n_factorial(0) = 1

  do in = 0, n_pole_maxx
    if (in > 0) n_factorial(in) = in * n_factorial(in-1)
    do im = 0, in
      c(in, im) = c(in, im) / n_factorial(in)
      if (mod(im, 4) == 0) c(in, im) = -c(in, im)
      if (mod(im, 4) == 3) c(in, im) = -c(in, im)
    enddo
  enddo

  init_needed = .false.

endif

!

if (logic_option (.false., no_n_fact)) then
  c_out = c(n, m) * n_factorial(n)
else
  c_out = c(n, m)
endif

end function c_multi

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function mexp (x, m) result (this_exp)
!
! Returns x^m with 0^0 = 1.
!
! Modules needed:
!   use bmad
!
! Input:
!   x -- Real(rp): Number.
!   m -- Integer: Exponent.
!
! Output:
!   this_exp -- Real(rp): Result.
!-

function mexp (x, m) result (this_exp)

implicit none

real(rp) x, this_exp
integer m

!

if (m < 0) then
  this_exp = 0
elseif (m == 0) then
  this_exp = 1
else
  this_exp = x**m
endif

end function mexp

end module
