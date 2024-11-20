@echo off

:: Make sure this is a decent name and not generic
set exe_name=sssprites.exe
set compile_path=sssprites

:: Debug = 0, Release = 1
if "%1" == "release" (
    set release_mode=1
) else (
    set release_mode=0
)

if not exist .git\ goto skip_git_hash
for /f "tokens=1,2" %%i IN ('git show "--pretty=%%cd %%h" "--date=format:%%Y-%%m-%%d" --no-patch --no-notes HEAD') do (
    set program_version_raw=dev-%%i
    set GIT_SHA=%%j
)
:skip_git_hash

if %release_mode%==1 (
    odin build %compile_path% -vet -o:speed -disable-assert -out:%exe_name% -define:VERSION="%program_version_raw%-%GIT_SHA%"
) else (
    odin build %compile_path% -vet -o:none -debug -out:%exe_name% -define:VERSION="%program_version_raw%-%GIT_SHA%"
)