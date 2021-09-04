program photon_test

use photon_init_mod
use photon_init_spline_mod

implicit none

type (lat_struct) lat
type (coord_struct) orbit, orb_start, orb_end
real(rp) E_rel, prob
integer i

!

open (1, file = 'output.now', recl = 200)

!

call bmad_parser ('grid.bmad', lat)

call init_coord (orb_start, vec0$, lat%ele(0), downstream_end$)
orb_start%vec(1) = 1d-4
orb_start%vec(3) = 2d-4
call track1 (orb_start, lat%ele(1), lat%param, orb_end)

write (1, '(a, 6f12.8)') '"Grid-orb" ABS 1e-12', orb_end%vec

!

do i = 0, 5
  E_rel = bend_photon_e_rel_init(i / 5.0_rp)
  write (1, '(a, i0, a, f16.10)') '"E_rel_', i, '" ABS 0', E_rel 
enddo

call ran_engine ('quasi')
call bend_photon_init (0.10_rp, 0.02_rp, 1d4, orbit, 1.0d3, 1.1d3)
prob = bend_photon_energy_integ_prob(1.0d3, 0.10_rp, 1d4)
write (1, '(a, 6f14.8)') '"Photon_vec"   ABS 0', orbit%vec
write (1, '(a, 6f14.4)') '"Photon_p0c"   ABS 0', orbit%p0c
write (1, '(a, 6f14.8)') '"Photon_field" ABS 0', orbit%field
write (1, '(a, 6f14.8)') '"Photon_prob"  ABS 0', prob

call bend_photon_init (0.10_rp, 0.02_rp, 1d4, orbit, 0d0, 0d0)
write (1, '(a, 6f14.8)') '"Photon2_vec"   ABS 0', orbit%vec
write (1, '(a, 6f14.4)') '"Photon2_p0c"   ABS 0', orbit%p0c
write (1, '(a, 6f14.8)') '"Photon2_field" ABS 0', orbit%field

end program
