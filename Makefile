PREFIX ?= /usr/local

basedir = ${DESTDIR}${PREFIX}

build/efa.1: bin/efa
	mkdir -p build
	pod2man $< > $@

install: build/efa.1
	mkdir -p ${basedir}/bin ${basedir}/share/man/man1
	cp bin/efa ${basedir}/bin/efa
	cp build/efa.1 ${basedir}/share/man/man1/efa.1
	chmod 755 ${basedir}/bin/efa
	chmod 644 ${basedir}/share/man/man1/efa.1

uninstall:
	rm -f ${basedir}/bin/efa
	rm -f ${basedir}/share/man/man1/efa.1

clean:
	rm -rf build

.PHONY: install uninstall clean
