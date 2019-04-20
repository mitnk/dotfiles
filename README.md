Set Up
======

Set up a Proxy Server?
----------------------

use https://github.com/inaz2/proxy2

Bash
----

```bash
cp bash_profile ~/.bash_profile
```

Vim, Git, Xonsh
---------------

cd to its subdirectory and type `make`.

**Vim Plugins**:

- supertab
- NerdTree
- [thwins](https://github.com/mitnk/thwins)
- Python-Match [386](http://www.vim.org/scripts/script.php?script_id=386)
    - Redefines the % motion: Cycles through if/try/for/while
    - Two other motions, [% and ]%: go to the start/end of block

**Font**:

- OS X: Using `open vim/fonts/Monaco-Powerline.otf` to install
- Ubuntu: `mkdir -p ~/.fonts && cp vim/fonts/Ubuntu*.otf ~/.fonts/ && fc-cache -vf`

**Note**: On Ubuntu, search `Ubuntu` in ~/.vimrc to make some change.

Aria2

```bash
mkdir -p ~/.aria2 && cp ./aria2/aria2.conf ~/.aria2/
```

Pre-Commit

```
cp -v git/pre-commit .git/hooks/
```

Others
------

**PostgreSQL**: `cp psqlrc ~/.psqlrc`

