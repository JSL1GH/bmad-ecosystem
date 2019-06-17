module hdf5_fieldmap_mod

use hdf5_interface
use bmad_interface

contains

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_cartesian_map (file_name, ele, cart_map, err_flag)
!
! Routine to write a cartesian_map structure.
! Note: The file name should have a ".h5" suffix.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!   cart_map      -- cartesian_map_struct: Cartesian map.
!
! Ouput:
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_cartesian_map (file_name, ele, cart_map, err_flag)

implicit none

type (cartesian_map_struct), target :: cart_map
type (ele_struct) ele

integer(HID_T) f_id
integer h5_err
logical err_flag, err

character(*) file_name
character(200) f_name
character(*), parameter :: r_name = 'hdf5_write_cartesian_map'

!

err_flag = .true.
call hdf5_open_file (file_name, 'WRITE', f_id, err);  if (err) return

call hdf5_write_attribute_string(f_id, 'fileType',         'Bmad:cartesian_map', err)
call hdf5_write_attribute_string(f_id, 'file_name',        file_name, err)
call hdf5_write_attribute_string(f_id, 'master_parameter', attribute_name(ele, cart_map%master_parameter), err)
call hdf5_write_attribute_real(f_id,   'field_scale',      cart_map%field_scale, err)
call hdf5_write_attribute_real(f_id,   'r0',               cart_map%r0, err)
call hdf5_write_attribute_int(f_id,    'ele_anchor_pt',    cart_map%ele_anchor_pt, err)
call hdf5_write_attribute_int(f_id,    'field_type',       cart_map%field_type, err)
call hdf5_write_attribute_int(f_id,    'n_term',           size(cart_map%ptr%term), err)

call hdf5_write_dataset_real(f_id, 'term%coef',   cart_map%ptr%term%coef, err)
call hdf5_write_dataset_real(f_id, 'term%kx',     cart_map%ptr%term%kx, err)
call hdf5_write_dataset_real(f_id, 'term%ky',     cart_map%ptr%term%ky, err)
call hdf5_write_dataset_real(f_id, 'term%kz',     cart_map%ptr%term%kz, err)
call hdf5_write_dataset_real(f_id, 'term%x0',     cart_map%ptr%term%x0, err)
call hdf5_write_dataset_real(f_id, 'term%y0',     cart_map%ptr%term%y0, err)
call hdf5_write_dataset_real(f_id, 'term%phi_z',  cart_map%ptr%term%phi_z, err)
call hdf5_write_dataset_int(f_id,  'term%family', cart_map%ptr%term%family, err)
call hdf5_write_dataset_int(f_id,  'term%form',   cart_map%ptr%term%form, err)

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_write_cartesian_map

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_cartesian_map (file_name, ele, cart_map, err_flag)
!
! Routine to read a binary cartesian_map structure.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!
! Ouput:
!   cart_map      -- cartesian_map_struct, cartesian map.
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_read_cartesian_map (file_name, ele, cart_map, err_flag)

implicit none

type (cartesian_map_struct), target :: cart_map
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, nt, iver, h5_err, n_term
logical err_flag, err

character(*) file_name
character(40) master_name, file_type
character(*), parameter :: r_name = 'hdf5_read_cartesian_map'

!

err_flag = .true.
allocate (cart_map%ptr)

call hdf5_open_file (file_name, 'READ', f_id, err);  if (err) return

call hdf5_read_attribute_string(f_id, 'fileType',         file_type, err, .true.)
call hdf5_read_attribute_string(f_id, 'file_name',        cart_map%ptr%file, err, .true.)
call hdf5_read_attribute_string(f_id, 'master_parameter', master_name, err, .true.)
call hdf5_read_attribute_real(f_id,   'field_scale',      cart_map%field_scale, err, .true.)
call hdf5_read_attribute_real(f_id,   'r0',               cart_map%r0, err, .true.)
call hdf5_read_attribute_int(f_id,    'ele_anchor_pt',    cart_map%ele_anchor_pt, err, .true.)
call hdf5_read_attribute_int(f_id,    'field_type',       cart_map%field_type, err, .true.)
call hdf5_read_attribute_int(f_id,    'n_term',           n_term, err, .true.)

cart_map%master_parameter = attribute_index(ele, master_name)
allocate (cart_map%ptr%term(n_term))

call hdf5_read_dataset_real(f_id, 'term%coef',   cart_map%ptr%term%coef, err)
call hdf5_read_dataset_real(f_id, 'term%kx',     cart_map%ptr%term%kx, err)
call hdf5_read_dataset_real(f_id, 'term%ky',     cart_map%ptr%term%ky, err)
call hdf5_read_dataset_real(f_id, 'term%kz',     cart_map%ptr%term%kz, err)
call hdf5_read_dataset_real(f_id, 'term%x0',     cart_map%ptr%term%x0, err)
call hdf5_read_dataset_real(f_id, 'term%y0',     cart_map%ptr%term%y0, err)
call hdf5_read_dataset_real(f_id, 'term%phi_z',  cart_map%ptr%term%phi_z, err)
call hdf5_read_dataset_int(f_id,  'term%family', cart_map%ptr%term%family, err)
call hdf5_read_dataset_int(f_id,  'term%form',   cart_map%ptr%term%form, err)

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_read_cartesian_map

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_cylindrical_map (file_name, ele, cl_map, err_flag)
!
! Routine to write a binary cylindrical_map structure.
! Note: The file name should have a ".h5" suffix.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!   cl_map        -- cylindrical_map_struct: Cylindrical map.
!
! Ouput:
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_cylindrical_map (file_name, ele, cl_map, err_flag)

implicit none

type (cylindrical_map_struct), target :: cl_map
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, h5_err
logical err_flag, err

character(*) file_name
character(200) f_name
character(*), parameter :: r_name = 'hdf5_write_cylindrical_map'

!

err_flag = .true.
call hdf5_open_file (file_name, 'WRITE', f_id, err);  if (err) return

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_write_cylindrical_map

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_cylindrical_map (file_name, ele, cl_map, err_flag)
!
! Routine to read a binary cylindrical_map structure.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!
! Ouput:
!   cl_map        -- cylindrical_map_struct, cylindrical map.
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_read_cylindrical_map (file_name, ele, cl_map, err_flag)

implicit none

type (cylindrical_map_struct), target :: cl_map
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, nt, iver, h5_err
logical err_flag, err

character(*) file_name
character(40) master_name
character(*), parameter :: r_name = 'hdf5_read_cylindrical_map'

!

err_flag = .true.
call hdf5_open_file (file_name, 'READ', f_id, err);  if (err) return

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_read_cylindrical_map

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_grid_field (file_name, ele, g_field, err_flag)
!
! Routine to write a binary grid_field structure.
! Note: The file name should have a ".h5" suffix.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!   g_field       -- grid_field_struct: Cylindrical map.
!
! Ouput:
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_grid_field (file_name, ele, g_field, err_flag)

implicit none

type (grid_field_struct), target :: g_field
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, k, n, h5_err
logical err_flag, err

character(*) file_name
character(*), parameter :: r_name = 'dhf5_write_grid_field'
character(200) f_name

!

err_flag = .true.
call hdf5_open_file (file_name, 'WRITE', f_id, err);  if (err) return

call hdf5_write_attribute_string(f_id, 'fileType',               'Bmad:grid_field', err)
call hdf5_write_attribute_string(f_id, 'file_name',              file_name, err)
call hdf5_write_attribute_string(f_id, 'master_parameter',       attribute_name(ele, g_field%master_parameter), err)
call hdf5_write_attribute_string(f_id, 'geometry',               grid_field_geometry_name(g_field%geometry), err)
call hdf5_write_attribute_string(f_id, 'field_type',             em_field_type_name(g_field%field_type), err)
call hdf5_write_attribute_string(f_id, 'ele_anchor_pt',          anchor_pt_name(g_field%ele_anchor_pt), err)
call hdf5_write_attribute_real(f_id,   'field_scale',            g_field%field_scale, err)
call hdf5_write_attribute_real(f_id,   'phi0_fieldmap',          g_field%phi0_fieldmap, err)
call hdf5_write_attribute_real(f_id,   'r0',                     g_field%r0, err)
call hdf5_write_attribute_real(f_id,   'dr',                     g_field%dr, err)
call hdf5_write_attribute_int(f_id,    'harmonic',               g_field%harmonic, err)
call hdf5_write_attribute_int(f_id,    'interpolation_order',    g_field%interpolation_order, err)
call hdf5_write_attribute_int(f_id,    'lbound',                 lbound(g_field%ptr%pt), err)
call hdf5_write_attribute_int(f_id,    'ubound',                 ubound(g_field%ptr%pt), err)


call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_write_grid_field

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_grid_field (file_name, ele, g_field, err_flag)
!
! Routine to read a binary grid_field structure.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!
! Ouput:
!   g_field       -- grid_field_struct, cylindrical map.
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_read_grid_field (file_name, ele, g_field, err_flag)

implicit none

type (grid_field_struct), target :: g_field
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, k, n0(3), n1(3), iver, h5_err
logical err_flag, err

character(*) file_name
character(40) master_name
character(*), parameter :: r_name = 'hdf5_read_grid_field'

!

err_flag = .true.
call hdf5_open_file (file_name, 'READ', f_id, err);  if (err) return

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_read_grid_field

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_taylor_field (file_name, ele, t_field, err_flag)
!
! Routine to write a binary taylor_field structure.
! Note: The file name should have a ".h5" suffix.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!   t_field       -- taylor_field_struct: Cylindrical map.
!
! Ouput:
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_taylor_field (file_name, ele, t_field, err_flag)

implicit none

type (taylor_field_struct), target :: t_field
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, k, n, h5_err
logical err_flag, err

character(*) file_name
character(*), parameter :: r_name = 'hdf5_write_taylor_field'
character(200) f_name

!

err_flag = .true.
call hdf5_open_file (file_name, 'WRITE', f_id, err);  if (err) return

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_write_taylor_field

!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_taylor_field (file_name, ele, t_field, err_flag)
!
! Routine to read a binary taylor_field structure.
!
! Input:
!   file_name     -- character(*): File to create.
!   ele           -- ele_struct: Element associated with the map.
!
! Ouput:
!   t_field       -- taylor_field_struct, cylindrical map.
!   err_flag      -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_read_taylor_field (file_name, ele, t_field, err_flag)

implicit none

type (taylor_field_struct), target :: t_field
type (ele_struct) ele

integer(HID_T) f_id
integer i, j, k, n0, n1, n, nn, iver, h5_err
logical err_flag, err

character(*) file_name
character(40) master_name
character(*), parameter :: r_name = 'hdf5_read_taylor_field'

!

err_flag = .true.
call hdf5_open_file (file_name, 'READ', f_id, err);  if (err) return

call h5fclose_f(f_id, h5_err)
err_flag = .false.

end subroutine hdf5_read_taylor_field

end module
