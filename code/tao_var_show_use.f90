!+
! subroutine tao_var_show_use (v1_var)
!
! Displays what variables are used by the optimizer for the specied v1_var
!
! Input:
!   s       -- tao_super_univewrse_struct
!   v1_var  -- tao_v1_var_struct
!-

subroutine tao_var_show_use (v1_var)

use tao_mod

implicit none

type (tao_v1_var_struct), intent(in) :: v1_var

character(17) :: r_name = "tao_var_show_use"
character(200) line

! find which variables to use

call location_encode (line, v1_var%v%useit_opt, &
                          v1_var%v%exists, lbound(v1_var%v,1))
write (line, '(2x, a, 2a)') v1_var%name, "Using: " // line(1:170)
call out_io (s_blank$, r_name, line)

end subroutine tao_var_show_use
