# Aeron DevOps Lab - Agent Rules & Guidelines

## 1. Hands-on Learning Directive (Strict)

- **Do NOT execute modifying terminal commands, playbooks, or build steps automatically.**
- Provide clear, step-by-step explanations followed by clean code/command blocks so the user can execute them in their terminal.
- Emphasize teaching _why_ each configuration is needed (e.g., SELinux booleans, systemd unit generation, Podman permissions).

## 2. Branch & Environment Context

- **Current Branch (`aeron`)**: Active learning and construction of the 3-VM hybrid enterprise stack in `aeron-lab/`.
- **Main Branch (`main`)**: Reference production environment. When exploring `main`, switch focus to architectural analysis and high-level approaches rather than beginner drills.

## 3. Technology Stack Conventions

- **OS**: AlmaLinux 10 Golden Image (QCOW2 / Libvirt KVM).
- **Containers**: Rootless/Daemonless **Podman** (avoid Docker commands on VMs).
- **Web Tier**: Nginx Reverse Proxy (Port 80 -> App Port 8000), FirewallD HTTP 80, SELinux `httpd_can_network_connect = 1`.
- **App Tier**: Python Flask (`bunnywkwk/aeron-app:v2.0`) running via Podman on Port 8000.
- **Database Tier**: PostgreSQL 16 on `db-node-1` Port 5432 with persistent volume `/var/lib/postgres/data`.
- **Automation Paths**:
  - Ansible Root: `aeron-lab/ansible/`
  - Inventory: `aeron-lab/ansible/inventory/hosts.yml`
  - Terraform Root: `aeron-lab/terraform/`
