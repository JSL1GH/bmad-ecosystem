set (EXENAME bmad_to_autocad)
set (SRC_FILES
  bmad_to_autocad/bmad_to_autocad.f90
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