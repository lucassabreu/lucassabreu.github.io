all: build

clean:
	rm -rf public/

git.submodule:
	git submodule update --init

build:
	hugo -v -b https://www.lucassabreu.net.br

server:
	$$BROWSER http://localhost:1313
	hugo server -v --minify
