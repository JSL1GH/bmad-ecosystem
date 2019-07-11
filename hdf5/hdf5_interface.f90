!+
! Module hdf5_interface
!
! Interface routines for HDF5.
!
! HDF5 (Hierarchical Data Format version 5) is a set of file format design to store large amounts of data.
! See the web documentation on HDF5 for more info.
!-

module hdf5_interface

use h5lt
use hdf5
use sim_utils

implicit none

! Misc

integer, parameter :: H5O_TYPE_ATTRIBUTE_F = 123

! %element_type identifies the type of element (group, dataset or attribute) can be:
!   H5O_TYPE_GROUP_F
!   H5O_TYPE_DATASET_F
!   H5O_TYPE_ATTRIBUTE_F   ! Defined by bmad. Not by HDF5.
!   anything else is not useful.
!
! %data_type identifies the type of the underlying data. Not relavent for groups. can be:
!   H5T_FLOAT_F
!   H5T_INTEGER_F
!   H5T_STRING_F
!   anything else is not useful.

type hdf5_info_struct
  integer :: element_type = -1         ! Type of the element. See above.
  integer :: data_type = -1            ! Type of associated data. Not used for groups. See above.
  integer(hsize_t) :: data_dim(3) = 0  ! Dimensions. Not used for groups. EG: Scaler data has [1, 0, 0].
  integer(SIZE_T) :: data_size = -1    ! Size of datums. Not used for groups. For strings size = # of characters.
  integer :: num_attributes = -1       ! Number of associated attributes. Used for groups and datasets only.
end type

interface hdf5_read_dataset_int
  module procedure hdf5_read_dataset_int_rank_0
  module procedure hdf5_read_dataset_int_rank_1
  module procedure hdf5_read_dataset_int_rank_2
  module procedure hdf5_read_dataset_int_rank_3
end interface

interface hdf5_read_dataset_real
  module procedure hdf5_read_dataset_real_rank_0
  module procedure hdf5_read_dataset_real_rank_1
  module procedure hdf5_read_dataset_real_rank_2
  module procedure hdf5_read_dataset_real_rank_3
end interface

interface hdf5_read_attribute_real
  module procedure hdf5_read_attribute_real_rank_0
  module procedure hdf5_read_attribute_real_rank_1
end interface

interface hdf5_read_attribute_int
  module procedure hdf5_read_attribute_int_rank_0
  module procedure hdf5_read_attribute_int_rank_1
end interface

interface hdf5_write_dataset_int
  module procedure hdf5_write_dataset_int_rank_0
  module procedure hdf5_write_dataset_int_rank_1
  module procedure hdf5_write_dataset_int_rank_2
  module procedure hdf5_write_dataset_int_rank_3
end interface

interface hdf5_write_dataset_real
  module procedure hdf5_write_dataset_real_rank_0
  module procedure hdf5_write_dataset_real_rank_1
  module procedure hdf5_write_dataset_real_rank_2
  module procedure hdf5_write_dataset_real_rank_3
end interface

interface hdf5_write_attribute_real
  module procedure hdf5_write_attribute_real_rank_0
  module procedure hdf5_write_attribute_real_rank_1
end interface

interface hdf5_write_attribute_int
  module procedure hdf5_write_attribute_int_rank_0
  module procedure hdf5_write_attribute_int_rank_1
end interface

contains

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_attribute_string(root_id, attrib_name, string, error)
!
! Routine to create an HDF5 attribute whose value is a string.
!
! Input:
!   root_id       -- integer(hid_t): ID of the group or dataset the attribute is to be put in.
!   attrib_name   -- character(*): Name of the attribute.
!   string        -- character(*): String attribute value.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_attribute_string(root_id, attrib_name, string, error)

integer(hid_t) :: root_id
character(*) :: attrib_name, string
integer h5_err
logical error
!
error = .true.
call H5LTset_attribute_string_f(root_id, '.', attrib_name, trim(string), h5_err); if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_attribute_string

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_attribute_int_rank_0(root_id, attrib_name, ival, error)
!
! Routine to create an attribute with a scalar integer value.
!
! Input:
!   root_id       -- integer(hid_t): ID of the group or dataset the attribute is to be put in.
!   attrib_name   -- character(*): Name of the attribute.
!   ival          -- integer: Integer value of the attribute.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_attribute_int_rank_0(root_id, attrib_name, ival, error)

integer(hid_t) :: root_id
character(*) :: attrib_name
integer :: ival
integer h5_err
logical error
!
error = .true.
call H5LTset_attribute_int_f(root_id, '.', attrib_name, [ival], 1_size_t, h5_err); if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_attribute_int_rank_0

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_attribute_int_rank_1(root_id, attrib_name, ival, error)
!
! Routine to create an attribute with a vector integer value.
!
! Input:
!   root_id       -- integer(hid_t): ID of the group or dataset the attribute is to be put in.
!   attrib_name   -- character(*): Name of the attribute.
!   ival(:)       -- integer: Integer array attribute value.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_attribute_int_rank_1(root_id, attrib_name, ival, error)

integer(hid_t) :: root_id
integer(size_t) iz 
character(*) :: attrib_name
integer :: ival(:)
integer h5_err
logical error
!
error = .true.
iz = size(ival)
call H5LTset_attribute_int_f(root_id, '.', attrib_name, ival, iz, h5_err); if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_attribute_int_rank_1

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_attribute_real_rank_0(root_id, attrib_name, rval, error)
!
! Routine to create an attribute with a scalar real value.
!
! Input:
!   root_id       -- integer(hid_t): ID of the group or dataset the attribute is to be put in.
!   attrib_name   -- character(*): Name of the attribute.
!   rval          -- real(rp): real value of the attribute.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_attribute_real_rank_0(root_id, attrib_name, rval, error)

integer(hid_t) :: root_id
character(*) :: attrib_name
real(rp) :: rval
integer h5_err
logical error
!
error = .true.
call H5LTset_attribute_double_f(root_id, '.', attrib_name, [rval], 1_size_t, h5_err); if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_attribute_real_rank_0

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_attribute_real_rank_1(root_id, attrib_name, rval, error)
!
! Routine to create an attribute with a real vector value.
!
! Input:
!   root_id       -- integer(hid_t): ID of the group or dataset the attribute is to be put in.
!   attrib_name   -- character(*): Name of the attribute.
!   rval(:)       -- real(rp): real vector value of the attribute.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_attribute_real_rank_1(root_id, attrib_name, rval, error)

integer(hid_t) :: root_id
integer(size_t) iz 
character(*) :: attrib_name
real(rp) :: rval(:)
integer h5_err
logical error
!
error = .true.
iz = size(rval)
call H5LTset_attribute_double_f(root_id, '.', attrib_name, rval, iz, h5_err); if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_attribute_real_rank_1

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_open_file (file_name, action, file_id, error)
!
! Routine to open an HDF5 file.
!
! Note: To close the file When finished use:
!   call h5fclose_f(file_name, h5_err)  ! h5_err is an integer
!
! Input:
!   file_name   -- character(*): Name of the file
!   action      -- character(*): Possibilities are:
!                     'READ'    -- Read only.
!                     'WRITE'   -- New file for writing to.
!                     'APPEND'  -- If file exists, open file for reading/writing. 
!                                  If file does not exist, create new file.
!
! Output:
!   file_id     -- integer(hid_t): File handle.
!   error       -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_open_file (file_name, action, file_id, error)

integer(hid_t) file_id
integer h5_err, h_err

logical error, exist

character(*) file_name, action
character(*), parameter :: r_name = 'hdf5_open_file'

!

error = .true.

call h5open_f(h5_err)  ! Init Fortran interface

call H5Eset_auto_f(0, h5_err)   ! Run silent

select case (action)
case ('READ')
  call h5fopen_f(file_name, H5F_ACC_RDONLY_F, file_id, h5_err)

case ('WRITE')
  call h5fcreate_f (file_name, H5F_ACC_TRUNC_F, file_id, h5_err)

case ('APPEND')
  inquire (file = file_name, exist = exist)
  if (exist) then
    call h5fopen_f(file_name, H5F_ACC_RDWR_F, file_id, h5_err)
  else
    call h5fcreate_f (file_name, H5F_ACC_TRUNC_F, file_id, h5_err)
  endif

case default
  call out_io(s_fatal$, r_name, 'BAD ACTION ARGUMENT! ' // quote(action))
  stop
end select

call H5Eset_auto_f(1, h_err)    ! Reset
CALL h5eclear_f(h_err)

if (h5_err < 0) then
  call out_io (s_error$, r_name, 'CANNOT OPEN FILE FOR READING: ' // file_name)
  return
endif

error = .false.

end subroutine hdf5_open_file

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_open_object(root_id, object_name, info, error, print_error) result (obj_id)
!
! Routine to open an existing group or dataset.
!
! Note: Use hdf5_close_object to close the object.
!
! Input:
!   root_id     -- integer(hid_t): ID of the group containing the object to be opened.
!   object_name -- character(*): Name of the object to be opened
!   info        -- hdf5_info_struct: Information on the object.
!   print_error -- logical: Print an error message if there is an error?
!
! Output:
!   error       -- logical: Set True if there is an error. False otherwise.
!   obj_id      -- integer(hid_t): Object ID.
!-

function hdf5_open_object(root_id, object_name, info, error, print_error) result (obj_id)

type (hdf5_info_struct) info

integer(hid_t) root_id, obj_id
integer h5_err

logical error, print_error

character(*) object_name
character(*), parameter :: r_name = 'hdf5_open_object'

!

if (info%element_type == H5O_TYPE_DATASET_F) then
  obj_id = hdf5_open_dataset (root_id, object_name, error, print_error) 
elseif (info%element_type == H5O_TYPE_GROUP_F) then
  obj_id = hdf5_open_group(root_id, object_name, error, print_error) 
endif

end function hdf5_open_object

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_close_object(obj_id, info)
!
! Routine to close a group or dataset.
!
! Note: Use hdf5_open_object to open the object.
!
! Input:
!   obj_id      -- integer(hid_t): Object ID.
!   info        -- hdf5_info_struct: Information on the object. 
!                     Obtained when hdf5_open_object was called.
!-

subroutine hdf5_close_object(obj_id, info)

type (hdf5_info_struct) info

integer(hid_t) obj_id
integer h5_err

!

if (info%element_type == H5O_TYPE_DATASET_F) then
  call H5Dclose_f(obj_id, h5_err)
elseif (info%element_type == H5O_TYPE_GROUP_F) then
  call H5Gclose_f(obj_id, h5_err)
endif

end subroutine hdf5_close_object

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_exists (root_id, object_name, error, print_error) result (exists)
!
! Routine to check if a object with object_name exists relative to root_id.
!
! Input:
!   root_id     -- integer(hid_t): ID of the base grroup.
!   object_name -- character(*): Path of the object.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. For example, if any element in the path 
!                     of object_name, except for the target, does not exist.
!   exists        -- logical: Object exists.
!-

function hdf5_exists (root_id, object_name, error, print_error) result (exists)

integer(hid_t) root_id
integer h5_err

logical error, print_error
logical exists

character(*) object_name
character(*), parameter :: r_name = 'hdf5_exists'

!

call H5Lexists_f(root_id, object_name, exists, h5_err, H5P_DEFAULT_F)
error = (h5_err /= 0)
if (error .and. print_error) then
  call out_io (s_error$, r_name, 'CANNOT QUERY EXISTANCE: ' // quote(object_name))
endif

end function hdf5_exists

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_open_group (root_id, group_name, error, print_error) result (g_id)
!
! Rouine to open an existing group.
!
! Notes: 
!   Use H5Gclose_f to close the group.
!   Use H5Gcreate_f to create a new group.
!
! Input:
!   root_id     -- integer(hid_t): ID of the Parent group containing the group to be opened.
!   group_name  -- character(*): Name of the group to be opened.
!   print_error -- logical: Print an error message if there is an error?
!
! Output:
!   error       -- logical: Set True if there is an error. False otherwise.
!   g_id        -- integer(hid_t): Group ID.
!-

function hdf5_open_group (root_id, group_name, error, print_error) result (g_id)

integer(hid_t) root_id, g_id
integer h5_err

logical error, print_error
logical exists

character(*) group_name
character(*), parameter :: r_name = 'hdf5_open_group'

!

error = .true.
call H5Lexists_f(root_id, group_name, exists, h5_err, H5P_DEFAULT_F)
if (.not. exists) then
  if (print_error) then
    call out_io (s_error$, r_name, 'GROUP DOES NOT EXIST: ' // quote(group_name))
  endif
  return
endif
 
call H5Gopen_f (root_id, group_name, g_id, h5_err, H5P_DEFAULT_F)
if (h5_err == -1) return
error = .false.

end function hdf5_open_group

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_open_dataset(root_id, dataset_name, info, error, print_error) result (obj_id)
!
! Routine to open an existing group or dataset.
!
! Note: Use H5Dclose_f close the dataset.
!
! Input:
!   root_id     -- integer(hid_t): ID of the group containing the dataset to be opened.
!   dataset_name -- character(*): Name of the dataset to be opened
!   info        -- hdf5_info_struct: Information on the dataset.
!   print_error -- logical: Print an error message if there is an error?
!
! Output:
!   error       -- logical: Set True if there is an error. False otherwise.
!   obj_id      -- integer(hid_t): Dataset ID.
!-

function hdf5_open_dataset (root_id, dataset_name, error, print_error) result (ds_id)

integer(hid_t) root_id, ds_id
integer h5_err

logical error, print_error
logical exists

character(*) dataset_name
character(*), parameter :: r_name = 'hdf5_open_dataset'

!

error = .true.
call H5Lexists_f(root_id, dataset_name, exists, h5_err, H5P_DEFAULT_F)
if (.not. exists) then
  if (print_error) then
    call out_io (s_error$, r_name, 'DATASET DOES NOT EXIST: ' // quote(dataset_name))
  endif
  return
endif
 
call H5Dopen_f (root_id, dataset_name, ds_id, h5_err, H5P_DEFAULT_F)
if (h5_err == -1) return
error = .false.

end function hdf5_open_dataset

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_num_attributes(root_id) result (num)
!
! Routine to return the number of attributes associated with a group or dataset.
!
! Also see: hdf5_get_attribute_by_index
!
! Input:
!   root_id     -- integer(hid_t): Group or dataset ID number.
!
! Output:
!   num         -- integer: Number of attributes in the group or dataset.
!-

function hdf5_num_attributes(root_id) result (num)

integer(hid_t) :: root_id
integer num, h5_err

!

call H5Aget_num_attrs_f (root_id, num, h5_err)

end function hdf5_num_attributes

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_get_attribute_by_index(root_id, attrib_indx, attrib_id, attrib_name)
!
! Routine to return the ID and name of an attribute given the attribute's index number.
! This routine is useful for looping over all the attributes in a group or dataset.
!
! Input:
!   root_id       -- integer(hid_t): ID number of the group or dataset containing the attribute.
!   attrib_indx   -- integer: Attribute index. Will be in the range 1 to hdf5_num_attributes.
!
! Output:
!   attrib_id     -- integer(hid_t): ID number of the attribute.
!   attrib_name   -- character(*): Name of the attribute.
!-

subroutine hdf5_get_attribute_by_index(root_id, attrib_indx, attrib_id, attrib_name)

integer(hid_t) root_id, attrib_id
integer(size_t) nam_len
integer attrib_indx, h5_err

character(*) attrib_name

!

call H5Aopen_by_idx_f (root_id, ".", H5_INDEX_CRT_ORDER_F, H5_ITER_INC_F, int(attrib_indx-1, HSIZE_T), &
                                                                 attrib_id, h5_err, aapl_id=H5P_DEFAULT_F)
nam_len = len(attrib_name)
call H5Aget_name_f(attrib_id, nam_len, attrib_name, h5_err)
call H5Aclose_f(attrib_id, h5_err)

end subroutine hdf5_get_attribute_by_index

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_attribute_info(root_id, attrib_name, error, print_error) result (info)
!
! Routine to return information on an attribute given the attribute name and encomposing group.
!
! Input:
!   root_id       -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name   -- character(*): Name of the attribute.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. False otherwise.
!   info          -- hdf5_info_struct: Information on the attribute.
!-

function hdf5_attribute_info(root_id, attrib_name, error, print_error) result (info)

type (hdf5_info_struct) info

integer(hid_t) root_id, a_id
integer h5_err

logical error, print_error, exists

character(*) attrib_name
character(*), parameter :: r_name = 'hdf5_attribute_info'

!

error = .true.

call H5Aexists_f (root_id, attrib_name, exists, h5_err)
if (.not. exists .or. h5_err == -1) then
  if (print_error) then
    call out_io (s_error$, r_name, 'ATTRIBUTE IS NOT PRESENT: ' // attrib_name)
  endif
  return
endif

call H5LTget_attribute_info_f(root_id, '.', attrib_name, info%data_dim, info%data_type, info%data_size, h5_err)
info%element_type = H5O_TYPE_ATTRIBUTE_F

if (h5_err < 0) then
  if (print_error) call out_io (s_error$, r_name, 'CANNOT FILE ATTRIBUTE: ' // attrib_name)
  return
endif

error = .false.

end function hdf5_attribute_info

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Function hdf5_object_info (root_id, obj_name, error, print_error) result (info)
!
! Routine to get information on an object (group or dataset).
!
! Input:
!   root_id       -- integer(hid_t): ID of group containing the object in question.
!   obj_name      -- character(*): Name of the object.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. False otherwise.
!   info          -- hdf5_info_struct: Information on the object.
!-

function hdf5_object_info (root_id, obj_name, error, print_error) result (info)

type (hdf5_info_struct) info
type (H5O_info_t) :: infobuf 

integer(hid_t), value :: root_id
integer stat, h5_err

character(*) obj_name

logical error, print_error

!

error = .true.

call H5Oget_info_by_name_f(root_id, obj_name, infobuf, h5_err)
info%element_type = infobuf%type
info%num_attributes = infobuf%num_attrs

if (info%element_type == H5O_TYPE_DATASET_F) then
  call H5LTget_dataset_info_f(root_id, obj_name, info%data_dim, info%data_type, info%data_size, h5_err)
endif

error = .false.

end function hdf5_object_info

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_attribute_int_rank_0(root_id, attrib_name, attrib_value, error, print_error)
!
! Routine to read an scaler (rank 0) integer attribute value.
! Overloaded by: hdf5_read_attribute_int
!
! Input:
!   root_id       -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name   -- character(*): Name of the attribute.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. False otherwise.
!   attrib_value  -- integer: Value of the attribute.
!-

subroutine hdf5_read_attribute_int_rank_0(root_id, attrib_name, attrib_value, error, print_error)

integer(hid_t) root_id
integer attrib_value, a_val(1)

logical error, print_error

character(*) attrib_name

call hdf5_read_attribute_int_rank_1(root_id, attrib_name, a_val, error, print_error)
attrib_value = a_val(1)

end subroutine hdf5_read_attribute_int_rank_0

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_attribute_int_rank_0(root_id, attrib_name, attrib_value, error, print_error)
!
! Routine to read a vector (rank 1) integer attribute array.
! Overloaded by: hdf5_read_attribute_int
!
! Input:
!   root_id         -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name     -- character(*): Name of the attribute.
!   print_error     -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error           -- logical: Set true if there is an error. False otherwise.
!   attrib_value(:) -- integer: Value of the attribute.
!-

subroutine hdf5_read_attribute_int_rank_1(root_id, attrib_name, attrib_value, error, print_error)

type (hdf5_info_struct) info

integer(hid_t) root_id, a_id
integer attrib_value(:)
integer h5_err

logical error, print_error

character(*) attrib_name
character(*), parameter :: r_name = 'hdf5_read_attribute_int_rank_1'

!

attrib_value = 0

info = hdf5_attribute_info(root_id, attrib_name, error, print_error)

if (info%data_type == H5T_INTEGER_F) then
  call H5LTget_attribute_int_f(root_id, '.', attrib_name, attrib_value, h5_err)
else
  if (print_error) call out_io (s_error$, r_name, 'ATTRIBUTE IS NOT OF INTEGER TYPE: ' // attrib_name)
  return
endif

error = .false.

end subroutine hdf5_read_attribute_int_rank_1

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_attribute_real_rank_0(root_id, attrib_name, attrib_value, error, print_error)
!
! Routine to read an scaler (rank 0) real attribute value.
! Overloaded by: hdf5_read_attribute_real
!
! Input:
!   root_id       -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name   -- character(*): Name of the attribute.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. False otherwise.
!   attrib_value  -- real(rp): Value of the attribute.
!-

subroutine hdf5_read_attribute_real_rank_0(root_id, attrib_name, attrib_value, error, print_error)

integer(hid_t) root_id
integer h5_err

real(rp) attrib_value, val(1)

logical error, print_error

character(*) attrib_name

!

call hdf5_read_attribute_real_rank_1(root_id, attrib_name, val, error, print_error)
attrib_value = val(1)

end subroutine hdf5_read_attribute_real_rank_0

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_attribute_real_rank_1(root_id, attrib_name, attrib_value, error, print_error)
!
! Routine to read a vector (rank 1) real attribute array
! Overloaded by: hdf5_read_attribute_real
!
! Input:
!   root_id         -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name     -- character(*): Name of the attribute.
!   print_error     -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error           -- logical: Set true if there is an error. False otherwise.
!   attrib_value(:) -- real(rp): Value array of the attribute.
!-

subroutine hdf5_read_attribute_real_rank_1(root_id, attrib_name, attrib_value, error, print_error)

type (hdf5_info_struct) info

integer(hid_t) root_id, a_id
integer h5_err

real(rp) attrib_value(:) 

logical error, print_error

character(*) attrib_name
character(*), parameter :: r_name = 'hdf5_read_attribute_real_rank_1'

!

attrib_value = 0
error = .true.

info = hdf5_attribute_info(root_id, attrib_name, error, print_error)

if (info%data_type == H5T_INTEGER_F .or. info%data_type == H5T_FLOAT_F) then
  call H5LTget_attribute_double_f(root_id, '.', attrib_name, attrib_value, h5_err)
else
  if (print_error) call out_io (s_error$, r_name, 'ATTRIBUTE IS NOT OF REAL TYPE: ' // attrib_name)
  return
endif

error = .false.

end subroutine hdf5_read_attribute_real_rank_1

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_attribute_alloc_string(root_id, attrib_name, string, error, print_error)
!
! Routine to read a string attribute.
! Also see: hdf5_read_attribute_string
!
! Input:
!   root_id       -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name   -- character(*): Name of the attribute.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. False otherwise.
!   string        -- character(:), allocatable: Variable length string to hold the attribute value.
!-

subroutine hdf5_read_attribute_alloc_string(root_id, attrib_name, string, error, print_error)

type (hdf5_info_struct) info

integer(hid_t) root_id, a_id
integer attrib_value
integer h5_err

logical error, print_error

character(*) attrib_name
character(:), allocatable :: string
character(*), parameter :: r_name = 'hdf5_read_attribute_alloc_string'

!

attrib_value = 0

info = hdf5_attribute_info(root_id, attrib_name, error, print_error)

if (info%data_type /= H5T_STRING_F) then
  if (print_error) then
    call out_io (s_error$, r_name, 'ATTRIBUTE: ' // attrib_name, 'IS NOT A STRING!')
  endif
  return
endif

allocate(character(info%data_size) :: string)
call H5LTget_attribute_string_f(root_id, '.', attrib_name, string, h5_err)
if (h5_err < 0) then
  if (print_error) then
    call out_io (s_error$, r_name, 'CANNOT READ ATTRIBUTE: ' // attrib_name)
  endif
  return
endif

error = .false.

end subroutine hdf5_read_attribute_alloc_string

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_read_attribute_string(root_id, attrib_name, string, error, print_error)
!
! Routine to read a string attribute.
! Also see: hdf5_read_attribute_alloc_string
!
! Input:
!   root_id       -- integer(hid_t): ID of group or dataset containing the attribute.
!   attrib_name   -- character(*): Name of the attribute.
!   print_error   -- logical: If true, print an error message if there is a problem.
!
! Output:
!   error         -- logical: Set true if there is an error. False otherwise.
!   string        -- character(*): String to hold the attribute value.
!-

subroutine hdf5_read_attribute_string(root_id, attrib_name, string, error, print_error)

type (hdf5_info_struct) info

integer(hid_t) root_id, a_id
integer attrib_value
integer h5_err

logical error, print_error

character(*) attrib_name
character(*) :: string
character(*), parameter :: r_name = 'hdf5_read_attribute_string'

!

attrib_value = 0

info = hdf5_attribute_info(root_id, attrib_name, error, print_error)

if (info%data_type /= H5T_STRING_F) then
  if (print_error) then
    call out_io (s_error$, r_name, 'ATTRIBUTE: ' // attrib_name, 'IS NOT A STRING!')
  endif
  return
endif

call H5LTget_attribute_string_f(root_id, '.', attrib_name, string, h5_err)
if (h5_err < 0) then
  if (print_error) then
    call out_io (s_error$, r_name, 'CANNOT READ ATTRIBUTE: ' // attrib_name)
  endif
  return
endif

error = .false.

end subroutine hdf5_read_attribute_string

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_real_rank_0(root_id, dataset_name, value, error)
!
! Routine to create a dataset with one real value.
! Overloaded by: interface hdf5_write_dataset_real
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value         -- real(rp): Dataset value.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_real_rank_0 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(1)
integer h5_err
real(rp) value
real(rp) vector(1)
logical error
character(*) dataset_name

!

error = .true.
v_size = 1
call H5LTmake_dataset_double_f(root_id, dataset_name, 1, [v_size], vector, h5_err);  if (h5_err < 0) return
value = vector(1)
error = .false.

end subroutine hdf5_write_dataset_real_rank_0

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_real_rank_1(root_id, dataset_name, value, error)
!
! Routine to create a dataset with an array of real values.
! Overloaded by: interface hdf5_write_dataset_real
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value(:)      -- real(rp): Dataset value array.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_real_rank_1 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(1)
integer h5_err
real(rp) value(:)
logical error
character(*) dataset_name

!

error = .true.
v_size = size(value)
call H5LTmake_dataset_double_f(root_id, dataset_name, 1, v_size, value, h5_err);  if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_dataset_real_rank_1

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_real_rank_2(root_id, dataset_name, value, error)
!
! Routine to create a dataset with a matrix of real values.
! Overloaded by: interface hdf5_write_dataset_real
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value(:,:)    -- real(rp): Dataset value matrix.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_real_rank_2 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(2)
integer h5_err
real(rp) value(:,:)
logical error
character(*) dataset_name

!

error = .true.
v_size = [size(value, 1), size(value, 2)]
call H5LTmake_dataset_double_f(root_id, dataset_name, 2, v_size, value, h5_err);  if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_dataset_real_rank_2

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_real_rank_3(root_id, dataset_name, value, error)
!
! Routine to create a dataset with a 3D array of real values.
! Overloaded by: interface hdf5_write_dataset_real
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value(:,:,:)  -- real(rp): Dataset values
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_real_rank_3 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(3)
integer h5_err
real(rp) value(:,:,:)
logical error
character(*) dataset_name

!

error = .true.
v_size = [size(value, 1), size(value, 2), size(value, 3)]
call H5LTmake_dataset_double_f(root_id, dataset_name, 3, v_size, value, h5_err);  if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_dataset_real_rank_3

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_int_rank_0(root_id, dataset_name, value, error)
!
! Routine to create a dataset with one integer value.
! Overloaded by: interface hdf5_write_dataset_int
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value         -- integer: Dataset value.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_int_rank_0 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(1)
integer h5_err
integer value
integer vector(1)
logical error
character(*) dataset_name

!

error = .true.
v_size = 1
call H5LTmake_dataset_int_f(root_id, dataset_name, 1, v_size, vector, h5_err);  if (h5_err < 0) return
value = vector(1)
error = .false.

end subroutine hdf5_write_dataset_int_rank_0

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_int_rank_1(root_id, dataset_name, value, error)
!
! Routine to create a dataset with an array of integer values.
! Overloaded by: interface hdf5_write_dataset_int
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value(:)      -- integer: Dataset value array.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_int_rank_1 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(1)
integer h5_err
integer value(:)
logical error
character(*) dataset_name

!

error = .true.
v_size = size(value)
call H5LTmake_dataset_int_f(root_id, dataset_name, 1, v_size, value, h5_err);  if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_dataset_int_rank_1

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_int_rank_2(root_id, dataset_name, value, error)
!
! Routine to create a dataset with a matrix of integer values.
! Overloaded by: interface hdf5_write_dataset_int
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value(:,:)    -- integer: Dataset value matrix.
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_int_rank_2 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(2)
integer h5_err
integer value(:,:)
logical error
character(*) dataset_name

!

error = .true.
v_size = [size(value, 1), size(value, 2)]
call H5LTmake_dataset_int_f(root_id, dataset_name, 2, v_size, value, h5_err);  if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_dataset_int_rank_2

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine hdf5_write_dataset_int_rank_3(root_id, dataset_name, value, error)
!
! Routine to create a dataset with a 3D array of integer values.
! Overloaded by: interface hdf5_write_dataset_int
!
! Input:
!   root_id       -- integer(hid_t): ID of the group the dataset is to be put in.
!   dataset_name  -- character(*): Name of the dataset.
!   value(:,:,:)  -- integer: Dataset values
!   error         -- logical Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_dataset_int_rank_3 (root_id, dataset_name, value, error)

integer(hid_t) root_id, v_size(3)
integer h5_err
integer value(:,:,:)
logical error
character(*) dataset_name

!

error = .true.
v_size = [size(value, 1), size(value, 2), size(value, 3)]
call H5LTmake_dataset_int_f(root_id, dataset_name, 3, v_size, value, h5_err);  if (h5_err < 0) return
error = .false.

end subroutine hdf5_write_dataset_int_rank_3

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------

! Adapted from h5ltread_dataset_double_kind_8_rank_0
SUBROUTINE hdf5_read_dataset_real_rank_0(loc_id,dset_name,buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  REAL(KIND=8),INTENT(INout), TARGET :: buf
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  logical error
  f_ptr = C_LOC(buf               )
  namelen = LEN(dset_name)
  h5_err = h5ltread_dataset_c(loc_id,namelen,dset_name,H5T_NATIVE_DOUBLE,f_ptr)
  error = (h5_err < 0)
END SUBROUTINE hdf5_read_dataset_real_rank_0

! Adapted from h5ltread_dataset_double_kind_8_rank_1
SUBROUTINE hdf5_read_dataset_real_rank_1(loc_id,dset_name,buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  REAL(KIND=8),INTENT(INout), TARGET :: buf(:)
  REAL(KIND=8), target :: temp_buf(size(buf))
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  logical error
  f_ptr = C_LOC(temp_buf(1)            )
  namelen = LEN(dset_name)
  h5_err = h5ltread_dataset_c(loc_id,namelen,dset_name,H5T_NATIVE_DOUBLE,f_ptr)
  error = (h5_err < 0)
  buf = temp_buf
END SUBROUTINE hdf5_read_dataset_real_rank_1

! Adapted from h5ltread_dataset_double_kind_8_rank_2
SUBROUTINE hdf5_read_dataset_real_rank_2(loc_id,dset_name,buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  REAL(KIND=8),INTENT(INout), TARGET :: buf(:,:)
  REAL(KIND=8), target :: temp_buf(size(buf,1),size(buf,2))
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  logical error
  f_ptr = C_LOC(temp_buf(1,1)          )
  namelen = LEN(dset_name)
  h5_err = h5ltread_dataset_c(loc_id,namelen,dset_name,H5T_NATIVE_DOUBLE,f_ptr)
  error = (h5_err < 0)
  buf = temp_buf
END SUBROUTINE hdf5_read_dataset_real_rank_2

! Adapted from h5ltread_dataset_double_kind_8_rank_3
SUBROUTINE hdf5_read_dataset_real_rank_3(loc_id,dset_name,buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  REAL(KIND=8),INTENT(INout), TARGET :: buf(:,:,:)
  REAL(KIND=8), target :: temp_buf(size(buf,1),size(buf,2),size(buf,3))
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  logical error
  f_ptr = C_LOC(temp_buf(1,1,1)        )
  namelen = LEN(dset_name)
  h5_err = h5ltread_dataset_c(loc_id,namelen,dset_name,H5T_NATIVE_DOUBLE,f_ptr)
  error = (h5_err < 0)
  buf = temp_buf
END SUBROUTINE hdf5_read_dataset_real_rank_3

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------

! Adapted from h5ltread_dataset_int_kind_4_rank_0
SUBROUTINE hdf5_read_dataset_int_rank_0(loc_id,dset_name, buf, error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  INTEGER(KIND=4),INTENT(INout), TARGET :: buf
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  INTEGER(hid_t) :: type_id
  logical error
  f_ptr = C_LOC(buf               )
  namelen = LEN(dset_name)
  type_id = h5kind_to_type(KIND(buf               ), H5_INTEGER_KIND)
  h5_err = h5ltread_dataset_c(loc_id, namelen, dset_name, type_id, f_ptr)
  error = (h5_err < 0)
END SUBROUTINE hdf5_read_dataset_int_rank_0

! Adapted from h5ltread_dataset_int_kind_4_rank_1
SUBROUTINE hdf5_read_dataset_int_rank_1(loc_id,dset_name, buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  INTEGER(KIND=4),INTENT(INout), TARGET :: buf(:)
  INTEGER(KIND=4), target :: temp_buf(size(buf))
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  INTEGER(hid_t) :: type_id
  logical error
  f_ptr = C_LOC(temp_buf(1)            )
  namelen = LEN(dset_name)
  type_id = h5kind_to_type(KIND(buf(1)            ), H5_INTEGER_KIND)
  h5_err = h5ltread_dataset_c(loc_id, namelen, dset_name, type_id, f_ptr)
  error = (h5_err < 0)
  buf = temp_buf
END SUBROUTINE hdf5_read_dataset_int_rank_1

! Adapted from h5ltread_dataset_int_kind_4_rank_2
SUBROUTINE hdf5_read_dataset_int_rank_2(loc_id,dset_name, buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  INTEGER(KIND=4),INTENT(INout), TARGET :: buf(:,:)
  INTEGER(KIND=4), target :: temp_buf(size(buf,1),size(buf,2))
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  INTEGER(hid_t) :: type_id
  logical error
  f_ptr = C_LOC(temp_buf(1,1)          )
  namelen = LEN(dset_name)
  type_id = h5kind_to_type(KIND(buf(1,1)          ), H5_INTEGER_KIND)
  h5_err = h5ltread_dataset_c(loc_id, namelen, dset_name, type_id, f_ptr)
  error = (h5_err < 0)
  buf = temp_buf
END SUBROUTINE hdf5_read_dataset_int_rank_2

! Adapted from h5ltread_dataset_int_kind_4_rank_3
SUBROUTINE hdf5_read_dataset_int_rank_3(loc_id,dset_name, buf,error)
  IMPLICIT NONE
  INTEGER(hid_t)  , INTENT(IN) :: loc_id
  CHARACTER(LEN=*), INTENT(IN) :: dset_name
  INTEGER(KIND=4),INTENT(INout), TARGET :: buf(:,:,:)
  INTEGER(KIND=4), target :: temp_buf(size(buf,1),size(buf,2),size(buf,3))
  INTEGER :: h5_err 
  TYPE(C_PTR) :: f_ptr
  INTEGER(size_t) :: namelen
  INTEGER(hid_t) :: type_id
  logical error
  f_ptr = C_LOC(temp_buf(1,1,1)        )
  namelen = LEN(dset_name)
  type_id = h5kind_to_type(KIND(buf(1,1,1)        ), H5_INTEGER_KIND)
  h5_err = h5ltread_dataset_c(loc_id, namelen, dset_name, type_id, f_ptr)
  error = (h5_err < 0)
  buf = temp_buf
END SUBROUTINE hdf5_read_dataset_int_rank_3

end module
