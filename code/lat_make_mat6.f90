!+
! Subroutine lat_make_mat6 (lat, ix_ele, ref_orb, ix_branch)
!
! Subroutine to make the first order transfer map for an element or elements:
!   r_out = M * r_in + vec0
! M is the 6x6 linear transfer matrix (Jacobian) about the 
! reference orbit ref_orb.
!
! If the element lat%ele(ix_ele) is a lord element then the martices of 
! all the slave elements will be recomputed.
!
! Moudules Needed:
!   use bmad
!
! Input:
!   lat         -- lat_struct: Lat containing the elements.
!   ix_ele      -- Integer, optional: Index of the element. if not present
!                    or negative then the entire lattice will be made.
!   ref_orb(0:) -- Coord_struct, optional: Coordinates of the reference orbit
!                   around which the matrix is calculated. If not present 
!                   then the referemce is taken to be the origin.
!   ix_branch   -- Integer, optional: Branch index. Default is 0 (main lattice).
!
! Output:
!   lat        -- lat_struct:
!     ele(:)%mat6  -- Real(rp): 1st order (Jacobian) 6x6 transfer matrix.
!     ele(:)%vec0  -- Real(rp): 0th order transfer vector.
!-

recursive subroutine lat_make_mat6 (lat, ix_ele, ref_orb, ix_branch)

use bmad_struct
use bmad_utils_mod
use bmad_interface, except_dummy => lat_make_mat6
use bookkeeper_mod, only: control_bookkeeper

implicit none
                                       
type (lat_struct), target :: lat
type (coord_struct), optional, volatile :: ref_orb(0:)
type (coord_struct) orb_start, orb_end
type (ele_struct), pointer :: ele, slave
type (branch_struct), pointer :: branch

real(rp), pointer :: mat6(:,:), vec0(:)

integer, optional :: ix_ele, ix_branch
integer i, j, ie, i1, n_taylor, i_ele, i_branch
integer, save, allocatable :: ix_taylor(:)

logical transferred, want_taylor, zero_orbit

character(16), parameter :: r_name = 'lat_make_mat6'

! Error check

if (.not. allocated(ix_taylor)) allocate(ix_taylor(200))

i_ele = integer_option (-1, ix_ele)
i_branch = integer_option (0, ix_branch)

branch => lat%branch(i_branch)

if (i_ele == 0 .or. i_ele > branch%n_ele_max) then
  call out_io (s_fatal$, r_name, 'ELEMENT INDEX OUT OF BOUNDS: \i0\ ', i_ele)
  if (bmad_status%exit_on_error) call err_exit
  return
endif

if (present(ref_orb)) then
  if (ubound(ref_orb, 1) < branch%n_ele_track) then
    call out_io (s_fatal$, r_name, 'REF_ORB(:) ARRAY SIZE IS TOO SMALL!')
    call err_exit
  endif
endif

if (bmad_com%auto_bookkeeper) call compute_reference_energy (lat)

! Is the reference orbit zero?

zero_orbit = .true.
if (present(ref_orb)) then
  do i = 0, branch%n_ele_track
    if (any(ref_orb(i)%vec /= 0)) then
      zero_orbit = .false.
      exit
    endif
  enddo
endif

!--------------------------------------------------------------
! Make entire lat if i_ele < 0.
! First do the inter-element bookkeeping.

if (i_ele < 0) then         

  if (bmad_com%auto_bookkeeper) call control_bookkeeper (lat)

  ! Now make the transfer matrices.
  ! For speed if a element needs a taylor series then check if we can use
  ! one from a previous element.

  ! For consistancy, if no orbit is given, the starting coords in a super_slave
  ! will be taken as the ending coords of the previous super_slave.

  n_taylor = 0  ! number of taylor series found
  call init_coord (orb_end)

  do i = 1, branch%n_ele_track

    ele => branch%ele(i)
    want_taylor = (ele%mat6_calc_method == taylor$) .or. &
                  (ele%mat6_calc_method == symp_map$) .or. &
                  (ele%tracking_method == taylor$) .or. &
                  (ele%tracking_method == symp_map$)

    transferred = .false.
    if (want_taylor) then
      if (.not. associated(ele%taylor(1)%term)) then
        do j = 1, n_taylor
          ie = ix_taylor(j)
          if (.not. equivalent_taylor_attributes (ele, branch%ele(ie))) cycle
          if (present(ref_orb)) then
            if (any(ref_orb(i-1)%vec /= ref_orb(ie-1)%vec)) cycle
          endif
          call transfer_ele_taylor (branch%ele(ie), ele)
          transferred = .true.
          exit
        enddo
      endif
    endif

    ! Check if transfer matrix needs to be recomputed

    if (.not. bmad_com%auto_bookkeeper .and. ele%status%mat6 /= stale$) then
      if (present(ref_orb)) then
        if (all(ref_orb(i-1)%vec == ele%map_ref_orb_in%vec)) cycle
      endif
    endif

    ! call make_mat6 for this element

    if (zero_orbit) then 
      if (ele%slave_status == super_slave$) then
        orb_start = orb_end
        call make_mat6(ele, branch%param, orb_start, orb_end)
      else
        call make_mat6(ele, branch%param)
        ! Reset orb_end if not in a superposition block.
        if (ele%value(l$) /= 0) orb_end%vec = 0  
      endif
    else  ! else ref_orb must be present
      call make_mat6(ele, branch%param, ref_orb(i-1), ref_orb(i), .true.)
    endif

    ! save this taylor in the list if it is a new one. 

    if (associated(ele%taylor(1)%term) .and. .not. transferred) then
      n_taylor = n_taylor + 1
      if (n_taylor > size(ix_taylor)) call re_allocate (ix_taylor, 2*size(ix_taylor))
      ix_taylor(n_taylor) = i
    endif

    call set_lords_status_stale (ele, lat, mat6_status$)
    ele%status%mat6 = ok$

  enddo

  if (branch%param%status%mat6 == stale$) branch%param%status%mat6 = ok$

  ! calc super_lord matrices

  do i = branch%n_ele_track+1, branch%n_ele_max
    ele => branch%ele(i)
    if (ele%lord_status /= super_lord$) cycle
    mat6 => ele%mat6
    vec0 => ele%vec0
    slave => pointer_to_slave (lat, ele, 1)
    mat6 = slave%mat6
    vec0 = slave%vec0
    do j = 2, ele%n_slave
      slave => pointer_to_slave (lat, ele, j)
      mat6 = matmul(slave%mat6, mat6)
      vec0 = matmul(slave%mat6, vec0) + slave%vec0
    enddo
  enddo 

  return

endif

!-----------------------------------------------------------
! otherwise make a single element

ele => branch%ele(i_ele)

! Check if transfer matrix needs to be recomputed

if (.not. bmad_com%auto_bookkeeper .and. ele%status%mat6 /= stale$) then
  if (present(ref_orb)) then
    if (all(ref_orb(i-1)%vec == ele%map_ref_orb_in%vec)) return
  endif
endif

! Bookkeeping

call control_bookkeeper (lat, ele)

! For an element in the tracking part of the lattice

if (i_ele <= branch%n_ele_track) then
   if (present(ref_orb)) then
      call make_mat6(ele, branch%param, ref_orb(i_ele-1), ref_orb(i_ele), .true.)
   else
      call make_mat6(ele, branch%param)
   endif

  return
endif                        

! for a control element

if (ele%lord_status == super_lord$) then
  mat6 => ele%mat6
  call mat_make_unit(mat6)
  vec0 => ele%vec0
  vec0 = 0
endif

do i = 1, ele%n_slave
  slave => pointer_to_slave (lat, ele, i)

  if (present(ref_orb)) then
    call lat_make_mat6 (lat, slave%ix_ele, ref_orb, slave%ix_branch)
  else
    call lat_make_mat6 (lat, slave%ix_ele, ix_branch = slave%ix_branch)
  endif

  if (ele%lord_status == super_lord$) then
    mat6 = matmul(slave%mat6, mat6)
    vec0 = matmul(slave%mat6, vec0) + slave%vec0
  endif
enddo


end subroutine
