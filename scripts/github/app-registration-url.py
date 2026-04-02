#!/usr/bin/env python3
"""Render a GitHub App registration URL from infra/github/terragrunt/data/apps.yaml."""

from __future__ import annotations

import argparse
from pathlib import Path
from urllib.parse import urlencode

try:
    import yaml
except ImportError as exc:  # pragma: no cover - import guard
    raise SystemExit(
        "PyYAML is required for this helper. Install it in the local dev environment and retry."
    ) from exc


DEFAULT_APPS_PATH = (
    Path(__file__).resolve().parents[2]
    / "infra"
    / "github"
    / "terragrunt"
    / "data"
    / "apps.yaml"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a GitHub App registration URL from apps.yaml."
    )
    parser.add_argument(
        "app_key",
        help="App key under apps.yaml, for example 'platform_sync'.",
    )
    parser.add_argument(
        "--apps-file",
        default=str(DEFAULT_APPS_PATH),
        help="Path to the apps.yaml file.",
    )
    return parser.parse_args()


def load_apps(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    return data.get("apps", {})


def build_registration_url(app_key: str, app_data: dict) -> str:
    registration = app_data.get("registration", {})

    owner = registration.get("owner")
    name = registration.get("name")
    if not owner or not name:
        raise SystemExit(
            f"App '{app_key}' must define registration.owner and registration.name."
        )

    base_url = f"https://github.com/organizations/{owner}/settings/apps/new"
    params: list[tuple[str, str]] = [
        ("name", str(name)),
    ]

    scalar_fields = [
        ("description", "description"),
        ("url", "url"),
        ("setup_url", "setup_url"),
        ("webhook_url", "webhook_url"),
    ]
    for source_key, param_name in scalar_fields:
        value = registration.get(source_key)
        if value:
            params.append((param_name, str(value)))

    bool_fields = [
        ("public", "public"),
        ("webhook_active", "webhook_active"),
        ("request_oauth_on_install", "request_oauth_on_install"),
        ("setup_on_update", "setup_on_update"),
    ]
    for source_key, param_name in bool_fields:
        value = registration.get(source_key)
        if value is not None:
            params.append((param_name, "true" if value else "false"))

    for callback_url in registration.get("callback_urls", []):
        params.append(("callback_urls[]", str(callback_url)))

    for permission_name, access in sorted(registration.get("permissions", {}).items()):
        params.append((permission_name, str(access)))

    for event_name in registration.get("events", []):
        params.append(("events[]", str(event_name)))

    return f"{base_url}?{urlencode(params)}"


def main() -> int:
    args = parse_args()
    apps = load_apps(Path(args.apps_file))

    if args.app_key not in apps:
        available = ", ".join(sorted(apps)) or "(none)"
        raise SystemExit(
            f"Unknown app '{args.app_key}'. Available apps: {available}"
        )

    url = build_registration_url(args.app_key, apps[args.app_key])
    print(url)
    print()
    print("Next steps:")
    print("1. Open the URL while signed into GitHub as an owner of the target org.")
    print("2. Review and submit the prefilled app registration.")
    print("3. Install the app on the selected repositories.")
    print(
        "4. Record the installation ID in "
        "infra/github/terragrunt/data/apps.yaml under apps.<name>.installation.id."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
