#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/fmt-infra.sh [--check]

Format or check Terraform and Terragrunt files for this repo.

Options:
  --check   Run in CI-style check mode instead of rewriting files
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_mode=false

while (($# > 0)); do
  case "$1" in
    --check)
      check_mode=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

terragrunt_dirs=()

for terragrunt_dir in "${repo_root}"/infra/*/terragrunt; do
  if [[ -d "${terragrunt_dir}" ]]; then
    terragrunt_dirs+=("${terragrunt_dir}")
  fi
done

if [[ ${#terragrunt_dirs[@]} -eq 0 ]]; then
  echo "No Terragrunt roots found under ${repo_root}/infra" >&2
  exit 1
fi

for terragrunt_dir in "${terragrunt_dirs[@]}"; do
  terraform_modules_dir="${terragrunt_dir}/modules"

  if [[ ! -d "${terraform_modules_dir}" ]]; then
    echo "Terraform modules directory not found: ${terraform_modules_dir}" >&2
    exit 1
  fi

  if [[ "${check_mode}" == true ]]; then
    terraform fmt -check -recursive "${terraform_modules_dir}"
    (
      cd "${terragrunt_dir}"
      terragrunt hcl format --check
    )
  else
    terraform fmt -recursive "${terraform_modules_dir}"
    (
      cd "${terragrunt_dir}"
      terragrunt hcl format
    )
  fi
done
