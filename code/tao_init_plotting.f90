!+
! Subroutine tao_init_plotting (plot_file)
!
! Subroutine to initialize the tao plotting structures.
! If plot_file is not in the current directory then it will be searched
! for in the directory:
!   TAO_INIT_DIR
!
! Input:
!   plot_file -- Character(*): Plot initialization file.
!
! Output:
!-

subroutine tao_init_plotting (plot_file)

use tao_mod
use tao_input_struct
use quick_plot
use tao_plot_window_mod

implicit none

type (tao_plot_page_struct), pointer :: page
type (tao_plot_struct), pointer :: plt
type (tao_graph_struct), pointer :: grph
type (tao_curve_struct), pointer :: crv
type (tao_plot_input) plot
type (tao_graph_input) graph
type (tao_plot_page_struct) plot_page, plot_page_default
type (tao_region_input) region(n_region_maxx)
type (tao_curve_input) curve(n_curve_maxx)
type (tao_place_input) place(10)
type (tao_ele_shape_struct) shape(20)
type (qp_symbol_struct) default_symbol
type (qp_line_struct) default_line
type (qp_axis_struct) init_axis

integer iu, i, j, ix, ip, n, ng, ios, i_uni
integer graph_index, color
integer, allocatable :: ix_ele(:)

character(*) plot_file
character(100) graph_name, file_name
character(80) label
character(20) :: r_name = 'tao_init_plotting'

logical lat_layout_here

namelist / tao_plot_page / plot_page, region, place
namelist / tao_template_plot / plot
namelist / tao_template_graph / graph, graph_index, curve
namelist / element_shapes / shape

! See if this routine has been called before

if (.not. s%global%init_plot_needed) return
s%global%init_plot_needed = .false.
init_axis%max = 0

! Read in the plot page parameters

call out_io (s_blank$, r_name, '*Init: Opening Plotting File: ' // plot_file)
call tao_open_file ('TAO_INIT_DIR', plot_file, iu, file_name)
if (iu == 0) then
  call out_io (s_fatal$, r_name, 'ERROR OPENING PLOTTING FILE. WILL EXIT HERE...')
  call err_exit
endif

place%region = ' '
region%name = ' '       ! a region exists only if its name is not blank 
plot_page = plot_page_default
plot_page%title(:)%draw_it = .false.
plot_page%title(:)%string = ' '
plot_page%title(:)%justify = 'CC'
plot_page%title(:)%x = 0.50
plot_page%title(:)%y = 0.990
plot_page%title(1)%y = 0.996
plot_page%title(2)%y = 0.97
plot_page%title(:)%units = '%PAGE'

call out_io (s_blank$, r_name, 'Init: Reading tao_plot_page namelist')
read (iu, nml = tao_plot_page, iostat = ios)
if (ios > 0) then
  call out_io (s_error$, r_name, 'ERROR READING TAO_PLOT_PAGE NAMELIST.')
  rewind (iu)
  read (iu, nml = tao_plot_page)  ! To give error message
endif
if (ios < 0) call out_io (s_blank$, r_name, 'Note: No tao_plot_page namelist found')

s%plot_page = plot_page
page => s%plot_page

! title

forall (i = 1:size(page%title), (page%title(i)%string .ne. ' ')) &
            page%title(i)%draw_it = .true.

! allocate a s%plot_page%plot structure for each region defined and
! transfer the info from the input region structure.

n = count(region%name /= ' ')
allocate (s%plot_region(n))

do i = 1, n
  s%plot_region(i)%name     = region(i)%name
  s%plot_region(i)%location = region(i)%location
enddo

! Read in the plot templates and transfer the info to the 
! s%tamplate_plot structures

ip = 0   ! number of template plots
lat_layout_here = .false.

do
  plot%name = ' '
  plot%x_axis_type = 'index'
  plot%x = init_axis
  plot%x%minor_div_max = 6
  plot%x%major_div = 6
  plot%independent_graphs = .false.
  plot%n_graph = 0
  read (iu, nml = tao_template_plot, iostat = ios, err = 9100)  
  if (ios /= 0) exit                                 ! exit on end of file.
  call out_io (s_blank$, r_name, &
                  'Init: Read tao_template_plot namelist: ' // plot%name)
  ip = ip + 1

  if (ip .gt. n_template_maxx) then
    call out_io (s_warn$, r_name, &
            "Number of plot templates exceeds maximum of \I2\ ", n_template_maxx)
    call out_io (s_blank$, r_name, &
                "Only first \I2\ will be used", n_template_maxx)
    exit
  endif
  
  plt => s%template_plot(ip)
  nullify(plt%r)
  plt%name            = plot%name
  plt%x_axis_type     = plot%x_axis_type
  plt%x               = plot%x
  plt%x%major_div_nominal = plot%x%major_div
  plt%independent_graphs  = plot%independent_graphs
  call qp_calc_axis_places (plt%x)

  do
    ix = index(plt%name, '.')
    if (ix == 0) exit
    call out_io (s_error$, r_name, 'PLOT NAME HAS ".": ' // plt%name, &
                 'SUBSTITUTING "-"')
    plt%name(ix:ix) = '-'
  enddo

  ng = plot%n_graph
  if (ng == 0) then
    deallocate (plt%graph)
  else
    allocate (plt%graph(ng))
  endif

  do i = 1, ng
    write (graph%name, '(a, i0)') 'g', i
    graph_index = 0                 ! setup defaults
    graph%title = ''
    graph%type  = 'data'
    graph%legend_origin = qp_point_struct(1.0_rp, 1.0_rp, '%GRAPH')
    graph%y  = init_axis
    graph%y2 = init_axis
    graph%y2%label_color = blue$
    graph%y2%draw_numbers = .false.
    graph%correct_xy_distortion = .false.
    graph%ix_universe = 0
    graph%clip = .true.
    graph%draw_axes = .true.
    graph%who%name  = ' '                               ! set default
    graph%who(1) = tao_plot_who_struct('model', +1)     ! set default
    graph%box    = (/ 1, 1, 1, 1 /)
    graph%margin = qp_rect_struct(0.0_rp, 0.0_rp, 0.0_rp, 0.0_rp, '%GRAPH')
    graph%n_curve = 0
    do j = 1, size(curve)
      write (curve(j)%name, '(a, i0)') 'c', j
    enddo
    curve(:)%data_source = 'lattice'
    curve(:)%x_axis_scale_factor = 1
    curve(:)%y_axis_scale_factor = 1
    curve(:)%ix_bunch = 0
    curve(:)%convert = .false.                             ! set default
    curve(:)%symbol_every = 1
    curve(:)%ix_universe = 0
    curve(:)%draw_line = .true.
    curve(:)%draw_symbols = .true.
    curve(:)%use_y2 = .false.
    curve(:)%symbol = default_symbol
    curve(:)%line   = default_line
    curve(:)%ele_ref_name   = ' '
    curve(:)%ix_ele_ref = -1
    curve(:)%draw_interpolated_curve = .true.
    curve(2:7)%symbol%type = &
                (/ times$, square$, plus$, triangle$, x_symbol$, diamond$ /)
    curve(2:7)%symbol%color = &
                (/ blue$, red$, green$, cyan$, magenta$, yellow$ /)
    curve(2:7)%line%color = curve(2:7)%symbol%color
    read (iu, nml = tao_template_graph, err = 9200)
    graph_name = trim(plot%name) // '.' // graph%name
    call out_io (s_blank$, r_name, &
            'Init: Read tao_template_graph namelist: ' // graph_name)
    if (graph_index /= i) then
      call out_io (s_error$, r_name, 'BAD "GRAPH_INDEX" FOR: ' // graph_name)
      call err_exit
    endif
    grph => plt%graph(i)
    grph%p             => plt
    grph%name          = graph%name
    grph%type          = graph%type
    grph%who           = graph%who
    grph%legend_origin = graph%legend_origin
    grph%box           = graph%box
    grph%title         = graph%title
    grph%margin        = graph%margin
    grph%y             = graph%y
    grph%y2            = graph%y2
    grph%ix_universe   = graph%ix_universe
    grph%clip          = graph%clip
    grph%draw_axes     = graph%draw_axes
    grph%correct_xy_distortion = graph%correct_xy_distortion
    grph%title_suffix = ' '
    grph%legend = ' '
    grph%y2_mirrors_y = .true.

    do
      ix = index(grph%name, '.')
      if (ix == 0) exit
      call out_io (s_error$, r_name, 'GRAPH NAME HAS ".": ' // grph%name, &
                   'SUBSTITUTING "-"')
      grph%name(ix:ix) = '-'
    enddo

    call qp_calc_axis_places (grph%y)

    if (grph%ix_universe < 0 .or. grph%ix_universe > size(s%u)) then
      call out_io (s_error$, r_name, 'UNIVERSE INDEX: \i4\ ', grph%ix_universe)
      call out_io (s_blank$, r_name, 'OUT OF RANGE FOR PLOT:GRAPH: ' // graph_name)
      call err_exit
    endif

    if (grph%type == 'floor_plan') lat_layout_here = .true.
    if (grph%type == 'lat_layout') then
      lat_layout_here = .true.
      if (plt%x_axis_type /= 's') call out_io (s_error$, r_name, &
                'A lat_layout must have x_axis_type = "s" for a visible plot!')
    endif

    if (graph%n_curve == 0) then
      if (allocated(grph%curve)) deallocate (grph%curve)
    else
      allocate (grph%curve(graph%n_curve))
    endif

    do j = 1, graph%n_curve
      crv => grph%curve(j)
      crv%g                       => grph
      crv%data_source             = curve(j)%data_source
      crv%data_type               = curve(j)%data_type
      crv%x_axis_scale_factor     = curve(j)%x_axis_scale_factor
      crv%y_axis_scale_factor     = curve(j)%y_axis_scale_factor
      crv%symbol_every            = curve(j)%symbol_every
      crv%ix_universe             = curve(j)%ix_universe
      crv%draw_line               = curve(j)%draw_line
      crv%draw_symbols            = curve(j)%draw_symbols
      crv%use_y2                  = curve(j)%use_y2
      crv%symbol                  = curve(j)%symbol
      crv%line                    = curve(j)%line
      crv%convert                 = curve(j)%convert
      crv%draw_interpolated_curve = curve(j)%draw_interpolated_curve
      crv%name                    = curve(j)%name
      crv%ele_ref_name            = curve(j)%ele_ref_name
      call str_upcase (crv%ele_ref_name, crv%ele_ref_name)
      crv%ix_ele_ref              = curve(j)%ix_ele_ref
      crv%ix_bunch                = curve(j)%ix_bunch

      do
        ix = index(crv%name, '.')
        if (ix == 0) exit
        call out_io (s_error$, r_name, 'CURVE NAME HAS ".": ' // crv%name, &
                     'SUBSTITUTING "-"')
        crv%name(ix:ix) = '-'
      enddo

      ! Turn on the y2 axis numbering if needed.

      if (crv%use_y2) then
        grph%y2%draw_numbers = .true.
        grph%y2_mirrors_y = .false.
        grph%y2%label_color = crv%symbol%color
      endif

      ! Enable the radiation integrals calculation if needed.

      i_uni = tao_universe_number (crv%ix_universe)

      if ((crv%data_type(1:10) == 'emittance.' .or. crv%data_type(1:15) == 'norm_emittance.') .and. &
                                                                         crv%data_source == 'lattice') then
        if (crv%ix_universe == 0) then
          s%u%do_synch_rad_int_calc = .true.
        else
          s%u(i_uni)%do_synch_rad_int_calc = .true.
        endif
      endif

      ! Find the ele_ref info if either ele_ref_name or ix_ele_ref has been set.
      ! If plotting something like the phase then the default is for ele_ref 
      ! to be the beginning element.

      if (crv%ele_ref_name == ' ' .and. crv%ix_ele_ref >= 0) then ! if ix_ele_ref has been set ...
        crv%ele_ref_name = s%u(i_uni)%design%lat%ele(crv%ix_ele_ref)%name ! then find the name
      elseif (crv%ele_ref_name /= ' ') then                    ! if ele_ref_name has been set ...
        call tao_locate_element (crv%ele_ref_name, i_uni, ix_ele, .true.) ! then find the index
        crv%ix_ele_ref = ix_ele(1)
      elseif (crv%data_type(1:5) == 'phase' .or. crv%data_type(1:2) == 'r.' .or. &
              crv%data_type(1:2) == 't.' .or. crv%data_type(1:3) == 'tt.') then
        crv%ix_ele_ref = 0
        crv%ele_ref_name = s%u(i_uni)%design%lat%ele(0)%name
      elseif (graph%type == 'phase_space') then
        plt%x_axis_type = 'phase_space'
        crv%ix_ele_ref = 0
        crv%ele_ref_name = s%u(i_uni)%design%lat%ele(0)%name
      elseif (graph%type == 'key_table') then
        plt%x_axis_type = 'none'
      endif

      call tao_ele_ref_to_ele_ref_track (crv%ix_universe, crv%ix_ele_ref, crv%ix_ele_ref_track)

    enddo  ! curve

    call qp_calc_axis_places (grph%y2)
    if (grph%y2%min == grph%y2%max .and. .not. grph%y2_mirrors_y) then
      label = grph%y2%label
      color = grph%y2%label_color
      grph%y2 = grph%y
      grph%y2%label = label
      grph%y2%label_color = color
    endif
  enddo  ! graph
enddo  ! plot

! read in shapes

s%plot_page%ele_shape%key = 0

if (lat_layout_here) then

  rewind (iu)
  shape(:)%key_name = ' '
  read (iu, nml = element_shapes, iostat = ios)

  if (ios /= 0) then
    call out_io (s_error$, r_name, 'ERROR READING ELE_SHAPE NAMELIST IN FILE.')
    call err_exit
  endif

  do i = 1, size(shape)
    call str_upcase (shape(i)%key_name, shape(i)%key_name)
    call str_upcase (shape(i)%ele_name, shape(i)%ele_name)
    call str_upcase (shape(i)%shape,    shape(i)%shape)
    call str_upcase (shape(i)%color,    shape(i)%color)

    if (shape(i)%key_name == ' ') cycle
    shape(i)%key = key_name_to_key_index (shape(i)%key_name, .true.)

    if (shape(i)%key < 1) then
      print *, 'ERROR: CANNOT FIND KEY FOR: ', shape(i)%key_name
      call err_exit
    endif

  enddo
  s%plot_page%ele_shape = shape

endif

close (iu)

! initial placement of plots

do i = 1, size(place)
  if (place(i)%region == ' ') cycle
  call tao_place_cmd (place(i)%region, place(i)%plot)
enddo

call tao_create_plot_window

return

!-----------------------------------------

9100 continue
call out_io (s_error$, r_name, &
        'TAO_TEMPLATE_PLOT NAMELIST READ ERROR.', 'IN FILE: ' // file_name)
rewind (iu)
do
  read (iu, nml = tao_template_plot)  ! force printing of error message
enddo

!-----------------------------------------

9200 continue
call out_io (s_error$, r_name, &
       'TAO_TEMPLATE_GRAPH NAMELIST READ ERROR.', 'IN FILE: ' // file_name)
rewind (iu)
do
  read (iu, nml = tao_template_graph)  ! force printing of error message
enddo

end subroutine tao_init_plotting
