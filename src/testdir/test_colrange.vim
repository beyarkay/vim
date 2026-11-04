" Tests for Ex commands with a column range: ":{lnum}.{col}" and ":`x".
" See ":help :range-col".

func s:Setup()
  new
  call setline(1, ['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'])
  " start a new undo block
  let &undolevels = &undolevels
endfunc

" Blockwise range with ":{lnum}.{col}"
func Test_colrange_block_substitute()
  call s:Setup()
  1.6,3.9s/b/X/g
  call assert_equal(['aaaa XXXX cccc', 'aaaa XXXX cccc', 'aaaa XXXX cccc', 'xx'],
        \ getline(1, '$'))
  let &undolevels = &undolevels
  " "^" and "$" match at the start and end of the block
  2.6,3.9s/^X\|X$/-/g
  call assert_equal(['aaaa XXXX cccc', 'aaaa -XX- cccc', 'aaaa -XX- cccc', 'xx'],
        \ getline(1, '$'))
  " a command with a column range is undone in one step
  undo
  call assert_equal(['aaaa XXXX cccc', 'aaaa XXXX cccc', 'aaaa XXXX cccc', 'xx'],
        \ getline(1, '$'))
  undo
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  redo
  call assert_equal(['aaaa XXXX cccc', 'aaaa XXXX cccc', 'aaaa XXXX cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_block_delete_yank()
  call s:Setup()
  set nomodified
  let tick = b:changedtick
  1.6,3.9yank x
  call assert_equal("bbbb\nbbbb\nbbbb", getreg('x'))
  call assert_equal("\<C-V>4", getregtype('x'))
  " yanking does not change the buffer
  call assert_equal(tick, b:changedtick)
  call assert_false(&modified)
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))

  1.11,2.14delete
  call assert_equal(['aaaa bbbb ', 'aaaa bbbb ', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  call assert_equal("cccc\ncccc", getreg('"'))
  call assert_equal("\<C-V>4", getregtype('"'))
  " the blockwise register can be put as a block
  call cursor(1, 10)
  normal! p
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))

  " "_ register is not changed
  call setreg('"', 'keep', 'l')
  1.1,1.4delete _
  call assert_equal(" bbbb cccc", getline(1))
  call assert_equal("keep\n", getreg('"'))
  bwipe!
endfunc

func Test_colrange_dollar()
  call s:Setup()
  " ".$" is the end of each line
  1.11,4.$s/$/;/
  " the short line is padded to the start of the block
  call assert_equal(['aaaa bbbb cccc;', 'aaaa bbbb cccc;', 'aaaa bbbb cccc;',
        \ 'xx        ;'],
        \ getline(1, '$'))
  undo
  1.6,3.$delete
  call assert_equal(['aaaa ', 'aaaa ', 'aaaa ', 'xx'], getline(1, '$'))
  call assert_equal("\<C-V>9", getregtype('"'))
  bwipe!
endfunc

func Test_colrange_normal()
  call s:Setup()
  1.6,3.9normal! A!
  call assert_equal(['aaaa bbbb! cccc', 'aaaa bbbb! cccc', 'aaaa bbbb! cccc', 'xx'],
        \ getline(1, '$'))
  undo
  " a line that is too short is padded to the start of the block
  3.6,4.9normal! Iy
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa ybbbb cccc', 'xx   y'],
        \ getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_sort_join()
  new
  call setline(1, ['b 3 x', 'c 1 y', 'a 2 z'])
  1.3,3.3sort
  call assert_equal(['b 1 x', 'c 2 y', 'a 3 z'], getline(1, '$'))
  1.3,3.3sort!
  call assert_equal(['b 3 x', 'c 2 y', 'a 1 z'], getline(1, '$'))
  " joining leaves the other lines with the text outside the block
  1.1,3.3join
  call assert_equal(['b 3 c 2 a 1 x', ' y', ' z'], getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_more_lines()
  call s:Setup()
  " when the command adds lines they are added below the block
  1.6,2.9s/bb/&\r/
  call assert_equal(['aaaa bb cccc', 'aaaa bb cccc', '     bb', '     bb',
        \ 'aaaa bbbb cccc', 'xx'], getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_filter()
  CheckExecutable tr
  call s:Setup()
  2.6,3.9!tr b B
  call assert_equal(['aaaa bbbb cccc', 'aaaa BBBB cccc', 'aaaa BBBB cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_write()
  call s:Setup()
  set nomodified
  1.6,3.9write XColrangeWrite
  call assert_equal(['bbbb', 'bbbb', 'bbbb'], readfile('XColrangeWrite'))
  call assert_false(&modified)
  call delete('XColrangeWrite')
  bwipe!
endfunc

func Test_colrange_global()
  call s:Setup()
  call setline(2, 'aaaa bxbb cccc')
  1.6,3.9global/x/s/b/B/g
  call assert_equal(['aaaa bbbb cccc', 'aaaa BxBB cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  " "x" in column 1 is outside the block, not matched.  When deleting a line
  " in the block, the text in the block below it moves up.
  1.6,4.9global/x/d
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa  cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_user_command()
  call s:Setup()
  command -range Upper <line1>,<line2>s/.*/\U&/
  1.6,2.9Upper
  call assert_equal(['aaaa BBBB cccc', 'aaaa BBBB cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  delcommand Upper
  bwipe!
endfunc

func Test_colrange_tab()
  new
  setlocal tabstop=8 noexpandtab
  call setline(1, ["a\tb\tc", "1234567890123"])
  let &undolevels = &undolevels
  " the Tab is partly inside the block, it is split into spaces
  1.3,2.5s/ /X/g
  call assert_equal(["a XXX   b\tc", "1234567890123"], getline(1, '$'))
  undo
  " when the text in the block does not change the line is kept
  1.3,2.5s/3/#/
  call assert_equal(["a\tb\tc", "12#4567890123"], getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_multibyte()
  new
  call setline(1, ['äöü xyz', 'abc xyz', '日本語 xyz'])
  let &undolevels = &undolevels
  " screen columns, the double-width characters take two columns
  1.1,3.2s/./#/g
  call assert_equal(['##ü xyz', '##c xyz', '#本語 xyz'], getline(1, '$'))
  undo
  1.5,3.7delete
  call assert_equal(['äöü ', 'abc ', '日本xyz'], getline(1, '$'))
  undo
  " a double-width character partly inside the block is split into spaces
  1.4,3.6delete
  call assert_equal(['äöüz', 'abcz', '日  xyz'], getline(1, '$'))
  bwipe!
endfunc

" Characterwise range with "`x" marks
func Test_colrange_char()
  call s:Setup()
  call cursor(1, 6)
  normal! ma
  call cursor(3, 9)
  normal! mb
  `a,`bs/./#/g
  call assert_equal(['aaaa #########', '##############', '######### cccc', 'xx'],
        \ getline(1, '$'))
  undo
  `a,`bdelete
  call assert_equal(['aaaa  cccc', 'xx'], getline(1, '$'))
  call assert_equal("bbbb cccc\naaaa bbbb cccc\naaaa bbbb", getreg('"'))
  call assert_equal('v', getregtype('"'))
  undo
  " within one line
  call cursor(2, 6)
  normal! ma
  call cursor(2, 9)
  normal! mb
  `a,`bs/b/B/g
  call assert_equal(['aaaa bbbb cccc', 'aaaa BBBB cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  " a backwards range is swapped
  `b,`as/B/b/g
  call assert_equal('aaaa bbbb cccc', getline(2))
  " "'a,`b": from the start of the line
  'a,`bs/a/A/g
  call assert_equal('AAAA bbbb cccc', getline(2))
  bwipe!
endfunc

func Test_colrange_char_whole_buffer()
  new
  call setline(1, ['one', 'two'])
  call cursor(1, 1)
  normal! ma
  call cursor(2, 3)
  normal! mb
  `a,`bdelete
  call assert_equal([''], getline(1, '$'))
  call assert_equal("one\ntwo", getreg('"'))
  call assert_equal('v', getregtype('"'))
  bwipe!
endfunc

func Test_colrange_visual()
  call s:Setup()
  set history=10
  " without 'columnrange' ":" in Visual mode uses whole lines
  call assert_false(&columnrange)
  call feedkeys("1G6|\<C-V>2j3l:s/b/X/\<CR>", "xt")
  call assert_equal("'<,'>s/b/X/", histget(':', -1))
  call assert_equal(['aaaa Xbbb cccc', 'aaaa Xbbb cccc', 'aaaa Xbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo

  set columnrange
  call feedkeys("1G6|\<C-V>2j3l:s/b/X/g\<CR>", "xt")
  call assert_equal("`<,`>s/b/X/g", histget(':', -1))
  call assert_equal(['aaaa XXXX cccc', 'aaaa XXXX cccc', 'aaaa XXXX cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " block selected from the bottom right
  exe "normal! 3G9|\<C-V>2k3h:s/b/Y/g\<CR>"
  call assert_equal(['aaaa YYYY cccc', 'aaaa YYYY cccc', 'aaaa YYYY cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " block extended to the end of the line with "$"
  exe "normal! 1G11|\<C-V>j$:s/$/!/\<CR>"
  call assert_equal(['aaaa bbbb cccc!', 'aaaa bbbb cccc!', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " characterwise
  exe "normal! 1G11|v2G4|:s/[ac]/-/g\<CR>"
  call assert_equal(['aaaa bbbb ----', '---- bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " linewise
  call feedkeys("2GV:s/b/L/\<CR>", "xt")
  call assert_equal("'<,'>s/b/L/", histget(':', -1))
  call assert_equal('aaaa Lbbb cccc', getline(2))
  undo

  " "`<,`>" after "V" is linewise too
  exe "normal! 2GV\<Esc>"
  `<,`>s/a/A/g
  call assert_equal('AAAA bbbb cccc', getline(2))
  undo

  " a command modifier can follow "`<,`>"
  exe "normal! 1G6|\<C-V>2j3l:silent s/b/Z/g\<CR>"
  call assert_equal(['aaaa ZZZZ cccc', 'aaaa ZZZZ cccc', 'aaaa ZZZZ cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " the Visual area marks are kept after deleting the block
  exe "normal! 1G6|\<C-V>2j3l:d\<CR>"
  call assert_equal(['aaaa  cccc', 'aaaa  cccc', 'aaaa  cccc', 'xx'],
        \ getline(1, '$'))
  call assert_equal([1, 6], getpos("'<")[1:2])
  call assert_equal([3, 9], getpos("'>")[1:2])

  set columnrange& history&
  bwipe!
endfunc

func Test_colrange_selection_exclusive()
  call s:Setup()
  set selection=exclusive columnrange
  exe "normal! 1G6|\<C-V>2j4l:s/./-/g\<CR>"
  call assert_equal(['aaaa ---- cccc', 'aaaa ---- cccc', 'aaaa ---- cccc', 'xx'],
        \ getline(1, '$'))
  undo
  exe "normal! 1G6|v4l:s/./-/g\<CR>"
  call assert_equal('aaaa ---- cccc', getline(1))
  set selection& columnrange&
  bwipe!
endfunc

" A range without a command moves the cursor to the column.
func Test_colrange_cursor()
  call s:Setup()
  3.11
  call assert_equal([3, 11], getpos('.')[1:2])
  2.$
  call assert_equal([2, 14], getpos('.')[1:2])
  call cursor(1, 7)
  normal! ma
  4
  `a
  call assert_equal([1, 7], getpos('.')[1:2])

  " the cursor stays in the same position in the text
  call cursor(2, 8)
  1.6,3.9s/b/B/
  call assert_equal(3, line('.'))
  call cursor(2, 8)
  1.6,3.9yank
  call assert_equal([2, 8], getpos('.')[1:2])
  bwipe!
endfunc

func Test_colrange_no_change()
  call s:Setup()
  set nomodified
  let tick = b:changedtick
  let seq = undotree().seq_last
  1.6,3.9s/notfound//e
  1.6,3.9print
  call assert_equal(tick, b:changedtick)
  call assert_equal(seq, undotree().seq_last)
  call assert_false(&modified)
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

func Test_colrange_nomodifiable()
  call s:Setup()
  setlocal nomodifiable
  1.6,3.9yank
  call assert_equal("bbbb\nbbbb\nbbbb", getreg('"'))
  call assert_fails('1.6,3.9s/b/X/', 'E21:')
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  setlocal modifiable
  bwipe!
endfunc

func Test_colrange_errors()
  call s:Setup()
  call assert_fails('1.6,3.9move $', 'E1588:')
  call assert_fails('1.6,3.9copy $', 'E1588:')
  call assert_fails('1.6,3.9t $', 'E1588:')
  call assert_fails('1.0,3.9d', 'E16:')
  call assert_fails('1.6,9.9d', 'E16:')
  call assert_fails('1.6,3.9global/b/..1,..2d', 'E1589:')
  call assert_fails('`z,`zd', 'E20:')
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

def Test_colrange_vim9()
  new
  setline(1, ['aaaa bbbb', 'aaaa bbbb'])
  :1.6,2.9s/b/X/g
  assert_equal(['aaaa XXXX', 'aaaa XXXX'], getline(1, '$'))
  :2.3
  assert_equal([2, 3], getpos('.')[1 : 2])
  assert_fails(':1.0', 'E16:')
  bwipe!
enddef

" When the command reloads the buffer the text is not put back.
func Test_colrange_reload()
  call writefile(['aaaa bbbb', 'aaaa bbbb'], 'XColrangeReload', 'D')
  edit XColrangeReload
  call setline(1, 'changed')
  exe "1.6,2.9normal :e!\<CR>"
  call assert_equal(['aaaa bbbb', 'aaaa bbbb'], getline(1, '$'))
  bwipe!
endfunc

" Existing ranges are not changed.
func Test_colrange_compatible()
  call s:Setup()
  call setline(1, range(1, 10))
  2
  " ".2" is still ".+2"
  .2d
  call assert_equal(['1', '2', '3', '5', '6', '7', '8', '9', '10'], getline(1, '$'))
  2;.3d
  call assert_equal(['1', '7', '8', '9', '10'], getline(1, '$'))
  call cursor(3, 1)
  normal! ma
  'a,'a+1d
  call assert_equal(['1', '7', '10'], getline(1, '$'))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
