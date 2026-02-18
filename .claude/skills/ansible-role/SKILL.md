---
name: ansible-role
description: Create or modify Ansible roles in the maodevops.mac collection following project conventions
---

# Ansible Role Conventions for maodevops.mac

When creating or modifying roles under `collections/ansible_collections/maodevops/mac/roles/`, follow these rules:

## tasks/main.yml must only contain import statements

The `tasks/main.yml` file in every role **must not contain any tasks directly**. It should only contain `ansible.builtin.import_tasks` statements that reference other task files in the same `tasks/` directory. Each import must have a `tags` key so that individual task groups can be targeted with `--tags`.

### Example tasks/main.yml

```yaml
---
- name: Configure git user settings
  ansible.builtin.import_tasks: config.yml
  tags: git-config

- name: Configure global gitignore
  ansible.builtin.import_tasks: ignore.yml
  tags: git-ignore
```

### Tag naming convention

Tags follow the pattern `<role_name>-<task_group>`, e.g. `brew-packages`, `git-config`, `certs-install`.

## Role file structure

Every role must have at minimum:

```
roles/<role_name>/
├── defaults/main.yml    # default variables
├── meta/main.yml        # role metadata
└── tasks/
    ├── main.yml         # only import_tasks statements
    ├── <group1>.yml     # actual tasks
    └── <group2>.yml     # actual tasks
```

## meta/main.yml template

```yaml
---
galaxy_info:
  author: mao
  description: <role description>
  license: GPL-2.0-or-later
  min_ansible_version: '2.15'

dependencies: []
```

## Variable layering (base + extra)

Variables are defined outside the collection in `vars/` at the repo root:

- `vars/base.yml` — team-wide defaults, checked into git
- `vars/user.yml` — personal overrides, gitignored (see `vars/user.yml.example`)

**Do not put variable values inline in `setup_mac.yml`.** All variables go in the vars files.

For **list** variables that users may extend, use the `_base` / `_extra` pattern:

- Define `<var>_base` in `vars/base.yml` (team defaults)
- Default `<var>_extra` to `[]` in the role's `defaults/main.yml`
- Combine them in `defaults/main.yml`: `<var>: "{{ <var>_base + <var>_extra }}"`
- Users add items via `<var>_extra` in their `vars/user.yml`

For **scalar** variables (strings, booleans), use the plain name in both files — `user.yml` naturally overrides `base.yml`.

### Example defaults/main.yml with list merging

```yaml
---
brew_packages_base: []
brew_packages_extra: []
brew_packages: '{{ brew_packages_base + brew_packages_extra }}'
```

## After creating or modifying a role

- Add the role to `collections/ansible_collections/maodevops/mac/playbooks/setup_mac.yml` if it is new.
- Run `ansible-playbook --syntax-check collections/ansible_collections/maodevops/mac/playbooks/setup_mac.yml` to validate.
