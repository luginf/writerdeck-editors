\ writerdeck.fs — minimal TUI text editor for gforth
\ Requirements: gforth 0.7+, libncurses-dev
\ Usage: gforth writerdeck.fs [filename]

\ ═══════════════════════════════════════════════════════════════════════════════
\ C / ncurses FFI
\ ═══════════════════════════════════════════════════════════════════════════════

c-library wr-ext
s" ncurses" add-lib

\c #include <ncurses.h>
\c #include <locale.h>
\c #include <stdlib.h>
\c #include <string.h>
\c #include <sys/stat.h>
\c #include <sys/types.h>
\c #include <time.h>
\c #include <dirent.h>
\c #include <errno.h>
\c #include <unistd.h>
\c
\c static Cell wr_rows(void) { return LINES; }
\c static Cell wr_cols(void) { return COLS; }
\c static Cell wr_print(Cell row, Cell col, char *s, Cell len) {
\c   char buf[len+1]; memcpy(buf,s,len); buf[len]=0;
\c   return mvprintw(row,col,"%s",buf); }
\c static Cell wr_escdelay(Cell ms) { ESCDELAY=ms; return 0; }
\c static void *wr_stdscr(void) { return stdscr; }
\c static Cell wr_locale(void) { setlocale(LC_ALL,""); return 0; }
\c static Cell wr_A_REVERSE(void) { return A_REVERSE; }
\c static Cell wr_A_BOLD(void)    { return A_BOLD; }
\c static Cell wr_A_DIM(void)     { return A_DIM; }
\c static Cell wr_KEY_UP(void)    { return KEY_UP; }
\c static Cell wr_KEY_DOWN(void)  { return KEY_DOWN; }
\c static Cell wr_KEY_LEFT(void)  { return KEY_LEFT; }
\c static Cell wr_KEY_RIGHT(void) { return KEY_RIGHT; }
\c static Cell wr_KEY_HOME(void)  { return KEY_HOME; }
\c static Cell wr_KEY_END(void)   { return KEY_END; }
\c static Cell wr_KEY_PPAGE(void) { return KEY_PPAGE; }
\c static Cell wr_KEY_NPAGE(void) { return KEY_NPAGE; }
\c static Cell wr_KEY_BACKSPACE(void) { return KEY_BACKSPACE; }
\c static Cell wr_KEY_DC(void)    { return KEY_DC; }
\c static Cell wr_KEY_ENTER(void) { return KEY_ENTER; }
\c static char *wr_getenv(char *name) { return getenv(name); }
\c static Cell wr_mkdirp(char *path) {
\c   char tmp[4096]; strncpy(tmp,path,4095); tmp[4095]=0;
\c   for(char *p=tmp+1;*p;p++) if(*p=='/'){*p=0;mkdir(tmp,0755);*p='/';}
\c   return mkdir(tmp,0755)==0||errno==EEXIST?0:-1; }
\c static Cell wr_fexists(char *p){struct stat st;return stat(p,&st)==0?-1:0;}
\c static Cell wr_fmtime(char *p){struct stat st;return stat(p,&st)==0?(Cell)st.st_mtime:0;}
\c static Cell wr_fsize(char *p){struct stat st;return stat(p,&st)==0?(Cell)st.st_size:0;}
\c static Cell wr_lsdir(char *path,char *buf,Cell blen){
\c   DIR *d=opendir(path);if(!d)return 0;
\c   struct dirent *e;Cell n=0;
\c   while((e=readdir(d))&&n<blen-1){if(e->d_name[0]=='.')continue;
\c     Cell l=strlen(e->d_name);if(n+l+1>=blen)break;
\c     memcpy(buf+n,e->d_name,l);buf[n+l]='\n';n+=l+1;}
\c   buf[n]=0;closedir(d);return n;}
\c static Cell wr_time(void){return (Cell)time(NULL);}
\c static Cell wr_strftime(char *buf,Cell blen){
\c   time_t t=time(NULL);struct tm *tm=localtime(&t);
\c   return (Cell)strftime(buf,blen,"%H:%M",tm);}
\c static Cell wr_frename(char *a,char *b){return rename(a,b);}
\c static Cell wr_fremove(char *a){return remove(a);}

c-function nc:initscr    initscr              -- a
c-function nc:endwin     endwin               -- n
c-function nc:curs-set   curs_set             n -- n
c-function nc:noecho     noecho               -- n
c-function nc:raw        raw                  -- n
c-function nc:keypad     keypad               a n -- n
c-function nc:refresh    refresh              -- n
c-function nc:erase      erase                -- n
c-function nc:attron     attron               n -- n
c-function nc:attroff    attroff              n -- n
c-function nc:move       move                 n n -- n
c-function nc:getch      getch                -- n
c-function nc:rows       wr_rows              -- n
c-function nc:cols       wr_cols              -- n
c-function nc:print      wr_print             n n a n -- n
c-function nc:defcolors  use_default_colors   -- n
c-function nc:escdelay   wr_escdelay          n -- n
c-function nc:stdscr     wr_stdscr            -- a
c-function nc:locale     wr_locale            -- n
c-function nc:A_REVERSE  wr_A_REVERSE         -- n
c-function nc:A_BOLD     wr_A_BOLD            -- n
c-function nc:A_DIM      wr_A_DIM             -- n
c-function nc:KEY_UP     wr_KEY_UP            -- n
c-function nc:KEY_DOWN   wr_KEY_DOWN          -- n
c-function nc:KEY_LEFT   wr_KEY_LEFT          -- n
c-function nc:KEY_RIGHT  wr_KEY_RIGHT         -- n
c-function nc:KEY_HOME   wr_KEY_HOME          -- n
c-function nc:KEY_END    wr_KEY_END           -- n
c-function nc:KEY_PPAGE  wr_KEY_PPAGE         -- n
c-function nc:KEY_NPAGE  wr_KEY_NPAGE         -- n
c-function nc:KEY_BS     wr_KEY_BACKSPACE      -- n
c-function nc:KEY_DC     wr_KEY_DC            -- n
c-function nc:KEY_NL     wr_KEY_ENTER         -- n
c-function os:getenv     wr_getenv            a -- a
c-function os:mkdirp     wr_mkdirp            a -- n
c-function os:fexists    wr_fexists           a -- n
c-function os:fmtime     wr_fmtime            a -- n
c-function os:fsize      wr_fsize             a -- n
c-function os:lsdir      wr_lsdir             a a n -- n
c-function os:time       wr_time              -- n
c-function os:strftime   wr_strftime          a n -- n
c-function os:frename    wr_frename           a a -- n
c-function os:fremove    wr_fremove           a -- n
end-c-library

\ ── Compatibility ────────────────────────────────────────────────────────────
: 2+  2 + ;  : 2-  2 - ;
: 3+  3 + ;  : 3-  3 - ;
: 4+  4 + ;  : 4-  4 - ;
: (.)  ( n -- addr len )  dup abs s>d <# #s rot sign #> ;

\ ── Key / attribute constants ─────────────────────────────────────────────────
variable K_UP    variable K_DOWN   variable K_LEFT   variable K_RIGHT
variable K_HOME  variable K_END    variable K_PPAGE  variable K_NPAGE
variable K_BS    variable K_DC     variable K_NL
variable A_REV   variable A_BOLD   variable A_DIM

: cache-constants ( -- )
  nc:KEY_UP    K_UP    !    nc:KEY_DOWN  K_DOWN  !
  nc:KEY_LEFT  K_LEFT  !    nc:KEY_RIGHT K_RIGHT !
  nc:KEY_HOME  K_HOME  !    nc:KEY_END   K_END   !
  nc:KEY_PPAGE K_PPAGE !    nc:KEY_NPAGE K_NPAGE !
  nc:KEY_BS    K_BS    !    nc:KEY_DC    K_DC    !
  nc:KEY_NL    K_NL    !
  nc:A_REVERSE A_REV   !    nc:A_BOLD    A_BOLD  !
  nc:A_DIM     A_DIM   ! ;

: k-up    K_UP    @ ;  : k-down  K_DOWN  @ ;
: k-left  K_LEFT  @ ;  : k-right K_RIGHT @ ;
: k-home  K_HOME  @ ;  : k-end   K_END   @ ;
: k-ppage K_PPAGE @ ;  : k-npage K_NPAGE @ ;
: k-bs    K_BS    @ ;  : k-dc    K_DC    @ ;
: k-nl    K_NL    @ ;
: a-rev   A_REV   @ ;  : a-bold  A_BOLD  @ ;  : a-dim A_DIM @ ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ String utilities
\ ═══════════════════════════════════════════════════════════════════════════════

: c-strlen ( c-addr -- n )
  dup begin dup c@ while 1+ repeat swap - ;

: c>s ( c-addr -- addr len )  dup c-strlen ;

\ Heap-allocate a null-terminated copy of a Forth string
: fs>c { addr len -- c-addr }
  len 1+ allocate throw
  addr over len move
  dup len + 0 swap c! ;

\ Heap-copy of a Forth string (not null-terminated)
: s-dup { addr len -- addr' len }
  len allocate throw  addr over len move  len ;

\ Concatenate two Forth strings into a new heap buffer
: s-cat { a1 l1 a2 l2 -- addr len }
  l1 l2 + allocate throw
  a1 over l1 move
  a2 over l1 + l2 move
  l1 l2 + ;

\ Scratch buffers for short-lived conversions (separate to avoid aliasing)
create _sc     1024 allot   \ s>c-tmp scratch
create _pathbuf 1024 allot  \ path building scratch

: s>c-tmp { addr len -- c-addr }
  addr _sc len move  0 _sc len + c!  _sc ;

\ Build "dir/name" in _pathbuf — name as null-terminated C string
: path-in-sc { dir-c name-c -- c-addr }
  dir-c c>s { da dl }
  da _pathbuf dl move
  [char] / _pathbuf dl + c!
  name-c c>s { na nl }
  na _pathbuf dl 1+ + nl move
  0 _pathbuf dl 1+ nl + + c!
  _pathbuf ;

\ Build "dir/name" in _pathbuf — name as Forth string (addr len)
: path-join { dir-c name-a name-l -- c-addr }
  dir-c c>s { da dl }
  da _pathbuf dl move
  [char] / _pathbuf dl + c!
  name-a _pathbuf dl 1+ + name-l move
  0 _pathbuf dl 1+ name-l + + c!
  _pathbuf ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Config & paths
\ ═══════════════════════════════════════════════════════════════════════════════

4 constant TAB-WIDTH

variable docs-dir     \ heap c-addr
variable cursor-file  \ heap c-addr

: init-paths ( -- )
  s" HOME" s>c-tmp os:getenv c>s
  s" /Documents/writerdeck" s-cat fs>c docs-dir !
  docs-dir @ c>s s" /.cursors.json" s-cat fs>c cursor-file ! ;

: ensure-docs-dir ( -- )  docs-dir @ os:mkdirp drop ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Lines buffer  (1-based indexing, 0-based byte offsets within lines)
\ ═══════════════════════════════════════════════════════════════════════════════

65536 constant MAX-LINES
create line-addrs MAX-LINES cells allot
create line-lens  MAX-LINES cells allot
variable n-lines

: line-addr@ ( li -- a )  1- cells line-addrs + @ ;
: line-len@  ( li -- n )  1- cells line-lens  + @ ;
: line-addr! ( a li -- )  1- cells line-addrs + ! ;
: line-len!  ( n li -- )  1- cells line-lens  + ! ;
: line@ ( li -- addr len )  dup line-addr@ swap line-len@ ;

: line! { addr len li -- }
  li line-addr@ ?dup if free throw then
  len allocate throw  addr over len move
  dup li line-addr!  len li line-len! ;

: line-replace! { new-a new-l li -- }
  li line-addr@ ?dup if free throw then
  new-a li line-addr!  new-l li line-len! ;

: lines-clear ( -- )
  n-lines @ 0 ?do  i 1+ line-addr@ ?dup if free throw then  loop
  0 n-lines ! ;

: lines-push { addr len -- }
  n-lines @ MAX-LINES >= abort" lines overflow"
  addr len n-lines @ 1+ line!
  1 n-lines +! ;

: lines-insert { li -- }
  \ Insert empty slot before li, shifting li..n-lines down by one
  n-lines @ MAX-LINES >= abort" lines overflow"
  n-lines @ li >= if
    li 1-  n-lines @  do
      i line-addr@ i 1+ line-addr!
      i line-len@  i 1+ line-len!
    -1 +loop
  then
  0 li line-addr!  0 li line-len!
  1 n-lines +! ;

: lines-delete { li -- }
  li line-addr@ ?dup if free throw then
  n-lines @ li > if
    n-lines @ 1+  li 1+  do
      i line-addr@ i 1- line-addr!
      i line-len@  i 1- line-len!
    loop
  then
  -1 n-lines +! ;

1024 constant RLBUF
create _rl RLBUF allot

: lines-load { c-path -- }
  lines-clear
  c-path c>s r/o open-file if drop  s" " lines-push  exit  then { fid }
  begin
    _rl RLBUF fid read-line throw { len more }
    more if  _rl len lines-push  then
    more 0=
  until
  fid close-file throw
  n-lines @ 0= if  s" " lines-push  then ;

: lines-save { c-path -- }
  c-path c>s w/o create-file throw { fid }
  10 _sc c!   \ newline in scratch byte 0
  n-lines @ 1+ 1 ?do
    i line@ fid write-file throw
    _sc 1 fid write-file throw
  loop
  fid close-file throw ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ UTF-8 helpers  (cx = 0-based byte offset within a line)
\ ═══════════════════════════════════════════════════════════════════════════════

: utf8-next { addr len cx -- cx' }
  cx len >= if cx exit then
  addr cx + c@ { b }
  b 0x80 < if cx 1+ exit then
  b 0xE0 < if cx 2+ exit then
  b 0xF0 < if cx 3+ exit then
  cx 4+ ;

: utf8-prev { addr len cx -- cx' }
  cx 0<= if 0 exit then
  cx 1- to cx
  begin cx 0>  addr cx + c@ 0x80 >= and  addr cx + c@ 0xC0 < and
  while cx 1- to cx repeat
  cx ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Word / char count
\ ═══════════════════════════════════════════════════════════════════════════════

: word-count ( -- n )
  0 { wc }
  n-lines @ 1+ 1 ?do
    true { ws }
    i line@ bounds ?do
      i c@ 32 > if  ws if wc 1+ to wc then  false to ws
      else true to ws
      then
    loop
  loop
  wc ;

: char-count ( -- n )
  0  n-lines @ 1+ 1 ?do  i line-len@ +  loop ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Minimal JSON  (cursor file: { "path": [row, col] })
\ ═══════════════════════════════════════════════════════════════════════════════

create _jbuf 8192 allot
variable _jpos

: j-reset  0 _jpos ! ;
: j-byte! ( b -- )  _jbuf _jpos @ + c!  1 _jpos +! ;
: j-str { a l -- }  a l bounds ?do i c@ j-byte! loop ;
: j-quoted { a l -- }
  34 j-byte!
  a l bounds ?do
    i c@ { b }
    b 92 = if 92 j-byte! 92 j-byte!
    else b 34 = if 92 j-byte! 34 j-byte!
    else b 10 = if 92 j-byte! 110 j-byte!
    else b j-byte!
    then then then
  loop
  34 j-byte! ;
: j-num ( n -- )  (.) j-str ;
: j-result ( -- addr len )  _jbuf _jpos @ ;

variable _ja  variable _jl  variable _jp

: jp-skip ( -- )
  begin _jp @ _jl @ < _ja @ _jp @ + c@ 32 <= and
  while 1 _jp +! repeat ;

: jp-char ( -- c )  _ja @ _jp @ + c@ ;

create _jstrbuf 512 allot

: jp-string ( -- addr len )
  1 _jp +!
  0 { n }
  begin _jp @ _jl @ < jp-char 34 <> and while
    jp-char 92 = if
      1 _jp +!
      jp-char dup 110 = if drop 10 then
    else
      jp-char
    then
    _jstrbuf n + c!  n 1+ to n
    1 _jp +!
  repeat
  1 _jp +!
  _jstrbuf n ;

: jp-number ( -- n )
  0 { acc }
  begin _jp @ _jl @ < jp-char [char] 0 >= and jp-char [char] 9 <= and while
    acc 10 * jp-char [char] 0 - + to acc
    1 _jp +!
  repeat
  acc ;

: jp-find-cursor { ka kl -- found row col }
  jp-skip  jp-char 123 <> if false 0 0 exit then
  1 _jp +!
  begin
    jp-skip  _jp @ _jl @ >= if false 0 0 exit then
    jp-char 125 = if false 0 0 exit then
    jp-char 34 <> if false 0 0 exit then
    jp-string { sa sl }
    jp-skip  jp-char 58 = if 1 _jp +! then
    jp-skip
    sa sl ka kl compare 0= if
      jp-char 91 = if 1 _jp +! then
      jp-skip  jp-number { row }
      jp-skip  jp-char 44 = if 1 _jp +! then
      jp-skip  jp-number { col }
      jp-skip  jp-char 93 = if 1 _jp +! then
      true row col exit
    else
      jp-char 91 = if
        1 _jp +!
        begin _jp @ _jl @ < jp-char 93 <> and while 1 _jp +! repeat
        jp-char 93 = if 1 _jp +! then
      else
        begin _jp @ _jl @ < jp-char 44 <> and jp-char 125 <> and
        while 1 _jp +! repeat
      then
      jp-skip  jp-char 44 = if 1 _jp +! then
    then
  again ;

: load-cursor { c-path -- cy cx }
  cursor-file @ c>s r/o open-file if drop 1 0 exit then { fid }
  fid file-size throw drop { fsz }
  fsz 0= if fid close-file drop 1 0 exit then
  fsz allocate throw { jbuf }
  jbuf fsz fid read-file throw drop
  fid close-file throw
  jbuf _ja !  fsz _jl !  0 _jp !
  c-path c>s jp-find-cursor { found row col }
  jbuf free throw
  found if row 1+ col else 1 0 then ;

: save-cursor { c-path cy cx -- }
  j-reset
  123 j-byte!  c-path c>s j-quoted  58 j-byte!
  91 j-byte!   cy 1- j-num  44 j-byte!  cx j-num  93 j-byte!
  125 j-byte!
  j-result
  cursor-file @ c>s w/o create-file throw { fid }
  fid write-file throw
  fid close-file throw ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Word-wrap engine
\ ═══════════════════════════════════════════════════════════════════════════════

43691 3 * cells constant VROWS-ALLOC
create _vrows VROWS-ALLOC allot
variable n-vrows

: vrow! { li scol ecol vi -- }
  vi 1- 3 * cells _vrows + { p }
  li p !  scol p cell+ !  ecol p 2 cells + ! ;

: vrow@ { vi -- li scol ecol }
  vi 1- 3 * cells _vrows + { p }
  p @  p cell+ @  p 2 cells + @ ;

: wrap-add { li scol ecol -- }
  n-vrows @ 1+ { nv }
  li scol ecol nv vrow!
  1 n-vrows +! ;

: wrap-line { li addr len width -- }
  width 0<= if  li 0 len wrap-add  exit  then
  len 0=    if  li 0 0   wrap-add  exit  then
  0 { pos }
  begin pos len < while
    len pos - width <= if
      li pos len wrap-add  len to pos
    else
      pos width + { chunk-end }
      -1 { last-sp }
      chunk-end pos ?do  addr i + c@ bl = if i to last-sp then  loop
      last-sp pos > if
        li pos last-sp wrap-add  last-sp 1+ to pos
      else
        li pos chunk-end wrap-add  chunk-end to pos
      then
    then
  repeat ;

: build-wrap-map { width -- }
  0 n-vrows !
  n-lines @ 1+ 1 ?do  i  i line@  width wrap-line  loop ;

: logical>visual { cy cx -- vi scx }
  n-vrows @ 1+ 1 ?do
    i vrow@ { li scol ecol }
    li cy = scol cx <= and cx ecol <= and if
      \ At a wrap boundary with next segment on same line? Skip this vi.
      cx ecol = ecol scol > and i n-vrows @ < and if
        i 1+ vrow@ { nli nsc nec }
        nli li <> if  i cx scol - unloop exit  then
        \ else: fall through to next iteration
      else
        i cx scol - unloop exit
      then
    then
  loop
  n-vrows @ 0> if
    n-vrows @ vrow@ { fli fscol fecol }
    n-vrows @  cx fscol - 0 max fecol fscol - min  exit
  then
  1 0 ;

: visual>logical { vi scx -- cy cx }
  n-vrows @ 0= if 1 0 exit then
  vi 1 max n-vrows @ min to vi
  vi vrow@ { li scol ecol }
  scx 0 max ecol scol - min to scx
  li scol scx + ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Screen drawing
\ ═══════════════════════════════════════════════════════════════════════════════

: scr-h ( -- h )  nc:rows ;
: scr-w ( -- w )  nc:cols ;

create _bar 1024 allot

: draw-bar { y la ll ra rl attr -- }
  scr-w { w }
  w ll - rl - 0 max { gap }
  la _bar ll move
  _bar ll + gap bl fill
  ra _bar ll + gap + rl move
  ll gap + rl + w min { blen }
  attr nc:attron drop
  y 0 _bar blen nc:print drop
  attr nc:attroff drop ;

create _helpbuf 256 allot

: draw-help { y addr len -- }
  scr-w { w }
  len w min { l }
  a-dim nc:attron drop
  y 0 addr l nc:print drop
  l w < if  _helpbuf w l - bl fill  y l _helpbuf w l - nc:print drop  then
  a-dim nc:attroff drop ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ UTF-8 input
\ ═══════════════════════════════════════════════════════════════════════════════

create _u8 8 allot

: read-char ( -- keycode utf8-addr utf8-len )
  nc:getch { b }
  b 0< b 255 > or if  b 0 0 exit  then
  b 0x80 <            if  b 0 0 exit  then
  b 0xC0 <            if  b 0 0 exit  then
  b 0xE0 < if 1 else  b 0xF0 < if 2 else 3 then then { nbytes }
  b _u8 c!
  nbytes 1 ?do
    nc:getch { c }
    c 0x80 >= c 0xC0 < and if c else 0 then  _u8 i + c!
  loop
  -1 _u8 nbytes 1+ ;

\ Helper: append decimal n to buf at offset pos, return new pos
: buf-num { n buf pos -- pos' }
  n (.) { na nl }  na buf pos + nl move  pos nl + ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Prompt & confirm
\ ═══════════════════════════════════════════════════════════════════════════════

create _pbuf 512 allot
variable _plen

: prompt-input { la ll -- addr len | 0 }
  1 nc:curs-set drop
  0 _plen !
  begin
    scr-h { h }  scr-w { w }
    a-rev nc:attron drop
    h 1- 0 nc:move drop
    bl emit
    la ll bounds ?do i c@ emit loop
    _pbuf _plen @ bounds ?do i c@ emit loop
    w 1 ll + _plen @ + 0 max 0 ?do bl emit loop
    h 1- 1 ll + _plen @ + nc:move drop
    a-rev nc:attroff drop
    nc:refresh drop
    read-char { k ua ul }
    k 27 = if  0 nc:curs-set drop  0  exit  then
    k 10 = k 13 = or k k-nl = or if
      0 nc:curs-set drop  _pbuf _plen @  exit
    then
    k k-bs = k 127 = or k 8 = or if
      _plen @ 0> if  _pbuf _plen @ utf8-prev _plen !  then
    else
      k -1 = ul 0> and if
        ua _pbuf _plen @ + ul move  ul _plen +!
      else
        k 32 >= k 126 <= and if  k _pbuf _plen @ + c!  1 _plen +!  then
      then
    then
  again ;

create _confbuf 256 allot

: confirm { ma ml -- flag }
  ml 7 + { blen }
  bl _confbuf c!
  ma _confbuf 1 + ml move
  s"  (y/n)" drop _confbuf ml 1+ + 6 move
  scr-h { h }
  a-rev nc:attron drop
  h 1- 0 _confbuf blen nc:print drop
  a-rev nc:attroff drop
  nc:refresh drop
  begin
    nc:getch { ch }
    ch [char] y = ch [char] Y = or if true exit then
    ch [char] n = ch [char] N = or ch 27 = or if false exit then
  again ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ File listing with mtime sort
\ ═══════════════════════════════════════════════════════════════════════════════

16384 constant LSBUFSZ
create _lsbuf LSBUFSZ allot
variable _ls-n
variable _ls-sorted   \ heap array of (mtime cell, c-addr cell) pairs

: ls-free ( -- )
  _ls-sorted @ ?dup if  free throw  0 _ls-sorted !  then ;

: ls-name ( i -- c-addr )   \ i is 0-based
  _ls-sorted @ i 2 cells * + cell+ @ ;

\ Build full path for file i as heap c-string; caller must free
: doc-path { i -- c-addr }
  docs-dir @ ls-name i path-in-sc c>s fs>c ;

: ls-docs ( -- n )
  ls-free
  docs-dir @ _lsbuf LSBUFSZ os:lsdir { n }
  n 0= if  0 _ls-n !  0 exit  then
  n 2 cells * allocate throw _ls-sorted !
  0 { pos }
  n 0 do
    _lsbuf pos + { nc }
    nc c-strlen { nl }
    docs-dir @ nc path-in-sc os:fmtime
    _ls-sorted @ i 2 cells * + !
    nc  _ls-sorted @ i 2 cells * + cell+ !
    pos nl + 1+ to pos
  loop
  \ Insertion sort descending by mtime
  n 1 ?do
    _ls-sorted @ i 2 cells * + @ { mt }
    _ls-sorted @ i 2 cells * + cell+ @ { nm }
    i { j }
    begin j 0>  _ls-sorted @ j 1- 2 cells * + @ mt < and while
      _ls-sorted @ j 1- 2 cells * + @       _ls-sorted @ j 2 cells * + !
      _ls-sorted @ j 1- 2 cells * + cell+ @ _ls-sorted @ j 2 cells * + cell+ !
      j 1- to j
    repeat
    mt _ls-sorted @ j 2 cells * + !
    nm _ls-sorted @ j 2 cells * + cell+ !
  loop
  n _ls-n !  n ;

: has-ext? { addr len -- flag }
  len 0= if false exit then
  addr len + 1- { p }
  begin p addr >= p c@ [char] . <> and while p 1- to p repeat
  p addr >= p c@ [char] . = and ;

: basename-c { c-addr -- addr len }
  c-addr c>s { a l }
  l 0= if a 0 exit then
  a l + 1- { p }
  begin p a > p c@ [char] / <> and while p 1- to p repeat
  p c@ [char] / = if p 1+ else p then { start }
  start  a l + start - ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Formatting scratch buffers (top-level, never inside word bodies)
\ ═══════════════════════════════════════════════════════════════════════════════

create _szb  16 allot    \ size string
create _dtb  20 allot    \ date string
create _meta 48 allot    \ metadata (size + date)
create _bmsg 128 allot   \ browser message
create _emsg 128 allot   \ editor message
create _lft  128 allot   \ status bar left
create _rgt  128 allot   \ status bar right
create _tab4 4 allot     \ tab spaces

\ ═══════════════════════════════════════════════════════════════════════════════
\ File browser
\ ═══════════════════════════════════════════════════════════════════════════════

variable _sel     \ 1-based selection index
variable _scroll  \ 0-based scroll offset

create _pfx-sel   3 allot   \ UTF-8 '»' + space for selected row
0xC2 _pfx-sel c!  0xBB _pfx-sel 1+ c!  bl _pfx-sel 2+ c!

create _pfx-nor   3 allot   \ spaces for non-selected row
bl _pfx-nor c!  bl _pfx-nor 1+ c!  bl _pfx-nor 2+ c!

: file-browser ( -- c-addr | 0 )
  0 nc:curs-set drop
  1 _sel !  0 _scroll !  0 _bmsg c!
  begin
    nc:erase drop
    scr-h { h }  scr-w { w }
    h 3 - { usable }
    ls-docs { nf }

    \ Header
    a-bold nc:attron drop
    0 0 s"  writerdeck" nc:print drop
    w 11 > if  0 11 nc:move drop  w 11 - 0 ?do bl emit loop  then
    a-bold nc:attroff drop

    nf 0= if
      s" No documents yet. Press [n] to create one." { ma ml }
      h 2/ { my }  w ml - 2/ 0 max { mx }
      a-dim nc:attron drop  my mx ma ml nc:print drop  a-dim nc:attroff drop
    else
      _sel @ 1 max nf min _sel !
      _sel @ 1- _scroll @ < if  _sel @ 1- _scroll !  then
      _sel @ 1- _scroll @ usable + >= if  _sel @ usable - _scroll !  then

      usable 0 ?do    \ i = display row (0-based)
        _scroll @ i + { idx }   \ 0-based file index
        idx nf >= if leave then
        idx doc-path { fp }
        ls-name idx c>s { na nl }
        fp os:fsize  { fsz }
        fp os:fmtime { fmt }
        fp free throw

        \ Size string right-aligned in 6 columns
        fsz 1024 < if
          fsz (.) { sa sl }  sa _szb sl move  [char] B _szb sl + c!  sl 1+
        else
          fsz 1024 / (.) { sa sl }  sa _szb sl move  [char] K _szb sl + c!  sl 1+
        then { szl }
        6 szl - 0 max { pad }
        _meta pad bl fill
        _szb _meta pad + szl move
        pad szl + { ml }
        s"   " drop _meta ml + 2 move  ml 2 + to ml
        _dtb fmt os:strftime drop
        _dtb c-strlen { dtl }
        _dtb _meta ml + dtl move  ml dtl + to ml

        3 { plen }   \ prefix width (3 bytes: » + space)
        w plen - ml - 2 - 0 max { maxn }
        nl maxn min { dlen }
        idx 1+ _sel @ = { hilit }

        hilit if a-rev nc:attron drop then

        \ Prefix
        hilit if  i 1+ 0 _pfx-sel 3 nc:print drop
        else       i 1+ 0 _pfx-nor 3 nc:print drop  then

        \ Filename
        i 1+ plen na dlen nc:print drop

        \ Gap fill
        plen dlen + ml + { used }
        w used - 0 max { gap }
        gap 0 ?do
          j 1+ used i + nc:move drop   \ j = outer loop row, i = gap offset
          bl emit
        loop

        \ Metadata
        i 1+ w ml - 0 max _meta ml nc:print drop

        hilit if a-rev nc:attroff drop then
      loop
    then

    h 2- s"  [enter] open  [n] new  [d] delete  [r] rename  [q] quit"
    draw-help

    \ Status bar
    _bmsg c@ 0<> if
      h 1- s" " 0 _bmsg _bmsg c-strlen a-rev draw-bar
      0 _bmsg c!
    else
      docs-dir @ c>s { da dl }
      bl _lft c!  da _lft 1+ dl move  dl 1+ { ll }
      nf (.) { na nl }  0 { rp }
      na _rgt nl move  nl to rp
      s"  doc" drop _rgt rp + 4 move  rp 4 + to rp
      nf 1 <> if  [char] s _rgt rp + c!  rp 1+ to rp  then
      bl _rgt rp + c!  rp 1+ to rp
      h 1- _lft ll _rgt rp a-rev draw-bar
    then

    nc:refresh drop
    nc:getch { ch }

    ch [char] q = if  ls-free  0 exit  then

    ch k-up    = ch [char] k = or if  _sel @ 1- 1 max _sel !  then
    ch k-down  = ch [char] j = or if  _sel @ 1+ nf min _sel !  then
    ch k-home  = if  1 _sel !  then
    ch k-end   = if  nf 1 max _sel !  then

    ch 10 = ch 13 = or ch k-nl = or if
      nf 0> if  _sel @ 1- doc-path { fp }  ls-free  fp exit  then
    then

    ch [char] n = if
      s" new file: " prompt-input { ra rl }
      rl 0> if
        ra { ta }  rl { tl }
        begin tl 0> ta c@ bl = and while  ta 1+ to ta  tl 1- to tl  repeat
        begin tl 0> ta tl + 1- c@ bl = and while  tl 1- to tl  repeat
        tl 0> ta c@ [char] . <> and if
          ta tl has-ext? if ta tl else ta tl s" .txt" s-cat then { na nl }
          docs-dir @ na nl path-join { fp }
          fp os:fexists if
            s" already exists" drop _bmsg 14 move  0 _bmsg 14 + c!
          else
            fp c>s w/o create-file throw close-file throw
            fp c>s fs>c { fp2 }  ls-free fp2 exit
          then
        then
      then
    then

    ch [char] d = if
      nf 0> if
        ls-name _sel @ 1- c>s
        s" delete '" 2swap s-cat s" '?" s-cat { ma ml }
        ma ml confirm if
          _sel @ 1- doc-path { fp }
          fp os:fremove drop  fp free throw
          s" deleted" drop _bmsg 7 move  0 _bmsg 7 + c!
          _sel @ 1- 1 max _sel !
        then
        ma free throw
      then
    then

    ch [char] r = if
      nf 0> if
        ls-name _sel @ 1- c>s { oa ol }
        s" rename '" oa ol s-cat s" ' to: " s-cat { la ll }
        la ll prompt-input { ra rl }
        rl 0> if
          ra rl has-ext? if ra rl else ra rl s" .txt" s-cat then { na nl }
          docs-dir @ na nl path-join c>s fs>c { newp }
          _sel @ 1- doc-path { oldp }
          newp os:fexists if
            s" already exists" drop _bmsg 14 move  0 _bmsg 14 + c!
          else
            oldp newp os:frename drop
            s" renamed" drop _bmsg 7 move  0 _bmsg 7 + c!
          then
          newp free throw  oldp free throw
        then
        la free throw
      then
    then
  again ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Editor
\ ═══════════════════════════════════════════════════════════════════════════════

variable _cy      \ 1-based logical row
variable _cx      \ 0-based byte offset in current line
variable _scy     \ visual scroll offset
variable _tscx    \ sticky screen-col for vertical movement (-1 = none)
variable _dirty
variable _emsg-t

: ed-set-msg { addr len -- }
  addr _emsg len move  0 _emsg len + c!  os:time _emsg-t ! ;

: ed-insert { src-a src-l -- }
  _cy @ line@ { la ll }
  ll src-l + allocate throw { nb }
  la nb _cx @ move
  src-a nb _cx @ + src-l move
  la _cx @ + nb _cx @ + src-l + ll _cx @ - move
  nb ll src-l + _cy @ line-replace!
  src-l _cx +!
  true _dirty ! ;

: wr-editor { c-path -- }
  c-path lines-load
  c-path load-cursor { icy icx }
  icy 1 max n-lines @ min _cy !
  icx 0 max _cy @ line-len@ min _cx !
  0 _scy !  -1 _tscx !  false _dirty !  0 _emsg c!  0 _emsg-t !
  bl _tab4 c!  bl _tab4 1+ c!  bl _tab4 2+ c!  bl _tab4 3+ c!
  1 nc:curs-set drop

  begin
    nc:erase drop
    scr-h { h }  scr-w { w }
    h 2 - { th }

    _cy @ 1 max n-lines @ min _cy !
    _cx @ 0 max _cy @ line-len@ min _cx !

    build-wrap-map w
    _cy @ _cx @ logical>visual { vic scxc }

    vic 1- _scy @ < if  vic 1- _scy !  then
    vic 1- _scy @ th + >= if  vic th - _scy !  then
    _scy @ 0 max n-vrows @ th - 0 max min _scy !

    th 0 ?do
      _scy @ i + 1+ { vi }
      vi n-vrows @ > if leave then
      vi vrow@ { vli vscol vecol }
      vli line@ { la ll }
      i 0 la vscol + vecol vscol - nc:print drop
    loop

    h 2- s"  ^S save  ^W/^Q close  ^G goto line" draw-help

    c-path basename-c { bna bnl }
    0 { lp }
    bl _lft c!  1 to lp
    bna _lft lp + bnl move  lp bnl + to lp
    _dirty @ if  s"  [+]" drop _lft lp + 4 move  lp 4 + to lp  then

    _emsg c@ 0<> os:time _emsg-t @ - 2 < and if
      bl _lft c!  1 to lp
      _emsg _lft 1+ _emsg c-strlen move  1 _emsg c-strlen + to lp
    then

    0 { rp }
    s" ln "    drop _rgt rp + 3 move  rp 3 + to rp
    _cy @      _rgt rp buf-num to rp
    [char] /   _rgt rp + c!  rp 1+ to rp
    n-lines @  _rgt rp buf-num to rp
    s"   col "  drop _rgt rp + 6 move  rp 6 + to rp
    _cx @ 1+   _rgt rp buf-num to rp
    s"   "     drop _rgt rp + 2 move  rp 2 + to rp
    word-count _rgt rp buf-num to rp
    s" w "     drop _rgt rp + 2 move  rp 2 + to rp
    char-count _rgt rp buf-num to rp
    s" c "     drop _rgt rp + 2 move  rp 2 + to rp

    h 1- _lft lp _rgt rp a-rev draw-bar

    vic 1- _scy @ - { srow }
    srow 0 >= srow th < and if  srow scxc nc:move drop  then

    nc:refresh drop
    read-char { ch ua ul }
    false { sticky }

    ch k-up = if
      vic 1 > if
        _tscx @ -1 = if  scxc _tscx !  then
        vic 1- _tscx @ visual>logical  _cx ! _cy !
      then  true to sticky

    else ch k-down = if
      vic n-vrows @ < if
        _tscx @ -1 = if  scxc _tscx !  then
        vic 1+ _tscx @ visual>logical  _cx ! _cy !
      then  true to sticky

    else ch k-left = if
      _cx @ 0> if
        _cy @ line@ drop _cx @ utf8-prev _cx !
      else
        _cy @ 1 > if  -1 _cy +!  _cy @ line-len@ _cx !  then
      then

    else ch k-right = if
      _cy @ line@ { la ll }
      _cx @ ll < if  la ll _cx @ utf8-next _cx !
      else  _cy @ n-lines @ < if  1 _cy +!  0 _cx !  then
      then

    else ch k-home = if
      vic vrow@ { vli2 vsc2 vec2 }  vsc2 _cx !

    else ch k-end = if
      vic vrow@ { vli3 vsc3 vec3 }  vec3 _cx !

    else ch k-ppage = if
      vic th - 1 max { tvi }
      _tscx @ -1 = if  scxc _tscx !  then
      tvi _tscx @ visual>logical  _cx ! _cy !
      true to sticky

    else ch k-npage = if
      vic th + n-vrows @ min { tvi }
      _tscx @ -1 = if  scxc _tscx !  then
      tvi _tscx @ visual>logical  _cx ! _cy !
      true to sticky

    else ch k-bs = ch 127 = or ch 8 = or if
      _cx @ 0> if
        _cy @ line@ { la ll }
        la ll _cx @ utf8-prev { ncx }
        ncx ll _cx @ - + allocate throw { nb }
        la nb ncx move
        la _cx @ + nb ncx + ll _cx @ - move
        nb ncx ll _cx @ - + _cy @ line-replace!
        ncx _cx !  true _dirty !
      else
        _cy @ 1 > if
          _cy @ line@ { ca cl }
          _cy @ 1- line@ { pa pl }
          pl cl + allocate throw { nb }
          pa nb pl move  ca nb pl + cl move
          nb pl cl + _cy @ 1- line-replace!
          _cy @ lines-delete
          -1 _cy +!  pl _cx !  true _dirty !
        then
      then

    else ch k-dc = if
      _cy @ line@ { la ll }
      _cx @ ll < if
        la ll _cx @ utf8-next { nx }
        ll nx - { rl2 }
        _cx @ rl2 + allocate throw { nb }
        la nb _cx @ move
        la nx + nb _cx @ + rl2 move
        nb _cx @ rl2 + _cy @ line-replace!
        true _dirty !
      else
        _cy @ n-lines @ < if
          _cy @ 1+ line@ { na nl }
          _cy @ line@ { la ll }
          ll nl + allocate throw { nb }
          la nb ll move  na nb ll + nl move
          nb ll nl + _cy @ line-replace!
          _cy @ 1+ lines-delete  true _dirty !
        then
      then

    else ch 10 = ch 13 = or ch k-nl = or if
      _cy @ line@ { la ll }
      ll _cx @ - { rest-l }
      _cx @ allocate throw { nb1 }
      la nb1 _cx @ move
      nb1 _cx @ _cy @ line-replace!
      _cy @ 1+ lines-insert
      rest-l allocate throw { nb2 }
      la _cx @ + nb2 rest-l move
      nb2 rest-l _cy @ 1+ line!
      1 _cy +!  0 _cx !  true _dirty !

    else ch 9 = if
      _tab4 TAB-WIDTH ed-insert

    else ch 19 = if   \ Ctrl+S
      c-path lines-save
      c-path _cy @ _cx @ save-cursor
      false _dirty !  s" saved" ed-set-msg

    else ch 23 = ch 17 = or ch 27 = or if   \ Ctrl+W / Ctrl+Q / Esc
      c-path lines-save
      c-path _cy @ _cx @ save-cursor
      0 nc:curs-set drop  exit

    else ch 7 = if   \ Ctrl+G
      s" go to line: " prompt-input { ra rl }
      rl 0> if
        true { ok }
        rl 0 ?do  ra i + c@ [char] 0 < ra i + c@ [char] 9 > or if  false to ok  then  loop
        ok if
          0 { n }
          rl 0 ?do  n 10 * ra i + c@ [char] 0 - + to n  loop
          n 1 max n-lines @ min _cy !  0 _cx !
        then
      then
      1 nc:curs-set drop

    else ch -1 = ul 0> and if
      ua ul ed-insert

    else ch 32 >= ch 126 <= and if
      ch _sc c!  _sc 1 ed-insert

    then then then then then then then then then then then then then then then then then

    sticky if else  -1 _tscx !  then
  again ;

\ ═══════════════════════════════════════════════════════════════════════════════
\ Main
\ ═══════════════════════════════════════════════════════════════════════════════

: main ( -- )
  nc:locale drop
  nc:initscr drop
  cache-constants
  nc:raw drop
  nc:noecho drop
  nc:stdscr true nc:keypad drop
  nc:defcolors drop
  25 nc:escdelay drop
  0 nc:curs-set drop
  init-paths
  ensure-docs-dir

  argc @ 1 > if
    1 arg fs>c { fpath }
    fpath os:fexists 0= if
      fpath c>s w/o create-file throw close-file throw
    then
    fpath wr-editor
  else
    begin
      file-browser { fp }
      fp 0<> while
      fp wr-editor
      fp free throw
    repeat
  then

  nc:endwin drop
  s" bye." type cr ;

main
bye
