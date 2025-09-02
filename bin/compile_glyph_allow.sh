#!/usr/bin/env bash
set -euo pipefail
awk '
  BEGIN { print "# auto-generated from /etc/nginx/glyph_allow.list — do not edit" }
  /^[[:space:]]*#/ { next }     # comments
  /^[[:space:]]*$/ { next }     # blanks
  { gsub(/\r$/,""); printf("~^%s 1;\n", $0) }
' /etc/nginx/glyph_allow.list | sudo tee /etc/nginx/glyph_allow.map >/dev/null
