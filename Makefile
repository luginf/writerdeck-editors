# Makefile for writhdeck modular build
# Concatenates source modules to generate standalone script files
#
# Usage:
#   make                              # Build with all available languages from src/i18n/
#   make LANGUAGES="fr"               # Build with French only (English always included as fallback)
#   make LANGUAGES="en fr de es"      # Build with specific languages
#   make LANGUAGES="de es"            # Build with German and Spanish (English always included as fallback)

AVAILABLE_LANGS := $(patsubst src/i18n/%.tcl,%,$(wildcard src/i18n/*.tcl))
LANGUAGES ?= $(AVAILABLE_LANGS)
ALL_LANGS := en $(filter-out en,$(LANGUAGES))
GUI_SRCS  := src/state.tcl src/config.tcl src/common.tcl src/gui.tcl src/tui.tcl src/main.tcl
CLI_SRCS  := src/state.tcl src/config.tcl src/common.tcl src/tui.tcl src/main-cli.tcl
I18N_FILES := $(patsubst %,src/i18n/%.tcl,$(ALL_LANGS))
SEP       := ===========================================================================

.PHONY: all clean .FORCE

all: writhdeck.tcl writhdeck-cli.tcl

writhdeck.tcl: src/boot.tcl $(GUI_SRCS) $(I18N_FILES) Makefile
	@rm -f $@
	@cat src/boot.tcl > $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "state.tcl" "$(SEP)" >> $@
	@cat src/state.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "config.tcl" "$(SEP)" >> $@
	@cat src/config.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "i18n ($(LANGUAGES))" "$(SEP)" >> $@
	@for f in $(I18N_FILES); do cat $$f >> $@; done
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "common.tcl" "$(SEP)" >> $@
	@cat src/common.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "gui.tcl" "$(SEP)" >> $@
	@cat src/gui.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "tui.tcl" "$(SEP)" >> $@
	@cat src/tui.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "main.tcl" "$(SEP)" >> $@
	@cat src/main.tcl >> $@
	@chmod +x $@
	@echo "Built $@ (GUI+TUI, languages: $(ALL_LANGS))"

writhdeck-cli.tcl: src/boot-cli.tcl $(CLI_SRCS) $(I18N_FILES) Makefile
	@rm -f $@
	@cat src/boot-cli.tcl > $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "state.tcl" "$(SEP)" >> $@
	@cat src/state.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "config.tcl" "$(SEP)" >> $@
	@cat src/config.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "i18n ($(LANGUAGES))" "$(SEP)" >> $@
	@for f in $(I18N_FILES); do cat $$f >> $@; done
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "common.tcl" "$(SEP)" >> $@
	@cat src/common.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "tui.tcl" "$(SEP)" >> $@
	@cat src/tui.tcl >> $@
	@printf '\n# %s\n# %s\n# %s\n' "$(SEP)" "main-cli.tcl" "$(SEP)" >> $@
	@cat src/main-cli.tcl >> $@
	@chmod +x $@
	@echo "Built $@ (TUI-only, languages: $(ALL_LANGS))"

clean:
	rm -f writhdeck.tcl writhdeck-cli.tcl
	@echo "Cleaned build artifacts"

.PHONY: test-gui test-cli test

test-gui: writhdeck.tcl
	@echo "Testing writhdeck.tcl (GUI mode)..."
	@wish writhdeck.tcl --help > /dev/null && echo "✓ GUI version loads"

test-cli: writhdeck-cli.tcl
	@echo "Testing writhdeck-cli.tcl (TUI mode)..."
	@tclsh writhdeck-cli.tcl --help > /dev/null && echo "✓ CLI version loads"

test: test-gui test-cli
	@echo "All tests passed"
