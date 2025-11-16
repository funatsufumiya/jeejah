(local fennel (require :fennel))
(local socket (require :socket))
(local bencode (require :bencode))
(local d (if (os.getenv "DEBUG") print #nil))

;; TODO:
;; * socket select
;; * accept fennel.repl options table
;; * middleware?
;; * write .nrepl-port file?

(local version "0.4.0-dev")

(local sessions {})

(λ send [conn from msg]
  (set (msg.session msg.id msg.ns) (values from.session from.id ">"))
  (d ">" (fennel.view msg))
  (conn:send (bencode.encode msg)))

(λ write-for [session]
  (fn [...]
    (send session.conn {:session session.id :id session.msg.id}
          {:out (table.concat [...] "\t")})
    nil))

(λ print-for [session]
  (fn [...]
    (let [args (icollect [_ x (ipairs [...])] (tostring x))]
      (send session.conn {:session session.id :id session.msg.id}
            {:out (.. (table.concat args "\t") "\n")})
      nil)))

(λ make-repl [session]
  (let [write (write-for session)
        repl-print (print-for session)
        env {}]
    (fn onValues [xs]
      (d :!values (fennel.view xs))
      ;; the spec implies you can combine these, but monroe disagrees
      (send session.conn session.msg {:value (table.concat xs "\t")})
      (send session.conn session.msg {:status [:done]}))

    (fn onError [errtype msg]
      (d :!err errtype msg (fennel.view session.msg))
      (send session.conn session.msg {:ex errtype :err (.. msg "\n")})
      (send session.conn session.msg {:status [:done]}))

    (fn readChunk []
      (let [input (coroutine.yield)]
        (if (input:find "^%s*$")
            "nil\n" ; If we skip empty input, it confuses the client.
            (.. input "\n"))))

    (collect [k v (pairs _G) &into env] k v)
    (set env.io {: write})
    (set env.print repl-print)
    (fn env.io.read []
      (session.needinput)
      (let [(input done) (coroutine.yield)]
        (done)
        input))
    (coroutine.wrap #(fennel.repl {: env : onError : onValues : readChunk}))))

(λ register-session [conn]
  (let [id (tostring (math.random 999999999))
        session {: conn : id}]
    (d :!register id)
    (tset sessions id session)
    (set session.repl (make-repl session))
    (session.repl)
    {:new-session id :status [:done]}))

(λ describe []
  (let [ops [:clone :close :describe :eval :load-file :lookup
             :ls-sessions :stdin :interrupt]]
    {: ops :status [:done] :server-name "jeejah" :server-version version}))

(λ session-for [conn msg]
  (doto (or (. sessions msg.session) (register-session conn))
    (tset :msg msg)))

(λ handle [conn msg]
  (d "<" (fennel.view msg))
  (case msg
    {:op :clone} (send conn msg (register-session conn))
    {:op :describe} (send conn msg (describe))
    {:op :ls-sessions} (send conn msg
                             {:sessions (icollect [_ {: id} (ipairs sessions)] id)
                              :status [:done]})
    {:op :eval} (let [{: repl} (session-for conn msg)]
                  (d :!evaluating msg.code)
                  (repl (.. msg.code "\n")))
    {:op :stdin} (let [session (session-for conn msg)]
                   (session.repl msg.stdin)
                   (send conn msg {:status [:done]}))
    {:op :interrupt} nil
    _ (do
        (send conn msg {:status [:unknown-op]})
        (print "  | Unknown op" (fennel.view msg)))))

(local handler-coros {})

(λ receive [conn ?part]
  (let [(s err) (conn:receive 1)]
    (for [i (length handler-coros) 1 (- 1)]
      (let [(ok err2) (coroutine.resume (. handler-coros i))]
        (when (not= (coroutine.status (. handler-coros i)) :suspended)
          (when (not ok) (print "  | Handler error" err2))
          (table.remove handler-coros i))))
    (if s
        (receive conn (.. (or ?part "") s))
        (and (= err :timeout) (= ?part nil))
        (do
          (coroutine.yield)
          (receive conn))
        (= err :timeout)
        ?part
        (values nil err))))

(λ client-loop [conn ?part]
  (case (receive conn ?part)
    input (let [(decoded d-err) (bencode.decode input)]
            (if (and decoded (< d-err (length input)))
                (set-forcibly! ?part (input:sub (+ d-err 1)))
                (set-forcibly! ?part nil))
            (coroutine.yield)
            (if (and decoded (= decoded.op :close))
                (do
                  (tset sessions decoded.session nil)
                  (send conn {:status [:done]})
                  (error :closed))
                (and decoded (not= decoded.op :close))
                (let [coro (coroutine.create handle)]
                  (let [(ok err) (coroutine.resume coro conn decoded)]
                    (when (not ok) (print "  | Handler error" err)))
                  (when (= (coroutine.status coro) :suspended)
                    (table.insert handler-coros coro)))
                (print "  | Decoding error:" d-err))
            (client-loop conn ?part))
    (_ err) (values nil err)))

(λ accept [conn timeout connections]
  (conn:settimeout timeout)
  (table.insert connections
                (coroutine.create #(case (pcall client-loop conn)
                                     (_ :closed) nil
                                     (_ err) (print "Connection closed" err)))))

(λ loop [server timeout connections]
  (socket.sleep timeout)
  (case (server:accept)
    conn (do (accept conn timeout connections)
             (loop server timeout connections))
    (_ err) (do
              (when (not= err :timeout) (print (.. "  | Socket error: " err)))
              (each [_ c (ipairs connections)]
                (coroutine.resume c))
              (if (= err :closed)
                  (do
                    (server:close)
                    (print "Server stopped."))
                  (loop server timeout connections)))))

(λ start [?port]
  (let [port (or ?port 7888)
        timeout 0.01
        server (assert (socket.bind "localhost" port))
        connections {}]
    (server:settimeout timeout)
    (print (.. "Server started on port " port "..."))
    (loop server timeout connections)))

{: start
 :stop (fn [coro] (coroutine.resume coro :stop))
 : version}
