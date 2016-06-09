-- these first few should all be in luarocks
local socket = require "socket"
local serpent = require "serpent"
local bencode = require "bencode"

local timeout = 0.1

local pack = function(...) return {...} end
local d = function(_) end
local p = function(x) print(serpent.block(x)) end
local sessions = {}

local serpent_opts = {maxlevel=8,maxnum=64,nocode=true}

local response_for = function(old_msg, msg)
   msg.session, msg.id, msg.ns = old_msg.session, old_msg.id, ""
   return msg
end

local send = function(conn, msg)
   d("Sending", bencode.encode(msg))
   conn:send(bencode.encode(msg))
end

local write_for = function(conn, msg)
   return function(...)
      send(conn, response_for(msg, {out=table.concat({...}, "\t")}))
   end
end

local print_for = function(write)
   return function(...)
      for _,x in ipairs({...}) do write(x) end
      write("\n")
   end
end

local sandbox_for = function(write, provided_sandbox)
   local sandbox = { io = { write = write },
                     print = print_for(write), }
   for k,v in pairs(provided_sandbox) do
      sandbox[k] = v
   end
   return sandbox
end

-- for stuff that's shared between eval and load_file
local execute_chunk = function(write, sandbox, chunk)
   local old_write, old_print = io.write, print
   if(sandbox) then
      setfenv(chunk, sandbox)
   else
      -- TODO: redirect stdin
      _G.print = print_for(write)
      _G.io.write = write
   end

   local trace, err
   local result = pack(xpcall(chunk, function(e)
                                 trace = debug.traceback()
                                 err = e end))
   if(not sandbox) then
      _G.print = old_print
      _G.io.write = old_write
   end

   if(result[1]) then
      local res, i = serpent.block(result[2], serpent_opts), 3
      while i <= #result do
         res = res .. ', ' .. serpent.block(result[i], serpent_opts)
         i = i + 1
      end
      return res
   else
      return false, (err or "Unknown error") .. "\n" .. trace
   end
end

local eval = function(write, sandbox, code)
   local chunk, err = loadstring("return " .. code, "*socket*")
   if(err and not chunk) then -- statement, not expression
      chunk, err = loadstring(code, "*socket*")
      if(not chunk) then
         return false, "Compilation error: " .. (err or "unknown")
      end
   end
   return execute_chunk(write, sandbox, chunk)
end

local load_file = function(write, sandbox, file)
   local chunk, err = loadfile(file)
   if(not chunk) then
      return false, "Compilation error in " .. file ": ".. (err or "unknown")
   end
   return execute_chunk(write, sandbox, chunk)
end

-- TODO: proper session support?
local register_session = function(msg)
   local session = tostring(math.random(999999999))
   sessions[session] = {}
   return response_for(msg, {["new-session"]=session, status="done"})
end

local complete = function(msg, sandbox)
   local clone = function(t)
      local n = {} for k,v in pairs(t) do n[k] = v end return n
   end
   local top_ctx = clone(sandbox or _G)
   for k,v in pairs(msg.libs or {}) do
      top_ctx[k] = require(v:sub(2,-2))
   end

   local function cpl_for(input_parts, ctx)
      if type(ctx) ~= "table" then return {} end
      if #input_parts == 0 and ctx ~= top_ctx then
         return ctx
      elseif #input_parts == 1 then
         local matches = {}
         for k in pairs(ctx) do
            if k:find('^' .. input_parts[1]) then
               table.insert(matches, k)
            end
         end
         return matches
      else
         local token1 = table.remove(input_parts, 1)
         return cpl_for(input_parts, ctx[token1])
      end
   end
   local input_parts = {}
   for i in string.gmatch(msg.input, "([^.%s]+)") do
      table.insert(input_parts, i)
   end
   return response_for(msg, {completions = cpl_for(input_parts, top_ctx)})
end

-- see https://github.com/clojure/tools.nrepl/blob/master/doc/ops.md
local handle = function(conn, handlers, provided_sandbox, msg)
   if(msg.op == "clone") then
      d("New session.")
      send(conn, register_session(msg))
   elseif(msg.op == "eval") then
      d("Evaluating", msg.code)
      local write = write_for(conn, msg)
      local sandbox = provided_sandbox and sandbox_for(write, provided_sandbox)
      local value, err = eval(write, sandbox, msg.code)
      d("Got", value, err)
      send(conn, response_for(msg, {value=value, ex=err}))
      send(conn, response_for(msg, {status="done"}))
   elseif(msg.op == "load-file") then
      d("Loading file", msg.file)
      local write = write_for(conn, msg)
      local sandbox = provided_sandbox and sandbox_for(write, provided_sandbox)
      local value, err = load_file(write, sandbox, msg.file)
      d("Got", value, err)
      send(conn, response_for(msg, {value=value, ex=err}))
      send(conn, response_for(msg, {status="done"}))
   elseif(msg.op == "complete") then
      d("Complete", msg.input)
      local sandbox = provided_sandbox and sandbox_for(nil, provided_sandbox)
      send(conn, complete(msg, sandbox))
   elseif(msg.op == "stdin") then
      d("Stdin", serpent.block(msg))
      return -- TODO: implement
   elseif(msg.op == "interrupt") then
      d("Interrupt")
      return -- we can't do anything to interrupt, ignore silently
   elseif(msg.op == "describe") then
      d("Describe")
      write_for(conn, msg)("Describe is not supported.\n")
   elseif(handlers[msg.op]) then
      d("Custom op:", msg.op)
      handlers[msg.op](conn, msg, provided_sandbox)
   else
      send(conn, response_for(msg, {status="unknown-op"}))
      print("  | Unknown op", serpent.block(msg))
   end
end

local function receive(conn, yield, partial)
   local s, err = conn:receive(1) -- wow this is primitive
   yield()
   if(s) then
      return receive(conn, yield, (partial or "") .. s)
   elseif(err == "timeout" and partial == nil) then
      return receive(conn, yield)
   elseif(err == "timeout") then
      return partial
   else
      return nil, err
   end
end

local function loop(server, handlers, sandbox, yield)
   local conn, err = server:accept()
   yield()
   if(conn) then
      conn:settimeout(timeout)
      d("Connected.")
      while true do
         local input, r_err = receive(conn, yield)
         if(input) then
            local decoded, d_err = bencode.decode(input)
            yield()
            if(decoded) then
               handle(conn, handlers, sandbox, decoded)
            else
               print("  | Decoding error:", d_err)
            end
         else
            if(r_err == "closed") then
               return loop(server, handlers, sandbox, yield)
            elseif(r_err ~= "timeout") then
               print("  | Error:", r_err)
            end
         end
      end
   else
      if(err ~= "timeout") then print("  | Socket error: " .. err) end
      return loop(server, handlers, sandbox, yield)
   end
end

-- Start an nrepl socket server on the given host and port. For opts
-- you can pass a table with fg=true to run in the foreground, debug=true for
-- verbose logging, and sandbox={...} to evaluate all code in a sandbox.
-- You can also give an opts.handlers table keying ops to handler functions
-- which take the socket, the decoded message, and the optional sandbox table.
return function(host, port, opts)
   host, port = host or "localhost", port or 7888
   local server, err = assert(socket.bind(host, port))
   opts = opts or {}
   if(opts.debug) then d = print end
   if(opts.timeout) then timeout = tonumber(opts.timeout) end

   if(server) then
      server:settimeout(timeout)
      print("Server started on " .. host .. ":" .. port .. "...")
      if(opts.fg) then
         return loop(server, opts.sandbox, opts.handlers, function() end)
      else
         return coroutine.create(function()
               loop(server, opts.sandbox, opts.handlers, coroutine.yield)
         end)
      end
   else
      print("  | Error starting socket repl server: " .. err)
   end
end
