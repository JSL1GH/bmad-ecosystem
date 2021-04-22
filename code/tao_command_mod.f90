module tao_command_mod

use output_mod
use tao_interface

contains

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine tao_cmd_history_record (cmd)
!
! Subroutine to record a cmd in the command history stack
!-

subroutine tao_cmd_history_record (cmd)

implicit none

character(*) cmd

!

s%com%ix_history = s%com%ix_history + 1
if (s%com%ix_history > size(s%history)) s%com%ix_history = 1
s%com%n_history = s%com%n_history + 1
s%history(s%com%ix_history)%ix = s%com%n_history
if (s%com%cmd_from_cmd_file) then
  s%history(s%com%ix_history)%cmd = '  ! ' // trim(cmd)
else
  s%history(s%com%ix_history)%cmd = trim(cmd)
endif

end subroutine

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine tao_re_exectue (string, err)
!
! Subroutine to execute a previous command.
!-

subroutine tao_re_execute (string, err)

implicit none

integer ios, ix1, ix, ix_rec
character(*) string
character(len(string)) line
character(*), parameter :: r_name = 'tao_history_cmd'
logical err

!

err = .true.

if (is_integer(string)) then
  call string_trim(string, line, ix)
  if (line(ix+1:) /= '') then
    call out_io (s_error$, r_name, 'EXTRA STUFF AFTER INTEGER INDEX.')
    return
  endif

  read (string, *, iostat = ios) ix_rec
  if (ios /= 0) then
    call out_io (s_error$, r_name, 'ERROR READING HISTORY NUMBER')
    return
  endif

  if (ix_rec > 0) then
    if (ix_rec > s%com%n_history .or. ix_rec < s%com%n_history - (size(s%history) - 1)) then
      call out_io (s_error$, r_name, 'INVALID INDEX FOR THE HISTORY LIST.')
      return
    endif
    ix = ix_rec + s%com%ix_history - s%com%n_history
  else
    if (-ix_rec > size(s%history) - 1 .or. -ix_rec > s%com%n_history - 1) then 
      call out_io (s_error$, r_name, 'INVALID INDEX FOR THE HISTORY LIST.')
      return
    endif
    ix = s%com%ix_history + ix_rec
  endif

  if (ix < 1) ix = ix + size(s%history)

!

else

  ix = s%com%ix_history
  do

    if (index(s%history(ix)%cmd, trim(string)) == 1) exit

    ix = ix - 1
    if (ix < 1) ix = ix + size(s%history)

    if (ix == s%com%ix_history .or. s%history(ix)%ix == 0) then
      call out_io (s_error$, r_name, 'COMMAND NOT FOUND IN THE HISTORY LIST.')
      return
    endif

  enddo

endif

! put the command in the common area so it can be used next.

call string_trim(s%history(ix)%cmd, s%com%cmd, ix)
if (s%com%cmd(1:1) == '!') s%com%cmd = s%com%cmd(2:)
s%com%use_cmd_here = .true.

err = .false.

end subroutine tao_re_execute

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine tao_cmd_split (cmd_line, n_word, cmd_word, extra_words_is_error, err, separator)
!
! This routine splits the command line into words.
!
! Input: 
!   cmd_line        -- Character(*): The command line.
!   n_word          -- Integer: Maximum number of words to split command line into.
!   extra_words_is_error 
!                   -- Logical: are extra words allowed at the end?
!                        If True then err argument is set True.
!                        If False then cmd_word(n_word) will contain everything after 
!                        the n_word-1 word.
!   separator       -- Character(*), optional: a list of characters that,
!                        besides a blank space, signify a word boundary. 
!
! Output:
!   cmd_word(n_word) -- Character(*): The individual words.
!   err              -- Logical: error in splitting words
!
! For example: 
!   separator = '-+' 
!   cmd_line = 'model-design'
! Result:
!   cmd_word(1) = 'model'
!   cmd_word(2) = '-'
!   cmd_word(3) = 'design'
!
! Notes:
!   Anything between single or double quotes is treated as a single word.
!   Whitespace or a separator inside of "{}", "()", or "[]" is ignored.
!   Whitespace after or before a comma is ignored.
!-

subroutine tao_cmd_split (cmd_line, n_word, cmd_word, extra_words_is_error, err, separator)

integer i, ix, nw, n_word, ix_b1, ix_b2, ix_b3, ix_comma

character(*) cmd_line
character(*), optional :: separator
character(*) cmd_word(:)
character(16) :: r_name = 'tao_cmd_split'
character(len(cmd_line)) line
character(1), parameter :: tab = char(9)

logical err
logical extra_words_is_error, comma_here, comma_in_separator

!

err = .false.
line = cmd_line
cmd_word(:) = ''
nw = 0
comma_here = .false.
comma_in_separator = .false.
if (present(separator)) comma_in_separator = (index(separator, ',') /= 0)

forall (i = 1:len(line), line(i:i) == tab) line(i:i) = ' '

nw_loop: do 
  call string_trim (line, line, ix)
  ix_comma = 0

  if (nw > 0 .and. line(1:1) == ',' .and. .not. comma_in_separator) then  ! append to previous
    line = trim(cmd_word(nw)) // line
    ix_comma = len_trim(cmd_word(nw)) + 1
    nw = nw - 1
  endif

  if (ix == 0) exit

  ! If extra words allowed, everything left goes into cmd_word(n_word)
  if (nw == n_word - 1 .and. .not. extra_words_is_error) then
    nw=nw+1; cmd_word(nw) = trim(line)
    return
  endif

  if (nw == n_word) then
    call out_io (s_error$, r_name, 'EXTRA STUFF ON COMMAND LINE: ' // line)
    err = .true.
    return
  endif

  if (line(1:1) == '"') then
    ix = index(line(2:), '"')
    if (ix == 0) ix = len(line)
    nw=nw+1; cmd_word(nw) = line(2:ix)
    line = line(ix+1:)
    cycle
  elseif (line(1:1) == "'") then
    ix = index(line(2:), "'")
    if (ix == 0) ix = len(line)
    nw=nw+1; cmd_word(nw) = line(2:ix)
    line = line(ix+1:)
    cycle
  endif

  ix_b1 = 0; ix_b2 = 0; ix_b3 = 0

  do i = 1, len(line)
    if (i < ix_comma) cycle

    if (line(i:i) == '{') ix_b1 = ix_b1 + 1
    if (line(i:i) == '}') ix_b1 = ix_b1 - 1
    if (line(i:i) == '(') ix_b2 = ix_b2 + 1
    if (line(i:i) == ')') ix_b2 = ix_b2 - 1
    if (line(i:i) == '[') ix_b3 = ix_b3 + 1
    if (line(i:i) == ']') ix_b3 = ix_b3 - 1

    if (line(i:i) == ',') then
      comma_here = .true.
    elseif (line(i:i) /= ' ') then
      comma_here = .false.
    endif

    if (ix_b1 /= 0 .or. ix_b2 /= 0 .or. ix_b3 /= 0) cycle

    if (present(separator)) then
      if (index(separator, line(i:i)) /= 0) then
        if (i /= 1) then
          nw=nw+1; cmd_word(nw) = line(1:i-1)
          line = line(i:)
          if (nw == n_word - 1 .and. .not. extra_words_is_error) cycle nw_loop 
        endif
        nw=nw+1; cmd_word(nw) = line(1:1)
        line = line(2:)
        cycle nw_loop
      endif
    endif

    if (line(i:i) == ' ') then
      if (comma_here) cycle
      nw=nw+1; cmd_word(nw) = line(1:i-1)
      line = line(i+1:)
      cycle nw_loop
    endif

  enddo

  if (ix_b1 /= 0 .or. ix_b2 /= 0 .or. ix_b3 /= 0) then
    call out_io (s_error$, r_name, 'MISMATCHED "{...}", "(...)", OR "[...]".')
    err = .true.
    return
  endif

  call out_io (s_fatal$, r_name, 'INTERNAL ERROR!')
  call err_exit

enddo nw_loop


end subroutine tao_cmd_split

!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
!+
! Subroutine tao_next_switch (line, switch_list, return_next_word, switch, err, ix_word, neg_num_not_switch)
!
! Subroutine look at the next word on the command line and match this word to a list of "switches"
! given by the switch_list argument.
! 
! Switches are assumed to start with a "-" character except if switch_list(1) does not start with
! a "-" character in which case everything is considered to be a switch.
!
! Switch abbreviations are permitted.
!
! If return_next_word = True then, when a non-switch word is encountered, the switch argument 
! will be set to that word and that word will be removed from the line argument.
!
! If return_next_word = False then, when a non-switch word is encountered, the switch argument 
! will be set to '' and the non-switch word will be left on the line argument.
!
! If the first non-blank character in line is a single or double quote. The word returned will be the
! substring from the initial quote mark to the next matching quote mark. The quote marks will be removed
! from the returned switch argument.
!
! Input:
!   line                -- character(*): Command line
!   switch_list(:)      -- character(*): List of valid switches. 
!   return_next_word    -- logical: See above.
!   neg_num_not_switch  -- logical, optional: If present and True then a word like "-34" will be treated
!                           as a non-switch.
!
! Output:
!   line            -- character(*): Line with first word removed if it is a switch or return_next_word = True.
!   switch          -- character(*): Switch found or first word on line if not a switch but return_next_word = True.
!                       If a switch this is the full name even if what was on the command line was an abbreviation.
!                       See above for more details.
!   err             -- logical: Set True if the next word begins with '-' but there is no match
!                       to anything in switch_list. An error message will be printed.
!   ix_word         -- integer: Character length of first word left on line.
!-

subroutine tao_next_switch (line, switch_list, return_next_word, switch, err, ix_word, neg_num_not_switch)

implicit none

character(*) line, switch, switch_list(:)
character(*), parameter :: r_name = 'tao_next_switch'
logical err
logical, optional :: neg_num_not_switch

integer i, ix, n, ix_word
logical return_next_word, switch_starts_with_hyphon
character(1) quote_mark

!

err = .false.
switch = ''
switch_starts_with_hyphon = (switch_list(1)(1:1) == '-')

call string_trim(line, line, ix_word)
if (ix_word == 0) return

! If quoted string...

if (line(1:1) == "'" .or. line(1:1) == '"') then
  quote_mark = line(1:1)
  do i = 2, len(line)
    if (line(i:i) /= quote_mark) cycle
    if (line(i-1:i-1) == '\') cycle  ! '
    switch = line(2:i-1)
    call string_trim(line(i+1:), line, ix_word)
    return
  enddo

  call out_io (s_error$, r_name, 'CLOSING QUOTE MARK NOT FOUND FOR:' // line)
  return
endif

! If not a switch...

if ((line(1:1) /= '-' .and. switch_starts_with_hyphon) .or. &
          (logic_option(.false., neg_num_not_switch) .and. is_real(line(1:ix_word)))) then
  if (return_next_word) then
    switch = line(1:ix_word)
    call string_trim(line(ix_word+1:), line, ix_word)
  endif
  return
endif

! It is a switch...

call match_word (line(:ix_word), switch_list, n, .true., matched_name=switch)
if (n < 1) then
  err = .true.
  if (n == 0) then
    call out_io (s_error$, r_name, 'UNKNOWN SWITCH: ' // line(:ix_word))
  else
    call out_io (s_error$, r_name, 'AMBIGUOUS SWITCH: ' // line(:ix_word))
  endif
  return
endif

call string_trim(line(ix_word+1:), line, ix_word)

end subroutine tao_next_switch

end module

