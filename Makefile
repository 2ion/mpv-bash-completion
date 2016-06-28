PREFIX ?= /usr/local

all: mpv check

mpv: gen.lua
	env MPV_BASHCOMPGEN_VERBOSE=1 lua $< > $@

check: mpv
	bash -n mpv

install: mpv
	install -Dm644 mpv $(DESTDIR)$(PREFIX)/etc/bash_completion.d/mpv
