#!/usr/bin/env bash
set -euo pipefail

repo_raw_base="https://raw.githubusercontent.com/Mrchazaaa/scripts/main"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
src_dir="${script_dir}/src"

fallback_scripts=(
  "install-git.sh"
  "install-docker.sh"
  "install-nvim.sh"
  "install-tmux.sh"
)

scripts=()
if [[ -d "$src_dir" ]]; then
  while IFS= read -r script; do
    scripts+=("$(basename "$script")")
  done < <(find "$src_dir" -maxdepth 1 -type f -name "*.sh" | sort)
fi

if [[ ${#scripts[@]} -eq 0 ]]; then
  scripts=("${fallback_scripts[@]}")
fi

if ! { exec 3<>/dev/tty; } 2>/dev/null; then
  echo "An interactive terminal is required to select scripts." >&2
  exit 1
fi

run_script() {
  local script_name="$1"
  local local_script="${src_dir}/${script_name}"
  local remote_script="${repo_raw_base}/src/${script_name}"

  echo
  echo "Running ${script_name}..."

  if [[ -f "$local_script" ]]; then
    bash "$local_script"
  else
    if ! command -v curl >/dev/null 2>&1; then
      echo "curl is required to run ${script_name} from GitHub." >&2
      return 1
    fi

    curl -fsSL "$remote_script" | bash
  fi
}

render_menu() {
  local cursor="$1"
  shift
  local selected=("$@")
  local index
  local marker
  local checkbox

  printf "\033[H\033[2J" >&3
  printf "Select scripts to run\n\n" >&3
  printf "Use Up/Down to move, Space to select, Enter to run, a to toggle all, q to quit.\n\n" >&3

  for index in "${!scripts[@]}"; do
    marker=" "
    checkbox="[ ]"

    if [[ "$index" -eq "$cursor" ]]; then
      marker=">"
    fi

    if [[ "${selected[$index]}" -eq 1 ]]; then
      checkbox="[x]"
    fi

    printf "%s %s %s\n" "$marker" "$checkbox" "${scripts[$index]}" >&3
  done
}

read_key() {
  local key

  IFS= read -rsn1 key <&3 || return 1
  if [[ "$key" == $'\033' ]]; then
    IFS= read -rsn2 -t 0.1 key <&3 || true
    key="${key:-}"
    case "$key" in
      "[A")
        printf "up"
        ;;
      "[B")
        printf "down"
        ;;
    esac
    return 0
  fi

  case "$key" in
    " ")
      printf "space"
      ;;
    "")
      printf "enter"
      ;;
    "a"|"A")
      printf "all"
      ;;
    "q"|"Q")
      printf "quit"
      ;;
  esac
}

choose_scripts() {
  local cursor=0
  local selected=()
  local selected_count=0
  local key
  local index
  local all_selected
  local chosen=()

  for _ in "${scripts[@]}"; do
    selected+=(0)
  done

  stty -echo -icanon time 0 min 0 <&3
  trap 'stty sane <&3; printf "\033[?25h" >&3' EXIT
  printf "\033[?25l" >&3

  while true; do
    render_menu "$cursor" "${selected[@]}"
    key="$(read_key || printf "quit")"

    case "$key" in
      up)
        if [[ "$cursor" -eq 0 ]]; then
          cursor=$((${#scripts[@]} - 1))
        else
          cursor=$((cursor - 1))
        fi
        ;;
      down)
        cursor=$(((cursor + 1) % ${#scripts[@]}))
        ;;
      space)
        if [[ "${selected[$cursor]}" -eq 1 ]]; then
          selected[$cursor]=0
          selected_count=$((selected_count - 1))
        else
          selected[$cursor]=1
          selected_count=$((selected_count + 1))
        fi
        ;;
      all)
        all_selected=1
        for index in "${!selected[@]}"; do
          if [[ "${selected[$index]}" -eq 0 ]]; then
            all_selected=0
            break
          fi
        done

        selected_count=0
        for index in "${!selected[@]}"; do
          if [[ "$all_selected" -eq 1 ]]; then
            selected[$index]=0
          else
            selected[$index]=1
            selected_count=$((selected_count + 1))
          fi
        done
        ;;
      enter)
        if [[ "$selected_count" -eq 0 ]]; then
          selected[$cursor]=1
          selected_count=1
        fi
        break
        ;;
      quit)
        selected=()
        selected_count=0
        break
        ;;
    esac
  done

  stty sane <&3
  trap - EXIT
  printf "\033[?25h\033[H\033[2J" >&3

  if [[ "$selected_count" -eq 0 ]]; then
    echo "No scripts selected." >&3
    return 0
  fi

  for index in "${!selected[@]}"; do
    if [[ "${selected[$index]}" -eq 1 ]]; then
      chosen+=("${scripts[$index]}")
    fi
  done

  printf "%s\n" "${chosen[@]}"
}

mapfile -t chosen_scripts < <(choose_scripts)

for script in "${chosen_scripts[@]}"; do
  run_script "$script"
done
