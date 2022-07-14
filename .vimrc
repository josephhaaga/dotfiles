set nocompatible                " required
filetype off                    " required

filetype plugin indent on    " required

set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab

" Enable hybrid line numbers
" set nu!
" Enable relative line numbers
set nu!
set rnu!

" Permanent statusbar
set laststatus=2

" Enable syntax highlighting
syntax on

" Create a Json command to prettify json
:command Json %!python -m json.tool

" Show the cursor position
set ruler

" Show the filename in the window titlebar
set title

" Use OS X system clipboard
set clipboard=unnamed

" Install vim-plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

" Run PlugInstall if there are missing plugins
"if len(filter(values(g:plugs), '!isdirectory(v:val.dir)'))
"  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
"endif


call plug#begin('~/.vim/plugged')

" Make sure you use single quotes
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
Plug 'tmhedberg/SimpylFold'

" Python formatting edgecases (e.g. multi-line function signatures)
"Plug 'vim-scripts/indentpython.vim'

" Python autocompletion
"Plug 'Valloric/YouCompleteMe'

" Check syntax on each save
"Plug 'vim-syntastic/syntastic'

" Add PEP8 checking
"Plug 'nvie/vim-flake8'

call plug#end()

autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

let g:limelight_conceal_ctermfg = 240

"split navigations
"nnoremap <C-J> <C-W><C-J>
"nnoremap <C-K> <C-W><C-K>
"nnoremap <C-L> <C-W><C-L>
"nnoremap <C-H> <C-W><C-H>

" Enable folding
set foldmethod=indent
set foldlevel=99

" Enable folding with the spacebar
nnoremap <space> za

" " Proper PEP8 Indentation
" au BufNewFile,BufRead *.py
"     \ set tabstop=4
"     \ set softtabstop=4
"     \ set shiftwidth=4
"     \ set textwidth=79
"     \ set expandtab
"     \ set autoindent
"     \ set fileformat=unix
" 
" 
" " Full-stack dev indenting
"  au BufNewFile,BufRead *.js,*.html,*.css
"     \ set tabstop=2
"     \ set softtabstop=2
"     \ set shiftwidth=2
" 
" " Mark whitespace as bad
" au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/
" 
" you should be using UTF-8 when working with Python3
set encoding=utf-8

"let g:ycm_autoclose_preview_window_after_completion=1
"let g:ycm_python_binary_path='/Users/josephhaaga/anaconda3/bin/python3'
"map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

"python with virtualenv support
" py << EOF
" import os
" import sys
" if 'VIRTUAL_ENV' in os.environ:
"  project_base_dir = os.environ['VIRTUAL_ENV']
"  activate_this = os.path.join(project_base_dir, 'bin/activate_this.py')
"  execfile(activate_this, dict(__file__=activate_this))
" EOF

let python_highlight_all=1
syntax on

" :colo darkblue

