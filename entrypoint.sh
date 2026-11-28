#!/bin/sh
# entrypoint — start pathviz, optionally with built-in demo traffic.
set -e

demo_pids=""
cleanup() {
    [ -n "$demo_pids" ] && kill $demo_pids 2>/dev/null || true
}

if [ "${DEMO:-0}" = "1" ]; then
    # Same flow as `make demo-local`: a web server on :8080 plus one loopback
    # request every two seconds (crosses OUTPUT, POSTROUTING, PREROUTING, INPUT).
    python3 -m http.server 8080 >/dev/null 2>&1 &
    demo_pids="$!"
    ( while true; do curl -s -m 2 -o /dev/null http://127.0.0.1:8080/ || true; sleep 2; done ) &
    demo_pids="$demo_pids $!"
    trap cleanup EXIT INT TERM
fi

exec pathviz "$@"
