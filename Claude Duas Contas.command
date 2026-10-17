#!/bin/bash
# ============================================================================
#  Claude Duas Contas
#  Cria uma segunda cópia do Claude Desktop no Mac, com login separado,
#  para usar conta pessoal e conta do trabalho ao mesmo tempo.
#
#  Como usar: dê dois cliques neste arquivo. Na primeira vez, se o macOS
#  bloquear, clique com o botão direito > Abrir.
#
#  Baseado nos guias de Rafael Pazini (dev.to / github.com/rflpazini/articles)
#  e Rodrigo Peixoto (LinkedIn). Não é um app oficial da Anthropic.
#  Use por sua conta e risco; em Mac da empresa, confira a política de TI.
# ============================================================================

set -uo pipefail

TITLE="Claude Duas Contas"
STORE="$HOME/Library/Application Support/Claude Duas Contas"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

# ---------- janelas do macOS ----------

msg() {
  osascript - "$1" "$TITLE" <<'EOF' >/dev/null 2>&1
on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button 1 with title (item 2 of argv) with icon note
end run
EOF
}

fail() {
  echo "ERRO: $1"
  osascript - "$1" "$TITLE" <<'EOF' >/dev/null 2>&1
on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button 1 with title (item 2 of argv) with icon stop
end run
EOF
  exit 1
}

# pergunta com dois botões; devolve o texto do botão clicado (vazio se cancelar)
ask_buttons() {
  osascript - "$1" "$2" "$3" "$TITLE" <<'EOF' 2>/dev/null
on run argv
  set r to display dialog (item 1 of argv) buttons {item 2 of argv, item 3 of argv} default button 2 with title (item 4 of argv)
  return button returned of r
end run
EOF
}

ask_text() {
  osascript - "$1" "$2" "$TITLE" <<'EOF' 2>/dev/null
on run argv
  set r to display dialog (item 1 of argv) default answer (item 2 of argv) buttons {"Cancelar", "Continuar"} default button 2 cancel button 1 with title (item 3 of argv)
  return text returned of r
end run
EOF
}

choose_one() {
  # $1 = pergunta, demais = opções
  osascript - "$TITLE" "$@" <<'EOF' 2>/dev/null
on run argv
  set t to item 1 of argv
  set p to item 2 of argv
  set opts to items 3 thru -1 of argv
  set c to choose from list opts with title t with prompt p default items {item 1 of opts}
  if c is false then return ""
  return item 1 of c
end run
EOF
}

pick_image() {
  osascript <<'EOF' 2>/dev/null
set f to choose file with prompt "Escolha uma imagem quadrada (PNG ou JPG) para o ícone da segunda conta" of type {"public.image"}
return POSIX path of f
EOF
}

# ---------- utilidades ----------

claude_running() {
  pgrep -x "Claude" >/dev/null 2>&1 || pgrep -x "Claude-bin" >/dev/null 2>&1
}

wait_for_claude_closed() {
  while claude_running; do
    local r
    r=$(ask_buttons "Feche todas as janelas do Claude antes de continuar (Cmd + Q em cada uma, não basta minimizar)." "Cancelar" "Já fechei")
    [[ "$r" == "Já fechei" ]] || exit 0
  done
}

make_slug() {
  local s
  s=$(printf '%s' "$1" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]')
  [[ -n "$s" ]] || s="segunda"
  printf '%s' "$s"
}

make_icns() {
  # $1 = imagem de origem, $2 = .icns de saída
  local tmp set s
  tmp=$(mktemp -d)
  set="$tmp/icon.iconset"
  mkdir "$set"
  for s in 16 32 128 256 512; do
    sips -s format png -z "$s" "$s" "$1" --out "$set/icon_${s}x${s}.png" >/dev/null 2>&1 || return 1
    sips -s format png -z $((s*2)) $((s*2)) "$1" --out "$set/icon_${s}x${s}@2x.png" >/dev/null 2>&1 || return 1
  done
  iconutil -c icns "$set" -o "$2" >/dev/null 2>&1 || return 1
  rm -rf "$tmp"
}

list_copies() {
  local d
  for d in "$APPDIR"/Claude\ -\ *.app; do
    [[ -d "$d" ]] && basename "$d" .app | sed 's/^Claude - //'
  done
}

# ---------- verificações iniciais ----------

[[ "$(uname)" == "Darwin" ]] || fail "Este script só funciona no macOS."

SRC=""
for p in "/Applications/Claude.app" "$HOME/Applications/Claude.app"; do
  [[ -d "$p" ]] && SRC="$p" && break
done
[[ -n "$SRC" ]] || fail "Não encontrei o Claude.app em Aplicativos. Instale o Claude Desktop primeiro."
APPDIR="$(dirname "$SRC")"
mkdir -p "$STORE"

# ---------- remover ----------

remove_copy() {
  local copies=() line name dst exe data r
  while IFS= read -r line; do copies+=("$line"); done < <(list_copies)
  [[ ${#copies[@]} -gt 0 ]] || { msg "Não encontrei nenhuma segunda conta criada por este script."; exit 0; }

  name=$(choose_one "Qual cópia você quer remover?" "${copies[@]}")
  [[ -n "$name" ]] || exit 0
  dst="$APPDIR/Claude - $name.app"

  wait_for_claude_closed

  exe=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$dst/Contents/Info.plist" 2>/dev/null || echo "Claude")
  data=$(grep -o 'Application Support/Claude-[a-z0-9]*' "$dst/Contents/MacOS/$exe" 2>/dev/null | head -1 | sed 's|Application Support/||')

  rm -rf "$dst" || fail "Não consegui apagar $dst."

  if [[ -n "$data" && -d "$HOME/Library/Application Support/$data" ]]; then
    r=$(ask_buttons "App removido. Quer apagar também o login e o histórico local dessa conta? (as conversas continuam salvas na sua conta online)" "Manter" "Apagar")
    if [[ "$r" == "Apagar" ]]; then
      rm -rf "$HOME/Library/Application Support/$data"
      rm -f "$STORE/$data.icns"
    fi
  fi
  killall Dock >/dev/null 2>&1 || true
  msg "Pronto! \"Claude - $name\" foi removido. O Claude original continua intacto."
  exit 0
}

# ---------- criar ou atualizar ----------

create_copy() {
  local default_name first name slug dst data_name pl exe icon_file icns r img

  first=$(list_copies | head -1)
  default_name="${first:-Pessoal}"

  name=$(ask_text "Nome da segunda conta (vai aparecer como \"Claude - Nome\" no Dock):" "$default_name") || exit 0
  name=$(printf '%s' "$name" | sed 's/^ *//; s/ *$//')
  [[ -n "$name" ]] || fail "O nome não pode ficar vazio."

  slug=$(make_slug "$name")
  dst="$APPDIR/Claude - $name.app"
  data_name="Claude-$slug"
  icns="$STORE/$data_name.icns"

  # ícone
  if [[ -f "$icns" ]]; then
    r=$(ask_buttons "Encontrei o ícone que você escolheu da última vez. Quer manter ou trocar?" "Trocar" "Manter")
    [[ "$r" == "Trocar" ]] && rm -f "$icns"
  fi
  if [[ ! -f "$icns" ]]; then
    r=$(ask_buttons "Quer escolher uma imagem para diferenciar o ícone da segunda conta no Dock?" "Pular" "Escolher imagem")
    if [[ "$r" == "Escolher imagem" ]]; then
      img=$(pick_image)
      if [[ -n "$img" ]]; then
        make_icns "$img" "$icns" || { rm -f "$icns"; msg "Não consegui converter essa imagem. Vou seguir com o ícone padrão."; }
      fi
    fi
  fi

  wait_for_claude_closed

  echo "→ Copiando o Claude..."
  rm -rf "$dst"
  cp -R "$SRC" "$dst" || fail "Não consegui copiar o Claude.app. Verifique se sua conta do Mac é de administrador."

  pl="$dst/Contents/Info.plist"
  exe=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$pl" 2>/dev/null) || fail "Não consegui ler o Info.plist do Claude."

  echo "→ Separando o login..."
  mv "$dst/Contents/MacOS/$exe" "$dst/Contents/MacOS/$exe-bin" || fail "Não consegui preparar o app."
  cat > "$dst/Contents/MacOS/$exe" <<EOF
#!/bin/bash
exec "\$(dirname "\$0")/$exe-bin" --user-data-dir="\$HOME/Library/Application Support/$data_name" "\$@"
EOF
  chmod +x "$dst/Contents/MacOS/$exe"

  # Importante: NÃO mexer em CFBundleName (o Electron usa para achar os helpers).
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.anthropic.claudefordesktop.$slug" "$pl"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Claude - $name" "$pl" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Claude - $name" "$pl"

  if [[ -f "$icns" ]]; then
    echo "→ Aplicando o ícone..."
    icon_file=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$pl" 2>/dev/null || echo "electron.icns")
    [[ "$icon_file" == *.icns ]] || icon_file="$icon_file.icns"
    cp "$icns" "$dst/Contents/Resources/$icon_file"
    # sem isso o macOS ignora o .icns e usa o ícone do Assets.car
    /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$pl" 2>/dev/null || true
  fi

  echo "→ Assinando a cópia (para o macOS aceitar abrir)..."
  xattr -cr "$dst"
  codesign --force --deep --sign - "$dst" >/dev/null 2>&1 || fail "Não consegui assinar a cópia. Se este Mac é da empresa, a TI pode estar bloqueando."

  mkdir -p "$HOME/Library/Application Support/$data_name"
  [[ -x "$LSREGISTER" ]] && "$LSREGISTER" -f "$dst" >/dev/null 2>&1
  touch "$dst"
  killall Dock >/dev/null 2>&1 || true

  echo "→ Pronto!"
  r=$(ask_buttons "Pronto! Agora faça o primeiro login, um app de cada vez:

1. Abra só o \"Claude - $name\" e entre com a conta dele.
   Se o Mac pedir sua senha (Keychain), é normal: digite e clique em Permitir sempre.
2. Feche ele (Cmd + Q).
3. Abra o Claude original e entre com a outra conta.

Depois disso, pode deixar os dois abertos juntos.

Se um dia os dois começarem a abrir na mesma conta (geralmente depois de uma atualização do Claude), é só rodar este arquivo de novo." "Fechar" "Abrir \"Claude - $name\" agora")
  [[ "$r" == "Fechar" || -z "$r" ]] || open "$dst"
  exit 0
}

# ---------- menu ----------

ACTION=$(choose_one "O que você quer fazer?" "Criar ou atualizar a segunda conta" "Remover a segunda conta")
case "$ACTION" in
  "Criar ou atualizar a segunda conta") create_copy ;;
  "Remover a segunda conta") remove_copy ;;
  *) exit 0 ;;
esac
