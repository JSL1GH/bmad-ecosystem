set (EXENAME element_attributes)
set (SRC_FILES
  element_attributes/element_attributes.f90
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