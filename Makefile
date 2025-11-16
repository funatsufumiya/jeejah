LUA ?= lua
FENNEL ?= fennel

DESTDIR ?=
PREFIX ?= /usr/local
BIN_DIR ?= $(PREFIX)/bin

run: ; $(FENNEL) $(FENNELFLAGS) main.fnl 7888

lint: ; fennel-ls --lint jeejah.fnl

# could pull in luasocket as a submodule here; not that hard

jeejah: main.fnl jeejah.fnl bencode.lua
	echo "#!/usr/bin/env $(LUA)" > $@
	$(FENNEL) $(FENNELFLAGS) --compile --require-as-include $< >> $@
	chmod 755 $@

fennel.lua: ../fennel/fennel.lua ; cp $< $@

install: jeejah
	mkdir -p $(DESTDIR)$(BIN_DIR) && cp $< $(DESTDIR)$(BIN_DIR)/

clean: ; rm -f jeejah

.PHONY: lint clean run install
