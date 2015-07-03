build:
	bash ./gen.sh > mpv

check: build
	bash -n mpv

install:
	install -Dm644 mpv $(DESTDIR)$(PREFIX)/etc/bash_completion.d/mpv
