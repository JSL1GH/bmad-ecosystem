program long_term_tracking

use lt_tracking_mod
use mpi

implicit none

type (ltt_params_struct) lttp
type (ltt_com_struct), target :: ltt_com
type (beam_init_struct) beam_init
type (ltt_sum_data_struct), allocatable, target :: sum_data_arr(:), sd_arr(:)
type (ltt_sum_data_struct) sum_data
type (ltt_sum_data_struct), pointer :: sd
type (ele_struct), pointer :: ele_start
type (lat_struct), pointer :: lat
type (beam_struct), target :: beam
type (bunch_struct), pointer :: bunch
type (bunch_struct) :: bunch0

real(rp) time_now

integer num_slaves, slave_rank, stat(MPI_STATUS_SIZE)
integer i, n, ix, ierr, rc, leng, sd_arr_dat_size, storage_size, dat_size
integer ix0_p, ix1_p

logical am_i_done, err_flag
logical, allocatable :: slave_is_done(:)

character(80) line
character(MPI_MAX_PROCESSOR_NAME) name

! Initialize MPI

call mpi_init(ierr)
if (ierr /= MPI_SUCCESS) then
  print *,'Error starting MPI program. Terminating.'
  call mpi_abort(MPI_COMM_WORLD, rc, ierr)
end if

! Get the number of processors this job is using:
call mpi_comm_size(MPI_COMM_WORLD, lttp%mpi_n_proc, ierr)

! Get the rank of the processor this thread is running on.
! Each processor has a unique rank.
call mpi_comm_rank(MPI_COMM_WORLD, lttp%mpi_rank, ierr)

! Get the name of this processor (usually the hostname)
call mpi_get_processor_name(name, leng, ierr)
if (ierr /= MPI_SUCCESS) then
  print *,'Error getting processor name. Terminating.'
  call mpi_abort(MPI_COMM_WORLD, rc, ierr)
end if

num_slaves = lttp%mpi_n_proc - 1
if (num_slaves /= 0) lttp%using_mpi = .true.

! If not doing BUNCH tracking then slaves have nothing to do.

call ltt_init_params(lttp, ltt_com, beam_init)

if (lttp%simulation_mode /= 'BUNCH' .and. lttp%mpi_rank /= master_rank$) then
  call mpi_finalize(ierr)
  stop
endif

! Only the master should create a map file if a file is to be created.

if (lttp%mpi_rank == master_rank$) then
  call ltt_init_tracking (lttp, ltt_com)
  call mpi_Bcast (0, 1, MPI_INTEGER, master_rank$, MPI_COMM_WORLD, ierr)
  call ltt_print_inital_info (lttp, ltt_com)

else
  call mpi_Bcast (ix, 1, MPI_INTEGER, master_rank$, MPI_COMM_WORLD, ierr)
  call ltt_init_tracking (lttp, ltt_com)
endif

! Calculation start.

call run_timer ('ABS', ltt_com%time_start)

select case (lttp%simulation_mode)
case ('CHECK');  call ltt_run_check_mode(lttp, ltt_com, beam_init)  ! A single turn tracking check
case ('SINGLE'); call ltt_run_single_mode(lttp, ltt_com, beam_init) ! Single particle tracking
case ('STAT');   call ltt_run_stat_mode(lttp, ltt_com)              ! Lattice statistics (radiation integrals, etc.).
case default;    print *, 'BAD SIMULATION_MODE: ' // lttp%simulation_mode

!-------------------------
! Only the BUNCH simulation mode uses mpi

case ('BUNCH')

  if (lttp%using_mpi .and. lttp%output_every_n_turns < 1) then
    if (lttp%mpi_rank == 0) print *, 'OUTPUT_EVERY_N_TURNS MUST BE POSITIVE WHEN USING MPI!'
    stop
  endif

  if (lttp%using_mpi .and. lttp%averages_output_file == '') then
    if (lttp%mpi_rank == 0) print *, 'AVERAGES_OUPUT_FILE MUST BE SET WHEN USING MPI!'
    stop
  endif

  lttp%mpi_n_particles_per_run = nint(real(beam_init%n_particle, rp) / (lttp%mpi_num_runs * (lttp%mpi_n_proc - 1)))

  if (.not. lttp%using_mpi) then
    call ltt_run_bunch_mode(lttp, ltt_com, beam_init)  ! Beam tracking

  !-----------------------------------------
  elseif (lttp%mpi_rank == master_rank$) then

    print '(a, i0)', 'Number of processes (including Master): ', lttp%mpi_n_proc
    print '(a, i0, 2x, i0)', 'Nominal number of particles per pass: ', lttp%mpi_n_particles_per_run
    call ltt_print_mpi_info (lttp, ltt_com, 'Master: Starting...', .true.)

    allocate (slave_is_done(num_slaves))
    slave_is_done = .false.

    lat => ltt_com%tracking_lat
    call ltt_pointer_to_map_ends(lttp, lat, ele_start)
    call init_beam_distribution (ele_start, lat%param, beam_init, beam, err_flag, modes = ltt_com%modes)
    bunch => beam%bunch(1)

    call ltt_allocate_sum_array(lttp, sd_arr)
    call ltt_allocate_sum_array(lttp, sum_data_arr)
    sd_arr_dat_size = size(sd_arr) * storage_size(sd_arr(1)) / 8

    ix0_p = 0
    do i = 1, lttp%mpi_n_proc-1
      ix1_p = min(ix0_p+lttp%mpi_n_particles_per_run, size(bunch%particle))
      n = ix1_p-ix0_p
      dat_size = n * storage_size(bunch%particle(1)) / 8
      call ltt_print_mpi_info (lttp, ltt_com, 'Master: Init position data size to slave: ' // int_str(i))
      call mpi_send (n, 1, MPI_INTEGER, i, num_tag$, MPI_COMM_WORLD, ierr)
      call ltt_print_mpi_info (lttp, ltt_com, 'Master: Initial positions to slave: ' // int_str(i) // &
                                                  '  For particles: [' // int_str(ix0_p) // ':' // int_str(ix1_p) // ']', .true.)
      call mpi_send (bunch%particle(ix0_p+1:ix1_p), dat_size, MPI_BYTE, i, particle_tag$, MPI_COMM_WORLD, ierr)
      ix0_p = ix1_p
    enddo

    !

    do
      ! Get data from a slave
      call ltt_print_mpi_info (lttp, ltt_com, 'Master: Waiting for data from a Slave... ' // int_str(sd_arr_dat_size))
      call mpi_recv (sd_arr, sd_arr_dat_size, MPI_BYTE, MPI_ANY_SOURCE, results_tag$, MPI_COMM_WORLD, stat, ierr)

      slave_rank = stat(MPI_SOURCE)
      call ltt_print_mpi_info (lttp, ltt_com, 'Master: Gathered data from Slave: ' // int_str(slave_rank))

      ! Add to data
      do ix = lbound(sum_data_arr, 1), ubound(sum_data_arr, 1)
        sd => sum_data_arr(ix)
        sd%i_turn   = sd_arr(ix)%i_turn
        sd%n_live   = sd%n_live + sd_arr(ix)%n_live
        sd%n_count  = sd%n_count + sd_arr(ix)%n_count
        sd%orb_sum  = sd%orb_sum + sd_arr(ix)%orb_sum
        sd%orb2_sum = sd%orb2_sum + sd_arr(ix)%orb2_sum
        sd%spin_sum = sd%spin_sum + sd_arr(ix)%spin_sum
        sd%p0c_sum  = sd%p0c_sum + sd_arr(ix)%p0c_sum
        sd%time_sum = sd%time_sum + sd_arr(ix)%time_sum
        if (sd_arr(ix)%status == valid$) sd%status = valid$
      enddo

      ! Tell slave if more tracking needed

      if (ix0_p == size(bunch%particle)) slave_is_done(slave_rank) = .true.
      call mpi_send (slave_is_done(slave_rank), 1, MPI_LOGICAL, slave_rank, is_done_tag$, MPI_COMM_WORLD, ierr)
      if (all(slave_is_done)) exit       ! All done?
      if (ix0_p == size(bunch%particle)) cycle
      
      ! Give slave particle positions

      ix1_p = min(ix0_p+lttp%mpi_n_particles_per_run, size(bunch%particle))

      n = ix1_p-ix0_p
      dat_size = n * storage_size(bunch%particle(1)) / 8
      call ltt_print_mpi_info (lttp, ltt_com, 'Master: Position data size to slave: ' // int_str(slave_rank))
      call mpi_send (n, 1, MPI_INTEGER, slave_rank, num_tag$, MPI_COMM_WORLD, ierr)
      call ltt_print_mpi_info (lttp, ltt_com, 'Master: Initial positions to slave: ' // int_str(slave_rank) // &
                                                   '  For particles: [' // int_str(ix0_p) // ':' // int_str(ix1_p) // ']', .true.)
      call mpi_send (bunch%particle(ix0_p+1:ix1_p), dat_size, MPI_BYTE, slave_rank, particle_tag$, MPI_COMM_WORLD, ierr)

      ix0_p = ix1_p
    enddo

    ! Write results and quit

    call ltt_write_bunch_averages (lttp, sum_data_arr)
    call ltt_write_sigma_matrix (lttp, sum_data_arr)
    call ltt_print_mpi_info (lttp, ltt_com, 'Master: All done!', .true.)
    call mpi_finalize(ierr)

    call run_timer ('ABS', time_now)
    print '(a, f8.2)', 'Tracking time (min):', (time_now - ltt_com%time_start) / 60

  !-----------------------------------------
  else  ! Is a slave

    do
      ! Init positions
      call ltt_print_mpi_info (lttp, ltt_com, 'Slave: Waiting for position size info.')
      call mpi_recv (n, 1, MPI_INTEGER, master_rank$, num_tag$, MPI_COMM_WORLD, stat, ierr)
      if (allocated(bunch0%particle)) then
        if (size(bunch0%particle) /= n) deallocate(bunch0%particle)
      endif
      if (.not. allocated(bunch0%particle)) allocate(bunch0%particle(n))
      call ltt_print_mpi_info (lttp, ltt_com, 'Slave: Waiting for position info for ' // int_str(n) // ' particles.')
      dat_size = n * storage_size(bunch0%particle(1)) / 8
      call mpi_recv (bunch0%particle, dat_size, MPI_BYTE, MPI_ANY_SOURCE, particle_tag$, MPI_COMM_WORLD, stat, ierr)

      ! Run
      call ltt_run_bunch_mode(lttp, ltt_com, beam_init, sd_arr, bunch0)  ! Beam tracking
      sd_arr_dat_size = size(sd_arr) * storage_size(sd_arr(1)) / 8
      call ltt_print_mpi_info (lttp, ltt_com, 'Slave: Sending Data... ' // int_str(sd_arr_dat_size))
      call mpi_send (sd_arr, sd_arr_dat_size, MPI_BYTE, master_rank$, results_tag$, MPI_COMM_WORLD, ierr)

      ! Query Master if more tracking needed
      call ltt_print_mpi_info (lttp, ltt_com, 'Slave: Query am-i-done to master...')
      call mpi_recv (am_i_done, 1, MPI_LOGICAL, master_rank$, is_done_tag$, MPI_COMM_WORLD, stat, ierr)
      if (am_i_done) exit
    enddo

    call ltt_print_mpi_info (lttp, ltt_com, 'Slave: All done!')
    call mpi_finalize(ierr)

  endif

end select

end program

