#!/usr/bin/env bash

test_tmp_root() {
  local root_dir="${1:-$(pwd)}"
  if [[ -n "${TMPDIR:-}" && -d "${TMPDIR:-}" && -w "${TMPDIR:-}" ]]; then
    printf '%s' "$TMPDIR"
    return 0
  fi
  mkdir -p "${root_dir}/.tmp"
  printf '%s' "${root_dir}/.tmp"
}

test_mktemp_dir() {
  local root_dir="${1:-$(pwd)}"
  TMPDIR="$(test_tmp_root "$root_dir")" mktemp -d
}

test_mktemp_file() {
  local root_dir="${1:-$(pwd)}" pattern="${2:-test.XXXXXX}" tmp_root
  tmp_root="$(test_tmp_root "$root_dir")"
  mktemp "${tmp_root}/${pattern}"
}
