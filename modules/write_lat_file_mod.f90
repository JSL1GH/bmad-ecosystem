module write_lat_file_mod

use bmad_struct
use bmad_interface
use multipole_mod
use multipass_mod
use element_modeling_mod
use lat_ele_loc_mod

private str, rchomp, cmplx_str, write_line_element, array_str

contains

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+ 
! Subroutine write_bmad_lattice_file (bmad_file, lat, err)
!
! Subroutine to write a Bmad lattice file using the information in
! a lat_struct. Optionally only part of the lattice can be generated.
!
! Modules needed:
!   use write_lat_file_mod
!
! Input:
!   bmad_file     -- Character(*): Name of the output lattice file.
!   lat           -- lat_struct: Holds the lattice information.
!   ix_start      -- Integer, optional: Starting index of lat%ele(i)
!                       used for output.
!   ix_end        -- Integer, optional: Ending index of lat%ele(i)
!                       used for output.
!
! Output:
!   err    -- Logical, optional: Set True if, say a file could not be opened.
!-

subroutine write_bmad_lattice_file (bmad_file, lat, err)

implicit none

type multipass_info_struct
  integer ix_region
  logical region_start_pt
  logical region_stop_pt
end type

type (multipass_info_struct), allocatable :: multipass(:)

type (ele_attribute_struct) attrib
type (lat_struct), target :: lat
type (branch_struct), pointer :: branch
type (ele_struct), pointer :: ele, super, slave, lord, s1, s2, multi_lord, slave2, ele2, ele_dflt
type (ele_struct), target :: ele_default(n_key)
type (wig_term_struct) wt
type (control_struct) ctl
type (taylor_term_struct) tm
type (multipass_all_info_struct), target :: m_info
type (rf_wake_lr_struct), pointer :: lr
type (ele_pointer_struct), pointer :: ss1(:), ss2(:)
type (em_field_mode_struct), pointer :: mode
type (em_field_grid_struct), pointer :: grid
type (em_field_map_struct), pointer :: map
type (wall3d_section_struct), pointer :: section
type (wall3d_vertex_struct), pointer :: v
real(rp) s0, x_lim, y_lim, val

character(*) bmad_file
character(4000) line
character(4) end_str
character(4) last
character(40) name, look_for, attrib_name
character(200) wake_name, file_name, path, basename
character(40), allocatable :: names(:)
character(200), allocatable, save :: sr_wake_name(:), lr_wake_name(:)
character(40) :: r_name = 'write_bmad_lattice_file'
character(10) angle

integer i, j, k, n, ix, iu, iu2, iuw, ios, ixs, n_sr, n_lr, ix1, ie, ib, ic, ic2
integer unit(6), n_names, ix_match, ie2, id1, id2, id3
integer ix_slave, ix_ss, ix_l, ix_r, ix_pass
integer ix_top, ix_super, default_val
integer, allocatable :: an_indexx(:)

logical, optional :: err
logical unit_found, write_term, found, in_multi_region, expand_lat_out
logical is_multi_sup, x_lim_good, y_lim_good, is_default, need_new_region

! Init...
! Init default parameters

do i = 1, size(ele_default)
  call init_ele (ele_default(i), i)
  call set_ele_defaults (ele_default(i))
enddo

! Count the number of foreign wake files

if (present(err)) err = .true.

n_sr = 0
n_lr = 0
do ie = 1, lat%n_ele_max
  ele => lat%ele(ie)
  if (.not. associated(ele%rf_wake)) cycle
  if (ele%rf_wake%sr_file(1:6) == 'xsif::') n_sr = n_sr + 1 
  if (ele%rf_wake%lr_file(1:6) == 'xsif::') n_lr = n_lr + 1  
enddo
call re_allocate(sr_wake_name, n_sr)
call re_allocate(lr_wake_name, n_lr)

n_sr = 0
n_lr = 0

! Open the file

iu = lunget()
call fullfilename (bmad_file, file_name)
open (iu, file = file_name, iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN FILE: ' // trim(bmad_file))
  return
endif

! Non-elemental stuff

if (lat%title /= ' ')            write (iu, '(4a)')    'title, "', trim(lat%title), '"'
if (lat%lattice /= ' ')          write (iu, '(4a)')    'parameter[lattice]     = "', trim(lat%lattice), '"'

write (iu, '(4a)') 'parameter[lattice_type] = ', lattice_type(lat%param%lattice_type)

if (lat%input_taylor_order /= 0) write (iu, '(a, i0)') 'parameter[taylor_order] = ', lat%input_taylor_order

write (iu, *)
write (iu, '(4a)')    'parameter[p0c]                    =', trim(str(lat%ele(0)%value(p0c_start$)))
write (iu, '(4a)')    'parameter[particle]               = ', particle_name(lat%param%particle)

if (.not. lat%param%aperture_limit_on) write (iu, '(4a)')    'parameter[aperture_limit_on]      = F'
if (lat%param%n_part /= 0)             write (iu, '(a, i0)') 'parameter[n_part]                 = ', lat%param%n_part

write (iu, '(a, l1)') 'parameter[rf_auto_scale_phase]    = ', lat%rf_auto_scale_phase
write (iu, '(a, l1)') 'parameter[rf_auto_scale_amp]      = ', lat%rf_auto_scale_amp
write (iu, '(a, l1)') 'parameter[absolute_time_tracking] = ', lat%absolute_time_tracking
write (iu, '(a, l1)') 'parameter[no_end_marker]          = ', .true.

ele => lat%ele(0) 

if (ele%floor%x /= 0)      write (iu, '(2a)') 'beginning[x_position]     = ', trim(str(ele%floor%x))
if (ele%floor%y /= 0)      write (iu, '(2a)') 'beginning[y_position]     = ', trim(str(ele%floor%y))
if (ele%floor%z /= 0)      write (iu, '(2a)') 'beginning[z_position]     = ', trim(str(ele%floor%z))
if (ele%floor%theta /= 0)  write (iu, '(2a)') 'beginning[theta_position] = ', trim(str(ele%floor%theta))
if (ele%floor%phi /= 0)    write (iu, '(2a)') 'beginning[phi_position]   = ', trim(str(ele%floor%phi))
if (ele%floor%psi /= 0)    write (iu, '(2a)') 'beginning[psi_position]   = ', trim(str(ele%floor%psi))

if (ele%s /= 0)            write (iu, '(2a)') 'beginning[s]        = ', trim(str(ele%s))
if (ele%ref_time /= 0)     write (iu, '(2a)') 'beginning[ref_time] = ', trim(str(ele%ref_time))

if (lat%param%lattice_type /= circular_lattice$) then
  write (iu, '(2a)')
  if (ele%a%beta /= 0)     write (iu, '(2a)') 'beginning[beta_a]   = ', trim(str(ele%a%beta))
  if (ele%a%alpha /= 0)    write (iu, '(2a)') 'beginning[alpha_a]  = ', trim(str(ele%a%alpha))
  if (ele%a%phi /= 0)      write (iu, '(2a)') 'beginning[phi_a]    = ', trim(str(ele%a%phi))
  if (ele%a%eta /= 0)      write (iu, '(2a)') 'beginning[eta_a]    = ', trim(str(ele%a%eta))
  if (ele%a%etap /= 0)     write (iu, '(2a)') 'beginning[etap_a]   = ', trim(str(ele%a%etap))
  if (ele%b%beta /= 0)     write (iu, '(2a)') 'beginning[beta_b]   = ', trim(str(ele%b%beta))
  if (ele%b%alpha /= 0)    write (iu, '(2a)') 'beginning[alpha_b]  = ', trim(str(ele%b%alpha))
  if (ele%b%phi /= 0)      write (iu, '(2a)') 'beginning[phi_b]    = ', trim(str(ele%b%phi))
  if (ele%b%eta /= 0)      write (iu, '(2a)') 'beginning[eta_b]    = ', trim(str(ele%b%eta))
  if (ele%b%etap /= 0)     write (iu, '(2a)') 'beginning[etap_b]   = ', trim(str(ele%b%etap))
  if (ele%c_mat(1,1) /= 0) write (iu, '(2a)') 'beginning[cmat_11]  = ', trim(str(ele%c_mat(1,1)))
  if (ele%c_mat(1,2) /= 0) write (iu, '(2a)') 'beginning[cmat_12]  = ', trim(str(ele%c_mat(1,2)))
  if (ele%c_mat(2,1) /= 0) write (iu, '(2a)') 'beginning[cmat_21]  = ', trim(str(ele%c_mat(2,1)))
  if (ele%c_mat(2,2) /= 0) write (iu, '(2a)') 'beginning[cmat_22]  = ', trim(str(ele%c_mat(2,2)))
endif

! Element stuff

write (iu, *)
write (iu, '(a)') '!-------------------------------------------------------'
write (iu, *)

ixs = 0
n_names = 0
allocate (names(lat%n_ele_max), an_indexx(lat%n_ele_max))

do ib = 0, ubound(lat%branch, 1)
  branch => lat%branch(ib)
  ele_loop: do ie = 1, branch%n_ele_max

    ele => branch%ele(ie)
    ele_dflt => ele_default(ele%key)

    multi_lord => pointer_to_multipass_lord (ele, lat, ix_pass) 

    if (ele%key == null_ele$) cycle
    if (ele%slave_status == multipass_slave$) cycle ! Ignore for now
    if (ele%lord_status == super_lord$ .and. ix_pass > 0) cycle
    if (ele%slave_status == super_slave$ .and. ix_pass > 1) cycle

    if (ie == lat%n_ele_track+1) then
      write (iu, *)
      write (iu, '(a)') '!-------------------------------------------------------'
      write (iu, '(a)') '! Overlays, groups, etc.'
      write (iu, *)
    endif

    ! For a super_slave just create a dummy drift. 

    if (ele%slave_status == super_slave$) then
      ixs = ixs + 1
      ele%ixx = ixs
      write (iu, '(a, i3.3, 2a)') 'slave_drift_', ixs, ': drift, l = ', trim(str(ele%value(l$)))
      cycle
    endif

    ! Do not write anything for elements that have a duplicate name.

    call find_indexx (ele%name, names, an_indexx, n_names, ix_match)
    if (ix_match > 0) cycle

    if (size(names) < n_names + 1) then
      call re_allocate(names, 2*size(names))
      call re_allocate(an_indexx, 2*size(names))
    endif
    call find_indexx (ele%name, names, an_indexx, n_names, ix_match, add_to_list = .true.)
    n_names = n_names + 1

    ! Overlays and groups

    if (ele%lord_status == overlay_lord$ .or. ele%lord_status == group_lord$) then
      if (ele%lord_status == overlay_lord$) then
        write (line, '(2a)') trim(ele%name), ': overlay = {'
      else
        write (line, '(2a)') trim(ele%name), ': group = {'
      endif
      j_loop: do j = 1, ele%n_slave
        slave => pointer_to_slave(ele, j, ic)
        ctl = lat%control(ic)
        ! do not use elements w/ duplicate names & attributes
        do k = 1, j-1 
          slave2 => pointer_to_slave(ele, k, ic2)
          if (slave2%name == slave%name .and. lat%control(ic2)%ix_attrib == ctl%ix_attrib) cycle j_loop
        enddo
        ! Now write the slave info
        if (j == 1) then
          write (line, '(3a)') trim(line), trim(slave%name)
        else
          write (line, '(3a)') trim(line), ', ', trim(slave%name)
        endif
        name = attribute_name(slave, ctl%ix_attrib)  
        if (name /= ele%component_name) line = trim(line) // '[' // trim(name) // ']'
        if (ctl%coef /= 1) write (line, '(3a)') trim(line), '/', trim(str(ctl%coef))
      enddo j_loop
      line = trim(line) // '}'
      if (ele%component_name == ' ') then
        line = trim(line) // ', command'
      else
        line = trim(line) // ', ' // ele%component_name
      endif
      if (ele%lord_status == overlay_lord$) then
        ix = ele%ix_value
        if (ele%value(ix) /= 0) write (line, '(3a)') &
                            trim(line), ' = ', str(ele%value(ix))
      endif
      if (ele%type /= ' ') line = trim(line) // ', type = "' // trim(ele%type) // '"'
      if (ele%alias /= ' ') line = trim(line) // ', alias = "' // trim(ele%alias) // '"'
      if (associated(ele%descrip)) line = trim(line) // &
                              ', descrip = "' // trim(ele%descrip) // '"'
      call write_lat_line (line, iu, .true.)
      cycle
    endif

    ! Girder

    if (ele%lord_status == girder_lord$) then
      write (line, '(2a)') trim(ele%name), ': girder = {'
      do j = 1, ele%n_slave
        slave => pointer_to_slave(ele, j)
        if (j == ele%n_slave) then
          write (line, '(3a)') trim(line), trim(slave%name), '}'
        else
          write (line, '(3a)') trim(line), trim(slave%name), ', '
        endif
      enddo
    else
      line = trim(ele%name) // ': ' // key_name(ele%key)
    endif

    ! Branch

    if (ele%key == branch$ .or. ele%key == photon_branch$) then
      n = nint(ele%value(ix_branch_to$))
      line = trim(line) // ', to = ' // trim(lat%branch(n)%name) // '_line'
    endif

    ! Other elements

    if (ele%type /= ' ') line = trim(line) // ', type = "' // trim(ele%type) // '"'
    if (ele%alias /= ' ') line = trim(line) // ', alias = "' // trim(ele%alias) // '"'
    if (associated(ele%descrip)) line = trim(line) // ', descrip = "' // trim(ele%descrip) // '"'

    ! patch_in_slave

    if (ele%slave_status == patch_in_slave$) then
      lord => pointer_to_lord(ele, 1)
      line = trim(line) // ', ref_patch = ' // trim(lord%name)
    endif

    ! Create a null_ele element for a superposition and fill in the superposition
    ! information.

    is_multi_sup = .false.
    if (ele%lord_status == multipass_lord$) then
      ix1 = lat%control(ele%ix1_slave)%ix_slave
      if (lat%ele(ix1)%lord_status == super_lord$) is_multi_sup = .true.
    endif

    if (ele%lord_status == super_lord$ .or. is_multi_sup) then
      write (iu, '(a)') "x__" // trim(ele%name) // ": null_ele"
      line = trim(line) // ', superimpose, ele_beginning, ref = x__' // trim(ele%name)
    endif

    ! Wall

    if (associated(ele%wall3d)) then
      ! First find out out if an wall file has been written
      found = .false.
      do ie2 = 1, ie-1
        ele2 => branch%ele(ie2)
        if (.not. associated(ele2%wall3d)) cycle
        if (.not. associated(ele2%wall3d, ele%wall3d)) cycle
        found = .true.
        exit
      enddo

      if (found) then
        call str_downcase(name, ele2%name)
        line = trim(line) // ', wall = call::wall_' // trim(name)
      else
        call str_downcase(name, ele%name)
        line = trim(line) // ', wall = call::wall_' // trim(name)
        iu2 = lunget()
 
        ix = splitfilename(file_name, path, basename)
        
        open (iu2, file = trim(path) // 'wall_' // trim(name))
        write (iu2, *) '{ &'
        write (iu2, '(2x, 3a)') 'ele_anchor_pt = ', trim(anchor_pt_name(ele%wall3d%ele_anchor_pt)), ','
        do i = 1, size(ele%wall3d%section)
          section => ele%wall3d%section(i)
          write (iu2, '(2x, a)')   'section = {'
          write (iu2, '(4x, 3a)')  's     = ', trim(str(section%s)), ','
          if (section%dr_ds /= real_garbage$) write (iu2, '(4x, 3a)')  'dr_ds = ', trim(str(section%s)), ','
          end_str = ','
          do j = 1, size(section%v)
            if (j == size(section%v)) then
              end_str = '},'
              if (i == size(ele%wall3d%section)) end_str = '}}'
            endif
            v => section%v(j)
            if (v%tilt /= 0) then
              write (iu2, '(4x, a, i0, 3a)') 'v(', j, ') = ', &
                    trim(array_str([v%x, v%y, v%radius_x, v%radius_y, v%tilt], '{}')), end_str
            elseif (v%radius_y /= 0) then
              write (iu2, '(4x, a, i0, 3a)') 'v(', j, ') = ', &
                    trim(array_str([v%x, v%y, v%radius_x, v%radius_y], '{}')), end_str
            elseif (v%radius_x /= 0) then
              write (iu2, '(4x, a, i0, 3a)') 'v(', j, ') = ', &
                    trim(array_str([v%x, v%y, v%radius_x], '{}')), end_str
            else
              write (iu2, '(4x, a, i0, 3a)') 'v(', j, ') = ', &
                    trim(array_str([v%x, v%y], '{}')), end_str
            endif
          enddo
        enddo
        close (iu2)

      endif
    endif

    ! EM fields

    if (associated(ele%em_field)) then

      ! First find out out if an em_file has been written
      found = .false.
      do ie2 = 1, ie-1
        ele2 => branch%ele(ie2)
        if (.not. associated(ele2%em_field)) cycle
        if (.not. (ele%em_field == ele2%em_field)) cycle
        found = .true.
        exit
      enddo

      if (found) then
        call str_downcase(name, ele2%name)
        line = trim(line) // ', field = call::field_' // trim(name)
      else
        call str_downcase(name, ele%name)
        line = trim(line) // ', field = call::field_' // trim(name)
        iu2 = lunget()
 
        ix = splitfilename(file_name, path, basename)
        open (iu2, file = trim(path) // 'field_' // trim(name))
        write (iu2, *) '{ &'
        do i = 1, size(ele%em_field%mode)
          mode => ele%em_field%mode(i)
          if (i > 1) write (iu2, '(a)') '  , &'
          write (iu2, '(2x, a)')      'mode = {'
          write (iu2, '(4x, a, i0, a)') 'm             = ', mode%m, ','
          write (iu2, '(4x, a, i0, a)') 'harmonic      = ', mode%harmonic, ','
          write (iu2, '(4x, 3a)')       'f_damp        = ', trim(str(mode%f_damp)), ','
          write (iu2, '(4x, 3a)')       'dphi0_ref     = ', trim(str(mode%dphi0_ref)), ','
          write (iu2, '(4x, 3a)')       'phi0_azimuth  = ', trim(str(mode%phi0_azimuth)), ','
          if (mode%master_scale > 0) write (iu2, '(3a)') &
                                        'master_scale  = ', trim(attribute_name(ele, mode%master_scale)), ','
          write (iu2, '(4x, 3a)')       'field_scale   = ', trim(str(mode%field_scale)), ','
          if (associated(mode%map)) then
            map => mode%map
            write (iu2, '(4x, a)')  'map = {'
            write (iu2, '(4x, 3a)') 'ele_anchor_pt = ', trim(anchor_pt_name(map%ele_anchor_pt)), ','
            write (iu2, '(4x, 3a)') 'dz            =', trim(str(map%dz)), ' &'
            if (any(real(map%term%e_coef) /= 0)) call write_map_coef ('e_coef_re', real(map%term%e_coef))
            if (any(aimag(map%term%e_coef) /= 0)) call write_map_coef ('e_coef_im', aimag(map%term%e_coef))
            if (any(real(map%term%b_coef) /= 0)) call write_map_coef ('b_coef_re', real(map%term%b_coef))
            if (any(aimag(map%term%b_coef) /= 0)) call write_map_coef ('b_coef_im', aimag(map%term%b_coef))
            write (iu2, '(4x, a)') '} &'
          endif

          if (associated(mode%grid)) then
            grid => mode%grid
            n = em_grid_dimension(grid%type)
            write (iu2, '(4x, a)')   'grid = {'
            write (iu2, '(6x, 3a)')  'type          = ', trim(em_grid_type_name(grid%type)), ','
            write (iu2, '(6x, 4a)')  'dr            = ', trim(array_str(grid%dr(1:n))), ','
            write (iu2, '(6x, 4a)')  'r0            = ', trim(array_str(grid%r0(1:n))), ','
            write (iu2, '(6x, 3a)')  'ele_anchor_pt = ', trim(anchor_pt_name(mode%grid%ele_anchor_pt)), ','
            end_str = '),'
            do id1 = lbound(grid%pt, 1), ubound(grid%pt, 1)
              if (n == 1) then
                if (id1 == ubound(grid%pt, 1)) end_str = ') &'
                write (iu2, '(6x, a, i0, 13a)') 'pt(', id1, ') = (', &
                                                        trim(cmplx_str(grid%pt(id1,1,1)%e(1))), ',', &
                                                        trim(cmplx_str(grid%pt(id1,1,1)%e(2))), ',', &
                                                        trim(cmplx_str(grid%pt(id1,1,1)%e(3))), ',', &
                                                        trim(cmplx_str(grid%pt(id1,1,1)%b(1))), ',', &
                                                        trim(cmplx_str(grid%pt(id1,1,1)%b(2))), ',', &
                                                        trim(cmplx_str(grid%pt(id1,1,1)%b(3))), end_str
                cycle
              endif

              do id2 = lbound(grid%pt, 2), ubound(grid%pt, 2)
                if (n == 2) then
                  if (all([id1, id2, 1] == ubound(grid%pt))) end_str = ') &'
                  write (iu2, '(6x, 2(a, i0), 13a)') 'pt(', id1, ',', id2, ') = (', &
                                                       trim(cmplx_str(grid%pt(id1,id2,1)%e(1))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,1)%e(2))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,1)%e(3))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,1)%b(1))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,1)%b(2))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,1)%b(3))), end_str
                  cycle
                endif

                do id3 = lbound(grid%pt, 3), ubound(grid%pt, 3)
                  if (all([id1, id2, id3] == ubound(grid%pt))) end_str = ') &'
                  write (iu2, '(6x, 3(a, i0), 13a)') 'pt(', id1, ',', id2, ',', id3, ') = (', &
                                                       trim(cmplx_str(grid%pt(id1,id2,id3)%e(1))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,id3)%e(2))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,id3)%e(3))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,id3)%b(1))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,id3)%b(2))), ',', &
                                                       trim(cmplx_str(grid%pt(id1,id2,id3)%b(3))), end_str
                enddo
              enddo
            enddo

            write (iu2, '(4x, a)') '} &'
          endif

          write (iu2, '(2x, a)') '} &'

        enddo
        write (iu2, '(a)') '}'
        close (iu2)
      endif

    endif

    ! If the wake file is not BMAD Format (Eg: XSIF format) then create a new wake file.
    ! If first three characters of the file name are '...' then it is a foreign file.

    if (associated(ele%rf_wake)) then

      ! Short-range

      if (ele%rf_wake%sr_file /= ' ') then

        wake_name = ele%rf_wake%sr_file

        if (wake_name(1:3) == '...') then
          found = .false.
          do n = 1, n_sr
            if (wake_name == sr_wake_name(n)) then
              found = .true.
              exit
            endif
          enddo
          if (.not. found) then
            n = n_sr + 1
            n_sr = n
            sr_wake_name(n_sr) = wake_name
          endif
          write (wake_name, '(a, i0, a)') 'sr_wake_file_', n, '.bmad'
          if (.not. found) then
            call out_io (s_info$, r_name, 'Creating SR Wake file: ' // trim(wake_name))
            iuw = lunget()
            open (iuw, file = wake_name)
            write (iuw, *) '!        z             Wz               Wt'
            write (iuw, *) '!       [m]         [V/C/m]         [V/C/m^2]'
            do n = lbound(ele%rf_wake%sr_table, 1), ubound(ele%rf_wake%sr_table, 1)
              write (iuw, '(3es16.7)') ele%rf_wake%sr_table(n)%z, &
                                    ele%rf_wake%sr_table(n)%long, ele%rf_wake%sr_table(n)%trans
            enddo
            close(iuw)
          endif
        endif

        line = trim(line) // ',  sr_wake_file = "' // trim(wake_name) // '"'

      endif

      ! Long-range

      if (ele%rf_wake%lr_file /= ' ') then

        wake_name = ele%rf_wake%lr_file

        if (wake_name(1:3) == '...') then
          found = .false.
          do n = 1, n_lr
            if (wake_name == lr_wake_name(n)) then
              found = .true.
              exit
            endif
          enddo
          if (.not. found) then
            n = n_lr + 1
            n_lr = n
            lr_wake_name(n_lr) = wake_name
          endif
          write (wake_name, '(a, i0, a)') 'lr_wake_file_', n, '.bmad'
          if (.not. found) then
            call out_io (s_info$, r_name, 'Creating LR Wake file: ' // trim(wake_name))
            iuw = lunget()
            open (iuw, file = wake_name)
            write (iuw, '(14x, a)') &
   'Freq         R/Q        Q       m    Polarization     b_sin         b_cos         a_sin         a_cos         t_ref'
            write (iuw, '(14x, a)') &
              '[Hz]  [Ohm/m^(2m)]             [Rad/2pi]'
            do n = lbound(ele%rf_wake%lr, 1), ubound(ele%rf_wake%lr, 1)
              lr => ele%rf_wake%lr(n)
              if (lr%polarized) then
                write (angle, '(f10.6)') lr%angle
              else
                angle = '     unpol'
              endif
              if (any ( [lr%b_sin, lr%b_cos, lr%a_sin, lr%a_cos, lr%t_ref ]/= 0)) then
                write (iuw, '(a, i0, a, 3es16.7, i6, a, 5es12.2)') 'lr(', n, ') =', lr%freq_in, &
                      lr%R_over_Q, lr%Q, lr%m, angle, lr%b_sin, lr%b_cos, lr%a_sin, lr%a_cos, lr%t_ref
              else
                write (iuw, '(a, i0, a, 3es16.7, i6, a)') 'lr(', n, ') =', &
                      lr%freq_in, lr%R_over_Q, lr%Q, lr%m, angle
              endif
            enddo
            close(iuw)
          endif
        endif

        line = trim(line) // ',  lr_wake_file = "' // trim(wake_name) // '"'

      endif

    endif

    ! Decide if x1_limit, etc. are to be output directly or combined. 

    x_lim = ele%value(x1_limit$) 
    x_lim_good = .false.
    if (x_lim /=0 .and. ele%value(x2_limit$) == x_lim) x_lim_good = .true.

    y_lim = ele%value(y1_limit$) 
    y_lim_good = .false.
    if (y_lim /=0 .and. ele%value(y2_limit$) == y_lim) y_lim_good = .true.

    ! Print the element attributes.

    do j = 1, num_ele_attrib$
      attrib = attribute_record(ele, j)
      val = ele%value(j)
      if (val == 0) cycle
      if (attrib%private) cycle
      if (j == check_sum$) cycle
      if (x_lim_good .and. (j == x1_limit$ .or. j == x2_limit$)) cycle
      if (y_lim_good .and. (j == y1_limit$ .or. j == y2_limit$)) cycle
      if (.not. attribute_free (ele, attrib%name, lat, .false., .true.)) cycle
      if (val == ele_dflt%value(j)) cycle
      if (attrib%name == 'DS_STEP' .and. val == bmad_com%default_ds_step) cycle
      if (attrib%name == null_name$) then
        print *, 'ERROR IN WRITE_BMAD_LATTICE_FILE:'
        print *, '      ELEMENT: ', ele%name
        print *, '      HAS AN UNKNOWN ATTRIBUTE INDEX:', j
        stop
      endif

      if (attrib%name == 'COUPLER_AT') then
        if (nint(val) /= exit_end$) then
          line = trim(line) // ', coupler_at = ' // coupler_at_name(nint(val))
        endif
        cycle
      endif

      select case (attribute_type(attrib%name))
      case (is_logical$)
        write (line, '(4a, l1)') trim(line), ', ', trim(attrib%name), ' = ', (val /= 0)
      case (is_integer$)
        write (line, '(4a, i0)') trim(line), ', ', trim(attrib%name), ' = ', int(val)
      case (is_real$)
        line = trim(line) // ', ' // trim(attrib%name) // ' = ' // str(val)
      case (is_name$)
        name = attribute_value_name (attrib%name, val, ele, is_default)
          if (.not. is_default) then
            line = trim(line) // ', ' // trim(attrib%name) // ' = ' // name
          endif
      end select

    enddo ! attribute loop

    ! Print the combined limits if needed.

    if (x_lim_good .and. y_lim_good .and. x_lim == y_lim) then
      line = trim(line) // ', aperture = ' // str(x_lim)
    else
      if (x_lim_good) line = trim(line) // ', x_limit = ' // str(x_lim)
      if (y_lim_good) line = trim(line) // ', y_limit = ' // str(y_lim)
    endif

    ! Encode methods, etc.

    if (ele_has(ele, 'MAT6_CALC_METHOD') .and. (ele%mat6_calc_method /= ele_dflt%mat6_calc_method)) &
                                      line = trim(line) // ', mat6_calc_method = ' // calc_method_name(ele%mat6_calc_method)
    if (ele_has(ele, 'TRACKING_METHOD') .and. (ele%tracking_method /= ele_dflt%tracking_method)) &
                                      line = trim(line) // ', tracking_method = ' // calc_method_name(ele%tracking_method)
    if (ele_has(ele, 'SPIN_TRACKING_METHOD') .and. (ele%spin_tracking_method /= ele_dflt%spin_tracking_method)) &
                                      line = trim(line) // ', spin_tracking_method = ' // calc_method_name(ele%spin_tracking_method)
    if (ele_has(ele, 'FIELD_CALC') .and. (ele%field_calc /= ele_dflt%field_calc)) &
                                      line = trim(line) // ', field_calc = ' // field_calc_name(ele%field_calc)

    if (ele_has(ele, 'APERTURE_AT') .and. (ele%aperture_at /= ele_dflt%aperture_at)) &
                                      line = trim(line) // ', aperture_at = ' // aperture_at_name(ele%aperture_at)
    if (ele_has(ele, 'APERTURE_TYPE') .and. (ele%aperture_type /= ele_dflt%aperture_type)) &
                                      line = trim(line) // ', aperture_type = ' // aperture_type_name(ele%aperture_type)

    if (ele_has(ele, 'REF_ORBIT') .and. (ele%ref_orbit /= 0)) line = trim(line) // ', ref_orbit = ' // ref_orbit_name(ele%ref_orbit)

    if (ele_has(ele, 'SYMPLECTIFY') .and. ele%symplectify) line = trim(line) // ', symplectify'

    if (ele_has(ele, 'FIELD_MASTER') .and. (ele%field_master .neqv. ele_dflt%field_master)) &
                                      write (line, '(2a, l1)') trim(line), ', field_master = ', ele%field_master
    if (ele_has(ele, 'IS_ON') .and. (ele%is_on .neqv. ele_dflt%is_on)) &
                                      write (line, '(2a, l1)') trim(line), ', is_on = ', ele%is_on
    if (ele_has(ele, 'SCALE_MULTIPOLES') .and. (ele%scale_multipoles .neqv. ele_dflt%scale_multipoles)) &
                                      write (line, '(2a, l1)') trim(line), ', scale_multipoles = ', ele%scale_multipoles
    if (ele_has(ele, 'MAP_WITH_OFFSETS') .and. (ele%map_with_offsets .neqv. ele_dflt%map_with_offsets)) &
                                      write (line, '(2a, l1)') trim(line), ', map_with_offsets = ', ele%map_with_offsets
    if (ele_has(ele, 'CSR_CALC_ON') .and. (ele%csr_calc_on .neqv. ele_dflt%csr_calc_on)) &
                                      write (line, '(2a, l1)') trim(line), ', csr_calc_on = ', ele%csr_calc_on
    if (ele_has(ele, 'OFFSET_MOVES_APERTURE') .and. (ele%offset_moves_aperture .neqv. ele_dflt%offset_moves_aperture)) &
                                      write (line, '(2a, l1)') trim(line), ', offset_moves_aperture = ', ele%offset_moves_aperture

    ! Multipass lord 

    if (ele%key == sbend$ .or. (ele%lord_status == multipass_lord$ .and. .not. ele%field_master)) then
      select case (ele%key)
      case (quadrupole$, sextupole$, octupole$, solenoid$, sol_quad$, sbend$, &
            hkicker$, vkicker$, kicker$, elseparator$, bend_sol_quad$)
        if (ele%value(n_ref_pass$) == 0) then
          line = trim(line) // ', e_tot = ' // str(ele%value(e_tot$))
        else
          write (line, '(2a, i0)') trim(line), ', n_ref_pass = ', nint(ele%value(n_ref_pass$))
        endif
      end select
    endif

    call write_lat_line (line, iu, .false.)  

    ! Encode taylor

    if (ele%key == taylor$) then
      do j = 1, 6
        unit_found = .false.
        unit = 0
        unit(j:j) = 1
        do k = 1, size(ele%taylor(j)%term)
          tm = ele%taylor(j)%term(k)
          write_term = .false.
          if (all(tm%expn == unit)) then
            unit_found = .true.
            if (tm%coef /= 1) write_term = .true.
          else
            write_term = .true.
          endif
          if (write_term) write (line, '(2a, i1, 3a, 6i2, a)') &
                trim(line), ', {', j, ': ', trim(str(tm%coef)), ',', tm%expn, '}'
        enddo
        if (.not. unit_found) write (line, '(2a, i1, a, 6i2, a)') &
                trim(line), ', {', j, ': 0,', tm%expn, '}'
      enddo
    endif

    if (associated(ele%a_pole)) then
      do j = 0, ubound(ele%a_pole, 1)
        if (ele%a_pole(j) /= 0) line = trim(line) // ', ' // &
                trim(attribute_name(ele, j+a0$)) // ' = ' // str(ele%a_pole(j))
        if (ele%b_pole(j) /= 0) line = trim(line) // ', ' // &
                trim(attribute_name(ele, j+b0$)) // ' = ' // str(ele%b_pole(j))
      enddo
    endif
    
    if (ele%key == wiggler$ .and. ele%sub_key == map_type$) then
      line = trim(line) // ', &'
      call write_lat_line (line, iu, .true.)  
      do j = 1, size(ele%wig%term)
        wt = ele%wig%term(j)
        last = '}, &'
        if (j == size(ele%wig%term)) last = '}'
        write (iu, '(a, i3, 11a)') ' term(', j, ')={', trim(str(wt%coef)), ', ', &
          trim(str(wt%kx)), ', ', trim(str(wt%ky)), ', ', trim(str(wt%kz)), &
          ', ', trim(str(wt%phi_z)), trim(last)  
      enddo
    else
      call write_lat_line (line, iu, .true.)  
    endif

  enddo ele_loop
enddo  ! branch loop

!----------------------------------------------------------
! Lattice Layout...

! Multipass stuff...

allocate (multipass(lat%n_ele_max))
multipass(:)%ix_region = 0
multipass(:)%region_start_pt = .false.
multipass(:)%region_stop_pt   = .false.

call multipass_all_info (lat, m_info)

if (size(m_info%top) /= 0) then

  ! Go through and mark all 1st pass regions
  ! In theory the original lattice file could have something like:
  !   lat: line = (..., m1, m2, ..., m1, -m2, ...)
  ! where m1 and m2 are multipass lines. The first pass region (m1, m2) looks 
  ! like this is one big region but the later (m1, -m2) signals that this 
  ! is not so.
  ! We thus go through all the first pass regions and compare them to the
  ! corresponding higher pass regions. If we find two elements that are contiguous
  ! in the first pass region but not contiguous in some higher pass region, 
  ! we need to break the first pass region into two.

  ix_r = 0
  in_multi_region = .false.

  do ie = 1, lat%n_ele_track+1
    ele => lat%ele(ie)
    ix_pass = m_info%bottom(ie)%ix_pass
    if (ix_pass /= 1 .or. ie == lat%n_ele_track+1) then  ! Not a first pass region
      if (in_multi_region) multipass(ie-1)%region_stop_pt = .true.
      in_multi_region = .false.
      cycle
    endif
    ! If start of a new region...
    if (.not. in_multi_region) then  
      ix_r = ix_r + 1
      multipass(ie)%ix_region = ix_r
      multipass(ie)%region_start_pt = .true.
      in_multi_region = .true.
      ix_top = m_info%bottom(ie)%ix_top(1)
      ix_super = m_info%bottom(ie)%ix_super(1)
      ss1 => m_info%top(ix_top)%slave(:,ix_super)
      cycle
    endif
    ix_top = m_info%bottom(ie)%ix_top(1)
    ix_super = m_info%bottom(ie)%ix_super(1)
    ss2 => m_info%top(ix_top)%slave(:, ix_super)

    need_new_region = .false.
    if (size(ss1) /= size(ss2)) then
      need_new_region = .true.
    else
      do ix_pass = 2, size(ss1)
        if (abs(ss1(ix_pass)%ele%ix_ele - ss2(ix_pass)%ele%ix_ele) == 1) cycle
        ! not contiguous then need a new region
        need_new_region = .true.
        exit
      enddo
    endif

    if (need_new_region) then
      ix_r = ix_r + 1
      multipass(ie-1)%region_stop_pt = .true.
      multipass(ie)%region_start_pt = .true.
    endif

    ss1 => ss2
    multipass(ie)%ix_region = ix_r
  enddo

  ! Each 1st pass region is now a valid multipass line.
  ! Write out this info.

  write (iu, *)
  write (iu, '(a)') '!-------------------------------------------------------'

  ix_r = 0
  in_multi_region = .false.

  do ie = 1, lat%n_ele_track

    ix_pass = m_info%bottom(ie)%ix_pass
    if (ix_pass /= 1) cycle 

    if (multipass(ie)%region_start_pt) then
      if (ix_r > 0) then
        line = line(:len_trim(line)-1) // ')'
        call write_lat_line (line, iu, .true.)
      endif
      ix_r = ix_r + 1
      write (iu, *)
      write (line, '(a, i2.2, a)') 'multi_line_', ix_r, ': line[multipass] = ('
    endif

    call write_line_element (line, iu, lat%ele(ie), lat)

  enddo

  line = line(:len_trim(line)-1) // ')'
  call write_lat_line (line, iu, .true.)

end if

! Main line.
! If we get into a multipass region then name in the main_line list is "multi_line_nn".
! But only write this once.

write (iu, *)
line = trim(lat%branch(0)%name) // '_line: line = ('

in_multi_region = .false.
do ie = 1, lat%n_ele_track

  if (.not. m_info%bottom(ie)%multipass) then
    call write_line_element (line, iu, lat%ele(ie), lat)
    cycle
  endif

  ix_top = m_info%bottom(ie)%ix_top(1)
  ix_super = m_info%bottom(ie)%ix_super(1)
  ix1 = m_info%top(ix_top)%slave(1,ix_super)%ele%ix_ele
  ix_r = multipass(ix1)%ix_region

  ! If entering new multipass region
  if (.not. in_multi_region) then
    in_multi_region = .true.
    if (multipass(ix1)%region_start_pt) then
      write (line, '(2a, i2.2, a)') trim(line), ' multi_line_', ix_r, ','
      look_for = 'stop'
    else
      write (line, '(2a, i2.2, a)') trim(line), ' -multi_line_', ix_r, ','
      look_for = 'start'
    endif
  endif

  if (look_for == 'start' .and. multipass(ix1)%region_start_pt .or. &
      look_for == 'stop' .and. multipass(ix1)%region_stop_pt) then 
    in_multi_region = .false.
  endif

enddo

line = line(:len_trim(line)-1) // ')'
call write_lat_line (line, iu, .true.)

write (iu, *)
write (iu, *) 'use, ' // trim(lat%branch(0)%name) // '_line'

! Branch lines

do ib = 1, ubound(lat%branch, 1)

  branch => lat%branch(ib)

  write (iu, *)
  write (iu, '(a)') '!-------------------------------------------------------'
  write (iu, *)
  line = trim(branch%name) // '_line: line = ('

  do ie = 1, branch%n_ele_track
    call write_line_element (line, iu, branch%ele(ie), lat) 
  enddo

  line = line(:len_trim(line)-1) // ')'
  call write_lat_line (line, iu, .true.)

enddo

! If there are multipass lines then expand the lattice and write out
! the post-expand info as needed.

expand_lat_out = .false.
do ie = 1, lat%n_ele_max
  ele => lat%ele(ie)
  if (ele%slave_status == super_slave$) cycle

  if (ele%key == lcavity$ .or. ele%key == rfcavity$) then
    if (ele%value(dphi0$) == 0) cycle
    if (.not. expand_lat_out) call write_expand_lat_header
    write (iu, '(3a)') trim(ele%name), '[dphi0] = ', trim(str(ele%value(dphi0$)))
  endif

  if (ele%key == patch$ .and. ele%ref_orbit /= 0) then
    if (.not. expand_lat_out) call write_expand_lat_header
    if (ele%value(x_offset$) /= 0) write (iu, '(3a)') trim(ele%name), '[x_offset] = ', trim(str(ele%value(x_offset$)))
    if (ele%value(y_offset$) /= 0) write (iu, '(3a)') trim(ele%name), '[y_offset] = ', trim(str(ele%value(y_offset$)))
    if (ele%value(z_offset$) /= 0) write (iu, '(3a)') trim(ele%name), '[z_offset] = ', trim(str(ele%value(z_offset$)))
    if (ele%value(x_pitch$) /= 0)  write (iu, '(3a)') trim(ele%name), '[x_pitch] = ', trim(str(ele%value(x_pitch$)))
    if (ele%value(y_pitch$) /= 0)  write (iu, '(3a)') trim(ele%name), '[y_pitch] = ', trim(str(ele%value(y_pitch$)))
    if (ele%value(tilt$) /= 0)     write (iu, '(3a)') trim(ele%name), '[tilt]    = ', trim(str(ele%value(tilt$)))
  endif

enddo

! cleanup

close(iu)
deallocate (names, an_indexx)
deallocate (multipass)
call deallocate_multipass_all_info_struct (m_info)

if (present(err)) err = .false.

!--------------------------------------------------------------------------------
contains

subroutine write_expand_lat_header ()

write (iu, *)
write (iu, '(a)') '!-------------------------------------------------------'
write (iu, *)
write (iu, '(a)') 'expand_lattice'
write (iu, *)
expand_lat_out = .true.

end subroutine write_expand_lat_header

!--------------------------------------------------------------------------------
! contains

function ele_has (ele, name) result (has_it)

type (ele_struct) ele
character(*) name
logical has_it

!

has_it = (attribute_index(ele, name) > 0)

end function

!--------------------------------------------------------------------------------
! contains

subroutine write_map_coef (tag, array)

real(rp) :: array(:)
character(*) tag
integer j, k, kk, n

!

write (iu2, '(6x, a)')  ', &'
write (iu2, '(6x, 2a)') tag, ' = ('

n = size(array)
do j = 1, n - 5, 5
  k = 5 * (j - 1)
  write (iu2, '(8x, 5(es14.6, a))') (array(k+kk:k+kk), ',', kk = 1, 5) 
enddo

k = 5 * (j - 1) 
write (iu2, '(8x, 5(es14.6, a))') (array(k+kk:k+kk), ',', k = 1, n-k-1), array(n), ') &' 

end subroutine write_map_coef

end subroutine write_bmad_lattice_file

!-------------------------------------------------------
!-------------------------------------------------------
!-------------------------------------------------------

subroutine write_line_element (line, iu, ele, lat)

implicit none

type (lat_struct), target :: lat
type (ele_struct) :: ele
type (ele_struct), pointer :: lord, m_lord, slave

character(*) line
character(40) lord_name

integer iu
integer j, ix

!

if (ele%slave_status == super_slave$) then
  ! If a super_lord element starts at the beginning of this slave element,
  !  put in the null_ele marker 'x__' + lord_name for the superposition.
  do j = 1, ele%n_lord
    lord => pointer_to_lord(ele, j)
    lord_name = lord%name
    m_lord => pointer_to_multipass_lord (lord, lat)
    if (associated(m_lord)) lord_name = m_lord%name
    slave => pointer_to_slave(lord, 1) 
    if (slave%ix_ele == ele%ix_ele) then
      write (line, '(4a)') trim(line), ' x__', trim(lord_name), ',' 
    endif
  enddo
  write (line, '(2a, i3.3, a)') trim(line), ' slave_drift_', ele%ixx, ','

elseif (ele%slave_status == multipass_slave$) then
  lord => pointer_to_lord(ele, 1)
  write (line, '(4a)') trim(line), ' ', trim(lord%name), ','

else
  write (line, '(4a)') trim(line), ' ', trim(ele%name), ','
endif

if (len_trim(line) > 80) call write_lat_line(line, iu, .false.)

end subroutine

!-------------------------------------------------------
!-------------------------------------------------------
!-------------------------------------------------------

function str(rel) result (str_out)

implicit none

real(rp) rel
integer pl
character(24) str_out
character(16) fmt

!

if (rel == 0) then
  str_out = '0'
  return
endif

pl = floor(log10(abs(rel)))

if (pl > 5) then
  fmt = '(2a, i0)'
  write (str_out, fmt) trim(rchomp(rel/10.0**pl, 0)), 'E', pl

elseif (pl > -3) then
  str_out = rchomp(rel, pl)

else
  fmt = '(2a, i0)'
  write (str_out, fmt) trim(rchomp(rel*10.0**(-pl), 0)), 'E', pl

endif

end function str

!-------------------------------------------------------
!-------------------------------------------------------
!-------------------------------------------------------

function array_str(arr, parens_in) result (str_out)

real(rp) arr(:)
integer i
character(100) str_out
character(*), optional :: parens_in
character(2) parens

!

parens = '()'
if (present(parens_in)) parens = parens_in

str_out = parens(1:1) // str(arr(1))
do i = 2, size(arr)
  str_out = trim(str_out) // ', ' // str(arr(i))
enddo
str_out = trim(str_out) // parens(2:2)

end function array_str

!-------------------------------------------------------
!-------------------------------------------------------
!-------------------------------------------------------

function cmplx_str(cmp) result (str_out)

complex(rp) cmp
character(40) str_out

!

str_out = '(' // trim(str(real(cmp))) // ', ' // trim(str(imag(cmp))) // ')'

end function cmplx_str

!-------------------------------------------------------
!-------------------------------------------------------
!-------------------------------------------------------

function rchomp (rel, plc) result (out)

implicit none

real(rp) rel
character(24) out
character(8) :: fmt = '(f24.xx)'
integer it, plc, ix

!

write (fmt(6:7), '(i2.2)') 10-plc
write (out, fmt) rel
do it = len(out), 1, -1
  if (out(it:it) == ' ') cycle
  if (out(it:it) == '0') then
    out(it:it) = ' '
    cycle
  endif
  if (out(it:it) == '.') out(it:it) = ' '
  call string_trim(out, out, ix)
  return
enddo

end function

!-------------------------------------------------------
!-------------------------------------------------------
!-------------------------------------------------------
!+
! Subroutine write_lat_line (line, iu, end_is_neigh, continue_char)
!
! Routine to write strings to a lattice file.
! This routine will break the string up into multiple lines
! if the string is too long and add a continuation character if needed.
!
! If the "line" arg does not represent a full "sentence" (end_is_neigh = False), 
! then only part of the line may be written and the part not writen will be returned.
!
! Module needed:
!   use write_lat_file_mod
!
! Input:
!   line          -- character(*): String of text.
!   iu            -- Integer: Unit number to write to.
!   end_is_neigh  -- Logical: If true then write out everything.
!                      Otherwise wait for a full line of max_char characters or so.
!   continue_char -- character(1), optional. Default is '&'
!
! Output:
!   line          -- Character(*): part of the string not writen. 
!                       If end_id_neight = T then line will be blank.
!-

subroutine write_lat_line (line, iu, end_is_neigh, continue_char)

implicit none

character(*) line
integer i, iu
logical end_is_neigh
logical, save :: init = .true.
integer, save :: max_char = 90
character(1), optional :: continue_char
character(1) c_char

!

if (present(continue_char)) then
 c_char = continue_char
else
 c_char = '&'
end if

outer_loop: do 

  if (len_trim(line) < max_char-4) then
    if (end_is_neigh) then
      call write_this (line)
      init = .true.
    endif
    return
  endif
      
  do i = max_char-6, 1, -1
    if (line(i:i) == ',') then
      call write_this (line(:i) // ' ' // c_char)
      line = line(i+1:)
      cycle outer_loop
    endif
  enddo

  do i = max_char-5, len_trim(line)
    if (line(i:i) == ',') then
      call write_this (line(:i) // ' ' // c_char)
      line = line(i+1:)
      cycle outer_loop
    endif
  enddo

  if (end_is_neigh) then
    call write_this (line)
    init = .true.
    return
  endif

enddo outer_loop

contains

subroutine write_this (line2)

character(*) line2

!

if (init) then
  init = .false.
  write (iu, '(a)') trim(line2)
else
  write (iu, '(2x, a)') trim(line2)
endif

end subroutine

end subroutine

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+ 
! Subroutine bmad_to_mad_or_xsif (out_type, out_file_name, lat, &
!                           use_matrix_model, ix_start, ix_end, converted_lat, err)
!
! Subroutine to write a MAD-8, MAD-X, or XSIF lattice file using the information in
! a lat_struct. Optionally only part of the lattice can be generated.
!
! Note: sol_quad elements are replaced by a drift-matrix-drift or solenoid-quad model.
! Note: wiggler elements are replaced by a drift-matrix-drift or drift-bend model.

! Modules needed:
!   use write_lat_file_mod
!
! Input:
!   out_type      -- Character(*): Either 'XSIF', 'MAD-8', 'MAD-X', or 'OPAL-T'.
!   out_file_name -- Character(*): Name of the mad output lattice file.
!   lat           -- lat_struct: Holds the lattice information.
!   use_matrix_model
!                 -- Logical, optional: Use a drift-matrix_drift model for wigglers
!                       and sol_quad elements? Default is False.
!   ix_start      -- Integer, optional: Starting index of lat%ele(i)
!                       used for output.
!   ix_end        -- Integer, optional: Ending index of lat%ele(i)
!                       used for output.
!
! Output:
!   converted_lat -- Lat_struct, optional: Equivalent Bmad lattice with wiggler and 
!                       sol_quad elements replaced by their respective models.
!   err           -- Logical, optional: Set True if, say a file could not be opened.
!-

subroutine bmad_to_mad_or_xsif (out_type, out_file_name, lat, &
                          use_matrix_model, ix_start, ix_end, converted_lat, err)

implicit none

type (lat_struct), target :: lat, lat_out, lat_model
type (lat_struct), optional :: converted_lat
type (ele_struct), pointer :: ele, ele1, ele2, lord
type (ele_struct), save :: drift_ele, ab_ele, taylor_ele, col_ele, kicker_ele
type (taylor_term_struct) :: term

real(rp) field, hk, vk, tilt, limit(2)
real(rp), pointer :: val(:)
real(rp) knl(0:n_pole_maxx), tilts(0:n_pole_maxx), a_pole(0:n_pole_maxx), b_pole(0:n_pole_maxx)

integer, optional :: ix_start, ix_end
integer i, j, j2, k, n, ix, i_unique, i_line, iout, iu, n_names, j_count, ix_ele
integer ie1, ie2, ios, t_count, a_count, ix_lord, ix_match, ix1, ix2, n_lord, aperture_at
integer, allocatable :: n_repeat(:), an_indexx(:)

character(*) out_type, out_file_name
character(300) line, knl_str, ksl_str
character(40), allocatable :: names(:)
character(1000) line_out
character(8) str
character(20) :: r_name = "bmad_to_mad_or_xsif"
character(2) continue_char, eol_char, comment_char

logical, optional :: use_matrix_model, err
logical init_needed, has_nonzero_pole
logical parsing

! open file

if (present(err)) err = .true.
iu = lunget()
call fullfilename (out_file_name, line)
open (iu, file = line, iostat = ios)
if (ios /= 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN FILE: ' // trim(out_file_name))
  return
endif

! Init

if (out_type == 'MAD-X' .or. out_type == 'OPAL-T') then
  comment_char = '//'
  continue_char = ''
  eol_char = ';'
elseif (out_type == 'MAD-8' .or. out_type == 'XSIF') then
  comment_char = '!'
  continue_char = ' &'
  eol_char = ''
else
  call out_io (s_error$, r_name, 'BAD OUT_TYPE: ' // out_type)
  return
endif

call init_ele (col_ele)
call init_ele (drift_ele, drift$)
call init_ele (taylor_ele, taylor$)
call init_ele (ab_ele, ab_multipole$)
call init_ele (kicker_ele, kicker$) 
call multipole_init (ab_ele)

ie1 = integer_option(1, ix_start)
ie2 = integer_option(lat%n_ele_track, ix_end)

allocate (names(lat%n_ele_max), an_indexx(lat%n_ele_max)) ! list of element names

call out_io (s_info$, r_name, &
      'Note: Bmad lattice elements have attributes that cannot be translated. ', &
      '      For example, higher order terms in a Taylor element.', &
      '      Please use caution when using a translated lattice.')

!-----------------------------------------------------------------------------
! Translation is a two step process. First we create a new lattice called lat_out.
! Then the information in lat_out is used to create the lattice file.
! Transfer info to lat_out and make substitutions for sol_quad and wiggler elements, etc.

lat_out = lat
j_count = 0    ! drift around solenoid or sol_quad index
t_count = 0    ! taylor element count.
a_count = 0    ! Aperture count
i_unique = 1000

ix_ele = ie1 - 1
do 

  ix_ele = ix_ele + 1
  if (ix_ele > ie2) exit
  ele => lat_out%ele(ix_ele)
  val => ele%value

  ! If the name has more than 16 characters then replace the name by something shorter and unique.

  if (len_trim(ele%name) > 16) then
    call out_io (s_warn$, r_name, 'Shortening element name: ' // ele%name)
    i_unique = i_unique + 1
    write (ele%name, '(a, i0)') ele%name(1:11), i_unique
  endif

  ! Replace element name containing "/" or "#" with "_"

  do
    j = index (ele%name, '\')         ! '
    j = index (ele%name, '#')   
    if (j == 0) exit
    ele%name(j:j) = '_'
  enddo

  ! If there is an aperture...

  if (val(x1_limit$) /= 0 .or. val(x2_limit$) /= 0 .or. &
      val(y1_limit$) /= 0 .or. val(y2_limit$) /= 0) then

    if (val(x1_limit$) /= val(x2_limit$)) then
      call out_io (s_warn$, r_name, 'Asymmetric x_limits cannot be converted for: ' // ele%name, &
                                    'Will use largest limit here.')
      val(x1_limit$) = max(val(x1_limit$), val(x2_limit$))
    endif

    if (val(y1_limit$) /= val(y2_limit$)) then
      call out_io (s_warn$, r_name, 'Asymmetric y_limits cannot be converted for: ' // ele%name, &
                                    'Will use largest limit here.')
      val(y1_limit$) = max(val(y1_limit$), val(y2_limit$))
    endif

    ! create ecoll and rcoll elements.

    if (ele%key /= ecollimator$ .and. ele%key /= rcollimator$) then
      if (out_type == 'MAD-8' .or. out_type == 'XSIF' .or. ele%key == drift$) then
        if (ele%aperture_type == rectangular$) then
          col_ele%key = rcollimator$
        else
          col_ele%key = ecollimator$
        endif
        a_count = a_count + 1
        write (col_ele%name, '(a, i3.3)')  'COLLIMATOR_N', a_count
        col_ele%value = val
        col_ele%value(l$) = 0
        val(x1_limit$) = 0; val(x2_limit$) = 0; val(y1_limit$) = 0; val(y2_limit$) = 0; 
        aperture_at = ele%aperture_at  ! Save since ele pointer will be invalid after the insert
        if (aperture_at == both_ends$ .or. aperture_at == exit_end$ .or. aperture_at == continuous$) then
          call insert_element (lat_out, col_ele, ix_ele+1)
          ie2 = ie2 + 1
        endif
        if (aperture_at == both_ends$ .or. aperture_at == entrance_end$ .or. aperture_at == continuous$) then
          call insert_element (lat_out, col_ele, ix_ele)
          ie2 = ie2 + 1
        endif
        ix_ele = ix_ele - 1 ! Want to process the element again on the next loop.
      endif

      cycle ! cycle since ele pointer is invalid
    endif

  endif

  ! If the bend has a roll then put kicker elements just before and just after

  if (ele%key == sbend$ .and. val(roll$) /= 0) then
    j_count = j_count + 1
    write (kicker_ele%name,   '(a, i3.3)') 'ROLL_Z', j_count
    kicker_ele%value(hkick$) =  val(angle$) * (1 - cos(val(roll$))) / 2
    kicker_ele%value(vkick$) = -val(angle$) * sin(val(roll$)) / 2
    val(roll$) = 0   ! So on next iteration will not create extra kickers.
    call insert_element (lat_out, kicker_ele, ix_ele)
    call insert_element (lat_out, kicker_ele, ix_ele+2)
    ie2 = ie2 + 2
    cycle
  endif

  ! If there is a multipole component then put multipole elements at half strength 
  ! just before and just after the element.

  if (ele%key /= multipole$ .and. ele%key /= ab_multipole$) then
    call multipole_ele_to_ab (ele, lat%param%particle, .true., has_nonzero_pole, ab_ele%a_pole, ab_ele%b_pole)
    if (has_nonzero_pole) then
      ab_ele%a_pole = ab_ele%a_pole / 2
      ab_ele%b_pole = ab_ele%b_pole / 2
      deallocate (ele%a_pole, ele%b_pole)
      j_count = j_count + 1
      write (ab_ele%name,   '(a, i3.3)') 'MULTIPOLE_Z', j_count
      call insert_element (lat_out, ab_ele, ix_ele)
      call insert_element (lat_out, ab_ele, ix_ele+2)
      ie2 = ie2 + 2
      cycle
    endif
  endif

  ! If there are nonzero kick values and this is not a kick type element then put
  ! kicker elements at half strength just before and just after the element

  if (ele%key /= kicker$ .and. ele%key /= hkicker$ .and. ele%key /= vkicker$) then
    if (val(hkick$) /= 0 .or. val(vkick$) /= 0) then
      j_count = j_count + 1
      write (kicker_ele%name,   '(a, i3.3)') 'KICKER_Z', j_count
      kicker_ele%value(hkick$) = val(hkick$) / 2
      kicker_ele%value(vkick$) = val(vkick$) / 2
      val(hkick$) = 0; val(vkick$) = 0
      call insert_element (lat_out, kicker_ele, ix_ele)
      call insert_element (lat_out, kicker_ele, ix_ele+2)
      ie2 = ie2 + 2
      cycle
    endif
  endif

  ! Convert sol_quad_and wiggler elements.
  ! NOTE: FOR NOW SOL_QUAD  USES DRIFT-MATRIX-DRIFT MODEL!

  if (ele%key == wiggler$ .or. ele%key == sol_quad$) then
    if (logic_option(.false., use_matrix_model) .or. ele%key == sol_quad$) then

      drift_ele%value(l$) = -val(l$) / 2
      call make_mat6 (drift_ele, lat_out%param)
      taylor_ele%mat6 = matmul(matmul(drift_ele%mat6, ele%mat6), drift_ele%mat6)
      call mat6_to_taylor (taylor_ele%vec0, taylor_ele%mat6, taylor_ele%taylor)

      ! Add drifts before and after wigglers and sol_quads so total length is invariant
      j_count = j_count + 1
      t_count = t_count + 1
      write (drift_ele%name, '(a, i3.3)') 'DRIFT_Z', j_count
      write (taylor_ele%name, '(a, i3.3)') 'SOL_QUAD', j_count
      drift_ele%value(l$) = val(l$) / 2
      ele%key = -1 ! Mark for deletion
      call remove_eles_from_lat (lat_out)
      call insert_element (lat_out, drift_ele, ix_ele)
      call insert_element (lat_out, taylor_ele, ix_ele+1)
      call insert_element (lat_out, drift_ele, ix_ele+2)
      ie2 = ie2 + 2
      cycle

    ! Non matrix model...
    ! If the wiggler has been sliced due to superposition, throw 
    ! out the markers that caused the slicing.

    else
      if (ele%key == wiggler$) then
        if (ele%slave_status == super_slave$) then
          ! Create the wiggler model using the super_lord
          lord => pointer_to_lord(ele, 1)
          call create_wiggler_model (lord, lat_model)
          ! Remove all the slave elements and markers in between.
          call out_io (s_warn$, r_name, &
              'Note: Not translating to MAD/XSIF the markers within wiggler: ' // lord%name)
          lord%key = -1 ! mark for deletion
          call find_element_ends (lat_out, lord, ele1, ele2)
          ix1 = ele1%ix_ele; ix2 = ele2%ix_ele
          ! If the wiggler wraps around the origin we are in trouble.
          if (ix2 < ix1) then 
            call out_io (s_fatal$, r_name, 'Wiggler wraps around origin. Cannot translate this!')
            if (bmad_status%exit_on_error) call err_exit
          endif
          do i = ix1+1, ix2
            lat_out%ele(i)%key = -1  ! mark for deletion
          enddo
          ie2 = ie2 - (ix2 - ix1 - 1)
        else
          call create_wiggler_model (ele, lat_model)
        endif
      else
        call create_sol_quad_model (ele, lat_model)  ! NOT YET IMPLEMENTED!
      endif
      ele%key = -1 ! Mark for deletion
      call remove_eles_from_lat (lat_out)
      do j = 1, lat_model%n_ele_track
        call insert_element (lat_out, lat_model%ele(j), ix_ele+j-1)
      enddo
      ie2 = ie2 + lat_model%n_ele_track - 1
      cycle
    endif
  endif

enddo

!-------------------------------------------
! Now write info to the output file...
! lat lattice name

write (iu, '(3a)') comment_char, ' File generated by: bmad_to_mad_or_xsif', trim(eol_char)
write (iu, '(4a)') comment_char, ' Bmad Lattice File: ', trim(lat_out%input_file_name), trim(eol_char)
write (iu, '(4a)') comment_char, ' Bmad Lattice: ', trim(lat_out%lattice), trim(eol_char)
write (iu, *)

! beam definition

if (out_type /= 'OPAL-T') then
  ele => lat_out%ele(ie1-1)

  write (iu, '(2a, 2(a, es13.5), a)')  &
        'beam_def: Beam, Particle = ', trim(particle_name(lat_out%param%particle)),  &
        ', Energy =', 1e-9*ele%value(E_TOT$), ', Npart =', lat_out%param%n_part, trim(eol_char)

  write (iu, *)
endif

! write element parameters

n_names = 0                          ! number of names stored in the list

do ix_ele = ie1, ie2

  ele => lat_out%ele(ix_ele)
  val => ele%value

  if (out_type == 'XSIF') then
    if (ele%key == elseparator$) ele%key = drift$  ! XSIF does not have elsep elements.
  endif

  ! do not make duplicate specs

  call find_indexx (ele%name, names, an_indexx, n_names, ix_match)
  if (ix_match > 0) cycle

  ! Add to the list of elements

  if (size(names) < n_names + 1) then
    call re_allocate(names, 2*size(names))
    call re_allocate(an_indexx, 2*size(names))
  endif

  call find_indexx (ele%name, names, an_indexx, n_names, ix_match, add_to_list = .true.)
  n_names = n_names + 1

  ! OPAL case
  
  if (out_type == 'OPAL-T') then

     select case (ele%key)

     case (marker$)
        write (line_out, '(a, es13.5)') trim(ele%name) // ': marker'
        call value_to_line (line_out, ele%s - val(L$), 'elemedge', 'es13.5', 'R', .false.)

     case (drift$)
        write (line_out, '(a, es13.5)') trim(ele%name) // ': drift, l =', val(l$)
        call value_to_line (line_out, ele%s - val(L$), 'elemedge', 'es13.5', 'R', .false.)
     case (sbend$)
        write (line_out, '(a, es13.5)') trim(ele%name) // ': sbend, l =', val(l$)
        call value_to_line (line_out, val(b_field$), 'k0', 'es13.5', 'R')
        call value_to_line (line_out, val(e_tot$), 'designenergy', 'es13.5', 'R')
        call value_to_line (line_out, ele%s - val(L$), 'elemedge', 'es13.5', 'R', .false.)
     case (quadrupole$)
        write (line_out, '(a, es13.5)') trim(ele%name) // ': quadrupole, l =', val(l$)
        !Note that OPAL-T has k1 = dBy/dx, and that bmad needs a -1 sign for electrons
        call value_to_line (line_out, -1*val(b1_gradient$), 'k1', 'es13.5', 'R')
        !elemedge The edge of the field is specifieda bsolute (floor space co-ordinates) in m.
        call value_to_line (line_out, ele%s - val(L$), 'elemedge', 'es13.5', 'R', .false.)

     case default
        call out_io (s_error$, r_name, 'UNKNOWN ELEMENT TYPE: ' // key_name(ele%key), &
             'CONVERTING TO DRIFT')
        write (line_out, '(a, es13.5)') trim(ele%name) // ': drift, l =', val(l$)
        call value_to_line (line_out, ele%s - val(L$), 'elemedge', 'es13.5', 'R', .false.)

     end select

     call element_out(line_out)
     cycle
  endif

  ! For anything else but opal

  select case (ele%key)

  ! drift

  case (drift$, instrument$, pipe$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': drift, l =', val(l$)
  
  ! beambeam

  case (beambeam$)

    line_out = trim(ele%name) // ': beambeam'
    call value_to_line (line_out, val(sig_x$), 'sigx', 'es13.5', 'R')
    call value_to_line (line_out, val(sig_y$), 'sigy', 'es13.5', 'R')
    call value_to_line (line_out, val(x_offset$), 'xma', 'es13.5', 'R')
    call value_to_line (line_out, val(y_offset$), 'yma', 'es13.5', 'R')
    call value_to_line (line_out, val(charge$), 'charge', 'es13.5', 'R')


  ! ecollimator

  case (ecollimator$, rcollimator$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': ' // trim(key_name(ele%key)) // ', l =', val(l$)
    call value_to_line (line_out, val(x1_limit$), 'xsize', 'es13.5', 'R')
    call value_to_line (line_out, val(y1_limit$), 'ysize', 'es13.5', 'R')

  ! elseparator

  case (elseparator$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': elseparator, l =', val(l$)
    hk = val(hkick$)
    vk = val(vkick$)

    if (hk /= 0 .or. vk /= 0) then

      ix = len_trim(line_out) + 1
      field = 1.0e3 * sqrt(hk**2 + vk**2) * val(E_TOT$) / val(l$)
      if (out_type == 'MAD-X') then
        write (line_out(ix:), '(a, es13.5)') ', ey =', field
      else
        write (line_out(ix:), '(a, es13.5)') ', e =', field
      endif

      if (lat_out%param%particle == positron$) then
        tilt = -atan2(hk, vk) + val(tilt$)
      else
        tilt = -atan2(hk, vk) + val(tilt$) + pi
      endif
      ix = len_trim(line_out) + 1
      write (line_out(ix:), '(a, es13.5)') ', tilt =', tilt

    endif

  ! hkicker

  case (hkicker$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': hkicker, l =', val(l$)

    call value_to_line (line_out, val(hkick$), 'kick', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! kicker

  case (kicker$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': kicker, l =', val(l$)

    call value_to_line (line_out, val(hkick$), 'hkick', 'es13.5', 'R')
    call value_to_line (line_out, val(vkick$), 'vkick', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! vkicker

  case (vkicker$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': vkicker, l =', val(l$)

    call value_to_line (line_out, val(vkick$), 'kick', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! marker

  case (marker$, branch$, photon_branch$)

    line_out = trim(ele%name) // ': marker'

  ! octupole

  case (octupole$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': octupole, l =', val(l$)

    call value_to_line (line_out, val(k3$), 'k3', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! quadrupole

  case (quadrupole$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': quadrupole, l =', val(l$)
    call value_to_line (line_out, val(k1$), 'k1', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! sbend

  case (sbend$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': sbend, l =', val(l$)

    call value_to_line (line_out, val(angle$), 'angle', 'es13.5', 'R')
    call value_to_line (line_out, val(e1$), 'e1', 'es13.5', 'R')
    call value_to_line (line_out, val(e2$), 'e2', 'es13.5', 'R')
    call value_to_line (line_out, val(k1$), 'k1', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! sextupole

  case (sextupole$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': sextupole, l =', val(l$)
    call value_to_line (line_out, val(k2$), 'k2', 'es13.5', 'R')
    call value_to_line (line_out, val(tilt$), 'tilt', 'es13.5', 'R')

  ! taylor

  case (taylor$)

    line_out = trim(ele%name) // ': matrix'

    do i = 1, 6
      do k = 1, size(ele%taylor(i)%term)
        term = ele%taylor(i)%term(k)

        select case (sum(term%expn))
        case (1)
          j = maxloc(term%expn, 1)
          if (out_type == 'MAD-8') then
            write (str, '(a, i0, a, i0, a)') 'rm(', i, ',', j, ')'
          elseif (out_type == 'MAD-X') then
            write (str, '(a, 2i0)') 'rm', i, j
          elseif (out_type == 'XSIF') then
            write (str, '(a, 2i0)') 'r', i, j
          endif
          call value_to_line (line_out, term%coef, str, 'es13.5', 'R')
          
        case (2)
          j = maxloc(term%expn, 1)
          term%expn(j) = term%expn(j) - 1
          j2 = maxloc(term%expn, 1)
          if (out_type == 'MAD-8') then
            write (str, '(a, 3(i0, a))') 'tm(', i, ',', j, ',', j2, ')'
          elseif (out_type == 'MAD-X') then
            write (str, '(a, 3i0)') 'tm', i, j, j2
          elseif (out_type == 'XSIF') then
            write (str, '(a, 3i0)') 't', i, j, j2
          endif
          call value_to_line (line_out, term%coef, str, 'es13.5', 'R')


        case default
          call out_io (s_error$, r_name, &
                  'TAYLOR TERM: \es12.2\ : \6i3\ ', &
                  'IN ELEMENT: ' // ele%name, &
                  'CANNOT BE CONVERTED TO MAD MATRIX TERM', &
                  r_array = [term%coef ], i_array = term%expn)
        end select
      enddo

      if (ele%mat6(i,i) == 0) then
        if (out_type == 'MAD-8') then
          write (str, '(a, i0, a, i0, a)') 'rm(', i, ',', i, ')'
        elseif (out_type == 'MAD-X') then
          write (str, '(a, 2i0)') 'rm', i, i
        elseif (out_type == 'XSIF') then
          write (str, '(a, 2i0)') 'r', i, i
        endif
        call value_to_line (line_out, 0.0_rp, str, 'es13.5', 'R')
      endif

    enddo

  ! rfcavity

  case (rfcavity$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': rfcavity, l =', val(l$)
    call value_to_line (line_out, val(voltage$)/1E6, 'volt', 'es13.5', 'R')
    call value_to_line (line_out, val(phi0$)+val(dphi0$)+0.5, 'lag', 'es13.5', 'R')
    call value_to_line (line_out, val(harmon$), 'harmon', 'i8', 'I')

  ! lcavity

  case (lcavity$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': lcavity, l =', val(l$)
    call value_to_line (line_out, val(gradient$)*val(l$)/1e6, 'deltae', 'f11.4', 'R')
    call value_to_line (line_out, val(rf_frequency$)/1e6, 'freq', 'es13.5', 'R')
    call value_to_line (line_out, val(phi0$)+val(dphi0$), 'phi0', 'es13.5', 'R')

  ! solenoid

  case (solenoid$)

    write (line_out, '(a, es13.5)') trim(ele%name) // ': solenoid, l =', val(l$)
    call value_to_line (line_out, val(ks$), 'ks', 'es13.5', 'R')

  ! multipole

  case (multipole$, ab_multipole$)

    call multipole_ele_to_kt (ele, lat_out%param%particle, .true., has_nonzero_pole, knl, tilts)
    write (line_out, '(a, es13.5)') trim(ele%name) // ': multipole'  

    if (out_type == 'MAD-X') then
      knl_str = ''; ksl_str = ''
      call multipole_ele_to_ab (ele, lat_out%param%particle, .true., has_nonzero_pole, a_pole, b_pole)
      do i = 0, 9
        if (all(knl(i:) == 0)) exit
        if (abs(a_pole(i)) < 1d-12 * abs(b_pole(i))) a_pole(i) = 0  ! Round to zero insignificant value
        if (abs(b_pole(i)) < 1d-12 * abs(a_pole(i))) b_pole(i) = 0  ! Round to zero insignificant value
        call value_to_line (knl_str,  b_pole(i) * factorial(i), '', 'es13.5', 'R', .false.)
        call value_to_line (ksl_str, -a_pole(i) * factorial(i), '', 'es13.5', 'R', .false.)
      enddo
      if (any(b_pole /= 0)) line_out = trim(line_out) // ', knl = {' // trim(knl_str(3:)) // '}'
      if (any(a_pole /= 0)) line_out = trim(line_out) // ', ksl = {' // trim(ksl_str(3:)) // '}'

    else
      do i = 0, 9
        write (str, '(a, i1, a)') 'K', i, 'L'
        call value_to_line (line_out, knl(i), str, 'es13.5', 'R')
        write (str, '(a, i1)') 'T', i
        call value_to_line (line_out, tilts(i), str, 'es13.5', 'R')
      enddo
    endif

  ! unknown

  case default

    call out_io (s_error$, r_name, 'UNKNOWN ELEMENT TYPE: ' // key_name(ele%key), &
                                  'CONVERTING TO MARKER')
    line_out = trim(ele%name) // ': marker'

  end select

  ! Add apertures for mad-x. Use 1 meter for unset apertures

  if (out_type == 'MAD-X') then
    if (val(x1_limit$) /= 0 .or. val(y1_limit$) /= 0) then
      limit = [val(x1_limit$), val(y1_limit$)]
      where (limit == 0) limit = 1
      if (ele%aperture_type == rectangular$) then
        line_out = trim(line_out) // ', apertype = rectangle'
      else
        line_out = trim(line_out) // ', apertype = ellipse'
      endif
      write (line_out, '(2a, es13.5, a, es13.5, a)') trim(line_out), &
                                  ', aperture = (', limit(1), ',', limit(2), ')'
    endif
  endif

  ! write element spec to file

  call element_out(line_out)

enddo

!---------------------------------------------------------------------------------------
! Write the lattice line
! bmad has a limit of 4000 characters so we may need to break the lat into pieces.

i_unique = 1000
i_line = 0
init_needed = .true.
line = ' '

do n = ie1, ie2

  ele => lat_out%ele(n)

  if (init_needed) then
    write (iu, *)
    write (iu, *) comment_char, '---------------------------------', trim(eol_char)
    write (iu, *)
    i_line = i_line + 1
    write (line, '(a, i0, 2a)') 'line_', i_line, ': line = (', ele%name
    iout = 0
    init_needed = .false.

  else

    ix = len_trim(line) + len_trim(ele%name)

    if (ix > 75) then
      write (iu, '(3a)') trim(line), ',', trim(continue_char)
      iout = iout + 1
      line = '   ' // ele%name
    else
      line = trim(line) // ', ' // ele%name
    endif
  endif

  ! Output line if long enough or at end

  if (n == ie2 .or. iout > 48) then
    line = trim(line) // ')'
    write (iu, '(2a)') trim(line), trim(eol_char)
    line = ' '
    init_needed = .true.
  endif

enddo

!---------------------------------------------------
! Element offsets

if (out_type(1:3) == 'MAD') then

  write (iu, *)
  write (iu, *) comment_char, '---------------------------------', trim(eol_char)
  write (iu, *)

  allocate (n_repeat(n_names))
  n_repeat = 0

  do ix_ele = ie1, ie2

    ele => lat_out%ele(ix_ele)
    val => ele%value
    
    call find_indexx (ele%name, names, an_indexx, n_names, ix_match)
    n_repeat(ix_match) = n_repeat(ix_match) + 1
    
    if (val(x_pitch$) == 0 .and. val(y_pitch$) == 0 .and. &
        val(x_offset_tot$) == 0 .and. val(y_offset_tot$) == 0 .and. val(s_offset_tot$) == 0) cycle

    write (iu, *) 'select, flag = error, clear', trim(eol_char)
    write (iu, '(3a, i0, 2a)') 'select, flag = error, range = ', trim(ele%name), &
                                    '[', n_repeat(ix_match), ']', trim(eol_char)

    line_out = 'ealign'
    call value_to_line (line_out,  val(x_pitch$), 'dtheta', 'es12.4', 'R')
    call value_to_line (line_out, -val(y_pitch$), 'dphi', 'es12.4', 'R')
    call value_to_line (line_out, val(x_offset$) - val(x_pitch$) * val(l$) / 2, 'dx', 'es12.4', 'R')
    call value_to_line (line_out, val(y_offset$) - val(y_pitch$) * val(l$) / 2, 'dy', 'es12.4', 'R')
    call value_to_line (line_out, val(s_offset$), 'ds', 'es12.4', 'R')
    call element_out (line_out)

  enddo

  deallocate (n_repeat)

endif

! Write twiss parameters for a linear lattice.

ele => lat_out%ele(ie1-1)
if (lat_out%param%lattice_type /= circular_lattice$ .and. out_type /= 'OPAL-T') then
  write (iu, *)
  write (iu, *) comment_char, '---------------------------------', trim(eol_char)
  write (iu, *)
  write (iu, '(2(a, es13.5), 2a)') 'TWISS, betx =', ele%a%beta, ', bety =', ele%b%beta, ',', trim(continue_char)
  write (iu, '(5x, 2(a, es13.5), 2a)') 'alfx =', ele%a%alpha, ', alfy =', ele%b%alpha, ',', trim(continue_char)
  write (iu, '(5x, 2(a, es13.5), 2a)') 'dx =', ele%a%eta, ', dpx = ', ele%a%etap, ',', trim(continue_char)
  write (iu, '(5x, 2(a, es13.5), a)') 'dy =', ele%b%eta, ', dpy = ', ele%b%etap, trim(eol_char)
endif

!------------------------------------------
! Use statement

write (iu, *)
write (iu, *) comment_char, '---------------------------------', trim(eol_char)
write (iu, *)
line = 'lat: line = (line_1'
do i = 2, i_line
  write (line, '(2a, i0)') trim(line), ', line_', i
enddo
line = trim(line) // ')'
write (iu, *) trim(line), trim(eol_char)
if (out_type == 'MAD-X') then
  write (iu, *) 'use, period=lat;'
elseif (out_type /= 'OPAL-T') then
  write (iu, *) 'use, lat'
endif

!

call out_io (s_info$, r_name, 'Written ' // trim(out_type) // &
                                ' lattice file: ' // trim(out_file_name))

deallocate (names)
if (present(err)) err = .false.

if (present(converted_lat)) then
  converted_lat = lat_out
  converted_lat%n_ele_max = converted_lat%n_ele_track
  do i = 1, converted_lat%n_ele_track
    converted_lat%ele(i)%slave_status = free$
    converted_lat%ele(i)%n_lord = 0
    converted_lat%ele(i)%ic2_lord = converted_lat%ele(i)%ic1_lord - 1
  enddo
  converted_lat%n_control_max = 0
  converted_lat%n_ic_max = 0
endif

call deallocate_lat_pointers (lat_out)
call deallocate_lat_pointers (lat_model)


!------------------------------------------------------------------------
contains

subroutine element_out (line_out)

implicit none

character(*) line_out
integer ix, ix1, ix2
integer, parameter :: ix_min = 65, ix_max = 85

!

do
  if (len_trim(line_out) < ix_max) exit
  ix1 = index(line_out(ix_min+1:), ',') + ix_min
  ix2 = index(line_out(ix_min+1:), ' ') + ix_min
  if (ix1 < ix2 .or. ix1 < ix_max) then
    ix = ix1
  else
    ix = ix2
  endif
  write (iu, '(2a)') line_out(:ix), trim(continue_char)
  line_out = '    ' // line_out(ix+1:)
enddo

write (iu, '(2a)') trim(line_out), trim(eol_char)

end subroutine element_out

end subroutine bmad_to_mad_or_xsif

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------

subroutine value_to_line (line, value, str, fmt, typ, ignore_if_zero)

use precision_def

implicit none

character(*) line, str, fmt
character(40) fmt2, val_str
character(*) typ

real(rp) value

integer ix

logical, optional :: ignore_if_zero

!

if (value == 0 .and. logic_option(.true., ignore_if_zero)) return

if (str == '') then
  line = trim(line) // ','
else
  line = trim(line) // ', ' // trim(str) // ' ='
endif

if (value == 0) then
  line = trim(line) // ' 0'
  return
endif

fmt2 = '(' // trim(fmt) // ')'
if (typ == 'R') then
  write (val_str, fmt2) value
elseif (typ == 'I') then
  write (val_str, fmt2) nint(value)
else
  print *, 'ERROR IN VALUE_TO_LINE. BAD "TYP": ', typ 
  if (bmad_status%exit_on_error) call err_exit
endif

call string_trim(val_str, val_str, ix)
line = trim(line) // ' ' // trim(val_str)

end subroutine value_to_line

end module

