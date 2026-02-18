# ansible-collection-mac

Ansible-based provisioning for Mac workstations. Run a single command on a fresh Mac to install Homebrew, Python, Ansible, and all the tools your team needs.

## Quick start

1. Create environment vars file for setup by downloading the example file
   ```shell
   curl -sSfL -o setup.env https://raw.githubusercontent.com/maodevops/ansible-collection-mac/refs/heads/main/setup.env.example
   ```
2. Edit the `setup.env` files with the values for your system
3. Source it
   ```shell
   source setup.env
   ```
4. Run the `setup.sh` script
   ```shell
   /bin/bash -c "$(curl https://raw.githubusercontent.com/maodevops/ansible-collection-mac/refs/heads/main/setup.sh)" </dev/tty
   ``` 


The `setup.sh` script does the following:

1. Installs Homebrew (if missing)
2. Installs [uv](https://docs.astral.sh/uv/) via Homebrew
3. Installs Python via `uv python install`
4. Creates a virtualenv and activates it
5. Installs Ansible in the virtualenv
6. Runs the Ansible playbook which sets up the Mac development system

Every step is idempotent — re-running the script skips anything already installed.

## Personalizing your setup

The playbook loads variables from two files in the `vars/` directory:

| File | Purpose | Checked in? |
|---|---|---|
| `vars/base.yml` | Team-wide defaults (shared packages, gitignore patterns) | Yes |
| `vars/user.yml` | Your personal overrides and additions | No (gitignored) |

To add your own customizations, copy the example file and edit it:

```bash
cp vars/user.yml.example vars/user.yml
```

Then edit `vars/user.yml` to set your git identity and add any extra packages:

```yaml
brew_packages_extra:
  - ncdu
  - htop

git_user_name: "Jane Doe"
git_user_email: "jane.doe@example.com"
```

Your extras are merged with the team baseline — you don't need to repeat what's already in `base.yml`.

## Running specific tasks with tags

Every task group has a tag so you can run only what you need:

```bash
source ~/.venvs/ansible-latest/bin/activate
ansible-playbook collections/ansible_collections/maodevops/mac/playbooks/setup_mac.yml --tags brew-packages
ansible-playbook collections/ansible_collections/maodevops/mac/playbooks/setup_mac.yml --tags git-config,git-ignore
```

Available tags:

| Tag | Description |
|---|---|
| `brew-packages` | Homebrew formulae |
| `brew-casks` | Homebrew casks |
| `git-config` | Git user.name and user.email |
| `git-ignore` | Global gitignore |

## Repo structure

```
.
├── setup.sh                          # Bootstrap script
├── ansible.cfg                       # Ansible configuration
├── vars/
│   ├── base.yml                      # Team-wide default variables
│   ├── user.yml.example              # Template for personal overrides
│   └── user.yml                      # Your personal overrides (gitignored)
└── collections/ansible_collections/maodevops/mac/
    ├── galaxy.yml                    # Collection metadata
    ├── playbooks/
    │   └── setup_mac.yml             # Main playbook
    └── roles/
        ├── brew/                     # Homebrew packages and casks
        └── git/                      # Git global configuration
```

## Adding a new role

Create the role under `collections/ansible_collections/maodevops/mac/roles/<role_name>/` with at minimum:

```
roles/<role_name>/
├── defaults/main.yml
├── meta/main.yml
└── tasks/
    ├── main.yml          # import_tasks statements only
    └── <task_group>.yml  # actual tasks
```

Add the role to `setup_mac.yml`:

```yaml
roles:
  - role: maodevops.mac.<role_name>
```

If the role introduces list variables that users should be able to extend, add the `_base` values to `vars/base.yml` and default `_extra` to `[]` in the role's `defaults/main.yml`. See existing roles for examples.
