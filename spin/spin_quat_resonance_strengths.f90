!+
! Subroutine spin_quat_resonance_strengths (orb_evec, spin_q, xi_quat)
!
! Routine to calculate for linear spin/orbit resonances the resonance strength from the 
! quaternion spin map and a particular eigen mode.
!
! Note: This routine will not be accurate unless the machine is at a sum or difference resonance.
! Also see: spin_mat8_resonance_strengths.
!
! Input:
!   orb_evec(6)       -- complex(rp): Orbital eigenvector.
!   spin_q(0:3,0:6)   -- real(rp): First order spin map.
!
! Output:
!   xi_quat(2)        -- real(rp): Resonance strengths for sum and difference resonances.
!-

subroutine spin_quat_resonance_strengths (orb_evec, spin_q, xi_quat)

use sim_utils

implicit none

real(rp) spin_q(0:3,0:6), xi_quat(2), nn0(3)
complex(rp) orb_evec(6), qv(0:3), qv2(0:3), np(0:3), nm(0:3)

integer k

!

nn0 = spin_q(1:3,0)
nn0 = nn0 / norm2(nn0)

np(0) = 0.5_rp
np(1:3) = i_imag * nn0 / 2
nm(0) = 0.5_rp
nm(1:3) = -i_imag * nn0 / 2

do k = 0, 3
  qv(k)  = sum(orb_evec(:) * spin_q(k,1:6))
  qv2(k) = sum(conjg(orb_evec(:)) * spin_q(k,1:6))
enddo

xi_quat(1) = sqrt(2.0) * norm2(abs(quat_mul(np, qv, nm))) / pi
xi_quat(2) = sqrt(2.0) * norm2(abs(quat_mul(np, qv2, nm))) / pi

end subroutine
