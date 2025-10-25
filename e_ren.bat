@echo off
REM E-Ren CLI wrapper for Windows
REM This allows running 'e_ren' instead of 'python e_ren'

python "%~dp0e_ren" %*
