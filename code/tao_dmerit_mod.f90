module tao_dmerit_mod

use tao_mod

contains

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine tao_dModel_dVar_calc (force_calc)
!
! Subroutine to calculate the dModel_dVar derivative matrix.
!
! Input:
!   s          -- Super_universe_struct:
!   force_calc -- Logical: If true then force recalculation of the matrix.
!                  If False then only calculate matrix if it doesn't exist.
!
! Output:
!   s       -- Super_universe_struct.
!    %u(:)%dModel_dVar(:,:)  -- Derivative matrix
!-

subroutine tao_dModel_dvar_calc (force_calc)

implicit none

type (tao_universe_struct), pointer :: u

real(rp) model_value
integer i, j, k
integer n_data, n_var, nd, nv
character(20) :: r_name = 'tao_dmodel_dvar_calc'
logical reinit, force_calc

! make sure size of matrices are correct.

reinit = force_calc

do i = 1, size(s%u)

  u => s%u(i)
  n_data = count (u%data%useit_opt)
  n_var = count (s%var%useit_opt)

  if (.not. associated(u%dModel_dVar)) then
    allocate (u%dModel_dVar(n_data, n_var))
    reinit = .true.
  endif

  if (size(u%dModel_dVar, 1) /= n_data .or. size(u%dModel_dVar, 2) /= n_var) then
    deallocate (u%dModel_dVar)
    allocate (u%dModel_dVar(n_data, n_var))
    reinit = .true.
  endif

  nd = 0
  do j = 1, size(u%data)
    if (.not. u%data(j)%useit_opt) cycle
    nd = nd + 1
    if (u%data(j)%ix_dModel /= nd) reinit = .true.
    u%data(j)%ix_dModel = nd
    u%data(j)%old_value = u%data(j)%delta
  enddo

enddo

nv = 0
do j = 1, size(s%var)
  if (.not. s%var(j)%useit_opt) cycle
  nv = nv + 1
  if (s%var(j)%ix_dVar /= nv) reinit = .true.
  s%var(j)%ix_dVar = nv
enddo

if (.not. reinit) return
call out_io (s_info$, r_name, 'Remaking dModel_dVar derivative matrix...') 

! Calculate matrices

call tao_merit ()
s%var%old_value = s%var%delta

do j = 1, size(s%var)

  if (.not. s%var(j)%useit_opt) cycle
  nv = s%var(j)%ix_dvar
  if (s%var(j)%step == 0) then
    call out_io (s_error$, r_name, 'VARIABLE STEP SIZE IS ZERO FOR: ' // s%var(j)%name)
    call err_exit
  endif
  model_value = s%var(j)%model_value
  call tao_set_var_model_value (s%var(j), model_value + s%var(j)%step)
  call tao_merit ()

  do i = 1, size(s%u)
    u => s%u(i)
    do k = 1, size(u%data)
      if (.not. u%data(k)%useit_opt) cycle
      nd = u%data(k)%ix_dmodel
      u%dModel_dVar(nd,nv) = (u%data(k)%delta - u%data(k)%old_value) / s%var(j)%step
    enddo
  enddo

  call tao_set_var_model_value (s%var(j), model_value)

enddo

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine tao_dmerit_calc ()
!-

subroutine tao_dmerit_calc ()

type (tao_data_struct), pointer :: data

integer i, j, k, nv, nd

!

call tao_dmodel_dvar_calc (.false.)

s%var(:)%dmerit_dvar = 0

do i = 1, size(s%var)

  if (.not. s%var(i)%useit_opt) cycle
  s%var(i)%dmerit_dvar = 2 * s%var(i)%weight * s%var(i)%delta
  nv = s%var(i)%ix_dvar

  do j = 1, size(s%u)
    do k = 1, size (s%u(j)%data)
      data => s%u(j)%data(k)
      if (.not. data%useit_opt) cycle
      nd = data%ix_dmodel
      s%var(i)%dmerit_dvar = s%var(i)%dmerit_dvar + 2 * data%weight * &
                                   s%u(j)%dmodel_dvar(nd,nv) * data%delta
    enddo
  enddo

end do

end subroutine

end module
