set nocompatible                " required
filetype off                    " required

filetype plugin indent on    " required

set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab

" Fix backspace in insert mode
set backspace=indent,eol,start

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

" Create a timestamp command
:command Ts :r!python3 -c "import datetime; now=datetime.datetime.now().strftime('\%Y-\%m-\%d \%I:\%M:\%S \%p'); print(f'[{now}]')"

" Create a Algo command to echo my LeetCode practice template
:command Algo :r!python3 -c "import datetime; now=datetime.datetime.now().strftime('\%Y-\%m-\%d \%I:\%M:\%S \%p'); print(f'[{now}]\n\n<URL>\n\nWhat went wrong?\n\nWhat is one thing I could have done/known that would\'ve made everything else easier?\n');"


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
Plug 'vim-scripts/indentpython.vim'

" Python autocompletion
Plug 'Valloric/YouCompleteMe', { 'do': './install.py' }

" Check syntax on each save
Plug 'vim-syntastic/syntastic'

" Add PEP8 checking
" Plug 'nvie/vim-flake8'

" Syntax highlighting for all languages
Plug 'sheerun/vim-polyglot'

" Asynchronous linting (no need to `:w` the file!)
Plug 'dense-analysis/ale'

" Context (i.e. floating function signatures while scrolling)
" Plug 'nvim-treesitter/nvim-treesitter-context'

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

" " python with virtualenv support
" function! ActivateVirtualenv()
"     if (g:current_venv != '')
"         call system(". " + g:current_venv + "/venv/bin/activate")
"     endif
" endfunction
" 
" let g:current_venv=system("echo $VIRTUAL_ENV")
" call ActivateVirtualenv()

let g:ale_python_auto_pipenv = 1
let g:ale_python_auto_poetry = 1
let g:ale_python_auto_virtualenv = 1

" YouCompleteMe setup
let g:ycm_autoclose_preview_window_after_completion=1
" let g:ycm_python_binary_path=g:current_venv + 'bin/python3'
"map <leader>g  :YcmCompleter GoToDefinitionElseDeclaration<CR>

" Only for non-Intel/AMD Macs
let g:ycm_clangd_binary_path = trim(system('brew --prefix llvm')).'/bin/clangd'

"https://vi.stackexchange.com/a/36667
"Toggle YouCompleteMe on and off with F3
function Toggle_ycm()
    if g:ycm_show_diagnostics_ui == 0
        let g:ycm_auto_trigger = 1
        let g:ycm_show_diagnostics_ui = 1
        :YcmRestartServer
        :e
        :echo "YCM on"
    elseif g:ycm_show_diagnostics_ui == 1
        let g:ycm_auto_trigger = 0
        let g:ycm_show_diagnostics_ui = 0
        :YcmRestartServer
        :e
        :echo "YCM off"
    endif
endfunction
map <F3> :call Toggle_ycm() <CR>

" turn off automatic YouCompleteMe cursor hover info
"let g:ycm_auto_hover = ''

" toggle language hover info with F4
"map <F4> <plug>(YCMHover)

" Proper PEP8 Indentation
au BufNewFile,BufRead *.py
    \ set tabstop=4 |
    \ set softtabstop=4 |
    \ set shiftwidth=4 |
    \ set textwidth=79 |
    \ set expandtab |
    \ set autoindent |
    \ set fileformat=unix


" Full-stack dev indenting
au BufNewFile,BufRead *.js,*.html,*.css
   \ set tabstop=2 |
   \ set softtabstop=2 |
   \ set shiftwidth=2

" Mark whitespace as bad
" au BufRead,BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" you should be using UTF-8 when working with Python3
set encoding=utf-8

let python_highlight_all=1
syntax on

" :colo darkblue
set t_Co=256
