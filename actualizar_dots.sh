#!/usr/bin/env bash

# Script para actualizar el repositorio dots-hyprland manteniendo las personalizaciones locales

DOTS_DIR="$HOME/dots-hyprland"

if [ ! -d "$DOTS_DIR" ]; then
    echo "❌ Error: No se encontró la carpeta $DOTS_DIR"
    exit 1
fi

cd "$DOTS_DIR" || exit 1

echo "🔄 Iniciando actualización de dots-hyprland..."

# Verificar si hay cambios locales sin guardar o pendientes de commit
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git status --porcelain)" ]; then
    echo "💾 Se detectaron cambios locales. Guardando cambios antes de actualizar..."
    git add .
    git commit -m "Respaldar cambios locales (Autosaved: $(date '+%Y-%m-%d %H:%M:%S'))"
else
    echo "✅ No hay cambios locales sin guardar."
fi

echo "📥 Descargando y aplicando actualizaciones desde el repositorio original..."
if git pull origin main --rebase; then
    echo "✨ ¡Actualización completada con éxito sin perder tus cambios locales!"
    
    # Subir automáticamente los cambios actualizados al repositorio personal en GitHub
    echo "📤 Subiendo los cambios actualizados a tu repositorio personal en GitHub..."
    if git push personal main --force-with-lease; then
        echo "🚀 ¡Cambios subidos a GitHub con éxito!"
    else
        echo "❌ Error al subir los cambios a GitHub. Es posible que debas verificar tu conexión o llaves SSH."
    fi
else
    echo "⚠️  Hubo un conflicto durante el rebase."
    echo "Por favor, resuelve los conflictos manualmente en: $DOTS_DIR"
    exit 1
fi
