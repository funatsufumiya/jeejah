local fennel = require("fennel")
local fennelview = fennel.dofile("fennelview.fnl")

local d = os.getenv("DEBUG") and print or function(_) end

local repls = {}

local make_repl = function(session, repls)
   local write = function(x)
      local out = table.concat(x, "\n")
      session.fennel_send({value=out})
      session.fennel_send({status={"done"}})
   end
   local read = function()
      -- If we skip empty input, it confuses the client.
      local input = coroutine.yield()
      if(input:find("^%s*$")) then return "nil\n" else return input end
   end
   local err = function(errtype, msg) write({errtype, msg}) end
   local f = function()
      return fennel.repl({readChunk = read,
                          onValues = write,
                          onError = err,
                          env = session.sandbox,
                          pp = fennelview})
   end
   repls[session.id] = coroutine.wrap(f)
   repls[session.id]()
   return repls[session.id]
end

return function(conn, msg, session, send, response_for, write)
   d("Evaluating", msg.code)
   session.fennel_write = write
   session.fennel_send = function(vals)
      return send(conn, response_for(msg, vals))
   end
   local repl = repls[session.id] or make_repl(session, repls)
   repl(msg.code .. "\n")
end
