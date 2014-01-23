!+
! Subroutine track1_symp_lie_ptc (start_orb, ele, param, end_orb)
!
! Particle tracking through a single element using a hamiltonian
! and a symplectic integrator. This uses Etienne's PTC code. For a 
! "native" BMAD version see track1_symnp_lie_bmad.
!
! Modules Needed:
!   use bmad
!
! Input:
!   start_orb  -- Coord_struct: Starting position
!   ele    -- Ele_struct: Element
!   param  -- lat_param_struct:
!
! Output:
!   end_orb   -- Coord_struct: End position
!-

subroutine track1_symp_lie_ptc (start_orb, ele, param, end_orb)

use ptc_interface_mod, except_dummy => track1_symp_lie_ptc
use s_tracking, only: DEFAULT, alloc_fibre
use mad_like, only: fibre, kill, ptc_track => track

implicit none

type (coord_struct) :: start_orb, start2_orb
type (coord_struct) :: end_orb
type (ele_struct) :: ele, drift_ele
type (lat_param_struct) :: param
type (fibre), pointer :: fibre_ele

real(dp) re(6), beta0

character(20) :: r_name = 'track1_symp_lie_ptc'

! call the PTC routines to track through the fibre.

beta0 = ele%value(p0c_start$) / ele%value(e_tot_start$)
call vec_bmad_to_ptc (start_orb%vec, beta0, re)

! Track a drift if using hard edge model

if (tracking_uses_end_drifts(ele)) then
  call create_hard_edge_drift (ele, upstream_end$, drift_ele)
  call ele_to_fibre (drift_ele, fibre_ele, param, .true.)
  call ptc_track (fibre_ele, re, DEFAULT)  ! "track" in PTC
endif  

! track element

start2_orb = start_orb
end_orb = start_orb

call ele_to_fibre (ele, fibre_ele, param, .true.)
call ptc_track (fibre_ele, re, DEFAULT)  ! "track" in PTC

if (tracking_uses_end_drifts(ele)) then
  call create_hard_edge_drift (ele, downstream_end$, drift_ele)
  call ele_to_fibre (drift_ele, fibre_ele, param, .true.)
  call ptc_track (fibre_ele, re, DEFAULT)  ! "track" in PTC
endif  

beta0 = ele%value(p0c$) / ele%value(e_tot$)
call vec_ptc_to_bmad (re, beta0, end_orb%vec)

! 

if (ele%value(p0c$) /= ele%value(p0c_start$) .or. start2_orb%vec(6) /= end_orb%vec(6)) then
  call convert_pc_to (ele%value(p0c$) * (1 + end_orb%vec(6)), param%particle, beta = end_orb%beta)
endif

end_orb%s = ele%s
end_orb%p0c = ele%value(p0c$)

end_orb%t = start2_orb%t + ele%value(delta_ref_time$) + &
                          start2_orb%vec(5) / (start2_orb%beta * c_light) - end_orb%vec(5) / (end_orb%beta * c_light)

end subroutine
