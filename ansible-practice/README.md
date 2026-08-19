# Ansible Architecture Practice Sandbox

Welcome to your safe Ansible architecture playground! This directory is 100% isolated from your working Pair B production pipeline (`ansible/`). 

Here you can experiment with **Multi-Group Inventories**, **Role Modularization**, and **Variable Precedence Resolution** without breaking your VMs or Jenkins!

---

## 📁 Directory Architecture Overview

```text
ansible-practice/
├── inventory/
│   └── hosts               <-- Multi-tier inventory ([webservers], [dbservers])
├── group_vars/
│   ├── all.yml             <-- Global variables (Company name, NTP)
│   ├── webservers.yml      <-- Web tier variables (app_port: 8080)
│   └── dbservers.yml       <-- DB tier variables (mysql_port: 3306)
├── host_vars/
│   └── web-node-1.yml      <-- Single node override (app_port: 9090)
├── roles/
│   ├── webserver/          <-- Custom role 1
│   │   └── tasks/main.yml
│   └── dbserver/           <-- Custom role 2
│       └── tasks/main.yml
└── playbook.yml            <-- Master multi-play execution file
```

---

## 🧪 Experiments You Can Run (Safe Sandbox Commands)

Run these commands from inside the `ansible-practice/` directory:

### Experiment 1: Inspect Variable Precedence Resolution
Run this command to see how Ansible resolves variables for `web-node-1` vs `web-node-2` without making any real SSH connections:

```bash
# Check how app_port resolves across different hosts:
ansible -i inventory/hosts webservers -m debug -a "var=app_port" --connection=local
```

**What you will observe:**
- `web-node-2` gets `app_port: 8080` (Inherited from `group_vars/webservers.yml`, overriding `all.yml`).
- `web-node-1` gets `app_port: 9090` (Inherited from `host_vars/web-node-1.yml`, overriding both `webservers.yml` and `all.yml`!).

---

### Experiment 2: Dry-Run Playbook Task Resolution
See how plays and roles are mapped to specific server groups:

```bash
ansible-playbook -i inventory/hosts playbook.yml --list-tasks
ansible-playbook -i inventory/hosts playbook.yml --list-hosts
```

---

### Experiment 3: Test Level 3 Extra-Vars Override
Test how CLI `-e` flags override all files:

```bash
ansible -i inventory/hosts web-node-1 -m debug -a "var=app_port" -e "app_port=12345" --connection=local
```

**Observation:** Even though `host_vars` set `9090`, the `-e` flag forces port `12345`!

---

## 🛡️ How to Defend this Architecture to your Mentor

1. **Why `group_vars/all.yml`?**
   *"We use `all.yml` for baseline corporate defaults (like NTP or logging) shared by 100% of hosts."*

2. **Why `group_vars/webservers.yml`?**
   *"We use tier-specific group_vars to configure architectural layers (like web vs database) without cluttering global scope."*

3. **Why `host_vars`?**
   *"We use `host_vars` for edge-case individual node overrides (like primary vs standby node ports) without breaking the group tier settings."*
