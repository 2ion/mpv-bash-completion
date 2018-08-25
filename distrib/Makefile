debian-stretch:
	mkdir -p ./src
	install -Dm755 ../gen.lua ./src/gen.lua
	docker run -v $(readlink -f ./src):/src debian:stretch bash -c 'apt-get update;apt-get -y install lua mpv;lua5.3 /src/gen.lua>/src/mpv'
