#!/bin/bash
# Ralph Installer - Instala o Ralph em qualquer projeto
# Uso: ./install.sh /caminho/do/projeto

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$1"

# Validacao
if [ -z "$TARGET_DIR" ]; then
  echo "Uso: ./install.sh /caminho/do/projeto"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Erro: Diretorio '$TARGET_DIR' nao existe"
  exit 1
fi

# Resolve caminho absoluto
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "Instalando Ralph em: $TARGET_DIR"
echo ""

# 1. Copiar ralph.sh
cp "$SCRIPT_DIR/ralph.sh" "$TARGET_DIR/"
echo "✓ ralph.sh copiado"

# 2. Copiar CLAUDE.md como RALPH.md
cp "$SCRIPT_DIR/CLAUDE.md" "$TARGET_DIR/RALPH.md"
echo "✓ RALPH.md criado"

# 3. Modificar ralph.sh para usar RALPH.md em vez de CLAUDE.md
sed -i 's|< "$SCRIPT_DIR/CLAUDE.md"|< "$SCRIPT_DIR/RALPH.md"|g' "$TARGET_DIR/ralph.sh"
echo "✓ ralph.sh modificado para usar RALPH.md"

# 4. Copiar prd.json.example
cp "$SCRIPT_DIR/prd.json.example" "$TARGET_DIR/"
echo "✓ prd.json.example copiado"

# 5. Criar diretorio de skills e copiar
mkdir -p "$TARGET_DIR/.claude/skills"
cp -r "$SCRIPT_DIR/skills/"* "$TARGET_DIR/.claude/skills/"
echo "✓ Skills copiadas para .claude/skills/"

# 6. Tornar executavel
chmod +x "$TARGET_DIR/ralph.sh"
echo "✓ ralph.sh marcado como executavel"

echo ""
echo "=========================================="
echo "Ralph instalado com sucesso!"
echo "=========================================="
echo ""
echo "Arquivos criados em $TARGET_DIR:"
echo "  - ralph.sh"
echo "  - RALPH.md"
echo "  - prd.json.example"
echo "  - .claude/skills/prd/SKILL.md"
echo "  - .claude/skills/ralph/SKILL.md"
echo ""
echo "Como usar:"
echo "  1. cd $TARGET_DIR"
echo "  2. /prd para gerar PRD"
echo "  3. /ralph para converter em prd.json"
echo "  4. ./ralph.sh --tool claude"
