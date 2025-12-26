" llm-ask.vim - Vim plugin for LLM chat integration
" Maintainer: Hugo & AI
" Version: 4.1
"
" This plugin is ENABLED by default. Configuration options for .vimrc:
"
"   " To disable the plugin completely:
"   let g:llm_ask_enabled = 0
"
"   " To change the LLM command (default: 'llm --oneshot'):
"   " For llm: adds --init-file <current-file> automatically
"   " For claude:
"   let g:llm_ask_command = 'claude -p'
"
"   " Other optional settings:
"   let g:llm_ask_base_dir = '~/chatgpt/vim-asks'
"   let g:llm_ask_server_port = 7777

if exists('g:loaded_llm_ask')
  finish
endif
let g:loaded_llm_ask = 1

" Check if plugin is enabled (enabled by default)
if !get(g:, 'llm_ask_enabled', 1)
  finish
endif

" Save cpo and set to vim default
let s:save_cpo = &cpo
set cpo&vim

" Configuration
let g:llm_ask_command = get(g:, 'llm_ask_command', 'llm --oneshot')
let g:llm_ask_base_dir = get(g:, 'llm_ask_base_dir', expand('~/chatgpt/vim-asks'))
let g:llm_ask_server_port = get(g:, 'llm_ask_server_port', 7777)

" Track pending jobs
let s:pending_jobs = {}

" Main function to ask LLM
function! s:AskLLM()
  " Get current file info
  let l:file_path = expand('%:p')
  let l:file_dir = expand('%:p:h')
  let l:file_name = expand('%:t')
  let l:file_rel_path = expand('%:.')

  if empty(l:file_path)
    let l:file_dir = getcwd()
    let l:file_rel_path = ''
    let l:file_name = 'nofile'
  endif

  " Prompt for question (ESC or empty input exits silently)
  let l:input_prompt = g:llm_ask_command =~# '^claude\>' ? 'Ask Claude: ' : 'Ask LLM: '
  let l:question = input(l:input_prompt)
  if empty(l:question)
    return
  endif

  " Build the prompt
  if empty(l:file_rel_path)
    let l:prompt = l:question
  else
    let l:prompt = 'on file ' . l:file_rel_path . ': ' . l:question
  endif

  " Build output file path
  let l:date_month = strftime('%Y-%m')
  let l:timestamp = strftime('%m%d-%H%M%S')

  let l:file_name_dashed = substitute(l:file_name, '[^a-zA-Z0-9]', '-', 'g')
  let l:file_name_dashed = substitute(l:file_name_dashed, '-\+', '-', 'g')
  let l:file_name_dashed = substitute(l:file_name_dashed, '^-\|-$', '', 'g')

  let l:output_dir = g:llm_ask_base_dir . '/' . l:date_month
  let l:output_file = l:timestamp . '-' . l:file_name_dashed . '.md'
  let l:output_path = l:output_dir . '/' . l:output_file
  let l:url = 'http://127.0.0.1:' . g:llm_ask_server_port . '/vim-asks/' . l:date_month . '/' . l:output_file

  " Create directory
  if !isdirectory(l:output_dir)
    call mkdir(l:output_dir, 'p')
  endif

  " Write question header to file
  let l:header = [
        \ '# ' . l:file_rel_path . ': ' . l:question,
        \ '',
        \ ]
  call writefile(l:header, l:output_path)

  " Build the LLM command
  " For llm: add --init-file option with current file
  " Both llm and claude support '-' to read from stdin
  let l:llm_cmd = g:llm_ask_command
  if l:llm_cmd =~# '^llm\>' && !empty(l:file_path)
    let l:llm_cmd .= ' --init-file ' . shellescape(l:file_path)
  endif
  let l:llm_cmd .= ' -'

  " Build shell command: run LLM, append to file
  " Use stdin to avoid command injection via argument parsing
  let l:escaped_prompt = shellescape(l:prompt)
  let l:cmd = 'cd ' . shellescape(l:file_dir)
  let l:cmd .= ' && { printf %s ' . l:escaped_prompt . ' | ' . l:llm_cmd . ' >> ' . shellescape(l:output_path) . ' 2>&1; }'

  " Only open browser on macOS
  if has('mac') || has('macunix')
    let l:cmd .= ' && open ' . shellescape(l:url)
  endif

  " Store context for callback
  let l:ctx = {
        \ 'output_path': l:output_path,
        \ 'url': l:url,
        \ }

  " Run in background with exit callback
  if has('nvim')
    let l:job_id = jobstart(['bash', '-c', l:cmd], {
          \ 'on_exit': function('s:OnJobExitNvim'),
          \ })
    let s:pending_jobs[l:job_id] = l:ctx
  else
    let l:job = job_start(['bash', '-c', l:cmd], {
          \ 'exit_cb': function('s:OnJobExit'),
          \ })
    let s:pending_jobs[job_info(l:job).process] = l:ctx
  endif

  echo "\nLLM is thinking... browser will open when ready."
endfunction

" Handle job completion (shared logic)
function! s:HandleJobCompletion(ctx, exit_code)
  if a:exit_code != 0
    " Append error to the markdown file
    let l:error_lines = [
          \ '',
          \ '---',
          \ '',
          \ '**Error:** LLM command failed with exit code ' . a:exit_code,
          \ ]
    call writefile(l:error_lines, a:ctx.output_path, 'a')
    echohl ErrorMsg
    echo 'LLM failed (exit code ' . a:exit_code . '). See ' . a:ctx.output_path
    echohl None
  else
    echo 'LLM response saved to ' . a:ctx.output_path
  endif
endfunction

" Callback when job exits (Vim 8+)
function! s:OnJobExit(job, status)
  let l:pid = job_info(a:job).process
  if !has_key(s:pending_jobs, l:pid)
    return
  endif
  let l:ctx = remove(s:pending_jobs, l:pid)
  call s:HandleJobCompletion(l:ctx, a:status)
endfunction

" Callback when job exits (Neovim)
function! s:OnJobExitNvim(job_id, exit_code, event)
  if !has_key(s:pending_jobs, a:job_id)
    return
  endif
  let l:ctx = remove(s:pending_jobs, a:job_id)
  call s:HandleJobCompletion(l:ctx, a:exit_code)
endfunction

" Create the mapping
nnoremap <silent> <Leader>i :call <SID>AskLLM()<CR>

" Restore cpo
let &cpo = s:save_cpo
unlet s:save_cpo
