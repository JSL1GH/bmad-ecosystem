!+
! Subroutine check_ring_controls (ring, exit_on_error)
!
! Subroutine to check if the control links in a ring structure are valid
!
! Modules needed:
!   use bmad
!
! Input:
!   ring -- Ring_struct: Ring to check
!   exit_on_error -- Logical: Exit if an error detected?
!-

!$Id$
!$Log$
!Revision 1.7  2003/01/27 14:40:31  dcs
!bmad_version = 56
!
!Revision 1.6  2002/11/04 16:48:58  dcs
!Null_ele$ add
!
!Revision 1.5  2002/06/13 14:54:23  dcs
!Interfaced with FPP/PTC
!
!Revision 1.4  2002/02/23 20:32:12  dcs
!Double/Single Real toggle added
!
!Revision 1.3  2002/01/08 21:44:37  dcs
!Aligned with VMS version  -- DCS
!
!Revision 1.2  2001/09/27 18:31:49  rwh24
!UNIX compatibility updates
!

#include "CESR_platform.inc"


subroutine check_ring_controls (ring, exit_on_error)

  use bmad_struct
  use bmad_interface

  implicit none
       
  type (ring_struct), target :: ring
  type (ele_struct), pointer :: ele, ele2

  integer i_t, j, i_t2, ix, t_type, t2_type, n, cc(100), i
  integer n_count, ix1, ix2, ii

  logical exit_on_error, found_err, good_control(10,10)

! check energy

  if (abs(ring%param%beam_energy-1d9*ring%param%energy) > &
                                             1e-5*ring%param%beam_energy) then
    print *, 'ERROR IN CHECK_RING_CONTROLS:'
    print *, '      RING%PARAM%ENERGY AND RING%PARAM%BEAM_ENERGY DO NOT MATCH'
    print *, '      ', ring%param%energy, ring%param%beam_energy 
    call err_exit
  endif

  if (any(ring%ele_(:)%key == linac_rf_cavity$) .and. &
                          ring%param%lattice_type /= linac_lattice$) then
    print *, 'ERROR IN CHECK_RING_CONTROLS: THERE IS A LINAC_RF_CAVITY BUT THE'
    print *, '      LATTICE_TYPE IS NOT SET TO LINAC_LATTICE!'
  endif

!

  good_control = .false.
  good_control(group_lord$, (/ group_lord$, overlay_lord$, super_lord$, &
                                            free$, overlay_slave$ /)) = .true.
  good_control(overlay_lord$, (/ overlay_lord$, &
           overlay_slave$, super_lord$ /)) = .true.
  good_control(super_lord$, (/ super_slave$ /)) = .true.

  found_err = .false.
             
! loop over all elements

  do i_t = 1, ring%n_ele_max

    ele => ring%ele_(i_t)
    t_type = ele%control_type

! check that element is in correct part of the ele_(:) array

    if (ele%key == null_ele$ .and. i_t > ring%n_ele_ring) cycle      

    if (i_t > ring%n_ele_ring) then
      if (t_type == free$ .or. t_type == super_slave$ .or. &
          t_type == overlay_slave$) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: ELEMENT: ', ele%name
        print *, '      WHICH IS A: ', control_name(t_type)
        print *, '      IS *NOT* IN THE REGULAR PART OF RING LIST AT', i_t
        found_err = .true.
      endif                                             
    else                                                         
      if (t_type == super_lord$ .or. t_type == overlay_lord$ .or. &
          t_type == group_lord$) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: ELEMENT: ', ele%name
        print *, '      WHICH IS A: ', control_name(t_type)
        print *, '      IS IN THE REGULAR PART OF RING LIST AT', i_t
        found_err = .true.
      endif
    endif

    if (.not. any( (/ free$, super_slave$, overlay_slave$, &
                    super_lord$, overlay_lord$, group_lord$ /) == t_type)) then
      print *, 'ERROR IN CHECK_RING_CONTROLS: ELEMENT: ', ele%name
      print *, '      HAS UNKNOWN CONTROL INDEX: ', t_type
      found_err = .true.
    endif

    if (ele%n_slave /= ele%ix2_slave - ele%ix1_slave + 1) then
      print *, 'ERROR IN CHECK_RING_CONTROLS: LORD: ', ele%name, i_t
      print *, '      HAS SLAVE NUMBER MISMATCH:', &
                                  ele%n_slave, ele%ix1_slave, ele%ix2_slave
      found_err = .true.
      cycle
    endif

    if (ele%n_lord /= ele%ic2_lord - ele%ic1_lord + 1) then
      print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele%name, i_t
      print *, '      HAS LORD NUMBER MISMATCH:', &
                                  ele%n_lord, ele%ic1_lord, ele%ic2_lord
      found_err = .true.
      cycle
    endif

    if (t_type == overlay_slave$ .and. ele%n_lord == 0) then
      print *, 'ERROR IN CHECK_RING_CONTROLS: OVERLAY_SLAVE: ', ele%name, i_t
      print *, '      DOES HAS ZERO LORDS'
      found_err = .true.
    endif

    if (t_type == super_slave$ .and. ele%n_lord == 0) then
      print *, 'ERROR IN CHECK_RING_CONTROLS: OVERLAY_SLAVE: ', ele%name, i_t
      print *, '      DOES HAS ZERO LORDS'
      found_err = .true.
    endif

! check that super_lord elements have their slaves in the correct order

    if (t_type == super_lord$) then
      do i = ele%ix1_slave+1, ele%ix2_slave
        ix1 = ring%control_(i-1)%ix_slave
        ix2 = ring%control_(i)%ix_slave
        if (ix2 > ix1) then
          do ii = ix1+1, ix2-1
            if (ring%ele_(ii)%value(l$) /= 0) goto 9000   ! error
          enddo
        elseif (ix2 < ix1) then
          do ii = ix1+1, ring%n_ele_ring
            if (ring%ele_(ii)%value(l$) /= 0) goto 9000   ! error
          enddo
          do ii = 1, ix2-1            
            if (ring%ele_(ii)%value(l$) /= 0) goto 9000   ! error
          enddo
        else
          print *, 'ERROR IN CHECK_RING_CONTROLS: DUPLICATE SUPER_SLAVES: ', &
                                                      ring%ele_(ix1)%name, ii
          print *, '      FOR SUPER_SLAVE: ', ele%name, i_t
          found_err = .true.
        endif
      enddo
    endif

! check slaves

    do j = ele%ix1_slave, ele%ix2_slave

      if (j < 1 .or. j > n_control_maxx) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: LORD: ', ele%name, i_t
        print *, '      HAS IX_SLAVE INDEX OUT OF BOUNDS:', &
                                  ele%ix1_slave, ele%ix2_slave
        found_err = .true.
      endif

      if (ring%control_(j)%ix_lord /= i_t) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: LORD: ', ele%name, i_t
        print *, '      HAS A %IX_LORD POINTER MISMATCH:', &
                                                 ring%control_(j)%ix_lord
        print *, '      AT:', j
        found_err = .true.
      endif

      i_t2 = ring%control_(j)%ix_slave

      if (i_t2 < 1 .or. i_t2 > ring%n_ele_max) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: LORD: ', ele%name, i_t
        print *, '      HAS A SLAVE INDEX OUT OF RANGE:', i_t2
        print *, '      AT:', j
        found_err = .true.
        cycle
      endif

      ele2 => ring%ele_(i_t2)  
      t2_type = ele2%control_type      

      if (.not. good_control(t_type, t2_type) .and. &
                        ring%control_(j)%ix_attrib /= l$) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: LORD: ', ele%name, i_t
        print *, '      WHICH IS A: ', control_name(t_type)
        print *, '      HAS A SLAVE: ', ele2%name, i_t2
        print *, '      WHICH IS A: ', control_name(t2_type)
        found_err = .true.
      endif

      if (t_type /= group_lord$) then
        n = ele2%ic2_lord - ele2%ic1_lord + 1
        cc(1:n) = (/ (ring%ic_(i), i = ele2%ic1_lord, ele2%ic2_lord) /)
        if (.not. any(ring%control_(cc(1:n))%ix_lord == i_t)) then
          print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele2%name, i_t2
          print *, '      WHICH IS A: ', control_name(t2_type)
          print *, '      DOES NOT HAVE A POINTER TO ITS LORD: ', ele%name, i_t
          found_err = .true.
        endif
      endif

    enddo      

! check lords

    do ix = ele%ic1_lord, ele%ic2_lord

      if (ix < 1 .or. ix > n_control_maxx) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele%name, i_t
        print *, '      HAS IC_LORD INDEX OUT OF BOUNDS:', &
                                  ele%ic1_lord, ele%ic2_lord
        found_err = .true.
      endif

      j = ring%ic_(ix)

      if (j < 1 .or. j > n_control_maxx) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele%name, i_t
        print *, '      HAS IC_ INDEX OUT OF BOUNDS:', ix, j
        found_err = .true.
      endif
          
      i_t2 = ring%control_(j)%ix_lord

      if (i_t2 < 1 .or. i_t2 > n_ele_maxx) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele%name, i_t
        print *, '      HAS A LORD INDEX OUT OF RANGE:', ix, j, i_t2
        found_err = .true.
        cycle
      endif

      if (ring%control_(j)%ix_slave /= i_t) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele%name, i_t
        print *, '      HAS A %IX_SLAVE POINTER MISMATCH:', &
                                                 ring%control_(j)%ix_slave
          print *, '      AT:', ix, j
        found_err = .true.
      endif

      ele2 => ring%ele_(i_t2)
      t2_type = ele2%control_type

      if (.not. good_control(t2_type, t_type)) then
        print *, 'ERROR IN CHECK_RING_CONTROLS: SLAVE: ', ele%name, i_t
        print *, '      WHICH IS A: ', control_name(t_type)
        print *, '      HAS A LORD: ', ele2%name, i_t2
        print *, '      WHICH IS A: ', control_name(t2_type)
        found_err = .true.
      endif

    enddo

  enddo

  if (found_err .and. exit_on_error) call err_exit
  return

!---------------------------------
! super_lord error

9000 continue

  print *, 'ERROR IN CHECK_RING_CONTROLS: SUPER_SLAVES: ', &
                                ring%ele_(ix1)%name, ring%ele_(ix2)%name
  print *, '      NOT IN CORRECT ORDER FOR SUPER_LORD: ', ele%name, i_t

  if (exit_on_error) call err_exit

end subroutine
