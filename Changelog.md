# Jeejah changelog: history of user-visible changes

## 0.4.0 / ???

* Port to Fennel; drop Lua support.
* Remove support for middleware, custom handlers, and sandboxing.

## 0.3.1 / 2020-04-24

* Fix compatibility for Lua 5.1 and 5.2.
* Improve error reporting.
* Move Fennel support to special handler instead of middleware.

## 0.3.0 / 2019-08-01

* Fix a bug with socket timeout.
* Add foreground mode.
* Avoid burning CPU when there's nothing to do.

## 0.2.1 / 2019-05-21

* Add support for launching a Fennel server using middleware.
* Add support for middleware.
* Support Luas newer than 5.1.

## 0.2.0 / 2016-06-20

* Support requesting a read from stdin.
* Support stopping the server.
* Change module API to return a table, not a function.
* Support multiple sessions.

## 0.1.0 / 2016-06-09

* Initial release!

