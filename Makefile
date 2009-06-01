prefix ?= /usr/local

build/efa.1: bin/efa
	mkdir -p build
	pod2man $< > $@

install: build/efa.1
	mkdir -p $(prefix)/bin $(prefix)/share/man/man1
	cp bin/efa $(prefix)/bin/efa
	cp build/efa.1 $(prefix)/share/man/man1/efa.1

uninstall:
	rm -f $(prefix)/bin/efa
	rm -f $(prefix)/share/man/man1/efa.1

clean:
	rm -rf build

.PHONY: install uninstall clean
