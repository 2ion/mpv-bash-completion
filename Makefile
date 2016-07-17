PREFIX ?= /usr

all: mpv check

mpv: gen.lua
	@env MPV_BASHCOMPGEN_VERBOSE=1 lua $< > $@

check: mpv
	@echo Checking Bash syntax...
	@bash -n mpv

clean:
	@rm mpv

install: mpv
	@install -Dm644 mpv $(DESTDIR)$(PREFIX)/share/bash-completion/completions/mpv
