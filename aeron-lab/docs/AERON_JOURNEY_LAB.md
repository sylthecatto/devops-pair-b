# Aeron's 3-VM Enterprise Hybrid Stack & DevOps Journey

An isolated, end-to-end enterprise lab for building, provisioning, hardening, and automating a 3-VM infrastructure from scratch.

---

## 🏗️ 3-VM Enterprise System Architecture

```text
                                  CLIENT / BROWSER (Port 80 / 443)
                                                  │
                         ┌────────────────────────┴────────────────────────┐
                         │                                                 │
                         ▼                                                 ▼
          [ VM 1: web-node-1 ]                              [ VM 2: web-node-2 ]
          - Native Nginx Proxy (Port 80)                    - Native Nginx Proxy (Port 80)
          - App Container Box 1 (Port 8000)                 - App Container Box 2 (Port 8000)
                         │                                                 │
                         └────────────────────────┬────────────────────────┘
                                                  │
                                                  ▼
                                         [ VM 3: db-node-1 ]
                                         - PostgreSQL DB Container (Port 5432)
                                         - CIS Hardened Storage Disk
```

---

## 📋 The 6-Step Journey Plan

| Journey Step | Component | What Aeron Will Build & Type |
| :--- | :--- | :--- |
| **Step 1** | **Python App & Dockerfile** | Write Python Web API (`aeron-lab/app/app.py`) & non-root `Dockerfile` |
| **Step 2** | **Packer OS Image** | Build `alma10-golden.qcow2` image (`aeron-lab/packer/`) |
| **Step 3** | **Terraform 3-VM Infrastructure** | Provision 3 Libvirt VMs (`web-node-1`, `web-node-2`, `db-node-1`) |
| **Step 4** | **Ansible YAML Inventory & Group Vars** | Create structured inventory, `group_vars/`, and `host_vars/` |
| **Step 5** | **Ansible Roles (Native Nginx + App Container)**| Build modular roles for Nginx, App Containers, & Postgres DB |
| **Step 6** | **Jenkins CI/CD Automation** | Automate 1-click build & deployment pipeline |
