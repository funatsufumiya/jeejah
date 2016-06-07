# JeeJah

An nREPL server for Lua.

Note that multiple sessions and stdin are not yet supported.

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
jeejah(host, port, {debug=true, fg=true, sandbox={x=12}})
```

If you don't set `fg=true` then you will get back a coroutine which
you'll need to repeatedly resume in order to handle requests.

You can also pass in a `handlers` table where the keys are custom
[nREPL ops](https://github.com/clojure/tools.nrepl/blob/master/doc/ops.md)
you want to handle yourself.

## License

Copyright © 2016 Phil Hagelberg and contributors

Distributed under the MIT license; see file LICENSE
