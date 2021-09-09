!+
! Subroutine lat_sanity_check (lat, err_flag)
!
! Routine to do lattice self-consistency checks including checking control links, etc.
!
! If the global variable global_com%exit_on_error = True and there is an error then 
! this routine will stop the program.
!
! Input:
!   lat -- lat_struct: Lattice to check
!
! Output:
!   err_flag -- Logical: Set True if there is an error. False otherwise.
!-

subroutine lat_sanity_check (lat, err_flag)

use bmad_interface, except_dummy => lat_sanity_check

implicit none
     
type (lat_struct), target :: lat
type (nametable_struct), pointer :: nt
type (ele_struct), pointer :: ele, slave, lord, lord2, slave1, slave2, ele2
type (branch_struct), pointer :: branch, slave_branch, branch2, associated_branch
type (photon_surface_struct), pointer :: surf
type (wake_sr_mode_struct), pointer :: sr_mode
type (wake_lr_mode_struct), pointer :: lr
type (floor_position_struct) floor0, floor
type (control_struct), pointer :: ctl, ctl1, ctl2
type (cylindrical_map_struct), pointer :: cl_map
type (grid_field_struct), pointer :: g_field
type (taylor_field_struct), pointer :: t_field
type (ele_attribute_struct) info

real(rp) s1, s2, ds, ds_small, l_lord, g(3)
real(rp), pointer :: array(:)

integer i_t, j, i_t2, ix, s_stat, l_stat, t2_type, n, cc(100), i, iw, i2, ib, ie
integer ix1, ix2, ii, i_b, i_b2, n_pass, k, is, tm, ix_match, dir1, dir2

character(16) str_ix_slave, str_ix_lord, str_ix_ele
character(*), parameter :: r_name = 'lat_sanity_check'

logical, intent(out) :: err_flag
logical good_control(12,12), girder_here, finished, foundit, problem_found

! Check the nametable.
! Instead of quiting, lat_sanity_check will repair a broken nametable.

problem_found = .false.
nt => lat%nametable
n = -1
do ib = 0, ubound(lat%branch, 1)
  branch => lat%branch(ib)

  do ie = 0, branch%n_ele_max
    n = n + 1
    ele => branch%ele(ie)

    if (ele%name /= nt%name(n)) then
      call out_io (s_fatal$, r_name, 'LAT NAMETABLE NAME ORDER MISMATCH!', 'PLEASE REPORT THIS!')
      problem_found = .true.
    endif

    call find_index(ele%name, nt, ix_match)
    if (ix_match < 0) then
      call out_io (s_fatal$, r_name, 'LAT NAMETABLE MAPPING MISMATCH!', 'PLEASE REPORT THIS!')
      problem_found = .true.
    endif

    if (n > 0) then
      if (nt%name(nt%index(n-1)) > nt%name(nt%index(n))) then
        call out_io (s_fatal$, r_name, 'LAT NAMETABLE INDEXX ORDER MISMATCH!', 'PLEASE REPORT THIS!')
        problem_found = .true.
      endif
    endif
  enddo
enddo

if (n /= nt%n_max) then
  call out_io (s_fatal$, r_name, 'LAT NAMETABLE SIZE MISMATCH!')
  problem_found = .true.
endif

if (problem_found) call create_lat_ele_nametable(lat, nt)

! Some global checks

if (lat%particle_start%direction /= -1 .and. lat%particle_start%direction /= 1) then
  call out_io (s_fatal$, r_name, 'PARTICLE_START DIRECTION IS NOT -1 NOR 1. IT IS: \i0\ ', lat%particle_start%direction)
  err_flag = .true.
endif

! good_control specifies what elements can control what other elements.

good_control = .false.
good_control(group_lord$, [minor_slave$, multipass_slave$, super_slave$]) = .true.
good_control(overlay_lord$, [minor_slave$, multipass_slave$, super_slave$]) = .true.
good_control(girder_lord$, [minor_slave$, multipass_slave$]) = .true.
good_control(super_lord$, [super_slave$]) = .true.
good_control(multipass_lord$, [multipass_slave$]) = .true.

err_flag = .false.
           
! loop over all branches

branch_loop: do i_b = 0, ubound(lat%branch, 1)
  branch => lat%branch(i_b)

  if (branch%ix_branch /= i_b) then
    call out_io (s_fatal$, r_name, &
              'BRANCH: ' // branch%name, &
              'IS OUT OF ORDER IN THE BRANCH(:) ARRAY \i0\ ', &
              i_array = [branch%ix_branch] )
    err_flag = .true.
  endif


  if (i_b > 0) then
    ix = branch%ix_from_branch

    if (ix < -1 .or. ix == i_b .or. ix > ubound(lat%branch, 1)) then 
      call out_io (s_fatal$, r_name, &
                'BRANCH: ' // branch%name, &
                'HAS A IX_FROM_BRANCH INDEX OUT OF RANGE: \i0\ ', i_array = [ix] )
      err_flag = .true.
    endif

    ! If there is a from branch

    if (ix > -1) then
      if (branch%ix_from_ele < -1 .or. branch%ix_from_ele > lat%branch(ix)%n_ele_track) then
        call out_io (s_fatal$, r_name, &
                  'BRANCH: ' // branch%name, &
                  'HAS A IX_FROM_ELE INDEX OUT OF RANGE: \i0\ ', i_array = [branch%ix_from_ele] )
        err_flag = .true.
      endif

      slave => lat%branch(ix)%ele(branch%ix_from_ele)
      str_ix_slave = ele_loc_name(slave)

      if (slave%key /= fork$ .and. slave%key /= photon_fork$) then
        call out_io (s_fatal$, r_name, &
              'BRANCH: ' // branch%name, &
              'HAS A FROM ELEMENT THAT IS NOT A FORK NOR A PHOTON_FORK ELEMENT: ' // slave%name)
        err_flag = .true.
      endif

      ix = nint(slave%value(ix_to_element$))
      if (ix /= branch%ix_to_ele) then
        call out_io (s_fatal$, r_name, &
              'BRANCH: ' // trim(branch%name) // ' (\i0\)', &
              'HAS A FROM FORK ' // trim(slave%name) // ' (\i0\>>\i0\).', &
              'IN WHICH THE IX_TO_ELEMENT (\i0\) DOES NOT MATCH THE BRANCH%IX_TO_ELEMENT (\i0\).', &
              i_array = [branch%ix_branch, slave%ix_branch, slave%ix_ele, ix, branch%ix_to_ele])
        err_flag = .true.
      endif
    endif

  endif

  ! branch%lat check

  if (.not. associated(branch%lat, lat)) then
    call out_io (s_fatal$, r_name, &
              'BRANCH: ' // trim(branch%name) // '   (\i0\)', &
              'HAS BAD BRANCH%LAT POINTER.', i_array = [i_b])
    err_flag = .true.
  endif

  !--------------------------------
  ! Loop over all elements

  ele_loop: do i_t = 0, branch%n_ele_max

    ele => branch%ele(i_t)
    str_ix_ele = '(' // trim(ele_loc_name(ele)) // ')'
    associated_branch => pointer_to_branch(ele)

    ! Element orientation

    if (i_t < branch%n_ele_track) then
      ele2 => branch%ele(i_t+1)
      if (ele%key == patch$) then
        dir1 = nint(ele%value(downstream_coord_dir$))
      else
        dir1 = ele%orientation
      endif

      if (ele2%key == patch$) then
        dir2 = nint(ele2%value(upstream_coord_dir$))
      else
        dir2 = ele2%orientation
      endif

      if (dir1 /= dir2) then
        call out_io (s_fatal$, r_name, &
                  'REVERSED (DOUBLE NEGATIVE SIGN IN LINE DEF) AND UNREVERSED ELEMENTS: ' // &
                  trim(ele%name) // ' AND ' // trim(ele2%name), &
                  'MUST HAVE A REFECTION PATCH PATCH IN BETWEEN.')
        err_flag = .true.
      endif
    endif

    ! Do not check the extra elements temporarily inserted by bmad_parser2.

    select case (ele%key)
    case (def_mad_beam$, def_parameter$, def_particle_start$, def_bmad_com$, def_line$, def_ptc_com$) 
      cycle
    end select

    ! Check limits

    if (has_attribute(ele, 'X1_LIMIT')) then
      if (ele%value(x1_limit$) /= 0 .and. ele%value(x1_limit$) == -ele%value(x2_limit$)) then
        call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // ele%name, &
                    'HAS X1_LIMIT EQUAL TO -X2_LIMIT.')
        err_flag = .true.
      endif

      if (ele%value(y1_limit$) /= 0 .and. ele%value(y1_limit$) == -ele%value(y2_limit$)) then
        call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // ele%name, &
                    'HAS Y1_LIMIT EQUAL TO -Y2_LIMIT.')
        err_flag = .true.
      endif
    endif

    ! Check switches

    if (ele%key /= overlay$ .and. ele%key /= group$) then
      do i = 1, num_ele_attrib$
        info = attribute_info(ele, i)
        if (info%kind /= is_switch$) cycle
        if (switch_attrib_value_name(info%name, ele%value(i), ele) /= null_name$) cycle
        call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // ele%name, &
                    'HAS ATTRIBUTE: ' // trim(info%name) // ' WHOSE VALUE IS INVALID: \i0\ ', i_array = [nint(ele%value(i))])
        err_flag = .true.
      enddo
    endif

    ! Check some ranges

    if (has_attribute(ele, 'FIELD_CALC')) then
      if (.not. valid_field_calc (ele, ele%field_calc)) then
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'HAS NON-VALID FIELD_CALC SETTING: \i0\ ', i_array = [ele%field_calc])
        err_flag = .true.
      endif
    endif

    ! Tracking methods check

    if (.not. any(ele%key == [group$, overlay$, girder$, ramper$, null_ele$])) then
      if (ele%tracking_method < 1 .or. ele%tracking_method > ubound(tracking_method_name, 1)) then
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'HAS TRACKING_METHOD SETTING OUT OF RANGE: \i0\ ', i_array = [ele%tracking_method])
        err_flag = .true.
      endif

      if (ele%spin_tracking_method < 1 .or. ele%spin_tracking_method > ubound(spin_tracking_method_name, 1)) then
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'HAS SPIN_TRACKING_METHOD SETTING OUT OF RANGE: \i0\ ', i_array = [ele%spin_tracking_method])
        err_flag = .true.
      endif

      if (ele%mat6_calc_method < 1 .or. ele%mat6_calc_method > ubound(mat6_calc_method_name, 1)) then
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'HAS MAT6_CALC_METHOD SETTING OUT OF RANGE: \i0\ ', i_array = [ele%mat6_calc_method])
        err_flag = .true.
      endif

      if (.not. valid_tracking_method(ele, ele%ref_species, ele%tracking_method)) then
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'HAS NON-VALID TRACKING_METHOD: ' // tracking_method_name(ele%tracking_method))
        err_flag = .true.
      endif

      if (.not. valid_mat6_calc_method(ele, ele%ref_species, ele%mat6_calc_method)) then
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'HAS NON-VALID MAT6_CALC_METHOD: ' // mat6_calc_method_name(ele%mat6_calc_method))
        err_flag = .true.
      endif
    endif

    !

    if (ele%ptc_integration_type < 1 .or. ele%ptc_integration_type > ubound(ptc_integration_type_name, 1)) then
      call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS PTC_INTEGRATION_TYPE SETTING OUT OF RANGE: \i0\ ', i_array = [ele%ptc_integration_type])
      err_flag = .true.
    endif

    ! Autoscale phase needs an AC field

    if (attribute_index(ele, 'AUTOSCALE_PHASE')/= 0 .and. &
                is_true(ele%value(autoscale_phase$)) .and. ele%field_calc == fieldmap$) then
      foundit = .false.
      if (associated(ele%cylindrical_map)) then
        do i = 1, size(ele%cylindrical_map)
          if (ele%cylindrical_map(i)%harmonic == 0) cycle
          foundit = .true.
          exit
        enddo
      endif

      if (associated(ele%grid_field)) then
        do i = 1, size(ele%grid_field)
          if (ele%grid_field(i)%harmonic == 0) cycle
          foundit = .true.
          exit
        enddo
      endif

      if (.not. foundit) then
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS AUTOSCALE_PHASE = T AND FIELD_CALC = FIELDMAP BUT ALL FIELD MAPS HAVE HARMONIC = 0.', &
                      'THAT IS, THERE ARE NO NO AC FIELDS PRESENT!')
        err_flag = .true.
      endif
    endif

    ! ac_kicker needs to have the time variation defined.

    if (ele%key == ac_kicker$) then
      if (.not. allocated(ele%ac_kick%amp_vs_time) .and. .not. allocated(ele%ac_kick%frequencies)) then
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'DOES NOT HAVE THE TIME DEPENDENCE (USING AMP_VS_TIME OR FREQUENCIES ATTRIBUTES) DEFINED.')
        err_flag = .true.
      endif

      if (allocated(ele%ac_kick%amp_vs_time) .and. allocated(ele%ac_kick%frequencies)) then
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS SET BOTH AMP_VS_TIME AND FREQUENCIES ATTRIBUTES SET.', &
                      'ONE AND ONLY ONE SHOULD BE SET.')
        err_flag = .true.
      endif
    endif

    ! Patch element should have at most one of e_tot_offset, e_tot_set and p0c_set nonzero

    if (ele%key == patch$) then
      n = 0
      if (ele%value(e_tot_offset$) /= 0) n = n + 1
      if (ele%value(e_tot_set$) /= 0) n = n + 1
      if (ele%value(p0c_set$) /= 0) n = n + 1

      if (n > 1) then
        call out_io (s_fatal$, r_name, &
                      'PATCH ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS MORE THAN ONE OF E_TOT_OFFSET, E_TOT_SET AND P0C_SET NONZERO!')
        err_flag = .true.
      endif  

      if ((ele%value(e_tot_set$) /= 0 .or. ele%value(p0c_set$) /= 0) .and. ele%orientation == -1) then
        call out_io (s_fatal$, r_name, &
                      'PATCH ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS REVERSED ORIENTATION AND HAS E_TOT_SET OR P0C_SET NONZERO!')
        err_flag = .true.
      endif  
    endif

    ! With fringe fields it is problematic to define how to handle an element with a negative length.
    ! Solution: Only allow negative length with drift or pipe.

    if (ele%value(l$) < 0) then
      select case (ele%key)
      case (drift$, pipe$, patch$, taylor$)
      case default
        call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'WHICH IS NOT A DRIFT, PIPE, PATCH OR TAYLOR, HAS A NEGATIVE LENGTH.')
        err_flag = .true.
      end select
    endif

    ! An e_gun must be the first element in a branch except for possibly marker elements
    ! Remember that an e_gun may be overlayed by a solenoid.

    if (ele%key == e_gun$ .and. ele%slave_status /= super_slave$) then
      ele2 => ele
      if (ele2%lord_status == super_lord$) ele2 => pointer_to_slave(ele2, 1)
      branch2 => ele2%branch

      if (branch2%param%geometry /= open$) then
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS AN E_GUN CAN ONLY EXIST IN LATTICE BRANCHES WITH AN OPEN GEOMENTRY.')
        err_flag = .true.
      endif

      do j = 1, ele2%ix_ele - 1
        if (branch2%ele(j)%key /= marker$ .and. branch2%ele(j)%key /= null_ele$) then
          call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'WHICH IS AN E_GUN CAN ONLY BE PROCEEDED IN THE LATTICE BY MARKER ELEMENTS.')
          err_flag = .true.
        endif
      enddo
    endif

    if ((ele%key == wiggler$ .or. ele%key == undulator$) .and. ele%value(l_period$) == 0 .and. &
                            (ele%field_calc == planar_model$ .or. ele%field_calc == helical_model$)) then
      call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                    'WHICH IS A WIGGLER OR UNDULATOR WITH FIELD_CALC SET TO PLANAR_MODEL OR HELICAL_MODEL.', &
                    'DOES NOT HAVE L_PERIOD NOR N_PERIOD SET.')
      err_flag = .true.
    endif      

    ! check fringe type

    if (ele%key == sbend$ .or. ele%key == rbend$) then
      select case (nint(ele%value(higher_order_fringe_type$)))
      case (none$, soft_edge_only$, hard_edge_only$, full$)
      case default
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS AN SBEND OR RBEND', &
                      'HAS INVALID HIGHER_ORDER_FRINGE_TYPE ATTRIBUTE: ' // &
                          higher_order_fringe_type_name(nint(ele%value(higher_order_fringe_type$))))
        err_flag = .true.
      end select
    endif

    if (has_attribute(ele, 'FRINGE_TYPE')) then
      if (.not. valid_fringe_type(ele, nint(ele%value(fringe_type$)))) then
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS A: ' // key_name(ele%key), &
                      'HAS INVALID FRINGE_TYPE ATTRIBUTE: ' // fringe_type_name(nint(ele%value(fringe_type$))))
        err_flag = .true.
      endif
    endif

    ! Diffraction_plate and mask elements must have an associated wall3d and all sections must be clear or opaque.
    ! Additionally the first section must be clear.

    if (ele%key == diffraction_plate$ .or. ele%key == mask$) then
      if (.not. associated (ele%wall3d)) then
        call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS A ' // key_name(ele%key), &
                      'DOES NOT HAVE AN ASSOCIATED WALL')
        err_flag = .true.

      else
        if (ele%wall3d(1)%section(1)%type /= clear$) then
          call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS A ' // key_name(ele%key), &
                      'MUST HAVE ITS FIRST SECTION BE OF TYPE CLEAR')
          err_flag = .true.
        endif

        do j = 1, size(ele%wall3d(1)%section)
          if (ele%wall3d(1)%section(j)%s /= 0) then
            call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS A ' // key_name(ele%key), &
                      'HAS A FINITE "S" VALUE. THIS DOES NOT MAKE SENSE.')
            err_flag = .true.
            exit
          endif      

          ii = ele%wall3d(1)%section(j)%type
          if (ii == opaque$ .or. ii == clear$) cycle
          call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'WHICH IS A ' // key_name(ele%key), &
                      'HAS A SECTION WITH TYPE NOT CLEAR OR OPAQUE.')
          err_flag = .true.
          exit
        enddo          
      endif

      if (nint(ele%value(mode$)) == reflection$) then
        call out_io (s_fatal$, r_name, &
                    'REFLECTION MODE NOT YET IMPLEMENTED FOR ELEMENT OF TYPE: ' // key_name(ele%key), &
                    'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                    'PLEASE CONTACT A BMAD MAINTAINER...')
        err_flag = .true.
      endif
    endif

    ! Match element checks

    if (ele%key == match$) then
      if (ele%value(beta_a0$) /= 0 .or. ele%value(beta_b0$) /= 0 .or. &
              ele%value(alpha_a0$) /= 0 .or. ele%value(alpha_b0$) /= 0 .or. &
              ele%value(beta_a1$) /= 0 .or. ele%value(beta_b1$) /= 0 .or. &
              ele%value(alpha_a1$) /= 0 .or. ele%value(alpha_b1$) /= 0 .or. is_true(ele%value(match_end$))) then

        if (ele%value(beta_a1$) <= 0 .or. ele%value(beta_b1$) <= 0) then
          call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'WHICH IS A MATCH ELEMENT HAS A BETA_A1 OR BETA_B1 THAT IS NOT POSITIVE.')
          err_flag = .true.
        endif

        if (is_false(ele%value(match_end$)) .and. (ele%value(beta_a0$) <= 0 .or. ele%value(beta_b0$) <= 0)) then
          call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'WHICH IS A MATCH ELEMENT HAS A BETA_A0 OR BETA_B0 THAT IS NOT POSITIVE.')
          err_flag = .true.
        endif

        if ((is_true(ele%value(match_end$)) .or. is_true(ele%value(match_end_orbit$))) .and. ele%value(delta_time$) /= 0) then
          call out_io (s_fatal$, r_name, &
                        'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                        'WHICH IS A FINITE DELTA_TIME AND MATCH_END OR MATCH_END_ORBIT IS TRUE.', &
                        'THIS IS NOT ALLOWED. SPLIT INTO TWO MATCH ELEMENTS IF NEEDED.')
          err_flag = .true.
        endif

      endif
    endif

    ! Zero length cavity is a verboten

    if (ele%key == lcavity$ .and. ele%value(l$) == 0) then
      call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                    'WHICH IS AN LCAVITY HAS ZERO LENGTH WHICH GIVES AN INFINITE GRADIENT.')
      err_flag = .true.
    endif

    if ((ele%key == lcavity$ .or. ele%key == rfcavity$) .and. &
          (nint(ele%value(longitudinal_mode$)) /= 0 .and. nint(ele%value(longitudinal_mode$)) /= 1)) then
      call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                    'WHICH IS AN LCAVITY OR RF CAVITY HAS LONGITUDINAL_MODE SET TO SOMETHING NOT 0 OR 1: \i0\ ', &
                    i_array = [nint(ele%value(longitudinal_mode$))] )
      err_flag = .true.
    endif

    !

    if (ele%key == lcavity$ .and. associated_branch%param%geometry == closed$) then
      call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                    'WHICH IS AN LCAVITY IS IN A LATTICE BRANCH WITH A CLOSED (NOT OPEN) GEOMETRY.')
      err_flag = .true.
    endif

    if (ele%key == converter$ .and. associated_branch%param%geometry == closed$) then
      call out_io (s_fatal$, r_name, &
                    'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                    'WHICH IS A CONVERTER IS IN A LATTICE BRANCH WITH A CLOSED (NOT OPEN) GEOMETRY.')
      err_flag = .true.
    endif

    ! Check wakes

    if (associated(ele%wake)) then
      if (allocated(ele%wake%lr%mode)) then
        do iw = 1, size(ele%wake%lr%mode)
          lr => ele%wake%lr%mode(iw)

          if (lr%freq_in < 0 .and. .not. has_attribute(ele, 'RF_FREQUENCY')) then
            call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS LR WAKE (#\i0\) WITH NEGATIVE FREQUENCY (LOCKED TO FUNDAMENTAL) BUT TYPE OF ELEMENT DOES NOT HAVE AN RF_FREQUENCY ATTRIBUTE (DOES NOT HAVE AN RF FIELD)!', &
                      i_array = [iw])
            err_flag = .true.
          endif

          if (lr%q /= real_garbage$ .and. lr%Q <= 0) then
            call out_io (s_fatal$, r_name, &
                      'ELEMENT: ' // trim(ele%name) // '  ' // trim(str_ix_ele), &
                      'HAS LR WAKE (#\i0\) WITH NON-POSITIVE Q!  \es10.1\ ', &
                      i_array = [iw], r_array = [lr%Q])
            err_flag = .true.
          endif
        enddo
      endif
    endif

    ! Check that %ix_ele and %ix_branch are correct. 

    if (ele%ix_ele /= i_t) then
      call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // ele%name, &
                'HAS BAD %IX_ELE INDEX: \i0\  (\i0\)', &
                'SHOULD BE: \i0\ ', i_array = [ele%ix_ele, ele%ix_branch, i_t] )
      err_flag = .true.
    endif

    if (ele%ix_branch /= i_b .and. ele%key /= null_ele$) then
      call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // trim(ele%name) // '   (\i0\)', &
                'HAS BAD %IX_BRANCH INDEX: \i0\  (\i0\)', &
                'SHOULD BE: \i0\ ', i_array = [ele%ix_ele, ele%ix_branch, i_b] )
      err_flag = .true.
    endif

    ! ele%branch check

    if (.not. associated(ele%branch, branch)) then
      call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // trim(ele%name) // '   (\i0\)', &
                'HAS BAD ELE%BRANCH POINTER.', i_array = [ele%ix_ele])
      err_flag = .true.
    endif

    ! branch check

    if (ele%key == fork$ .or. ele%key == photon_fork$) then
      ix = nint(ele%value(ix_to_branch$))
      if (ix < 0 .or. ix > ubound(lat%branch, 1) .or. ix == i_b) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'WHICH IS A: BRANCH OR PHOTON_BRANCH ELEMENT', &
                  'HAS A IX_TO_BRANCH INDEX OUT OF RANGE: \i0\ ', i_array = [ix] )
        err_flag = .true.
      endif
    endif

    ! wall3d check

    if (associated(ele%wall3d) .and. ele%key /= diffraction_plate$ .and. ele%key /= mask$) then
      do iw = 1, size(ele%wall3d)

        do k = 2, size(ele%wall3d(iw)%section)
          if (ele%wall3d(iw)%section(k-1)%s > ele%wall3d(iw)%section(k)%s) then
            call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'S VALUES FOR WALL3D SECTIONS NOT INCREASING.')
            err_flag = .true.
          endif
        enddo

        ! Only a warning...
        n = size(ele%wall3d(iw)%section)
        if (ele%wall3d(iw)%section(n)%s == ele%wall3d(iw)%section(1)%s) then
          call out_io (s_warn$, r_name, &
                  'DISTANCE BETWEEN FIRST AND LAST WALL SECTIONS IS ZERO FOR ELEMENT: '// ele%name)
        endif

      enddo
    endif

    ! If crystal graze_angle_in is set so must graze_angle_out

    if (ele%key == crystal$) then
      if (ele%value(graze_angle_in$) < 0 .or. ele%value(graze_angle_out$) < 0) then
        call out_io (s_fatal$, r_name, &
                  'BOTH GRAZE_ANGLE_IN AND GRAZE_ANGLE_OUT MUST BE NON-NEGATIVE.', &
                  'FOR ELEMENT: ' // ele%name)
        err_flag = .true.
      endif

      if (ele%value(graze_angle_in$) > 0 .neqv. ele%value(graze_angle_out$) > 0) then
        call out_io (s_fatal$, r_name, &
                  'IF GRAZE_ANGLE_IN IS SET SO MUST GRAZE_ANGLE_OUT BE SET AND VICE VERSA.', &
                  'FOR ELEMENT: ' // ele%name)
        err_flag = .true.
      endif

      if (ele%value(graze_angle_in$) > pi/2 .or. ele%value(graze_angle_out$) > pi/2) then
        call out_io (s_fatal$, r_name, &
                  'GRAZE_ANGLE_IN AND GRAZE_ANGLE_OUT BE LESS THAN PI/2.', &
                  'FOR ELEMENT: ' // ele%name)
        err_flag = .true.
      endif

      if (ele%component_name == '') then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'DOES NOT HAVE ITS CRYSTAL_TYPE SET.')
        err_flag = .true.
      endif
    endif

    if (ele%key == photon_init$) then
      if (ele%value(sig_E$) < 0 .or. ele%value(sig_vx$) < 0 .or. ele%value(sig_vy$) < 0 .or. &
          ele%value(sig_x$) < 0 .or. ele%value(sig_y$) < 0) then
        call out_io (s_fatal$, r_name, &
                  'ALL SIGMA MUST BE NONZERO.', &
                  'FOR ELEMENT: ' // ele%name)
        err_flag = .true.
      endif

      if (ele%value(sig_vx$) > 1 .or. ele%value(sig_vy$) > 1 .or. &
          ele%value(sig_x$) > 1 .or. ele%value(sig_y$) > 1) then
        call out_io (s_fatal$, r_name, &
                  'ALL VELOCITY AND POSITION SIGMAS MUST BE LESS THAN 1.', &
                  'FOR ELEMENT: ' // ele%name)
        err_flag = .true.
      endif
    endif

    ! photon elements with a surface must have ele%photon associated.

    if (ele%key == crystal$ .or. ele%key == mirror$ .or. ele%key == multilayer_mirror$) then
      if (.not. associated(ele%photon)) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'SHOULD HAVE AN ASSOCIATED %PHOTON COMPONENT BUT IT DOES NOT!')
        err_flag = .true.
      endif
    endif

    !

    if ((ele%key == sample$ .and. nint(ele%value(mode$)) == transmission$) .or. ele%key == multilayer_mirror$) then
      if (ele%component_name == '') then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'DOES NOT HAVE ITS MATERIAL_TYPE SET.')
        err_flag = .true.
      endif
    endif

    ! photonic element surface consistancy check

    if (associated(ele%photon)) then
      surf => ele%photon%surface
      if (all (surf%grid%type /= [not_set$, segmented$, h_misalign$, displacement$])) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'HAS AN INVALID SURFACE%GRID%TYPE SETTING: \i0\ ', i_array = [surf%grid%type])
        err_flag = .true.
      endif

      if (surf%grid%type /= not_set$ .and. any (surf%grid%dr == 0)) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'HAS A ZERO DR VALUE BUT THE GRID TYPE IS NOT OFF. \2f10.2\ ', r_array = surf%grid%dr)
        err_flag = .true.
      endif

      if (surf%grid%type /= not_set$ .and. .not. allocated(surf%grid%pt)) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'HAS NO GRID IS DEFINED!')
        err_flag = .true.
      endif

      if (surf%grid%type == h_misalign$ .and. ele%value(b_param$) > 0) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'HAS GRID TYPE H_MISALIGN BUT THIS IS NOT IMPLEMENTED FOR LAUE DIFFRACTION!')
        err_flag = .true.
      endif

      g = surf%spherical_curvature + surf%elliptical_curvature
      if ((g(1) /= 0 .or. g(2) /= 0) .and. g(3) == 0) then
        call out_io (s_warn$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'HAS ELLIPTICAL_CURVATURE_Z+SPHERICAL_CURVATURE = 0 BUT ELLIPTICAL_CURVATURE_X+SPHERICAL_CURVATURE OR', &
                  'ELLIPTICAL_CURVATURE_Y+SPHERICAL_CURVATURE IS NON-ZERO. THE CURVATURE WILL BE IGNORED.')
      endif
    endif

    ! Cylindrical_map field

    if (associated(ele%cylindrical_map)) then
      do iw = 1, size(ele%cylindrical_map)
        cl_map => ele%cylindrical_map(iw)
        if (cl_map%harmonic == 0) then
          if (cl_map%phi0_fieldmap /= 0) then
            call out_io (s_fatal$, r_name, &
                  'CYLINDRICAL_MAP IN ELEMENT: ' // ele%name, &
                  'HAS ZERO HARMONIC (THAT IS, REPRESENTS A DC FIELD) BUT HAS NON-ZERO PHI0_FIELDMAP.')
            err_flag = .true.
          endif

        else
          select case (ele%key)
          case (lcavity$, rfcavity$, em_field$, e_gun$)
          case default
            call out_io (s_fatal$, r_name, &
                  'CYLINDRICAL_MAP IN ELEMENT: ' // ele%name, &
                  'HAS NON-ZERO HARMONIC (THAT IS, REPRESENTS AN RF FIELD).', &
                  'BUT THAT IS NOT ALLOWED FOR THIS TYPE OF ELEMENT: ' // key_name(ele%key))
            err_flag = .true.
          end select
        endif
      enddo
    endif

    ! Grid_field field

    if (associated(ele%grid_field)) then
      do iw = 1, size(ele%grid_field)
        g_field => ele%grid_field(iw)

        if (g_field%interpolation_order /= 1 .and. g_field%interpolation_order /= 3) then
          call out_io (s_fatal$, r_name, &
                'GRID_FIELD IN ELEMENT: ' // ele%name, &
                'HAS INTERPOLATION_ORDER VALUE THAT IS NOT 1 OR 3: \i0\ ', i_array = [g_field%interpolation_order])
          err_flag = .true.
        endif


        if (g_field%harmonic == 0) then
          if (g_field%phi0_fieldmap /= 0) then
            call out_io (s_fatal$, r_name, &
                  'GRID_FIELD IN ELEMENT: ' // ele%name, &
                  'HAS ZERO HARMONIC (THAT IS, REPRESENTS A DC FIELD) BUT HAS NON-ZERO PHI0_FIELDMAP.')
            err_flag = .true.
          endif

        else
          select case (ele%key)
          case (lcavity$, rfcavity$, em_field$, e_gun$)
          case default
            call out_io (s_fatal$, r_name, &
                  'GRID_FIELD IN ELEMENT: ' // ele%name, &
                  'HAS NON-ZERO HARMONIC (THAT IS, REPRESENTS AN RF FIELD).', &
                  'BUT THAT IS NOT ALLOWED FOR THIS TYPE OF ELEMENT: ' // key_name(ele%key))
            err_flag = .true.
          end select

          if (g_field%field_type /= mixed$) then
            call out_io (s_fatal$, r_name, &
                  'GRID_FIELD IN ELEMENT: ' // ele%name, &
                  'HAS NON-ZERO HARMONIC (THAT IS, REPRESENTS AN RF FIELD).', &
                  'BUT THE FIELD_TYPE IS NOT SET TO "MIXED".')
            err_flag = .true.
          endif
        endif

        if (g_field%dr(1) == 0 .or. g_field%dr(2) == 0) then
          call out_io (s_fatal$, r_name, &
                'GRID_FIELD IN ELEMENT: ' // ele%name, &
                'HAS DR(1) OR DR(2) EQUAL TO 0')
          err_flag = .true.
        endif

        if (g_field%geometry == xyz$ .and. g_field%dr(3) == 0) then
          call out_io (s_fatal$, r_name, &
                'GRID_FIELD IN ELEMENT: ' // ele%name, &
                'HAS GEOMETRY = "XYZ" BUT DR(3) IS 0.')
          err_flag = .true.
        endif
      enddo
    endif

    ! taylor_field

    if (associated(ele%taylor_field)) then
      do iw = 1, size(ele%taylor_field)
        t_field => ele%taylor_field(iw)
        do j = lbound(t_field%ptr%plane, 1), ubound(t_field%ptr%plane, 1)
          do k = 1, 3
            if (allocated(t_field%ptr%plane(j)%field(k)%term)) cycle
            call out_io (s_fatal$, r_name, &
                  'TAYLOR_FIELD IN ELEMENT: ' // ele%name, &
                  'HAS NO TAYLOR TERMS FOR THE ' // trim(plane_name(k)) // ' FIELD COMPONENT OF PLANE WITH INDEX \i0\ ', &
                  i_array = [j])
            err_flag = .true.
          enddo
        enddo
      enddo
    endif

    ! match elements with match_end set should only appear in opens

    if (ele%key == match$) then
      if (is_true(ele%value(match_end$)) .and. lat%param%geometry /= open$) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // ele%name, &
                  'WHICH IS A: MATCH ELEMENT', &
                  'HAS THE MATCH_END ATTRIBUTE SET BUT THIS IS NOT AN OPEN LATTICE!')
        err_flag = .true.
      endif
    endif

    ! Two "consecutive" element with finite length and opposite orientations is not physical.
    ! But is allowed for testing purposes.

    if (abs(ele%orientation) /= 1) then
      call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // trim(ele%name) // ' HAS BAD ORIENTATION VALUE: \i0\ ', i_array = [ele%orientation])
    endif


    if (i_t <  branch%n_ele_track .and. ele%value(l$) /= 0 .and. abs(ele%orientation) == 1 .and. &
        ele%key /= patch$ .and. ele%key /= floor_shift$) then
      do i2 = i_t + 1, branch%n_ele_track
        ele2 => branch%ele(i2)
        if (abs(ele2%orientation) /= 1) exit
        if (ele2%key == patch$ .or. ele2%key == floor_shift$) exit
        if (ele2%value(l$) == 0) cycle
        if (ele%orientation * ele2%orientation /= 1) then
          call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // trim(ele%name) // ' WITH ORIENTATION: \i0\ ', &
                'WHICH IS NOT SPEARATED BY ELEMENTS OF ANY LENGTH FROM: ' // trim(ele2%name) // ' WITH ORIENTATION: \i0\ ', &
                'HAVE CONFOUNDING ORIENTATIONS! THIS IS NOT PHYSICAL.', i_array = [ele%orientation, ele2%orientation])
        endif
        exit
      enddo
    endif

    !

    l_stat = ele%lord_status
    s_stat = ele%slave_status

    ! multipoles and ab_multipoles are not allowed to have a finite length if they are super_lords

    if (l_stat == super_lord$ .and. ele%value(l$) /= 0 .and. &
                    (ele%key == multipole$ .or. ele%key == ab_multipole$)) then 
      call out_io (s_fatal$, r_name, &
                'SUPER_LORD: ' // ele%name, &
                'IS A MULTIPOLE OR AB_MULTIPOLE AND HAS FINITE LENGTH.', &
                'THIS IS NOT ALLOWED FOR A SUPER_LORD.')
      err_flag = .true.
    endif

    ! multipass lords/slaves must share %wall3d memory

    if (l_stat == multipass_lord$) then
      do is = 1, ele%n_slave
        slave => pointer_to_slave(ele, is)
        if (.not. associated(ele%wall3d) .and. .not. associated(slave%wall3d)) cycle
        if (associated(ele%wall3d) .and. .not. associated(slave%wall3d)) then
          call out_io (s_fatal$, r_name, &
                    'MULTIPASS_LORD: ' // ele%name, &
                    'HAS A SLAVE: ' // slave%name, &
                    'THE LORD HAS A %WALL3D BUT THE SLAVE DOES NOT.')
          err_flag = .true.
        elseif (.not. associated(ele%wall3d) .and. associated(slave%wall3d)) then
          call out_io (s_fatal$, r_name, &
                    'MULTIPASS_LORD: ' // ele%name, &
                    'HAS A SLAVE: ' // slave%name, &
                    'THE SLAVE HAS A %WALL3D BUT THE LORD DOES NOT.')
          err_flag = .true.
        elseif (.not. associated(ele%wall3d, slave%wall3d)) then
          call out_io (s_fatal$, r_name, &
                    'MULTIPASS_LORD: ' // ele%name, &
                    'HAS A SLAVE: ' // slave%name, &
                    'THE %WALL3D OF BOTH DO NOT POINT TO THE SAME MEMORY LOCATION.')
          err_flag = .true.
        endif
      enddo
    endif

    ! sbend multipass lord must have non-zero ref_energy or multipass_ref_energy must be set to first_pass$.
    ! This restriction is necessary to compute the reference orbit.
    ! Check both p0c and e_tot since if this routine is called by bmad_parser we
    ! can have one zero and the other non-zero.

    if (ele%key == sbend$ .and. l_stat == multipass_lord$) then
      if (ele%value(p0c$) == 0 .and. ele%value(e_tot$) == 0 .and. nint(ele%value(multipass_ref_energy$)) == user_set$) then
        call out_io (s_fatal$, r_name, &
                  'BEND: ' // ele%name, &
                  'WHICH IS A: MULTIPASS_LORD', &
                  'DOES NOT HAVE A REFERENCE ENERGY OR MULTIPASS_REF_ENERGY DEFINED')
        err_flag = .true.
      endif
    endif

    ! A multipass lord that is a magnetic or electric element must either:
    !   1) Have field_master = True or
    !   2) Have a defined reference energy.

    if (l_stat == multipass_lord$ .and. .not. ele%field_master .and. ele%value(p0c$) == 0 .and. &
        ele%value(e_tot$) == 0 .and. ele%value(multipass_ref_energy$) == 0) then
      select case (ele%key)
      case (quadrupole$, sextupole$, octupole$, solenoid$, sol_quad$, sbend$, &
            hkicker$, vkicker$, kicker$, elseparator$)
        call out_io (s_fatal$, r_name, &
              'FOR MULTIPASS LORD: ' // ele%name, &
              'MULTIPASS_REF_ENERGY, E_TOT, AND P0C ARE ALL ZERO AND FIELD_MASTER = FALSE!')
        err_flag = .true.
      end select
    endif

    ! The first lord of a multipass_slave should be its multipass_lord

    if (s_stat == multipass_slave$) then
      lord2 => pointer_to_lord(ele, 1)
      if (lord2%lord_status /= multipass_lord$) then
        call out_io (s_fatal$, r_name, &
              'FOR MULTIPASS SLAVE: ' // ele%name, &
              'FIRST LORD IS NOT A MULTIPASS_LORD! IT IS: ' // lord2%name)
        err_flag = .true.
      endif
    endif

    ! Check that element is in correct part of the ele(:) array

    if (ele%key == null_ele$ .and. i_t > branch%n_ele_track) cycle      

    if (i_t > branch%n_ele_track) then
      if (s_stat == super_slave$) then
        call out_io (s_fatal$, r_name, &
                  'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                  'IS *NOT* IN THE TRACKING PART OF LATTICE LIST', &
                  i_array = [i_t] )
        err_flag = .true.
      endif                                             
    else                                                         
      if (l_stat == super_lord$ .or. l_stat == overlay_lord$ .or. &
          l_stat == group_lord$ .or. l_stat == girder_lord$ .or. &
          l_stat == multipass_lord$) then
        call out_io (s_fatal$, r_name, &
                  'ELEMENT: ' // trim(ele%name) // '  (\i0\)', &
                  'WITH LORD_STATUS: ' // control_name(l_stat), &
                  'IS IN THE TRACKING PART OF LATTICE LIST', i_array = [i_t] )
        err_flag = .true.
      endif
    endif

    if (.not. any( [not_a_lord$, girder_lord$, super_lord$, overlay_lord$, group_lord$, &
                      multipass_lord$, ramper_lord$] == l_stat)) then
      call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // trim(ele%name) // '  (\i0\)', &
                'HAS UNKNOWN LORD_STATUS INDEX: \i0\ ', i_array = [i_t, l_stat] )
      err_flag = .true.
    endif

    if (.not. any( [minor_slave$, free$, super_slave$, multipass_slave$] == s_stat)) then
      call out_io (s_fatal$, r_name, &
                'ELEMENT: ' // trim(ele%name) // '  (\i0\)', &
                'HAS UNKNOWN SLAVE_STATUS INDEX: \i0\ ', i_array = [i_t, s_stat] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. ele%n_lord == 0) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ZERO LORDS!', i_array = [i_t] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. associated(ele%wall3d)) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ASSOCIATED %WALL3D COMPONENT.', i_array = [i_t] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. associated(ele%cartesian_map)) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ASSOCIATED %CARTESIAN_MAP COMPONENT.', i_array = [i_t] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. associated(ele%cylindrical_map)) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ASSOCIATED %CYLINDRICAL_MAP COMPONENT.', i_array = [i_t] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. associated(ele%grid_field)) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ASSOCIATED %GRID_FIELD COMPONENT.', i_array = [i_t] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. associated(ele%taylor_field)) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ASSOCIATED %TAYLOR_FIELD COMPONENT.', i_array = [i_t] )
      err_flag = .true.
    endif

    if (s_stat == super_slave$ .and. associated(ele%wake)) then
      call out_io (s_fatal$, r_name, &
                'SUPER_SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                'HAS ASSOCIATED %WAKE COMPONENT.', i_array = [i_t] )
      err_flag = .true.
    endif

    ! Check knots

    if (associated(ele%control)) then
      if (allocated(ele%control%x_knot)) then
        array => ele%control%x_knot
        do i = 2, size(array)
          if (array(i-1) >= array(i)) then
            call out_io (s_fatal$, r_name, &
                    'CONTROLLER USING KNOT POINTS: ' // ele%name, &
                    'HAS X_KNOT VALUES THAT ARE NOT STRICKLY ASCENDING: ' // real_str(array(i-1), 12) // &
                                                                                 ', ' // real_str(array(i), 12))
            err_flag = .true.
          endif
        enddo

        if (ele%key == ramper$) then
          do i = 1, size(ele%control%ramp)
            if (size(ele%control%x_knot) /= size(ele%control%ramp(i)%y_knot)) then
              call out_io (s_fatal$, r_name, &
                    'RAMPER LORD: ' // ele%name, &
                    'HAS X_KNOT SIZE DIFFERENT FROM Y_KNOT SIZE FOR SLAVE #' // int_str(i))
              err_flag = .true.
            endif
          enddo
        else
          do i = 1, ele%n_slave
            slave => pointer_to_slave(ele, i, ctl)
            if (size(ele%control%x_knot) /= size(ctl%y_knot)) then
              call out_io (s_fatal$, r_name, &
                    'RAMPER LORD: ' // ele%name, &
                    'HAS X_KNOT SIZE DIFFERENT FROM Y_KNOT SIZE FOR SLAVE #' // int_str(i))
              err_flag = .true.
            endif
          enddo
        endif

      endif
    endif

    ! check that super_lord elements have their slaves in the correct order

    if (l_stat == super_lord$) then
      do i = ele%ix1_slave+1, ele%ix1_slave+ele%n_slave-1
        slave_branch => lat%branch(lat%control(i)%slave%ix_branch)
        ix1 = lat%control(i-1)%slave%ix_ele
        ix2 = lat%control(i)%slave%ix_ele
        if (ix1 == ix2) then
          call out_io (s_fatal$, r_name, &
                    'DUPLICATE SUPER_SLAVES: ', trim(slave_branch%ele(ix1)%name) // '  (\i0\)', &
                    'FOR SUPER_LORD: ' // trim(ele%name) // '  (\i0\)', &
                    i_array = [ix1, i_t] )
          err_flag = .true.

        elseif (ix1 < 1 .or. ix1 > slave_branch%n_ele_track .or. ix2 < 1 .or. ix2 > slave_branch%n_ele_track) then
          call out_io (s_fatal$, r_name, &
                    'SUPER LORD INDEX CORRUPTION! \i0\, \i0\ ', &
                    'FOR SUPER_LORD: ' // trim(ele%name) // '  (\i0\)', &
                    i_array = [ix1, ix2, i_t] )
          err_flag = .true.

        else
          ! All elements in between are not controlled and must be zero length
          ii = ix1
          do 
            ii = ii + 1
            if (ii > slave_branch%n_ele_track) ii = 1
            if (ii == ix2) exit
            if (slave_branch%ele(ii)%value(l$) /= 0) then
              call out_io (s_fatal$, r_name, &
                'CONSECUTIVE SUPER_SLAVES: ' // trim(branch%ele(ix1)%name) // ', ' // branch%ele(ix2)%name, &
                'OF SUPER_LORD: ' // trim(ele%name) // '  (\i0\)', &
                'HAS AN ELEMENT IN BETWEEN WITH NON-ZERO LENGTH: ' // trim(slave_branch%ele(ii)%name), &
                i_array = [i_t] )
              err_flag = .true.
            endif
          enddo
        endif
      enddo
    endif

    ! Check that super_lords have the correct length.

    if (l_stat == super_lord$) then
      ds_small = 10 / 10.0_rp**precision(1.0_rp) ! Used to avoid roundoff problems
      slave => pointer_to_slave(ele, 1)
      s1 = slave%s_start
      slave => pointer_to_slave(ele, ele%n_slave)
      s2 = slave%s
      if (s2 >= s1) then
        ds = s2 - s1
        ds_small = ds_small * max(abs(s1), abs(s2)) 
      else
        ds = (branch%param%total_length - s1) + s2
        ds_small = ds_small * max(abs(s1), abs(s2), branch%param%total_length)
      endif 
      l_lord = ele%value(l$) + ele%value(lord_pad2$) + ele%value(lord_pad1$)
      if (abs(l_lord - ds) > bmad_com%significant_length + ds_small) then
        call out_io (s_fatal$, r_name, &
                  'SUPER_LORD: ' // trim(ele%name) // '  (\i0\)', &
                  'HAS LENGTH (+ POSSIBLE PADDING) OF: \f15.10\ ', &
                  'WHICH IS NOT EQUAL TO THE SUM OF THE SLAVE LENGTHS \f15.10\.', &
                   i_array = [i_t], r_array =  [l_lord, ds])
        err_flag = .true.
      endif
    endif

    ! The ultimate slaves of a multipass_lord must must be in order

    if (l_stat == multipass_lord$) then
      do i = 2, ele%n_slave
        slave1 => pointer_to_slave(ele, i-1)
        if (slave1%lord_status == super_lord$) slave1 => pointer_to_slave(slave1, 1)
        slave2 => pointer_to_slave(ele, i)
        if (slave2%lord_status == super_lord$) slave2 => pointer_to_slave(slave2, 1)

        if (slave2%ix_branch < slave1%ix_branch .or. &
            (slave2%ix_branch == slave1%ix_branch .and. slave2%ix_ele <= slave1%ix_ele)) then
          call out_io (s_fatal$, r_name, &
                    'SLAVES OF A MULTIPASS_LORD: ' // trim(slave1%name) // '  (\i0\)', &
                    '                          : ' // trim(slave2%name) // '  (\i0\)', &
                    'ARE OUT OF ORDER IN THE LORD LIST', &
                    'FOR MULTIPASS_LORD: ' // trim(ele%name) // '  (\i0\)', &
                    i_array = [slave1%ix_ele, slave2%ix_ele, i_t] )
          err_flag = .true.
        endif
      enddo
    endif

    ! check regular slaves

    do j = ele%ix1_slave, ele%ix1_slave+ele%n_slave+ele%n_slave_field-1

      if (j < 0 .or. j > lat%n_control_max) then
        call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name)  // '  (\i0\)', &
                  'HAS IX_SLAVE INDEX OUT OF BOUNDS: \3i5\ ', &
                  i_array = [i_t, ele%ix1_slave, ele%n_slave, ele%n_slave_field] )
        err_flag = .true.
      endif

      ctl => lat%control(j)

      if (ctl%lord%ix_ele /= i_t .or. ctl%lord%ix_branch /= i_b) then
        call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)', &
                  'HAS A %LORD%IX_ELE POINTER MISMATCH: \i0\ ', &
                  'AT: \i0\ ', &
                  i_array = [i_t, ctl%lord%ix_ele, j] )
        err_flag = .true.
      endif

      i_t2 = ctl%slave%ix_ele
      i_b2 = ctl%slave%ix_branch

      if (i_t2 < 0 .or. i_t2 > lat%branch(i_b2)%n_ele_max) then
        call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)', &
                  'HAS A SLAVE INDEX OUT OF RANGE: \i0\ ', &
                  'AT: \i0\ ', &
                  i_array = [i_t, i_t2, j] )
        err_flag = .true.
        cycle
      endif

      slave => lat%branch(i_b2)%ele(i_t2)
      t2_type = slave%slave_status 
      str_ix_slave = ele_loc_name(slave)

      if (j <= ele%ix1_slave+ele%n_slave-1 .and. .not. good_control(l_stat, t2_type) .and. ctl%ix_attrib /= l$) then
        call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)',  &
                  'WITH LORD_STATUS: ' // control_name(l_stat), &
                  'HAS A SLAVE: ' // trim(slave%name) // '  (\i0\)', &
                  'WITH SLAVE_STATUS: ' // control_name(t2_type), &
                  i_array = [i_t, i_t2] )
        err_flag = .true.
      endif

      if (l_stat /= group_lord$ .and. l_stat /= girder_lord$) then
        do ix = slave%ic1_lord, slave%ic1_lord+slave%n_lord+slave%n_lord_field-1
          if (ix < 1 .or. ix > lat%n_ic_max) then
            call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)',  &
                  'HAS A SLAVE: ' // trim(slave%name) // '  (\i0\)', &
                  'AND THE SLAVE HAS A BAD IC POINTER. ', &
                  i_array = [i_t, i_t2] )
            err_flag = .true.
            exit
          endif

          k = lat%ic(ix)
          if (k < 1 .or. k > lat%n_control_max) then
            call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)',  &
                  'HAS A SLAVE: ' // trim(slave%name) // '  (\i0\)', &
                  'AND THE SLAVE HAS A BAD CONTROL POINTER. ', &
                  i_array = [i_t, i_t2] )
            err_flag = .true.
            exit
          endif
        enddo

        foundit = .false.
        do ix = slave%ic1_lord, slave%ic1_lord+slave%n_lord+slave%n_lord_field-1
          k = lat%ic(ix)
          if (lat%control(k)%lord%ix_ele /= i_t .or. lat%control(k)%lord%ix_branch /= i_b) cycle
          foundit = .true.
          exit
        enddo
        if (.not. foundit) then
          call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)',  &
                  'HAS A SLAVE: ' // trim(slave%name) // '  (\i0\)', &
                  'AND THE SLAVE HAS NO CONTROL STRUCT POINTING TO THE LORD. ', &
                  i_array = [i_t, i_t2] )
          err_flag = .true.
        endif
      endif

    enddo  ! j = ele%ix1_slave, ele%ix1_slave+ele%n_slave-1

    ! Check that field overlaps are unique

    n = ele%ix1_slave + ele%n_slave
    do j = n, n + ele%n_slave_field - 1
      ctl1 => lat%control(j)
      do k = n, j-1
        ctl2 => lat%control(k)
        if (ctl1%slave == ctl2%slave) then
          slave => pointer_to_ele(lat, ctl1%slave)
          call out_io (s_fatal$, r_name, &
                  'LORD: ' // trim(ele%name) // '  (\i0\)',  &
                  'HAS MULTIPLE FIELD OVERLAP POINTERS TO SLAVE: ' // trim(slave%name) // '  (\i0\)', &
                  i_array = [i_t, ctl1%slave%ix_ele] )
          err_flag = .true.
        endif
      enddo
    enddo

    ! check lords

    girder_here = .false.

    do ix = ele%ic1_lord, ele%ic1_lord+ele%n_lord+ele%n_lord_field-1

      if (ix < 1 .or. ix > lat%n_control_max) then
        call out_io (s_fatal$, r_name, &
                  'SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                  'HAS IC_LORD INDEX OUT OF BOUNDS: \3i5\ ', &
                  i_array = [i_t, ele%ic1_lord, ele%n_lord, ele%n_lord_field] )
        err_flag = .true.
      endif

      j = lat%ic(ix)

      if (j < 1 .or. j > lat%n_control_max) then
        call out_io (s_fatal$, r_name, &
                  'SLAVE: ' // trim(ele%name) // '  (\i0\)', &
                  'HAS IC INDEX OUT OF BOUNDS: \2i5\ ', & 
                  i_array = [i_t, ix, j] )
        err_flag = .true.
      endif

      ctl => lat%control(j)
      i_b2 = ctl%lord%ix_branch 

      if (i_b2 < 0 .or. i_b2 > ubound(lat%branch, 1) .or. (i_b2 /= 0 .and. ix <= ele%ic1_lord+ele%n_lord-1)) then
        call out_io (s_fatal$, r_name, &
                  'SLAVE: ' // trim(ele%name) // ' ' // str_ix_ele, &
                  'HAS A LORD BRANCH OUT OF RANGE: \3i7\ ', &
                  i_array = [ix, j, i_b2] )
        err_flag = .true.
        cycle
      endif


      i_t2 = ctl%lord%ix_ele

      if (ctl%slave%ix_ele /= i_t) then
        call out_io (s_fatal$, r_name, &
                  'SLAVE: ' // trim(ele%name) // '  ' // str_ix_ele, &
                  'HAS A %IX_SLAVE POINTER MISMATCH: \i0\ ', &
                  'AT: \2i7\ ', &
                  i_array = [ctl%slave%ix_ele, ix, j] )
        err_flag = .true.
      endif

      if (i_t2 < 1 .or. i_t2 > lat%branch(i_b2)%n_ele_max) then
        call out_io (s_fatal$, r_name, &
                  'SLAVE: ' // trim(ele%name) // ' ' // str_ix_ele, &
                  'HAS A LORD INDEX OUT OF RANGE: \3i7\ ', &
                  i_array = [ix, j, i_t2] )
        err_flag = .true.
        cycle
      endif

      lord => lat%branch(i_b2)%ele(i_t2)
      t2_type = lord%lord_status
      str_ix_lord = ele_loc_name(lord)

      if (ix <= ele%ic1_lord+ele%n_lord-1 .and. .not. good_control(t2_type, s_stat)) then
        call out_io (s_fatal$, r_name, &
                  'SLAVE: ' // trim(ele%name) // '  ' // str_ix_ele, &
                  'WITH SLAVE_STATUS: ' // control_name(s_stat), &
                  'HAS A LORD: ' // trim(lord%name) // '  (\i0\)', &
                  'WITH LORD_STATUS: ' // control_name(t2_type), &
                  i_array = [i_t2] )
        err_flag = .true.
      endif

      ! element is only allowed more than one girder_lord if custom geometry calculation is done.

      if (t2_type == girder_lord$) then
        if (girder_here) then
          call ele_geometry_hook (floor0, ele, floor, finished, 1.0_rp)
          if (.not. finished) then
            call out_io (s_fatal$, r_name, &
                    'SLAVE: ' // trim(ele%name) // '  ' // str_ix_ele, &
                    'HAS MORE THAN ONE GIRDER_LORD.', &
                    i_array = [i_t] )
            err_flag = .true.
         endif
        endif
        girder_here = .true.
      endif

    enddo  ! ix = ele%ic1_lord, ele%ic1_lord+ele%n_lord-1

  enddo ele_loop

enddo branch_loop

!

if (err_flag .and. global_com%exit_on_error) stop

end subroutine
