!+
! Subroutine type2_twiss (ele, lines, n_lines, frequency_units, compact_format)
!
! Subroutine to encode Twiss information in an element in an array of strings.
! See also the subroutine: type_twiss.
!
! Modules needed:
!   use bmad
!
! Input:
!   ele             -- Ele_struct: Element containing the Twiss parameters.
!   frequency_units -- Integer, optional: Units for phi:
!                       = radians$  => Type Twiss, use radians for phi (Default).
!                       = degrees$  => Type Twiss, use degrees for phi.
!                       = cycles$   => Type Twiss, use cycles (1 = 2pi) units.
!   compact_format  -- Logical, optional: If present and True then output looks like:
!
!           Beta     Alpha     Gamma       Phi        Eta       Etap
!            (m)       (-)     (1/m)     (rad)        (m)        (-)
!  X:    29.8929    -2.953     0.325   11.9116     1.4442     0.1347
!  Y:     1.3982     0.015     0.715   11.6300    -0.0006     0.0033     
!
! Else the default is for a format like:
!                                A                   B
! Beta (m)              29.89292748          1.39825638
! Alpha (-)             -2.95314539          0.01539874
! Gamma (1/m)            0.32495843          0.71532874
! Phi (rad)             11.91163456         11.63002398  
! Eta (m)                1.44429482         -0.00066948
! Etap (-)               0.13477010          0.00337943
!
! Output:
!   lines(:)     -- Character(*): Character array to hold the output.
!   n_lines      -- Number of lines used
!-

subroutine type2_twiss (ele, lines, n_lines, frequency_units, compact_format)

use bmad_interface, except_dummy => type2_twiss

implicit none

type (ele_struct)  ele

integer, optional :: frequency_units
integer n_lines

real(rp) coef

character(*) lines(:)
character(80) fmt, str, freq_str

logical, optional :: compact_format

! Encode twiss info

select case (integer_option(radians$, frequency_units))
case (0)
  n_lines = 0
  return
case (radians$)
  str = '           (m)       (-)     (1/m)     (rad)'
  fmt = '(a, f11.4, 2f10.3, f10.4, 2f11.4)'
  freq_str = 'Phi (rad)'
  coef = 1
case (degrees$)
  str = '           (m)       (-)     (1/m)     (deg)'
  fmt = '(a, f11.4, 2f10.3, f10.2, 2f11.4)'
  freq_str = 'Phi (deg)'
  coef = 180 / pi
case (cycles$)
  str = '           (m)       (-)     (1/m)  (cycles)'
  fmt = '(a, f11.4, 2f10.3, f10.4, 2f11.4)'
  freq_str = 'Phi (cycles)'
  coef = 1 / twopi                   
case default
 lines(1) = 'ERROR IN TYPE2_TWISS: BAD "FREQUENCY_UNITS"'
 n_lines = 1
 return
end select

!

if (logic_option (.false., compact_format)) then
  write (lines(1), '(10x, a)')  &
            'Beta     Alpha     Gamma       Phi        Eta       Etap'
  lines(2) = trim(str) // '        (m)        (-)'
  write (lines(3), fmt) ' X:', ele%a%beta,  &
          ele%a%alpha, ele%a%gamma, coef*ele%a%phi, ele%a%eta, ele%a%etap
  write (lines(4), fmt) ' Y:', ele%b%beta,  &
          ele%b%alpha, ele%b%gamma, coef*ele%b%phi, ele%b%eta, ele%b%etap
  n_lines = 4

else
  write (lines(7), '(9x, 4(19x, a))') 'X', 'Y','A','B'  

  write (lines(1), '(12x, 2(14x, a))') 'A', 'B'
  write (lines(2), '(2x, a12, 2a)') 'Beta (m)    ', v(ele%a%beta), v(ele%b%beta)
  write (lines(3), '(2x, a12, 2a)') 'Alpha (-)   ', v(ele%a%alpha), v(ele%b%alpha)
  write (lines(4), '(2x, a12, 2a)') 'Gamma (1/m) ', v(ele%a%gamma), v(ele%b%gamma)
  write (lines(5), '(2x, a12, 2a, 12x, a, 3(14x, a))') freq_str, v(ele%a%phi*coef), v(ele%b%phi*coef), 'X', 'Y', 'Z'
  write (lines(6), '(2x, a12, 5a)') 'Eta (m)     ', v(ele%a%eta),  v(ele%b%eta),  v(ele%x%eta),  v(ele%y%eta),  v(ele%z%eta)
  write (lines(7), '(2x, a12, 5a)') 'Etap (-)    ', v(ele%a%etap), v(ele%b%etap), v(ele%x%etap), v(ele%y%etap), v(ele%z%etap)
  n_lines = 7
endif

!--------------------------------------------
contains

function v(val) result (str)
real(rp) val
character(15) str

!

if (abs(val) < 9999) then
  write (str, '(f15.8)') val
else
  write (str, '(es15.5)') val
endif

end function v

end subroutine
