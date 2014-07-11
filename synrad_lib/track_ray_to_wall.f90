!+
! subroutine track_ray_to_wall (ray, lat, walls, hit_flag, track_max)
!
! subroutine to propagate a synch radiation ray until it hits
!    a wall
!
! Modules needed:
!   use synrad_mod
!
! Input:
!   ray    -- ray_struct: synch radiation ray with starting
!                         parameters set
!   lat   -- lat_struct: with twiss propagated and mat6s made
!   walls -- walls_struct: both walls and ends
!   track_max -- real(rp), optional: Maximum length in m to track
!                                    the ray
!
! Output:
!   ray    -- ray_struct: synch radiation ray propagated to wall
!   hit_flag -- logical, optional: true if wall was hit,
!                                  false if track_max was reached first
!-

subroutine track_ray_to_wall (ray, lat, walls, hit_flag, track_max)

  use synrad_struct
  use synrad_interface, except => track_ray_to_wall

  implicit none

  type (lat_struct), target :: lat
  type (ray_struct), target :: ray
  type (walls_struct), target :: walls
  type (wall_struct), pointer :: negative_x_wall, positive_x_wall

  logical, optional :: hit_flag
  real(rp), optional :: track_max

  integer ix_neg, ix_pos

  real(rp) s_next

  logical is_hit, passed_end

  ! set pointers
  positive_x_wall => walls%positive_x_wall
  negative_x_wall => walls%negative_x_wall

  ! init

  if (present(hit_flag)) hit_flag = .true.  ! assume that we will hit
  passed_end = .false.

  ! ix_neg and ix_pos are the next negative_x_wall and 
  ! positive_x_wall side points that
  ! are at or just "downstream" of the ray.

  call get_initial_pt (ray, negative_x_wall, ix_neg, lat)
  call get_initial_pt (ray, positive_x_wall, ix_pos, lat)

  ! propagation loop:
  ! Propagate the ray. Figure out how far to advance in s.
  ! Do not advance past the next wall point 
  ! (either negative_x_wall or positive_x_wall).
  ! Also since the next wall point may be a very long ways off, 
  !    do not propagate more than 1 meter.

  do

    if (ray%direction == 1) then
      s_next = min(negative_x_wall%pt(ix_neg)%s, positive_x_wall%pt(ix_pos)%s, ray%now%s + 1.0)
      if (present(track_max)) s_next = &
                min(s_next, ray%now%s + (1.0001 * track_max - ray%track_len))
    else
      s_next = max(negative_x_wall%pt(ix_neg)%s, positive_x_wall%pt(ix_pos)%s, ray%now%s - 1.0)
      if (present(track_max)) s_next = &
                max(s_next, ray%now%s - (1.0001 * track_max - ray%track_len))
    endif

    call propagate_ray (ray, s_next, lat, .true.)

    ! See if we have hit the end of the machine

    if (lat%param%geometry == open$) then
      if ((ray%direction ==  1 .and. ray%now%s == lat%ele(lat%n_ele_track)%s) .or. &
          (ray%direction == -1 .and. ray%now%s == lat%ele(0)%s)) then
        if (ray%direction == 1) then
          ray%wall_side = exit_side$   ! End "wall" at end of lattice
        else
          ray%wall_side = start_side$  ! End "wall" at beginning of lattice
        endif
        return
      endif
    endif

    ! See if we have hit the wall.

    call hit_spot_calc (ray, negative_x_wall, ix_neg, is_hit, lat)
    if (is_hit) return

    call hit_spot_calc (ray, positive_x_wall, ix_pos, is_hit, lat)
    if (is_hit) return

    ! See if we have tracked as far as needed.

    if (present(track_max)) then
      if (ray%track_len .ge. track_max) then
        hit_flag = .false.
        return
      endif
    endif

    if (ray%now%s == negative_x_wall%pt(ix_neg)%s) then
      call next_pt (ray, negative_x_wall, ix_neg, passed_end)
    endif

    if (ray%now%s == positive_x_wall%pt(ix_pos)%s) then
      call next_pt (ray, positive_x_wall, ix_pos, passed_end)
    endif

  enddo

end subroutine
