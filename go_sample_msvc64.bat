@echo off
call "%ProgramFiles%\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" amd64

c:\harb\msvc64\bin\hbmk2 app.hbp -comp=msvc64

if errorlevel 1 goto compileerror

app.exe

goto exit

:compileerror

echo *** Error ***

:exit

pause