check: ; luacheck --std max jeejah.lua bencode.lua

run: ; bin/jeejah

publish: rockspecs/jeejah-$(VERSION)-1.rockspec
	luarocks upload --sign --api-key $(shell pass luarocks-api-key) $<
