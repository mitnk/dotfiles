function! FindGitRoot()
    let l:current_dir = getcwd()
    while l:current_dir != '/' && l:current_dir != ''
        if isdirectory(l:current_dir . '/.git')
            return l:current_dir
        else
            let l:current_dir = fnamemodify(l:current_dir, ':h')
        endif
    endwhile

    return ''
endfunction

function! GetGitBranch()
    let l:git_root = FindGitRoot()
    if empty(l:git_root)
        " not a git direcotry
        return ''
    endif

    let l:head_file = l:git_root . '/.git/HEAD'
    if !filereadable(l:head_file)
        return 'Cannot read HEAD'
    endif

    let l:head_content = readfile(l:head_file)
    if empty(l:head_content)
        return 'Empty HEAD file'
    endif

    let l:head_content = l:head_content[0]
    if l:head_content =~ '^ref:'
        let l:branch_name = substitute(l:head_content, '^ref: refs/heads/', '', '')

        " Check if the branch name is longer than 20 characters.
        if strlen(l:branch_name) > 18
            " Get the last 20 characters of the branch name.
            let l:branch_name = l:branch_name[-18:]
        endif

        return '[' . l:branch_name . ']'
    else
        return 'bad HEAD file'
    endif
endfunction

function! HighlightStatusLine()
    " Set statusline
    set statusline=
    " File path
    if has("gui_running")
        set statusline+=%5*
    endif
    set statusline+=\ %m%r%w%F%=

    " Row / Column
    if has("gui_running")
        set statusline+=%5*
    endif
    set statusline+=[%l:%c][%P]

    set statusline+=%{GetGitBranch()}

    " FileType
    if has("gui_running")
        set statusline+=\ %3*
    endif
    set statusline+=\ %Y/

    " Encoding
    if has("gui_running")
        set statusline+=%3*
    endif
    set statusline+=%{''.(&fenc!=''?&fenc:&enc).''}/

    " Encoding2
    if has("gui_running")
        set statusline+=%3*
    endif
    set statusline+=%{(&bomb?\",BOM\":\"\")}           "Encoding2

    " FileFormat (unix / dos ..)
    if has("gui_running")
        set statusline+=%3*
    endif
    set statusline+=%{&ff}\ 

    if has("gui_running")
        hi User1 guifg=#ffdad8  guibg=#000000
        hi User2 guifg=#000000  guibg=#F4905C
        hi User3 guifg=#999999  guibg=#aefe7B
        hi User4 guifg=#112605  guibg=#aefe7B
        hi User5 guifg=#051d00  guibg=#7dcc7d
        hi User7 guifg=#ffffff  guibg=#880c0e gui=bold
        hi User8 guifg=#ffffff  guibg=#5b7fbb
        hi User9 guifg=#ffffff  guibg=#810085
        hi User0 guifg=#ffffff  guibg=#094afe
    endif
endfunction

function! UnHighlightStatusLine()
    setlocal statusline=%1*%F
    if has("gui_running")
        hi User1 guifg=#333333 guibg=#222222
    endif
endfunction

set laststatus=2
autocmd! BufEnter * call HighlightStatusLine()
autocmd! BufLeave * call UnHighlightStatusLine()
