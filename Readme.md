# JeeJah

An nREPL server for Lua.

## A what now?

The [nREPL protocol](https://github.com/clojure/tools.nrepl/#why-nrepl)
allows developers to embed a server in their programs to which
external programs can connect for development, debugging, etc.

The original implementation of the protocol was written in Clojure,
and most clients assume they will connect to a Clojure server; however
the protocol is quite agnostic about what language is being
evaluated. It supports evaluating snippets of code or whole files with
`print` and `io.write` redirected back to the connected client.

This library was originally written to add Emacs support to
[Bussard](https://gitlab.com/technomancy/bussard), a spaceflight
programming game. See the file `data/upgrades.lua`.

Currently only tested with [monroe](https://github.com/sanel/monroe/)
as a client, which runs in Emacs. Other clients exist for Vim,
Eclipse, and Atom, as well as several independent command-line
clients; however these may require some adaptation to work with Lua.

## Installation

    $ luarocks install --local jeejah

Make sure `~/.luarocks/bin` is on your `$PATH`.

Or from source:

    $ luarocks install --local luasocket
    $ luarocks install --local serpent
    $ luarocks install --local bencode

You can symlink `bin/jeejah` to your `$PATH` or something.

## Usage

You can launch a standalone nREPL server:

    $ jeejah

Accepts `--host` and `--port` args. Also accepts `--debug` flag.

You can use it as a library too, of course:

```lua
local jeejah = require("jeejah")
local coro = jeejah.start(host, port, {debug=true, sandbox={x=12}})
while true do coroutine.resume(coro) end
```

The function returns a coroutine which you'll need to repeatedly
resume in order to handle requests. Each accepted connection is stored
in a coroutine internal to that function; these are each repeatedly
resumed by the main coroutine.

Note that the sandbox feature is not well-tested or audited and should
not be trusted to provide robust security.

You can also pass in a `handlers` table where the keys are custom
[nREPL ops](https://github.com/clojure/tools.nrepl/blob/master/doc/ops.md)
you want to handle yourself.

## Completion

The included `monroe-lua-complete.el` file adds support for completion
to the Monroe client by querying the connected nREPL server for
possibilities. Simply invoke `completion-at-point` (bound to `C-M-i`
by default) when connected.

## Caveats

Lua 5.1 does not allow yielding coroutines from inside protected
calls, which means you cannot use `io.read`, though LuaJIT and
Lua 5.2+ allow it.

## License

Copyright © 2016 Phil Hagelberg and contributors

Distributed under the MIT license; see file LICENSE
