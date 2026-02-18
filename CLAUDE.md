# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo contains two things:
1. `setup.sh` — a Bash bootstrap script that provisions the full toolchain from scratch on a fresh Mac
2. The `maodevops.mac` Ansible collection that performs the actual Mac configuration

## Bootstrap script

```bash
./setup.sh
```

The script runs these steps in order:
1. Installs Homebrew (if missing)
2. Installs `uv` via Homebrew (`brew install uv`)
3. Installs the latest Python via `uv python install`
4. Creates a virtualenv at `~/.venvs/ansible-latest` using `uv venv`
5. Activates the virtualenv and installs Ansible via `uv pip install ansible`
6. Runs `collections/ansible_collections/maodevops/mac/playbooks/setup_mac.yml`

Each step is idempotent — already-present tools are detected and skipped.

## Ansible collection: `maodevops.mac`

Collection lives at:
```
collections/ansible_collections/maodevops/mac/
```

`ansible.cfg` at the repo root sets `collections_paths = ./collections`, so Ansible resolves the `maodevops.mac` namespace automatically when run from the repo root.

### Running the playbook directly (development)

```bash
source ~/.venvs/ansible-latest/bin/activate
cd /path/to/mac
ansible-playbook collections/ansible_collections/maodevops/mac/playbooks/setup_mac.yml
```

### Adding roles

Create new roles under:
```
collections/ansible_collections/maodevops/mac/roles/<role_name>/
```

Then reference them in `setup_mac.yml`:
```yaml
roles:
  - maodevops.mac.<role_name>
```

## Logging framework (setup.sh)

Custom functions available throughout the script:

| Function | Purpose |
|---|---|
| `log.debug/info/warn/error/fatal` | Leveled output to stderr |
| `log.msg` | Unleveled colored message to stderr |
| `log.header` | Section divider with title |
| `log.line` | Horizontal rule |

Control verbosity with `LOG_LEVEL` env var (default: `DEBUG`). Valid values: `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`, `OFF`.
