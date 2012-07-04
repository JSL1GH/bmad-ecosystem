module fortran_cpp_utils

use precision_def
use, intrinsic :: iso_c_binding

type c_dummy_struct
  real(rp) dummy
end type

interface vec2fvec
  module procedure bool_vec2fvec
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function fscaler2scaler (f_scaler, n) result (c_scaler)
!
! Overloaded function to translate a scaler from Fortran form to C form.
! Overloads:
!   bool_fscaler2scaler (bool_f_scaler, n) result (bool_c_scaler)
!
! Input:
!   bool_f_scaler  -- Logical: Input scaler.
!   n              -- Integer: 0 if actual scaler is not allocated, 1 otherwise.
!
! Output:
!   bool_c_scaler  -- Logical(c_bool): Output scaler
!-

interface fscaler2scaler
  module procedure bool_fscaler2scaler
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function fvec2vec (f_vec, n) result (c_vec)
!
! Overloaded function to translate a vector from Fortran form to C form.
! Overloads:
!   bool_fvec2vec (bool_f_vec, n) result (bool_c_vec)
!
! Input:
!   bool_f_vec(:)  -- Logical: Input vector
!
! Output:
!   bool_c_vec(:)  -- Logical(c_bool): Output array 
!-

interface fvec2vec
  module procedure real_fvec2vec
  module procedure int_fvec2vec
  module procedure complx_fvec2vec
  module procedure bool_fvec2vec
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function mat2vec (mat, n) result (vec)
!
! Overloaded function to take a matrix and turn it into an array in 
! C standard row-major order:
!   vec(n2*(i-1) + j) = mat(i,j)
! where n2 = size(mat,2).
! This is used for passing matrices to C++ routines.
!
! Overloaded functions:
!   real_mat2vec   (real_mat)   result (real_vec)
!   int_mat2vec    (int_mat)    result (int_vec)
!   complx_mat2vec (complx_mat) result (complx_vec)
!   bool_mat2vec   (bool_mat)   result (bool_vec)
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   real_mat(:,:)   -- Real(rp): Input matrix
!   int_mat(:,:)    -- Integer: Input matrix
!   complx_mat(:,:) -- Çomplex(rp): Input matrix
!   bool_mat(:,:)   -- Logical: Input matrix
!   n               -- Integer: Number of elements. Normally this is size(mat). 
!                        Set to 0 if actual mat arg is not allocated.
!
! Output:
!   real_vec(*)   -- Real(c_double): Output array 
!   int_vec(*)    -- Integer(c_int): Output array 
!   complx_vec(*) -- complex(c_double_complex): Output array 
!   bool_vec(*)   -- Logical(c_bool): Output array 
!-

interface mat2vec
  module procedure real_mat2vec
  module procedure int_mat2vec
  module procedure cmplx_mat2vec
  module procedure bool_mat2vec
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function tensor2vec (tensor, n) result (vec)
!
! Function to take a tensor and turn it into an array in 
! C standard row-major order::
!   vec(n3*n2*(i-1) + n3*(j - 1) + k) = tensor(i,j,k)
! where n2 = size(tensor,2).
! This is used for passing tensorrices to C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   tensor(:,:)     -- Real(rp): Input tensorrix
!   n               -- Integer: Number of elements. Normally this 
!                        is size(tensor), 0 if actual tensor arg is not allocated.
!
! Output:
!   vec(*)   -- Real(c_double): Output array 
!-

interface tensor2vec
  module procedure real_tensor2vec
  module procedure int_tensor2vec
  module procedure cmplx_tensor2vec
  module procedure bool_tensor2vec
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine vec2mat (vec, mat)
!
! Overloaded routine to take a an array in C standard row-major 
! order and turn it into a matrix:
!   mat(i,j) = vec(n2*(i-1) + j) 
! This is used for getting matrices from C++ routines.
!
! Overloaded functions:
!   real_vec2mat
!   int_vec2mat
!   cmplx_vec2mat
!   bool_vec2mat
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- Real(c_double): Input array.
!   n1       -- Integer: Size of first mat index.
!   n2       -- Integer: Size of second mat index.
!
! Output:
!   mat(:,:)  -- Real(rp): Output matrix
!-

interface vec2mat
  module procedure real_vec2mat
  module procedure int_vec2mat
  module procedure cmplx_vec2mat
  module procedure bool_vec2mat
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine vec2tensor (vec, tensor)
!
! Routine to take a an array in C standard row-major 
! order and turn it into a tensor:
!   tensor(i,j) = vec(n3*n2*(i-1) + n3*j + k) 
! This is used for getting tensorrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- Real(c_double): Input array.
!   n1       -- Integer: Size of first tensor index.
!   n2       -- Integer: Size of second tensor index.
!   n3       -- Integer: Size of third tensor index.
!
! Output:
!   tensor(n1,n2,n3)  -- Real(rp): Output tensor.
!-

interface vec2tensor
  module procedure real_vec2tensor
  module procedure int_vec2tensor
  module procedure cmplx_vec2tensor
  module procedure bool_vec2tensor
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine remove_null_in_string 
! 
! This is an overloaded routine for:
!   remove_null_in_string_char (str_char, str_out)
!   remove_null_in_string_arr (str_arr, str_out)
!
! Routine to convert a null character in a string to a blank.
! All characters thereafter are similarly converted.
! This is useful for converting a C style string to Fortran.
! If there is no null character then str_out = str_in.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   str_char   -- Character(*): Input string with null character.
!   str_arr(*) -- Character(1): Input array of null terminated character(1) characters.
!
! Output:
!   str_out -- Character(*): String with null character converted.
!-

interface remove_null_in_string
  module procedure remove_null_in_string_char
  module procedure remove_null_in_string_arr
end interface

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function f_logic (logic) result (f_log)
!
! Function to convert from a C logical to a Fortran logical.
! This function overloads:
!   f_logic_int  (int_logic) result (f_log)
!   f_logic_bool (bool_logic) result (f_log)
!
! Modules needed:
!   use fortran_cpp_utils
!
! Input:
!   int_logic  -- Integer: C logical.
!   bool_logic -- Logical(c_bool): C logical.
!
! Output:
!   f_log -- Logical: Fortran logical.
!-

interface f_logic
  module procedure f_logic_bool
  module procedure f_logic_int
end interface

interface c_logic
  module procedure c_logic1
  module procedure c_logic_vec
end interface

contains

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function c_logic1 (logic) result (c_log)
!
! Function to convert from a fortran logical to a C logical.
! See c_logic for more details.
!
! Modules needed:
!   use fortran_cpp_utils
!
! Input:
!   logic -- Logical: Fortran logical.
!
! Output:
!   c_log -- Integer: C logical.
!-

pure function c_logic1 (logic) result (c_log)

implicit none

logical, intent(in) :: logic
logical(c_bool) c_log

!

if (logic) then
  c_log = 1
else
  c_log = 0
endif

end function c_logic1

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function c_logic_vec (logic) result (c_log)
!
! Function to convert from a fortran logical to a C logical.
! See c_logic for more details.
!
! Modules needed:
!   use fortran_cpp_utils
!
! Input:
!   logic -- Logical: Fortran logical.
!
! Output:
!   c_log -- Integer: C logical.
!-

pure function c_logic_vec (logic) result (c_log)

implicit none

logical, intent(in) :: logic(:)
logical(c_bool) c_log(size(logic))
integer i

!

do i = 1, size(logic)
  c_log(i) = c_logic1(logic(i))
enddo

end function c_logic_vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function f_logic_int (logic) result (f_log)
!
! Function to convert from a C logical to a Fortran logical.
! This function is overloaded by f_logic.
! See f_logic for more details.
!-

function f_logic_int (logic) result (f_log)

implicit none

integer, intent(in) :: logic
logical f_log

!

if (logic == 0) then
  f_log = .false.
else
  f_log = .true.
endif

end function f_logic_int

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function f_logic_bool (logic) result (f_log)
!
! Function to convert from a C logical to a Fortran logical.
! This function is overloaded by f_logic.
! See f_logic for more details.
!-

function f_logic_bool (logic) result (f_log)

implicit none

logical(c_bool), intent(in) :: logic
logical f_log
integer int_logic

interface
  subroutine bool_to_int (logic, int_logic) bind(c)
    import c_bool, c_int
    logical(c_bool) logic
    integer(c_int) int_logic
  end subroutine
end interface

!

call bool_to_int (logic, int_logic)

if (int_logic == 0) then
  f_log = .false.
else
  f_log = .true.
endif

end function f_logic_bool

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function r_size (ptr) result (this_size)
!
! Function to return the size of a real pointer.
! If the pointer is not associated then 0 is returned.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   ptr(:) -- Real(rp), pointer: Pointer to an array.
!
! Output:
!   this_size -- Integer: Size of array. 0 if not associated.
!-

function r_size (ptr) result (this_size)

implicit none

real(rp), pointer :: ptr(:)
integer this_size

this_size = 0
if (associated(ptr)) this_size = size(ptr)

end function r_size

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function i_size (ptr) result (this_size)
!
! Function to return the size of an integer pointer.
! If the pointer is not associated then 0 is returned.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   ptr(:) -- Integer, pointer: Pointer to an array.
!
! Output:
!   this_size -- Integer: Size of array. 0 if not associated.
!-


function i_size (ptr) result (this_size)

implicit none

integer, pointer :: ptr(:)
integer this_size

this_size = 0
if (associated(ptr)) this_size = size(ptr)

end function i_size

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine remove_null_in_string_arr (str_in, str_out)
! 
! This routine overloaded by:
!        remove_null_in_string
! See remove_null_in_string for more details.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   str_in(*) -- Character(1): Input character array. Null terminated.
!
! Output:
!   str_out -- Character(*): String with null character converted.
!-

subroutine remove_null_in_string_arr (str_in, str_out)

implicit none

character(1) str_in(*)
character(*) str_out
integer ix

!

str_out = ''
do ix = 1, 32000
  if (str_in(ix) == char(0)) return
  str_out(ix:ix) = str_in(ix)
enddo

end subroutine remove_null_in_string_arr

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine remove_null_in_string_char (str_in, str_out)
! 
! This routine overloaded by:
!        remove_null_in_string
! See remove_null_in_string for more details.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   str_in -- Character(*): Input string with null character.
!
! Output:
!   str_out -- Character(*): String with null character converted.
!-

subroutine remove_null_in_string_char (str_in, str_out)

implicit none

character(*) str_in, str_out
integer ix

!

ix = index(str_in, char(0))
if (ix == 0) then
  str_out = str_in
else
  str_out = str_in(1:ix-1)
endif

end subroutine remove_null_in_string_char

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine to_c_str (f_string, c_string)
!
! Subroutine to append a null (0) character at the end of a string (trimmed
! of trailing blanks) so it will look like a C character array. 
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   f_string   -- Character(*): Input character string
!
! Output:
!   c_string(*) -- Character(kind=c_char): String with a null put just after the last
!                    non-blank character.
!-

subroutine to_c_str (f_string, c_string)

implicit none

character(*) f_string
character(kind=c_char) c_string(*)
integer i

!

do i = 1, len_trim(f_string)
  c_string(i) = f_string(i:i)
enddo

c_string(i) = char(0)

end subroutine to_c_str

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine to_f_str (c_string, f_string)
!
! Subroutine to append a null (0) character at the end of a string (trimmed
! of trailing blanks) so it will look like a C character array. 
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   c_string(*) -- Character(kind=c_char): C-style string.
!
! Output:
!   f_string -- Character(*): Output character string.
!-

subroutine to_f_str (c_string, f_string)

implicit none

character(*) f_string
character(kind=c_char) c_string(*)
integer i

!

do i = 1, len(f_string)
  if (c_string(i) == char(0)) then
    f_string(i:) = ''
    return
  endif
  f_string(i:i) = c_string(i)
enddo

end subroutine to_f_str

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function bool_fscaler2scaler (f_scaler, n) result (c_scaler)
!
! Function transform from Fortran to C.
! See fscaler2scaler for more details
!-

function bool_fscaler2scaler (f_scaler, n) result (c_scaler)

implicit none

integer n, i
logical f_scaler
logical(c_bool) c_scaler

c_scaler = 0
if (n == 0) return
c_scaler = c_logic(f_scaler)

end function bool_fscaler2scaler

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function real_fvec2vec (f_vec, n) result (c_vec)
!
! Function transform from Fortran to C.
! See fvec2vec for more details
!-

function real_fvec2vec (f_vec, n) result (c_vec)

implicit none

integer n, i
real(rp) f_vec(:)
real(c_double) c_vec(n)

forall (i = 1:n) c_vec(i) = f_vec(i)

end function real_fvec2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function int_fvec2vec (f_vec, n) result (c_vec)
!
! Function transform from Fortran to C.
! See fvec2vec for more details
!-

function int_fvec2vec (f_vec, n) result (c_vec)

implicit none

integer n, i
integer f_vec(:)
integer(c_int) c_vec(n)

forall (i = 1:n) c_vec(i) = f_vec(i)
 
end function int_fvec2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function complx_fvec2vec (f_vec, n) result (c_vec)
!
! Function transform from Fortran to C.
! See fvec2vec for more details
!-

function complx_fvec2vec (f_vec, n) result (c_vec)

implicit none

integer n, i
complex(rp) f_vec(:)
complex(c_double_complex) c_vec(n)

forall (i = 1:n) c_vec(i) = f_vec(i)
 
end function complx_fvec2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function bool_fvec2vec (f_vec, n) result (c_vec)
!
! Function transform from Fortran to C.
! See fvec2vec for more details
!-

function bool_fvec2vec (f_vec, n) result (c_vec)

implicit none

integer n, i
logical f_vec(:)
logical(c_bool) c_vec(n)

forall (i = 1:n) c_vec(i) = c_logic(f_vec(i))
 
end function bool_fvec2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function real_mat2vec (mat, n) result (vec)
!
! Function to take a matrix and turn it into an array:
!   vec(n2*(i-1) + j) = mat(i,j)
! See mat2vec for more details
!
! Input:
!   mat(:,:)  -- Real(rp): Input matrix
!
! Output:
!   vec(:)   -- Real(c_double): Output array 
!-

function real_mat2vec (mat, n) result (vec)

implicit none

integer n
real(rp) mat(:,:)
real(c_double) vec(n)
integer i, j, n1, n2

if (n == 0) return ! Real arg not allocated
n1 = size(mat, 1); n2 = size(mat, 2)
forall (i = 1:n1, j = 1:n2) vec(n2*(i-1) + j) = mat(i,j)
 
end function real_mat2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function int_mat2vec (mat, n) result (vec)
!
! Function to take a matrix and turn it into an array:
!   vec(n2*(i-1) + j) = mat(i,j)
! See mat2vec for more details
!
! Input:
!   mat(:,:)  -- integer: Input matrix
!
! Output:
!   vec(:)   -- integer(c_int): Output array 
!-

function int_mat2vec (mat, n) result (vec)

implicit none

integer n
integer mat(:,:)
integer(c_int) vec(n)
integer i, j, n1, n2

if (n == 0) return ! Real arg not allocated
n1 = size(mat, 1); n2 = size(mat, 2)
forall (i = 1:n1, j = 1:n2) vec(n2*(i-1) + j) = mat(i,j)
 
end function int_mat2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function bool_mat2vec (mat, n) result (vec)
!
! Function to take a matrix and turn it into an array:
!   vec(n2*(i-1) + j) = mat(i,j)
! See mat2vec for more details
!
! Input:
!   mat(:,:)  -- logical: Input matrix
!
! Output:
!   vec(:)   -- logical: Output array 
!-

function bool_mat2vec (mat, n) result (vec)

implicit none

integer n
logical mat(:,:)
logical(c_bool) vec(n)
integer i, j, n1, n2

if (n == 0) return ! Real arg not allocated

n1 = size(mat, 1); n2 = size(mat, 2)
do i = 1, n1
do j = 1, n2 
  vec(n2*(i-1) + j) = c_logic(mat(i,j))
enddo
enddo

end function bool_mat2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function cmplx_mat2vec (mat, n) result (vec)
!
! Function to take a matrix and turn it into an array:
!   vec(n2*(i-1) + j) = mat(i,j)
! See mat2vec for more details
!
! Input:
!   mat(:,:)  -- complex(rp): Input matrix
!
! Output:
!   vec(:)   -- complex(c_double_complex): Output array 
!-

function cmplx_mat2vec (mat, n) result (vec)

implicit none

integer n
complex(rp) mat(:,:)
complex(c_double_complex) vec(n)
integer i, j, n1, n2

if (n == 0) return ! Real arg not allocated
n1 = size(mat, 1); n2 = size(mat, 2)
forall (i = 1:n1, j = 1:n2) vec(n2*(i-1) + j) = mat(i,j)
 
end function cmplx_mat2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function real_tensor2vec (tensor, n) result (vec)
!
! Function to take a tensor and turn it into an array:
!   vec(n3*n2*(i-1) + n3*(j - 1) + k) = tensor(i,j, k)
! See tensor2vec for more details
!
! Input:
!   tensor(:,:,:)  -- Real(rp): Input tensorrix
!
! Output:
!   vec(:)   -- Real(c_double): Output array 
!-

function real_tensor2vec (tensor, n) result (vec)

implicit none

integer n
real(rp) tensor(:,:,:)
real(c_double) vec(n)
integer i, j, k, n1, n2, n3

if (n == 0) return ! Real arg not allocated
n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor, 3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) vec(n3*n2*(i-1) + n3*(j-1) + k) = tensor(i,j,k)
 
end function real_tensor2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function int_tensor2vec (tensor, n) result (vec)
!
! Function to take a tensor and turn it into an array:
!   vec(n3*n2*(i-1) + n3*(j - 1) + k) = tensor(i,j, k)
! See tensor2vec for more details
!
! Input:
!   tensor(:,:,:)  -- Integer: Input tensorrix
!
! Output:
!   vec(:)   -- Integer(c_int): Output array 
!-

function int_tensor2vec (tensor, n) result (vec)

implicit none

integer n
integer tensor(:,:,:)
integer(c_int) vec(n)
integer i, j, k, n1, n2, n3

if (n == 0) return ! Real arg not allocated
n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor, 3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) vec(n3*n2*(i-1) + n3*(j-1) + k) = tensor(i,j,k)
 
end function int_tensor2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function cmplx_tensor2vec (tensor, n) result (vec)
!
! Function to take a tensor and turn it into an array:
!   vec(n3*n2*(i-1) + n3*(j - 1) + k) = tensor(i,j, k)
! See tensor2vec for more details
!
! Input:
!   tensor(:,:,:)  -- complex(rp): Input tensorrix
!
! Output:
!   vec(:)   -- complex(c_double_complex): Output array 
!-

function cmplx_tensor2vec (tensor, n) result (vec)

implicit none

integer n
complex(rp) tensor(:,:,:)
complex(c_double_complex) vec(n)
integer i, j, k, n1, n2, n3

if (n == 0) return ! Real arg not allocated
n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor, 3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) vec(n3*n2*(i-1) + n3*(j-1) + k) = tensor(i,j,k)
 
end function cmplx_tensor2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Function bool_tensor2vec (tensor, n) result (vec)
!
! Function to take a tensor and turn it into an array:
!   vec(n3*n2*(i-1) + n3*(j - 1) + k) = tensor(i,j, k)
! See tensor2vec for more details
!
! Input:
!   tensor(:,:,:)  -- logical: Input tensorrix
!
! Output:
!   vec(:)   -- logical(c_bool): Output array 
!-

function bool_tensor2vec (tensor, n) result (vec)

implicit none

integer n
logical tensor(:,:,:)
logical(c_bool) vec(n)
integer i, j, k, n1, n2, n3

if (n == 0) return ! Real arg not allocated
n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor, 3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) vec(n3*n2*(i-1) + n3*(j-1) + k) = c_logic(tensor(i,j,k))
 
end function bool_tensor2vec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine bool_vec2fvec (c_vec, f_vec)
!
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   c_vec(*)   -- Logical(c_bool): Input array.
!
! Output:
!   f_vec(n1,n2)  -- Logical: Output f_vec
!-

subroutine bool_vec2fvec (c_vec, f_vec)

implicit none

integer i, j, n1, n2
logical(c_bool) c_vec(*)
logical f_vec(:)


do i = 1, size(f_vec)
  f_vec(i) = f_logic(c_vec(i))
enddo
 
end subroutine bool_vec2fvec

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine real_vec2mat (vec, mat)
!
! Subroutine to take a an array and turn it into a matrix:
!   mat(i,j) = vec(n2*(i-1) + j) 
! This is used for getting matrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- Real(c_double): Input array.
!
! Output:
!   mat(n1,n2)  -- Real(rp): Output matrix
!-

subroutine real_vec2mat (vec, mat)

implicit none

integer i, j, n1, n2
real(c_double) vec(*)
real(rp) mat(:,:)

n1 = size(mat, 1); n2 = size(mat, 2)
forall (i = 1:n1, j = 1:n2) mat(i,j) = vec(n2*(i-1) + j) 
 
end subroutine real_vec2mat

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine int_vec2mat (vec, mat)
!
! Subroutine to take a an array and turn it into a matrix:
!   mat(i,j) = vec(n2*(i-1) + j) 
! This is used for getting matrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- integer: Input array.
!
! Output:
!   mat(:,:)  -- integer: Output matrix
!-

subroutine int_vec2mat (vec, mat)

implicit none

integer i, j, n1, n2
integer(c_int) vec(*)
integer mat(:,:)

n1 = size(mat, 1); n2 = size(mat, 2)
forall (i = 1:n1, j = 1:n2) mat(i,j) = vec(n2*(i-1) + j) 
 
end subroutine int_vec2mat

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine bool_vec2mat (vec, mat)
!
! Subroutine to take a an array and turn it into a matrix:
!   mat(i,j) = vec(n2*(i-1) + j) 
! This is used for getting matrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- logical: Input array.
!
! Output:
!   mat(:,:)  -- logical: Output matrix
!-

subroutine bool_vec2mat (vec, mat)

implicit none

integer i, j, n1, n2
logical(c_bool) vec(*)
logical mat(:,:)

n1 = size(mat, 1); n2 = size(mat, 2)
do i = 1,n1
do j = 1,n2
  mat(i,j) = f_logic(vec(n2*(i-1) + j))
enddo
enddo

end subroutine bool_vec2mat

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine cmplx_vec2mat (vec, mat)
!
! Subroutine to take a an array and turn it into a matrix:
!   mat(i,j) = vec(n2*(i-1) + j) 
! This is used for getting matrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- complex(c_double_complex): Input array.
!
! Output:
!   mat(:,:)  -- complex(rp): Output matrix
!-

subroutine cmplx_vec2mat (vec, mat)

implicit none

integer i, j, n1, n2
complex(c_double_complex) vec(*)
complex(rp) mat(:,:)

n1 = size(mat, 1); n2 = size(mat, 2)
forall (i = 1:n1, j = 1:n2) mat(i,j) = vec(n2*(i-1) + j) 
 
end subroutine cmplx_vec2mat

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine real_vec2tensor (vec, tensor)
!
! Subroutine to take a an array and turn it into a tensor:
!   tensor(i,j) = vec(n3*n2*(i-1) + n3*j + k) 
! This is used for getting tensorrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- Real(rp): Input array.
!
! Output:
!   tensor(:,:,:)  -- Real(rp): Output tensor.
!-

subroutine real_vec2tensor (vec, tensor)

implicit none

integer i, j, k, n1, n2, n3
real(c_double) vec(*)
real(rp) tensor(:,:,:)

n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor,3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) tensor(i,j,k) = vec(n3*n2*(i-1) + n3*(j-1) + k) 
 
end subroutine real_vec2tensor

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine int_vec2tensor (vec, tensor)
!
! Subroutine to take a an array and turn it into a tensor:
!   tensor(i,j) = vec(n3*n2*(i-1) + n3*j + k) 
! This is used for getting tensorrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- integer: Input array.
!
! Output:
!   tensor(:,:,:)  -- integer(c_int): Output tensor.
!-

subroutine int_vec2tensor (vec, tensor)

implicit none

integer i, j, k, n1, n2, n3
integer(c_int) vec(*)
integer tensor(:,:,:)

n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor,3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) tensor(i,j,k) = vec(n3*n2*(i-1) + n3*(j-1) + k) 
 
end subroutine int_vec2tensor

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine cmplx_vec2tensor (vec, tensor)
!
! Subroutine to take a an array and turn it into a tensor:
!   tensor(i,j) = vec(n3*n2*(i-1) + n3*j + k) 
! This is used for getting tensorrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- complex(c_double_complex): Input array.
!
! Output:
!   tensor(:,:,:)  -- complex(rp): Output tensor.
!-

subroutine cmplx_vec2tensor (vec, tensor)

implicit none

integer i, j, k, n1, n2, n3
complex(c_double_complex) vec(*)
complex(rp) tensor(:,:,:)

n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor,3)
forall (i = 1:n1, j = 1:n2, k = 1:n3) tensor(i,j,k) = vec(n3*n2*(i-1) + n3*(j-1) + k) 
 
end subroutine cmplx_vec2tensor

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine bool_vec2tensor (vec, tensor)
!
! Subroutine to take a an array and turn it into a tensor:
!   tensor(i,j) = vec(n3*n2*(i-1) + n3*j + k) 
! This is used for getting tensorrices from C++ routines.
!
! Modules needed:
!  use fortran_cpp_utils
!
! Input:
!   vec(*)   -- logical(c_bool): Input array.
!
! Output:
!   tensor(:,:,:)  -- logical: Output tensor.
!-

subroutine bool_vec2tensor (vec, tensor)

implicit none

integer i, j, k, n1, n2, n3
logical(c_bool) vec(*)
logical tensor(:,:,:)

n1 = size(tensor, 1); n2 = size(tensor, 2); n3 = size(tensor,3)
do i = 1, n1
do j = 1, n2
do k = 1, n3
  tensor(i,j,k) = f_logic(vec(n3*n2*(i-1) + n3*(j-1) + k))
enddo
enddo
enddo

end subroutine bool_vec2tensor

!-----------------------------------------------------------------------------

end module
