module super_recipes_mod

use precision_def
use output_mod
use re_allocate_mod

contains

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Function super_zbrent (func, x1, x2, tol, err_flag) result (x_min)
!
! Routine find the root of a function.
! This routine is essentially zbrent from Numerical Recipes with the feature that it returns
! an error flag if something goes wrong instead of bombing.
!
! Modules needed:
!   use super_recipes_mod
!
! Input:
!   func(x)  -- Function whose root is to be found. See zbrent for more details.
!   x1, x2   -- Real(rp): Bracket values.
!   tol      -- Real(rp): Tolerance for root.
!
! Output:
!   x_min    -- Real(rp): Root found.
!   err_flag -- Logical: Set True if there is a problem. False otherwise.
!-

function super_zbrent (func, x1, x2, tol, err_flag) result (x_min)

use nrtype

implicit none

real(rp), intent(in) :: x1,x2,tol
real(rp) :: x_min

interface
  function func(x)
    use precision_def
    implicit none
    real(rp), intent(in) :: x
    real(rp) :: func
    end function func
end interface

integer(i4b), parameter :: itmax=100
real(rp), parameter :: eps=epsilon(x1)
integer(i4b) :: iter
real(rp) :: a,b,c,d,e,fa,fb,fc,p,q,r,s,tol1,xm

logical err_flag
character(16) :: r_name = 'super_zbrent'

!

err_flag = .true.
a=x1
b=x2
fa=func(a)
fb=func(b)
if ((fa > 0.0 .and. fb > 0.0) .or. (fa < 0.0 .and. fb < 0.0)) &
call out_io (s_fatal$, r_name, 'ROOT NOT BRACKETED!')
c=b
fc=fb
do iter=1,ITMAX
if ((fb > 0.0 .and. fc > 0.0) .or. (fb < 0.0 .and. fc < 0.0)) then
c=a
fc=fa
    d=b-a
    e=d
  end if
  if (abs(fc) < abs(fb)) then
    a=b
    b=c
    c=a
    fa=fb
    fb=fc
    fc=fa
  end if
  tol1=2.0_rp*EPS*abs(b)+0.5_rp*tol
  xm=0.5_rp*(c-b)
  if (abs(xm) <= tol1 .or. fb == 0.0) then
    x_min=b
    err_flag = .false.
    RETURN
  end if
  if (abs(e) >= tol1 .and. abs(fa) > abs(fb)) then
    s=fb/fa
    if (a == c) then
      p=2.0_rp*xm*s
      q=1.0_rp-s
    else
      q=fa/fc
      r=fb/fc
      p=s*(2.0_rp*xm*q*(q-r)-(b-a)*(r-1.0_rp))
      q=(q-1.0_rp)*(r-1.0_rp)*(s-1.0_rp)
    end if
    if (p > 0.0) q=-q
    p=abs(p)
    if (2.0_rp*p  <  min(3.0_rp*xm*q-abs(tol1*q),abs(e*q))) then
      e=d
      d=p/q
    else
      d=xm
      e=d
    end if
  else
    d=xm
    e=d
  end if
  a=b
  fa=fb
  b=b+merge(d,sign(tol1,xm), abs(d) > tol1 )
  fb=func(b)
end do
call out_io (s_fatal$, r_name, 'EXCEEDED MAXIMUM ITERATIONS!')
x_min=b

end function super_zbrent 

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! subroutine super_mrqmin (y, weight, a, covar, alpha, chisq, funcs, alamda, status, maska)
!
! Routine to do non-linear optimizations. 
! This routine is essentially mrqmin from Numerical Recipes with some added features and
! some code tweaking to make the code run faster.
!
! Note: This routine uses saved (global) variables. It is NOT thread safe.
! 
! Modules needed:
!   use super_recipes_mod
!
! Input:
!   y(:)        -- Real(rp): See mrqmin in NR for more details.
!   weight(:)   -- Real(rp): This is equivalent to the 1/sig^2 of mrqmin in NR.
!   a(:)        -- Real(rp): See mrqmin in NR for more details.
!   funcs       -- Function: User supplied function. See mrqmin in NR for more details.
!                   The interface is:
!                        subroutine funcs(a, yfit, dyda, status)
!                          use precision_def
!                          real(rp), intent(in) :: a(:)
!                          real(rp), intent(out) :: yfit(:)
!                          real(rp), intent(out) :: dyda(:, :)
!                          integer status
!                        end subroutine funcs
!                   Note: If funcs sets the status argument to anything non-zero, 
!                   super_mrqmin will halt the calculation and return back to the 
!                   calling routine. funcs should use positive values for status to
!                   avoid conflict with gaussj. 
!                   to the calling routine
!   alamda      -- Real(rp): See mrqmin in NR for more details.
!   maska(:)    -- Logical, optional: See mrqmin in NR for more details.
!                    Default is True for all elements of the array.
!
! Output:
!   a(:)        -- Real(rp): See mrqmin in NR for more details.
!   covar(:,:)  -- Real(rp): See mrqmin in NR for more details.
!   alpha(:,:)  -- Real(rp): See mrqmin in NR for more details.
!   chisq       -- Real(rp): See mrqmin in NR for more details.
!   alamda      -- Real(rp): See mrqmin in NR for more details.
!   status      -- Integer: Calculation status:
!                      -2     => Singular matrix error in gaussj routine.
!                      -1     => Singular matrix error in gaussj routine.
!                       0     => Normal.
!                       Other => Set by funcs. 
!-

subroutine super_mrqmin (y, weight, a, covar, alpha, chisq, funcs, alamda, status, maska)

use nrtype; use nrutil, only : assert_eq, diagmult
use nr, only : covsrt

implicit none

real(rp) :: y(:), weight(:)
real(rp) :: a(:)
real(rp) :: covar(:, :), alpha(:, :)
real(rp) :: chisq
real(rp) :: alamda
integer(i4b) :: ma, ndata
integer(i4b), save :: mfit
integer status

logical, allocatable, save :: mask(:)
logical, intent(in), optional :: maska(:)

real(rp), save :: ochisq
real(rp), dimension(:), allocatable, save :: atry, beta
real(rp), allocatable, save :: da(:,:)

interface
  subroutine funcs(a, yfit, dyda, status)
    use precision_def
    real(rp), intent(in) :: a(:)
    real(rp), intent(out) :: yfit(:)
    real(rp), intent(out) :: dyda(:, :)
    integer status
  end subroutine funcs
end interface

!

ndata=assert_eq(size(y), size(weight), 'super_mrqmin: ndata')
ma=assert_eq([size(a), size(covar, 1), size(covar, 2), &
              size(alpha, 1), size(alpha, 2)], 'super_mrqmin: ma')

call re_allocate(mask, size(a))
if (present(maska)) then
  ma = assert_eq([size(a), size(maska)], 'super_mrqmin: maska')
  mask = maska
else
  mask = .true.
endif

status = 0
mfit = count(mask)

if (alamda < 0.0) then
  call re_allocate(atry, ma)
  call re_allocate(beta, ma)
  call re_allocate2d (da, ma, 1)
  alamda=0.001_rp
  call super_mrqcof(a, y, alpha, beta, weight, chisq, funcs, status, mask)
  if (status /= 0) then
    deallocate(atry, beta, da)
    return
  endif
  ochisq=chisq
  atry=a
end if

covar(1:mfit, 1:mfit)=alpha(1:mfit, 1:mfit)
call diagmult(covar(1:mfit, 1:mfit), 1.0_rp+alamda)
da(1:mfit, 1)=beta(1:mfit)
call super_gaussj(covar(1:mfit, 1:mfit), da(1:mfit, 1:1), status)
if (status /= 0) return

if (alamda == 0.0) then
  call covsrt(covar, mask)
  call covsrt(alpha, mask)
  deallocate(atry, beta, da)
  return
end if

atry=a+unpack(da(1:mfit, 1), mask, 0.0_rp)
call super_mrqcof(atry, y, covar, da(1:mfit, 1), weight, chisq, funcs, status, mask)
if (status /= 0) return

! Increase alamda by 2 (Instead of 10 as in NR version) gives better convergence. See:
!   "The Geometry of Nonlinear Least Squares, with applications to Sloppy Models and Optimization"
!   Mark K Transtrum, et. al.

if (chisq < ochisq) then
  alamda=0.1_rp * alamda
  ochisq=chisq
  alpha(1:mfit, 1:mfit)=covar(1:mfit, 1:mfit)
  beta(1:mfit)=da(1:mfit, 1)
  a=atry
else
  alamda=2.0_rp * alamda
  chisq=ochisq
end if

end subroutine super_mrqmin

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine super_mrqcof (a, y, alpha, beta, weight, chisq, funcs, status, mask)
! 
! Routine used by super_mrqmin. Not meant for general use.
!-

subroutine super_mrqcof (a, y, alpha, beta, weight, chisq, funcs, status, mask)

use nrtype 

implicit none

real(rp) :: y(:), a(:), weight(:)
real(rp) :: beta(:)
real(rp) :: alpha(:, :)
real(rp) chisq
real(rp), allocatable, save :: dyda(:, :)
real(rp), allocatable, save :: dy(:), wt(:), ymod(:)

integer(i4b) :: j, k, l, m, nv, nd
integer status

logical :: mask(:)


interface
  subroutine funcs(a, yfit, dyda, status)
    use precision_def
    real(rp), intent(in) :: a(:)
    real(rp), intent(out) :: yfit(:)
    real(rp), intent(out) :: dyda(:, :)
    integer status
  end subroutine funcs
end interface

!

nd = size(weight)
nv = size(a)

if (allocated(dyda)) then
  if (size(dyda, 1) /= nd .or. size(dyda, 2) /= nv) &
                                        deallocate (dyda, dy, wt, ymod)
endif
if (.not. allocated(dyda)) then
  allocate (dyda(nd, nv), dy(nd), wt(nd), ymod(nd))
endif

!

call funcs(a, ymod, dyda, status)
if (status /= 0) return

dy=y-ymod
j=0

do l=1, nv
  if (.not. mask(l)) cycle
  j=j+1
  wt=dyda(:, l) * weight
  k=0
  do m=1, l
    k=k+1
    alpha(j, k)=dot_product(wt, dyda(:, m))
    alpha(k, j)=alpha(j, k)
  end do
  beta(j)=dot_product(dy, wt)
end do

chisq = dot_product(dy**2, weight)

end subroutine super_mrqcof

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine super_gaussj (a, b, status)
! 
! This is the gaussj routine from Num Rec with an added status argument.
!
! Modules needed:
!   super_recipes_mod
!
! Input:
!   a(:,:) -- Real(rp): matrix.
!   b(:,:) -- Real(rp): matrix.
!
! Output:
!   a(:,:) -- Real(rp): matrix.
!   b(:,:) -- Real(rp): matrix.
!   status -- Integer: Status. Set to -1 or -2 if there is an error.
!               Set to 0 otherwise.
!-

subroutine super_gaussj (a, b, status)

use nrtype; use nrutil, only : assert_eq, outerand, outerprod, swap

implicit none

real(rp), dimension(:, :), intent(inout) :: a, b
real(rp) :: pivinv

real(rp), dimension(size(a, 1)) :: dumc
integer(i4b), dimension(size(a, 1)) :: ipiv, indxr, indxc
logical(lgt), dimension(size(a, 1)) :: lpiv

integer status
integer(i4b), target :: irc(2)
integer(i4b) :: i, l, n
integer(i4b), pointer :: irow, icol

character(16) :: r_name = 'super_gaussj'

!

n=assert_eq(size(a, 1), size(a, 2), size(b, 1), 'gaussj')
irow => irc(1)
icol => irc(2)
ipiv=0

do i=1, n
   lpiv = (ipiv == 0)
   irc=maxloc(abs(a), outerand(lpiv, lpiv))
   ipiv(icol)=ipiv(icol)+1
   if (ipiv(icol) > 1) then
      status = -1
      call out_io (s_error$, r_name, 'SINGULAR MATRIX! (1)')
      return
   end if
   if (irow /= icol) then
      call swap(a(irow, :), a(icol, :))
      call swap(b(irow, :), b(icol, :))
   end if
   indxr(i)=irow
   indxc(i)=icol
   if (a(icol, icol) == 0.0) then
      status = -2
      call out_io (s_error$, r_name, 'SINGULAR MATRIX! (2)')
      return
   end if
   pivinv=1.0_rp/a(icol, icol)
   a(icol, icol)=1.0
   a(icol, :)=a(icol, :)*pivinv
   b(icol, :)=b(icol, :)*pivinv
   dumc=a(:, icol)
   a(:, icol)=0.0
   a(icol, icol)=pivinv
   a(1:icol-1, :)=a(1:icol-1, :)-outerprod(dumc(1:icol-1), a(icol, :))
   b(1:icol-1, :)=b(1:icol-1, :)-outerprod(dumc(1:icol-1), b(icol, :))
   a(icol+1:, :)=a(icol+1:, :)-outerprod(dumc(icol+1:), a(icol, :))
   b(icol+1:, :)=b(icol+1:, :)-outerprod(dumc(icol+1:), b(icol, :))
end do

do l=n, 1, -1
   call swap(a(:, indxr(l)), a(:, indxc(l)))
end do

status = 0

end subroutine super_gaussj

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine super_ludcmp (a, indx, d, err)
!
! This routine is essentially ludcmp from Numerical Recipes with the added feature
! that an error flag is set instead of bombing the program when there is a problem.
!
! Modules needed:
!   use super_recipes_mod
!
! Input:
!   a(:,:) -- Real(rp): Input matrix.
!
! Output
!   indx(:) -- Integer: See NR.
!   d       -- Real(rp): See NR.
!   err     -- Logical: Error flag set True if there is a problem. False otherwise.
!-

subroutine super_ludcmp(a,indx,d, err)

use nrtype; use nrutil, only : assert_eq,imaxloc,outerprod,swap
implicit none
real(rp), dimension(:,:), intent(inout) :: a
integer, dimension(:), intent(out) :: indx
real(rp), intent(out) :: d
real(rp), dimension(size(a,1)) :: vv
real(rp), parameter :: tiny=1.0e-20_rp
integer :: j,n,imax
character :: r_name = 'super_ludcmp'
logical err

!

err = .true.
n=assert_eq(size(a,1),size(a,2),size(indx),'ludcmp')
d=1.0
vv=maxval(abs(a),dim=2)
if (any(vv == 0.0)) then
  call out_io (s_error$, r_name, 'singular matrix')
  return
endif
vv=1.0_rp/vv
do j=1,n
  imax=(j-1)+imaxloc(vv(j:n)*abs(a(j:n,j)))
  if (j /= imax) then
    call swap(a(imax,:),a(j,:))
    d=-d
    vv(imax)=vv(j)
  end if
  indx(j)=imax
  if (a(j,j) == 0.0) a(j,j)=tiny
  a(j+1:n,j)=a(j+1:n,j)/a(j,j)
  a(j+1:n,j+1:n)=a(j+1:n,j+1:n)-outerprod(a(j+1:n,j),a(j,j+1:n))
end do
err = .false.

end subroutine super_ludcmp

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Function super_brent (ax, bx, cx, func, rel_tol, abs_tol, xmin)
!
! This routine is essentially brent from Numerical Recipes with the added feature
! there are two tollerances: rel_tol and abs_tol.
!
! Modules needed:
!   use super_recipes_mod
!
! Input:
!
!
! Output
!
!
!
!-

function super_brent(ax, bx, cx, func, rel_tol, abs_tol, xmin) result (f_max)

use nrtype

implicit none

real(rp), intent(in) :: ax,bx,cx,rel_tol, abs_tol
real(rp), intent(out) :: xmin
real(rp) :: f_max

interface
  function func(x)
    use precision_def
    implicit none
    real(rp), intent(in) :: x
    real(rp) :: func
  end function func
end interface

integer(i4b), parameter :: itmax=100
real(rp), parameter :: cgold=0.3819660_rp
integer(i4b) :: iter
real(rp) :: a,b,d,e,etemp,fu,fv,fw,fx,p,q,r,tol1,tol2,u,v,w,x,xm

character(16) :: r_name = 'super_brent'

!

a=min(ax,cx)
b=max(ax,cx)
v=bx
w=v
x=v
e=0.0
fx=func(x)
fv=fx
fw=fx
do iter=1,ITMAX
  xm=0.5_rp*(a+b)
  tol1=rel_tol*abs(x)+abs_tol
  tol2=2.0_rp*tol1
  if (abs(x-xm) <= (tol2-0.5_rp*(b-a))) then
    xmin=x
    f_max=fx
    RETURN
  end if
  if (abs(e) > tol1) then
    r=(x-w)*(fx-fv)
    q=(x-v)*(fx-fw)
    p=(x-v)*q-(x-w)*r
    q=2.0_rp*(q-r)
    if (q > 0.0) p=-p
    q=abs(q)
    etemp=e
    e=d
    if (abs(p) >= abs(0.5_rp*q*etemp) .or. p <= q*(a-x) .or. p >= q*(b-x)) then
      e=merge(a-x,b-x, x >= xm )
      d=CGOLD*e
    else
      d=p/q
      u=x+d
      if (u-a < tol2 .or. b-u < tol2) d=sign(tol1,xm-x)
    end if
  else
    e=merge(a-x,b-x, x >= xm )
    d=cgold*e
  end if
  u=merge(x+d,x+sign(tol1,d), abs(d) >= tol1 )
  fu=func(u)
  if (fu <= fx) then
    if (u >= x) then
      a=x
    else
      b=x
    end if
    call shft(v,w,x,u)
    call shft(fv,fw,fx,fu)
  else
    if (u < x) then
      a=u
    else
      b=u
    end if
    if (fu <= fw .or. w == x) then
      v=w
      fv=fw
      w=u
      fw=fu
    else if (fu <= fv .or. v == x .or. v == w) then
      v=u
      fv=fu
    end if
  end if
end do
call out_io (s_fatal$, r_name, 'EXCEED MAXIMUM ITERATIONS.')
if (global_com%exit_on_error) call err_exit

!-------------------------------------------------
contains

subroutine shft(a,b,c,d)
real(rp), intent(out) :: a
real(rp), intent(inout) :: b,c
real(rp), intent(in) :: d

a=b
b=c
c=d
end subroutine shft
end function super_brent

end module
