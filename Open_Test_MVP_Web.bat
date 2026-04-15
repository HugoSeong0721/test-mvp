@echo off
cd /d "%~dp0build\web"
start "" http://127.0.0.1:7360
python -m http.server 7360 --bind 0.0.0.0
