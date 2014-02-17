module bmad_taylor_mod

! Note: The companion bmad_complex_taylor_mod is the same as this one, with 
!   taylor -> complex_taylor
!   real -> complex
! When editing this file, please update bmad_complex_taylor_mod

use sim_utils

! Note: the taylor_struct uses the Bmad standard (x, p_x, y, p_y, z, p_z) 
! the universal_taylor in Etienne's PTC uses (x, p_x, y, p_y, p_z, -c*t)
! %ref is the reference point about which the taylor expansion was made

type taylor_term_struct
  real(rp) :: coef
  integer :: expn(6)  
end type

type taylor_struct
  real (rp) :: ref = 0
  type (taylor_term_struct), pointer :: term(:) => null()
end type

!

interface assignment (=)
  module procedure taylor_equal_taylor
  module procedure taylors_equal_taylors
end interface

!+
! Function taylor_coef (bmad_taylor, exp)
! Function taylor_coef (bmad_taylor, i1, i2, i3, i4, i5, i6, i7, i8, i9)
!
! Function to return the coefficient for a particular taylor term
! from a Taylor Series.
!
! Note: taylor_coef is overloaded by:
!   taylor_coef1 (bmad_taylor, exp)
!   taylor_coef2 (bmad_taylor, i1, i2, i3, i4, i5, i6, i7, i8, i9)
! Using the taylor_coef2 form limits obtaining coefficients to 9th order
! or less. Also: taylor_coef2 does not check that all i1, ..., i9 are between
! 1 and 6.
!
! For example: To get the 2nd order term corresponding to 
!   y(out) = Coef * p_z(in)^2 
! [This is somtimes refered to as the T_366 term]
! The call would be:
!   type (taylor_struct) bmad_taylor(6)      ! Taylor Map
!   ...
!   coef = taylor_coef (bmad_taylor(3), 6, 6)  ! 1st possibility or ...
!   coef = taylor_coef (bmad_taylor(3), [0, 0, 0, 0, 0, 2 ])  
!
! Modules needed:
!   use bmad
!
! Input (taylor_coef1):
!   bmad_taylor -- Taylor_struct: Taylor series.
!   exp(6)      -- Integer: Array of exponent indices.
!
! Input (taylor_coef2):
!   bmad_taylor -- Taylor_struct: Taylor series.
!   i1, ..., i9 -- Integer, optional: indexes (each between 1 and 6).
!
! Output:
!   taylor_coef -- Real(rp): Coefficient.
!-

interface taylor_coef
  module procedure taylor_coef1
  module procedure taylor_coef2
end interface

private taylor_coef1, taylor_coef2

!+
! Subroutine add_taylor_term (bmad_taylor, coef, exp)
! Subroutine add_taylor_term (bmad_taylor, coef, i1, i2, i3, i4, i5, i6, i7, i8, i9)
!
! Routine to add a Taylor term to a Taylor series.
!
! If bmad_taylor does not have a term with the same exponents as expn then a new
! term is added to bmad_taylor so the total number of terms is increased by one.
!
! If bmad_taylor already has a term with the same exponents then
! the "replace" argument determines what happens:
!   If replace = False (default) then
!      coef is added to the coefficient of the old term.
!   If replace = True then
!      coef replaces the coefficient of the old term.
! In both these cases, the number of terms in bmad_taylor remains the same.
!
! Note: add_taylor_term is overloaded by:
!   add_taylor_term1 (bmad_taylor, exp, replace)
!   add_taylor_term2 (bmad_taylor, i1, i2, i3, i4, i5, i6, i7, i8, i9, replace)
! Using the add_taylor_term2 form limits obtaining coefficients to 9th order
! or less. Also: add_taylor_term2 does not check that all i1, ..., i9 are between
! 1 and 6.
!
! For example: To add the 2nd order term corresponding to:
!   y(out) = 1.34 * p_z(in)^2 
! [This is somtimes refered to as the T_366 term]
! The call would be:
!   type (taylor_struct) bmad_taylor(6)      ! Taylor Map
!   ...
!   coef = add_taylor_term (bmad_taylor(3), 1.34_rp, 6, 6)  ! 1st possibility or ...
!   coef = add_taylor_term (bmad_taylor(3), 1.34_rp, [0, 0, 0, 0, 0, 2 ])  
!
! Modules needed:
!   use bmad
!
! Input (add_taylor_term1):
!   bmad_taylor -- Taylor_struct: Taylor series.
!   coef        -- Real(rp): Coefficient.
!   exp(6)      -- Integer: Array of exponent indices.
!   replace     -- Logical, optional: Replace existing term? Default is False.
!
! Input (add_taylor_term2):
!   bmad_taylor -- Taylor_struct: Taylor series.
!   coef        -- Real(rp): Coefficient.
!   i1, ..., i9 -- Integer, optional: Exponent indexes (each between 1 and 6).
!   replace     -- Logical, optional: Replace existing term? Default is False.
!
! Output:
!   bmad_taylor -- Taylor_struct: New series with term added
!-

interface add_taylor_term
  module procedure add_taylor_term1
  module procedure add_taylor_term2
end interface

private add_taylor_term1, add_taylor_term2

contains

!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
!+
! Subroutine taylor_equal_taylor (taylor1, taylor2)
!
! Subroutine that is used to set one taylor equal to another. 
! This routine takes care of the pointers in taylor1. 
!
! Note: This subroutine is called by the overloaded equal sign:
!		taylor1 = taylor2
!
! Input:
!   taylor2 -- Taylor_struct: Input taylor.
!
! Output:
!   taylor1 -- Taylor_struct: Output taylor.
!-

subroutine taylor_equal_taylor (taylor1, taylor2)

implicit none
	
type (taylor_struct), intent(inout) :: taylor1
type (taylor_struct), intent(in) :: taylor2

!

taylor1%ref = taylor2%ref

if (associated(taylor2%term)) then
  call init_taylor_series (taylor1, size(taylor2%term))
  taylor1%term = taylor2%term
else
  if (associated (taylor1%term)) deallocate (taylor1%term)
endif

end subroutine

!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
!+
! Subroutine taylors_equal_taylors (taylor1, taylor2)
!
! Subroutine to transfer the values from one taylor map to another:
!     Taylor1 <= Taylor2
!
! Modules needed:
!   use bmad
!
! Input:
!   taylor2(:) -- Taylor_struct: Taylor map.
!
! Output:
!   taylor1(:) -- Taylor_struct: Taylor map. 
!-

subroutine taylors_equal_taylors (taylor1, taylor2)

implicit none

type (taylor_struct), intent(inout) :: taylor1(:)
type (taylor_struct), intent(in)    :: taylor2(:)

integer i

!

do i = 1, size(taylor1)
  taylor1(i) = taylor2(i)
enddo

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Function taylor_monomial(monomial) result(expn)
!
! Converts a monomial string 'abcdef' to integers [a, b, c, d, e, f] for use in taylor_coef
!
!-
function taylor_monomial(monomial) result(expn)
implicit none
character(6) :: monomial
integer :: i, expn(6)
! Read monomial 
do i=1, 6
  if (monomial(i:i) == ' ') then
    expn(i:6) = 0
    exit
  endif
  expn(i) = index('0123456789', monomial(i:i)) - 1
enddo
end function

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Function taylor_coef1 (bmad_taylor, exp)
!
! Function to return the coefficient for a particular taylor term
! from a Taylor Series. This routine is used by the overloaded function
! taylor_coef. See taylor_coef for more details.
!-

function taylor_coef1 (bmad_taylor, exp) result (coef)

implicit none

type (taylor_struct), intent(in) :: bmad_taylor

real(rp) coef

integer, intent(in) :: exp(:)
integer i

!

coef = 0

do i = 1, size(bmad_taylor%term)
  if (all(bmad_taylor%term(i)%expn == exp)) then
    coef = bmad_taylor%term(i)%coef
    return
  endif
enddo

end function

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Function taylor_coef2 (bmad_taylor, i1, i2, i3, i4, i5, i6, i7, i8, i9)
!
! Function to return the coefficient for a particular taylor term
! from a Taylor Series. This routine is used by the overloaded function
! taylor_coef. See taylor_coef for more details.
!-

function taylor_coef2 (bmad_taylor, i1, i2, i3, &
                          i4, i5, i6, i7, i8, i9) result (coef)

implicit none

type (taylor_struct), intent(in) :: bmad_taylor

real(rp) coef

integer, intent(in), optional :: i1, i2, i3, i4, i5, i6, i7, i8, i9
integer i, exp(6)

!

exp = 0
if (present (i1)) exp(i1) = exp(i1) + 1
if (present (i2)) exp(i2) = exp(i2) + 1
if (present (i3)) exp(i3) = exp(i3) + 1
if (present (i4)) exp(i4) = exp(i4) + 1
if (present (i5)) exp(i5) = exp(i5) + 1
if (present (i6)) exp(i6) = exp(i6) + 1
if (present (i7)) exp(i7) = exp(i7) + 1
if (present (i8)) exp(i8) = exp(i8) + 1
if (present (i9)) exp(i9) = exp(i9) + 1

coef = 0

do i = 1, size(bmad_taylor%term)
  if (all(bmad_taylor%term(i)%expn == exp)) then
    coef = bmad_taylor%term(i)%coef
    return
  endif
enddo

end function

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine type_taylors (bmad_taylor, max_order)
!
! Subroutine to print in a nice format a Bmad Taylor Map at the terminal.
!
! Modules needed:
!   use bmad
!
! Input:
!   bmad_taylor(6) -- Taylor_struct: 6 taylor series: (x, P_x, y, P_y, z, P_z) 
!   max_order      -- Integer, optional: Maximum order to print.
!-

subroutine type_taylors (bmad_taylor, max_order)

implicit none

type (taylor_struct), target :: bmad_taylor(:)
integer i, n_lines
integer, optional :: max_order
character(100), allocatable :: lines(:)

!

call type2_taylors (bmad_taylor, lines, n_lines, max_order)

do i = 1, n_lines
  print *, trim(lines(i))
enddo

deallocate(lines)

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine type2_taylors (bmad_taylor, lines, n_lines, max_order)
!
! Subroutine to write a Bmad taylor map in a nice format to a character array.
!
! Moudles needed:
!   use bmad
!
! Input:
!   bmad_taylor(6) -- Taylor_struct: Array of taylors.
!   max_order      -- Integer, optional: Maximum order to print.
!
! Output:
!   lines(:)     -- Character(*), allocatable: Character array to hold the 
!                     output. The array size of lines(:) will be set by
!                     this subroutine.
!   n_lines      -- Number of lines in lines(:).
!-

subroutine type2_taylors (bmad_taylor, lines, n_lines, max_order)

use re_allocate_mod

implicit none

type (taylor_struct), intent(in), target :: bmad_taylor(6)
type (taylor_term_struct), pointer :: tt
type (taylor_struct) tlr

integer, intent(out) :: n_lines
integer, optional :: max_order
integer i, j, k, nl, ix

character(*), allocatable :: lines(:)
character(40) fmt1, fmt2, fmt

! If not allocated then not much to do

if (.not. associated(bmad_taylor(1)%term)) then
  n_lines = 2
  allocate (lines(n_lines))
  lines(1) = '---------------------------------------------------'
  lines(2) = 'A Taylor Map Does Not Exist.' 
  return
endif

! Normal case

deallocate (lines, stat = ix)
n_lines = 8 + sum( [(size(bmad_taylor(i)%term), i = 1, 6) ])
allocate(lines(n_lines))

write (lines(1), *) 'Taylor Terms:'
write (lines(2), *) &
      'Out     Coef              Exponents           Order        Reference'
nl = 2


fmt1 = '(i4, a, f20.12, 6i3, i9, f18.9)'
fmt2 = '(i4, a, 1p, e20.11, 0p, 6i3, i9, f18.9)'

do i = 1, 6
  nl=nl+1; lines(nl) = ' ---------------------------------------------------'

  nullify (tlr%term)
  call sort_taylor_terms (bmad_taylor(i), tlr)

  do j = 1, size(bmad_taylor(i)%term)

    tt => tlr%term(j)

    if (present(max_order)) then
      if (sum(tt%expn) > max_order) cycle
    endif

    if (abs(tt%coef) < 1e5) then
      fmt = fmt1
    else
      fmt = fmt2
    endif

    if (j == 1) then
      nl=nl+1; write (lines(nl), fmt) i, ':', tt%coef, &
                  (tt%expn(k), k = 1, 6), sum(tt%expn), bmad_taylor(i)%ref
    else
      nl=nl+1; write (lines(nl), fmt) i, ':', tt%coef, &
                  (tt%expn(k), k = 1, 6), sum(tt%expn)
    endif
  enddo

  deallocate (tlr%term)

enddo

call re_allocate (lines, nl)
n_lines = nl

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine taylor_make_unit (bmad_taylor)
!
! Subroutine to make the unit Taylor map:
!       r(out) = Map * r(in) = r(in)
!
! Modules needed:
!   use bmad
!
! Output:
!   bmad_taylor(6) -- Taylor_struct: Unit Taylor map .
!-

subroutine taylor_make_unit (bmad_taylor)

implicit none

type (taylor_struct) bmad_taylor(:)
integer i

do i = 1, size(bmad_taylor)
  call init_taylor_series (bmad_taylor(i), 1)
  bmad_taylor(i)%term(1)%coef = 1.0
  bmad_taylor(i)%term(1)%expn = 0
  bmad_taylor(i)%term(1)%expn(i) = 1
  bmad_taylor(i)%ref = 0
enddo

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine add_taylor_term1 (bmad_taylor, coef, expn, replace)
!
! Routine to add a Taylor term to a Taylor series.
!
! This routine is used by the overloaded function add_taylor_term. 
! See add_taylor_term for more details.
!-

subroutine add_taylor_term1 (bmad_taylor, coef, expn, replace)

implicit none

type (taylor_struct) bmad_taylor

real(rp) coef
integer expn(:), i, n

logical, optional :: replace

! Search for an existing term of the same type

n = size(bmad_taylor%term)

do i = 1, n
  if (all(bmad_taylor%term(i)%expn == expn)) then
    if (logic_option(.false., replace)) then
      bmad_taylor%term(i)%coef = coef
    else
      bmad_taylor%term(i)%coef = coef + bmad_taylor%term(i)%coef
    endif
    if (bmad_taylor%term(i)%coef == 0) then  ! Kill this term
      bmad_taylor%term(i:n-1) = bmad_taylor%term(i+1:n)
      call init_taylor_series (bmad_taylor, n-1, .true.)
    endif
    return
  endif
enddo

! new term

call init_taylor_series (bmad_taylor, n+1, .true.)
bmad_taylor%term(n+1)%coef = coef
bmad_taylor%term(n+1)%expn = expn

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine add_taylor_term2 (bmad_taylor, coef, 
!                        i1, i2, i3, i4, i5, i6, i7, i8, i9, replace)
!
! Routine to add a Taylor term to a Taylor series.
!
! This routine is used by the overloaded function add_taylor_term. 
! See add_taylor_term for more details.
!-

subroutine add_taylor_term2 (bmad_taylor, coef, &
                        i1, i2, i3, i4, i5, i6, i7, i8, i9, replace)

implicit none

type (taylor_struct) bmad_taylor

real(rp) coef

integer, intent(in), optional :: i1, i2, i3, i4, i5, i6, i7, i8, i9
integer i, n, expn(6)

logical, optional :: replace

! 

expn = 0
if (present (i1)) expn(i1) = expn(i1) + 1
if (present (i2)) expn(i2) = expn(i2) + 1
if (present (i3)) expn(i3) = expn(i3) + 1
if (present (i4)) expn(i4) = expn(i4) + 1
if (present (i5)) expn(i5) = expn(i5) + 1
if (present (i6)) expn(i6) = expn(i6) + 1
if (present (i7)) expn(i7) = expn(i7) + 1
if (present (i8)) expn(i8) = expn(i8) + 1
if (present (i9)) expn(i9) = expn(i9) + 1

call add_taylor_term1 (bmad_taylor, coef, expn, replace)

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine init_taylor_series (bmad_taylor, n_term, save)
!
! Subroutine to initialize a Bmad Taylor series (6 of these series make
! a Taylor map). Note: This routine does not zero the structure. The calling
! routine is responsible for setting all values.
!
! Modules needed:
!   use bmad
!
! Input:
!   bmad_taylor -- Taylor_struct: Old structure.
!   n_term      -- Integer: Number of terms to allocate. 
!                   n_term < 1 => bmad_taylor%term pointer will be disassociated.
!   save        -- Logical, optional: If True then save any old terms when
!                   bmad_taylor is resized. Default is False.
!
! Output:
!   bmad_taylor -- Taylor_struct: Initalized structure.
!-

subroutine init_taylor_series (bmad_taylor, n_term, save)

implicit none

type (taylor_struct) bmad_taylor
type (taylor_term_struct), allocatable :: term(:)
integer n_term
integer n
logical, optional :: save

!

if (n_term < 1) then
  if (associated(bmad_taylor%term)) deallocate(bmad_taylor%term)
  return
endif

if (.not. associated (bmad_taylor%term)) then
  allocate (bmad_taylor%term(n_term))
  return
endif

if (size(bmad_taylor%term) == n_term) return

!

if (logic_option (.false., save) .and. n_term > 0 .and. size(bmad_taylor%term) > 0) then
  n = min (n_term, size(bmad_taylor%term))
  allocate (term(n))
  term = bmad_taylor%term(1:n)
  deallocate (bmad_taylor%term)
  allocate (bmad_taylor%term(n_term))
  bmad_taylor%term(1:n) = term
  deallocate (term)

else
  deallocate (bmad_taylor%term)
  allocate (bmad_taylor%term(n_term))
endif

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine kill_taylor (bmad_taylor)
!
! Subroutine to deallocate a Bmad taylor map.
!
! Modules needed:
!   use bmad
!
! Input:
!   bmad_taylor(:) -- Taylor_struct: Taylor to be deallocated. It is OK
!                       if bmad_taylor has already been deallocated.
!
! Output:
!   bmad_taylor(:) -- Taylor_struct: deallocated Taylor structure.
!-

subroutine kill_taylor (bmad_taylor)

implicit none

type (taylor_struct) bmad_taylor(:)

integer i

!

do i = 1, size(bmad_taylor)
  if (associated(bmad_taylor(i)%term)) deallocate (bmad_taylor(i)%term)
enddo

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! subroutine sort_taylor_terms (taylor_in, taylor_sorted)
!
! Subroutine to sort the taylor terms from "lowest" to "highest" of
! a taylor series.
! This subroutine is needed because what comes out of PTC is not sorted.
!
! Uses function taylor_exponent_index to sort.
!
! Note: taylor_sorted needs to have been initialized.
! Note: taylor_sorted cannot be taylor_in. That is it is not legal to write:
!           call sort_taylor_terms (this_taylor, this_taylor)
!
! Modules needed:
!   use bmad
!
! Input:
!   taylor_in     -- Taylor_struct: Unsorted taylor series.
!
! Output:
!   taylor_sorted -- Taylor_struct: Sorted taylor series.
!-

subroutine sort_taylor_terms (taylor_in, taylor_sorted)

use nr

implicit none

type (taylor_struct), intent(in)  :: taylor_in
type (taylor_struct) :: taylor_sorted
type (taylor_term_struct), allocatable :: tt(:)

integer, allocatable :: ord(:), ix(:)

integer i, n, expn(6)

! init

n = size(taylor_in%term)
if (associated(taylor_sorted%term)) deallocate(taylor_sorted%term)
allocate(taylor_sorted%term(n), ix(n), ord(n), tt(n))

!

tt = taylor_in%term

do i = 1, n
  expn = tt(i)%expn
  ord(i) = taylor_exponent_index(expn)
enddo

call indexx (ord, ix)

do i = 1, n
  taylor_sorted%term(i)= tt(ix(i))
enddo

deallocate(ord, ix, tt)

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Function taylor_exponent_index(expn) result(index)
!
! Function to associate a unique number with a taylor exponent.
!
! The number associated with a taylor_term that is used for the sort is:
!     number = sum(exp(i))*10^6 + exp(6)*10^5 + ... + exp(1)*10^0
! where exp(1) is the exponent for x, exp(2) is the exponent for P_x, etc.
! 
! Input:
!   expn(6)  -- integer: taylor exponent
!
! Output:
!   index    -- integer: Sorted taylor series.
!-
function taylor_exponent_index(expn) result(index)
implicit none
integer :: expn(6), index
!
index = sum(expn)*10**6 + expn(6)*10**5 + expn(5)*10**4 + &
              expn(4)*10**3 + expn(3)*10**2 + expn(2)*10**1 + expn(1)
end function


!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine taylor_to_mat6 (a_taylor, r_in, vec0, mat6, r_out)
!
! Subroutine to calculate, from a Taylor map and about some trajectory:
!   The 1st order (Jacobian) transfer matrix.
!
! Modules needed:
!   use bmad
!
! Input:
!   a_taylor(6) -- Taylor_struct: Taylor map.
!   r_in(6)     -- Real(rp): Coordinates at the input. 
!
! Output:
!   vec0(6)   -- Real(rp): 0th order tranfsfer map
!   mat6(6,6) -- Real(rp): 1st order transfer map (6x6 matrix).
!   r_out(6)  -- Real(rp), optional: Coordinates at output.
!-

subroutine taylor_to_mat6 (a_taylor, r_in, vec0, mat6, r_out)

implicit none

type (taylor_struct), target, intent(in) :: a_taylor(6)
real(rp), intent(in) :: r_in(:)
real(rp), optional :: r_out(:)
type (taylor_term_struct), pointer :: term

real(rp), intent(out) :: mat6(6,6), vec0(6)
real(rp) prod, t(6), t_out, out(6)

integer i, j, k, l

! mat6 calc

mat6 = 0
vec0 = 0
out = 0

do i = 1, 6

  terms: do k = 1, size(a_taylor(i)%term)
    term => a_taylor(i)%term(k)
 
    t_out = term%coef
    do l = 1, 6
      if (term%expn(l) == 0) cycle
      t(l) = r_in(l) ** term%expn(l)
      t_out = t_out * t(l)
    enddo

    out(i) = out(i) + t_out
 
    do j = 1, 6
 
      if (term%expn(j) == 0) cycle
      if (term%expn(j) > 1 .and. r_in(j) == 0) cycle

      if (term%expn(j) > 1)then
        prod = term%coef * term%expn(j) * r_in(j) ** (term%expn(j)-1)
      else  ! term%expn(j) == 1
        prod = term%coef
      endif

      do l = 1, 6
        if (term%expn(l) == 0) cycle
        if (l == j) cycle
        prod = prod * t(l)
      enddo

      mat6(i,j) = mat6(i,j) + prod

    enddo

  enddo terms

  vec0(i) = out(i) - sum(mat6(i,:) * r_in)

enddo

if (present(r_out)) r_out = out

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine mat6_to_taylor (vec0, mat6, bmad_taylor)
!
! Subroutine to form a first order Taylor map from the 6x6 transfer
! matrix and the 0th order transfer vector.
!
! Modules needed:
!   use bmad
!
! Input:
!   vec0(6)   -- 0th order transfer vector.
!   mat6(6,6) -- 6x6 transfer matrix.
!
! Output:
!   bmad_taylor(6) -- Taylor_struct: first order taylor map.
!-

subroutine mat6_to_taylor (vec0, mat6, bmad_taylor)

implicit none

type (taylor_struct) bmad_taylor(6)

real(rp), intent(in) :: mat6(6,6)
real(rp), intent(in) :: vec0(6)

integer i, j, n
!

call kill_taylor(bmad_taylor)

do i = 1, 6
  n = count(mat6(i,1:6) /= 0)
  if (vec0(i) /= 0) n = n + 1
  allocate (bmad_taylor(i)%term(n))

  n = 0

  if (vec0(i) /= 0) then
    n = n + 1
    bmad_taylor(i)%term(1)%coef = vec0(i)
    bmad_taylor(i)%term(1)%expn = 0
  endif

  do j = 1, 6
    if (mat6(i,j) /= 0) then
      n = n + 1
      bmad_taylor(i)%term(n)%coef = mat6(i,j)
      bmad_taylor(i)%term(n)%expn = 0
      bmad_taylor(i)%term(n)%expn(j) = 1
    endif
  enddo

enddo

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine track_taylor (start_orb, bmad_taylor, end_orb)
!
! Subroutine to track using a Taylor map.
!
! Modules needed:
!   use bmad
!
! Input:
!   bmad_taylor(6) -- Taylor_struct: Taylor map.
!   start_orb      -- Real(rp): Starting coords.
!
! Output:
!   end_orb        -- Real(rp): Ending coords.
!-

subroutine track_taylor (start_orb, bmad_taylor, end_orb)

implicit none

type (taylor_struct), intent(in) :: bmad_taylor(:)

real(rp), intent(in) :: start_orb(:)
real(rp), intent(out) :: end_orb(:)
real(rp) s0(6)
real(rp), allocatable :: expn(:, :)

integer i, j, k, ie, e_max, i_max

! size cache matrix

e_max = 0
i_max = size(bmad_taylor)

do i = 1, i_max
  do j = 1, size(bmad_taylor(i)%term)
    e_max = max (e_max, maxval(bmad_taylor(i)%term(j)%expn)) 
  enddo
enddo

allocate (expn(0:e_max, i_max))

! Fill in cache matrix

expn(0,:) = 1.0d0  !for when ie=0
expn(1,:) = start_orb(:)
do j = 2, e_max
  expn(j,:) = expn(j-1,:) * start_orb(:)
enddo

! compute taylor map

s0 = start_orb  ! in case start and end are the same in memory.
end_orb = 0

do i = 1, i_max
  do j = 1, size(bmad_taylor(i)%term)
    end_orb(i) = end_orb(i) + bmad_taylor(i)%term(j)%coef * &
                       expn(bmad_taylor(i)%term(j)%expn(1), 1) * &
                       expn(bmad_taylor(i)%term(j)%expn(2), 2) * &
                       expn(bmad_taylor(i)%term(j)%expn(3), 3) * &
                       expn(bmad_taylor(i)%term(j)%expn(4), 4) * &
                       expn(bmad_taylor(i)%term(j)%expn(5), 5) * &
                       expn(bmad_taylor(i)%term(j)%expn(6), 6)
  enddo
enddo

end subroutine


!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine truncate_taylor_to_order (taylor_in, order, taylor_out)
!
! Subroutine to throw out all terms in a taylor map that are above a certain order.
!
! Modules needed:
!   use bmad
!
! Input:
!   taylor_in(:)   -- Taylor_struct: Input Taylor map.
!   order          -- Integer: Order above which terms are dropped.
!
! Output:
!   taylor_out(:)  -- Taylor_struct: Truncated Taylor map.
!-

subroutine truncate_taylor_to_order (taylor_in, order, taylor_out)

implicit none

type (taylor_struct) :: taylor_in(:), taylor_out(:)
type (taylor_struct) :: taylor

integer order
integer i, j, n

!

do i = 1, size(taylor_in)

  taylor = taylor_in(i) ! in case actual args taylor_out and taylor_in are the same

  ! Count the number of terms

  n = 0
  do j = 1, size(taylor%term)
    if (sum(taylor%term(j)%expn) <= order) n = n + 1
  enddo

  call init_taylor_series (taylor_out(i), n)

  n = 0
  do j = 1, size(taylor%term)
    if (sum(taylor%term(j)%expn) > order) cycle
    n = n + 1
    taylor_out(i)%term(n) = taylor%term(j)
  enddo

  taylor_out(i)%ref = taylor_in(i)%ref

enddo

end subroutine truncate_taylor_to_order

end module
