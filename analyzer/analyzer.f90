program anaylzer

  use bmad
  use bmadz_interface
  use cesr_utils
  use cbar_mod
  use bookkeeper_mod
  use bsim_interface
  use mode3_mod

  implicit none

  interface
    subroutine psp(ring, co, traj, n_turns, istat2, ix_start, ix_end)
      use bmad_struct, only: lat_struct, coord_struct
      implicit none
      type (lat_struct) ring
      type (coord_struct) traj
      type (coord_struct), allocatable :: co(:)
      integer n_turns, i, pgopen, istat2
      integer ix_start, ix_end
    end subroutine
  end interface

  type (rad_int_all_ele_struct) rad_int
  type (lat_struct) ring_1, ring_2
  type (lat_struct), save :: ring, ring_two(-1:1)
  type (coord_struct), allocatable, save :: co(:), cot(:), co_high(:), co_low(:)
  type (coord_struct), allocatable, save :: co_off(:)
  type (coord_struct), allocatable, save :: co_electron(:)
  type (coord_struct) traj
  type (coord_struct) dorb
  type (normal_modes_struct) mode
  type (coord_struct) track_start

  integer pgopen, istat1, istat2
  integer i, j, k(6)/1,3,6,2,4,5/
  integer ix
  integer, allocatable :: track_meth(:)
  integer ke
  integer n/0/
  integer nd
  integer plot_flag/0/, last
  integer, parameter :: orbit$=1,beta$=2,cbar$=3,diff$=4, de_beta$=5
  integer, parameter :: eta$=6, de_cbar$=7, eta_prop$=8, rad_int$=9, sext$=10
  integer, parameter :: phase$=11, de_phase$=12, v15$=13, v16$=14
  integer ix_cache
  integer, allocatable :: n_ele(:)
  integer i_dim/4/
  integer ix_ele
  integer n_turns
  integer nargs, iargc
  integer n_all
  integer l
  integer ix_start/1/, ix_end/1/
  integer io_stat
  integer ncross, cross(1000)
  integer lun

  real*4, allocatable :: z(:), x(:), y(:), zz(:,:), xx(:,:), yy(:,:)
  real*4, allocatable :: zz_diff(:), xx_diff(:), yy_diff(:)

  real*4 width/7./, aspect/1.3/
  real*4 xmax/0./, ymax/0./, xmax0, ymax0
  real*4 xscale, yscale, x_low, y_low
  real*4 xa(4), za(4)
  real*4 xdet(1000), ydet(1000), zdet(1000)
  real*4 new_width, new_aspect, last_aspect

  real(rp) cbar_mat(2,2), cbar_mat1(2,2), cbar_mat2(2,2)
  real(rp) de/8e-4/
  real(rp) rms_x, rms_y
  real(rp) frev
  real*4 length, start, end     
  real(rp)rate_x, rate_y, rate_xq, rate_yq, rate_x_tot, rate_y_tot
  real(rp) d_amp_x, d_amp_y
  real (rp) p1, p2
  real (rp) f,p
  real(rp) axx, axy, ayy     
  real(rp) res_cos, res_sin, res_amp
  real(rp) n_part_save
  real(rp) slopes(4)
  real(rp) delta_frf, frf
  real(rp) betah_tot, betav_tot
  real(rp) energy
     
  character*40 lattice
  character*120 lat_file
  character*120 line, last_line, vec_start
  character*20 x_or_y, answer, save_answer
  character*72 comment
  character*20 device_type, last_device_type/' '/
  character*40 ele_names(4)
  character*40 location
  character*40 name_flag(10)/'orbit','beta','cbar','diff', 'denergy_dbeta', 'eta', &
                         'denergy_dcbar', 'eta_prop', 'radiation_integrals', 'sextupoles'/

  logical keep_trying/.true./
  logical write/.false./                                        
  logical diff
  logical radiation/.false./
  logical transfer_line/.false./
  logical track/.false./
  logical cbarve/.false./
  logical path_length_patch/.false./
  logical set_synchronous_phase/.false./
  logical err_flag
  logical error/.false./
!
  nargs = cesr_iargc()
  if (nargs == 1)then
     call cesr_getarg(1, lat_file)
     print *, 'Using ', trim(lat_file)
  else

    lat_file = 'bmad.'
    print '(a,$)',' Lattice file name ? (default= bmad.) '
    read(5,'(a)') line
    call string_trim(line, line, ix)
    lat_file = line
    if(ix == 0) lat_file = 'bmad.'
    print *, ' lat_file = ', lat_file
  endif

!  call bmad_parser (lat_file, ring_1)
  call bmad_and_xsif_parser(lat_file, ring_1)
  ring  = ring_1
!  call implement_pathlength_patch(path_length_patch, ring)

  call reallocate_coord (co, ring%n_ele_max)
  call reallocate_coord (co_electron, ring%n_ele_max)
  call reallocate_coord (cot, ring%n_ele_max)
  call reallocate_coord (co_off, ring%n_ele_max)
  call reallocate_coord (co_high, ring%n_ele_max)
  call reallocate_coord (co_low, ring%n_ele_max)

  co(0)%vec = 0
  co_electron(0)%vec=0
  cot(0)%vec=0
  co_off(0)%vec=0
  co_high(0)%vec=0
  co_low(0)%vec=0
  track_start%vec = 0.

  allocate(track_meth(0:ring%n_ele_max+100))
  allocate(x(0:ring%n_ele_max+100))
  allocate(y(0:ring%n_ele_max+100))
  allocate(z(0:ring%n_ele_max+100))
  allocate(xx_diff(0:ring%n_ele_max+100))
  allocate(yy_diff(0:ring%n_ele_max+100))
  allocate(zz_diff(0:ring%n_ele_max+100))
  allocate(yy(0:ring%n_ele_max+100,1:5))
  allocate(xx(0:ring%n_ele_max+100,1:5))
  allocate(zz(0:ring%n_ele_max+100,1:5))
  allocate(n_ele(1:5))

  length = ring%ele(ring%n_ele_track)%s

  last = 0

!  do while (.not. write_orbit)
  do while (.true.)
  do while (keep_trying)

10  print '(a, $)', ' ANALYZER:  element change or GO> '
      read(5, '(a)',err=10) line
     
  ix = index(line, '!')
  if (ix /= 0) line = line(:ix-1)        ! strip off comments

  call str_upcase(line, line)
  call string_trim(line, line, ix)

  if (ix == 0) then       ! nothing typed. do the same thing
      line = last_line
  endif

   last_line = line

   call str_upcase(line,line)
   if(line(1:1) .eq. 'G')exit
   if(index(line, 'RADIATION') /= 0)then
    if(index(line, 'ON') /= 0) radiation = .true.
    if(index(line, 'OFF') /= 0) radiation = .false.
    exit 
  endif
    

   if(index(line, 'CBAR_V_E') /= 0)then
    if(index(line, 'ON') /= 0) cbarve = .true.
    if(index(line, 'OFF') /= 0) cbarve = .false.
    exit 
  endif

   if(line(1:2) == 'EX' .or. line(1:2) == 'QU')then
!     if(istat1 > 0)then
!      call pgslct(istat1)
!      call pgclos
!     endif
     if(istat2 > 0)then
      call pgslct(istat2)
      call pgclos
     endif
     goto 100
   endif
   if(line(1:4) == 'TRAN')then
     if(index(line,'OFF') == 0)then
       transfer_line = .true.
       print *,' Transfer line mode on'
      else
       transfer_line = .false.
       print *,' Transfer line mode off'
     endif
     call set_on_off (rfcavity$, ring, off$)
     cycle
   endif

   if(line(1:4) == 'READ')then
      print '(a,$)',' Lattice file name ? '
      read(5, '(a)') line
       call string_trim(line, line, ix)
       lat_file = line
       print *, ' lat_file = ', lat_file
     call bmad_parser(lat_file, ring_2)
     ring = ring_2
     exit
   endif


   if(line(1:4) == 'RING')then
     if(index(line(6:),'1') /= 0)ring=ring_1
     if(index(line(6:),'2') /= 0)ring=ring_2
     exit
   endif


!  lat_file = line

   if(line(1:4) == 'REVE')then
     ring_1 = ring
     !!! call lat_reverse(ring_1, ring_2)
     !!! print '(a)', "RING 2 is the reverse of RING 1"
     print *, 'Ring reversal disabled. Please contact DCS for mor info.'
     exit
   endif

   if(line(1:2) == '6D')then
     i_dim=6
     print *,' Compute 6-d closed orbit'
       call string_trim(line, line, ix)
       call string_trim(line(ix+1:), line, ix)

       if(ix /= 0)then
          read(line(1:ix),*)delta_frf
          call string_trim(line(ix+1:), line, ix)

          if(ix /= 0)then
            read(line(1:ix),*)frf
            else
            frf = 5.e8
          endif

          call implement_pathlength_patch(path_length_patch,ring,delta_frf,frf)
          print '(1x,a13,1x,e12.4,a9,1x,e12.4)',' delta_frf = ', delta_frf, '   frf = ', frf

       endif

     exit
   endif
   if(line(1:2) == '4D')then
     i_dim=4
       call string_trim(line, line, ix)
       call string_trim(line(ix+1:), line, ix)
       if(ix /= 0)then
         read(line(1:ix),*)co(0)%vec(6)
        else
         co(0)%vec(6)=0.
       endif
     co_electron(0)%vec(6)=0.
     print '(a43,e12.4)',' Compute 4-d closed orbit, energy offset = ', co(0)%vec(6)
     exit
   endif

   if(line(1:4) == 'TRAC')then
     call str_upcase(line, line)
     call string_trim(line, line, ix)
     call string_trim(line(ix+1:), line, ix)

     If(index(line(1:ix),'START') /= 0)then
       call string_trim(line(ix+1:), line, ix)
       location = line(1:ix)
       call element_locator(location, ring, ix_start)
       if(ix_start < 0) print *,' Element ', location, ' is not found in the ring'
       cycle
     endif
     If(index(line(1:ix),'END') /= 0)then
       call string_trim(line(ix+1:), line, ix)
       location = line(1:ix)
       call element_locator(location, ring, ix_end)
       if(ix_start < 0) print *,' Element ', location, ' is not found in the ring'
       cycle
     endif

     track_start%vec = 0. 
     track = .true.

     if(ix == 0)then
       print *,' TRACK <n_turns> <x> <y> <de/e> <xp> <yp> <dl> '
       print *,' or  TRACK START <start_location>'
       print *,' or  TRACK END   <end_location>'
       print *,' Phase space will be computed at ',ring%ele(ix_end)%name
       cycle 
    else
       read(line(1:ix),*,iostat = io_stat)n_turns
       if(io_stat /= 0)cycle
       vec_start = line(ix+1:)
       call num_words(vec_start, j)
       if(ix /= 0) read(line(ix+1:),*)(track_start%vec(k(i)),i=1,j)
     endif

    exit
   endif

   if(line(1:4) == 'PRET')then
      call string_trim(line(ix+1:),line,ix)
        if(ix == 0)then
          print '(a)',' type "PRETZ <trains> <bunches> <spacing>" or "PRETZ <filename>"'
          cycle
        endif
     line = 'PRET'//' '//line
     call get_crossings(ring,line, ncross, cross)
     call plot_pretz(ring, ncross, cross)
     exit
   endif

   if(line(1:4) == 'ENER')then
     call string_trim(line(ix+1:),line,ix)
     if (ix /= 0)then
       read(line,*)energy
       ring%ele(0)%value(E_TOT$) = energy * 1.e9
       call lattice_bookkeeper(ring, err_flag)
       call lat_make_mat6(ring, -1)  
    endif  
     print '(a,es12.4)', 'Energy (GeV) = ',ring%ele(0)%value(E_TOT$)/1.e9 
     cycle
     exit
   endif

   ix= index(line, 'PLOT_WIDTH')
   if(ix /= 0)then
      read(line(ix+11:),*)new_width
      if(new_width /= 0) width = new_width
      print *,' Plot width = ', width
    cycle
   endif
   ix= index(line, 'PLOT_ASPECT')
   if(ix/= 0)then
      read(line(ix+12:),*)new_aspect
      if(new_aspect /= 0)aspect = new_aspect
      print *,' Plot_aspect = ', aspect
     cycle
   endif

    if(index(line, 'SYNCH_PH') /= 0)then
     if(index(line, 'SET') /= 0)then
         set_synchronous_phase = .true.
         radiation = .true.
     endif
     if(index(line, 'noc') /= 0) set_synchronous_phase = .false.
     exit
   endif

   if(line(1:2) == 'PS' .or.  line(1:3) == 'GIF')exit

   
   call find_change( line, ring)

  if(line(1:2) == 'HE' .or. index(line, '?') /= 0)call list_commands

 end do

   if(line(1:2) /= 'PS' .and.  line(1:3) /= 'GIF')then

!  call lat_make_mat6 (ring, -1)

!  forall( i=0:ring.n_ele_use) co(i)%vec = 0.
     ring%param%particle = positron$

    if(.not. transfer_line)then
     call twiss_at_start(ring)
     print *,' i_dim = ', i_dim
     call closed_orbit_calc(ring, co, i_dim)
    endif

      print *, ' '
      print *,ring%input_file_name
      print '(a,es12.4)',' Beam energy (GeV) = ', ring%ele(0)%value(E_TOT$)/1.e9
      print '(a42,a12,1x,6f9.4)',' e+ orbit at start (mm/mr)       Element: ', &
                  ring%ele(1)%name , (co(0)%vec(i)*1000.,i=1,6)
      print '(a42,a12,1x,6f9.4)',' e+ closed orbit (mm/mr) at end, Element: ', &
                  ring%ele(ring%n_ele_track)%name,  (co(0)%vec(i)*1000.,i=1,6)

      if(track)then
        traj%vec(1:6) = co(ix_start)%vec(1:6) + track_start%vec(1:6)       
        print *
        print '(1x,a10,1x,a12,1x,a2,1x,a12,i5,1x,a6)', &
                      'TRACK from',ring%ele(ix_start)%name,'to',ring%ele(ix_end)%name, n_turns, ' turns'
        print '(1x,a15,1x,a12,6f10.2)','TRACK: start at',ring%ele(ix_start)%name, track_start%vec *1000
        print '(1x,a15,1x,a12,6f10.2)','TRACK: start+co',ring%ele(ix_start)%name, traj%vec * 1000

        call psp(ring, co, traj, n_turns, istat2, ix_start, ix_end)

        print '(1x,a15,1x,a12,6f10.2,/)','TRACK: end at  ',location, traj%vec*1000
        track=.false.
      endif

     ring%param%particle = electron$
     n_part_save = ring%param%n_part
     ring%param%n_part = 0.
    if(.not. transfer_line) &
     call closed_orbit_calc(ring, co_electron, i_dim)
      print '(a42,a12,1x,6f9.4)',' e- closed orbit (mm/mr) at end, Element: ', & 
               ring%ele(ring%n_ele_track)%name, (co_electron(0)%vec(i)*1000.,i=1,6)
      print *, ' '

     ring%param%n_part = n_part_save
     ring%param%particle = positron$

     call lat_make_mat6(ring,-1,co)
    if(.not. transfer_line) &
     call twiss_at_start(ring)
     call calc_z_tune (ring)

      call twiss_propagate_all(ring)
       call twiss3_at_start(ring,error)
        if(error)print *,' mode3 calc error'
       call twiss3_propagate_all(ring)

       frev=c_light/ring%ele(ring%n_ele_track)%s
!      print *,' Recompute tunes with new matrices'
      print '(23x,3a14)','  Horizontal  ','  Vertical    ',' Longitudinal '
      print '(a19,3f14.4)',' Fractional Tune   ',ring%a%tune/twopi,ring%b%tune/twopi,ring%z%tune/twopi
      print '(a19,3f14.4)',' Tune (kHz)        ',ring%a%tune/twopi*frev/1000,ring%b%tune/twopi*frev/1000, &
                                                             ring%z%tune/twopi*frev/1000
      print '(a19,2f14.4)','  Beta*            ',ring%ele(0)%a%beta, ring%ele(0)%b%beta
      print '(a19,2f14.4)','  Alpha*           ',ring%ele(0)%a%alpha, ring%ele(0)%b%alpha
      print '(a19,2f14.4)','   Eta*            ',ring%ele(0)%a%eta, ring%ele(0)%b%eta
      print '(a19,2f14.4)','   Etap*           ',ring%ele(0)%a%etap, ring%ele(0)%b%etap
      print '(a19,2f14.4)','  Full turn Phase  ',ring%ele(ring%n_ele_track)%a%phi, &
                                                       ring%ele(ring%n_ele_track)%b%phi


      call c_to_cbar(ring%ele(0),cbar_mat)


    if(transfer_line)then
      print '(/,a19,2f14.4)','  Beta at end      ',ring%ele(ring%n_ele_track)%a%beta, &
                                                          ring%ele(ring%n_ele_track)%b%beta
      print '(a19,2f14.4)','  Alpha at end     ',ring%ele(ring%n_ele_track)%a%alpha, &
                                                          ring%ele(ring%n_ele_track)%b%alpha
      print '(a19,2f14.4)','   Eta at end      ',ring%ele(ring%n_ele_track)%a%eta, &
                                                          ring%ele(ring%n_ele_track)%b%eta
      print '(a19,2f14.4)','   Etap at end     ',ring%ele(ring%n_ele_track)%a%etap, &
                                                       ring%ele(ring%n_ele_track)%b%etap
    endif

! calculate average beta
  betah_tot = 0.
  betav_tot = 0.
  do i=1,ring%n_ele_track
   betah_tot = betah_tot + ring%ele(i)%a%beta * ring%ele(i)%value(l$)
   betav_tot = betav_tot + ring%ele(i)%b%beta * ring%ele(i)%value(l$)
  end do 
      print '(a19,2f14.4)',' <Beta_h> = ',betah_tot/ring%ele(ring%n_ele_track)%s
      print '(a19,2f14.4)',' <Beta_v> = ',betav_tot/ring%ele(ring%n_ele_track)%s

!  calculate off energy beta

      ring_two(1) = ring
      ring_two(-1) = ring
      do i = -1,1,2
       co_off(0)%vec(6) = de *i
       if(transfer_line)then
         co_off(0)%vec(1) = ring_two(i)%ele(0)%a%eta * co_off(0)%vec(6)
         co_off(0)%vec(2) = ring_two(i)%ele(0)%a%etap * co_off(0)%vec(6)
         co_off(0)%vec(3) = ring_two(i)%ele(0)%b%eta * co_off(0)%vec(6)
         co_off(0)%vec(4) = ring_two(i)%ele(0)%b%etap * co_off(0)%vec(6)

         call track_all(ring_two(i), co_off)
       endif
       if(.not. transfer_line) call closed_orbit_calc(ring_two(i), co_off,i_dim)
       call lat_make_mat6(ring_two(i), -1, co_off)
       if(.not. transfer_line) call twiss_at_start(ring_two(i))
       call twiss_propagate_all(ring_two(i))
       if(i == -1)forall(j=0:ring%n_ele_track)co_low(j)%vec = co_off(j)%vec
       if(i ==  1)forall(j=0:ring%n_ele_track)co_high(j)%vec = co_off(j)%vec
      end do

      call de_dbeta(ring_two(1), ring_two(-1), de, rms_x, rms_y)

      print *

      print '(a19,2f14.4)',' dBeta*/dE          ',(ring_two(1)%ele(0)%a%beta - ring_two(-1)%ele(0)%a%beta)/2/de, &
                             (ring_two(1)%ele(0)%b%beta - ring_two(-1)%ele(0)%b%beta)/2/de 

      print '(a19,2f14.4)', ' Chromaticity      ',(ring_two(1)%a%tune - ring_two(-1)%a%tune)/twopi/2/de, &
                             (ring_two(1)%b%tune - ring_two(-1)%b%tune)/twopi/2/de 
      print '(a19,2f14.4)', ' sqrt(<(dB/dE)^2>) ',rms_x, rms_y

      print *,' ' 
      print '(1x,a13,2f12.4)','    cbar     ',cbar_mat(1,1), cbar_mat(1,2) 
      print '(1x,a13,2f12.4)','             ',cbar_mat(2,1),cbar_mat(2,2) 

      call c_to_cbar(ring_two(1)%ele(0),cbar_mat1)
      call c_to_cbar(ring_two(-1)%ele(0),cbar_mat2)
      print *,' '
      print '(1x,a13,2f12.4)',' dcbar*/dE   ',(cbar_mat1(1,1)-cbar_mat2(1,1))/de, &
                                             (cbar_mat1(1,2)-cbar_mat2(1,2))/de 
      print '(1x,a13,2f12.4)','             ',(cbar_mat1(2,1)-cbar_mat2(2,1))/de, &
                                             (cbar_mat1(2,2)-cbar_mat2(2,2))/de 


! sextupole detuning rate
     if( .not. transfer_line)then
      call sext_detune(ring, axx, axy, ayy)
      print *
      print *,' Sextupole detuning rates '
      print '(a12,e12.4)',' Alpha_ax = ',axx 
      print '(a12,e12.4)',' Alpha_ay = ',axy 
      print '(a12,e12.4)',' Alpha_yy = ',ayy
      print * 

      call fourier_comp(ring, res_cos, res_sin, res_amp)
      print *
      print '(a8)',' Qs-2Qx '
      print '(2(a7,e12.4),a15,e12.4)', ' A_m = ',res_cos,' B_m = ', res_sin, &
                        ' |A_m + B_m| = ', res_amp
      print * 

     endif

      if(.not. transfer_line .and. cbarve)then   
       ele_names(1) = 'SK_Q03E'
       ele_names(2) = 'SK_Q03W'
       ele_names(3:4) = ' '
       call cbar_v_e(ring, ele_names, slopes)
       print *
       print '(a38,a10,a4,a10)',' Energy derivative of cbar for insert ',ele_names(1),' to ',ele_names(2)
!       print '(4(a10,f7.3))',' d_Cb11 = ',slopes(1),' d_Cb12 = ',slopes(2), &
!               ' d_Cb22 = ',slopes(3),' d_Cr21 = ', slopes(4)
       print '(1x,a21,2f12.4)',' dcbar/dE(insert)   ', slopes(1:2)
       print '(1x,a21,2f12.4)','                    ', slopes(3:4)
      endif

      ix_cache = 0
      if(radiation)then
       call radiation_integrals (ring, co, mode, ix_cache, 0, rad_int)
       call calc_synchronous_phase(ring, mode,set_synchronous_phase)
       if(set_synchronous_phase)then
        call lat_make_mat6(ring,-1,co)
        if(.not. transfer_line) call twiss_at_start(ring)
        call calc_z_tune (ring)
        call radiation_integrals (ring, co, mode, ix_cache, 0, rad_int)
        print '(a,es12.4)',' synchrotron tune = ', ring%z%tune/twopi
       endif
       print '(a24,e12.4,a25,e12.4)',' horizontal emittance = ', mode%a%emittance, &
                                    '    vertical emittance = ',mode%b%emittance
       print '(a17,e12.4,a18,e12.4, a, e12.4)',' Energy spread = ',mode%sige_e,'   Bunch length = ',mode%sig_z ,&
                                     ' Energy loss/turn [MeV] ',mode%e_loss/1.e6
       print '(a11,e12.4)',' Revolution freq    = ', frev
       if(mode%a%alpha_damp /= 0.)then
         print '(a22,e12.4)',' Horiz damping time = ',1/mode%a%alpha_damp/frev
         print '(a22,e12.4)',' Vert damping time =  ',1/mode%b%alpha_damp/frev
         print '(a22,e12.4)',' Long damping time =  ',1/mode%z%alpha_damp/frev
         print '(a7,e12.4,a10,e12.4)',' i1  =',mode%synch_int(1), &
                                      ' alpha_p =',mode%synch_int(1)/ring%ele(ring%n_ele_track)%s
         print '(a7,e12.4)',' i2  =',mode%synch_int(2)
         print '(a7,e12.4)',' i3  =',mode%synch_int(3)
         print '(a7,e12.4)',' i4  =',mode%a%synch_int(4)
         print '(a7,e12.4)',' i5a =',mode%a%synch_int(5)
         print '(a7,e12.4)',' i6b =',mode%b%synch_int(6)
       endif
      endif

      if(.not. transfer_line)then
       call sextupole_resonance(ring,rate_x, rate_y, rate_xq, rate_yq, rate_x_tot, rate_y_tot, mode%sige_e)
       print *,' '
       print '(a45,2e12.4)', &
         ' Synchro-betatron sext growth rate at 0.5+Qs/2, H/V ' , rate_x, rate_y
       print '(a45,2e12.4)', &
         ' Synchro-betatron quad growth rate at 0.5+Qs/2, H/V ' , rate_xq, rate_yq
       print '(a45,2e12.4)', &
         ' Synchro-betatron tot growth rate at 0.5+Qs/2, H/V ' , rate_x_tot, rate_y_tot

       if(ring%z%tune /= 0.)then
         call sync_beta_path(ring, d_amp_x, d_amp_y)
         print '(a31,4e12.4)',' (6d orbit amp- 4d orbit amp)/6d amp/ total volts  x   y', d_amp_x, d_amp_y 
         call sync_beta_volt(ring, d_amp_x, d_amp_y)
         print '(a24,2e12.4)',' (d(amp)/d(volt))  x   y', d_amp_x, d_amp_y
       endif
      endif


     answer='                '

     device_type ='/XSERVE'
     diff=.false.

20   print *, ' '
     write = .false.
     print '(a,$)',' Plot ? ([ORBIT,BETA,CBAR, DBETA/DE, DPHASE/DE,  ETA, DCBAR/DE, RAD_INT, DIFF, SEXT, PHASE, V15, V16]) > '
     read(5, '(a)', err=20)answer
     save_answer = answer

    else !    if(line(1:2) /= 'PS'.and. line(1:2) /= 'GIF')then
      if(line(1:2) == 'PS')device_type = 'plot.ps/VCPS'
      if(line(1:2) == 'GI')device_type = 'plot.gif/VGIF'
      answer = save_answer
    endif

     call str_upcase(answer,answer)
     call string_trim (answer, answer, ix)
     if(index(answer(1:ix),'OR') /= 0)then
       plot_flag = orbit$
      elseif(index(answer(1:ix),'BE') /= 0)then
       plot_flag=beta$
      elseif(index(answer(1:ix),'DB') /= 0)then
       plot_flag=de_beta$
      elseif(index(answer(1:ix),'DP') /= 0)then
       plot_flag=de_phase$
      elseif(index(answer(1:ix),'CB') /= 0)then
       plot_flag=cbar$
      elseif(index(answer(1:ix),'ETA_PROP') /= 0)then
       plot_flag=eta_prop$
      elseif(index(answer(1:ix),'ET') /=0 .and. index(answer(1:ix),'PROP') == 0)then
       plot_flag=eta$
      elseif(index(answer(1:ix),'DC') /=0)then
       plot_flag=de_cbar$
      elseif(index(answer(1:ix),'RAD') /=0)then
       plot_flag=rad_int$
      elseif(index(answer(1:ix),'SEX') /=0)then
       plot_flag=sext$
      elseif(index(answer(1:ix),'PHA') /=0)then
       plot_flag=phase$
      elseif(index(answer(1:ix),'V15') /=0)then
       plot_flag=v15$
      elseif(index(answer(1:ix),'V16') /=0)then
       plot_flag=v16$
      elseif(index(answer,'DI') /= 0 .or. diff)then
       diff = .true.
      elseif(index(answer,'WRITE') /= 0)then
       if(plot_flag /= 0)then
        write = .true.
        lun = lunget()
        open(unit=lun, file = trim(name_flag(plot_flag))//'.dat')
       endif
      else
       cycle
     endif
    
    if(line(1:2) /= 'PS'.and. line(1:3) /= 'GIF')then
     x_or_y = ' '
     xmax0=0.
     ymax0=0.
     start=0.
     end=length
     print *,answer
     call string_trim(answer(ix+1:),answer,ix)
     print*,answer(1:ix)
     if(ix /= 0.)read(answer(1:ix),*)x_or_y
     call string_trim(answer(ix+1:),answer,ix)
     if(ix /= 0.)read(answer(1:ix),*)p1
     call string_trim(answer(ix+1:),answer,ix)
     print*,answer(1:ix)
     if(ix /= 0.)read(answer(1:ix),*)p2
     
     xmax=0.
     ymax=0.

     xmax0=0.
     ymax0=0.


     if(x_or_y(1:1) == 'Y')then
       xmax0 = p1
       ymax0 = p2
     endif
     if(x_or_y(1:1) == 'X')then
       start = p1
       end = p2
     endif

     print *,' start =', start,'   end = ',end
     print *,'  xmax0 =',xmax0,  '  ymax0 = ',ymax0

     if(plot_flag == last)then
       n=n+1
       if(n>5)n=1
     else
       n=1
     endif
     last=plot_flag

    endif ! if(line(1:2) /= 'PS'.and. line(1:2) /= 'GIF')then

!      device_type = '?'
      if(device_type /= last_device_type .or. aspect /= last_aspect)then
       last_device_type = device_type
       last_aspect = aspect
       istat1 = pgopen(device_type)
       if(istat1 .lt. 1) stop
       call pgpap (width, aspect)
       call pgsubp(1,3)
       call pgask(.false.)
       call pgscr(0, 1., 1., 1.)
       call pgscr(1,0.,0.,0.)
       call pgscr(2, 1., 0., 0.)
       call pgscr(3,0.,0.,0.,1.0)
       call pgsch(2.)
       print '(a,$)', ' Comment ?'
       read(5,'(a)') comment
      endif
      call pgslct(istat1)
      if(device_type(1:7)  == '/XSERVE')then


     if(diff)then
      n=1
      call pgeras

     else


     nd=0
     n_all = ring%n_ele_track
!     do i=0,ring%n_ele_track
      z(0:n_all) = ring%ele(0:n_all)%s

      if(plot_flag == orbit$)then
       x(0:n_all)= co(0:n_all)%vec(1)*1000.
       y(0:n_all)= co(0:n_all)%vec(3)*1000.
       if(write) then
        print *,' Write orbit to '//trim(name_flag(plot_flag))//'.dat'
         write(lun,'(a16,7a12)')'element','s','x[mm]','xp[mm]','y[mm]','yp[mm]','dl[mm]','deltaE/E'
         do i=0,n_all
          write(lun,'(a16,7e12.4)')ring%ele(i)%name,ring%ele(i)%s,co(i)%vec(1:6)*1000
         end do
       endif
      endif

      if(plot_flag == beta$)then
       x(0:n_all) = ring%ele(0:n_all)%a%beta
       y(0:n_all) = ring%ele(0:n_all)%b%beta
       if(write) then
         write(lun,'(a16,5a12)')'element','s','a%beta','a%alpha','b%beta','b%alpha'
         print *,' Write orbit to '//trim(name_flag(plot_flag))//'.dat'
         do i=0,n_all
          write(lun,'(a16,5e12.4)')ring%ele(i)%name,ring%ele(i)%s, ring%ele(i)%a%beta, ring%ele(i)%a%alpha, &
                                      ring%ele(i)%b%beta, ring%ele(i)%b%alpha
         end do
       endif
      endif
      if(plot_flag == phase$)then
       x(0:n_all) = ring%ele(0:n_all)%a%phi
       y(0:n_all) = ring%ele(0:n_all)%b%phi
      endif

      if(plot_flag == v15$)then
       
       forall(i=0:n_all)x(i) = ring%ele(i)%mode3%v(1,5)
       forall(i=0:n_all)y(i) = ring%ele(i)%mode3%v(3,5)
      endif

      if(plot_flag == v16$)then
       
       forall(i=0:n_all)x(i) = ring%ele(i)%mode3%v(1,6)
       forall(i=0:n_all)y(i) = ring%ele(i)%mode3%v(3,6)
      endif

      if(plot_flag == de_beta$)then
       x(0:n_all) = (ring_two(1)%ele(0:n_all)%a%beta - ring_two(-1)%ele(0:n_all)%a%beta)/2/de/ &
                   ring%ele(0:n_all)%a%beta
       y(0:n_all) = (ring_two(1)%ele(0:n_all)%b%beta - ring_two(-1)%ele(0:n_all)%b%beta)/2/de/ &
                    ring%ele(0:n_all)%b%beta
      endif

      if(plot_flag == de_phase$)then
       x(0:n_all) = (ring_two(1)%ele(0:n_all)%a%phi - ring_two(-1)%ele(0:n_all)%a%phi)/2/de
       y(0:n_all) = (ring_two(1)%ele(0:n_all)%b%phi - ring_two(-1)%ele(0:n_all)%b%phi)/2/de
      endif

      if(plot_flag == eta$)then
       x(0:n_all) = (co_high(0:n_all)%vec(1) - co_low(0:n_all)%vec(1))/2/de
       y(0:n_all) = (co_high(0:n_all)%vec(3) - co_low(0:n_all)%vec(3))/2/de
       if(write) then
         write(lun,'(a16,3a12)')'element','s','etax','etay'
         print *,' Write orbit to '//trim(name_flag(plot_flag))//'.dat'
         do i=0,n_all
          write(lun,'(a16,3e12.4)')ring%ele(i)%name,ring%ele(i)%s, x(i), y(i)
         end do
       endif
      endif

      if(plot_flag == eta_prop$)then
       x(0:n_all) = ring%ele(0:n_all)%a%eta
       y(0:n_all) = ring%ele(0:n_all)%b%eta
       if(write) then
         write(lun,'(a16,3a12)')'element','s','a%eta','a%etap','b%eta','b%etap'
         print *,' Write orbit to '//trim(name_flag(plot_flag))//'.dat'
         do i=0,n_all
          write(lun,'(a16,3e12.4)')ring%ele(i)%name,ring%ele(i)%s,ring%ele(i)%a%eta,ring%ele(i)%a%etap, &
                                                                  ring%ele(i)%b%eta,ring%ele(i)%b%etap
         end do
       endif
      endif

      if(plot_flag == cbar$)then
        if(write)write(lun,'(a16,5a12)')'element','s','cbar_11','cbar_12','cbar_21','cbar_22'
        if(write)print *,' Write cbar to '//trim(name_flag(plot_flag))//'.dat'
        do i = 0,n_all
          call c_to_cbar(ring%ele(i),cbar_mat)
          x(i) = cbar_mat(1,2)
          y(i) = cbar_mat(2,2)
         if(write)write(lun,'(a16,5e12.4)')ring%ele(i)%name,ring%ele(i)%s, cbar_mat(1,1), cbar_mat(1,2), &
                                      cbar_mat(2,1), cbar_mat(2,2)
        end do
      endif

      if(plot_flag == de_cbar$)then
       do i = 0,n_all
         call c_to_cbar(ring_two(1)%ele(i),cbar_mat1)
         call c_to_cbar(ring_two(-1)%ele(i),cbar_mat2)
         x(i) = (cbar_mat1(1,2)-cbar_mat2(1,2))/2/de
         y(i) = (cbar_mat1(2,2)-cbar_mat2(2,2))/2/de
       end do
      endif

      if(plot_flag == rad_int$)then
       do i=0,n_all
         x(i) = rad_int%ele(i)%i5a
         y(i) = rad_int%ele(i)%i5b
       end do
      endif

      if(plot_flag == sext$)then
        do i=0,n_all
          x(i)=0
          y(i)=0
          if(ring%ele(i)%key == sextupole$)then
            if(ring%ele(i)%a%beta > ring%ele(i)%b%beta)then
              x(i) = ring%ele(i)%value(k2$)
             else      
              y(i) = ring%ele(i)%value(k2$) 
            endif
          endif
        end do
      endif

      do i = 0,n_all
        if(index(ring%ele(i)%name, 'DET') /= 0)then
          nd = nd+1
          zdet(nd) = z(i)
          xdet(nd) = x(i)
          ydet(nd) = y(i)
        endif


        xmax = max(abs(x(i)),xmax)
        ymax = max(abs(y(i)),ymax)
        if(xmax0 /= 0.)xmax=xmax0
        if(ymax0 /= 0.)ymax=ymax0

        write(61,'(1x,a,1x,3e12.4)')ring%ele(i)%name,z(i),x(i),y(i)
     end do


     n_all = ring%n_ele_track
     l = n_all
     endif


     if(diff)then
     nd = 0
     l=0
     do i=0,ring%n_ele_track
      do j = 0, n_all
       if(abs(z(j) -  ring%ele(i)%s) > 0.0001) cycle

       l = l+1

       zz_diff(l) = ring%ele(i)%s 

      if(plot_flag == orbit$)then
       xx_diff(l)= co(i)%vec(1)*1000. -x(j)
       yy_diff(l)= co(i)%vec(3)*1000. -y(j)
      endif
      if(plot_flag == beta$)then
       xx_diff(l) = ring%ele(i)%a%beta -x(j)
       yy_diff(l) = ring%ele(i)%b%beta -y(j)
      endif

      if(plot_flag == phase$)then
       xx_diff(l) = ring%ele(i)%a%phi -x(j)
       yy_diff(l) = ring%ele(i)%b%phi -y(j)
      endif

      if(plot_flag == v15$)then
       xx_diff(l) = ring%ele(i)%mode3%v(1,5) -x(j)
       yy_diff(l) = ring%ele(i)%mode3%v(3,5) -y(j)
      endif

      if(plot_flag == v16$)then
       xx_diff(l) = ring%ele(i)%mode3%v(1,6) -x(j)
       yy_diff(l) = ring%ele(i)%mode3%v(3,6) -y(j)
      endif

      if(plot_flag == de_beta$)then
       xx_diff(l) = (ring_two(1)%ele(i)%a%beta - ring_two(-1)%ele(i)%a%beta)/2/de/ &
                  ring%ele(i)%a%beta - x(j)
       yy_diff(l) = (ring_two(1)%ele(i)%b%beta - ring_two(-1)%ele(i)%b%beta)/2/de/ &
                  ring%ele(i)%b%beta - y(j)
      endif

      if(plot_flag == de_phase$)then
       xx_diff(l) = (ring_two(1)%ele(i)%a%phi - ring_two(-1)%ele(i)%a%phi)/2/de - x(j)
       yy_diff(l) = (ring_two(1)%ele(i)%b%phi - ring_two(-1)%ele(i)%b%phi)/2/de - y(j)
      endif

      if(plot_flag == eta$)then
       xx_diff(l) = (co_high(i)%vec(1) - co_low(i)%vec(1))/2/de - x(j)
       yy_diff(l) = (co_high(i)%vec(3) - co_low(i)%vec(3))/2/de - y(j)
      endif

      if(plot_flag == eta_prop$)then
       xx_diff(l) = ring%ele(i)%a%eta - x(j)
       yy_diff(l) = ring%ele(i)%b%eta - y(j)
      endif


      if(plot_flag == cbar$)then
       call c_to_cbar(ring%ele(i),cbar_mat)
       xx_diff(l) = cbar_mat(1,2) -x(j)
       yy_diff(l) = cbar_mat(2,2) -y(j)
      endif

      if(plot_flag == de_cbar$)then
       call c_to_cbar(ring_two(1)%ele(i),cbar_mat1)
       call c_to_cbar(ring_two(-1)%ele(i),cbar_mat2)
       xx_diff(l) = (cbar_mat1(1,2)-cbar_mat2(1,2))/2/de - x(j)
       yy_diff(l) = (cbar_mat1(2,2)-cbar_mat2(2,2))/2/de - y(j)
      endif




      xmax = max(abs(xx_diff(l)),xmax)
      ymax = max(abs(yy_diff(l)),ymax)
      if(xmax0 /= 0.)xmax=xmax0
      if(ymax0 /= 0.)ymax=ymax0

      if(index(ring%ele(i)%name, 'DET') /= 0)then
        nd = nd+1
        zdet(nd) = zz_diff(l)
        xdet(nd) = xx_diff(l)
        ydet(nd) = yy_diff(l)
      endif
       print *,ring%ele(i)%name, l, zz_diff(l), xx_diff(l), yy_diff(l)       
      end do

     end do
    
     x(0:l) = xx_diff(0:l)
     y(0:l) = yy_diff(0:l)
     z(0:l) = zz_diff(0:l)
     endif


  endif !      if(device_type(1:7)  == '/XSERVE')then


! first panel
       call pgsci(1)
       if(plot_flag==orbit$)then
         p = int(log10(xmax))
         if(p<=0)p=p-1
         f=xmax/10**p
         xscale=(int(f*2+1)/2.)*10**p
         print *,' p,f, xmax, xscale ',p,f, xmax, xscale
         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','x(mm)',' Closed orbit')
       endif
       if(plot_flag==v15$ .or. plot_flag==v16$)then
         p = int(log10(xmax))
         if(p<=0)p=p-1
         f=xmax/10**p
         xscale=(int(f*2+1)/2.)*10**p
         print *,' p,f, xmax, xscale ',p,f, xmax, xscale
         call pgenv(start, end,-xscale,xscale,0,1)
         if(plot_flag == v15$)call pglab('z (m)','v(1,5) (rad)',' x-z tilt')
         if(plot_flag == v16$)call pglab('z (m)','v(1,6) (rad)',' x-z tilt')
       endif
       if(plot_flag == beta$)then
         xscale=(int(xmax/10.)+1)*10
         x_low = 0.
         if(diff)x_low = -xscale
         if(start >= 0)then
          call pgenv(start, end,x_low,xscale,0,1)
         else
          call pgenv(0., end,x_low,xscale,0,1)
          call pgenv(length+start, length,x_low,xscale,0,1)
         endif
         call pglab('z (m)','Bx(m)',' Beta')
       endif
       if(plot_flag == phase$)then
         xscale=(int(xmax/10)+1)*10
         x_low = 0
         if(diff)then
           xscale=(int(xmax/0.1)+1)*0.1
           x_low = -xscale
         endif
         if(start >= 0)then
          call pgenv(start, end,x_low,xscale,0,1)
         else
          call pgenv(0., end,x_low,xscale,0,1)
          call pgenv(length+start, length,x_low,xscale,0,1)
         endif
         call pglab('z (m)','Phi_x(m)',' Phase')
       endif
       if(plot_flag == de_beta$)then
         xscale=(int(xmax/5.)+1)*5

         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','dBx/dE(m)',' dBeta/dE')
       endif
       if(plot_flag == de_phase$)then
         xscale=(int(xmax/0.1)+1)*0.1

         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','dPhix/dE(m)',' dPhi/dE')
       endif
       if(plot_flag == eta$ .or. plot_flag == eta_prop$)then
         xscale=(int(xmax/1.)+1)*1
         if(xmax0 /= 0.)xscale = xmax0
         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','etax',' eta')
       endif
       if(plot_flag == cbar$)then
         xscale=(int(xmax/0.1)+1)*0.1

         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','cbar12',' cbar')
       endif

       if(plot_flag == de_cbar$)then
         xscale=(int(xmax/0.1)+1)*0.1
         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','d(cbar12)/dE',' cbar')
       endif

       if(plot_flag==rad_int$)then
         p = int(log10(xmax))
         if(p<=0)p=p-1
         f=xmax/10**p
         xscale=(int(f*2+1)/2.)*10**p
         print *,' p,f, xmax, xscale ',p,f, xmax, xscale
         call pgenv(start, end,-xscale,xscale,0,1)
         call pglab('z (m)','I5a[1/m]',' Radiation Integrals')
       endif

       if(plot_flag == sext$)then
         xscale=(int(xmax/0.1)+1)*0.1
         call pgenv(start,end,-xscale,xscale,0,1)
         call pglab('z (m)','k2',' Horizontal focus sextupole')
       endif

!       endif

!       do i=1,ring%n_ele_track
       do i=1,l
         zz(i,n)=z(i)
         xx(i,n)=x(i)
       end do
!         n_ele(n) = ring%n_ele_track
         n_ele(n) = l

       do j =1,n
         call pgsci(j)
         do i=1,n_ele(j) 
          z(i)=zz(i,j)
          x(i)=xx(i,j)
         end do
         if(plot_flag == rad_int$ .or. plot_flag == sext$)then
!            call pgpt(n_ele(j), z,x,-4)
            do i=1,n_ele(j)
             if(xx(i,j) /= 0.)then
              za(1:2)=z(i-1)
              za(3:4)=z(i)
              xa(1:4)=0.
              xa(2:3)=x(i)
              call pgline(4, za,xa)
             endif
            end do
          else
           call pgline(n_ele(j), z, x)
         endif
       end do
       if(plot_flag /= rad_int$)call pgpt(nd, zdet, xdet, 18)
       call pgmtxt('T',3.,0.,0.,comment)

!  plot elements - middle panel
       call plot_elements(ring, start, end)

! third panel
       call pgsci(1)
       if(plot_flag == orbit$)then
         p = int(log10(ymax))
         if(p<=0)p=p-1
         f=ymax/10**p
         yscale=(int(f*2+1)/2.)*10**p
         if(yscale < 1.e-20)yscale = 1.e-20
         print *,' p,f, ymax, yscale ',p,f, ymax, yscale
         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','y(mm)',' Closed orbit')
       endif
       if(plot_flag == v15$ .or. plot_flag == v16$)then
         p = int(log10(ymax))
         if(p<=0)p=p-1
         f=ymax/10**p
         yscale=(int(f*2+1)/2.)*10**p
         if(yscale < 1.e-20)yscale = 1.e-20
         print *,' p,f, ymax, yscale ',p,f, ymax, yscale
         call pgenv(start, end,-yscale,yscale,0,1)
         if(plot_flag == v15$)call pglab('z (m)','V(3,5) (mrad)',' y-z tilt')
         if(plot_flag == v16$)call pglab('z (m)','V(3,6) (mrad)',' y-z tilt')
       endif
       if(plot_flag == beta$)then
         yscale=(int(ymax/10.)+1)*10
         y_low = 0.
         if(diff)y_low=-yscale
         if(start >=0)then
          call pgenv(start, end, y_low, yscale,0,1)
         else
          call pgenv(0., end, y_low, yscale,0,1)
          call pgenv(length+start, length, y_low, yscale,0,1)
         endif
         call pglab('z (m)','By(m)',' Beta')
       endif
       if(plot_flag == phase$)then
         yscale=(int(ymax/10.)+1)*10
         y_low = 0.
         if(diff)then
            yscale = (int(ymax/0.1)+1)*0.1
            y_low=-yscale
         endif
         if(start >=0)then
          call pgenv(start, end, y_low, yscale,0,1)
         else
          call pgenv(0., end, y_low, yscale,0,1)
          call pgenv(length+start, length, y_low, yscale,0,1)
         endif
         call pglab('z (m)','Phi_y(m)',' Phase')
       endif
       if(plot_flag == de_beta$)then
         yscale=(int(ymax/5.)+1)*5

         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','dBy/dE(m)',' dBeta/dE')
       endif
       if(plot_flag == de_phase$)then
         yscale=(int(ymax/0.1)+1)*0.1

         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','dPhiy/dE(m)',' dPhi/dE')
       endif
       if(plot_flag == eta$ .or. plot_flag == eta_prop$)then
         yscale=(int(ymax/0.5)+1)*0.5
         if(ymax0 /= 0.)yscale=ymax0
         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','etay',' eta')
       endif
       if(plot_flag == cbar$)then 
         yscale=(int(ymax/0.1)+1)*0.1

         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','cbar22',' cbar')
       endif
       if(plot_flag == de_cbar$)then 
         yscale=(int(ymax/0.1)+1)*0.1
         yscale = 10.
         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','d(cbar22)/dE',' cbar')
       endif

       if(plot_flag == rad_int$)then
         p = int(log10(ymax))
         if(p<=0)p=p-1
         f=ymax/10**p
         yscale=(int(f*2+1)/2.)*10**p
         if(yscale < 1.e-20)yscale = 1.e-20
         print *,' p,f, ymax, yscale ',p,f, ymax, yscale
         call pgenv(start, end,-yscale,yscale,0,1)
         call pglab('z (m)','I5b[1/m]',' Radiation Integrals')
       endif

       if(plot_flag == sext$)then
         yscale=(int(ymax/0.1)+1)*0.1
         call pgenv(start,end,-yscale,yscale,0,1)
         call pglab('z (m)','k2',' Vertical focus sextupole')
       endif

!       do i=1,ring%n_ele_track
       do i=1,l
         zz(i,n)=z(i)
         yy(i,n)=y(i)
       end do

       do j =1,n
         call pgsci(j)
         forall(i=1:n_ele(j))z(i)=zz(i,j)
         forall(i=1:n_ele(j))y(i)=yy(i,j)
         if(plot_flag == rad_int$ .or. plot_flag == sext$)then
!           call pgpt(n_ele(j),z,y,-4)
            do i=1,n_ele(j)
             if(yy(i,j) /= 0.)then
              za(1:2)=z(i-1)
              za(3:4)=z(i)
              xa(1:4)=0.
              xa(2:3)=y(i)
              call pgline(4, za,xa)
             endif
            end do
          else
           call pgline(n_ele(j), z, y)
         endif
       end do

         if(plot_flag /= rad_int$)call pgpt(nd, zdet, ydet, 18)

    

!     answer = ' '
!     print '(a,$)',' Write orbit ?', answer
!     accept *,answer
!     if(answer(1:1) == 'y' .or. answer(1:1) == 'Y')exit

      if(device_type(1:7) /= '/XSERVE') then
       print *,' write ',device_type(1:index(device_type,'/')-1)
       if(istat1 > 0)call pgslct(istat1)
       call pgclos
      endif

 end do
 


100      print *,' write orbit data to fort.33'
      print *,' plot orbit with orbit.pcm and orbit_ir.pcm'
      open(unit=33)
      write (33,*) ' z(meters), x,xp,y,yp (mm,mrad)'
      write(33,2)
2     format(1x,'ele',14x,'z',9x,'x',5x,'xp',6x,'y',7x,'yp',10x,'l',7x,'energy')

       do i=1,ring%n_ele_track
  write(33,1)ring%ele(i)%name,ring%ele(i)%s,(co(i)%vec(j)*1000.,j=1,4),   &
                       co(i)%vec(5), co(i)%vec(6)
       end do
1      format(1x,a13,f8.3,4f8.2,2e12.4) 
       close(unit=33)

      print *,' write geometry data to "geometry.dat"'
      open(unit=34, file='geometry.dat')
      write(34,'(1x,a13,7a15)')'  Ele name  ','     s       ', &
                                              '     x       ','     y      ','     z      ',&
                                              '   theta     ','    phi     ','    psi     ' 

       do i=1,ring%n_ele_track
  write(34,'(1x,a13,6es15.7)')ring%ele(i)%name, ring%ele(i)%s, &
!                        ring%ele(i)%floor%x,ring%ele(i)%floor%y,ring%ele(i)%floor%z, &
                        ring%ele(i)%floor%r, ring%ele(i)%floor%theta,ring%ele(i)%floor%phi,ring%ele(i)%floor%psi

       end do

       close(unit=34)

      print *,' write beta and eta data to "beta_eta.dat"'
      open(unit=34,file="beta_eta.dat")
      print *,' write beta, alpha, and eta, etap data to "beta_alpha_eta_etap.dat"'
      open(unit=35,file="beta_alpha_eta_etap.dat")
      write(34,'(a13,5a12)')'Element','s','beta x','beta y','eta x','eta y'
      write(35,'(a13,10a15)')'Element','s','beta x','alpha x','beta y','alpha y','eta x','etap x','eta y','etap y','v15'
       do i=1,ring%n_ele_track
  write(34,'(1x,a13,5e12.4)')ring%ele(i)%name, ring%ele(i)%s, &
                        ring%ele(i)%a%beta,ring%ele(i)%b%beta,ring%ele(i)%x%eta, &
                        ring%ele(i)%y%eta
  write(35,'(1x,a13,10es15.7)')ring%ele(i)%name, ring%ele(i)%s, &
                        ring%ele(i)%a%beta,ring%ele(i)%a%alpha, &
                        ring%ele(i)%b%beta, ring%ele(i)%b%alpha, &
                        ring%ele(i)%x%eta, ring%ele(i)%x%etap, &
                        ring%ele(i)%y%eta, ring%ele(i)%y%etap, ring%ele(i)%mode3%v(1,5)

       end do

       close(unit=35)
       close(unit=34)

   


      end

  subroutine de_dbeta(ring_high, ring_low, de, rms_x, rms_y)
  use bmad_struct
  use bmad_interface

 implicit none

 type (lat_struct) ring_high, ring_low

 real(rp) de, rms_x, rms_y, avg_x, avg_y,sum_x,sum_y

  integer i

   sum_x=0.
   sum_y=0.
   do i=1,ring_high%n_ele_track
      sum_x = sum_x + (ring_high%ele(i)%a%beta - ring_low%ele(i)%a%beta)/2/de
      sum_y = sum_y + (ring_high%ele(i)%b%beta - ring_low%ele(i)%b%beta)/2/de
   end do
    avg_x = sum_x/ring_high%n_ele_track
    avg_y = sum_y/ring_high%n_ele_track

    sum_x=0.
    sum_y=0.

   do i=1,ring_high%n_ele_track
      sum_x = sum_x + ( (ring_high%ele(i)%a%beta - ring_low%ele(i)%a%beta)/2/de -  avg_x)**2
      sum_y = sum_y + ( (ring_high%ele(i)%b%beta - ring_low%ele(i)%b%beta)/2/de -  avg_y)**2
   end do

   rms_x = sqrt(sum_x/ring_high%n_ele_track)
   rms_y = sqrt(sum_y/ring_high%n_ele_track)

   return
   end

  subroutine list_commands
    implicit none

    print *
    print *,' "READ" : to read another lattice into ring_2'
    print *,' "REVERSE" : create ring_2 as reverse of ring_1'
    print *,' "RING_1(2)" : switch to ring_1(2). '
    print *,'        Ring_1(2) is the ring structure for the lattice read at startup'
    print *,' "RADIATION ON(OFF)" : turn radiation damping and fluctuations on(off)'
    print *,' "CBAR_V_E ON(OFF)" : turn cbar vs energy calc on(off)'
    print *,' "TRANSFER ON(OFF)" :transfer line mode (ON) or closed +coring (OFF)'
    print *,' "6D" :compute 6-dimensional closed orbit'
    print *,'  6D <delta f_rf (Hz)> < f_rf (Hz)> '
    print *,' "4D   Delta E/E" :compute 4-dimensional closed orbit with energy offset'
    print *,' "TRACK" :track and plot phase space'
    print *,' "SYNCH_PHASE" : set synchronous phase (SET) or nochange (NOCHANGE)' 
    print *,' "PRETZ" :write orbit and crossing point data for PRETZEL plot'
    print *,' "ENERGY #" :change energy to #(GeV)'
    print *,'           fort.35 - Electron and positron orbits'
    print *,'           fort.37 - Origin and Injection point'
    print *,'           fort.40 - Separators'
    print *,'           fort.36 - parasitic crossing points' 
    print *,'           fort.39 - Location of feedback kickers'
    print *,'           fort.38 - hard bends and xray wigglers '
    print *,'           fort.41 - Location and outline of quadrupoles, bends and wigglers'
    print *,'           fort.42 - Location and outline of bends'
    print *,'           fort.43 - Location and outline of quadrupoles'
    print *,'           fort.44 - Location and outline of wigglers'
    print *,'           Use "/home/dlr/gnuplot_macro/plot_pretz.gnu" to plot' 
    print *,'                                            pretzel and crossing points'
    print *,'           Use "/home/dlr/gnuplot_macro/plot_hb.gnu" to plot'
    print *,'                                            layout of hard bends'
    print *,'           Use "/home/dlr/gnuplot_macro/plot_hb_compare.gnu" to plot'
    print *,'                                            two hard bend layouts' 
    print *,' At <Plot> prompt:'
    print *,'                  print "PS" or "GIF" for hardcopy of last plot'
    print *,'                  type "<data_type>  X  <x_min>  <x_max> " to'
    print *,'                   set xrange' 
    print *,'                  type "<data_type>  Y  <y_up>  <y_low> " to'
    print *,'                   set absolute yrange for upper and lower plots'
    print *,'                  print "WRITE" to write the last thing plotted to a file"' 
    print *,' "PLOT_WIDTH #" :set plot width to # '
    print *,' "PLOT_ASPECT #" :set plot width to # '
    print *
    return
  end
 
  subroutine sextupole_resonance(ring, rate_x, rate_y, rate_xq, rate_yq, rate_x_tot, rate_y_tot, delta_e)
  use bmad_struct
  use bmad_interface

 implicit none

 type (lat_struct) ring

 real(rp) rate_x, rate_y, delta_e, rate_xq, rate_yq
 real(rp) xf, yf,sum_x_real, sum_x_imagine, sum_y_real, sum_y_imagine
 real(rp) xfq, yfq,sum_x_realq, sum_x_imagineq, sum_y_realq, sum_y_imagineq
 real(rp) rate_x_tot, rate_y_tot
 real(rp) frev

  integer i

   frev=c_light/ring%ele(ring%n_ele_track)%s
   sum_x_real =0.
   sum_x_imagine =0.
   sum_y_real =0.
   sum_y_imagine =0.
   sum_x_realq =0.
   sum_x_imagineq =0.
   sum_y_realq =0.
   sum_y_imagineq =0.

   do i=1,ring%n_ele_track
     if(ring%ele(i)%key == sextupole$)then
     xf = ring%ele(i)%value(k2$) * ring%ele(i)%a%eta *ring%ele(i)%a%beta
     yf = ring%ele(i)%value(k2$) * ring%ele(i)%a%eta *ring%ele(i)%b%beta

     sum_x_real = sum_x_real+ xf*cos(2*ring%ele(i)%a%phi)
     sum_x_imagine = sum_x_imagine +xf*sin(2*ring%ele(i)%a%phi)
     sum_y_real = sum_y_real + yf*cos(2*ring%ele(i)%b%phi)
     sum_y_imagine = sum_y_imagine + yf*sin(2*ring%ele(i)%b%phi)
!!     print '(a16,a16,i,2e12.4)',' name, i, xf, yf', ring%ele(i)%name, i, xf, yf
   
    elseif (ring%ele(i)%key == quadrupole$ .or. index(ring%ele(i)%name,'Q01')/= 0) then
     xfq = ring%ele(i)%value(k1$) *ring%ele(i)%a%beta
     yfq = ring%ele(i)%value(k1$) *ring%ele(i)%b%beta
     sum_x_realq = sum_x_realq+ xfq*cos(2*ring%ele(i)%a%phi)
     sum_x_imagineq = sum_x_imagineq +xfq*sin(2*ring%ele(i)%a%phi)
     sum_y_realq = sum_y_realq + yfq*cos(2*ring%ele(i)%b%phi)
     sum_y_imagineq = sum_y_imagineq + yfq*sin(2*ring%ele(i)%b%phi)
 !    print '( a16,2e12.4,i)', ring%ele(i)%name, xfq, sum_x_realq, ring%ele(i)%key
   
   endif   
  
   end do

   rate_x = sqrt(sum_x_real**2 + sum_x_imagine**2)* frev * delta_e
   rate_y = sqrt(sum_y_real**2 + sum_y_imagine**2)* frev * delta_e
   rate_xq = sqrt(sum_x_realq**2 + sum_x_imagineq**2)* frev * delta_e
   rate_yq = sqrt(sum_y_realq**2 + sum_y_imagineq**2)* frev * delta_e

   rate_x_tot = sqrt((sum_x_real+sum_x_realq)**2 + (sum_x_imagine+sum_x_imagineq)**2)* frev * delta_e
   rate_y_tot = sqrt((sum_y_real+sum_y_realq)**2 + (sum_y_imagine+sum_y_imagineq)**2)* frev * delta_e

   return
   end

   subroutine calc_synchronous_phase(ring, mode, set)
    use bmad

    implicit none

  type (lat_struct) ring
  type (normal_modes_struct) mode

  integer i
  integer ncav
  real(rp) volt
  real(rp) synch_phase
  real(rp) phi

  logical set

! find total accelerating voltage
    volt = 0.
    ncav = 0
    do i = 1,ring%n_ele_track
     if(ring%ele(i)%key == rfcavity$)then
       volt = volt + ring%ele(i)%value(voltage$)
       ncav = ncav + 1
       phi = ring%ele(i)%value(phi0$)
     endif
    end do

    synch_phase = 0.
    if(volt /= 0)synch_phase = asin(mode%e_loss/volt)
     print '(a,es12.4,a,i3,a)',' total accelerating voltage = ',volt,'  with ',ncav,' RF cavities '
!    print '(a,es12.4)',' energy loss /turn = ',mode%e_loss
    print '(a,es12.4,a,es12.4,a,es12.4)',' synchronous phase (deg) = ',synch_phase * 360./twopi, &
                              '     phi/360 =', synch_phase/twopi, &
                              '     value(phi0$) = ', phi 
    if(set)then
    do i = 1,ring%n_ele_track
     if(ring%ele(i)%key == rfcavity$)ring%ele(i)%value(phi0$) = synch_phase/twopi
    end do
    endif

    return
   end subroutine

   subroutine  num_words(line, ix)
   implicit none
   character*(*) line
   integer i, ix

   ix=0
   call string_trim(line, line, i)
   do while (i /= 0 )
     ix = ix+1
     call string_trim(line(i+1:), line, i)
   end do
   return
   end


  subroutine psp(ring, co, traj, n_turns, istat2, ix_start, ix_end)
  use bmad
  implicit none
  type (lat_struct) ring
  type (coord_struct) traj, psp_all
  type (coord_struct), allocatable :: co(:), psp_save(:)
  type (coord_struct), allocatable, save :: orbit(:)

  real*4, allocatable, save :: psx(:), psxp(:), psy(:), psyp(:), psz(:), pszp(:)
  real*4 xscale/0./, xscalep/0./, yscale/0./,yscalep/0./,zscale/0./, zscalep/0./


  integer n_turns, i, pgopen, istat2
  integer number_turns
  integer icall
  integer ix_start, ix_end
  integer ix, track_state
  integer ix_det(16)
  integer istart, j

  logical first1/.true./,first2/.true./
  logical already_open/.false./

  character*30 file_name
  character*40 title
  character*20 device_type/'          '/
  character*20 answer/'   '/
  character*7 detector(16)
  character*16 end_name

  data detector/'DET_00W','DET_01W','DET_02W','DET_03W','DET_04W','DET_05W', &
                        'DET_06W','DET_07W','DET_08W','DET_09W','DET_10W','DET_11W', &
                        'DET_12W','DET_02E','DET_01E','DET_00E'/

  call reallocate_coord(orbit, ring%n_ele_max)
  call reallocate_coord(psp_save, n_turns)
  allocate(psx(n_turns), psxp(n_turns), psy(n_turns), psyp(n_turns), psz(n_turns), pszp(n_turns))

  do i=1,size(ix_det)
    call element_locator(detector(i), ring, ix_det(i))
  end do

  do i = 1, ring%n_ele_max
    if(ring%ele(i)%value(x1_limit$) == 0) ring%ele(i)%value(x1_limit$) = 0.05
    if(ring%ele(i)%value(y2_limit$) == 0) ring%ele(i)%value(y2_limit$) = 0.05
    if(ring%ele(i)%value(x1_limit$) == 0) ring%ele(i)%value(x1_limit$) = 0.05
    if(ring%ele(i)%value(y2_limit$) == 0) ring%ele(i)%value(y2_limit$) = 0.05
  enddo

  ring%param%aperture_limit_on = .true.

  orbit(ix_start)%vec = traj%vec
  open(unit = 51, file = 'phase_space_cesr_bpm.dat')
  open(unit = 52, file = 'phase_space_start.dat')
   write(51,'(a6,a12,6a12)')' turn ','  Element   ','     x      ','     xp     ','     y      ','    yp      ', &
                                                                                  '   delta l  ','  delta E/E '
  call string_trim(ring%ele(ix_end)%name, end_name, ix)

  do i=1,n_turns
    istart = ix_start

    do j =1, size(ix_det)
     if(ix_det(j) <= 0)cycle
      call track_many(ring, orbit, istart, ix_det(j), 1)
      psp_all%vec(1:6)= (orbit(ix_det(j))%vec(1:6) - co(ix_det(j))%vec(1:6))*1000.
     
      write(51,'(i6,a12,6e12.4)')i,detector(j),psp_all%vec(1:6)
!      if(ix_det(j) == ix_ele)write(52,'(i6,4e12.4)')i,psp_save(i)%vec(1:4)

      istart = ix_det(j)
    end do

    if(ix_end > ix_start)then
       call track_many(ring, orbit, ix_start, ix_end, 1, 0, track_state)
       if(track_state /= moving_forward$) exit
       psp_save(i)%vec(1:6) = (orbit(ix_end)%vec(1:6) - co(ix_end)%vec(1:6))*1000.
       call track_many(ring, orbit, ix_end, ring%n_ele_track, 1, 0, track_state)
       if(track_state /= moving_forward$) exit
       orbit(0)%vec = orbit(ring%n_ele_track)%vec
       call track_many(ring, orbit, 0, ix_start, 1, 0, track_state)
       if(track_state /= moving_forward$) exit

     else
       call track_many(ring, orbit, ix_start, ring%n_ele_track, 1, 0, track_state)
       if(track_state /= moving_forward$) exit
       orbit(0)%vec = orbit(ring%n_ele_track)%vec
       call track_many(ring, orbit, 0, ix_end, 1, 0, track_state)
       if(track_state /= moving_forward$) exit
       psp_save(i)%vec(1:6) = (orbit(ix_end)%vec(1:6) - co(ix_end)%vec(1:6))*1000.
       call track_many(ring, orbit, ix_end, ix_start, 1, 0, track_state)
       if(track_state /= moving_forward$) exit

    endif

      do j=1,ring%n_ele_track
       if(abs(orbit(j)%vec(1))>0.045)print '(2i5,a12,4f12.4)',i,j,ring%ele(j)%name, orbit(j)%vec(1:4)
      enddo
    if(track_state /= moving_forward$)exit

    write(51,'(i6,a12,6e12.4)')i,end_name(1:ix),psp_all%vec(1:6)
    write(52,'(i6,6e12.4)')i,psp_save(i)%vec(1:6)

  end do
   close(unit=51)
   close(unit=52)
   print *,' Write phase space data at cesr BPMs to: phase_space_cesr_bpm.dat'
   print *,' Write phase space data at cesr BPMs to: phase_space_start.dat'
  number_turns = i-1
  print *,' Number of turns = ', number_turns
  traj%vec = orbit(0)%vec

  xscale=0.
  xscalep=0.
  do i=1,number_turns
    psx(i) = psp_save(i)%vec(1)
    psxp(i) = psp_save(i)%vec(2)
    xscale = max(abs(psp_save(i)%vec(1)),xscale)
    xscalep = max(abs(psp_save(i)%vec(2)),xscalep)
  end do

  yscale=0.
  yscalep=0.
  do i=1,number_turns
    psy(i) = psp_save(i)%vec(3)
    psyp(i) = psp_save(i)%vec(4)
    yscale = max(abs(psp_save(i)%vec(3)),yscale)
    yscalep = max(abs(psp_save(i)%vec(4)),yscalep)
  end do
    
  zscale=0.
  zscalep=0.
  do i=1,number_turns
    psz(i) = psp_save(i)%vec(5)
    pszp(i) = psp_save(i)%vec(6)
    zscale = max(abs(psp_save(i)%vec(5)),zscale)
    zscalep = max(abs(psp_save(i)%vec(6)),zscalep)
  end do

  if(.not. already_open)then
     istat2 =  pgopen('/XSERVE')
     if(istat2 >= 0)already_open = .true.
     icall = 1
  endif
    device_type = '/XSERVE'
99  if(device_type(1:7) /= '/XSERVE')istat2 = pgopen(device_type)

!  icall = icall +1
  call pgslct(istat2)
  call pgpap(4.5,2.2)
  call pgsubp(1,3)
       call pgscr(0, 1., 1., 1.)
       call pgscr(1,0.,0.,0.)
       call pgscr(2, 1., 0., 0.)
       call pgscr(3,0.,0.,0.,1.0)
  call pgsch(2.)     
  call pgask(.false.)
  call pgsci(icall)

  call pgenv(-yscale, yscale, -yscalep, yscalep,0,1)
  title = ' vertical phase space at '//ring%ele(ix_end)%name
  call pglab('y(mm)','yp',title)
  call pgpt(number_turns, psy, psyp, 18)

  call pgenv(-xscale, xscale, -xscalep, xscalep,0,1)
  title = ' horizontal phase space at '//ring%ele(ix_end)%name
  call pglab('x(mm)','xp', title)
  call pgpt(number_turns, psx, psxp, 18)

  call pgenv(-zscale, zscale, -zscalep, zscalep,0,1)
  title = ' longitudinal phase space at '//ring%ele(ix_end)%name
  call pglab('l(mm)','Delta E/E 0.1%', title)
  call pgpt(number_turns, psz, pszp, 18)

  if(device_type(1:7) == '/XSERVE')then
   answer = ' '
   print '(a,$)', ' Hardcopy?, Postscript("PS") or Gif ("Gif") '
   read(5,'(a)', err=30) answer
   call str_upcase(answer, answer)
   if(index(answer, 'PS') /= 0 .or. index(answer,'GIF') /= 0)then
     if(index(answer, 'PS') /= 0)device_type = 'phase_space.ps/VCPS' 
     if(index(answer, 'GIF') /= 0)device_type = 'phase_space.gif/VGIF' 
     goto 99
   endif
  endif

30  if(device_type(1:7) /= '/XSERVE') then
   print *,' write ',device_type(1:index(device_type,'/')-1)
   if(istat2 > 0)call pgslct(istat2)
   call pgclos
   already_open = .false.
  endif

  deallocate(psx,psxp,psy,psyp,psz,pszp)
  deallocate(psp_save)

  return
  end

  subroutine plot_elements(ring, start, end)

  use bmad
  use bmad_struct

  implicit none
  type(lat_struct)ring
  type (ele_struct) ele
  real(rp) begin
  real*4 x(4), y(4), xavg, y0, start, end, width
  integer i, ix
  integer n/4/
  character*16 word


  call pgenv(start, end,-10.,10.,0,0)
  call pgsch(1.3)
  do i =1,ring%n_ele_track
   begin = ring%ele(i-1)%s
   ele = ring%ele(i)
   if(ele%key /= sbend$ .and. ele%key /= quadrupole$ .and.ele%key /= rbend$ &
            .and. ele%key /= sextupole$ .and. ele%key /= rfcavity$)cycle
   if(ele%key == sbend$ .or. ele%key == rbend$)then
     width = 1.
     call pgsci(1)
   endif    
   if(ele%key == quadrupole$)then
     width = 2.
     call pgsci(2)
   endif
   if(ele%key == sextupole$)then
     width = 1.5
     call pgsci(5)
   endif    
   if(ele%key == rfcavity$)then
     width = 0.5
     call pgsci(6)
   endif    
   x(1) = begin
   x(2) = begin
   x(3) = ele%s
   x(4) = ele%s
   y(1) = -width
   y(2) = width
   y(3) = width
   y(4) = -width
   xavg = 0.5*(x(1)+x(3))
   y0 = -5.
   call pgpoly(n,x(1:4), y(1:4)) 
   call string_trim(ele%name, word, ix)
   call pgptxt(xavg, y0,90.,0.5,word(1:ix))
  end do

  call pgsch(2.)
  return
 end
