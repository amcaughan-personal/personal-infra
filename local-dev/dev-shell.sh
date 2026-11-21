#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="aws-infra-dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERFILE="$REPO_ROOT/local-dev/docker/Dockerfile"
BUILD_CONTEXT="$REPO_ROOT/local-dev/docker"
DEFAULT_PASSTHROUGH_ENV_VARS=(
  AWS_PROFILE
  GITHUB_TOKEN
)

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  build      Build the dev image
  rebuild    Rebuild the dev image (no cache)
  run        Start an interactive shell
  destroy    Remove the dev image
  help       Show this message

The shell forwards a small allowlist of host environment variables by default.
Append more names with LOCAL_DEV_PASSTHROUGH_VARS="VAR1 VAR2".
If GITHUB_TOKEN is not already set, the shell will try to source it from
the host's gh CLI session.
EOF
}

resolve_env_value() {
  local env_name="$1"

  case "$env_name" in
    GITHUB_TOKEN)
      if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        printf '%s\n' "${GITHUB_TOKEN}"
        return 0
      fi

      if command -v gh >/dev/null 2>&1; then
        gh auth token 2>/dev/null || true
      fi
      ;;
    *)
      if [[ -n "${!env_name:-}" ]]; then
        printf '%s\n' "${!env_name}"
      fi
      ;;
  esac
}

collect_docker_env_args() {
  local env_name
  local env_value
  local -a docker_env_args=()
  local -a passthrough_env_vars=("${DEFAULT_PASSTHROUGH_ENV_VARS[@]}")

  if [[ -n "${LOCAL_DEV_PASSTHROUGH_VARS:-}" ]]; then
    # shellcheck disable=SC2206
    passthrough_env_vars+=(${LOCAL_DEV_PASSTHROUGH_VARS})
  fi

  for env_name in "${passthrough_env_vars[@]}"; do
    if [[ ! "$env_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      continue
    fi

    env_value="$(resolve_env_value "$env_name")"
    if [[ -n "$env_value" ]]; then
      docker_env_args+=(--env "$env_name=$env_value")
    fi
  done

  printf '%s\n' "${docker_env_args[@]}"
}

# Tool versions come from the repo's .tool-versions, the same file CI and root.hcl read.
tool_version() {
  awk -v tool="$1" '$1 == tool {print $2}' "$REPO_ROOT/.tool-versions"
}

tool_versions_label() {
  grep -v '^#' "$REPO_ROOT/.tool-versions" | sha256sum | cut -c1-12
}

build_args() {
  printf '%s\n' \
    --build-arg "TERRAFORM_VERSION=$(tool_version terraform)" \
    --build-arg "TERRAGRUNT_VERSION=$(tool_version terragrunt)" \
    --label "tool-versions=$(tool_versions_label)"
}

build() {
  mapfile -t args < <(build_args)
  docker build "${args[@]}" -f "$DOCKERFILE" -t "$IMAGE_NAME" "$BUILD_CONTEXT"
}

rebuild() {
  mapfile -t args < <(build_args)
  docker build --no-cache "${args[@]}" -f "$DOCKERFILE" -t "$IMAGE_NAME" "$BUILD_CONTEXT"
}

# True when the image was built from the current .tool-versions.
image_current() {
  [[ "$(docker image inspect -f '{{ index .Config.Labels "tool-versions" }}' "$IMAGE_NAME" 2>/dev/null)" == "$(tool_versions_label)" ]]
}

destroy() {
  docker rmi -f "$IMAGE_NAME"
}

run() {
  if ! image_current; then
    build
  fi

  local -a docker_env_args=()
  mapfile -t docker_env_args < <(collect_docker_env_args)

  docker run --rm -it \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace \
    -v "$HOME/.aws:/home/dev/.aws:rw" \
    "${docker_env_args[@]}" \
    "$IMAGE_NAME" \
    /bin/bash
}

if [[ $# -eq 0 ]]; then
  run
  exit 0
fi

cmd="$1"
shift || true

case "$cmd" in
  build) build ;;
  rebuild) rebuild ;;
  run) run ;;
  destroy) destroy ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
