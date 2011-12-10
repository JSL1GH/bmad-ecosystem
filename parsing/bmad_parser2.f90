!+
! Subroutine bmad_parser2 (lat_file, lat, orbit, make_mats6)
!
! Subroutine parse (read in) a BMAD input file.
! This subrotine assumes that lat already holds an existing lattice.
! To read in a lattice from scratch use bmad_parser or xsif_parser.
!
! With bmad_parser2 you may:
!     a) Modify the attributes of elements.
!     b) Define new overlays and groups.
!     c) Superimpose new elements upon the lattice.
!
! Note: Unlike bmad_parser, no digested file will be created.
!
! Note: If you use the superimpose feature to insert an element into the latttice
!       then the index of a given element already in the lattice may change.
!
! Modules needed:
!   use bmad
!
! Input:
!   lat_file    -- Character(*): Input file name.
!   lat         -- lat_struct: lattice with existing layout.
!   orbit(0:)   -- Coord_struct, optional: closed orbit for when
!                           bmad_parser2 calls lat_make_mat6
!   make_mats6  -- Logical, optional: Make the 6x6 transport matrices for then
!                   Elements? Default is True.
!
! Output:
!   lat    -- lat_struct: lattice with modifications.
!-

subroutine bmad_parser2 (lat_file, lat, orbit, make_mats6)

use bmad_parser_mod, except_dummy => bmad_parser2

implicit none
  
type (lat_struct), target :: lat
type (lat_struct), save :: lat2
type (ele_struct), pointer :: ele
type (parser_ele_struct), pointer :: pele
type (ele_struct), target, save :: beam_ele, param_ele, beam_start_ele
type (coord_struct), optional :: orbit(0:)
type (parser_lat_struct), target :: plat

real(rp) v1, v2

integer ix_word, i, ix, ix1, ix2, n_plat_ele, ixx, ele_num, ix_word_1
integer key, n_max_old
integer, pointer :: n_max
integer, allocatable :: lat_indexx(:)

character(*) lat_file
character(1) delim 
character(40) word_2, name
character(40), allocatable :: lat_name(:)
character(16) :: r_name = 'bmad_parser2'
character(32) word_1
character(40) this_name
character(280) parse_line_save
character(200) call_file
character(80) debug_line

logical, optional :: make_mats6
logical parsing, found, delim_found, xsif_called, err, wild_here, key_here
logical end_of_file, err_flag, finished, good_attrib, wildcards_permitted, integer_permitted
logical print_err, check

! Init...

bmad_status%ok = .true.
bp_com%write_digested2 = .false.
bp_com%parser_name = 'bmad_parser2'
bp_com%input_from_file = .true.
bp_com%e_tot_set = .false.
bp_com%p0c_set   = .false.

! If lat_file = 'FROM: BMAD_PARSER' then bmad_parser2 has been called by 
! bmad_parser (after an expand_lattice command). 
! In this case we just read from the current open file.

if (lat_file /= 'FROM: BMAD_PARSER') then
  bp_com%do_superimpose = .true.
  call parser_file_stack('init')
  call parser_file_stack('push', lat_file, finished, err)   ! open file on stack
  if (err) return
endif

debug_line = ''
n_max => lat%n_ele_max
n_max_old = n_max

call allocate_plat (plat, 4)

bp_com%beam_ele => beam_ele
call init_ele(beam_ele)
beam_ele%name = 'BEAM'              ! fake beam element
beam_ele%key = def_beam$            ! "definition of beam"
beam_ele%value(n_part$)     = lat%param%n_part
beam_ele%value(particle$)   = lat%param%particle
beam_ele%ixx = 1                    ! Pointer to plat%ele() array

bp_com%param_ele => param_ele
call init_ele (param_ele)
param_ele%name = 'PARAMETER'
param_ele%key = def_parameter$
param_ele%value(lattice_type$) = lat%param%lattice_type
param_ele%value(taylor_order$) = lat%input_taylor_order
param_ele%value(n_part$)       = lat%param%n_part
param_ele%value(particle$)     = lat%param%particle
param_ele%ixx = 2                    ! Pointer to plat%ele() array

bp_com%beam_start_ele => beam_start_ele
call init_ele (beam_start_ele)
beam_start_ele%name = 'BEAM_START'
beam_start_ele%key = def_beam_start$
beam_start_ele%ixx = 3                    ! Pointer to plat%ele() array

n_plat_ele = 3
bmad_status%ok = .true.

!-----------------------------------------------------------
! main parsing loop

bp_com%input_line_meaningful = .true.

parsing_loop: do

  ! get a line from the input file and parse out the first word

  call load_parse_line ('normal', 1, end_of_file)  ! load an input line
  call get_next_word (word_1, ix_word, '[:](,)=', delim, delim_found, .true.)
  if (end_of_file) then
    word_1 = 'END_FILE'
    ix_word = 8
  else
    wildcards_permitted = (delim == '[')  ! For 'q*[x_offset] = ...' constructs
    integer_permitted = (delim == '[')    ! For '78[x_offset] = ...' constructs
    call verify_valid_name(word_1, ix_word, wildcards_permitted, integer_permitted)
  endif

  ! PARSER_DEBUG

  if (word_1(:ix_word) == 'PARSER_DEBUG') then
    debug_line = bp_com%parse_line
    call out_io (s_info$, r_name, 'FOUND IN FILE: "PARSER_DEBUG". DEBUG IS NOW ON')
    cycle parsing_loop
  endif

  ! NO_DIGESTED

  if (word_1(:ix_word) == 'NO_DIGESTED') then
    bp_com%write_digested  = .false.
    bp_com%write_digested2 = .false.
    call out_io (s_info$, r_name, 'FOUND IN FILE: "NO_DIGESTED". NO DIGESTED FILE WILL BE CREATED')
    cycle parsing_loop
  endif

  ! CALL command

  if (word_1(:ix_word) == 'CALL') then
    call get_called_file(delim, call_file, xsif_called, err)
    if (err) return
    cycle parsing_loop

  endif

  ! BEAM command

  if (word_1(:ix_word) == 'BEAM') then
    if (delim /= ',')  call parser_warning ('"BEAM" NOT FOLLOWED BY COMMA', ' ')

    parsing = .true.
    do while (parsing)
      if (.not. delim_found) then
        parsing = .false.
      elseif (delim /= ',') then
        call parser_warning ('EXPECTING: "," BUT GOT: ' // delim, 'FOR "BEAM" COMMAND')
        parsing = .false.
      else
        call parser_set_attribute (def$, beam_ele, lat, delim, delim_found, &
                                        err_flag, .true., check_free = .true.)
        if (err_flag) cycle parsing_loop
      endif
    enddo

    cycle parsing_loop

  endif

  ! LATTICE command

  if (word_1(:ix_word) == 'LATTICE') then
    if ((delim /= ':' .or. bp_com%parse_line(1:1) /= '=') .and. (delim /= '=')) then
      call parser_warning ('"LATTICE" NOT FOLLOWED BY ":="', ' ')
    else
      if (delim == ':') bp_com%parse_line = bp_com%parse_line(2:)  ! trim off '='
      call get_next_word (lat%lattice, ix_word, ',', delim, delim_found, .true.)
    endif
    cycle parsing_loop
  endif

  ! RETURN or END_FILE command

  if (word_1(:ix_word) == 'RETURN' .or.  word_1(:ix_word) == 'END_FILE') then
    call parser_file_stack ('pop', ' ', finished, err)
    if (err) return
    if (finished) then
      exit parsing_loop
    else
      cycle parsing_loop
    endif
  endif

  !---------------------------------------
  ! Variable definition or element redef...

  ! if an element attribute redef.

  if (delim == '[') then

    call get_next_word (word_2, ix_word, ']', delim, delim_found, .true.)
    if (.not. delim_found) then
      call parser_warning ('OPENING "[" FOUND WITHOUT MATCHING "]"')
      cycle parsing_loop
    endif

    call get_next_word (this_name, ix_word, ':=', delim, delim_found, .true.)
    if (.not. delim_found .or. ix_word /= 0) then
      call parser_warning ('MALFORMED ELEMENT ATTRIBUTE REDEFINITION')
      cycle parsing_loop
    endif

    ! If delim is ':' then this is an error since get_next_word treats
    ! a ':=' construction as a '=' 

    if (delim == ':') then
      call parser_warning ('MALFORMED ELEMENT ATTRIBUTE REDEF')
      cycle parsing_loop
    endif

    ! find associated element and evaluate the attribute value

    wild_here = .false.
    if (index(word_1, '*') /= 0 .or. index(word_1, '%') /= 0) wild_here = .true.

    key_here = .false.
    do i = 1, size(key_name)
      if (word_1 == key_name(i)) then
        key_here = .true.
        exit
      endif
    enddo

    found = .false.
    good_attrib = .false.

    if (is_integer(word_1)) then
      read (word_1, *) ix_word_1
    else
      ix_word_1 = -1
    endif

    do i = 0, n_max

      ele => lat%ele(i)

      ! See if element is a match

      print_err = .true.
      check = .true.

      ! With wild cards and key names we ignore bad sets since this could not be a typo.

      if (key_here) then
        if (key_name(ele%key) /= word_1) cycle
        print_err = .false.

      elseif (wild_here) then
        select case (ele%name)
        case ('BEGINNING', 'BEAM', 'PARAMETER', 'BEAM_START')
          cycle  ! Wild card matches not permitted for predefined elements
        end select
        if (.not. match_wild(ele%name, word_1)) cycle
        print_err = .false.

      elseif (word_1  == 'PARAMETER') then
        ele => param_ele
        check = .false.
      elseif (word_1  == 'BEAM_START') then
        ele => beam_start_ele
        check = .false.
      elseif (ix_word_1 > -1) then
        if (i /= ix_word_1) cycle
      elseif (ele%name /= word_1) then
        cycle
      endif

      bp_com%parse_line = trim(word_2) // ' = ' // bp_com%parse_line 
      if (found) then   ! if not first time
        bp_com%parse_line = parse_line_save
      else
        parse_line_save = bp_com%parse_line
      endif

      call parser_set_attribute (redef$, ele, lat, delim, delim_found, &
                                                err_flag, print_err, check_free = check)
      if (.not. err_flag .and. delim_found) call parser_warning ('BAD DELIMITER: ' // delim, ' ')
      found = .true.
      if (.not. err_flag) good_attrib = .true.
      call set_flags_for_changed_attribute (lat, ele)

      if (word_1  == 'PARAMETER' .or. word_1  == 'BEAM_START') cycle parsing_loop

    enddo

    ! If bmad_parser2 has been called from bmad_parser then check if the
    ! element was just not used in the lattice. If so then just ignore it.

    if (.not. found .and. .not. key_here) then
      if (bp_com%bmad_parser_calling) then
        do i = 0, bp_com%old_lat%n_ele_max
          if (bp_com%old_lat%ele(i)%name == word_1) then
            bp_com%parse_line = ' '  ! discard rest of statement
            cycle parsing_loop       ! goto next statement
          endif
        enddo
      endif
      call parser_warning ('ELEMENT NOT FOUND: ' // word_1)
    endif

    if (found .and. (wild_here .or. key_here) .and. .not. good_attrib) then
      call parser_warning ('BAD ATTRIBUTE')
    endif

    cycle parsing_loop

  !---------------------------------------
  ! else must be a variable

  elseif (delim == '=') then

    call parser_add_variable (word_1, lat)
    cycle parsing_loop

  endif

  ! bad delimiter

  if (delim /= ':') then
    call parser_warning ('1ST DELIMITER IS NOT ":". IT IS: ' // delim,  'FOR: ' // word_1)
    cycle parsing_loop
  endif

  ! only possibilities left are: element, list, or line
  ! to decide which look at 2nd word

  call get_next_word(word_2, ix_word, ':=,', delim, delim_found, .true.)
  if (ix_word == 0) then
    call parser_warning ('NO NAME FOUND AFTER: ' // word_1, ' ')
    call err_exit
  endif

  call verify_valid_name(word_2, ix_word)

  ! if line or list then this is an error for bmad_parser2

  if (word_2(:ix_word) == 'LINE' .or. word_2(:ix_word) == 'LIST') then
    call parser_warning ('LINES OR LISTS NOT PERMITTED: ' // word_1, ' ')

  !-------------------------------------------------------
  ! if not line or list then must be an element

  else

    n_max = n_max + 1
    if (n_max > ubound(lat%ele, 1)) call allocate_lat_ele_array(lat)
    ele => lat%ele(n_max)

    ele%name = word_1

    n_plat_ele = n_plat_ele + 1     ! next free slot
    ele%ixx = n_plat_ele
    if (n_plat_ele > ubound(plat%ele, 1)) call allocate_plat (plat, 2*size(plat%ele))
    pele => plat%ele(n_plat_ele)

    pele%lat_file = bp_com%current_file%full_name
    pele%ix_line_in_file = bp_com%current_file%i_line

    do i = 1, n_max-1
      if (ele%name == lat%ele(i)%name) then
        call parser_warning ('DUPLICATE ELEMENT NAME ' // ele%name, ' ')
        exit
      endif
    enddo

    ! Check for valid element key name or if element is part of a element key.
    ! If none of the above then we have an error.

    found = .false.  ! found a match?

    do i = 1, n_max-1
      if (word_2 == lat%ele(i)%name) then
        ixx = ele%ixx  ! save
        ele = lat%ele(i)
        ele%ixx = ixx   ! Restore correct value
        ele%name = word_1
        found = .true.
        exit
      endif
    enddo

    if (.not. found) then
      ele%key = key_name_to_key_index(word_2, .true.)
      if (ele%key > 0) then
        call parser_set_ele_defaults (ele)
        found = .true.
      endif
    endif

    if (.not. found) then
      call parser_warning ('KEY NAME NOT RECOGNIZED OR AMBIGUOUS: ' // word_2,  &
                    'FOR ELEMENT: ' // ele%name)
      ele%key = 1       ! dummy value
    endif

    ! now get the attribute values.
    ! For control elements lat%ele()%ixx temporarily points to
    ! the plat structure where storage for the control lists is
                 
    key = ele%key
    if (key == overlay$ .or. key == group$ .or. key == girder$) then
      if (delim /= '=') then
        call parser_warning ('EXPECTING: "=" BUT GOT: ' // delim,  &
                    'FOR ELEMENT: ' // ele%name)
      else
        if (key == overlay$) ele%lord_status = overlay_lord$
        if (key == group$)   ele%lord_status = group_lord$
        if (key == girder$)  ele%lord_status = girder_lord$
        call get_overlay_group_names(ele, lat,  pele, delim, delim_found)
      endif
      if (key /= girder$ .and. .not. delim_found) then
        call parser_warning ('NO CONTROL ATTRIBUTE GIVEN AFTER CLOSING "}"',  &
                      'FOR ELEMENT: ' // ele%name)
        n_max = n_max - 1
        cycle parsing_loop
      endif
    endif

    parsing = .true.
    do while (parsing)
      if (.not. delim_found) then          ! if nothing more
        parsing = .false.           ! break loop
      elseif (delim /= ',') then
        call parser_warning ('EXPECTING: "," BUT GOT: ' // delim,  &
                      'FOR ELEMENT: ' // ele%name)
        n_max = n_max - 1
        cycle parsing_loop
      else
        call parser_set_attribute (def$, ele, lat, delim, delim_found, err_flag, .true., pele)
        call set_flags_for_changed_attribute (lat, ele)
        if (err_flag) then
          n_max = n_max - 1
          cycle parsing_loop
        endif
      endif
    enddo

    ! Element must be a group, overlay, or superimpose element

    if (key /= overlay$ .and. key /= group$ .and. ele%lord_status /= super_lord$) then
      call parser_warning ('ELEMENT MUST BE AN OVERLAY, SUPERIMPOSE, ' //  &
                                           'OR GROUP: ' // word_1, ' ')
      n_max = n_max - 1
      cycle parsing_loop
    endif

  endif

enddo parsing_loop

!---------------------------------------------------------------
! Now we have read everything in

bp_com%input_line_meaningful = .false.

lat%param%lattice_type = nint(param_ele%value(lattice_type$))
lat%input_taylor_order = nint(param_ele%value(taylor_order$))

if (associated(bp_com%param_ele%descrip)) then
  lat%lattice = bp_com%param_ele%descrip
  deallocate (bp_com%param_ele%descrip)
endif

if (bp_com%p0c_set) then
  call convert_pc_to (lat%ele(0)%value(p0c$), lat%param%particle, e_tot = lat%ele(0)%value(e_tot$))
elseif (bp_com%e_tot_set) then
  call convert_total_energy_to (lat%ele(0)%value(e_tot$), lat%param%particle, &
                                                         pc = lat%ele(0)%value(p0c$))
endif

v1 = param_ele%value(n_part$)
v2 = beam_ele%value(n_part$)
if (lat%param%n_part /= v1 .and. lat%param%n_part /= v2) then
  call parser_warning ('BOTH "PARAMETER[N_PART]" AND "BEAM, N_PART" SET.')
else if (v1 /= lat%param%n_part) then
  lat%param%n_part = v1
else
  lat%param%n_part = v2
endif

ix1 = nint(param_ele%value(particle$))
ix2 = nint(beam_ele%value(particle$))
if (ix1 /= lat%param%particle .and. ix2 /= lat%param%particle) &
        call parser_warning ('BOTH "PARAMETER[PARTICLE]" AND "BEAM, PARTICLE" SET.')
lat%param%particle = ix1
if (ix2 /=  lat%param%particle) lat%param%particle = ix2


! Transfer the new elements to a safe_place

ele_num = n_max - n_max_old
allocate (lat2%ele(1:ele_num))
lat2%ele(1:ele_num) = lat%ele(n_max_old+1:n_max)
n_max = n_max_old

! Do bookkeeping for settable dependent variables.

do i = 1, ele_num
  ele => lat2%ele(i)
  call settable_dep_var_bookkeeping (ele)
enddo

! Put in the new elements...
! First put in superimpose elements

do i = 1, ele_num
  ele => lat2%ele(i)
  if (ele%lord_status /= super_lord$) cycle

  select case (ele%key)
  case (wiggler$)
    if (ele%sub_key == periodic_type$) then
      if (ele%value(l_pole$) == 0 .and. ele%value(n_pole$) /= 0) then
        ele%value(l_pole$) = ele%value(l$) / ele%value(n_pole$) 
      endif
    endif
  end select

  ixx = ele%ixx
  call add_all_superimpose (lat, ele, plat%ele(ixx))
enddo

do i = 1, lat%n_ele_max
  if (lat%ele(i)%key == null_ele$) lat%ele(i)%key = -1 ! mark for deletion
enddo
call remove_eles_from_lat (lat)  ! remove all null_ele elements.

! Go through and create the overlay, girder, and group lord elements.

call parser_add_lord (lat2, ele_num, plat, lat)

! make matrices for entire lat

call lattice_bookkeeper (lat)
if (logic_option (.true., make_mats6)) call lat_make_mat6(lat, -1, orbit) 

!-----------------------------------------------------------------------------
! error check

if (debug_line /= '') call parser_debug_print_info (lat, debug_line)

if (.not. bmad_status%ok .and. bmad_status%exit_on_error) then
  call out_io (s_info$, r_name, 'FINISHED. EXITING ON ERRORS')
  stop
endif

call check_lat_controls (lat, .true.)

do i = lbound(plat%ele, 1) , ubound(plat%ele, 1)
  if (associated (plat%ele(i)%name)) then
    deallocate(plat%ele(i)%name)
    deallocate(plat%ele(i)%attrib_name)
    deallocate(plat%ele(i)%coef)
  endif
enddo

if (associated (plat%ele))      deallocate (plat%ele)
if (allocated(lat_name))        deallocate (lat_name, lat_indexx)

call deallocate_lat_pointers (lat2)

end subroutine
