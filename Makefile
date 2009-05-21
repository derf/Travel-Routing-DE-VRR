prefix ?= /usr/local

build/efa.1: bin/efa
	mkdir -p build
	pod2man $< > $@

install: build/efa.1
	install -m 755 -D bin/efa $(prefix)/bin/efa
	install -m 644 -D build/efa.1 $(prefix)/share/man/man1/efa.1

uninstall:
	$(RM) $(prefix)/bin/efa
	$(RM) $(prefix)/share/man/man1/efa.1

clean:
	$(RM) -r build

.PHONY: install uninstall clean
