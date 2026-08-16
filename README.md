# Ansible Role for nginx setup

[![CI](https://github.com/unleftie/ansible-role-nginx/actions/workflows/ci.yml/badge.svg)](https://github.com/unleftie/ansible-role-nginx/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/unleftie/ansible-role-nginx/badge)](https://securityscorecards.dev/viewer/?uri=github.com/unleftie/ansible-role-nginx)

## Compatibility

| Platform | Version |
| -------- | ------- |
| ubuntu   | 26.04   |

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
ansible-galaxy install -r requirements.yml
molecule test
```

- For ease of use, you can install and/or upgrade Molecule, the Molecule plugins package, and the Docker Python SDK by running the following command on your Ansible host:

  ```bash
  pip install --upgrade -r https://raw.githubusercontent.com/nginx/ansible-role-nginx/main/.github/workflows/requirements/requirements_molecule.txt
  ```

## Installation

```sh
ansible-galaxy install -r requirements.yml
```

Example [playbook](main.yml)

## 📝 License

This project is licensed under the [Apache License 2.0](LICENSE).
