# JeeJah

An nREPL server for Lua.

Note that stdin is not currently implemented.

## Installation

    $ luarocks install --local jeejah

Make sure `~/.luarocks/bin` is on your `$PATH`.

Or from source:

    $ luarocks install --local luasocket
    $ luarocks install --local serpent
    $ luarocks install --local bencode

You can symlink `bin/jeejah` to your `$PATH` or something.

## Usage

    $ jeejah

Accepts `--host` and `--port` args. Also accepts `--debug` flag.

Currently only tested with [monroe](https://github.com/sanel/monroe/)
as a client. Install and run `M-x monroe`.

You can use it as a library too, of course:

```lua
local jeejah = require("jeejah")
local coro = jeejah(host, port, {debug=true, sandbox={x=12}})
while true do coroutine.resume(coro) end
```

The function returns a coroutine which you'll need to repeatedly
resume in order to handle requests. Each accepted connection is stored
in a coroutine internal to that function; these are each repeatedly
resumed by the main coroutine.

Note that the sandbox feature is not well-tested and should not be
trusted to provide security.

You can also pass in a `handlers` table where the keys are custom
[nREPL ops](https://github.com/clojure/tools.nrepl/blob/master/doc/ops.md)
you want to handle yourself.

## Completion

The included `monroe-lua-complete.el` file handles completion by
querying the connected nREPL server for possibilities. Simply invoke
`completion-at-point` (bound to `C-M-i` by default) when connected.

## License

Copyright © 2016 Phil Hagelberg and contributors

Distributed under the MIT license; see file LICENSE
