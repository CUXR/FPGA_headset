#!/usr/bin/env bash
# Source from Bash. Parameters belong in each module's testbench.

echo "Setting up Verification commands..."

VERIF_BASE="${PROJ_BASE}/verif"

_verif_modules() {
  local file directory
  for file in "$VERIF_BASE"/*/filelist.f; do
    [[ -f "$file" ]] || continue
    directory="${file%/filelist.f}"
    printf '%s\n' "${directory##*/}"
  done
}

_verif_cases() {
  awk '
    { gsub(/^[ \t]+|[ \t]+$/, "") }
    $0 != "" && $0 !~ /^#/ { print }
  ' "$VERIF_BASE/$1/cases.list"
}

# Returns 0 for a listing, 1 for a normal invocation, 2 for an invalid module.
_verif_list() {
  if [[ $# -eq 1 && "$1" == --list ]]; then
    _verif_modules
    return 0
  fi

  if [[ -z "${1:-}" || ! -f "$VERIF_BASE/$1/filelist.f" ]]; then
    echo "Specify a module; use --list to list modules." >&2
    return 2
  fi

  if [[ $# -eq 2 && "$2" == --list ]]; then
    _verif_cases "$1"
    return $?
  fi

  return 1
}

_verif_compile() {
  local module="$1" directory="$2"
  iverilog -g2012 -Wall -s "tb_$module" \
    -o "$directory/test.vvp" -f "verif/$module/filelist.f" \
    > "$directory/compile.log" 2>&1
  local result=$?
  if (( result != 0 )); then
    cat "$directory/compile.log"
  fi
  return "$result"
}

lint() (
  _verif_list "$@"
  local result=$?
  (( result == 1 )) || return "$result"

  if [[ $# -ne 1 ]]; then
    echo "Usage: lint <module> | lint [module] --list" >&2
    return 2
  fi

  if ! command -v verilator >/dev/null 2>&1; then
    echo "lint requires Verilator; install it and ensure it is on PATH." >&2
    return 127
  fi

  cd "$PROJ_BASE" || return 1
  local directory="$PROJ_BASE/sim/$1/lint"
  mkdir -p "$directory" || return 1
  # Verilator includes source excerpts, line/column numbers, and carets.
  # Check the complete testbench; --timing supports its clock and task delays.
  verilator --lint-only --timing -Wall -Wno-fatal --error-limit 0 \
    --top-module "tb_$1" -f "verif/$1/filelist.f" \
    > "$directory/compile.log" 2>&1
  result=$?
  cat "$directory/compile.log"
  (( result == 0 )) || return "$result"
  echo "Lint passed: $1"
)

echo "  'lint' command created."

sim() (
  _verif_list "$@"
  local result=$?
  (( result == 1 )) || return "$result"

  if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: sim <module> <case> [seed] | sim [module] --list" >&2
    return 2
  fi

  local module="$1" name="$2" seed="${3:-1}"
  if [[ ! "$seed" =~ ^[0-9]+$ ]] || (( seed > 2147483647 )); then
    echo "Seed must be an integer from 0 to 2147483647." >&2
    return 2
  fi

  local found directory
  found=$(awk -v name="$name" '
    { gsub(/^[ \t]+|[ \t]+$/, "") }
    $0 == name && $0 !~ /^#/ { print "yes"; exit }
  ' "$VERIF_BASE/$module/cases.list")

  if [[ -z "$found" ]]; then
    echo "Unknown case: $name. Use sim $module --list." >&2
    return 2
  fi

  directory="$PROJ_BASE/sim/$module/$name/seed_$seed"
  cd "$PROJ_BASE" || return 1
  mkdir -p "$directory" || return 1
  _verif_compile "$module" "$directory" || return $?

  vvp -N "$directory/test.vvp" "+TEST=$name" "+SEED=$seed" \
    > "$directory/simulation.log" 2>&1
  result=$?
  cat "$directory/simulation.log"
  echo "Logs: $directory"
  return "$result"
)

echo "  'sim' command created."

regress() (
  _verif_list "$@"
  local result=$?
  (( result == 1 )) || return "$result"

  if [[ $# -ne 1 ]]; then
    echo "Usage: regress <module> | regress [module] --list" >&2
    return 2
  fi

  local name total=0 failed=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    total=$((total + 1))
    sim "$1" "$name" 1 || failed=$((failed + 1))
  done < <(_verif_cases "$1")

  echo "Regression: $((total - failed)) passed, $failed failed"
  (( total > 0 && failed == 0 ))
)

echo "  'regress' command created."

clean() (
  _verif_list "$@"
  local result=$?
  (( result == 1 )) || return "$result"

  if [[ $# -ne 1 ]]; then
    echo "Usage: clean <module> | clean --list" >&2
    return 2
  fi

  rm -rf "$PROJ_BASE/sim/$1"
  echo "Cleaned: $1"
)

clean_all() (
  rm -rf "$PROJ_BASE/sim"
  echo "Cleaned all simulation directories."
)

echo "  'clean' and 'clean_all' commands created."
