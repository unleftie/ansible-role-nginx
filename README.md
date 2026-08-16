# Ansible Role for nginx setup

[![CI](https://github.com/unleftie/ansible-role-nginx/actions/workflows/ci.yml/badge.svg)](https://github.com/unleftie/ansible-role-nginx/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/unleftie/ansible-role-nginx/badge)](https://securityscorecards.dev/viewer/?uri=github.com/unleftie/ansible-role-nginx)

## Compatibility

| Platform | Version |
| -------- | ------- |
| debian   | 12      |

## Dependencies

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (v2.14+)
- [Molecule](https://molecule.readthedocs.io/en/latest/installation.html) + (v4.0.4+) + [docker plugin](https://github.com/ansible-community/molecule-plugins) (for local testing)
- [Docker](https://docs.docker.com/get-docker/) (for local testing)

## Role dependencies

- iptables `required`
- iptables persistent `optional`

## Local Testing

```sh
git clone https://github.com/unleftie/ansible-role-nginx.git
cd ansible-role-nginx/
molecule test
```

- For ease of use, you can install and/or upgrade Molecule, the Molecule plugins package, and the Docker Python SDK by running the following command on your Ansible host:

  ```bash
  pip install --upgrade -r https://raw.githubusercontent.com/nginx/ansible-role-nginx/main/.github/workflows/requirements/requirements_molecule.txt
  ```

## Role Installation

This role can be installed via either Ansible Galaxy (the Ansible community marketplace) or by cloning this repo. Once installed, you will need to include the role in your Ansible playbook using [the `roles` keyword, the `import_role` module, or the `include_role` module](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#using-roles).

> Upgradability notice: When upgrading from old version of this role, be aware that some files may be lost.

```yml
- name: Sample 1
  hosts: all
  become: true
  pre_tasks:
    - name: Ensure apt cache are updated
      apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"
  tasks:
    - include_role:
        name: "ansible-role-nginx"
```

## 📝 License

This project is licensed under the [Apache License 2.0](LICENSE).
