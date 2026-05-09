syntax enable
syntax on
set background=dark
set tags=tags;
set incsearch
set showcmd
set ignorecase
set smartcase
set t_Co=256
set ruler
set hlsearch
set tabstop=2
set tabpagemax=100
set number

filetype plugin on
filetype indent on

set autoread
au FocusGained,BufEnter * silent! checktime

set showmatch
set mat=2

set noerrorbells
set novisualbell
set t_vb=
set tm=500

if has("gui_running")
    set guioptions-=T
    set guioptions-=e
    set t_Co=256
    set guitablabel=%M\ %t
endif

set encoding=utf8

set nobackup
set nowb
set noswapfile

set ai
set si
set wrap

set laststatus=2
set statusline=\ %{HasPaste()}%F%m%r%h\ %w\ \ CWD:\ %r%{getcwd()}%h\ \ \ Line:\ %l\ \ Column:\ %c

function! HasPaste()
    if &paste
        return 'PASTE MODE  '
    endif
    return ''
endfunction

let g:vim_markdown_conceal = 0
let g:vim_markdown_conceal_code_blocks = 0
let g:vim_markdown_emphasis_multiline = 0
let g:vim_markdown_fenced_languages = [
      \ 'bash=sh',
      \ 'json',
      \ 'javascript',
      \ 'lua',
      \ 'python',
      \ 'typescript',
      \ 'vim',
      \ 'yaml',
      \ ]
let g:vim_markdown_folding_disabled = 1
let g:vim_markdown_frontmatter = 1
let g:vim_markdown_no_default_key_mappings = 1
packadd! vim-markdown
