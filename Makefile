FENNEL ?= fennel

DESTDIR ?=
PREFIX ?= /usr/local
BIN_DIR ?= $(PREFIX)/bin

run: ; $(FENNEL) $(FENNELFLAGS) main.fnl 7888

lint: ; fennel-ls --lint jeejah.fnl

jeejah: main.fnl jeejah.fnl bencode.lua
	$(FENNEL) $(FENNELFLAGS) --compile --require-as-include $< > $@

fennel.lua: ../fennel/fennel.lua ; cp $< $@

install: jeejah
	mkdir -p $(DESTDIR)$(BIN_DIR) && cp $< $(DESTDIR)$(BIN_DIR)/

clean: ; rm -f jeejah

.PHONY: lint clean run install
