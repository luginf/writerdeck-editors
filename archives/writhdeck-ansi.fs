\ writhdeck-ansi.fs — pure gforth text editor, ANSI terminal, no C FFI
\ Usage: gforth writhdeck-ansi.fs [filename]
decimal

\ ─── compatibility ───────────────────────────────────────────────────────────
: 2+  2 + ;  : 2-  2 - ;  : nip  swap drop ;
: >=   < invert ;  : <=   > invert ;  : u>=  u< invert ;
\ gforth-specific — no ANS equivalent:
\   stdout system argc arg
: (u.) ( u -- )  dup 10 u>= if dup 10 / recurse 10 mod then [char] 0 + emit ;

\ ─── string helper ───────────────────────────────────────────────────────────
: c-strlen ( ca -- n )  dup begin dup c@ while 1+ repeat swap - ;
: c>s      ( ca -- a l )  dup c-strlen ;

: s-dup { a l -- a' l }
  l allocate throw  a over l move  l ;

\ ─── ANSI terminal ───────────────────────────────────────────────────────────
: esc!      27 emit ;
: csi!      esc! [char] [ emit ;
\ 0-based row col → ANSI (1-based)
: at-xy ( row col -- )  csi! swap 1+ (u.) [char] ; emit 1+ (u.) [char] H emit ;
: cls       csi! s" 2J" type ;
: eol       csi! s" K" type ;
: rev       csi! s" 7m" type ;
: aoff      csi! s" 0m" type ;
: cur-hide  csi! s" ?25l" type ;
: cur-show  csi! s" ?25h" type ;
: flush-out  stdout flush-file drop ;

variable TW  80 TW !   \ terminal width
variable TH  24 TH !   \ terminal height

: get-term-size ( -- )
  csi! s" 999;999H" type  csi! s" 6n" type  flush-out
  key drop  key drop  \ ESC [
  0 begin key dup [char] ; <> while [char] 0 - swap 10 * + repeat drop  \ rows
  0 begin key dup [char] R <> while [char] 0 - swap 10 * + repeat drop  \ cols
  TW !  TH ! ;  \ stack: rows cols → TW=cols, TH=rows

\ ─── raw terminal ────────────────────────────────────────────────────────────
: term-raw   s" stty raw -echo 2>/dev/null" system ;
: term-cook  s" stty sane 2>/dev/null" system ;

\ ─── key reading ─────────────────────────────────────────────────────────────
-1 constant K-UP      -2 constant K-DOWN
-3 constant K-LEFT    -4 constant K-RIGHT
-5 constant K-HOME    -6 constant K-END
-7 constant K-PPAGE   -8 constant K-NPAGE
-9 constant K-DEL    -10 constant K-BS
-11 constant K-ESC   -12 constant K-ENTER

create _kb 8 allot  variable _kn  0 _kn !
: key+ ( c -- )  _kn @ _kb + c!  1 _kn +! ;
: key* ( -- c )  _kn @ if -1 _kn +! _kn @ _kb + c@ else key then ;
: skip~ begin key* [char] ~ = until ;

: read-esc ( -- n )
  key* { b1 }
  b1 [char] [ <> b1 [char] O <> and if  b1 key+  K-ESC exit  then
  key* { b2 }
  b2 [char] A = if K-UP    exit then   b2 [char] B = if K-DOWN  exit then
  b2 [char] C = if K-RIGHT exit then   b2 [char] D = if K-LEFT  exit then
  b2 [char] H = if K-HOME  exit then   b2 [char] F = if K-END   exit then
  b2 [char] 0 >= b2 [char] 9 <= and if
    b2 [char] 0 - { n }
    begin
      key* dup [char] ~ = if drop
        n 1 = if K-HOME  exit then   n 3 = if K-DEL   exit then
        n 4 = if K-END   exit then   n 5 = if K-PPAGE exit then
        n 6 = if K-NPAGE exit then   0 exit
      then
      dup [char] ; = if drop skip~ 0 exit then
      [char] 0 - n 10 * + to n
    again
  then  0 ;

: getkey ( -- n )
  key* dup 27 = if drop read-esc exit then
  dup 127 = over 8 = or if drop K-BS    exit then
  dup 13  = over 10 = or if drop K-ENTER exit then ;

\ ─── UTF-8 ───────────────────────────────────────────────────────────────────
: u8len ( b -- n )
  dup $80 u< if drop 1 exit then   dup $E0 u< if drop 2 exit then
  dup $F0 u< if drop 3 exit then   drop 4 ;

: u8next { a l cx -- cx' }
  cx l >= if cx exit then  a cx + c@ u8len cx + l min ;
: u8prev { a l cx -- cx' }
  cx 0= if 0 exit then  cx 1- { p }
  begin p 0> a p + c@ $C0 and $80 = and while -1 p +! repeat  p ;

: cx>col { a cx -- col }   \ byte offset → visual column number
  0 { col } 0 { i }
  begin i cx < while  a i + c@ u8len i + to i  1 col + to col  repeat  col ;
: col>cx { a l col -- cx } \ visual column → byte offset (clamps to l)
  0 { cx } 0 { c }
  begin cx l < c col < and while  a cx + c@ u8len cx + to cx  1 c + to c  repeat  cx ;

\ ─── text buffer ─────────────────────────────────────────────────────────────
4000 constant MAXLI
create _la MAXLI cells allot   \ heap address per line (1-based index)
create _ll MAXLI cells allot   \ byte length per line
variable NL  0 NL !

: init-bufs  _la MAXLI cells 0 fill  _ll MAXLI cells 0 fill ;

: la@ ( li -- a )   1- cells _la + @ ;
: ll@ ( li -- l )   1- cells _ll + @ ;
: la! ( a  li -- )  1- cells _la + ! ;
: ll! ( l  li -- )  1- cells _ll + ! ;
: li@ ( li -- a l ) dup la@ swap ll@ ;

: li! { a l li -- }
  li la@ ?dup if free throw then
  l 0= if  0 li la!  0 li ll!  exit  then
  l allocate throw  a over l move  dup li la!  l li ll! ;

\ Pointer-move line src to dst, freeing dst's old content; clears src
: li-mv { src dst -- }
  dst la@ ?dup if free throw then
  src la@ dst la!  src ll@ dst ll!  0 src la!  0 src ll! ;

: buf-clear ( -- )
  NL @ 0 ?do  i 1+ la@ ?dup if free throw then  loop  0 NL ! ;

: buf-push { a l -- }
  NL @ MAXLI < if  1 NL +!  a l NL @ li!  then ;

\ Insert blank line at 1-based pos, shifting pos..NL down to pos+1..NL+1
: buf-ins { pos -- }
  NL @ MAXLI < if
    NL @ { src }
    begin src pos >= while
      src src 1+ li-mv  \ move src → src+1, clears src
      -1 src + to src
    repeat
    0 pos la!  0 pos ll!  1 NL +!
  then ;

\ Delete line at 1-based pos, shifting pos+1..NL up to pos..NL-1
: buf-del { pos -- }
  NL @ 1+ pos 1+ ?do  i  i 1-  li-mv  loop  -1 NL +! ;

1024 constant RLBUF  create _rl RLBUF allot
create _fn  512 allot  0 _fn c!   \ filename (c-string, set by wr-editor)

: buf-load { a l -- }
  buf-clear
  l 0= if  s" " buf-push  exit  then
  a l r/o open-file if drop  s" " buf-push  exit  then  { fid }
  begin
    _rl RLBUF fid read-line throw  { len more }
    len 0> more or if  _rl len buf-push  then  \ push last line even without newline
    more 0=
  until
  fid close-file throw
  NL @ 0= if  s" " buf-push  then ;

create _nl-b 1 allot  10 _nl-b c!

: buf-save ( -- )   \ saves to _fn (set by wr-editor)
  _fn c>s w/o create-file throw  { fid }
  NL @ 1+ 1 ?do
    i li@ fid write-file throw
    _nl-b 1 fid write-file throw
  loop
  fid close-file throw ;

\ ─── wrap map ────────────────────────────────────────────────────────────────
\ Each entry: ( li sc ec ) — logical line, start-byte, end-byte (exclusive)
6000 constant MAXVR
create _vm MAXVR 3 * cells allot
variable NVR  0 NVR !

: vr@ ( vi -- li sc ec )   \ fetch visual row fields
  3 * cells _vm +  dup @  swap cell+  dup @  swap cell+  @ ;
: vr-add { li sc ec -- }
  NVR @ MAXVR < if
    NVR @ 3 * cells _vm +  li over !  cell+  sc over !  cell+  ec swap !
    1 NVR +!
  then ;

: wrap-line { li tw -- }
  li li@ { a l }
  l 0= if  li 0 0 vr-add  exit  then
  0 { sc }
  begin sc l < while
    sc { ec }  0 { col }
    begin ec l < col tw < and while
      a ec + c@ u8len ec + to ec  1 col + to col
    repeat
    ec l < if   \ try to word-break at last space
      ec { bp }
      begin bp sc > a bp 1- + c@ bl > and while -1 bp +! repeat
      bp sc > if  bp to ec  then
    then
    li sc ec vr-add
    a ec + c@ bl = ec l < and if  ec 1+ else ec then  to sc
  repeat ;

: build-map ( -- )
  0 NVR !  NL @ 1+ 1 ?do  i TW @ 1- wrap-line  loop ;

\ ─── editor state ────────────────────────────────────────────────────────────
variable _cy   1 _cy !    \ cursor logical line, 1-based
variable _cx   0 _cx !    \ cursor byte offset in current line
variable _svy  0 _svy !   \ scroll: index of first visible visual row
variable _tgc -1 _tgc !   \ sticky target column for up/down (-1 = recompute)
variable _dirty  false _dirty !
create _msg 128 allot  0 _msg c!   \ status message (c-string)

: msg! { a l -- }  l 127 min  _msg swap move  _msg l + 0 swap c! ;

\ ─── cursor/scroll helpers ───────────────────────────────────────────────────
: cur-vi ( -- vi )  \ visual row index containing cursor
  NVR @ 0 ?do
    i vr@ { li sc ec }
    li _cy @ = if
      _cx @ sc >= _cx @ ec < and if  i unloop exit  then
      ec li ll@ >=                   if  i unloop exit  then
    then
  loop  0 ;

: vi-cx { vi tgcol -- cx }  \ cx in row vi closest to target column
  vi vr@ { li sc ec }
  li la@ sc +  ec sc -  tgcol  col>cx  sc + ;

: scroll-ensure ( -- )
  cur-vi { vi }
  TH @ 1- { ch }
  vi _svy @ < if  vi _svy !  then
  vi _svy @ ch + >= if  vi ch - 1+ _svy !  then
  _svy @ 0 max _svy ! ;

\ ─── display ─────────────────────────────────────────────────────────────────
: draw-text ( -- )
  TH @ 1- 0 ?do
    i 0 at-xy
    _svy @ i + { vi }
    vi NVR @ < if
      vi vr@ { li sc ec }
      ec sc > if  li la@ sc + ec sc - type  then
    then
    eol
  loop ;

: draw-status ( -- )
  TH @ 1- 0 at-xy  rev
  _dirty @ if  s" * " else  s"   " then  type
  _fn c@ if  _fn c-strlen _fn swap type  else  s" [new]" type  then
  s"   Ln " type   _cy @ (u.)
  s"  Col " type   _cy @ la@ _cx @ cx>col 1+ (u.)
  _msg c@ if  s"   | " type  _msg c-strlen _msg swap type  then
  eol  aoff ;

: draw-cursor ( -- )
  cur-vi { vi }
  vi _svy @ - { row }
  row 0>= row TH @ 1- < and if
    vi vr@ { li sc ec }
    row  li la@ _cx @ cx>col  at-xy
  then ;

: redraw ( -- )
  cur-hide  build-map  scroll-ensure
  draw-text  draw-status  draw-cursor  cur-show  flush-out ;

\ ─── edit operations ─────────────────────────────────────────────────────────
create _1b 1 allot   \ 1-byte scratch for single-char insert

: ed-ins { b -- }   \ insert one byte b at cursor
  b _1b c!
  _cy @ li@ { a l }
  l 1+ allocate throw { nb }
  a nb _cx @ move
  b nb _cx @ + c!
  a _cx @ + nb _cx @ 1+ + l _cx @ - move
  nb l 1+ _cy @ li!  nb free throw
  1 _cx +!  true _dirty ! ;

: ed-enter ( -- )   \ split line at cursor
  _cy @ li@ { a l }
  a          _cx @          s-dup { ha hl }   \ head: bytes before cursor
  a _cx @ +  l _cx @ -      s-dup { ta tl }   \ tail: bytes after cursor
  ha hl _cy @ li!                              \ store head (frees old line)
  ha free throw
  _cy @ 1+ buf-ins                             \ shift lines down
  ta tl _cy @ 1+ li!                           \ store tail in new line
  ta free throw
  0 _cx !  1 _cy +!  true _dirty ! ;

: ed-bs ( -- )   \ backspace
  _cx @ 0> if
    _cy @ li@ { a l }
    a l _cx @ u8prev { ncx }
    ncx l _cx @ - + allocate throw { nb }
    a nb ncx move
    a _cx @ + nb ncx + l _cx @ - move
    nb ncx l _cx @ - + _cy @ li!  nb free throw
    ncx _cx !  true _dirty !
  else
    _cy @ 1 > if
      _cy @ 1- ll@ { plen }
      _cy @ 1- la@ { pa }
      _cy @ li@ { ca cl }
      plen cl + allocate throw { nb }
      pa nb plen move  ca nb plen + cl move
      nb plen cl + _cy @ 1- li!  nb free throw
      _cy @ buf-del
      -1 _cy +!  plen _cx !  true _dirty !
    then
  then ;

: ed-del ( -- )   \ delete key
  _cy @ li@ { a l }
  _cx @ l < if
    a l _cx @ u8next { ncx }
    _cx @ l ncx - + allocate throw { nb }
    a nb _cx @ move
    a ncx + nb _cx @ + l ncx - move
    nb _cx @ l ncx - + _cy @ li!  nb free throw
    true _dirty !
  else
    _cy @ NL @ < if
      _cy @ li@ { ca cl }
      _cy @ 1+ li@ { na nl }
      cl nl + allocate throw { nb }
      ca nb cl move  na nb cl + nl move
      nb cl nl + _cy @ li!  nb free throw
      _cy @ 1+ buf-del  true _dirty !
    then
  then ;

: ed-kill ( -- )   \ Ctrl+K: delete from cursor to end of line
  _cy @ li@ { a l }
  _cx @ l < if
    a _cx @ _cy @ li!  true _dirty !
  then ;

: ed-goto-prompt ( -- )   \ Ctrl+G: go to line number
  0 TH @ 1- at-xy  rev  s" Goto line: " type  eol  aoff  flush-out
  0 { n }
  begin
    key* { ch }
    ch 13 = ch 10 = or if
      n 1 max NL @ min _cy !  0 _cx !  exit
    then
    ch 27 = if exit then
    ch [char] 0 >= ch [char] 9 <= and if
      ch [char] 0 - n 10 * + to n
      ch emit  flush-out
    then
  again ;

\ ─── editor main loop ────────────────────────────────────────────────────────
: nav-up ( -- )
  _tgc @ -1 = if  _cy @ la@ _cx @ cx>col _tgc !  then
  cur-vi { vi }
  vi 0> if
    vi 1- _tgc @ vi-cx _cx !
    vi 1- vr@ nip drop _cy !
  then ;

: nav-down ( -- )
  _tgc @ -1 = if  _cy @ la@ _cx @ cx>col _tgc !  then
  cur-vi { vi }
  vi NVR @ 1- < if
    vi 1+ _tgc @ vi-cx _cx !
    vi 1+ vr@ nip drop _cy !
  then ;

: nav-pgup ( -- )
  _tgc @ -1 = if  _cy @ la@ _cx @ cx>col _tgc !  then
  cur-vi { vi }
  vi TH @ 1- - 0 max { nvi }
  nvi _tgc @ vi-cx _cx !
  nvi vr@ nip drop _cy ! ;

: nav-pgdn ( -- )
  _tgc @ -1 = if  _cy @ la@ _cx @ cx>col _tgc !  then
  cur-vi { vi }
  vi TH @ 1- + NVR @ 1- min { nvi }
  nvi _tgc @ vi-cx _cx !
  nvi vr@ nip drop _cy ! ;

: wr-editor { fa fl -- }   \ Forth string filename
  fl 511 min { cl }
  fa _fn cl move  0 _fn cl + c!   \ store null-terminated copy in _fn
  fa fl buf-load
  false _dirty !  -1 _tgc !  0 _svy !  1 _cy !  0 _cx !
  cls  redraw

  begin
    getkey { k }
    k K-UP = k K-DOWN = or k K-LEFT = or k K-RIGHT = or
    k K-PPAGE = or k K-NPAGE = or  0= if  -1 _tgc !  then

    k K-UP    = if  nav-up    else
    k K-DOWN  = if  nav-down  else
    k K-LEFT  = if
      _cx @ 0> if
        _cy @ li@ _cx @ u8prev _cx !
      else
        _cy @ 1 > if  -1 _cy +!  _cy @ ll@ _cx !  then
      then
    else
    k K-RIGHT = if
      _cy @ li@ { a l }
      _cx @ l < if  a l _cx @ u8next _cx !
      else  _cy @ NL @ < if  1 _cy +!  0 _cx !  then  then
    else
    k K-HOME  = if  0 _cx !  else
    k K-END   = if  _cy @ ll@ _cx !  else
    k K-PPAGE = if  nav-pgup  else
    k K-NPAGE = if  nav-pgdn  else
    k K-BS    = if  ed-bs     else
    k K-DEL   = if  ed-del    else
    k K-ENTER = if  ed-enter  else
    k 9       = if  4 0 do 32 ed-ins loop  else   \ Tab → 4 spaces
    k 11      = if  ed-kill   else                 \ Ctrl+K
    k 19      = if                                 \ Ctrl+S
      buf-save  false _dirty !  s" saved" msg!
    else
    k 17 = k 23 = or k K-ESC = or if              \ Ctrl+Q / Ctrl+W / ESC
      _dirty @ if  buf-save  then
      cls  0 0 at-xy  flush-out  exit
    else
    k 7 = if  ed-goto-prompt  else                 \ Ctrl+G
    k 32 >= k 256 < and if  k ed-ins               \ printable ASCII byte
    then then then then then then then then then then then then then then then then then

    redraw
  again ;

\ ─── entry point ─────────────────────────────────────────────────────────────
: main ( -- )
  init-bufs
  term-raw
  get-term-size
  \ arg indices vary by gforth version: try 1 (script as arg0), fallback to 0
  argc @ 1 > if  1 arg wr-editor  else
  argc @ 0 > if  0 arg wr-editor  else
  s" Usage: gforth writhdeck-ansi.fs filename" type cr
  then then
  term-cook ;

main
bye
