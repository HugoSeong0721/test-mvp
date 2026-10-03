#!/bin/sh
# flutter test --platform chrome 용: 샌드박스 없이 헤드리스 크로미움
exec /opt/pw-browsers/chromium-1194/chrome-linux/chrome --no-sandbox --headless=new "$@"
