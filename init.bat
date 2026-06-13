@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ─── init.bat — 将 c-workspace-kit 初始化到目标 Java 项目 ───────────────────

set "SCRIPT_DIR=%~dp0"
:: 去掉末尾反斜杠
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

set "TARGET_DIR=%~1"

:: ─── 帮助 ─────────────────────────────────────────────────────────────────────
if "%TARGET_DIR%"=="" (
    call :print_usage
    call :print_error "请提供目标项目路径"
    exit /b 1
)

:: ─── 解析绝对路径 ──────────────────────────────────────────────────────────────
pushd "%TARGET_DIR%" 2>nul
if errorlevel 1 (
    set /p "CREATE_DIR=目标目录不存在，是否创建？[y/N] "
    if /i "!CREATE_DIR!"=="y" (
        mkdir "%TARGET_DIR%" 2>nul || (
            call :print_error "无法创建目录：%TARGET_DIR%"
            exit /b 1
        )
        call :print_success "已创建目录：%TARGET_DIR%"
        pushd "%TARGET_DIR%"
    ) else (
        call :print_error "已取消"
        exit /b 1
    )
)
set "TARGET_DIR=%CD%"
popd

call :print_info "源目录：%SCRIPT_DIR%"
call :print_info "目标目录：%TARGET_DIR%"
echo.

:: ─── 冲突检查 ─────────────────────────────────────────────────────────────────
set "HAS_CONFLICT=0"
set "CONFLICT_LIST="

if exist "%TARGET_DIR%\.workspace"           set "HAS_CONFLICT=1" & set "CONFLICT_LIST=%CONFLICT_LIST% .workspace"
if exist "%TARGET_DIR%\.claude\skills"       set "HAS_CONFLICT=1" & set "CONFLICT_LIST=%CONFLICT_LIST% .claude\skills"
if exist "%TARGET_DIR%\.claude\memory"       set "HAS_CONFLICT=1" & set "CONFLICT_LIST=%CONFLICT_LIST% .claude\memory"
if exist "%TARGET_DIR%\.claude\settings.json" set "HAS_CONFLICT=1" & set "CONFLICT_LIST=%CONFLICT_LIST% .claude\settings.json"
if exist "%TARGET_DIR%\CLAUDE.md"            set "HAS_CONFLICT=1" & set "CONFLICT_LIST=%CONFLICT_LIST% CLAUDE.md"

set "OVERWRITE_MODE=ask"

if "%HAS_CONFLICT%"=="1" (
    echo [WARN]  以下文件/目录在目标项目中已存在：
    for %%F in (%CONFLICT_LIST%) do echo         - %%F
    echo.
    echo 请选择处理方式：
    echo   [1] 覆盖（直接替换现有内容）
    echo   [2] 备份后覆盖（原文件/目录重命名为 *.bak）
    echo   [3] 跳过已存在的文件
    echo   [4] 取消
    set /p "CHOICE=请输入选项 [1-4]: "

    if "!CHOICE!"=="1" set "OVERWRITE_MODE=overwrite"
    if "!CHOICE!"=="2" set "OVERWRITE_MODE=backup"
    if "!CHOICE!"=="3" set "OVERWRITE_MODE=skip"
    if "!CHOICE!"=="4" (
        call :print_error "已取消"
        exit /b 1
    )
    if not "!OVERWRITE_MODE!"=="overwrite" if not "!OVERWRITE_MODE!"=="backup" if not "!OVERWRITE_MODE!"=="skip" (
        call :print_error "无效选项，已取消"
        exit /b 1
    )
)

:: ─── 执行复制 ─────────────────────────────────────────────────────────────────
echo.
call :print_info "开始复制文件..."
echo.

call :copy_item ".workspace"
call :copy_item ".claude\skills"
call :copy_item ".claude\memory"
call :copy_item ".claude\settings.json"
call :copy_item "CLAUDE.md"

:: ─── 创建 requirements 目录 ──────────────────────────────────────────────────
if not exist "%TARGET_DIR%\requirements\" (
    mkdir "%TARGET_DIR%\requirements"
    type nul > "%TARGET_DIR%\requirements\.gitkeep"
    call :print_success "已创建：requirements\ 目录"
)

:: ─── 更新 .gitignore ─────────────────────────────────────────────────────────
set "GITIGNORE=%TARGET_DIR%\.gitignore"
if exist "%GITIGNORE%" (
    findstr /C:"requirements/blockers.md" "%GITIGNORE%" >nul 2>&1 || echo requirements/blockers.md>> "%GITIGNORE%"
    findstr /C:"requirements/eval-report.md" "%GITIGNORE%" >nul 2>&1 || echo requirements/eval-report.md>> "%GITIGNORE%"
    call :print_info ".gitignore 已更新"
) else (
    echo requirements/blockers.md> "%GITIGNORE%"
    echo requirements/eval-report.md>> "%GITIGNORE%"
    call :print_success "已创建 .gitignore"
)

:: ─── 完成提示 ─────────────────────────────────────────────────────────────────
echo.
echo =====================================================
echo   初始化完成！
echo =====================================================
echo.
echo   目标项目：%TARGET_DIR%
echo.
echo   下一步：
echo     1. 打开 CLAUDE.md，根据项目实际情况更新知识索引
echo     2. 在 .workspace\architecture.md 填充技术栈和架构决策
echo     3. 使用 Claude Code 运行 /plan 开始需求规划
echo.

endlocal
exit /b 0

:: ─── 函数：复制单个文件或目录 ────────────────────────────────────────────────
:copy_item
set "ITEM=%~1"
set "SRC=%SCRIPT_DIR%\%ITEM%"
set "DST=%TARGET_DIR%\%ITEM%"

:: 源不存在
if not exist "%SRC%" (
    call :print_warn "源不存在，跳过：%ITEM%"
    goto :eof
)

:: 目标存在时的处理
if exist "%DST%" (
    if "%OVERWRITE_MODE%"=="skip" (
        call :print_warn "跳过（已存在）：%ITEM%"
        goto :eof
    )
    if "%OVERWRITE_MODE%"=="backup" (
        if exist "%DST%.bak" rd /s /q "%DST%.bak" 2>nul
        rename "%DST%" "%ITEM%.bak" 2>nul || (
            :: 若 rename 失败（跨目录）则用 move
            move "%DST%" "%DST%.bak" >nul 2>&1
        )
        call :print_warn "已备份：%ITEM% → %ITEM%.bak"
    )
    if "%OVERWRITE_MODE%"=="overwrite" (
        if exist "%DST%\" (
            rd /s /q "%DST%"
        ) else (
            del /f /q "%DST%"
        )
    )
)

:: 确保父目录存在
for %%P in ("%DST%") do if not exist "%%~dpP" mkdir "%%~dpP"

:: 复制
if exist "%SRC%\" (
    xcopy /e /i /q /y "%SRC%" "%DST%\" >nul
) else (
    copy /y "%SRC%" "%DST%" >nul
)

call :print_success "已复制：%ITEM%"
goto :eof

:: ─── 打印函数 ─────────────────────────────────────────────────────────────────
:print_info
echo [INFO]  %~1
goto :eof

:print_success
echo [OK]    %~1
goto :eof

:print_warn
echo [WARN]  %~1
goto :eof

:print_error
echo [ERROR] %~1 >&2
goto :eof

:print_usage
echo.
echo 用法: init.bat ^<目标项目路径^>
echo.
echo   将 c-workspace-kit 中的规范文件复制到目标项目。
echo.
echo   复制内容：
echo     .workspace\       架构、编码规范、API 规范、组件地图
echo     .claude\skills\   三个 Agent 行为规范
echo     .claude\memory\   品质锚定、知识地图
echo     .claude\settings.json  Claude Code 配置（Hooks）
echo     CLAUDE.md         项目主入口文档
echo.
echo   示例：
echo     init.bat C:\Projects\my-java-project
echo     init.bat ..\my-service
echo.
goto :eof
