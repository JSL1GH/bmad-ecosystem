!+
! Subroutine tao_init_lattice (input_file_name)
!
! Subroutine to initialize the design lattices.
!
! Input:
!   input_file_name  -- character(*): file name containing lattice file
!                                             namestructs
!
! Output:
!    %u(:)%design -- Initialized design lattices.
!-

subroutine tao_init_lattice (input_file_name)

use tao_mod, except => tao_init_lattice
use tao_input_struct
use ptc_interface_mod

implicit none

type (tao_design_lat_input) design_lattice(0:200), design_lat
type (tao_universe_struct), pointer :: u, u_work

character(*) input_file_name
character(200) full_input_name, init_lat_file
character(40) unique_name_suffix, suffix
character(20) :: r_name = 'tao_init_lattice'
character(16) aperture_limit_on

integer i, j, k, n, iu, ios, version, taylor_order, ix, key, n_universes

logical custom_init, combine_consecutive_elements_of_like_name
logical common_lattice
logical err

namelist / tao_design_lattice / design_lattice, taylor_order, &
       combine_consecutive_elements_of_like_name, unique_name_suffix, &
       aperture_limit_on, common_lattice, n_universes

! Defaults

design_lattice%file   = ''
design_lattice%file2  = ''
design_lattice%language = ''
design_lattice%use_line = ''

design_lat = design_lattice(0)

! Read lattice info

call tao_hook_init_read_lattice_info (input_file_name)

if (tao_com%init_read_lat_info) then

  ! input_file_name == '' means there is no lattice file so just use the defaults.

  if (input_file_name /= '') then
    call tao_open_file (input_file_name, iu, full_input_name, s_fatal$)
    call out_io (s_blank$, r_name, '*Init: Opening File: ' // full_input_name)
    if (iu == 0) then
      call out_io (s_fatal$, r_name, 'ERROR OPENING TAO LATTICE INFO FILE. WILL EXIT HERE...')
      call err_exit
    endif
  endif

  ! Defaults

  common_lattice = .false.
  n_universes = tao_com%n_universes
  taylor_order = 0
  combine_consecutive_elements_of_like_name = .false.
  unique_name_suffix = ''
  aperture_limit_on = ''

  if (input_file_name /= '') then
    read (iu, nml = tao_design_lattice, iostat = ios)
    if (ios /= 0) then
      call out_io (s_abort$, r_name, 'TAO_DESIGN_LATTICE NAMELIST READ ERROR.')
      rewind (iu)
      do
        read (iu, nml = tao_design_lattice)  ! force printing of error message
      enddo
    endif
    close (iu)
  endif

  if (taylor_order /= 0) call set_taylor_order (taylor_order)
  tao_com%combine_consecutive_elements_of_like_name = combine_consecutive_elements_of_like_name
  tao_com%common_lattice = common_lattice
  tao_com%n_universes = n_universes
  tao_com%aperture_limit_on = aperture_limit_on
  tao_com%unique_name_suffix = unique_name_suffix
endif

!

if (tao_com%common_lattice) then
  allocate (s%u(0:tao_com%n_universes))
  allocate (tao_com%u_working)

  if (any(design_lattice(2:)%file /= '')) then
    call out_io (s_fatal$, r_name, 'ONLY ONE LATTICE MAY BE SPECIFIED WHEN USING COMMON_LATTICE')
    call err_exit
  endif

else
  allocate (s%u(tao_com%n_universes))
  nullify (tao_com%u_working)
endif

! Read in the lattices

init_lat_file = tao_com%lat_file

do i = lbound(s%u, 1), ubound(s%u, 1)

  u => s%u(i)
  u%is_on = .true.          ! turn universe on
  u%ix_uni = i
  u%calc%rad_int_for_data = .false.
  u%calc%rad_int_for_plotting = .false.
  u%calc%chrom   = .false.

  ! If unified then only read in a lattice for the common universe.

  if (tao_com%common_lattice .and. i /= ix_common_uni$) cycle

  ! Get the name of the lattice file

  if (init_lat_file /= '') then
    ix = index (init_lat_file, '|') ! Indicates multiple lattices
    if (ix == 0) then
      design_lat%file = init_lat_file
    else
      design_lat%file = init_lat_file(1:ix-1)
      init_lat_file = init_lat_file(ix+1:)
    endif
    design_lat%language = ''
    design_lat%file2 = ''
  else
    ! If %file is blank then default is to use last one
    if (design_lattice(i)%file /= '') design_lat = design_lattice(i)
  endif

  ! Can happen when design_lattice(1) is set and not design_lattice(0)

  if (tao_com%common_lattice .and. design_lat%file == '') then
    design_lat = design_lattice(i+1)
  endif

  ! Split off language name and/or use_line if needed

  ix = index(design_lat%file(1:10), '::')
  if (ix == 0) then
    design_lat%language = 'bmad'
  else
    design_lat%language = design_lat%file(1:ix-1)
    design_lat%file = design_lat%file(ix+2:)
  endif

  ix = index(design_lat%file, '@')
  if (ix /= 0) then
    design_lat%use_line = design_lat%file(ix+1:)
    design_lat%file = design_lat%file(:ix-1)
  else
    design_lat%use_line = ''
  endif

  ! If the lattice file was obtained from the tao init file and if the lattice name 
  ! is relative, then it is relative to the directory where the tao init file is.

  if (tao_com%lat_file == '' .and. file_name_is_relative(design_lat%file)) &
                design_lat%file = trim(tao_com%init_tao_file_path) // design_lat%file 

  ! Read in the design lattice. 
  ! A blank means use the lattice form universe 1.

  allocate (u%design, u%base, u%model)
  select case (design_lat%language)
  case ('bmad')
    call bmad_parser (design_lat%file, u%design%lat, use_line = design_lat%use_line, err_flag = err)
  case ('xsif')
    call xsif_parser (design_lat%file, u%design%lat, use_line = design_lat%use_line, err_flag = err)
  case ('aml')
    call aml_parser (design_lat%file, u%design%lat, err_flag = err)
  case ('digested')
    call out_io (s_blank$, r_name, &
                "Reading digested BMAD file " // trim(design_lat%file))
    call read_digested_bmad_file (design_lat%file, u%design%lat, version)
    err = (bmad_inc_version$ /= version)
  case default
    call out_io (s_abort$, r_name, 'LANGUAGE NOT RECOGNIZED: ' // design_lat%language)
    call err_exit
  end select

  ! When reading digested files there are parser errors associated with, for example, the file
  ! having been moved. Do not exit for such stuff.

  if (design_lat%language /= 'digested' .and. err) then
    call out_io (s_fatal$, r_name, &
            'PARSER ERROR DETECTED FOR UNIVERSE: \i0\ ', &
            'EXITING...', & 
            i_array = (/ i /))
    stop
  endif

  u%design%modes%a%emittance = u%design%lat%a%emit
  u%design%modes%b%emittance = u%design%lat%b%emit

  if (tao_com%combine_consecutive_elements_of_like_name) &
                              call combine_consecutive_elements(u%design%lat)

  if (tao_com%unique_name_suffix /= '') then
    call tao_string_to_element_id (tao_com%unique_name_suffix, key, suffix, err, .true.)
    if (err) call err_exit
    call create_unique_ele_names (u%design%lat, key, suffix)
  endif

  ! Call bmad_parser2 if wanted

  if (design_lat%file2 /= '') then
    call bmad_parser2 (design_lat%file2, u%design%lat)
  endif

  ! Aperture limit

  if (tao_com%aperture_limit_on /= '') then
    read (tao_com%aperture_limit_on, *) u%design%lat%param%aperture_limit_on
    do j = 1, ubound(u%design%lat%branch, 1)
      u%design%lat%branch(j)%param%aperture_limit_on = u%design%lat%param%aperture_limit_on
    enddo
  endif

  if (u%design%lat%param%lattice_type == circular_lattice$ .and. .not. s%global%rf_on) then
    call out_io (s_info$, r_name, &
            "Note: global%rf_on = False  -->  RFCavities will be turned off in lattices")
    call calc_z_tune(u%design%lat)
    call set_on_off (rfcavity$, u%design%lat, off$)
  endif

  ! Custom stuff

  call tao_hook_init_lattice_post_parse (u)

  ! In case there is a match element with match_end = T, propagate the twiss parameters which
  ! makes the beginning Twiss of the match element match the end Twiss of the previous element

  if (u%design%lat%param%lattice_type == linear_lattice$) then
    call twiss_propagate_all (u%design%lat)
  endif

  ! Init model, base, and u%ele

  n = ubound(u%design%lat%branch, 1)
  allocate (u%model%lat_branch(0:n))
  allocate (u%design%lat_branch(0:n))
  allocate (u%base%lat_branch(0:n))
  allocate (u%uni_branch(0:n))

  do k = 0, ubound(u%design%lat%branch, 1)
    n = u%design%lat%branch(k)%n_ele_max
    allocate (u%model%lat_branch(k)%orbit(0:n), u%model%lat_branch(k)%bunch_params(0:n))
    allocate (u%design%lat_branch(k)%orbit(0:n), u%design%lat_branch(k)%bunch_params(0:n))
    allocate (u%base%lat_branch(k)%orbit(0:n), u%base%lat_branch(k)%bunch_params(0:n))
    allocate (u%uni_branch(k)%ele(-1:n))
  enddo

  u%model = u%design
  u%base  = u%design

enddo

! Working lattice setup

if (tao_com%common_lattice) then

  u_work => tao_com%u_working
  u_work%common     => s%u(ix_common_uni$)
  allocate (u_work%design, u_work%base, u_work%model)
  u_work%design%lat = u_work%common%design%lat
  u_work%base%lat   = u_work%common%base%lat
  u_work%model%lat  = u_work%common%model%lat

  n = ubound(u_work%design%lat%branch, 1)
  allocate (u_work%model%lat_branch(0:n))
  allocate (u_work%design%lat_branch(0:n))
  allocate (u_work%base%lat_branch(0:n))
  allocate (u_work%uni_branch(0:n))

  do k = 0, ubound(u_work%design%lat%branch, 1)
    n = u_work%design%lat%branch(k)%n_ele_max
    allocate (u_work%model%lat_branch(k)%orbit(0:n), u_work%model%lat_branch(k)%bunch_params(0:n))
    allocate (u_work%design%lat_branch(k)%orbit(0:n), u_work%design%lat_branch(k)%bunch_params(0:n))
    allocate (u_work%base%lat_branch(k)%orbit(0:n), u_work%base%lat_branch(k)%bunch_params(0:n))
    allocate (u_work%uni_branch(k)%ele(-1:n))
  enddo

  ! If unified then point back to the common universe (#1) and the working universe (#2)

  do i = lbound(s%u, 1), ubound(s%u, 1)
    if (i == ix_common_uni$) cycle
    u => s%u(i)
    u%common     => s%u(ix_common_uni$)
    u%uni_branch => s%u(ix_common_uni$)%uni_branch
    u%design => s%u(ix_common_uni$)%design
    u%base   => s%u(ix_common_uni$)%model  ! Base is identical to common model
    u%model  => tao_com%u_working%model
  enddo

endif

end subroutine tao_init_lattice
