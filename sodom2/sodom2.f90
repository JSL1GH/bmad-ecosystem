program sodom2

use sodom2_mod
!use bmad
!!use sim_utils

implicit none

type (sodom2_params_struct) sodom
type (sodom2_com_struct), target :: sodom2_com
real(rp) del_time

! Programs should always implement "intelligent bookkeeping".
bmad_com%auto_bookkeeper = .false.
call run_timer ('START')
call sodom2_read_params(sodom, sodom2_com)
call sodom2_init_params(sodom, sodom2_com)
print *, 'Initializing bunch...'

call sodom2_init_bunch(sodom, sodom2_com)
print *, 'Tracking 1-turn...'
call sodom2_track_bunch(sodom, sodom2_com)
print *,  'Tracking complete. Constructing matrix of Fourier components...'
call sodom2_construct_quaternions(sodom, sodom2_com)

call sodom2_construct_mat(sodom, sodom2_com)
print *, "Matrix constructed. Solving eigensystem to obtain n-axis and ADST..."

call sodom2_eig(sodom, sodom2_com)
print *,'ADST = ', sodom2_com%ADST

call sodom2_check_n(sodom, sodom2_com)

print *,  'Writing n-axis to file...'
call sodom2_write_n(sodom, sodom2_com)
call sodom2_write_particles(sodom, sodom2_com)
call run_timer ('READ', del_time)
print *, 'Total time = ' // real_str(del_time/60, 4, 2)

call sodom2_deallocate_memory(sodom2_com)

print *,  'Complete.'

end program
