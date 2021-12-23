#!/usr/bin/env bash

# 'vm_default_user' and 'vm_memory' will be sourced from build.conf
# and passed as environment variables to Packer
set -o allexport
build_conf="build.conf"

help() {
    printf "\n"
    echo "$0 (proxmox|debug) [VM_NODE] [VM_NET_BRIDGE] [VM_ROLE] [VM_SOCKETS] [VM_CORES] [VM_MEM] [VM_DISK] [VM_ZFS] [VM_ID]"
    echo
    echo "proxmox   - Build and create a Proxmox VM template"
    echo "debug     - Debug Mode: Build and create a Proxmox VM template"
    echo
    echo "VM_NODE       - Name of the node to lookup - defaults to pve"
    echo "VM_NET_BRIDGE - Network bridge to use - defaults to vmbr0"
    echo "VM_ROLE       - (prod|dev) - dev loads extra packages - defaults to prod"
    echo "VM_SOCKETS    - Number of sockets for template - defaults to 2"
    echo "VM_CORES      - Number of cores for template - defaults to 4"
    echo "VM_MEM        - Size of RAM (in megabytes) - defaults to 8192"
    echo "VM_DISK       - Size of disk (with suffix) - defaults to 8G"
    echo "VM_ZFS        - Build support for ZFS - defaults to false"
    echo "VM_ID         - ID for template - defaults to 999"
    echo
    echo "Enter Passwords when prompted or provide them via ENV variables:"
    echo "(use a space in front of ' export' to keep passwords out of bash_history)"
    echo " export proxmox_password=MyLoginPassword"
    echo " export ssh_password=MyPasswordInVM"
    printf "\n"
    exit 0
}

die_var_unset() {
    echo "ERROR: Variable '$1' is required to be set. Please edit '${build_conf}' and set."
    exit 1
}

check_prereqs() {
    for i in ansible j2 mkpasswd packer; do
        command -v $i &> /dev/null
        if [[ ! $? -eq 0 ]]; then
            printf "\nThe following programs are required to be installed:\n\n"
            printf "ansible\nj2cli\nmkpasswd\npacker\n"
            printf "\nPlease install them, and try again\n"
            exit 1
        fi
    done
}

## check that data in build_conf is complete
[[ -f $build_conf ]] || { echo "User variables file '$build_conf' not found."; exit 1; }
source $build_conf

[[ -z "$vm_default_user" ]] && die_var_unset "vm_default_user"
[[ -z "$default_vm_id" ]] && die_var_unset "default_vm_id"
[[ -z "$iso_url" ]] && die_var_unset "iso_url"
[[ -z "$iso_sha256_url" ]] && die_var_unset "iso_sha256_url"
[[ -z "$iso_directory" ]] && die_var_unset "iso_directory"

## check that build-mode (proxmox|debug) is passed to script
target=${1:-}
[[ "${1}" == "proxmox" ]] || [[ "${1}" == "debug" ]] || help

## check that prerequisites are installed
check_prereqs

# These will override defaults set in build.conf
vm_node=${2:-$default_vm_node}
vm_net_bridge=${3:-$default_net_bridge}
vm_role=${4:-$default_vm_role}
vm_sockets=${5:-$default_vm_sockets}
vm_cores=${6:-$default_vm_cores}
vm_mem=${7-$default_vm_mem}
vm_disk=${8:-$default_vm_disk}
vm_zfs=${9:-$default_vm_zfs}
vm_id=${10:-$default_vm_id}
printf "\n==> Node: $vm_node"
printf "\n==> Net Bridge: $vm_net_bridge"
printf "\n==> VM ID: $vm_id"
printf "\n==> User: $vm_default_user"
printf "\n==> Role: $vm_role"
printf "\n==> Sockets: $vm_sockets"
printf "\n==> Cores: $vm_cores"
printf "\n==> Mem: $vm_mem"
printf "\n==> Disk: $vm_disk"
printf "\n==> ZFS: $vm_zfs\n"

read -p "Continue with the above settings? (y/n) " -n 1 -r
if [[ $REPLY =~ ^[Nn]$ ]]; then
    printf "\nExiting\n"
    exit 1
else
    printf "\nContinuing\n"
fi

## template_name is based on name of current directory, check it exists
template_name="${PWD##*/}.json"

[[ -f $template_name ]] || { echo "Template (${template_name}) not found."; exit 1; }

## If passwords are not set in env variable, prompt for them
[[ -z "$proxmox_password" ]] && printf "\n" && read -s -p "Existing PROXMOX Login Password: " proxmox_password && printf "\n"
printf "\n"

if [[ -z "$ssh_password" ]]; then
    while true; do
        read -s -p "Enter  new SSH Password: " ssh_password
        printf "\n"
        read -s -p "Repeat new SSH Password: " ssh_password2
        printf "\n"
        [ "$ssh_password" = "$ssh_password2" ] && break
        printf "Passwords do not match. Please try again!\n\n"
    done
fi

[[ -z "$proxmox_password" ]] && echo "The Proxmox Password is required." && exit 1
[[ -z "$ssh_password" ]] && echo "The SSH Password is required." && exit 1

## download ISO and Ansible role
printf "\n=> Downloading and checking ISO\n\n"
iso_filename=$(basename $iso_url)
wget -P $iso_directory -N $iso_url                  # only re-download when newer on the server
wget --no-verbose $iso_sha256_url -O $iso_directory/SHA256SUMS  # always download and overwrite
(cd $iso_directory && cat $iso_directory/SHA256SUMS | grep $iso_filename | sha256sum --check)
if [ $? -eq 1 ]; then echo "ISO checksum does not match!"; exit 1; fi

printf "\n=> Downloading Ansible role\n\n"
# will always overwrite role to get latest version from Github
ansible-galaxy install --force -p playbook/roles -r playbook/requirements.yml
[[ -f playbook/roles/ansible-initial-server/tasks/main.yml ]] || { echo "Ansible role not found."; exit 1; }

# the vm_default_user name will be used by Packer and Ansible
export vm_default_user=$vm_default_user
export ssh_password=$ssh_password

mkdir -p http

# j2 is the better solution than 'envsubst' which messes up '$' in the text unless you specify each variable

# Debian & Ubuntu
## Insert the password hashes for root and default user into preseed.cfg using a Jinja2 template
if [[ -f preseed.cfg.j2 ]]; then
    export password_hash1=$(mkpasswd -R 1000000 -m sha-512 $ssh_password)
    export password_hash2=$(mkpasswd -R 1000000 -m sha-512 $ssh_password)
    printf "\n=> Customizing auto preseed.cfg\n"
    j2 preseed.cfg.j2 > http/preseed.cfg
    [[ -f http/preseed.cfg ]] || { echo "Customized preseed.cfg file not found."; exit 1; }
fi

# OpenBSD
## Insert the password hashes for root and default user into install.conf using a Jinja2 template
if [[ -f install.conf.j2 ]]; then
    export password_hash1=$(python3 -c "import os, bcrypt; print(bcrypt.hashpw(os.environ['ssh_password'], bcrypt.gensalt(10)))")
    export password_hash2=$(python3 -c "import os, bcrypt; print(bcrypt.hashpw(os.environ['ssh_password'], bcrypt.gensalt(10)))")
    printf "\n=> Customizing install.conf\n"
    j2 install.conf.j2 > http/install.conf
    [[ -f http/install.conf ]] || { echo "Customized install.conf file not found."; exit 1; }
fi

vm_ver=$(git describe --tags)

## Call Packer build with the provided data
case $target in
    proxmox)
        printf "\n==> Build and create a Proxmox template.\n\n"
        # single quotes such as -var 'vm_id=$vm_id' do not work here
        packer build -var iso_filename=$iso_filename -var vm_ver=$vm_ver -var vm_id=$vm_id -var proxmox_password=$proxmox_password -var ssh_password=$ssh_password $template_name
        ;;
    debug)
        printf "\n==> DEBUG: Build and create a Proxmox template.\n\n"
        PACKER_LOG=1 packer build -debug -on-error=ask -var iso_filename=$iso_filename -var vm_ver=$vm_ver -var vm_id=$vm_id -var proxmox_password=$proxmox_password -var ssh_password=$ssh_password $template_name
        ;;
    *)
        help
        ;;
esac

## remove file which has the hashed passwords
[[ -f http/preseed.cfg ]] && printf "=> " && rm -v http/preseed.cfg
[[ -f http/install.conf ]] && printf "=> " && rm -v http/install.conf
