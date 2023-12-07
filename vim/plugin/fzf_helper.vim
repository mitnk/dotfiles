" You need to put fzf.vim file under the same dir.
" https://github.com/junegunn/fzf/blob/d21d5c9510170d74a7f959309da720b6df72ca01/plugin/fzf.vim

function! FindFzfRoot()
    let l:current_dir = getcwd()
    while l:current_dir != '/' && l:current_dir != ''
        " Update logic here based on your project languages.
        if filereadable(l:current_dir . '/mix.exs') || isdirectory(l:current_dir . '/.git')
            return l:current_dir
        else
            let l:current_dir = fnamemodify(l:current_dir, ':h')
        endif
    endwhile

    " Return the initial directory if nothing found
    return getcwd()
endfunction

function! FzfWithDirFunc(directory)
    execute 'FZF ' . a:directory
endfunction

nnoremap <Leader>f :call FzfWithDirFunc(FindFzfRoot())<CR>
