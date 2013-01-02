!+
! Subroutine read_digested_bmad_file (digested_file, lat, inc_version, err_flag)
!
! Subroutine to read in a digested file. The subroutine will check that
! the version of the digested file is up to date and that the digested file
! is current with respect to the original BMAD files that were used. [See
! write_digested_bmad_file.]
!
! Note: This subroutine also reads in the common structures for bmad_parser2
!
! Modules Needed:
!   use bmad
!
! Input:
!   digested_file -- Character(*): Name of the digested file.
!
! Output:
!   lat         -- lat_struct: Output lattice structure
!   inc_version -- Integer: bmad_inc_version number stored in the lattice file.
!                   If the file is current this number should be the same 
!                   as the global parameter bmad_inc_version$. 
!                   Set to -1 if there is a read error.
!   err_flag    -- Logical, optional: Set True if there is an error. False otherwise.
!-

subroutine read_digested_bmad_file (digested_file, lat, inc_version, err_flag)

use ptc_interface_mod, dummy => read_digested_bmad_file

implicit none

type (lat_struct), target, intent(inout) :: lat
type (branch_struct), pointer :: branch
type (ran_parsing_struct) :: ran_state
type (ptc_parameter_struct) ptc_param

real(rp) value(num_ele_attrib$)

integer inc_version, d_unit, n_files, file_version, i, j, k, ix, ix_value(num_ele_attrib$)
integer stat_b(13), stat_b2, stat_b8, stat_b10, n_branch, n, control_type, coupler_at, idum1
integer ierr, stat, ios, n_wall_section, garbage, idum2, j1, j2

character(*) digested_file
character(200) fname_read, fname_versionless, fname_full
character(200) input_file_name, full_digested_file, digested_prefix_in, digested_prefix_out
character(200), allocatable :: file_names(:)
character(60) p_name
character(25) :: r_name = 'read_digested_bmad_file'

logical, optional :: err_flag
logical deterministic_ran_function_used, is_ok
logical found_it, can_read_this_old_version, mode3, error, is_match, err, err_found

! init all elements in lat

if (present(err_flag)) err_flag = .true.
err_found = .false.

call init_lat (lat)

! Read the digested file.
! Some old versions can be read even though they are not the current version.

d_unit = lunget()
inc_version = -1
lat%n_ele_track = 0
deterministic_ran_function_used = .false.

call fullfilename (digested_file, full_digested_file)
inquire (file = full_digested_file, name = full_digested_file)
call simplify_path (full_digested_file, full_digested_file)
open (unit = d_unit, file = full_digested_file, status = 'old',  &
                     form = 'unformatted', action = 'READ', err = 9000)

read (d_unit, err = 9010) n_files, file_version
allocate (file_names(n_files))

! Version is old but recent enough to read.

can_read_this_old_version = .false.

if (file_version < bmad_inc_version$) then
  if (global_com%type_out) call out_io (s_info$, r_name, &
         ['DIGESTED FILE VERSION OUT OF DATE \i0\ > \i0\ ' ],  &
          i_array = [bmad_inc_version$, file_version ])
  if (can_read_this_old_version) then 
    err_found = .true.
  else
    close (d_unit)
    return
  endif
endif

if (file_version > bmad_inc_version$) then
  if (global_com%type_out) call out_io (s_info$, r_name, &
       'DIGESTED FILE HAS VERSION: \i0\ ', &
       'GREATER THAN VERSION OF THIS PROGRAM: \i0\ ', &
       'WILL NOT USE THE DIGESTED FILE. YOU SHOULD RECOMPILE THIS PROGRAM.', &
       i_array = [file_version, bmad_inc_version$ ])
  close (d_unit)
  return
endif

! if the digested file is out of date then we still read in the file since
! we can possibly reuse the taylor series.

do i = 1, n_files

  stat_b = 0

  read (d_unit, err = 9020, end = 9020) fname_read, stat_b2, stat_b8, stat_b10, idum1, idum2
  file_names(i) = fname_read

  ! Cannot use full file name to check if this is the original digested file since
  ! the path may change depending upon what system the program is running on and how
  ! things are mounted. So use stat() instead

  if (fname_read(1:10) == '!DIGESTED:') then
  fname_read = fname_read(11:)
    ierr = stat(full_digested_file, stat_b)
    ! Time stamp in file is created while file is being written to so is not accurate.
    is_match = (stat_b2 == stat_b(2))            !!!! .and. (stat_b10 == stat_b(10))
    j1 = len_trim(fname_read)
    j2 = len_trim(full_digested_file)
    do j = 0, min(j1, j2) - 1
      if (fname_read(j1-j:j1-j) /= full_digested_file(j2-j:j2-j)) exit
    enddo
    digested_prefix_in = fname_read(1:j1-j)
    digested_prefix_out = full_digested_file(1:j2-j)
    if (.not. is_match) then
      if (global_com%type_out .and. .not. err_found) &
                      call out_io(s_info$, r_name, ' NOTE: MOVED DIGESTED FILE.')
      err_found = .true.
    endif
    cycle
  endif

  if (fname_read == '!RAN FUNCTION WAS CALLED') then ! Not deterministic
    err_found = .true.
    cycle
  endif

  if (fname_read == '!DETERMINISTIC RAN FUNCTION WAS CALLED') then
    deterministic_ran_function_used = .true.
    cycle
  endif

  if (fname_read(1:7) == '!PRINT:') cycle  ! Only print at end if no errors.

  call simplify_path (fname_read, fname_read)

  is_ok = .true.
  if (digested_prefix_in /= '') then
    if (index(fname_read, trim(digested_prefix_in)) == 1) then
      ix = len_trim(digested_prefix_in)
      fname_read = fname_read(ix+1:)
    else
      is_ok = .false.
    endif
  endif
  if (digested_prefix_out /= '') then
    fname_read = trim(digested_prefix_out) // trim(fname_read)
  endif
  ierr = stat(fname_read, stat_b)
  fname_versionless = fname_read
  is_match = (stat_b2 == stat_b(2)) .and. (stat_b10 == stat_b(10))

  inquire (file = fname_versionless, exist = found_it, name = fname_full)
  call simplify_path (fname_full, fname_full)
  if (.not. found_it .or. fname_read /= fname_full .or. .not. is_match) then
    if (global_com%type_out .and. .not. err_found) &
            call out_io(s_info$, r_name, 'NOTE: DIGESTED FILE OUT OF DATE.')
    err_found = .true.
  endif

enddo

! Read bmad_com structure

read (d_unit, err = 9025) bmad_com

! we read (and write) the lat in pieces since it is
! too big to write in one piece

read (d_unit, err = 9030)  &   
        lat%use_name, lat%lattice, lat%input_file_name, lat%title, &
        lat%a, lat%b, lat%z, lat%param, lat%version, lat%n_ele_track, &
        lat%n_ele_track, lat%n_ele_max, lat%lord_state, &
        lat%n_control_max, lat%n_ic_max, lat%input_taylor_order, &
        lat%absolute_time_tracking, lat%rf_auto_scale_phase, &
        lat%rf_auto_scale_amp, lat%use_ptc_layout, lat%pre_tracker

! custom attribute names

read (d_unit, err = 9035) n
if (n > 0) then
  allocate (lat%attribute_alias(n))
  do i = 1, n
    read (d_unit, err = 9035) lat%attribute_alias(i)
  enddo
endif

! Allocate lat%ele, lat%control and lat%ic arrays

call allocate_lat_ele_array(lat, lat%n_ele_max+10)
call reallocate_control (lat, lat%n_control_max+10)

!

branch => lat%branch(0)
do i = 0, lat%n_ele_max
  call read_this_ele(lat%ele(i), i, error)
  if (error) return
enddo

do i = 1, lat%n_control_max
  read (d_unit, err = 9040) lat%control(i)
enddo

do i = 1, lat%n_ic_max
  read (d_unit, err = 9050) lat%ic(i)
enddo

read (d_unit, err = 9060) lat%beam_start

! read branch lines

read (d_unit, err = 9070) n_branch
call allocate_branch_array (lat, n_branch)  ! Initial allocation

do i = 0, n_branch
  branch => lat%branch(i)
  branch%ix_branch = i
  read (d_unit, err = 9070) branch%param
  read (d_unit, err = 9070) branch%name, branch%ix_root_branch, branch%ix_from_branch, &
                 branch%ix_from_ele, branch%ix_to_ele, &
                 branch%n_ele_track, branch%n_ele_max, idum1

  call allocate_lat_ele_array (lat, branch%n_ele_max, i)
  do j = 0, branch%n_ele_max
    call read_this_ele (branch%ele(j), j, error)
    if (error) return
  enddo

  call read_this_wall3d (branch%wall3d, error)
  if (error) return
enddo

! Read PTC info

read (d_unit, iostat = ios) ptc_param
if (ios /= 0) then
  if (global_com%type_out) call out_io(s_error$, r_name, 'ERROR READING PTC PARAMETERS.')
  close (d_unit)
  return
endif

if (ios == 0) then
  call set_ptc (exact_modeling = ptc_param%exact_model, exact_misalign = ptc_param%exact_misalign)
endif

! Read random state info.
! At this point in time this is not used.

read (d_unit, iostat = ios) ran_state

! Setup any attribute aliases in the global attribute name table.
! This is done last in read_digested bmad_file so as to not to pollute the name table if 
! there is an error.

if (.not. err_found .and. allocated(lat%attribute_alias)) then
  do i = 1, size(lat%attribute_alias)
    p_name = lat%attribute_alias(i)
    ix = index(lat%attribute_alias(i), '=')
    call set_attribute_alias(p_name(1:ix-1), p_name(ix+1:), err)
    if (err) err_found = .true.
  enddo
endif

! And finish

close (d_unit)

lat%param%stable = .true.  ! Assume this 
inc_version = file_version

if (present(err_flag)) err_flag = err_found

if (.not. err_found .and. global_com%type_out) then
  do i = 1, size(file_names)
    fname_read = file_names(i)
    if (fname_read(1:7) /= '!PRINT:') cycle
    call out_io (s_dwarn$, r_name, 'Print Message in Lattice File: ' // fname_read(8:))
  enddo
endif

return

!------------------

9000  continue
!! if (global_com%type_out) call out_io (s_warn$, r_name, 'Digested file does not exist: ' // trim(full_digested_file))
close (d_unit)
return

!--------------------------------------------------------------

9010  continue
if (global_com%type_out) call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE VERSION.')
close (d_unit)
return

!--------------------------------------------------------------

9020  continue
if (global_com%type_out) call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE FILE AND DATE.')
close (d_unit)
return

!--------------------------------------------------------------

9025  continue
if (global_com%type_out) call out_io(s_error$, r_name, 'ERROR READING BMAD_COM COMMON BLOCK.')
close (d_unit)
return

!--------------------------------------------------------------

9030  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE LATTICE GLOBALS.')
endif
close (d_unit)
return

!--------------------------------------------------------------

9035  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE GENERAL PARAMETER NAME LIST.')
endif
close (d_unit)
return

!--------------------------------------------------------------

9040  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE CONTROL.')
endif
close (d_unit)
return

!--------------------------------------------------------------

9050  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE IC.')
endif
close (d_unit)
return

!--------------------------------------------------------------

9060  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED BEAM_INIT.')
endif
close (d_unit)
return

!--------------------------------------------------------------

9070  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE BRANCH DATA.')
endif
close (d_unit)
return

!--------------------------------------------------------------

9080  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED RANDOM NUMBER STATE.')
endif
close (d_unit)
return

!-----------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------
contains

subroutine read_this_ele (ele, ix_ele_in, error)

type (ele_struct), target :: ele
type (em_field_mode_struct), pointer :: mode

integer i, j, lb1, lb2, lb3, ub1, ub2, ub3, nf, ng, ix_ele, ix_branch, ix_wall3d
integer n_em_field_mode, i_min(3), i_max(3), ix_ele_in
integer ix_wig, ix_r, ix_wig_branch, idum1, idum2, idum3, idum4, ix_d, ix_m, ix_t(6), ios, k_max
integer ix_sr_table, ix_sr_mode_long, ix_sr_mode_trans, ix_lr, ix_wall3d_branch

logical error

!

error = .true.

if (file_version >= 99) then
  read (d_unit, err = 9100) mode3, ix_wig, ix_wig_branch, ix_r, ix_wall3d_branch, &
          idum2, idum3, ix_d, ix_m, ix_t, ix_sr_table, ix_sr_mode_long, ix_sr_mode_trans, &
          ix_lr, ix_wall3d, n_em_field_mode, idum4
  read (d_unit, err = 9100) &
          ele%name, ele%type, ele%alias, ele%component_name, ele%x, ele%y, &
          ele%a, ele%b, ele%z, ele%gen0, ele%vec0, ele%mat6, &
          ele%c_mat, ele%gamma_c, ele%s, ele%key, ele%floor, &
          ele%is_on, ele%sub_key, ele%lord_status, ele%slave_status, ele%ix_value, &
          ele%n_slave, ele%ix1_slave, ele%ix2_slave, ele%n_lord, &
          ele%ic1_lord, ele%ic2_lord, ele%ix_pointer, ele%ixx, &
          ele%ix_ele, ele%mat6_calc_method, ele%tracking_method, &
          ele%spin_tracking_method, ele%symplectify, ele%mode_flip, &
          ele%multipoles_on, ele%map_with_offsets, ele%Field_master, &
          ele%logic, ele%old_is_on, ele%field_calc, ele%aperture_at, &
          ele%aperture_type, ele%on_a_girder, ele%csr_calc_on, ele%orientation, &
          ele%map_ref_orb_in, ele%map_ref_orb_out, ele%offset_moves_aperture, &
          ele%ix_branch, ele%ref_time, ele%scale_multipoles, idum1, &
          idum2, ele%bookkeeping_state, ele%ptc_integration_type
endif

! Decompress value array

read (d_unit, err = 9110) k_max
read (d_unit, err = 9120) ix_value(1:k_max), value(1:k_max)
do k = 1, k_max
  ele%value(ix_value(k)) = value(k)
enddo

! RF field def

call init_em_field (ele%em_field, n_em_field_mode)
if (n_em_field_mode > 0) then
  do i = 1, n_em_field_mode
    mode => ele%em_field%mode(i)
    read (d_unit, err = 9140) nf, ng, ix_ele, ix_branch, mode%harmonic, mode%f_damp, mode%dphi0_ref, &
                         mode%stored_energy, mode%m, mode%phi0_azimuth, mode%field_scale, mode%master_scale

    if (ix_ele /= 0) then
      mode%map  => lat%branch(ix_branch)%ele(ix_ele)%em_field%mode(i)%map
      if (associated(mode%map)) mode%map%n_link = mode%map%n_link + 1
      mode%grid => lat%branch(ix_branch)%ele(ix_ele)%em_field%mode(i)%grid
      if (associated(mode%grid)) mode%grid%n_link = mode%grid%n_link + 1
      cycle
    endif

    if (nf > 0) then
      allocate (mode%map)
      allocate (mode%map%term(nf))
      read (d_unit, err = 9140) mode%map%file, mode%map%dz, mode%map%ele_anchor_pt
      read (d_unit, err = 9140) mode%map%term
    endif

    if (ng > 0) then
      allocate (mode%grid)
      read (d_unit, err = 9140) lb1, ub1, lb2, ub2, lb3, ub3, mode%grid%type, mode%grid%file, &
                                mode%grid%dr, mode%grid%r0, mode%grid%ele_anchor_pt
      allocate (mode%grid%pt(lb1:ub1, lb2:ub2, lb3:ub3))
      do j = lb3, ub3
        read (d_unit, err = 9140) mode%grid%pt(:,:,j)
      enddo
    endif

  enddo
endif

! Mode3

if (mode3) then
  allocate(ele%mode3)
  read (d_unit, err = 9150) ele%mode3
endif

if (ix_wig > 0) then
  allocate (ele%wig)
  ele%wig%n_link = 1
  allocate (ele%wig%term(ix_wig))
  do j = 1, ix_wig
    read (d_unit, err = 9200) ele%wig%term(j)
  enddo
elseif (ix_wig < 0) then  ! Points to another wiggler with same field
  ele%wig => lat%branch(ix_wig_branch)%ele(abs(ix_wig))%wig
  ele%wig%n_link = ele%wig%n_link + 1
endif

if (ix_r /= 0) then
  read (d_unit, err = 9350) i_min, i_max
  allocate (ele%r(i_min(1):i_max(1), i_min(2):i_max(2), i_min(3):i_max(3)))
  do i = i_min(3), i_max(3)
    read (d_unit, err = 9400) ele%r(:,:,i)
  enddo
endif

if (ix_d /= 0) then
  allocate (ele%descrip)
  read (d_unit, err = 9500) ele%descrip
endif

if (ix_m /= 0) then
  call multipole_init (ele)
  read (d_unit, err = 9600) ele%a_pole, ele%b_pole
endif
  
do j = 1, 6
  if (ix_t(j) == 0) cycle
  read (d_unit, err = 9650) ele%taylor(j)%ref
  allocate (ele%taylor(j)%term(ix_t(j)))
  do k = 1, ix_t(j)
    read (d_unit, err = 9700) ele%taylor(j)%term(k)
  enddo
enddo

! If ix_lr is negative then it is a pointer to a previously read wake. 
! See write_digested_bmad_file.

if (ix_sr_table /= 0 .or. ix_sr_mode_long /= 0 .or. ix_sr_mode_trans /= 0 .or. ix_lr /= 0) then
  if (ix_lr < 0) then
    call transfer_rf_wake (branch%ele(abs(ix_lr))%rf_wake, ele%rf_wake)

  else
    call init_wake (ele%rf_wake, ix_sr_table, ix_sr_mode_long, ix_sr_mode_trans, ix_lr)
    read (d_unit, err = 9800) ele%rf_wake%sr_file
    read (d_unit, err = 9810) ele%rf_wake%sr_table
    read (d_unit, err = 9840) ele%rf_wake%sr_mode_long
    read (d_unit, err = 9850) ele%rf_wake%sr_mode_trans
    read (d_unit, err = 9820) ele%rf_wake%lr_file
    read (d_unit, err = 9830) ele%rf_wake%lr
    read (d_unit, err = 9860) ele%rf_wake%z_sr_mode_max
  endif
endif

if (ix_wall3d > 0) then
  call read_this_wall3d (ele%wall3d, error)
  if (error) return
elseif (ix_wall3d < 0) then
  read (d_unit, err = 9900) idum1
  ele%wall3d => lat%branch(ix_wall3d_branch)%ele(abs(ix_wall3d))%wall3d
  if (.not. associated(ele%wall3d)) then
    if (global_com%type_out) then
      call out_io(s_error$, r_name, 'ERROR IN WALL3D INIT.')
    endif
    close (d_unit)
    return
  endif
  ele%wall3d%n_link = ele%wall3d%n_link + 1
else
  read (d_unit, err = 9900) idum1
endif

!

ele%value(check_sum$) = 0
if (associated(ele%a_pole)) ele%value(check_sum$) = sum(ele%a_pole) + sum(ele%b_pole)
 
ele%old_value = ele%value

error = .false.

return

!--------------------------------------------------------------

9100  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                 'ERROR READING ELEMENT # \i0\ ', &
                                  i_array = [ix_ele_in])
endif
close (d_unit)
return

9110  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                 'ERROR READING K_MAX OF ELEMENT # \i0\ ', &
                                  i_array = [ix_ele_in])
endif
close (d_unit)
return

9120  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                 'ERROR READING VALUES OF ELEMENT # \i0\ ', &
                                  i_array = [ix_ele_in])
endif
close (d_unit)
return

9140  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
        'ERROR READING EM_FIELD COMPONENT FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9150  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
        'ERROR READING MODE3 COMPONENT FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9200  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
        'ERROR READING WIGGLER TERM FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9350  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING %R ARRAY SIZE: ' // ele%name)
endif
close (d_unit)
return

9400  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING R TERM FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9500  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING DESCRIP TERM FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9600  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING AN,BN TERMS FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9650  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING %TAYLOR(:)%REF FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9700  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING TAYLOR TERMS FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9800  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%SR_FILE FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9810  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%sr_table FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9820  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%LR_FILE FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9830  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%LR FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9840  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%sr_mode_long FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9850  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%sr_mode_trans FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9860  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING WAKE%Z_CUT_SR FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

9900  continue
if (global_com%type_out) then
   call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
          'ERROR READING IDUM1 FOR ELEMENT: ' // ele%name)
endif
close (d_unit)
return

end subroutine

!-----------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------
! contains

subroutine read_this_wall3d (wall3d, error)

type (wall3d_struct), pointer :: wall3d

integer j, k, n_wall_section, ios
logical error

!

error = .true.

read (d_unit, iostat = ios) n_wall_section
if (n_wall_section == 0) then
  error = .false.
  return
endif

if (ios /= 0) then
  if (global_com%type_out) then
     call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                   'ERROR READING WALL3D N_WALL_SECTION NUMBER')
  endif
  close (d_unit)
  return
endif

allocate(wall3d)
read (d_unit, iostat = ios) wall3d%ele_anchor_pt, wall3d%priority, &
      wall3d%crotch%location, wall3d%crotch%ix_section, &
      wall3d%crotch%ix_v1_cut, wall3d%crotch%ix_v2_cut
if (ios /= 0) then
  if (global_com%type_out) then
     call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                   'ERROR READING WALL PRIORITY')
  endif
  close (d_unit)
  return
endif

call re_allocate (wall3d%section, n_wall_section)

do j = 1, n_wall_section
  call read_this_wall3d_section (wall3d%section(j))
enddo

if (wall3d%crotch%ix_section /= 0) call read_this_wall3d_section(wall3d%crotch%section)

error = .false.

end subroutine

!-----------------------------------------------
! contains

subroutine read_this_wall3d_section (sec)

type (wall3d_section_struct), target :: sec
type (wall3d_vertex_struct), pointer :: v
integer nv

!

read (d_unit, iostat = ios) sec%type, sec%s, sec%x0, sec%y0, sec%dx0_ds, sec%dy0_ds, sec%x0_coef, sec%y0_coef, &
                 sec%dr_ds, sec%p1_coef, sec%p2_coef, nv, sec%n_vertex_input
if (ios /= 0) then
  if (global_com%type_out) then
     call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                   'ERROR READING WALL3D SECTION')
  endif
  close (d_unit)
  return
endif

allocate(sec%v(nv))
do k = 1, nv
  read (d_unit, iostat = ios) sec%v(k)
  if (ios /= 0) then
    if (global_com%type_out) then
       call out_io(s_error$, r_name, 'ERROR READING DIGESTED FILE.', &
                                     'ERROR READING WALL3D VERTEX')
    endif
    close (d_unit)
    return
  endif
enddo

end subroutine read_this_wall3d_section

end subroutine
