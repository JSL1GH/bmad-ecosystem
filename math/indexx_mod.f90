module indexx_mod

use utilities_mod

implicit none

type char_indexx_struct
  character(400), allocatable :: names(:)  !  Array of names.
  integer,       allocatable :: indexx(:)  !  Sorted index for names(:) array.
                                           !    names(an_indexx(i)) is in alphabetical order.
  integer                    :: n_min = 1  ! 
  integer                    :: n_max      !  Use only names(n_min:n_max) part of array.
end type


interface indexx
  module procedure indexx_char
end interface

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine find_indexx
!
! This routine is an overloaded name for: 
!   Subroutine find_indexx0 (name, char_indexx, ix_match, ix2_match, add_to_list, n_match)
!   Subroutine find_indexx1 (name, names, an_indexx, n_max, ix_match, ix2_match, add_to_list, n_match)
!   Subroutine find_indexx2 (name, names, an_indexx, n_min_max, ix_match, ix2_match, add_to_list, n_match)
!
! Subroutine to find a matching name in a list of names.
! The routine indexx should be used to create an_indexx.
! Also see: find_indexx2
!
! If add_to_list = True, name is added to the names_list and
! an_indexx is updated using the prescription:
!   Find ix2_match.
!   an_indexx(ix2_match+1:n_max+1) = an_indexx(ix2_match:n_max)
!   an_indexx(ix2_match) = n_max + 1
!   names(n_max+1) = name
!   ix_match = n_max+1
!
! Modules needed:
!   use indexx_mod
!
! Input:
!   name         -- Character(*): Name to match to.
!   char_indexx  -- char_index_struct: Array of names.
!   names(:)     -- Character(*): Array of names.
!   an_indexx(:) -- Integer: Sorted index for names(:) array.
!                     names(an_indexx(i)) is in alphabetical order.
!   n_min_max(2) -- integer: Min and max indexes for names(:) array.
!   n_max        -- Integer: Use only names(1:n_max) part of array.
!   add_to_list  -- Logical, optional: If present and True and name does not appear in the names(:) array,
!                       add name to the end of the names(:) array and update the char_indexx%index array.
!
! Output:
!   ix_match  -- Integer: If a match is found then:
!                             names(ix_match) = name
!                  If no match is found then ix_match = 0.
!   ix2_match -- Integer, optional: 
!                  If a match is found then
!                              an_indexx(ix2_match) = ix_match
!                              names(an_indexx(ix2_match-1)) /= name
!                  If no match is found then 
!                    for j = an_indexx(ix2_match):
!                              names(j) > name
!                    and if ix2_match > 1 then for j = an_indexx(ix2_match-1):
!                              names(j) < name
!   names(:)     -- Character(*): Updated if add_to_list = True.
!   an_indexx(:) -- Integer: Updated if add_to_list = True.
!   n_match      -- integer, optional: Number items in the updated names list that match .
!-

interface find_indexx
  module procedure find_indexx0
  module procedure find_indexx1
  module procedure find_indexx2
end interface

contains

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine find_indexx0 (name, char_indexx, ix_match, ix2_match, add_to_list, n_match)
!
! Subroutine to find a matching name in a list of names.
! This name is overloaded by find_indexx.
! See the find_indexx documentation for more details.
!-

subroutine find_indexx0 (name, name_index, ix_match, ix2_match, add_to_list, n_match)

character(*) name
type (char_indexx_struct) name_index
integer  ix_match
integer, optional :: ix2_match
logical, optional :: add_to_list
integer, optional :: n_match

!

call find_indexx2 (name, name_index%names, name_index%indexx, &
              [name_index%n_min, name_index%n_max], ix_match, ix2_match, add_to_list, n_match)

end subroutine find_indexx0

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine find_indexx1 (name, names, an_indexx, n_max, ix_match, ix2_match, add_to_list, n_match)
!
! Subroutine to find a matching name in a list of names.
! This name is overloaded by find_indexx.
! See the find_indexx documentation for more details.
!-

subroutine find_indexx1 (name, names, an_indexx, n_max, ix_match, ix2_match, add_to_list, n_match)

integer ix1, ix2, ix3, n_max, ix_match
integer, optional :: ix2_match
integer an_indexx(:)
integer, optional :: n_match

character(*) name, names(:)

logical, optional :: add_to_list

! 

call find_indexx2 (name, names, an_indexx, [1, n_max], ix_match, ix2_match, add_to_list, n_match)

end subroutine find_indexx1

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine find_indexx2 (name, names, an_indexx, n_min_max, ix_match, ix2_match, add_to_list, n_match)
!
! Subroutine to find a matching name in a list of names.
! This name is overloaded by find_indexx.
! See the find_indexx documentation for more details.
!-

subroutine find_indexx2 (name, names, an_indexx, n_min_max, ix_match, ix2_match, add_to_list, n_match)

integer ix1, ix2, ix3, n_min_max(2), n_min, n_max, ix_match
integer, optional :: ix2_match
integer an_indexx(n_min_max(1):)

character(*) name, names(n_min_max(1):)

logical, optional :: add_to_list
integer, optional :: n_match

! simple case where there are no elements

n_min = n_min_max(1)
n_max = n_min_max(2)

if (n_max < n_min) then
  if (present(ix2_match)) ix2_match = n_min
  ix_match = n_min - 1
  if (logic_option(.false., add_to_list)) then
    ix_match = n_min
    an_indexx(n_min) = n_min
    names(n_min) = name
    if (present(n_match)) n_match = 1
  else
    if (present(n_match)) n_match = 0
  endif
  return
endif

!

ix1 = n_min
ix3 = n_max

do

  ix2 = (ix1 + ix3) / 2 

  if (names(an_indexx(ix2)) == name) then
    do ! if there are duplicate names in the list choose the first one
      if (ix2 == n_min) exit
      if (names(an_indexx(ix2-1)) /= names(an_indexx(ix2))) exit
      ix2 = ix2 - 1
    enddo
    ix_match = an_indexx(ix2)
    exit
  elseif (names(an_indexx(ix2)) < name) then
    ix1 = ix2 + 1
  else
    ix3 = ix2 - 1
  endif
                     
  if (ix1 > ix3) then
    ix_match = n_min - 1
    if (names(an_indexx(ix2)) < name) ix2 = ix2 + 1
    exit
  endif

enddo

if (present(ix2_match)) ix2_match = ix2

if (logic_option(.false., add_to_list) .and. name /= names(ix_match)) then
  an_indexx(ix2+1:n_max+1) = an_indexx(ix2:n_max)
  an_indexx(ix2) = n_max + 1
  names(n_max+1) = name
  ix_match = n_max + 1
endif

if (present(n_match)) then
  n_match = 0
  if (ix_match == n_min - 1) return
  do
    if (names(an_indexx(ix2)) /= name) return
    n_match = n_match +1
    ix2 = ix2 + 1
    if (ix2 > n_max) return
  enddo
endif

end subroutine find_indexx2

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine indexx_char (arr, index)
!
! Subroutine to sort a character array.
! This subroutine is used to overload the generic name indexx.
! This is an extension of the Numerical Recipes routine indexx.
!
! See also find_indexx
!
! Modules needed:
!   use sim_utils
!
! Input:
!   arr(:) -- character(*): Array of strings
!
! Output:
!   index(:) -- integer: sorted list such that:
!                 For all j, arr(i1) < arr(i2) where i1 = index(j), i2 = index(j+1).
!-

  SUBROUTINE indexx_char(arr,index)
  USE nrtype; USE nrutil, ONLY : arth,assert_eq,nrerror,swap

  character(*), DIMENSION(:), INTENT(IN) :: arr
  INTEGER(I4B), DIMENSION(:), INTENT(OUT) :: index
  INTEGER(I4B), PARAMETER :: NN=15, NSTACK=50
  character(120) :: a
  integer ia
  INTEGER(I4B) :: n,k,i,j,indext,jstack,l,r
  INTEGER(I4B), DIMENSION(NSTACK) :: istack
  n=assert_eq(size(index),size(arr),'indexx_char')
  index=arth(1,1,n)
  jstack=0
  ia = len(arr(1))
  if (ia > len(a)) then
    print *, 'ERROR IN INDEXX_CHAR: CHARACTER LENGTH TOO LARGE!'
    stop
  endif
  l=1
  r=n
  do
    if (r-l < NN) then
      do j=l+1,r
        indext=index(j)
        a(1:ia)=arr(indext)
        do i=j-1,l,-1
          if (arr(index(i)) <= a(1:ia)) exit
          index(i+1)=index(i)
        end do
        index(i+1)=indext
      end do
      if (jstack == 0) RETURN
      r=istack(jstack)
      l=istack(jstack-1)
      jstack=jstack-2
    else
      k=(l+r)/2
      call swap(index(k),index(l+1))
      call icomp_xchg(index(l),index(r))
      call icomp_xchg(index(l+1),index(r))
      call icomp_xchg(index(l),index(l+1))
      i=l+1
      j=r
      indext=index(l+1)
      a(1:ia)=arr(indext)
      do
        do
          i=i+1
          if (arr(index(i)) >= a(1:ia)) exit
        end do
        do
          j=j-1
          if (arr(index(j)) <= a(1:ia)) exit
        end do
        if (j < i) exit
        call swap(index(i),index(j))
      end do
      index(l+1)=index(j)
      index(j)=indext
      jstack=jstack+2
      if (jstack > NSTACK) call nrerror('indexx: NSTACK too small')
      if (r-i+1 >= j-l) then
        istack(jstack)=r
        istack(jstack-1)=i
        r=j-1
      else
        istack(jstack)=j-1
        istack(jstack-1)=l
        l=i
      end if
    end if
  end do
  CONTAINS
!BL
  SUBROUTINE icomp_xchg(i,j)
  INTEGER(I4B), INTENT(INOUT) :: i,j
  INTEGER(I4B) :: swp
  if (arr(j) < arr(i)) then
    swp=i
    i=j
    j=swp
  end if
  END SUBROUTINE icomp_xchg
  END SUBROUTINE indexx_char

end module
