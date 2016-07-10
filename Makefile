PREFIX ?= /usr

all: mpv check

mpv: gen.lua
	env MPV_BASHCOMPGEN_VERBOSE=1 lua $< > $@

check: mpv
	bash -n mpv

install: mpv
	install -Dm644 mpv $(DESTDIR)$(PREFIX)/share/bash-completion/completions/mpv
