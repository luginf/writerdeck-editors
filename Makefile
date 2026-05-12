# Makefile for writhdeck modular build
# Concatenates source modules to generate standalone script files
#
# Usage:
#   make                                              # Build GUI with all (languages, schemes), CLI with en+fr, default+alt01
#   make LANGUAGES="fr"                               # GUI: French only (English always included)
#   make LANGUAGES="en fr de es"                      # GUI: specific languages
#   make CLI_LANGUAGES="en fr de es ko no"            # CLI: specific languages (by default: en fr)
#   make SCHEMES="default solarized gruvbox"          # GUI: specific schemes (by default: all)
#   make CLI_SCHEMES="default alt01"                  # CLI: specific schemes (by default: default alt01)
#
# Typical builds:
#   make                                              # Standard: full GUI, minimal CLI
#   make LANGUAGES="en" SCHEMES="default"             # Minimal: GUI en + default scheme only
#   make CLI_LANGUAGES="en fr de es" CLI_SCHEMES="default solarized gruvbox everforest nord alt01"  # Full CLI

AVAILABLE_LANGS := $(patsubst src/i18n/%.tcl,%,$(wildcard src/i18n/*.tcl))
AVAILABLE_SCHEMES := $(patsubst src/schemes/%.tcl,%,$(wildcard src/schemes/*.tcl))
LANGUAGES ?= $(AVAILABLE_LANGS)
CLI_LANGUAGES ?= en fr
SCHEMES ?= $(AVAILABLE_SCHEMES)
CLI_SCHEMES ?= default alt01
GUI_LANGS := en $(filter-out en,$(LANGUAGES))
CLI_LANGS := en $(filter-out en,$(CLI_LANGUAGES))
GUI_I18N_FILES := $(patsubst %,src/i18n/%.tcl,$(GUI_LANGS))
CLI_I18N_FILES := $(patsubst %,src/i18n/%.tcl,$(CLI_LANGS))
GUI_SCHEME_FILES := $(patsubst %,src/schemes/%.tcl,$(SCHEMES))
CLI_SCHEME_FILES := $(patsubst %,src/schemes/%.tcl,$(CLI_SCHEMES))
SEP       := ===========================================================================

GUI_SRCS  := src/state.tcl src/config.tcl $(GUI_SCHEME_FILES) src/common.tcl src/gui.tcl src/tui.tcl src/main.tcl
CLI_SRCS  := src/state.tcl src/config.tcl $(CLI_SCHEME_FILES) src/common.tcl src/tui.tcl src/main-cli.tcl

.PHONY: all clean .FORCE

all: writhdeck.tcl writhdeck-cli.tcl

writhdeck.tcl: src/boot.tcl $(GUI_SRCS) $(GUI_I18N_FILES) Makefile
	@rm -f $@
	@cat src/boot.tcl > $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "state.tcl" "$(SEP)" >> $@
	@cat src/state.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "config.tcl" "$(SEP)" >> $@
	@cat src/config.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "schemes ($(SCHEMES))" "$(SEP)" >> $@
	@for f in $(GUI_SCHEME_FILES); do cat $$f >> $@; done
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "i18n ($(LANGUAGES))" "$(SEP)" >> $@
	@for f in $(GUI_I18N_FILES); do cat $$f >> $@; done
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "common.tcl" "$(SEP)" >> $@
	@cat src/common.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "gui.tcl" "$(SEP)" >> $@
	@cat src/gui.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "tui.tcl" "$(SEP)" >> $@
	@cat src/tui.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "main.tcl" "$(SEP)" >> $@
	@cat src/main.tcl >> $@
	@chmod +x $@
	@echo "Built $@ (GUI+TUI, languages: $(GUI_LANGS), schemes: $(SCHEMES))"

writhdeck-cli.tcl: src/boot-cli.tcl $(CLI_SRCS) $(CLI_I18N_FILES) Makefile
	@rm -f $@
	@cat src/boot-cli.tcl > $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "state.tcl" "$(SEP)" >> $@
	@cat src/state.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "config.tcl" "$(SEP)" >> $@
	@cat src/config.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "schemes ($(CLI_SCHEMES))" "$(SEP)" >> $@
	@for f in $(CLI_SCHEME_FILES); do cat $$f >> $@; done
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "i18n ($(CLI_LANGUAGES))" "$(SEP)" >> $@
	@for f in $(CLI_I18N_FILES); do cat $$f >> $@; done
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "common.tcl" "$(SEP)" >> $@
	@cat src/common.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "tui.tcl" "$(SEP)" >> $@
	@cat src/tui.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "main-cli.tcl" "$(SEP)" >> $@
	@cat src/main-cli.tcl >> $@
	@chmod +x $@
	@echo "Built $@ (TUI-only, languages: $(CLI_LANGS), schemes: $(CLI_SCHEMES))"

clean:
	rm -f writhdeck.tcl writhdeck-cli.tcl
	@echo "Cleaned build artifacts"

.PHONY: test-gui test-cli test test-i18n test-syntax test-runtime test-langs lint-doc

test-gui: writhdeck.tcl
	@echo "Testing writhdeck.tcl (GUI mode)..."
	@wish writhdeck.tcl --help > /dev/null && echo "✓ GUI version loads"

test-cli: writhdeck-cli.tcl
	@echo "Testing writhdeck-cli.tcl (TUI mode)..."
	@tclsh writhdeck-cli.tcl --help > /dev/null && echo "✓ CLI version loads"

test-i18n:
	@echo "Testing i18n translations..."
	@tclsh tests/test-i18n.tcl

test-syntax:
	@echo "Checking Tcl syntax..."
	@tclsh tests/test-syntax.tcl

test-runtime: writhdeck.tcl
	@echo "Checking runtime definitions..."
	@tclsh tests/test-runtime.tcl

test-langs:
	@echo "Testing builds with different language combinations..."
	@$(MAKE) clean > /dev/null && $(MAKE) LANGUAGES="fr" > /dev/null && echo "✓ LANGUAGES=fr (includes en automatically)"
	@$(MAKE) clean > /dev/null && $(MAKE) LANGUAGES="de es" > /dev/null && echo "✓ LANGUAGES=de es"
	@$(MAKE) clean > /dev/null && $(MAKE) > /dev/null && echo "✓ Default build (all languages)"

test: test-i18n test-syntax test-runtime test-gui test-cli test-langs
	@echo ""
	@echo "✓ All regression tests passed"

lint-doc:
	@echo "Aligning markdown table pipes..."
	@tclsh tools/align-tables.tcl writhdeck_MANUAL.md --inplace
	@tclsh tools/align-tables.tcl README.md --inplace
	@tclsh tools/align-tables.tcl README.fr.md --inplace
	@tclsh tools/align-tables.tcl CLAUDE.md --inplace
	@echo "✓ Documentation tables aligned"
