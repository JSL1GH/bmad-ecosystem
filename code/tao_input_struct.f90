!+
! module tao_input_struct
!
! Module to define the structures needed for the namelist input.
!-

module tao_input_struct

use tao_struct
use bmad_struct
use bmad_interface

integer, private, save :: dummy = 0 ! So ranlib will not complain about no symbols

!-------------------------------------------------------------
! data input structures

type tao_d2_data_input
  character(40) name           ! name of data
end type

type tao_d1_data_input
  character(40) name           ! type of data
end type

type tao_data_input
  character(100) :: data_type
  character(40) :: ele0_name
  character(40) :: ele_name
  character(20) :: merit_type
  real(rp) :: meas
  real(rp) :: weight
  logical :: good_user
  character(20) data_source
  real(rp) :: invalid_value
  integer ix_bunch
end type

type tao_datum_input
  character(100) :: data_type
  character(40) :: ele_ref_name
  character(40) :: ele_start_name
  character(40) :: ele_name
  character(20) :: merit_type
  real(rp) :: meas
  real(rp) :: weight
  logical :: good_user
  character(20) data_source
  real(rp) :: invalid_value
  integer ix_bunch
end type

!-------------------------------------------------------------
! variable input structures

type tao_v1_var_input
  character(40) name           ! name of variable
end type

type tao_var_input
  character(40) :: ele_name
  character(40) attribute       ! attribute to vary
  character(16) universe
  real(rp) :: weight
  real(rp) :: step
  real(rp) low_lim
  real(rp) high_lim
  character(40) :: merit_type
  logical :: good_user
  logical key_bound
  real(rp) key_delta
end type

!-------------------------------------------------------------
! plot input structures

type tao_region_input
  character(40) name             ! Eg: 'top', 'bottom'.
  real(rp) location(4)           ! location on page.
end type

type tao_place_input
  character(40) region
  character(40) plot
end type

type tao_curve_input
  character(40) name
  character(40) data_source
  character(100) data_type_x
  character(100) data_type
  character(100) data_index
  character(40) legend_text
  real(rp) y_axis_scale_factor
  integer symbol_every
  integer ix_universe
  logical draw_line
  logical draw_symbols
  logical draw_symbol_index
  logical use_y2
  logical draw_interpolated_curve
  logical smooth_line_calc
  character(40) ele_ref_name
  integer ix_branch
  integer ix_ele_ref
  integer ix_bunch
  real(rp) x_axis_scale_factor
  type (qp_line_struct) line
  type (qp_symbol_struct) symbol
end type

type tao_graph_input
  character(40) name
  character(40) type
  character(80) title
  character(60) component
  integer box(4)
  integer ix_universe
  integer ix_branch
  integer n_curve
  real(rp) x_axis_scale_factor
  real(rp) symbol_size_scale 
  real(rp) bin_width
  logical clip
  logical draw_axes
  logical correct_xy_distortion
  logical draw_curve_legend     ! For identifying curves. 
  logical draw_only_good_user_data_or_vars
  type (qp_point_struct) legend_origin  ! For backwards compatibility
  type (qp_point_struct) text_legend_origin
  type (qp_point_struct) curve_legend_origin
  type (tao_data_var_component_struct) who(n_who_maxx)
  type (qp_rect_struct) margin
  type (qp_axis_struct) x
  type (qp_axis_struct) y
  type (qp_axis_struct) y2
end type 

type tao_plot_input
  character(40) name
  character(60) description
  character(16) x_axis_type
  integer n_graph
  logical independent_graphs
  logical autoscale_gang_x      ! scale cmd scales graphs independently?
  logical autoscale_gang_y      ! scale cmd scales graphs independently?
  logical autoscale_x 
  logical autoscale_y 
  type (qp_axis_struct) x
end type

!-------------------------------------------------------------
! other structures

type tao_design_lat_input
  character(100) file
  character(100) file2
  character(16) language
  character(40) use_line
end type

type tao_key_input
  character(40) ele_name
  character(40) attrib_name
  real(rp) delta
  character(16) universe
  real(rp) small_step
  real(rp) low_lim
  real(rp) high_lim
  real(rp) weight
  logical good_opt
  character(40) merit_type
end type

type tao_plot_page_struct
  character(8) :: plot_display_type = 'X'       ! 'X' or 'TK'
  character(80) ps_scale             ! scaling when creating PS files.
  real(rp) size(2)                   ! width and height of window in pixels.
  real(rp) :: text_height = 12              ! In points. Scales the height of all text
  real(rp) :: main_title_text_scale  = 1.3  ! Relative to text_height
  real(rp) :: graph_title_text_scale = 1.1  ! Relative to text_height
  real(rp) :: axis_number_text_scale = 0.9  ! Relative to text_height
  real(rp) :: axis_label_text_scale  = 1.0  ! Relative to text_height
  real(rp) :: legend_text_scale      = 0.8  ! Relative to text_height
  real(rp) :: key_table_text_scale   = 0.9  ! Relative to text_height
  real(rp) :: curve_legend_line_len  = 50   ! Points
  real(rp) :: curve_legend_text_offset = 10 ! Points
  real(rp) :: floor_plan_rotation = 0    ! Rotation of floor plan plot: 1.0 -> 360^deg 
  integer :: n_curve_pts = 401           ! Number of points for plotting a smooth curve
  type (tao_title_struct) title(2)       ! Titles at top of page.
  type (qp_rect_struct) border           ! Border around plots edge of page.
end type

contains

!------------------------------------------------------------------------------

subroutine tao_set_plotting (plot_page, plotting, use_cmd_line_geom)

implicit none

type (tao_plot_page_struct) plot_page
type (tao_plotting_struct) plotting

integer ix
logical use_cmd_line_geom
character(40) str
character(16), parameter :: r_name = 'tao_set_plotting'

!

plotting%plot_display_type         = plot_page%plot_display_type
plotting%ps_scale                  = plot_page%ps_scale
plotting%size                      = plot_page%size
plotting%text_height               = plot_page%text_height
plotting%main_title_text_scale     = plot_page%main_title_text_scale
plotting%graph_title_text_scale    = plot_page%graph_title_text_scale
plotting%axis_number_text_scale    = plot_page%axis_number_text_scale
plotting%axis_label_text_scale     = plot_page%axis_label_text_scale
plotting%legend_text_scale         = plot_page%legend_text_scale
plotting%key_table_text_scale      = plot_page%key_table_text_scale
plotting%curve_legend_line_len     = plot_page%curve_legend_line_len
plotting%curve_legend_text_offset  = plot_page%curve_legend_text_offset
plotting%floor_plan_rotation       = plot_page%floor_plan_rotation
plotting%n_curve_pts               = plot_page%n_curve_pts
plotting%title                     = plot_page%title 
plotting%border                    = plot_page%border

! Plot window geometry specified on cmd line?

if (use_cmd_line_geom .and. tao_com%plot_geometry /= '') then
   str = tao_com%plot_geometry
   ix = index(str, 'x')
   if (ix == 0) then
     call out_io (s_error$, r_name, 'Malformed -geometry argument. No "x" present: ' // str)
   else
     if (.not. is_integer(str(1:ix-1)) .or. .not. is_integer(str(ix+1:))) then
       call out_io (s_error$, r_name, 'Malformed -geometry argument: ' // str)
     else
       read (str(:ix-1), *) plotting%size(1)
       read (str(ix+1:), *) plotting%size(2)
     endif
   endif
 endif
 
end subroutine tao_set_plotting

!------------------------------------------------------------------------------

end module
