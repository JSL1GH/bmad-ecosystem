!+
! Subroutine tao_hook_optimizer ()
!
! Dummy subroutine that needs to be over written in order to implement a custom
! optimizer.
!
! Input:
!
! Output:
!-

subroutine tao_hook_optimizer ()

use tao_mod
implicit none

character(20) :: r_name = 'tao_hook_optimizer'
!

  call out_io (s_error$, r_name, &
                      'THIS DUMMY ROUTINE NEEDS TO BE OVER WRITTEN!')

end subroutine
