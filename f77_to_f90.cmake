set (EXENAME f77_to_f90)
set (SRC_FILES
  f77_to_f90/f77_to_f90.f90
)

set (INC_DIRS
  ../include
  include
)

set (LINK_LIBS
  bsim
  bmad 
  sim_utils
  recipes_f-90_LEPP 
  forest 
)