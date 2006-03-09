!+
! function tao_merit () result (this_merit)
! 
! function to calculate the merit.
!
! Input:
!
! Output:
!   this_merit -- Real(rp): Merit value.
!-

function tao_merit () result (this_merit)

use tao_mod
use tao_lattice_calc_mod

implicit none

type (tao_var_struct), pointer :: var
type (tao_data_struct), pointer :: data(:)
type (tao_d1_data_struct), pointer :: d1

real(rp) this_merit, ave, value

integer i, j, n
logical err

! make sure all calculations are up to date.

call tao_lattice_calc ()

!----------------------------------------
! Merit contribution from the variables.

this_merit = 0

do j = 1, size(s%var)

  var => s%var(j)
  var%delta = 0
  var%merit = 0

  if (.not. var%useit_opt) cycle

  select case (var%merit_type)
  case ('target')
    var%delta = var%model_value - var%meas_value
  case ('limit')
    if (var%model_value > var%high_lim) then
      var%delta = var%model_value - var%high_lim
    elseif (var%model_value < var%low_lim) then
      var%delta = var%model_value - var%low_lim
    endif
  case default
    call tao_hook_merit_var (i, j, var)
  end select

  var%merit = var%weight * var%delta**2
  this_merit = this_merit + var%merit

enddo

!----------------------------------------
! Merit contribution from the data:

do i = 1, size(s%u)

! check if universe is turned off
  if (.not. s%u(i)%is_on) cycle

! First compute the delta for the merit function
  
  data => s%u(i)%data
  data%merit = 0
  data%delta = 0

  do j = 1, size(data)
    if (.not. data(j)%useit_opt) cycle
    if (s%global%opt_with_ref .and. s%global%opt_with_base) then
      if (data(j)%merit_type(1:3) == 'abs') then
        data(j)%delta = abs(data(j)%model_value) - &
            data(j)%meas_value + data(j)%ref_value - data(j)%base_value
      else
        data(j)%delta = data(j)%model_value - &
            data(j)%meas_value + data(j)%ref_value - data(j)%base_value
      endif
    elseif (s%global%opt_with_ref) then
      if (data(j)%merit_type(1:3) == 'abs') then
        data(j)%delta = abs(data(j)%model_value) - &
            data(j)%meas_value + data(j)%ref_value - data(j)%design_value
      else
        data(j)%delta = data(j)%model_value - &
            data(j)%meas_value + data(j)%ref_value - data(j)%design_value
      endif
    elseif (s%global%opt_with_base) then
      if (data(j)%merit_type(1:3) == 'abs') then
        data(j)%delta = abs(data(j)%model_value) - &
                                data(j)%meas_value - data(j)%base_value
      else
        data(j)%delta = data(j)%model_value - &
                                data(j)%meas_value - data(j)%base_value
      endif
    else
      if (data(j)%merit_type(1:3) == 'abs') then
        data(j)%delta = abs(data(j)%model_value) - data(j)%meas_value 
      else
        data(j)%delta = data(j)%model_value - data(j)%meas_value 
      endif
    endif
  enddo

! For phase data, since there is an arbitrary overall phase,
! we choose to make the average delta zero.

  call tao_find_data (err, s%u(i), 'phase:x', d1_ptr = d1, print_err = .false.)
  if (.not. err) then
    n = count(d1%d%useit_opt)
    if (n /= 0) then
      ave = sum(d1%d%delta, mask = d1%d%useit_opt) / n
      d1%d%delta = d1%d%delta - ave
    endif
  endif

  call tao_find_data (err, s%u(i), 'phase:y', d1_ptr = d1, print_err = .false.)
  if (.not. err) then
    n = count(d1%d%useit_opt)
    if (n /= 0) then
      ave = sum(d1%d%delta, mask = d1%d%useit_opt) / count(d1%d%useit_opt)
      d1%d%delta = d1%d%delta - ave
    endif
  endif

! for max or min merit_types the delta might be modified.

  do j = 1, size(data)
    select case (data(j)%merit_type)
    case ('target')
    case ('max', 'abs_max')
      if (data(j)%delta < 0) data(j)%delta = 0  ! it's OK to be less
    case ('min', 'abs_min')
      if (data(j)%delta > 0) data(j)%delta = 0  ! it's OK to be more
    case default
      call tao_hook_merit_data (i, j, data(j))
    end select
  enddo

  where (data%useit_opt) data%merit = data%weight * data%delta**2
  this_merit = this_merit + sum (data%merit, mask = data%useit_opt)

enddo

end function
