# JeeJah

An nREPL server for [Fennel](https://fennel-lang.org) and [Lua](https://lua.org).

**Notice**: this project is looking for a new maintainer.

## A what now?

The [nREPL protocol](https://nrepl.org/nrepl/index.html#_why_nrepl)
allows developers to embed a server in their programs to which
external programs can connect for development, debugging, etc.

The original implementation of the protocol was written in Clojure,
and many clients assume they will connect to a Clojure server; however
the protocol is quite agnostic about what language is being
evaluated. It supports evaluating snippets of code or whole files with
`print` and `io.write` redirected back to the connected client.

This library was originally written to add Emacs support to
[Bussard](https://gitlab.com/technomancy/bussard), a spaceflight
programming game.

Currently mainly tested with
[monroe](https://github.com/sanel/monroe/) and
[shevek](https://git.sr.ht/~technomancy/shevek/) as
clients. [grenchman](https://leiningen.org/grench.html) version 0.3.0+
works. Other clients exist for Vim, Eclipse, and Atom, as well as
several independent command-line clients; however these may require
some adaptation to work with Jeejah. If you try your favorite client
and find that it makes Clojure-specific assumptions, please report a
bug with it so that it can gracefully degrade when those assumptions
don't hold.

## Installation

The pure-Lua dependencies are included (`bencode`, `serpent`, and
`fennel`) but you will need to install `luasocket` yourself. If your
operating system does not provide it, you can install it using LuaRocks:

    $ luarocks install --local luasocket

Note that [LÖVE](https://love2d.org) ships with its own copy of
luasocket, so there is no need to install it there.

You can symlink `bin/jeejah` to your `$PATH` or something.

## Usage

You can launch a standalone nREPL server:

    $ bin/jeejah

Pass in a `--fennel` flag to start a server for evaluating Fennel code
instead of Lua. Accepts a `--port` argument and a `--debug` flag.

You can use it as a library too, of course:

```lua
local jeejah = require("jeejah")
local coro = jeejah.start(port, {debug=true, sandbox={x=12}})
```

The `start` function takes a `port` argument as well as an `options`
table. The `opts` table takes a few options:

* `debug`: Log more.
* `foreground`: Leave the server running in the foreground and skip the
  step of resuming the coroutine.
* `timeout`: Override the default timeout (in seconds).
* `fennel`: Evaluate code as fennel.
* `serializer`: Replace `serpent.block` with the provided function to
  serialize objects to string.

The function returns a coroutine which you'll need to repeatedly
resume in order to handle requests. Each accepted connection is stored
in a coroutine internal to that function; these are each repeatedly
resumed by the main coroutine.

Note that the sandbox feature is not well-tested or audited and should
not be trusted to provide robust security. It currently only works
with Lua 5.1 and LuaJIT.

You can also pass in a `handlers` table where the keys are custom
[nREPL ops](https://nrepl.org/nrepl/ops.html)
you want to handle yourself.

## Completion

The included `monroe-lua-complete.el` file adds support for completion
to the Monroe client by querying the connected nREPL server for
possibilities. Simply invoke `completion-at-point` (bound to `C-M-i`
by default) when connected.

## Caveats

PUC Lua 5.1 does not allow yielding coroutines from inside protected
calls, which means you cannot use `io.read`, though LuaJIT and
Lua 5.2+ allow it.

## License

Copyright © 2016-2020 Phil Hagelberg and contributors

Distributed under the MIT license; see file LICENSE
