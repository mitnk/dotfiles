update:
	cp gvimrc ${HOME}/.gvimrc
	cp vimrc ${HOME}/.vimrc
	mkdir -pv ${HOME}/.vim
	mkdir -pv ${HOME}/.vim/tmp
	mkdir -pv ${HOME}/.vim/undo
	cp -Rv ./* ${HOME}/.vim
	vim -c "helptags ${HOME}/.vim/doc/|q"
