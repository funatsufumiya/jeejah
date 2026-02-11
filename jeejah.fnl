(local fennel (require :fennel))
(local socket (require :socket))
(local bencode (require :bencode))
(local d (if (os.getenv "DEBUG") print #nil))
(if (os.getenv "DEBUG")
  (print "debug: on"))

(local version "0.4.0-dev")

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

(λ make-repl [session options]
  (let [write (write-for session)
        repl-print (print-for session)
        env (or options.env {})]
    (when (= nil options.env)
      (set options.env env))

    (fn options.onValues [xs]
      (d :!values (fennel.view xs))
      (if session.values-override ; completion intercepts this
          (session.values-override xs)
          (doto session.conn
            ;; the spec implies you can combine these, but monroe disagrees
            (send session.msg {:value (table.concat xs "\t")})
            (send session.msg {:status [:done]}))))

    (fn options.onError [errtype msg]
      (d :!err errtype msg (fennel.view session.msg))
      (send session.conn session.msg {:ex errtype :err (.. msg "\n")})
      (send session.conn session.msg {:status [:done]}))

    (fn options.readChunk []
      (let [input (coroutine.yield)]
        (if (input:find "^%s*$")
            "nil\n" ; If we skip empty input, it confuses the client.
            (.. input "\n"))))

    (collect [k v (pairs _G) &into env] k v)
    (set env.io {: write})
    (set env.print repl-print)
    (fn env.io.read []
      (send session.conn session.msg {:status [:need-input]})
      (d :!need-input)
      (coroutine.yield))
    (set options.useMetadata true)
    (coroutine.wrap #(fennel.repl options))))

(λ register-session [sessions options conn]
  (let [id (tostring (math.random 999999999))
        session {: conn : id}]
    (d :!register id)
    (tset sessions id session)
    (set session.repl (make-repl session options))
    (session.repl)
    {:new-session id :status [:done]}))

(λ describe []
  (let [ops [:clone :close :describe :completions :eval :load-file :lookup
             :ls-sessions :stdin]]
    {: ops :status [:done]
     :server-name "jeejah" :server-version version}))

(λ completions [session conn msg]
  (var targets nil)
  (fn session.values-override [completion-targets]
    (set targets completion-targets))
  (session.repl (string.format ",complete %s\n" msg.prefix))
  (set session.values-override nil)
  (d :!completion msg.prefix :-> (fennel.view targets))
  (send conn msg {:completions (icollect [_ t (ipairs targets)]
                                 {:candidate t :type "unknown"})
                  :status [:done]}))

(λ lookup [session msg]
  (let [info {}]
    (fn session.values-override [[location]]
      (when (not (location:find "^Repl error:"))
        (set [info.file info.line] [(location:match "^(.*):(%d)")])))
    (session.repl (string.format ",find %s\n" msg.sym))
    (fn session.values-override [[doc]]
      (when (not (doc:find "not found$"))
        (set [info.arglist info.doc] [(doc:match "^(.*)\n(.*)")])))
    (session.repl (string.format ",doc %s\n" msg.sym))
    (set session.values-override nil)
    (if (next info)
        (send session.conn msg {: info :status [:done]})
        (send session.conn msg {:status [:done]}))))

; (λ session-for [sessions options conn msg]
;   ;; the fallback register-session here shouldn't be necessary, but let's
;   ;; just be tolerant in case there are client bugs
;   (doto (or (. sessions msg.session)
;             (do (print "  | Warning: implicit session registration")
;                 (register-session sessions options conn)))
;     (tset :msg msg)))

 (λ session-for [sessions options conn msg]
  ;; the fallback register-session here shouldn't be necessary, but let's
  ;; just be tolerant in case there are client bugs
  (let [session (or (. sessions msg.session)
                    (do (print "  | Warning: implicit session registration")
                        (register-session sessions options conn)))]
    (tset session :msg msg)
    (when (= nil session.repl)
      (set session.repl (make-repl session options)))
    session))

(λ handle [sessions options conn msg]
  (d "<" (fennel.view msg))
  (case msg
    {:op :clone} (send conn msg (register-session sessions options conn))
    {:op :describe} (send conn msg (describe))
    {:op :completions} (completions (session-for sessions options conn msg)
                                    conn msg)
    {:op :ls-sessions} (send conn msg
                             {:sessions (icollect [_ {: id} (ipairs sessions)]
                                          id)
                              :status [:done]})
    {:op :eval} (let [{: repl} (session-for sessions options conn msg)]
                  (d :!evaluating msg.code)
                  (repl (.. msg.code "\n")))
    {:op :stdin} (let [session (session-for sessions options conn msg)]
                   (session.repl msg.stdin)
                   (send conn msg {:status [:done]}))
    {:op :load-file} (case (pcall fennel.dofile msg.file {:useMetadata true})
                       true (send conn msg {:status [:done]})
                       (_ err) (send conn msg {:ex err :status [:done]}))
    {:op :lookup} (lookup (session-for sessions options conn msg) msg)
    {:op :interrupt} nil
    _ (do
        (send conn msg {:status [:unknown-op :done]})
        (print "  | Unknown op" (fennel.view msg)))))

(λ receive [handler-coros conn ?part]
  (let [(s err) (conn:receive 1)]
    (for [i (length handler-coros) 1 (- 1)]
      (let [(ok err2) (coroutine.resume (. handler-coros i))]
        (when (not= (coroutine.status (. handler-coros i)) :suspended)
          (when (not ok) (print "  | Handler error" err2))
          (table.remove handler-coros i))))
    (if s
        (receive handler-coros conn (.. (or ?part "") s))
        (and (= err :timeout) (= ?part nil))
        (do
          (coroutine.yield)
          (receive handler-coros conn))
        (= err :timeout)
        ?part
        (values nil err))))

(λ cleanup [state conn why]
  (when (not= :closed why) (print "  | Client closed" why))
  (tset state.connections conn nil)
  (each [i c (ipairs state.sockets)]
    (when (= c conn)
      (table.remove state.sockets i))))

(λ client-loop [{: sessions : handler-coros : options &as state} conn ?part]
  (case (receive handler-coros conn ?part)
    input (case (bencode.decode input)
            {:op :close &as msg} (do (send conn msg {:status [:done]})
                                     (cleanup state conn :closed))
            (decoded len) (let [coro (coroutine.create handle)
                                (ok err) (coroutine.resume coro sessions options
                                                           conn decoded)
                                part (if (< len (length input))
                                         (input:sub (+ len 1))
                                         nil)]
                            (when (not ok) (print "  | Handler error" err))
                            (when (= (coroutine.status coro) :suspended)
                              (table.insert handler-coros coro))
                            (client-loop state conn part))
            (_ err) (print "  | Decoding error:" err))
    (_ err) (values nil err)))

(λ accept [state conn]
  (conn:settimeout 0.01)
  (table.insert state.sockets conn)
  (tset state.connections conn
        (coroutine.create #(case (pcall client-loop state conn)
                             (_ err) (cleanup state conn err)))))

(λ loop [{: server : sockets : connections &as state}]
  (each [_ ready (ipairs (socket.select sockets))]
    (if (= ready server)
        (case (server:accept)
          conn (accept state conn)
          (_ :timeout) nil
          (_ err) (error err))
        (case (. connections ready)
          coro (case (coroutine.resume coro)
                 (false err) (cleanup state ready err))
          _ (print "  | Unrecognized connection" ready))))
  (loop state))

(λ start [options]
  (let [port (or options.port 7888)
        server (assert (socket.bind "localhost" port))
        state {: server : options :connections {} :handler-coros {} :sessions {}
               :sockets [server]}]
    (server:settimeout 0.01)
    (print (.. "Server started on port " port "..."))
    (loop state)))

{: start : version}
