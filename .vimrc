set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab

" Enable hybrid line numbers
set nu! rnu!

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

call plug#begin('~/.vim/plugged')

" Make sure you use single quotes
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

call plug#end()

autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

let g:limelight_conceal_ctermfg = 240

