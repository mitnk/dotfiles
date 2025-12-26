" You need to 1) put fzf.vim file under the same dir:
" https://github.com/junegunn/fzf/blob/master/plugin/fzf.vim
" 2) install fzf: https://github.com/junegunn/fzf/releases
" 3) install fd: cargo install -f fd-find
let $FZF_DEFAULT_COMMAND = "fd --type f"
let $FZF_DEFAULT_OPTS = "--exact"

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

nnoremap <Leader>k :call FzfWithDirFunc(FindFzfRoot())<CR>
