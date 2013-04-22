!+
! Subroutine create_girder (lat, ix_girder, contrl, ele_init)
!
! Subroutine to add the controller information to slave elements of
! an girder_lord.
!
! Modules needed:
!   use bmad
!
! Input:
!   lat          -- lat_struct: Lat to modify.
!   ix_girder    -- Integer: Index of girder element.
!   contrl(:)    -- Control_struct: What to control.
!     %ix_slave       -- Integer: Index in lat%branch()%ele() of element controlled.
!     %ix_branch      -- Integer: Branch index.  
!   ele_init     -- Element containing attributes to be transfered
!                   to the Girder element:
!                       ele_init%name        
!                       ele_init%alias
!                       ele_init%descrip
!                       ele_init%value(:)
!
! Output:
!   lat    -- lat_struct: Modified lattice.
!
! Note: Use NEW_CONTROL to get an index for the girder element
!
! Example: Create the Girder supporting elements 
! lat%ele(10) and lat%ele(12)
!
!   call new_control (lat, ix_ele)        ! get IX_ELE index of the girder.
!   control(1:2)%ix_branch = 0
!   control(1)%ix_ele = 10; control(2)%ix_ele = 12
!   call create_girder (lat, ix_ele, control(1:2))  ! create the girder
!-

subroutine create_girder (lat, ix_girder, contrl, ele_init)

use bmad_interface, except_dummy => create_girder

implicit none

type (lat_struct), target :: lat
type (ele_struct), optional :: ele_init
type (ele_struct), pointer ::  slave, girder_ele
type (control_struct)  contrl(:)

integer, intent(in) :: ix_girder
integer i, j, ix, ix2, ixc, n_con2
integer ixs, idel, n_slave, ix_con

real(rp) s_max, s_min

! Mark element as an girder lord

girder_ele => lat%ele(ix_girder)

n_slave = size (contrl)
ix = lat%n_control_max
n_con2 = ix + n_slave

if (n_con2 > size(lat%control)) call reallocate_control (lat, n_con2+500)

do j = 1, n_slave
  lat%control(ix+j)           = contrl(j)
  lat%control(ix+j)%ix_lord   = ix_girder
  lat%control(ix+j)%coef      = 0
  lat%control(ix+j)%ix_attrib = 0
enddo

girder_ele%n_slave = n_slave
girder_ele%ix1_slave = ix + 1
girder_ele%ix2_slave = ix + n_slave
girder_ele%lord_status = girder_lord$
girder_ele%key = girder$
lat%n_control_max = n_con2

! Loop over all slaves
! Free elements convert to overlay slaves.

do i = 1, girder_ele%n_slave

  slave => pointer_to_slave(girder_ele, i, ix_con)

  if (slave%slave_status == free$ .or. slave%slave_status == group_slave$) &
                                                slave%slave_status = overlay_slave$

  ! You cannot control super_slaves, group_lords or overlay_lords

  if (slave%slave_status == super_slave$ .or. slave%lord_status == group_lord$ .or. &
                                          slave%lord_status == overlay_lord$) then
    print *, 'ERROR IN CREATE_GIRDER: ILLEGAL GIRDER ON ', slave%name
    print *, '      BY: ', girder_ele%name
    if (global_com%exit_on_error) call err_exit
  endif

  ! update controller info for the slave ele

  slave%n_lord = slave%n_lord + 1
  call add_lattice_control_structs (lat, slave)
  lat%ic(slave%ic2_lord) = ix_con

  ! compute min/max

enddo

! ele_init stuff

if (present(ele_init)) then
  girder_ele%name    = ele_init%name
  girder_ele%alias   = ele_init%alias
  girder_ele%value   = ele_init%value
  if (associated(ele_init%descrip)) then
    allocate (girder_ele%descrip)
    girder_ele%descrip = ele_init%descrip
  endif
endif

! center of girder
! Need to make a correction if girder wraps around zero.

slave => pointer_to_slave(girder_ele, 1)
s_min = slave%s - slave%value(l$)

slave => pointer_to_slave(girder_ele, girder_ele%n_slave)
s_max = slave%s

if (s_min > s_max) s_min = s_min - lat%branch(slave%ix_branch)%param%total_length ! wrap correction

girder_ele%value(l$) = (s_max - s_min)
girder_ele%value(s_center$) = (s_max + s_min) / 2
girder_ele%value(s_max$) = s_max
girder_ele%value(s_min$) = s_min
girder_ele%s = s_max

end subroutine
