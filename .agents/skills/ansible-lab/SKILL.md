---
name: ansible-lab
description: >-
  Use this skill when the user is writing, syntax-checking, executing,
  or debugging Ansible roles and playbooks inside aeron-lab/ansible.
---

# Ansible Lab Workflow & Runbook

This skill provides standard procedures for managing and testing the Ansible stack in `aeron-lab/ansible/`.

## 1. Inventory & Connectivity Check

Before running playbooks, guide the user to verify ping connectivity to the VM cluster:

```bash
ansible -i aeron-lab/ansible/inventory/hosts.yml all -m ping
```

## 2. Syntax & Dry-Run Verification

Always suggest verifying syntax and running check mode before full execution:

```bash
# 1. Syntax Check
ansible-playbook -i aeron-lab/ansible/inventory/hosts.yml aeron-lab/ansible/playbook.yml --syntax-check

# 2. Check Mode (Dry-Run)
ansible-playbook -i aeron-lab/ansible/inventory/hosts.yml aeron-lab/ansible/playbook.yml --check
```

## 3. Playbook Execution

```bash
ansible-playbook -i aeron-lab/ansible/inventory/hosts.yml aeron-lab/ansible/playbook.yml
```

## 4. Role-Specific Debugging Checklist

- **`roles/app_container`**:
  - Check Podman container status on web nodes: `ssh sysadmin@<ip> "podman ps -a"`
  - Check container logs: `ssh sysadmin@<ip> "podman logs <container_name>"`
- **`roles/webserver`**:
  - Verify Nginx syntax: `nginx -t`
  - Check SELinux boolean: `getsebool httpd_can_network_connect`
  - Check FirewallD ports: `firewall-cmd --list-ports`
- **`roles/db_container`**:
  - Test PostgreSQL connection: `pg_isready -h 192.168.122.103 -p 5432`
