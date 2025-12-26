" llm-session.vim - Interactive LLM session in a special buffer
" Maintainer: Hugo & AI
" Version: 1.2
"
" Usage:
"   <Leader>u  - Toggle session buffer
"   q          - Close session (in normal mode)
"   <CR>       - Submit input (in normal mode, on input line)
"   i/a/o      - Start typing
"
" Configuration:
"   let g:llm_session_command = 'llm'        " or 'claude -p'
"   let g:llm_session_position = 'bottom'    " bottom/top/left/right
"   let g:llm_session_size = 40              " percentage
"   let g:llm_session_base_dir = '~/chatgpt/vim-sessions'

if exists('g:loaded_llm_session')
  finish
endif
let g:loaded_llm_session = 1

if !get(g:, 'llm_session_enabled', 1)
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

" Configuration
let g:llm_session_command = get(g:, 'llm_session_command', 'llm')
let g:llm_session_position = get(g:, 'llm_session_position', 'bottom')
let g:llm_session_size = get(g:, 'llm_session_size', 40)
let g:llm_session_base_dir = get(g:, 'llm_session_base_dir', expand('~/chatgpt/vim-sessions'))

" State
let s:bufnr = -1
let s:history = []
let s:output_lines = []
let s:is_waiting = 0
let s:context_file = ''
let s:context_dir = ''
let s:context_rel = ''
let s:session_file = ''
let s:session_uuid = ''
let s:is_first_message = 1

" Generate a UUID v4
function! s:GenerateUUID()
  " Use system uuidgen if available, otherwise generate manually
  if executable('uuidgen')
    return trim(system('uuidgen'))
  else
    " Fallback: generate UUID-like string using random
    let l:hex = '0123456789abcdef'
    let l:uuid = ''
    for l:i in range(32)
      let l:uuid .= l:hex[rand() % 16]
      if l:i == 7 || l:i == 11 || l:i == 15 || l:i == 19
        let l:uuid .= '-'
      endif
    endfor
    return l:uuid
  endif
endfunction

" Generate session file path
function! s:GenerateSessionFile()
  let l:date_month = strftime('%Y-%m')
  let l:timestamp = strftime('%m%d-%H%M%S')

  " Get filename part
  let l:fname = expand('%:t')
  if empty(l:fname)
    let l:fname = 'scratch'
  endif
  let l:fname_dashed = substitute(l:fname, '[^a-zA-Z0-9]', '-', 'g')
  let l:fname_dashed = substitute(l:fname_dashed, '-\+', '-', 'g')
  let l:fname_dashed = substitute(l:fname_dashed, '^-\|-$', '', 'g')

  let l:dir = g:llm_session_base_dir . '/' . l:date_month
  if !isdirectory(l:dir)
    call mkdir(l:dir, 'p')
  endif

  return l:dir . '/' . l:timestamp . '-' . l:fname_dashed . '.md'
endfunction

" Write session header to file
function! s:WriteSessionHeader()
  let l:header = [
        \ '# LLM Session',
        \ '',
        \ '- **File**: ' . (empty(s:context_rel) ? '(none)' : s:context_rel),
        \ '- **Date**: ' . strftime('%Y-%m-%d %H:%M:%S'),
        \ '- **UUID**: ' . s:session_uuid,
        \ '',
        \ '---',
        \ '',
        \ ]
  call writefile(l:header, s:session_file)
endfunction

" Append user input to session file
function! s:AppendUserInput(input)
  if empty(s:session_file)
    return
  endif
  " Use the input as the heading for better readability
  let l:first_line = split(a:input, '\n')[0]
  let l:lines = ['## ' . l:first_line, '']
  call writefile(l:lines, s:session_file, 'a')
endfunction

" Append LLM response to session file
function! s:AppendLLMResponse(output, is_error)
  if empty(s:session_file)
    return
  endif
  let l:lines = ['## ' . (a:is_error ? 'Error' : 'LLM'), '']
  " Split output by newlines and add each line (keepempty=1 to preserve blank lines)
  call extend(l:lines, split(a:output, '\n', 1))
  call extend(l:lines, ['', '---', ''])
  call writefile(l:lines, s:session_file, 'a')
endfunction

" Load history from existing session file
function! s:LoadSessionFromFile(filepath)
  if !filereadable(a:filepath)
    return 0
  endif

  let s:session_file = a:filepath
  let s:history = []

  let l:lines = readfile(a:filepath)
  let l:current_type = ''
  let l:current_content = []
  let l:in_header = 1

  for l:line in l:lines
    " Skip until we pass the first ---
    if l:in_header
      if l:line ==# '---'
        let l:in_header = 0
      endif
      continue
    endif

    " Detect section headers
    if l:line =~# '^## You'
      " Save previous section
      if !empty(l:current_type) && !empty(l:current_content)
        call add(s:history, {'type': l:current_type, 'content': join(l:current_content, "\n")})
      endif
      let l:current_type = 'user'
      let l:current_content = []
    elseif l:line =~# '^## LLM'
      if !empty(l:current_type) && !empty(l:current_content)
        call add(s:history, {'type': l:current_type, 'content': join(l:current_content, "\n")})
      endif
      let l:current_type = 'llm'
      let l:current_content = []
    elseif l:line =~# '^## Error'
      if !empty(l:current_type) && !empty(l:current_content)
        call add(s:history, {'type': l:current_type, 'content': join(l:current_content, "\n")})
      endif
      let l:current_type = 'error'
      let l:current_content = []
    elseif l:line ==# '---'
      " Section separator, save current
      if !empty(l:current_type) && !empty(l:current_content)
        call add(s:history, {'type': l:current_type, 'content': join(l:current_content, "\n")})
      endif
      let l:current_type = ''
      let l:current_content = []
    elseif !empty(l:current_type)
      " Accumulate content (skip empty lines at start)
      if !empty(l:current_content) || !empty(l:line)
        call add(l:current_content, l:line)
      endif
    endif
  endfor

  " Save last section
  if !empty(l:current_type) && !empty(l:current_content)
    call add(s:history, {'type': l:current_type, 'content': join(l:current_content, "\n")})
  endif

  " Extract context and UUID from file header
  for l:line in l:lines[:15]
    if l:line =~# '^- \*\*File\*\*:'
      let s:context_rel = substitute(l:line, '^- \*\*File\*\*:\s*', '', '')
      if s:context_rel ==# '(none)'
        let s:context_rel = ''
      endif
    elseif l:line =~# '^- \*\*UUID\*\*:'
      let s:session_uuid = trim(substitute(l:line, '^- \*\*UUID\*\*:\s*', '', ''))
    endif
  endfor

  " If we have history, it's not the first message
  let s:is_first_message = empty(s:history)

  return 1
endfunction

" Close the session window
function! s:Close()
  if s:bufnr != -1 && bufexists(s:bufnr)
    let l:win = bufwinnr(s:bufnr)
    if l:win != -1
      execute l:win . 'wincmd c'
    endif
  endif
endfunction

" Open the session window
function! s:Open()
  " Capture context from current file before switching (only if new session)
  if empty(s:session_file)
    let s:context_file = expand('%:p')
    let s:context_dir = expand('%:p:h')
    let s:context_rel = expand('%:.')

    if empty(s:context_file)
      let s:context_dir = getcwd()
      let s:context_rel = ''
    endif

    " Generate new UUID for this session
    let s:session_uuid = s:GenerateUUID()
    let s:is_first_message = 1

    " Create new session file
    let s:session_file = s:GenerateSessionFile()
    call s:WriteSessionHeader()
  endif

  " If already open, just focus it
  if s:bufnr != -1 && bufexists(s:bufnr)
    let l:win = bufwinnr(s:bufnr)
    if l:win != -1
      execute l:win . 'wincmd w'
      return
    endif
  endif

  " Create split
  let l:size = g:llm_session_size
  if g:llm_session_position ==# 'bottom'
    execute 'botright ' . l:size . '% new'
  elseif g:llm_session_position ==# 'top'
    execute 'topleft ' . l:size . '% new'
  elseif g:llm_session_position ==# 'left'
    execute 'topleft vertical ' . l:size . '% new'
  elseif g:llm_session_position ==# 'right'
    execute 'botright vertical ' . l:size . '% new'
  else
    execute 'botright ' . l:size . '% new'
  endif

  " Reuse existing buffer or setup new one
  if s:bufnr != -1 && bufexists(s:bufnr)
    execute 'buffer ' . s:bufnr
  else
    call s:SetupBuffer()
  endif

  call s:Render()
endfunction

" Toggle session
function! s:Toggle()
  if s:bufnr != -1 && bufexists(s:bufnr)
    let l:win = bufwinnr(s:bufnr)
    if l:win != -1
      call s:Close()
      return
    endif
  endif
  call s:Open()
endfunction

" Setup buffer properties
function! s:SetupBuffer()
  let s:bufnr = bufnr('%')

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal nobuflisted
  setlocal wrap
  setlocal linebreak
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no

  silent! file [LLM-Session]

  " Mappings
  nnoremap <buffer> <silent> q :call <SID>Close()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>Submit()<CR>
  nnoremap <buffer> <silent> i :call <SID>GoToInput()<CR>i
  nnoremap <buffer> <silent> a :call <SID>GoToInput()<CR>a
  nnoremap <buffer> <silent> o :call <SID>GoToInput()<CR>a
  nnoremap <buffer> <silent> A :call <SID>GoToInput()<CR>A
  nnoremap <buffer> <silent> I :call <SID>GoToInput()<CR>I
  nnoremap <buffer> <silent> O :call <SID>GoToInput()<CR>I
  nnoremap <buffer> <silent> cc :call <SID>ClearInput()<CR>i
  nnoremap <buffer> <silent> dd :call <SID>ClearInput()<CR>
endfunction

" Go to input line
function! s:GoToInput()
  normal! G
  let l:last = line('$')
  " Find the input line (line starting with "> ")
  for l:i in range(l:last, 1, -1)
    if getline(l:i) =~# '^> '
      call cursor(l:i, 3)
      return
    endif
  endfor
  call cursor(l:last, 1)
endfunction

" Clear input line
function! s:ClearInput()
  call s:GoToInput()
  let l:lnum = line('.')
  call setline(l:lnum, '> ')
  call cursor(l:lnum, 3)
endfunction

" Render buffer content
function! s:Render()
  if s:bufnr == -1 || !bufexists(s:bufnr)
    return
  endif

  let l:win = bufwinnr(s:bufnr)
  if l:win == -1
    return
  endif

  " Save current window and switch
  let l:curwin = winnr()
  execute l:win . 'wincmd w'

  setlocal modifiable

  let l:lines = []
  call add(l:lines, '═══ LLM Session ═══  [q]close  [Enter]submit  [i]input')
  if !empty(s:context_rel)
    call add(l:lines, '    Context: ' . s:context_rel)
  endif
  if !empty(s:session_file)
    call add(l:lines, '    File: ' . fnamemodify(s:session_file, ':~'))
  endif
  if !empty(s:session_uuid)
    call add(l:lines, '    UUID: ' . s:session_uuid)
  endif
  call add(l:lines, '')

  " History
  for l:entry in s:history
    if l:entry.type ==# 'user'
      call add(l:lines, '>> YOU:')
      for l:line in split(l:entry.content, '\n')
        call add(l:lines, '   ' . l:line)
      endfor
      call add(l:lines, '')
    elseif l:entry.type ==# 'llm'
      call add(l:lines, '<< LLM:')
      for l:line in split(l:entry.content, '\n')
        call add(l:lines, '   ' . l:line)
      endfor
      call add(l:lines, '')
    elseif l:entry.type ==# 'error'
      call add(l:lines, '!! ERROR:')
      for l:line in split(l:entry.content, '\n')
        call add(l:lines, '   ' . l:line)
      endfor
      call add(l:lines, '')
    endif
  endfor

  " Waiting indicator
  if s:is_waiting
    call add(l:lines, '... waiting for response ...')
    call add(l:lines, '')
  endif

  " Input prompt
  call add(l:lines, '───────────────────────────────────────────')
  call add(l:lines, '> ')

  " Update buffer
  silent! %delete _
  call setline(1, l:lines)

  " Go to input line
  normal! G
  call cursor(line('$'), 3)

  " Return to original window
  execute l:curwin . 'wincmd w'
endfunction

" Submit input
function! s:Submit()
  if s:is_waiting
    echo 'Still waiting for LLM response...'
    return
  endif

  " Find the input start line (line starting with "> ")
  let l:input_start = 0
  for l:i in range(line('$'), 1, -1)
    if getline(l:i) =~# '^> '
      let l:input_start = l:i
      break
    endif
  endfor

  if l:input_start == 0
    return
  endif

  " Collect all lines from input start to end of buffer
  let l:input_lines = []
  for l:i in range(l:input_start, line('$'))
    let l:line = getline(l:i)
    if l:i == l:input_start
      " Remove the "> " prefix from first line
      let l:line = substitute(l:line, '^> ', '', '')
    endif
    call add(l:input_lines, l:line)
  endfor

  let l:input = join(l:input_lines, "\n")
  let l:input = trim(l:input)
  if empty(l:input)
    return
  endif

  " Add to history
  call add(s:history, {'type': 'user', 'content': l:input})

  " Write to session file
  call s:AppendUserInput(l:input)

  let s:is_waiting = 1
  let s:output_lines = []

  call s:Render()

  " Run LLM async
  call s:RunLLM(l:input)
endfunction

" Run LLM command
function! s:RunLLM(prompt)
  " Replace newlines with spaces for command line
  let l:clean_prompt = substitute(a:prompt, '\n\+', ' ', 'g')
  let l:clean_prompt = trim(l:clean_prompt)

  " Build prompt with file context
  let l:prompt = l:clean_prompt
  if !empty(s:context_rel)
    let l:prompt = 'on file ' . s:context_rel . ': ' . l:clean_prompt
  endif

  " Build LLM command
  let l:cmd = g:llm_session_command

  " For claude: use --session-id for first message, -r for follow-ups
  if l:cmd =~# '^claude\>'
    if s:is_first_message && !empty(s:session_uuid)
      let l:cmd .= ' --session-id ' . shellescape(s:session_uuid)
    elseif !s:is_first_message && !empty(s:session_uuid)
      let l:cmd .= ' -r ' . shellescape(s:session_uuid)
    endif
  " For llm: add --init-file option with current file
  elseif l:cmd =~# '^llm\>' && !empty(s:context_file)
    let l:cmd .= ' --init-file ' . shellescape(s:context_file)
  endif
  let l:cmd .= ' -'

  let l:escaped = shellescape(l:prompt)
  let l:run_dir = empty(s:context_dir) ? getcwd() : s:context_dir
  let l:full_cmd = 'cd ' . shellescape(l:run_dir) . ' && printf %s ' . l:escaped . ' | ' . l:cmd

  call job_start(['bash', '-c', l:full_cmd], {
        \ 'out_cb': function('s:OnStdout'),
        \ 'err_cb': function('s:OnStdout'),
        \ 'exit_cb': function('s:OnExit'),
        \ })
endfunction

" Vim callbacks - default 'nl' mode gives one line per callback (without newline)
function! s:OnStdout(channel, msg)
  call add(s:output_lines, a:msg)
endfunction

function! s:OnExit(job, status)
  " Join with newline since each line was received separately
  let l:output = join(s:output_lines, "\n")
  call s:HandleResponse(a:status, l:output)
endfunction

" Handle LLM response
function! s:HandleResponse(exit_code, output)
  let s:is_waiting = 0

  let l:output = a:output
  " Normalize line endings: convert CRLF to LF, then CR to LF
  let l:output = substitute(l:output, '\r\n', '\n', 'g')
  let l:output = substitute(l:output, '\r', '\n', 'g')
  " Trim leading/trailing newlines only
  let l:output = substitute(l:output, '\n\+$', '', '')
  let l:output = substitute(l:output, '^\n\+', '', '')

  let l:is_error = a:exit_code != 0
  if l:is_error
    call add(s:history, {
          \ 'type': 'error',
          \ 'content': 'Exit code ' . a:exit_code . ': ' . l:output
          \ })
  else
    call add(s:history, {
          \ 'type': 'llm',
          \ 'content': l:output
          \ })
    " First message succeeded, subsequent messages use -r
    let s:is_first_message = 0
  endif

  " Write to session file
  call s:AppendLLMResponse(l:output, l:is_error)

  call s:Render()
endfunction

" Clear history and start new session
function! s:Clear()
  let s:history = []
  let s:session_file = ''
  let s:session_uuid = ''
  let s:is_first_message = 1
  let s:context_file = ''
  let s:context_dir = ''
  let s:context_rel = ''
  call s:Render()
  echo 'Session cleared. New session will start on next input.'
endfunction

" Load an existing session file
function! s:Load(filepath)
  let l:path = expand(a:filepath)
  if !filereadable(l:path)
    echoerr 'File not found: ' . l:path
    return
  endif

  call s:LoadSessionFromFile(l:path)
  call s:Open()
  echo 'Loaded session from ' . l:path
endfunction

" Commands
command! LLMSession call s:Open()
command! LLMSessionToggle call s:Toggle()
command! LLMSessionClear call s:Clear()
command! -nargs=1 -complete=file LLMSessionLoad call s:Load(<q-args>)

" Mapping
nnoremap <silent> <Leader>u :call <SID>Toggle()<CR>

let &cpo = s:save_cpo
unlet s:save_cpo
