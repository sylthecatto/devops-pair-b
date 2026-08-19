# Ansible Hands-On Practice Journal & Real-World Use Cases

This document records the exact hands-on concepts, folder structures, real-world use cases, and mentor defense justifications practiced in the `ansible-practice/` sandbox.

---

## 1. Directory Structure & Naming Conventions

Ansible relies strictly on **Convention over Configuration**. Folder and file names must match exact expected patterns:

```text
ansible-practice/
├── inventory/
│   └── hosts                <-- INI inventory defining server groups ([webservers], [dbservers])
├── group_vars/
│   ├── all.yml              <-- Global variables for EVERY server in the inventory
│   ├── webservers.yml       <-- Variables specific ONLY to [webservers] group
│   └── dbservers.yml        <-- Variables specific ONLY to [dbservers] group
├── host_vars/
│   └── web-node-1.yml       <-- Single host override (filename matches host in inventory)
├── roles/
│   ├── webserver/
│   │   ├── tasks/
│   │   │   └── main.yml     <-- Execution tasks (folder MUST be plural 'tasks')
│   │   └── handlers/
│   │       └── main.yml     <-- Dormant event listeners (folder MUST be plural 'handlers')
│   └── dbserver/
│       └── tasks/
│           └── main.yml
└── playbook.yml             <-- Master multi-play orchestration file
```

---

## 2. Real-World Deep Dive: Handlers (`notify:` & `handlers/main.yml`)

### What is a Handler?
A **Handler** is a dormant task inside `roles/<rolename>/handlers/main.yml` that only executes when explicitly triggered by a preceding task's `notify:` directive.

### How Ansible Detects Changes (Idempotency)
Every Ansible task returns a status:
- **`ok` (Green)**: The server was already in the desired state. No file edits were made. `notify:` is **ignored**.
- **`changed` (Yellow)**: Ansible detected a difference and updated the server state. `notify:` sends a signal to the handler.

### Real-World Use Cases for Handlers:
1. **Zero Unnecessary Downtime**: 
   If you run a deployment playbook 20 times a day, but `nginx.conf` hasn't changed, handlers ensure Nginx is **never restarted**, eliminating unnecessary service interruptions for users.
2. **Notification De-Duplication (Batching)**:
   If 5 different tasks in a role edit 5 different config files, and all 5 tasks specify `notify: Restart Nginx`, **Ansible only restarts Nginx ONCE at the end of the play**! It batches the restarts together.

### Cause & Effect Rule for Handlers:
$$\text{Task State is \textbf{changed}} + \text{Task has \texttt{notify: Handler Name}} \implies \text{Handler executes at the end of the play!}$$

### Verified Live Test Result:
When two separate tasks (`Update webserver configuration file` AND `Update the SSL certificate file`) both returned `changed: true` and notified `Restart WebServer Service`, Ansible batched the signals and ran `RUNNING HANDLER [webserver : Restart WebServer Service]` **EXACTLY ONCE** for `web-node-1` and `web-node-2` at the end of the play!

### Mentor Defense Script:
> *"Putting service restart commands directly inside task files causes unconditional restarts every time the playbook runs, leading to unnecessary service downtime. We use Handlers because they leverage Ansible's idempotency—they remain dormant and ONLY execute at the end of the play if a preceding task actually modified system state (`changed`). Furthermore, Handlers de-duplicate multiple restart notifications into a single execution."*

---

## 3. The Implicit `all` Group Mechanism

### Why does `db-node-1` inherit variables from `group_vars/all.yml`?
- **Implicit Core Group**: In Ansible, `all` is a reserved built-in group. Every server declared in an inventory (whether under `[webservers]`, `[dbservers]`, or ungrouped) is automatically a member of `all`.
- **Global Precedence**: Because every host is implicitly in `all`, variables declared in `group_vars/all.yml` automatically apply to 100% of hosts in the environment as the global baseline.

---

## 4. Multi-Play Playbooks vs Single-Play Playbooks

### Enterprise Standard:
Instead of forcing every server into a single play, multi-play playbooks break deployment into logical application tiers:

```yaml
---
# Play 1: Web Tier Operations
- name: Configure Web Server Tier
  hosts: webservers
  become: false
  roles:
    - webserver

# Play 2: Database Tier Operations
- name: Configure Database Server Tier
  hosts: dbservers
  become: false
  roles:
    - dbserver
```

---

## 5. Privilege Escalation (`become: true` vs `become: false`)

- **`become: true`**: Instructs Ansible to execute tasks using `sudo` / `root` privileges. Required for system configuration (modifying `/etc/`, formatting hard drives, configuring services).
- **`become: false`**: Executes tasks as the unprivileged SSH user. Used for non-root tasks (printing debug messages, local user scripts).

---

## 6. Dynamic File Generation with Jinja2 Templates (`ansible.builtin.template`)

### What is a Jinja2 Template?
Instead of creating and maintaining 50 separate static configuration files for 50 different servers, DevOps engineers write **ONE base template blueprint** ending in `.j2` (e.g. `index.html.j2` or `nginx.conf.j2`).

### How Ansible Resolves Templates:
1. Ansible reads the `.j2` template file containing placeholders (e.g., `{{ company_name }}`, `{{ inventory_hostname }}`, `{{ app_port }}`).
2. As it executes on each target host, it evaluates the exact resolved values for that host from `group_vars`, `host_vars`, or inventory.
3. Ansible writes the dynamically generated destination file onto the target server.

### Advanced Jinja2 Logic:
1. **Double Curly Braces `{{ variable }}`**: Evaluates and prints a variable's value (e.g. `listen {{ app_port }};`).
2. **Control Logic `{% statement %}`**: Executes template logic:
   - **Conditionals**: `{% if environment_type == "production" %}` ... `{% else %}` ... `{% endif %}`
   - **Loops**: `{% for ip in allowed_admin_ips %}` ... `{% endfor %}`
3. **Whitespace Control `{%-`**: Adding a hyphen `-` after `{%` tells Jinja2 to strip whitespace and newline characters from the generated output.

### Mentor Defense Script:
> *"Hardcoding separate configuration files for every server creates immense code duplication and maintenance overhead. By using Jinja2 templates (`ansible.builtin.template`), we maintain a single, standardized configuration blueprint (`.j2`). Ansible dynamically evaluates and injects node-specific variables (`app_port`, hostnames, environment parameters) at runtime, guaranteeing consistency across environments."*

---

## 7. Task Loops (`loop:`) & Conditionals (`when:`)

### Task Loops (`loop:`):
Instead of declaring separate tasks to process multiple items (packages, users, disks), a single task can iterate over a list using `loop:`. Inside the task, Ansible provides the built-in variable `{{ item }}` to represent the current iteration item.

### Task Conditionals (`when:`):
Task execution can be gated using Boolean conditions. If a `when:` expression evaluates to `false`, Ansible skips the task entirely (incrementing the `skipped` counter in the Play Recap).

### Mentor Defense Script:
> *"Instead of duplicating code blocks to process multiple packages or files, we use `loop:` to iterate over data lists cleanly. Combining loops with `when:` conditionals ensures Ansible tasks execute only on the intended target environments (e.g. production vs staging), adhering to DRY (Don't Repeat Yourself) automation principles."*

---

## 8. Error Handling (`block:`, `rescue:`, `always:`) & Play Recap Metrics

### The Master Play Recap Dictionary:
```text
PLAY RECAP ************************************************************************
web-node-1 : ok=11  changed=1  unreachable=0  failed=0  skipped=0  rescued=1  ignored=1
```

| Metric | What Triggers It? |
| :--- | :--- |
| **`ok`** | Task succeeded with no modifications required on the target server. |
| **`changed`** | Task succeeded AND modified the state of the target server. |
| **`skipped`** | A task's `when:` condition evaluated to `false`. |
| **`ignored`** | A task threw an error, BUT had `ignore_errors: true`. Ansible swallowed the error and kept running (`ignored=1`). |
| **`rescued`** | A task inside a `block:` failed, BUT a `rescue:` section caught the error and fixed it (`rescued=1`). |
| **`failed`** | A task failed (exit code $\neq$ 0) without `ignore_errors` or `rescue`, stopping execution. |
| **`unreachable`** | Ansible failed to establish an SSH connection to the server. |

### Ignored vs Rescued Error Handling:
1. **`ignore_errors: true`**: Used for non-critical tasks. If the command fails, Ansible prints `...ignoring`, records `ignored=1`, and continues to the next task.
2. **`block / rescue / always`**: Enterprise fallback pattern (`try / catch / finally`).
   - **`block:`**: Main tasks to attempt.
   - **`rescue:`**: Emergency fallback tasks that execute ONLY if a task inside `block:` fails (records `rescued=1` while keeping `failed=0`).
   - **`always:`**: Cleanup tasks that execute no matter what (success or failure).

### Mentor Defense Script:
> *"In enterprise automation, a single task failure shouldn't blindly crash an entire deployment. We use `block / rescue / always` to implement robust error-handling logic. If a primary command fails inside `block:`, Ansible automatically jumps to `rescue:` to perform emergency recovery tasks (e.g. failing over to a secondary server), while `always:` guarantees cleanup tasks execute regardless of execution state. This ensures zero orphan processes and records `rescued=1` with `failed=0` in the final Play Recap."*

---

## 9. Secrets Encryption with Ansible Vault (`ansible-vault`)

### Why Use Ansible Vault?
Hardcoding plaintext passwords (like database passwords, API tokens, or root credentials) inside Git repositories is a major security violation. `ansible-vault` uses **AES256 encryption** to scramble secret files into unreadable cipher text so they can be safely committed to GitHub.

### Key Vault Commands:
- **Create/Encrypt File:** `ansible-vault encrypt group_vars/vault.yml --vault-password-file vaultpass.txt`
- **View Encrypted File (Read-Only):** `ansible-vault view group_vars/vault.yml --vault-password-file vaultpass.txt`
- **Edit Encrypted File:** `ansible-vault edit group_vars/vault.yml --vault-password-file vaultpass.txt`
- **Decrypt Back to Plaintext:** `ansible-vault decrypt group_vars/vault.yml --vault-password-file vaultpass.txt`

### How In-Memory Decryption Works:
1. **Header Detection**: When Ansible opens a file starting with `$ANSIBLE_VAULT;1.1;AES256`, it automatically detects that the file is encrypted.
2. **RAM Decryption**: Passing `--vault-password-file vaultpass.txt` allows Ansible to decrypt the variables **inside RAM memory only** for the duration of the playbook run.
3. **Disk Security**: The physical file on disk remains 100% encrypted at all times.

### Mentor Defense Script:
> *"Committing plaintext secrets to Git violates corporate security compliance. We use `ansible-vault` (AES256) to encrypt sensitive configuration files (`group_vars/vault.yml`) before committing them to GitHub. At runtime, Jenkins passes the vault password file securely, allowing Ansible to decrypt secrets in memory only during execution while keeping disk files fully encrypted."*
