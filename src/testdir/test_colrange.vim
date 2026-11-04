" Tests for Ex commands with a column range: ":{lnum}.{col}" and ":`x".
" See ":help :range-col".

import './util/vim9.vim' as v9

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

" An address without a column starts in the first column or ends at the end
" of the line.  The columns and lines can be given in any order.
func Test_colrange_block_partial()
  call s:Setup()
  1,3.5s/./-/g
  call assert_equal(['-----bbbb cccc', '-----bbbb cccc', '-----bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo
  1.11,3s/./-/g
  call assert_equal(['aaaa bbbb ----', 'aaaa bbbb ----', 'aaaa bbbb ----', 'xx'],
        \ getline(1, '$'))
  undo
  1.9,3.6s/./-/g
  call assert_equal(['aaaa ---- cccc', 'aaaa ---- cccc', 'aaaa ---- cccc', 'xx'],
        \ getline(1, '$'))
  undo
  silent 3.9,1.6s/./-/g
  call assert_equal(['aaaa ---- cccc', 'aaaa ---- cccc', 'aaaa ---- cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

" With one address the block is one column wide, also with a count.
func Test_colrange_block_one_column()
  call s:Setup()
  2.6d
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  call assert_equal(['b'], getreg('"', 1, 1))
  undo
  " the count starts at the last address and uses its column
  1.6,1.10d 3
  call assert_equal(['aaaa bbbbcccc', 'aaaa bbbbcccc', 'aaaa bbbbcccc', 'xx'],
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

  " a mark in a line of the block is kept
  call cursor(2, 3)
  normal! mc
  1.11,2.14delete
  call assert_equal(['aaaa bbbb ', 'aaaa bbbb ', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  call assert_equal([2, 3], getpos("'c")[1 : 2])
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

  " appending to a register works like with a Visual block
  exe "normal! 2G6|\<C-V>3l\"xy3G11|\<C-V>3l\"Xy"
  let expected = [getreg('x', 1, 1), getregtype('x')]
  2.6,2.9yank x
  3.11,3.14yank X
  call assert_equal(expected, [getreg('x', 1, 1), getregtype('x')])

  " deleting all the text in all lines keeps the empty lines
  1.1,$.$delete
  call assert_equal(['', '', '', ''], getline(1, '$'))
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
  defer delete('XColrangeWrite')
  call assert_equal(['bbbb', 'bbbb', 'bbbb'], readfile('XColrangeWrite'))
  call assert_false(&modified)
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
  undo
  " the Tab starts inside the block and ends after it
  1.1,2.3s/./-/g
  call assert_equal(["---     b\tc", "---4567890123"], getline(1, '$'))
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
  undo
  1.1,3.3delete
  call assert_equal([' xyz', ' xyz', ' 語 xyz'], getline(1, '$'))
  bwipe!
endfunc

" "`x" combined with "{address}.{col}" is blockwise and uses the screen
" column of the mark.
func Test_colrange_block_mark()
  new
  call setline(1, ["\tbbbb", '        bbbb'])
  call cursor(1, 2)
  normal! ma
  `a,2.12s/b/X/g
  call assert_equal(["\tXXXX", '        XXXX'], getline(1, '$'))
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
  " "`a,3": up to the end of the line
  `a,3s/[bc]/-/g
  call assert_equal(['aaaa bbbb cccc', 'AAAA ---- ----', 'aaaa ---- ----', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

" When the command adds or deletes lines the text after the range goes with the
" last line.
func Test_colrange_char_lines()
  call s:Setup()
  call cursor(1, 6)
  normal! ma
  call cursor(2, 9)
  normal! mb
  `a,`bs/ /\r/g
  call assert_equal(['aaaa bbbb', 'cccc', 'aaaa', 'bbbb cccc', 'aaaa bbbb cccc',
        \ 'xx'], getline(1, '$'))
  undo
  `a,`bglobal/^aaaa/d
  call assert_equal(['aaaa bbbb cccc cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
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
  " without 'columnrange' ":" in Visual mode uses whole lines
  call assert_false(&columnrange)
  call feedkeys("1G6|\<C-V>2j3l:s/b/X/\<CR>", 'xt')
  call assert_equal("'<,'>s/b/X/", @:)
  call assert_equal(['aaaa Xbbb cccc', 'aaaa Xbbb cccc', 'aaaa Xbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo

  set columnrange
  call feedkeys("1G6|\<C-V>2j3l:s/b/X/g\<CR>", 'xt')
  call assert_equal("`<,`>s/b/X/g", @:)
  call assert_equal(['aaaa XXXX cccc', 'aaaa XXXX cccc', 'aaaa XXXX cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " block selected from the bottom right
  call feedkeys("3G9|\<C-V>2k3h:s/b/Y/g\<CR>", "xt")
  call assert_equal(['aaaa YYYY cccc', 'aaaa YYYY cccc', 'aaaa YYYY cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " block selected from the top right
  call feedkeys("1G9|\<C-V>2j3h:s/b/Y/g\<CR>", "xt")
  call assert_equal(['aaaa YYYY cccc', 'aaaa YYYY cccc', 'aaaa YYYY cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " block extended to the end of the line with "$"
  call feedkeys("1G11|\<C-V>j$:s/$/!/\<CR>", "xt")
  call assert_equal(['aaaa bbbb cccc!', 'aaaa bbbb cccc!', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " characterwise
  call feedkeys("1G11|v2G4|:s/[ac]/-/g\<CR>", "xt")
  call assert_equal(['aaaa bbbb ----', '---- bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " linewise
  call feedkeys("2GV:s/b/L/\<CR>", 'xt')
  call assert_equal("'<,'>s/b/L/", @:)
  call assert_equal('aaaa Lbbb cccc', getline(2))
  undo

  " "`<,`>" after "V" is linewise too
  exe "normal! 2GV\<Esc>"
  `<,`>s/a/A/g
  call assert_equal('AAAA bbbb cccc', getline(2))
  undo

  " a command modifier can follow "`<,`>"
  call feedkeys("1G6|\<C-V>2j3l:silent s/b/Z/g\<CR>", "xt")
  call assert_equal(['aaaa ZZZZ cccc', 'aaaa ZZZZ cccc', 'aaaa ZZZZ cccc', 'xx'],
        \ getline(1, '$'))
  undo

  " the Visual area marks are kept after deleting the block
  call feedkeys("1G6|\<C-V>2j3l:d\<CR>", "xt")
  call assert_equal(['aaaa  cccc', 'aaaa  cccc', 'aaaa  cccc', 'xx'],
        \ getline(1, '$'))
  call assert_equal([1, 6], getpos("'<")[1:2])
  call assert_equal([3, 9], getpos("'>")[1:2])

  set columnrange&
  bwipe!
endfunc

func Test_colrange_selection_exclusive()
  call s:Setup()
  set selection=exclusive columnrange
  call feedkeys("1G6|\<C-V>2j4l:s/./-/g\<CR>", "xt")
  call assert_equal(['aaaa ---- cccc', 'aaaa ---- cccc', 'aaaa ---- cccc', 'xx'],
        \ getline(1, '$'))
  undo
  call feedkeys("1G6|v4l:s/./-/g\<CR>", "xt")
  call assert_equal('aaaa ---- cccc', getline(1))
  undo
  " ending in the first column the line break is not included
  call feedkeys("1G6|vj0:s/./-/g\<CR>", "xt")
  call assert_equal(['aaaa ---------', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
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

  " :substitute moves the cursor to the start of the block in the last line
  call cursor(2, 8)
  1.6,3.9s/b/B/
  call assert_equal([3, 6], getpos('.')[1:2])
  " the cursor stays in the same position in the text
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
  call assert_fails('1.99999999999,3.9d', 'E16:')
  call assert_fails('1.6,9.9d', 'E16:')
  call assert_fails('1.6,3.9global/b/..1,..2d', 'E1589:')
  call assert_fails('`z,`zd', 'E20:')
  call assert_fails('`a,`abdelete', 'E16:')
  " a mark in another buffer cannot be used
  call cursor(2, 6)
  normal! mA
  new
  call assert_fails('`A,`Ad', 'E20:')
  bwipe!
  delmarks A
  " no error when skipped
  if 0
    `z,`zd
    1.99999999999d
  endif
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
  assert_fails(':1.99999999999', 'E16:')
  :1.6
  normal! ma
  :2
  :`a
  assert_equal([1, 6], getpos('.')[1 : 2])
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

" When the command makes another buffer current the text is put back in the
" buffer of the range.
func Test_colrange_other_buffer()
  call s:Setup()
  setlocal bufhidden=hide
  let buf = bufnr()
  exe "1.6,1.9normal! rX:enew\<CR>"
  call assert_notequal(buf, bufnr())
  call assert_equal(['aaaa Xbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getbufline(buf, 1, '$'))
  bwipe!
  exe 'bwipe! ' .. buf
endfunc

func Test_colrange_cmdline_complete()
  call feedkeys(":`<,`>sub\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"`<,`>substitute', @:)
  call feedkeys(":1.6,$.$norm\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"1.6,$.$normal', @:)
endfunc

" Existing ranges are not changed.
func Test_colrange_compatible()
  new
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

" With 'selection' "exclusive" a Visual area of one character is used.
func Test_colrange_selection_exclusive_one_char()
  call s:Setup()
  set selection=exclusive columnrange
  call feedkeys("1G6|v:s/./-/g\<CR>", 'xt')
  call assert_equal('aaaa -bbb cccc', getline(1))
  set selection& columnrange&
  bwipe!
endfunc

" 'columnrange' is only used when ":" is typed, not for a mapping, :normal or
" another operator using a range.
func Test_colrange_option_typed_only()
  call s:Setup()
  set columnrange
  xnoremap <buffer> ,s :s/b/M/<CR>
  exe "normal 1G6|\<C-V>j3l,s"
  call assert_equal(['aaaa Mbbb cccc', 'aaaa Mbbb cccc'], getline(1, 2))
  undo
  exe "normal! 1G6|\<C-V>j3l:s/b/N/\<CR>"
  call assert_equal(['aaaa Nbbb cccc', 'aaaa Nbbb cccc'], getline(1, 2))
  set columnrange&
  bwipe!
endfunc

" Commands that put text above the range or get text from elsewhere.
func Test_colrange_unsupported()
  call s:Setup()
  call setreg('x', ['P1'], 'l')
  call assert_fails('2.6put! x', 'E1588:')
  call assert_fails('2.6,2.9insert', 'E1588:')
  " ":put" below the range adds a line in the block
  2.6put x
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', '     P1',
        \ 'aaaa bbbb cccc', 'xx'], getline(1, '$'))
  bwipe!

  CheckFeature diff
  call s:Setup()
  let buf = bufnr()
  diffthis
  call s:Setup()
  call setline(1, ['zzzz yyyy cccc', 'zzzz yyyy cccc'])
  diffthis
  call assert_fails('1.6,2.9diffput', 'E1588:')
  call assert_fails('1.6,2.9diffget', 'E1588:')
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getbufline(buf, 1, '$'))
  diffoff!
  bwipe!
  exe 'bwipe! ' .. buf
endfunc

" When a mark is in a closed fold the whole fold is used, not the column.
func Test_colrange_char_closed_fold()
  call s:Setup()
  call cursor(3, 6)
  normal! ma
  call cursor(4, 2)
  normal! mb
  2,3fold
  `a,`bs/./-/g
  call assert_equal(['aaaa bbbb cccc', '--------------', '--------------', '--'],
        \ getline(1, '$'))
  bwipe!
endfunc

def Test_colrange_vim9_put()
  new
  setline(1, ['aaaa bbbb'])
  setreg('x', ['P1'], 'l')
  v9.CheckDefFailure([':1.6put x'], 'E1588:')
  v9.CheckDefFailure([':`aput x'], 'E1588:')
  # ".0" is not a column
  v9.CheckDefSuccess([':1.0put x'])
  bwipe!
enddef

" "\%V" matches the text in the range, a match cannot continue below it.
func Test_colrange_pattern()
  call s:Setup()
  1.6,2.9s/\%Vb/V/g
  call assert_equal(['aaaa VVVV cccc', 'aaaa VVVV cccc'], getline(1, 2))
  undo
  " "\n" does not match at the end of the last line in the range
  call cursor(1, 6)
  normal! ma
  call cursor(2, 9)
  normal! mb
  `a,`bs/\n/ /
  " at the end of the range like at the end of the buffer: no join
  call assert_equal(['aaaa bbbb cccc aaaa bbbb  cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo
  1.6,2.9s/\n/ /
  call assert_equal(['aaaa bbbb bbbb  cccc', 'aaaa  cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  undo
  `a,`bs/\_.*/Y/
  call assert_equal(['aaaa Y cccc', 'aaaa bbbb cccc', 'xx'], getline(1, '$'))
  bwipe!
endfunc

" Lines inserted or deleted above or below the range.
func Test_colrange_lines_outside()
  call s:Setup()
  exe "3.6,3.9normal! ggddGo\<Esc>"
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx', ''],
        \ getline(1, '$'))
  undo
  " deleting the line just above the range: text is not put back
  call assert_fails('2.6,3.9normal! kdd', 'E1590:')
  undo
  call assert_equal(['aaaa bbbb cccc', 'aaaa bbbb cccc', 'aaaa bbbb cccc', 'xx'],
        \ getline(1, '$'))
  bwipe!
endfunc

" ":delete" and ":yank" into a named register, TextYankPost sees the type.
func Test_colrange_register_type()
  call s:Setup()
  let g:regtypes = []
  autocmd TextYankPost * call add(g:regtypes, v:event.regtype)
  1.6,2.9delete x
  call assert_equal("\<C-V>4", getregtype('x'))
  call assert_equal("\<C-V>4", getregtype('1'))
  call setpos("'a", [0, 1, 6, 0])
  call setpos("'b", [0, 2, 3, 0])
  `a,`byank y
  call assert_equal('v', getregtype('y'))
  call assert_equal(["\<C-V>4", 'v'], g:regtypes)
  autocmd! TextYankPost
  unlet g:regtypes
  bwipe!
endfunc

" Blockwise ":>" works like "v_>": the shift starts at the block.
func Test_colrange_shift_tab()
  new
  setlocal noexpandtab shiftwidth=8 tabstop=8
  call setline(1, ['abcdef ghi', 'abcdef ghi'])
  let &undolevels = &undolevels
  exe "normal! 1G7|\<C-V>j3l>"
  let expected = getline(1, '$')
  undo
  1.7,2.10>
  call assert_equal(expected, getline(1, '$'))
  let &undolevels = &undolevels
  exe "normal! 1G7|\<C-V>j<"
  let expected = getline(1, '$')
  undo
  1.7,2.7<
  call assert_equal(expected, getline(1, '$'))
  bwipe!
endfunc

" Visual block extending past the end of a line with 'virtualedit' "block".
func Test_colrange_virtualedit_block()
  new
  call setline(1, ['short', 'a much longer line', 'mid line'])
  let &undolevels = &undolevels
  set virtualedit=block columnrange
  exe "normal! 1G0\<C-V>2j15ld"
  let expected = getline(1, '$')
  undo
  call feedkeys("1G0\<C-V>2j15l:d\<CR>", 'xt')
  call assert_equal(expected, getline(1, '$'))
  call assert_equal(['', 'ne', ''], getline(1, '$'))
  set virtualedit& columnrange&
  bwipe!
endfunc

" The cursor column is remembered for moving up and down.
func Test_colrange_curswant()
  call s:Setup()
  call cursor(2, 1)
  1.6,2.9normal! IXY
  call assert_equal([2, 7], getpos('.')[1:2])
  normal! k
  call assert_equal([1, 7], getpos('.')[1:2])
  bwipe!
endfunc

" Commands that get a line before saving it for undo must not see the line
" being changed.  Used to be a use-after-free.
func Test_colrange_line_pointer()
  new
  setlocal expandtab
  call setline(1, ["abc\tdef\tghi"])
  1.1,1.$retab
  call assert_equal('abc     def     ghi', getline(1))
  call setline(1, ['aaaa bbbb cccc', 'aaaa bbbb cccc'])
  setlocal foldmethod=marker
  1.6,1.9normal! zf$
  call assert_equal('aaaa bbbb/* {{{ *//* }}} */ cccc', getline(1))
  bwipe!
endfunc

" The Visual area end is after the end of the line that got shorter.
" Used to read before the start of the line.
func Test_colrange_selection_exclusive_short_line()
  new
  set selection=exclusive
  call setline(1, ['abcdef', 'ghijkl'])
  exe "normal! gg0vj3l\<Esc>"
  call setline(2, '')
  `<,`>yank z
  call assert_equal(['abcdef', 'v'], [getreg('z'), getregtype('z')])
  set selection&
  bwipe!
endfunc

" Undo while the lines are narrowed would make a mess.
func Test_colrange_no_undo_inside()
  call s:Setup()
  call assert_fails('1.6,2.9normal! xu', 'E1591:')
  call assert_equal(['aaaa bbb cccc', 'aaaa bbb cccc'], getline(1, 2))
  bwipe!
endfunc

" ":join" with one address joins with the next line.
func Test_colrange_join_one_line()
  call s:Setup()
  " one address is one column
  1.6join
  call assert_equal(['aaaa b bbbb cccc', 'aaaa bbb cccc', 'aaaa bbbb cccc'],
        \ getline(1, 3))
  " like ":1,1join" does nothing
  1.6,1.9join
  call assert_equal('aaaa b bbbb cccc', getline(1))
  bwipe!
endfunc

" The width of a blockwise register for "$" is like with a Visual block.
func Test_colrange_register_width_dollar()
  new
  call setline(1, ["abc\tx", 'abcdefgh'])
  exe "normal! 1G2|\<C-V>j$y"
  let expected = [getreg('"'), getregtype('"')]
  1.2,2.$yank
  call assert_equal(expected, [getreg('"'), getregtype('"')])
  bwipe!
endfunc

" Text properties in lines where the text in the range is not changed are
" kept.
func Test_colrange_textprop_kept()
  CheckFeature textprop
  call s:Setup()
  call prop_type_add('colrange', {})
  call prop_add(2, 6, {'type': 'colrange', 'length': 4})
  1.6,2.9s/xxx/y/e
  1.6,2.9s/^\%1lb/B/
  call assert_equal('aaaa Bbbb cccc', getline(1))
  call assert_equal([{'id': 0, 'col': 6, 'type_bufnr': 0, 'end': 1,
        \ 'type': 'colrange', 'length': 4, 'start': 1}], prop_list(2))
  call prop_type_delete('colrange')
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
