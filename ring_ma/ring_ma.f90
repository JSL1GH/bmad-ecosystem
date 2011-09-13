program ring_ma
  use bmad
  use correct_ring_mod
  use dr_misalign_mod
  use ran_state, only: ran_seed
  use sim_bpm_mod ! from bsim_cesr
  implicit none


  integer, parameter :: n_corrections_max = 4
  integer, parameter :: n_ma_max = 30

!==========================================================================
! Parameters for the input file

  character*200 lattice_file, output_file, comment
  real(rp) :: det_abs_res, det_diff_res, det_rot_res
  real(rp) :: alignment_multiplier=1.
  real(rp) :: sigma_cutoff=3.
  integer :: seed = 0, n_iterations, n_lm_iterations, n_bad_seeds
  logical :: write_orbits=.false.
  real(rp) :: key_value1, key_value2
  type(ma_struct) :: ma(n_ma_max)
  type(correct_struct) :: correct(n_corrections_max)

  type data_struct
     real(rp) emit_x, emit_y, rms_x, rms_y, rms_eta_y, rms_cbar12, &
          rms_phi_x, rms_phi_y, rms_param
  end type data_struct
  type(data_struct), allocatable :: datablock(:,:)

  real(rp) rms_param

  type(lat_struct) :: design_ring        ! straight from the lattice file
  type(lat_struct) :: ma_ring            ! misaligned

  type(coord_struct), allocatable :: co(:)
  type(normal_modes_struct) modes
  integer rad_cache, i_ele, i_correction, ix_suffix, time(8), i_iter

  character*200 init_file, base_name, out_file, opt_file
  logical everything_ok

  ! for sim_bpm_mod:
  type(det_error_struct) :: bpm_error_sigmas
  type(det_struct), allocatable :: bpm(:)
  integer :: n_bpms = 0, i
  real(rp) :: bpm_noise = 0., current = 750000


  namelist /ring_ma_init/ lattice_file, seed, n_iterations, output_file, &
       comment, n_lm_iterations, correct, &
       write_orbits, key_value1, key_value2, ma, &
       alignment_multiplier, sigma_cutoff, &
       bpm_error_sigmas, bpm_noise

!==========================================================================
! Get init file from command line

  if (cesr_iargc() .ne. 1) then
     !write(*,*) "usage: ring_ma <init_file>"
     !stop
     init_file = 'ring_ma.in'
  else
     call cesr_getarg(1, init_file)
  endif
  open(1, file=init_file)
  read(1, nml=ring_ma_init)
  close(1)

!==========================================================================
! Initialize random-number generator from time or with specific value

  if (seed < 1) then
     seed = 0 ! seed randomizer with CPU time
  end if
  call ran_seed_put(seed)

!==========================================================================
! Transfer the parameters from the input file to the appropriate structures

  dr_misalign_params%alignment_multiplier = alignment_multiplier
  dr_misalign_params%sigma_cutoff         = sigma_cutoff
  correct_ring_params%sigma_cutoff        = sigma_cutoff
  correct_ring_params%n_lm_iterations     = n_lm_iterations

  dr_misalign_params%accumulate_errors    = .false.
  dr_misalign_params%tie_dup_ele          = .true.
  correct_ring_params%eta_delta_e_e       = 1.e-3
  correct_ring_params%write_elements      = .true.
  correct_ring_params%skip_dup_ele        = .true.

!==========================================================================
! Setup file names

  ix_suffix = index(init_file, ".", .true.)
  if (ix_suffix > 0) then
     base_name = init_file(:ix_suffix-1)
  else
     base_name = init_file
  end if
  out_file = trim(base_name) // ".out"

!==========================================================================
! Read in design ring from lattice and do some intialization


  if (match_wild(lattice_file, "*.xsif")) then
     call fullfilename(lattice_file, lattice_file)
     call xsif_parser(lattice_file, design_ring)
  else
     call bmad_parser(lattice_file, design_ring)
  end if

  do i_ele = 1, design_ring%n_ele_max
     if (design_ring%ele(i_ele)%key == wiggler$) &
          design_ring%ele(i_ele)%map_with_offsets = .false.
  end do

  write(*,'(A)') "--------------------------"
  write(*,'(A)') "Turning off RF cavities..."
  write(*,'(A)') "--------------------------"
  call set_on_off(rfcavity$, design_ring, off$)

  call twiss_and_track(design_ring, co)
  if (write_orbits) then
     opt_file = trim(base_name)//".design"
     write(*,*) "Writing design orbit file: ", trim(opt_file)
     open(2, file=opt_file, recl=250)
     call write_opt(design_ring, co)
     close(2)
  end if

  allocate(datablock(n_iterations, 0:n_corrections_max))
  call reallocate_coord(cr_model_co, design_ring%n_ele_track)

  call find_bpms(design_ring, correct(1)%bpm_mask, bpm)
  n_bpms = size(bpm)

  ! Find resolution in terms of button signal error:
  call resolution_to_button_error(bpm(1), current, bpm_noise)
  bpm(:)%butn_res_sigma = bpm(1)%butn_res_sigma

!==========================================================================
! Start iterations

  bmad_status%exit_on_error = .false.
  open(1,file=out_file, recl=250)
  write(1,'("#",A)') trim(comment)
  write(1,'("# Random seed: ",i0)') seed
  rad_cache = 0
  do i_iter = 1, n_iterations
     write(*,*) "============================================"
     write(*,*) "Starting iteration:        ", i_iter

     ! Catch when things are too far off
     n_bad_seeds = 0
     do
        ma_ring = design_ring
        call dr_misalign(ma_ring, ma)
        co(0)%vec = 0.
        call twiss_and_track (ma_ring, co, everything_ok)
        if (everything_ok) exit
        n_bad_seeds = n_bad_seeds + 1
        if (n_bad_seeds > 5) then
           write(*,'(A)') "Couldn't find any good seeds."
           write(*,'(A)') "Perhaps the misalignment parameters are too severe."
           stop
        end if
     end do

     open(unit=47, file='bpms.ma', status='replace')
     write(47, '(a7,7a14)') "!index", "x-offset", "y-offset", "tilt", "g1", "g2", "g3", "g4"
     write(47, '(a7, 7a14)') ""

     ! generate persistent BPM errors-- these are fixed for each correction, but 
     ! vary between random magnet misalignment seeds.
     do i=1,n_bpms
        call bpm_errors(bpm(i), bpm_error_sigmas)
        write(47, '(i7,7e14.4)') bpm(i)%ix_db, bpm(i)%x_offset, &
             bpm(i)%y_offset, bpm(i)%tilt, bpm(i)%gain(:)
     enddo
     close(47)

     call radiation_integrals(ma_ring, co, modes, rad_cache)
     call release_rad_int_cache(rad_cache)

     i_correction = 0
     if (write_orbits) then
        write(opt_file, '(A,".opt.",i3.3)') trim(base_name), i_iter
        write(*,*) "Writing optimization file: ", trim(opt_file)
        open(2, file=opt_file, recl=250)
        call write_opt(ma_ring, co)
     end if

     write(*,'(A,2es12.4)') 'Emittance:', modes%a%emittance, modes%b%emittance
 
     ! Store initial values
     call ring_to_data(ma_ring, co, modes, datablock(i_iter, 0))
     call write_data(datablock, i_iter, 0)

     ! Apply correction(s)
     do i_correction = 1, n_corrections_max
        rms_param = 0.
        if (len(trim(correct(i_correction)%cor(1)%param_name)) == 0) cycle
        cr_model_ring = design_ring
        call correct_ring(ma_ring, bpm, correct(i_correction), rms_param)
        call twiss_and_track(ma_ring, co)

        if (write_orbits) call write_opt(ma_ring, co)

        call radiation_integrals(ma_ring, co, modes, rad_cache)
        call release_rad_int_cache(rad_cache)
        call ring_to_data(ma_ring, co, modes, datablock(i_iter, i_correction))
        call write_data(datablock, i_iter, i_correction)
        write(*,'(A,2es12.4)') 'Emittance:', modes%a%emittance, modes%b%emittance
     end do
     if (write_orbits) close(2)
     correct_ring_params%write_elements = .false.
     if (i_iter == n_iterations) call write_ma_ring(ma_ring, ma, correct)
  end do

  ! Write summary
  call write_data(datablock)
  close(1)

contains
!==========================================================================
! Routine for writing out the complete element-by-element
! parameters for every seed. Can generate a LOT of output.

  subroutine write_opt(ring, co)
    implicit none
    type(lat_struct) :: ring
    type(coord_struct) :: co(:)
    integer i_ele
    real(rp) cbar(2,2)

    write(2,'(2A5,9A13,A18)') '# cor', 'ele', 's', 'x', 'y', 'eta_x', 'eta_y', &
         'phi_a', 'phi_b', 'cbar12', 'length', 'name'
    do i_ele = 1, ring%n_ele_track
       call c_to_cbar(ring%ele(i_ele), cbar)
       write(2,'(2i5,9es13.4,a18)') i_correction, i_ele, ring%ele(i_ele)%s, &
            co(i_ele)%vec(1), co(i_ele)%vec(3), &
            ring%ele(i_ele)%x%eta, ring%ele(i_ele)%y%eta, &
            ring%ele(i_ele)%a%phi - design_ring%ele(i_ele)%a%phi, &
            ring%ele(i_ele)%b%phi - design_ring%ele(i_ele)%b%phi, &
            cbar(1,2), ring%ele(i_ele)%value(l$), trim(ring%ele(i_ele)%name)
    end do
    write(2,*)
    write(2,*)
  end subroutine write_opt

!==========================================================================
! Routine to transfer relevant parameters from a ring to the DATABLOCK

  subroutine ring_to_data(ring, co, modes, data)
    implicit none
    type(lat_struct), intent(in) :: ring
    type(coord_struct), intent(in) :: co(:)
    type(normal_modes_struct), intent(in) :: modes
    type(data_struct), intent(out) :: data
    real(rp) l, ltot, cbar(2,2)
    integer i_ele

    ! Emittances
    data%emit_x = modes%a%emittance
    data%emit_y = modes%b%emittance

    ! RMS values
    data%rms_x = 0.
    data%rms_y = 0.
    data%rms_eta_y = 0.
    data%rms_cbar12 = 0.
    data%rms_phi_x = 0.
    data%rms_phi_y = 0.
    ltot = 0.
    do i_ele = 1, ring%n_ele_track
       call c_to_cbar(ring%ele(i_ele), cbar)
       l = ring%ele(i_ele)%value(l$)
       ltot = ltot + l
       data%rms_x      = data%rms_x      + l * co(i_ele)%vec(1)**2
       data%rms_y      = data%rms_y      + l * co(i_ele)%vec(3)**2
       data%rms_eta_y  = data%rms_eta_y  + l * ring%ele(i_ele)%y%eta**2
       data%rms_cbar12 = data%rms_cbar12 + l * cbar(1,2)**2
       data%rms_phi_x  = data%rms_phi_x  + l * (mod(ring%ele(i_ele)%a%phi - design_ring%ele(i_ele)%a%phi, twopi))**2
       data%rms_phi_y  = data%rms_phi_y  + l * (mod(ring%ele(i_ele)%b%phi - design_ring%ele(i_ele)%b%phi, twopi))**2
    end do
    data%rms_x      = sqrt(data%rms_x / ltot)
    data%rms_y      = sqrt(data%rms_y / ltot)
    data%rms_eta_y  = sqrt(data%rms_eta_y / ltot)
    data%rms_cbar12 = sqrt(data%rms_cbar12 / ltot)
    data%rms_phi_x  = sqrt(data%rms_phi_x / ltot)
    data%rms_phi_y  = sqrt(data%rms_phi_y / ltot)
    data%rms_param  = rms_param
  end subroutine ring_to_data

!==========================================================================
! Routine to write out the results of an individual seed, OR to write
! a summary table

  subroutine write_data(data, iter, cor)
    implicit none
    type(data_struct), allocatable, intent(in) :: data(:,:)
    integer, intent(in), optional :: iter, cor
    integer i_cor

    if (present(iter)) then
       if (iter==1 .and. cor==0) then
          write(1,'("#",2a6,11a14)') "iter", "cor", "emit_x", "emit_y", "rms_x", "rms_y", &
               "rms_eta_y", "rms_cbar12", "rms_phi_x", "rms_phi_y", &
               "param_rms", "key_val1", "key_val2"
       end if
       write(1,'("D",2i6,11es14.5)') iter, cor, &
            data(iter, cor)%emit_x, &
            data(iter, cor)%emit_y, &
            data(iter, cor)%rms_x, &
            data(iter, cor)%rms_y, &
            data(iter, cor)%rms_eta_y, &
            data(iter, cor)%rms_cbar12, &
            data(iter, cor)%rms_phi_x, &
            data(iter, cor)%rms_phi_y, &
            data(iter, cor)%rms_param, &
            key_value1, key_value2
    else
       write(1,*)
       write(1,'(a)') "# Summary"
       write(1, '("#",a6,a10,6a14)') "cor", "param", "key_val1", "key_val2", "mean", "sigma", "50pct", "95pct"
       do i_cor = 0, n_corrections_max
          if (i_cor > 0) then
             if (all(correct(i_cor)%cor(:)%param == 0)) cycle
          end if
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "emit_x",  key_value1, key_value2, data_line(data(:,i_cor)%emit_x)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "emit_y",  key_value1, key_value2, data_line(data(:,i_cor)%emit_y)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "orbit_x", key_value1, key_value2, data_line(data(:,i_cor)%rms_x)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "orbit_y", key_value1, key_value2, data_line(data(:,i_cor)%rms_y)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "eta_y",   key_value1, key_value2, data_line(data(:,i_cor)%rms_eta_y)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "cbar12",  key_value1, key_value2, data_line(data(:,i_cor)%rms_cbar12)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "phi_x",   key_value1, key_value2, data_line(data(:,i_cor)%rms_phi_x)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "phi_y",   key_value1, key_value2, data_line(data(:,i_cor)%rms_phi_y)
          write(1, '(" ",i6,a10,6es14.5)') i_cor, "param",   key_value1, key_value2, data_line(data(:,i_cor)%rms_param)
       end do
    end if
  end subroutine write_data


!==========================================================================
! Routine to write misaligned and corrected lattice to a file
  subroutine write_ma_ring(ma_ring, ma_params, correct)
    implicit none
    type(lat_struct), intent(in), target :: ma_ring
    type(ma_struct), intent(in), target :: ma_params(:)
    type(correct_struct), intent(in), target :: correct(:)
    type(ma_struct), pointer :: ma
    type(ele_struct), pointer :: ele
    type(detcor_grp), pointer :: cor
    integer i_param, i_ele, i_cor, ix, jx


    open(unit=23,file='ma_lat.bmad',status='replace')
    write(23,'(a)') '! Misalignments and errors: '
    do i_param = 1, size(ma_params)
       if (ma_params(i_param)%amp == 0) cycle
       ma => ma_params(i_param)       
       do i_ele = 1, ma_ring%n_ele_max 
          ele => ma_ring%ele(i_ele)
          if (ele%key /= ma%key) cycle
          if (match_reg(ele%name,'#')) cycle
          if (.not. (ma%mask == "" .or. match_reg(ele%name, ma%mask))) cycle
          write(23,'(4a,es12.3)') trim(ele%name), '[', trim(attribute_name(ele, ma%param)), &
               '] := ', ele%value(ma%param)
       end do
       
    end do
    
    write(23,'(a)') ''
    write(23,'(a)') ''
    write(23,'(a)') '! Corrections:'
    write(23,'(a)') ''
    write(23,'(a)') ''

    corLoop1: do i_cor = 1, size(correct)
       corLoop2: do i_param = 1, size(correct(i_cor)%cor)
          cor => correct(i_cor)%cor(i_param)
          if (cor%param == 0) cycle ! empty element; ignore
          eleLoop: do i_ele = 1, ma_ring%n_ele_max 
             ele => ma_ring%ele(i_ele)
             if (match_reg(ele%name,'#')) cycle eleLoop
             if (.not. match_reg(trim(ele%name), trim(cor%mask))) cycle eleLoop
             !write(*,*) '"',trim(ele%name), '"  "', trim(cor%mask),'"'
             write(23,'(4a,es12.3)') trim(ele%name), '[', trim(attribute_name(ele, cor%param)), &
                  '] := ', ele%value(cor%param)
          end do eleLoop
       end do corLoop2
    end do corLoop1

    close(23)

  end subroutine write_ma_ring
  
!==========================================================================
! Routine to compute statistical summary information for an array

  function data_line(array)
    use nr
    implicit none

    real(rp) :: data_line(4)
    real(rp), intent(in) :: array(:)
    integer indx(size(array)), k50, k95

    ! Compute mean and standard deviation
    call avevar(array, data_line(1), data_line(2))
    data_line(2) = sqrt(data_line(2))

    ! Compute quantiles if we have enough seeds
    if (size(array) > 10) then
       call indexx(array, indx)
       k50 = ceiling(.50 * size(array))
       k95 = ceiling(.95 * size(array))
       data_line(3) = array(indx(k50))
       data_line(4) = array(indx(k95))
    else
       data_line(3:4) = -1
    end if
  end function data_line

end program ring_ma
