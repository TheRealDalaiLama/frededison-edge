#!/usr/bin/env bash
set -euo pipefail
CONF="/etc/nginx/sites-available/frededison-triad.conf"

ok(){   echo "✓ $*"; }
fail(){ echo "✗ $*" >&2; exit 1; }

[ -s "$CONF" ] || fail "missing $CONF"

# 1) glyph allow map present
if grep -qE '^[[:space:]]*map[[:space:]]+\$request_uri[[:space:]]+\$glyph_allowed[[:space:]]*\{' "$CONF"; then
  ok "map present"
else
  fail "glyph allow map not found"
fi

# 2) no regex gateway location
if grep -qE '^[[:space:]]*location[[:space:]]+~[[:space:]]*\^/api/v1/g/' "$CONF"; then
  fail "found regex gateway: 'location ~ ^/api/v1/g/' (use 'location ^~ /api/v1/g/')"
else
  ok "no regex gateway"
fi

# 3) numeric .com (HTTPS) server block check
awk '
BEGIN { inblk=0; braces=0; passed=0; }
function reset(){ blk=""; inblk=0; braces=0; }
# start of server block
/^[[:space:]]*server[[:space:]]*\{/ { inblk=1; braces=1; blk=$0 ORS; next }
# inside server block: accumulate & count braces (mawk-safe)
inblk{
  blk = blk $0 ORS
  t=$0; ob=gsub(/\{/,"",t); t=$0; cb=gsub(/\}/,"",t); braces += ob - cb
  if (braces==0) {
    # must be 443 and for frededison.com with regex server_name (~^)
    if (blk ~ /listen[[:space:]].*443/ && blk ~ /server_name[[:space:]].*~\^/ && index(blk, "frededison\\.com")) {

      # extract the server_name line (first hit)
      sn=""
      if (match(blk, /server_name[[:space:]]+~\^[^\n;]*;/)) sn = substr(blk, RSTART, RLENGTH)

      # numeric hint: allow any of these on the server_name line
      #   - literal "[0-9]+"
      #   - literal "\d+"
      #   - pattern "~^<digits>\.frededison\.com"
      has_class = (sn!="" && index(sn, "[0-9]+")>0)
      has_dplus = (sn!="" && index(sn, "\\d+")>0)
      has_plain = (sn ~ /server_name[[:space:]]+~\^[[:space:]]*[0-9]+\\\.frededison\\\.com/)

      if (has_class || has_dplus || has_plain) {
        # exactly one blanket deny for /api with prefix location
        apideny=0; tmp=blk
        while (match(tmp, /location[[:space:]]+\^~[[:space:]]+\/api\/[[:space:]]*\{[[:space:]]*return[[:space:]]+403[[:space:]]*;[[:space:]]*\}/)) {
          apideny++; tmp=substr(tmp, RSTART+RLENGTH)
        }
        gw = (blk ~ /location[[:space:]]+\^~[[:space:]]+\/api\/v1\/g\//)
        rl = (blk ~ /limit_req[[:space:]]+zone=rl_dm_text/)
        if (apideny==1 && gw && rl) { print "OK"; passed=1; exit 0 }
      }
    }
    reset()
  }
}
END { if (!passed) print "NOSRV" }
' "$CONF" | {
  read out || true
  case "$out" in
    OK)        ok "numeric .com (443) block found; one /api deny; gateway present; rl_dm_text applied" ;;
    NOSRV|"")  fail "could not find numeric .com HTTPS server block in $CONF" ;;
    *)         fail "unexpected parse result: ${out}" ;;
  esac
}
