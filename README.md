
# FORRDECK

some simple editors for a writerdeck:

- forrdeck.lua : lua version
- forrdeck.py  : python version
- forrdeck.fs : gforth version (uses C bindings)
- forrdeck-ansi.fs : gforth version (no C bindings, simpler version) 
- forrdeck.tcl : tcl/tk version  ("wish forrdeck-tk.tcl file.txt")

Converted to lua and others with the help of LLM (Claude code)

Nano and micro are also great tools for simple writerdeck. Simple, yet powerful.  Scite is my editor of choice for using with a GUI.

Those simpler editors are some kind of proof-of-concept for alternatives or other usages. 


## Usage

lua forrdeck.lua : forrdeck mode, let you create and restore files from ~/Documents/forrdeck/ folder.
lua forrdeck.lua file.txt : editor mode, let you edit a file from any folder.

Same usage for the python and tcl versions.


forrdeck Tcl/Tk editor with configurable margins, font size, colors, fullscreen toggle, and chapter navigation via a custom marker or Markdown headings. All options live in  ~/Documents/forrdeck/forrdeck.ini.


## Summary

  Forrdeck — Feature Summary                                                                                   
                                                                                                               
  All versions share                                                                                           
                                                                                                               
  - Plain .txt file editor focused on distraction-free writing                                                 
  - Documents stored in ~/Documents/forrdeck/ (auto-created)                                                   
  - Configuration via ~/Documents/forrdeck/forrdeck.ini                                                        
  - File browser: list files sorted by modification date, open/create/rename/delete                            
  - Heading detection: configurable marker (= title =) + Markdown (# title)                                    
  - Table of contents overlay (TOC key configurable, default F11): jump to any heading                         
  - Word-wrapped display with configurable margins (in characters/lines for TUI)                               
  - Status bar: filename, line/column, word count                                                              
  - Help bar with key hints                                                                                    
  - Go to line (Ctrl+G)                                                                                        
  - Save (Ctrl+S), close/quit (Ctrl+W / Ctrl+Q / Esc)                                                          
  - UTF-8 input support                                                                                        
                                                                                                               
  ---                                                                                                          
  forrdeck.tcl — Tcl/Tk GUI + TUI (dual mode)                                                               
                                                                                                               
  GUI mode (default, requires Tk):
  - Graphical window with scrollable text editor and file browser                                              
  - Configurable pixel margins (horizontal + vertical), font size, colors (all via INI)                        
  - Fullscreen toggle (configurable key, default Alt+Enter)                                                    
  - Dynamic font resize: Ctrl++ / Ctrl+- (keyboard and numpad)                                                 
  - Heading lines highlighted in a distinct color                                                              
  - TOC as a popup dialog window                                                                               
  - Save as… (Ctrl+Shift+S) with overwrite confirmation                                                        
  - Help dialog (Ctrl+H or h in browser)                                                                       
  - Built-in Solarized Light theme (commented out in INI, ready to enable)                                     
  - Optional second docs folder (docs_dir INI key), shown as two labeled sections in the browser               
  - Ctrl+F : opens an inline search bar just above the status bar                                              
  - Search is live (matches are highlighted in real time as you type)
  - Enter : next match (wraps around)                                                                          
  - Shift+Enter : previous match     
  - Ctrl+F from the search bar : next match                                                                    
  - Esc : closes the bar and clears highlights              
  - Match counter displayed (3 matches)               
  - Search & Replace (Ctrl+H): inline replace bar with Replace (Enter) and Replace All (Ctrl+Enter); Tab       
  navigates between find/replace fields                                                                 
  - Line numbers: enabled via line_numbers = 1 in the .ini, synchronized with scroll                           
  - Cursor restore: position saved in .cursors.json (format compatible with the Lua version) on every
  save/close; toggled via cursor_restore = 1                                                                   
  - Ctrl+O: tk_getOpenFile dialog to open any file                                                             
  - F1: help (Ctrl+H was reassigned to replace)     
                                                            
                                                                                                               
  TUI mode (--no-gui flag, pure terminal via ANSI escapes):                                                    
  - Identical feature set to the GUI editor, rendered in the terminal                                          
  - Browser with » selection marker, section headers for dual-folder mode                                      
  - Vim-style navigation (j/k) + arrow keys, Home/End, PgUp/PgDn                                               
  - Sticky-column cursor on vertical movement                                                                  
  - Inline prompts (new file, rename, go to line, confirm delete/save)                                         
  - Bold rendering for heading lines                                                                           
   - Ctrl+F : opens a find: prompt at the bottom of the screen
  - Type a term, jumps to the first occurrence after the cursor (wraps around)                                 
  - Press Ctrl+F again without typing a new term (just Enter) to find the next occurrence
  - Displays not found: … if no match  
  - Undo (Ctrl+Z): 100-state stack; every destructive edit pushes a snapshot
  - Selection (Shift+↑↓←→): character-level visual highlight; Ctrl+A selects all                               
  - Copy/Cut/Paste (Ctrl+C / Ctrl+X / Ctrl+V): via xclip, xsel, or wl-copy (tried in cascade); multi-line paste
   handled                                                                                                     
  - Cursor restore: same JSON as GUI and Lua                                                                   
  - Line numbers: left column when line_numbers = 1, shown only on the first visual row of each paragraph      
  - Scroll indicator: mini ▐/│ bar in the rightmost column when content overflows the screen                   
  - Search & Replace (Ctrl+R): two consecutive find/replace prompts, global replacement with a counter
  - Ctrl+O: saves and returns to the browser  
  
  Ctrl+B behavior:                                                                                       
                                            
  - First press: sets the anchor at the current position, arrows extend the selection normally                 
  - Second press: cancels the selection
  - The help bar shows ^B sel or ^B cancel-sel depending on the state   
  
  
  ---                                                       
  forrdeck.lua — Lua TUI (lcurses)                                                                             
                                                                                                               
  - Requires lcurses + luafilesystem
  - Cursor position persisted across sessions in .cursors.json (shared format with Python version)             
  - UTF-8 aware editing (multi-byte character movement with utf8_prev_cx/utf8_next_cx)                         
  - Word count + character count in status bar                                                                 
  - Configurable margins in columns/rows (separate INI keys from Tk pixel values)                              
  - TOC as fullscreen overlay with scrolling                                                                   
  - Heading lines rendered in bold                                                                             
  - Robust KEY_F detection (handles lcurses versions where KEY_F is nil)                                       
                                                                                                               
  ---                                                       
  forrdeck.py — Python TUI (curses, stdlib)                                                                    
                                                            
  - No dependencies beyond Python 3.7+ standard library (optional windows-curses on Windows)
  - Cursor persistence in .cursors.json                                                                        
  - Basic editor with file browser, word-wrapped display, status bar
                                                                                                               
  ---                                                       
  forrdeck.fs — Forth TUI (gforth + ncurses FFI)                                                               
                                                                                                               
  - Requires gforth 0.7+ and libncurses
  - Uses C FFI to call ncurses directly                                                                        
  - Full-screen terminal editor with file browser           
                                                                                                               
  ---                                                       
  forrdeck-ansi.fs — Forth TUI (gforth, pure ANSI, no FFI)                                                     
                                                                                                               
  - Requires only gforth, no external C libraries
  - Pure ANSI escape sequences for terminal control                                                            
  - Can open a file passed as a command-line argument directly


## Credits

Based on https://github.com/lallero7/forrdeckForCMD, itself based on https://github.com/shmimel/bee-write-back/