all: build

clean:
	rm -rf public/

git.submodule:
	git submodule update --init

build:
	./binaries/hugo -v -b https://www.lucassabreu.net.br

server:
	hugo server -v
