all: build

clean:
	rm -rf public/

git.submodule:
	git submodule update --init

build:
ifeq ($(shell command -v hugo 2> /dev/null && echo 1 || echo 0), 0)
	@echo "hugo não esta instalado"
	exit 1
endif
	hugo -v -b https://www.lucassabreu.net.br

server:
	hugo server -v
