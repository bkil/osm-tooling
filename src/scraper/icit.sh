#!/bin/sh

main() {
  if [ -z "$DOMAIN" ]; then
    echo "error: need to set DOMAIN" >&2
    exit 1
  fi

  curl -A- https://$DOMAIN/ingatlanok 2>/dev/null |
  sed -nr "
    s~^\s*<a target=\"_blank\"[^>]*>([^<>]+)</a>$~\1~
    T end
    s~&#34;~\"~g
    p
    :end
    "
}

main "$@"
