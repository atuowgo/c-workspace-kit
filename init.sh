#!/usr/bin/env bash
# init.sh — 将 c-workspace-kit 初始化到目标 Java 项目

set -euo pipefail

# ─── 颜色 ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── 路径 ───────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-}"

# ─── 帮助 ────────────────────────────────────────────────────────────────────
usage() {
    echo ""
    echo "用法: $0 <目标项目路径>"
    echo ""
    echo "  将 c-workspace-kit 中的规范文件复制到目标项目。"
    echo ""
    echo "  复制内容："
    echo "    .workspace/       架构、编码规范、API 规范、组件地图"
    echo "    .claude/skills/   三个 Agent 行为规范"
    echo "    .claude/memory/   品质锚定、知识地图"
    echo "    .claude/settings.json  Claude Code 配置（Hooks）"
    echo "    CLAUDE.md         项目主入口文档"
    echo ""
    echo "  示例："
    echo "    $0 /path/to/my-java-project"
    echo "    $0 ../my-service"
    echo ""
}

if [[ -z "$TARGET_DIR" ]]; then
    usage
    error "请提供目标项目路径"
fi

TARGET_DIR="$(realpath "$TARGET_DIR")"

# ─── 目标目录检查 ────────────────────────────────────────────────────────────
if [[ ! -d "$TARGET_DIR" ]]; then
    warn "目标目录不存在，是否创建？[y/N] "
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || error "已取消"
    mkdir -p "$TARGET_DIR"
    success "已创建目录：$TARGET_DIR"
fi

info "源目录：$SCRIPT_DIR"
info "目标目录：$TARGET_DIR"
echo ""

# ─── 冲突检查 ────────────────────────────────────────────────────────────────
CONFLICT_FILES=()
check_conflict() {
    local src="$1" rel="$2"
    if [[ -e "$TARGET_DIR/$rel" ]]; then
        CONFLICT_FILES+=("$rel")
    fi
}

check_conflict ".workspace" ".workspace"
check_conflict ".claude/skills" ".claude/skills"
check_conflict ".claude/memory" ".claude/memory"
check_conflict ".claude/settings.json" ".claude/settings.json"
check_conflict "CLAUDE.md" "CLAUDE.md"

OVERWRITE_MODE="ask"   # ask | overwrite | backup | skip

if [[ ${#CONFLICT_FILES[@]} -gt 0 ]]; then
    echo -e "${YELLOW}以下文件/目录在目标项目中已存在：${NC}"
    for f in "${CONFLICT_FILES[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo "请选择处理方式："
    echo "  [1] 覆盖（直接替换现有内容）"
    echo "  [2] 备份后覆盖（原文件重命名为 *.bak）"
    echo "  [3] 跳过已存在的文件"
    echo "  [4] 取消"
    read -rp "请输入选项 [1-4]: " choice
    case "$choice" in
        1) OVERWRITE_MODE="overwrite" ;;
        2) OVERWRITE_MODE="backup" ;;
        3) OVERWRITE_MODE="skip" ;;
        *) error "已取消" ;;
    esac
fi

# ─── 复制函数 ─────────────────────────────────────────────────────────────────
copy_item() {
    local src_rel="$1"           # 相对于 SCRIPT_DIR 的路径
    local src="$SCRIPT_DIR/$src_rel"
    local dst="$TARGET_DIR/$src_rel"

    if [[ ! -e "$src" ]]; then
        warn "源文件不存在，跳过：$src_rel"
        return
    fi

    if [[ -e "$dst" ]]; then
        case "$OVERWRITE_MODE" in
            skip)
                warn "跳过（已存在）：$src_rel"
                return
                ;;
            backup)
                local bak="${dst}.bak"
                mv "$dst" "$bak"
                warn "已备份：$src_rel → ${src_rel}.bak"
                ;;
            overwrite)
                rm -rf "$dst"
                ;;
        esac
    fi

    local dst_parent
    dst_parent="$(dirname "$dst")"
    mkdir -p "$dst_parent"

    if [[ -d "$src" ]]; then
        cp -r "$src" "$dst"
    else
        cp "$src" "$dst"
    fi

    success "已复制：$src_rel"
}

# ─── 执行复制 ─────────────────────────────────────────────────────────────────
echo ""
info "开始复制文件..."
echo ""

copy_item ".workspace"
copy_item ".claude/skills"
copy_item ".claude/memory"
copy_item ".claude/settings.json"
copy_item "CLAUDE.md"

# ─── 创建 requirements 目录（占位） ─────────────────────────────────────────
REQUIREMENTS_DIR="$TARGET_DIR/requirements"
if [[ ! -d "$REQUIREMENTS_DIR" ]]; then
    mkdir -p "$REQUIREMENTS_DIR"
    # 创建 .gitkeep 使空目录可被 git 跟踪
    touch "$REQUIREMENTS_DIR/.gitkeep"
    success "已创建：requirements/ 目录"
fi

# ─── 更新 .gitignore ─────────────────────────────────────────────────────────
GITIGNORE="$TARGET_DIR/.gitignore"
GITIGNORE_ENTRIES=("requirements/blockers.md" "requirements/eval-report.md")
if [[ -f "$GITIGNORE" ]]; then
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if ! grep -qF "$entry" "$GITIGNORE"; then
            echo "$entry" >> "$GITIGNORE"
            info ".gitignore 追加：$entry"
        fi
    done
else
    printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > "$GITIGNORE"
    success "已创建 .gitignore"
fi

# ─── 完成提示 ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}  初始化完成！${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo "  目标项目：$TARGET_DIR"
echo ""
echo "  下一步："
echo "    1. 打开 CLAUDE.md，根据项目实际情况更新知识索引"
echo "    2. 在 .workspace/architecture.md 填充技术栈和架构决策"
echo "    3. 使用 Claude Code 运行 /plan 开始需求规划"
echo ""
