"=============================================================================
" FILE: autoload/incsearch.vim
" AUTHOR: haya14busa
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================
scriptencoding utf-8
" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

let s:TRUE = !0
let s:FALSE = 0

" Option:
let g:incsearch#emacs_like_keymap = get(g:, 'incsearch#emacs_like_keymap', s:FALSE)
let g:incsearch#highlight = get(g:, 'incsearch#highlight', {})
let g:incsearch#separate_highlight = get(g:, 'incsearch#separate_highlight', s:FALSE)


let s:V = vital#of('incsearch')

" Highlight: {{{
let s:hi = s:V.import("Coaster.Highlight").make()

function! s:init_hl()
    hi link IncSearchMatch IncSearch
    hi link IncSearchMatchReverse Search
    hi link IncSearchCursor Cursor
    hi link IncSearchOnCursor IncSearch
    hi IncSearchUnderline term=underline cterm=underline gui=underline
endfunction
call s:init_hl()
augroup plugin-incsearch-highlight
    autocmd!
    autocmd ColorScheme * call s:init_hl()
augroup END

let s:default_highlight = {
\   'visual' : {
\       'group'    : 'IncSearchVisual',
\       'priority' : '10'
\   },
\   'match' : {
\       'group'    : 'IncSearchMatch',
\       'priority' : '49'
\   },
\   'match_reverse' : {
\       'group'    : 'IncSearchMatchReverse',
\       'priority' : '49'
\   },
\   'on_cursor' : {
\       'group'    : 'IncSearchOnCursor',
\       'priority' : '50'
\   },
\   'cursor' : {
\       'group'    : 'IncSearchCursor',
\       'priority' : '51'
\   },
\ }
function! s:hgm() " highlight group management
    let hgm = copy(s:default_highlight)
    for key in keys(hgm)
        call extend(hgm[key], get(g:incsearch#highlight, key, {}))
    endfor
    return hgm
endfunction

function! s:update_hl()
    call s:hi.disable_all()
    call s:hi.enable_all()
endfunction

"}}}

" CommandLine Interface: {{{
let s:cli = s:V.import('Over.Commandline').make_default("/")
let s:modules = s:V.import('Over.Commandline.Modules')

" Add modules
call s:cli.connect('BufferComplete')
call s:cli.connect('Cancel')
call s:cli.connect('CursorMove')
call s:cli.connect('Delete')
call s:cli.connect('DrawCommandline')
call s:cli.connect('ExceptionExit')
call s:cli.connect('Exit')
call s:cli.connect('InsertRegister')
call s:cli.connect('Paste')
" XXX: better handling.
if expand("%:p") !=# expand("<sfile>:p")
    call s:cli.connect(s:modules.get('Doautocmd').make('IncSearch'))
endif
call s:cli.connect(s:modules.get('ExceptionMessage').make('incsearch.vim: ', 'echom'))
call s:cli.connect(s:modules.get('History').make('/'))
call s:cli.connect(s:modules.get('NoInsert').make_special_chars())
if g:incsearch#emacs_like_keymap
    call s:cli.connect(s:modules.get('KeyMapping').make_emacs())
endif


function! s:cli.keymapping()
    return extend({
\       "\<CR>"   : {
\           "key" : "<Over>(exit)",
\           "noremap" : 1,
\           "lock" : 1,
\       },
\       "\<Tab>"   : {
\           "key" : "<Over>(incsearch-next)",
\           "noremap" : 1,
\       },
\       "\<S-Tab>"   : {
\           "key" : "<Over>(incsearch-prev)",
\           "noremap" : 1,
\       },
\       "\<C-j>"   : {
\           "key" : "<Over>(incsearch-scroll-f)",
\           "noremap" : 1,
\       },
\       "\<C-k>"   : {
\           "key" : "<Over>(incsearch-scroll-b)",
\           "noremap" : 1,
\       },
\       "\<C-l>"   : {
\           "key" : "<Over>(buffer-complete)",
\           "noremap" : 1,
\       },
\   }, g:incsearch_cli_key_mappings)
endfunction

let s:inc = {
\   "name" : "incsearch",
\}

function! s:inc.on_enter(cmdline)
    nohlsearch " disable previous highlight
    let s:w = winsaveview()
    let hgm = s:hgm()
    let c = hgm.cursor
    call s:hi.add(c.group, c.group, '\%#', c.priority)
    call s:update_hl()
endfunction

function! s:inc.on_leave(cmdline)
    call s:hi.disable_all()
    call s:hi.delete_all()
    " redraw: hide pseud-cursor
    echo | redraw
    if s:cli.getline() !=# ''
        echo s:cli.get_prompt() . s:cli.getline()
    endif
endfunction

function! s:inc.get_pattern()
    " get `pattern` and ignore {offset}
    let [pattern, flags] = incsearch#parse_pattern(s:cli.getline(), s:cli.get_prompt())
    return pattern
endfunction

function! s:inc.on_char_pre(cmdline)
    if a:cmdline.is_input("<Over>(incsearch-next)")
        if a:cmdline.flag ==# 'n' " exit stay mode
            let s:cli.flag = ''
        else
            let s:cli.vcount1 += 1
        endif
        call a:cmdline.setchar('')
    elseif a:cmdline.is_input("<Over>(incsearch-prev)")
        if a:cmdline.flag ==# 'n' " exit stay mode
            let s:cli.flag = ''
        endif
        let s:cli.vcount1 -= 1
        if s:cli.vcount1 < 1
            let pattern = s:inc.get_pattern()
            let s:cli.vcount1 += s:count_pattern(pattern)
        endif
        call a:cmdline.setchar('')
    elseif a:cmdline.is_input("<Over>(incsearch-scroll-f)")
        if a:cmdline.flag ==# 'n' | let s:cli.flag = '' | endif
        let pattern = s:inc.get_pattern()
        let from = getpos('.')[1:2]
        let to = [line('w$'), s:get_max_col('w$')]
        let cnt = s:count_pattern(pattern, from, to)
        let s:cli.vcount1 += cnt
        call a:cmdline.setchar('')
    elseif a:cmdline.is_input("<Over>(incsearch-scroll-b)")
        if a:cmdline.flag ==# 'n' | let s:cli.flag = '' | endif
        let pattern = s:inc.get_pattern()
        let from = [line('w0'), 1]
        let to = getpos('.')[1:2]
        let cnt = s:count_pattern(pattern, from, to)
        let s:cli.vcount1 -= cnt
        if s:cli.vcount1 < 1
            let s:cli.vcount1 += s:count_pattern(pattern)
        endif
        call a:cmdline.setchar('')
    endif
endfunction

function! s:inc.on_char(cmdline)
    try
        call winrestview(s:w)
        let pattern = s:inc.get_pattern()

        if pattern ==# ''
            call s:hi.disable_all()
            return
        endif

        let pattern = incsearch#convert_with_case(pattern)

        " pseud-move cursor position: this is restored afterward if called by
        " <expr> mappings
        for _ in range(s:cli.vcount1)
            call search(pattern, a:cmdline.flag)
        endfor
        let hgm = s:hgm()
        let m = hgm.match
        let r = hgm.match_reverse
        let o = hgm.on_cursor
        let c = hgm.cursor
        let on_cursor_pattern = '\M\%#\(' . pattern . '\M\)'
        let forward_pattern = s:forward_pattern(pattern, s:w.lnum, s:w.col)
        let backward_pattern = s:backward_pattern(pattern, s:w.lnum, s:w.col)

        " Highlight
        if g:incsearch#separate_highlight == s:FALSE || s:cli.flag == 'n'
            call s:hi.add(m.group , m.group , pattern          , m.priority)
        elseif s:cli.flag == '' " forward
            call s:hi.add(m.group , m.group , forward_pattern  , m.priority)
            call s:hi.add(r.group , r.group , backward_pattern , r.priority)
        elseif s:cli.flag == 'b' " backward
            call s:hi.add(m.group , m.group , backward_pattern , m.priority)
            call s:hi.add(r.group , r.group , forward_pattern  , r.priority)
        endif
        call s:hi.add(o.group , o.group , on_cursor_pattern , o.priority)
        call s:hi.add(c.group , c.group , '\v%#'            , c.priority)
        call s:update_hl()
    catch /E53:/ " E53: Unmatched %(
    catch /E54:/
    catch /E55:/
    catch /E867:/ " E867: (NFA) Unknown operator
        call s:hi.disable_all()
    catch
        echohl ErrorMsg | echom v:throwpoint . " " . v:exception | echohl None
    endtry
endfunction

call s:cli.connect(s:inc)
"}}}

" Main: {{{

function! incsearch#forward()
    return s:search('/')
endfunction

function! incsearch#backward()
    return s:search('?')
endfunction

" similar to incsearch#forward() but do not move the cursor unless explicitly
" move the cursor while searching
function! incsearch#stay()
    let m = mode(1)
    let pattern = s:get_pattern('', m)
    if s:cli.flag ==# 'n' " stay
        call histadd('/', pattern)
        let @/ = pattern
        return (m =~# "[vV\<C-v>]") ? '\<ESC>gv' : "\<ESC>"
    else " exit stay mode
        return s:generate_command(m, pattern, '/') " assume '/'
    endif
endfunction

function! s:search(search_key)
    let m = mode(1)
    let pattern = s:get_pattern(a:search_key, m)
    return s:generate_command(m, pattern, a:search_key)
endfunction

function! s:get_pattern(search_key, mode)
    " if search_key is empty, it means `stay` & do not move cursor
    let s:cli.vcount1 = v:count1
    let prompt = a:search_key ==# '' ? '/' : a:search_key
    call s:cli.set_prompt(prompt)
    let s:cli.flag = a:search_key ==# '/' ? ''
    \              : a:search_key ==# '?' ? 'b'
    \              : a:search_key ==# ''  ? 'n'
    \              : ''

    " Handle visual mode highlight
    if (a:mode =~# "[vV\<C-v>]")
        let visual_hl = s:highlight_capture('Visual')
        try
            call s:turn_off(visual_hl)
            call s:pseud_visual_highlight(visual_hl, a:mode)
            let pattern = s:cli.get()
        finally
            call s:turn_on(visual_hl)
        endtry
    else
        let pattern = s:cli.get()
    endif
    return pattern
endfunction

function! s:generate_command(mode, pattern, search_key)
    let op = (a:mode == 'no')          ? v:operator
    \      : (a:mode =~# "[vV\<C-v>]") ? 'gv'
    \      : ''
    if (s:cli.exit_code() == 0)
        call s:cli.callevent('on_execute_pre')
        return "\<ESC>" . op . s:cli.vcount1 . a:search_key . a:pattern . "\<CR>"
    else " Cancel
        return (a:mode =~# "[vV\<C-v>]") ? '\<ESC>gv' : "\<ESC>"
    endif
endfunction

"}}}

" Helper: {{{
function! incsearch#parse_pattern(expr, search_key)
    " search_key : '/' or '?'
    " expr       : /{pattern\/pattern}/{offset}
    " return     : [{pattern\/pattern}, {offset}]
    let very_magic = '\v'
    let pattern  = '(%(\\.|.){-})'
    let slash = '(\' . a:search_key . '&[^\\"|[:alnum:][:blank:]])'
    let offset = '(.*)'

    let parse_pattern = very_magic . pattern . '%(' . slash . offset . ')?$'
    let result = matchlist(a:expr, parse_pattern)[1:3]
    if type(result) == type(0) || empty(result)
        return []
    endif
    unlet result[1]
    return result
endfunction

function! incsearch#convert_with_case(pattern)
    if &ignorecase == s:FALSE
        return '\C' . a:pattern " noignorecase
    endif

    if &smartcase == s:FALSE
        return '\c' . a:pattern " ignorecase & nosmartcase
    endif

    " Find uppercase letter which isn't escaped
    let very_magic = '\v'
    let escaped_backslash = '%(^|[^\\])%(\\\\)*'
    if a:pattern =~# very_magic . escaped_backslash . '[A-Z]'
        return '\C' . a:pattern " smartcase with [A-Z]
    else
        return '\c' . a:pattern " smartcase without [A-Z]
    endif
endfunction

function! s:highlight_capture(hlname) "{{{
    " Based On: https://github.com/t9md/vim-ezbar
    "           https://github.com/osyo-manga/vital-over
    let hlname = a:hlname
    if !hlexists(hlname)
        return
    endif
    while 1
        let save_verbose = &verbose
        let &verbose = 0
        try
            redir => HL_SAVE
            execute 'silent! highlight ' . hlname
            redir END
        finally
            let &verbose = save_verbose
        endtry
        if !empty(matchstr(HL_SAVE, 'xxx cleared$'))
            return ''
        endif
        " follow highlight link
        let ml = matchlist(HL_SAVE, 'links to \zs.*')
        if !empty(ml)
            let hlname = ml[0]
            continue
        endif
        break
    endwhile
    let HL_SAVE = substitute(matchstr(HL_SAVE, 'xxx \zs.*'),
                           \ '[ \t\n]\+', ' ', 'g')
    return { 'name': hlname, 'highlight': HL_SAVE }
endfunction "}}}

function! s:turn_off(highlight)
    execute 'highlight' a:highlight.name 'NONE'
endfunction

function! s:turn_on(highlight)
    execute 'highlight' a:highlight.name a:highlight.highlight
endfunction

function! s:pseud_visual_highlight(visual_hl, mode)
    let pattern = s:get_visual_pattern_by_range(a:mode)
    let hgm = s:hgm()
    let v = hgm.visual
    execute 'hi IncSearchVisual' a:visual_hl.highlight
    call s:hi.add(v.group, v.group, pattern, v.priority)
    call s:update_hl()
endfunction

function! s:get_visual_pattern_by_range(mode)
    let v_start = [line("v"),col("v")] " visual_start_position
    let v_end   = [line("."),col(".")] " visual_end_position
    if s:is_pos_less_equal(v_end, v_start)
        " swap position
        let [v_end, v_start] = [v_start, v_end]
    endif
    if a:mode ==# 'v'
        return printf('\v%%%dl%%%dc\_.*%%%dl%%%dc',
        \              v_start[0], v_start[1], v_end[0], v_end[1])
    elseif a:mode ==# 'V'
        return printf('\v%%%dl\_.*%%%dl', v_start[0], v_end[0])
    elseif a:mode ==# "\<C-v>"
        let [min_c, max_c] = sort([v_start[1], v_end[1]])
        return '\v'.join(map(range(v_start[0], v_end[0]), '
        \               printf("%%%dl%%%dc.*%%%dc",
        \                      v:val, min_c, min([max_c, len(getline(v:val))]))
        \      '), "|")
    else " Error: unexpected mode
        " TODO: error handling
        return ''
    endif
endfunction

" return (x <= y)
function! s:is_pos_less_equal(x, y)
    return (a:x[0] == a:y[0]) ? a:x[1] <= a:y[1] : a:x[0] < a:y[0]
endfunction

function! s:forward_pattern(pattern, line, col)
    let forward_line = printf('%%>%dl', a:line)
    let current_line = printf('%%%dl%%>%dc', a:line, a:col)
    return '\v(' . forward_line . '|' . current_line . ')\M\(' . a:pattern . '\M\)'
endfunction

function! s:backward_pattern(pattern, line, col)
    let backward_line = printf('%%<%dl', a:line)
    let current_line = printf('%%%dl%%<%dc', a:line, a:col)
    return '\v(' . backward_line . '|' . current_line . ')\M\(' . a:pattern . '\M\)'
endfunction

" Return the number of matched patterns in the current buffer or the specified
" region with `from` and `to` positions
" parameter: pattern, from, to
function! s:count_pattern(pattern, ...)
    let w = winsaveview()
    let from = get(a:, 1, [1, 1])
    let to   = get(a:, 2, [line('$'), s:get_max_col('$')])
    call cursor(from)
    let cnt = 0
    try
        " first: accept a match at the cursor position
        let pos = searchpos(a:pattern, 'cW')
        while (pos != [0, 0] && s:is_pos_less_equal(pos, to))
            let cnt += 1
            let pos = searchpos(a:pattern, 'W')
        endwhile
    finally
        call winrestview(w)
    endtry
    return cnt
endfunction

" Return max column number of given line expression
" expr: similar to line(), col()
function! s:get_max_col(expr)
    return strlen(getline(a:expr)) + 1
endfunction

"}}}

" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
unlet s:save_cpo
" }}}
" __END__  {{{
" vim: expandtab softtabstop=4 shiftwidth=4
" vim: foldmethod=marker
" }}}
