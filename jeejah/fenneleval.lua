local fennel = require("fennel")
local fennelview_ok, fennelview = pcall(require, "fennelview")
if not fennelview_ok then fennelview = fennel.dofile("fennelview.fnl") end

local d = os.getenv("DEBUG") and print or function(_) end

local repls = {}

local print_for = function(write)
   return function(...)
      local args = {...}
      for i,x in ipairs(args) do args[i] = tostring(x) end
      table.insert(args, "\n")
      write(table.concat(args, " "))
   end
end

local make_repl = function(session, repls)
   local on_values = function(xs)
      session.write(table.concat(xs, "\n") .. "\n")
      session.done({status={"done"}})
   end
   local read = function()
      -- If we skip empty input, it confuses the client.
      local input = coroutine.yield()
      if(input:find("^%s*$")) then return "nil\n" else return input end
   end
   local err = function(errtype, msg) write({errtype, msg}) session.done() end

   local env = session.sandbox or {io={}}
   env.print = print_for(session.write)
   env.io.write, env.io.read = session.write, session.read

   local f = function()
      return fennel.repl({readChunk = read,
                          onValues = on_values,
                          onError = err,
                          env = env,
                          pp = fennelview})
   end
   repls[session.id] = coroutine.wrap(f)
   repls[session.id]()
   return repls[session.id]
end

return function(conn, msg, session, send, response_for)
   d("Evaluating", msg.code)
   session.done = function() send(conn, response_for(msg, {status={"done"}})) end
   local repl = repls[session.id] or make_repl(session, repls)
   repl(msg.code .. "\n")
end
