# JeeJah

An nREPL server for [Fennel](https://fennel-lang.org).

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

Currently mainly tested with [monroe](https://github.com/sanel/monroe/)
Other clients exist for Vim, Eclipse, and VS Code, as well as several
independent command-line clients; however these may require some
adaptation to work with Jeejah. If you try your favorite client and
find that it makes Clojure-specific assumptions, please report a bug
with it so that it can gracefully degrade when those assumptions don't
hold.

## Installation

The pure-Lua dependencies are included (`bencode`, and `fennel`) but
you will need to install `luasocket` yourself. Try installing it using
your system package manager first. If your operating system does not
provide it, you can install it using LuaRocks:

    $ luarocks install --local luasocket

Note that [LÖVE](https://love2d.org) ships with its own copy of
luasocket, so there is no need to install it there.

Run `make` to create `jeejah` in the checkout; use `make install` to
put it in `PREFIX`.

## Usage

You can launch a standalone nREPL server:

    $ ./jeejah $PORT

## License

Copyright © 2016-2025 Phil Hagelberg and contributors

Distributed under the MIT license; see file LICENSE
