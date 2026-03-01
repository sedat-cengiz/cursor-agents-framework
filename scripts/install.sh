#!/usr/bin/env bash
# Cursor Agents Framework — Project Installer (Bash)
# Usage: ./install.sh [project-path]

set -euo pipefail

PROJECT_PATH="${1:-.}"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"
FRAMEWORK_PATH="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  Cursor Agents Framework — Project Setup     ║"
echo "  ║  Modular Multi-Agent System v3.0             ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  Framework: $FRAMEWORK_PATH"
echo "  Project:   $PROJECT_PATH"
echo ""

TARGET_RULES="$PROJECT_PATH/.cursor/rules"
TARGET_DOCS="$PROJECT_PATH/docs/agents"

if [ ! -d "$FRAMEWORK_PATH/core" ]; then
    echo "  ERROR: Framework core not found at $FRAMEWORK_PATH" >&2
    exit 1
fi

mkdir -p "$TARGET_RULES"

# Check for manifest
MANIFEST=""
if [ -f "$PROJECT_PATH/agents.manifest.json" ]; then
    MANIFEST="$PROJECT_PATH/agents.manifest.json"
    echo "  Using manifest: $MANIFEST"
fi

# ═══════════════════════════════════════
# STEP 1: Core (always)
# ═══════════════════════════════════════
echo "  [1/6] Core rules..."
cp -f "$FRAMEWORK_PATH"/core/*.mdc "$TARGET_RULES/"
echo "        ✓ global-conventions, orchestrator, code-quality"

# ═══════════════════════════════════════
# STEP 2: Technology
# ═══════════════════════════════════════
echo ""
echo "  [2/6] Technology packs..."

if [ -n "$MANIFEST" ] && command -v jq &>/dev/null; then
    TECHS=$(jq -r '.layers.technology[]' "$MANIFEST" 2>/dev/null || true)
    for t in $TECHS; do
        FILE="tech-${t}.mdc"
        if [ -f "$FRAMEWORK_PATH/technology/$FILE" ]; then
            cp -f "$FRAMEWORK_PATH/technology/$FILE" "$TARGET_RULES/"
            echo "        ✓ $FILE"
        else
            echo "        ✗ $FILE (not found)"
        fi
    done
else
    echo "    1) .NET Backend      2) React Frontend    3) Python Backend"
    echo "    4) SQL Server        5) .NET MAUI Mobile  6) AI/ML"
    echo "    7) DevOps            8) Security          9) Testing"
    echo "    A) ALL"
    read -rp "  Select (e.g. 1289 or A): " TECH_CHOICE

    declare -A TECH_MAP=(
        [1]="tech-dotnet" [2]="tech-react" [3]="tech-python"
        [4]="tech-sql-server" [5]="tech-maui" [6]="tech-ai-ml"
        [7]="tech-devops" [8]="tech-security" [9]="tech-testing"
    )

    if [[ "$TECH_CHOICE" =~ ^[Aa]$ ]]; then
        cp -f "$FRAMEWORK_PATH"/technology/*.mdc "$TARGET_RULES/"
        echo "        ✓ All technology packs installed"
    else
        for (( i=0; i<${#TECH_CHOICE}; i++ )); do
            c="${TECH_CHOICE:$i:1}"
            PACK="${TECH_MAP[$c]:-}"
            if [ -n "$PACK" ] && [ -f "$FRAMEWORK_PATH/technology/$PACK.mdc" ]; then
                cp -f "$FRAMEWORK_PATH/technology/$PACK.mdc" "$TARGET_RULES/"
                echo "        ✓ $PACK.mdc"
            fi
        done
    fi
fi

# ═══════════════════════════════════════
# STEP 3: Process (always)
# ═══════════════════════════════════════
echo ""
echo "  [3/6] Process rules..."
cp -f "$FRAMEWORK_PATH"/process/*.mdc "$TARGET_RULES/"
echo "        ✓ process-analysis, process-architecture, process-documentation"

# ═══════════════════════════════════════
# STEP 4: Domain
# ═══════════════════════════════════════
echo ""
echo "  [4/6] Domain packs..."

if [ -n "$MANIFEST" ] && command -v jq &>/dev/null; then
    DOMAINS=$(jq -r '.layers.domain[]?' "$MANIFEST" 2>/dev/null || true)
    if [ -z "$DOMAINS" ]; then
        echo "        ✓ No domain in manifest"
    else
        for d in $DOMAINS; do
            DPATH="$FRAMEWORK_PATH/domains/$d"
            if [ -d "$DPATH" ]; then
                cp -f "$DPATH"/*.mdc "$TARGET_RULES/"
                echo "        ✓ $d domain pack"
            else
                echo "        ✗ $d (not found)"
            fi
        done
    fi
else
    i=1
    declare -A DOMAIN_MAP
    for d in "$FRAMEWORK_PATH"/domains/*/; do
        DNAME="$(basename "$d")"
        [ "$DNAME" = "_template" ] && continue
        echo "    $i) $DNAME"
        DOMAIN_MAP[$i]="$DNAME"
        ((i++))
    done
    echo "    0) None"
    read -rp "  Select domain(s) (e.g. 12 or 0): " D_CHOICE

    if [ "$D_CHOICE" != "0" ]; then
        for (( i=0; i<${#D_CHOICE}; i++ )); do
            c="${D_CHOICE:$i:1}"
            DNAME="${DOMAIN_MAP[$c]:-}"
            if [ -n "$DNAME" ] && [ -d "$FRAMEWORK_PATH/domains/$DNAME" ]; then
                cp -f "$FRAMEWORK_PATH/domains/$DNAME"/*.mdc "$TARGET_RULES/"
                echo "        ✓ $DNAME domain pack"
            fi
        done
    else
        echo "        ✓ No domain selected"
    fi
fi

# ═══════════════════════════════════════
# STEP 5: Learning + Docs
# ═══════════════════════════════════════
echo ""
echo "  [5/6] Learning system + docs structure..."

cp -f "$FRAMEWORK_PATH/learning/agent-learning.mdc" "$TARGET_RULES/"

for sub in "" requirements decisions contracts handoffs reviews; do
    mkdir -p "$TARGET_DOCS/$sub"
done

if [ -d "$FRAMEWORK_PATH/standards" ]; then
    cp -f "$FRAMEWORK_PATH"/standards/*.md "$TARGET_DOCS/" 2>/dev/null || true
fi

[ -f "$TARGET_DOCS/lessons-learned.md" ] || printf "# Proje Ogrenme Gunlugu\n\n> Bu dosya proje boyunca biriken ogrenmeleri icerir.\n" > "$TARGET_DOCS/lessons-learned.md"
[ -f "$TARGET_DOCS/taskboard.md" ]       || printf "# Gorev Tablosu\nSon Guncelleme: $(date +%Y-%m-%d)\n\n### BACKLOG\n\n### IN PROGRESS\n\n### DONE\n" > "$TARGET_DOCS/taskboard.md"
[ -f "$TARGET_DOCS/workflow-state.md" ]   || printf "# Workflow State\nAktif Faz: Analiz\nSon Guncelleme: $(date +%Y-%m-%d)\n" > "$TARGET_DOCS/workflow-state.md"

echo "        ✓ Learning + docs/agents/ structure created"

# ═══════════════════════════════════════
# STEP 6: Aliases
# ═══════════════════════════════════════
echo ""
echo "  [6/6] Creating aliases..."

declare -A ALIASES=(
    [sef]="orchestrator" [review]="code-quality"
    [backend]="tech-dotnet" [frontend]="tech-react"
    [qa]="tech-testing" [db]="tech-sql-server"
    [guvenlik]="tech-security" [devops]="tech-devops"
    [mobil]="tech-maui" [ai]="tech-ai-ml"
    [mimari]="process-architecture" [analist]="process-analysis"
    [dokumantasyon]="process-documentation"
)

ALIAS_LIST=""
for alias in "${!ALIASES[@]}"; do
    SOURCE="$TARGET_RULES/${ALIASES[$alias]}.mdc"
    TARGET="$TARGET_RULES/${alias}.mdc"
    if [ -f "$SOURCE" ] && [ "$alias" != "${ALIASES[$alias]}" ]; then
        cp -f "$SOURCE" "$TARGET"
        ALIAS_LIST="$ALIAS_LIST @$alias"
    fi
done

echo "        ✓ Aliases:$ALIAS_LIST"

# ═══════════════════════════════════════
# DONE
# ═══════════════════════════════════════
echo ""
echo "  ════════════════════════════════════════════════"
echo "   Cursor Agents Framework installed!"
echo ""
echo "   Next steps:"
echo "   1. Open project in Cursor"
echo "   2. Edit .cursor/rules/global-conventions.mdc"
echo "      - Fill project name and platform"
echo "      - Adjust technology stack if needed"
echo "   3. Start with @sef for task coordination"
echo "  ════════════════════════════════════════════════"
echo ""
