module xraylib

use iso_c_binding

type crystal_struct
  real volume
end type

type compounddatanist
  integer nElements, elements(1)
  real massFractions(1), density
end type

real, parameter :: r_e = 0

!------------------------------------------------------------------

contains

function crystal_getcrystal(material) result (cryst)
character(*) material
type (crystal_struct), pointer :: cryst
nullify(cryst)
end function

function crystal_f_h_structurefactor (cryst, E_kev, i, j, k, debye, angle) result (f_h)
type (crystal_struct) cryst
real(c_float) E_kev, debye, angle
integer i, j, k
complex(8) f0_tot
f_h = 0
end function

function atomicnumbertosymbol(n) result (sym)
integer n
character(16) sym
sym = ''
end function

function atomicweight(n) result (weight)
integer n
real(c_float) weight
weight = 0
end function

function atomicdensity(n) result (density)
integer n
real(c_float) density
density = 0
end function

subroutine atomic_factors (n, E_kev, q, debye, f0, fp, fpp) 
integer n
real(c_float) E_kev, q, debye, f0, fp, fpp
end subroutine

function elementdensity(n) result (density)
integer n
real(c_float) density
density = 0
end function

function GetCompoundDataNISTByIndex(n) result (compound)
integer n
type (compoundDataNIST), pointer :: compound
nullify (compound)
end function

function Crystal_dSpacing(cryst, hkl1, hkl2, hkl3) result (spacing)
type (crystal_struct) cryst
integer hkl1, hkl2, hkl3
real spacing
spacing = 0
end function


end module
