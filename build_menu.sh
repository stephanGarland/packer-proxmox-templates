#!/usr/bin/env bash

check_prereqs() {
    for i in ansible dialog j2 mkpasswd packer; do
        command -v $i &> /dev/null
        if [[ ! $? -eq 0 ]]; then
            printf "\nThe following programs are required to be installed:\n\n"
            printf "ansible\ndialog\nj2\nmkpasswd\npacker\n"
            printf "\nPlease install them, and try again\n"
            exit 1
        fi
    done
}

call_dialog() {
    vm_node="pve"
    vm_role="prod"
    vm_cpu_type="host"
    vm_sockets="1"
    vm_cores="4"
    vm_mem="2048"
    vm_disk="8G"
    vm_zfs="false"
    vm_zsh="false"
    vm_id="999"
    proxmox_pass=""
    ssh_pass1=""
    ssh_pass2=""

    # Get a new fd and redirect it to stdout
    exec 3>&1

    dialog_values=$(dialog \
            --backtitle "Proxmox Template Creation" \
            --title "Create A New Template" \
            --form "Template Options" 15 50 0 \
                "Node: "     1 1 "$vm_node"      1 10 10 0 \
                "Role: "     2 1 "$vm_role"      2 10 10 0 \
                "CPU Type: " 3 1 "$vm_cpu_type"  3 10 10 0 \
                "Sockets: "  4 1 "$vm_sockets"   4 10 10 0 \
                "Cores: "    5 1 "$vm_cores"     5 10 10 0 \
                "Memory: "   6 1 "$vm_mem"       6 10 10 0 \
                "Disk: "     7 1 "$vm_disk"      7 10 10 0 \
                "ZFS: "      8 1 "$vm_zfs"       8 10 10 0 \
                "ZFS: "      9 1 "$vm_zsh"       9 10 10 0 \
                "VM ID: "    10 1 "$vm_id"       10 10 10 0 \
            --and-widget --insecure \
            --title "Create A New Template" \
            --passwordform "Template Passwords" 15 50 0 \
                "Proxmox Password: " 1 1 "$proxmox_pass" 1 32 32 0 \
                "New SSH Password: " 2 1 "$ssh_pass1"    2 32 32 0 \
                "New SSH Password: " 3 1 "$ssh_pass2"    3 32 32 0 \
            2>&1 1>&3 # Redirect stdout to fd3 and stderr to stdout
            )
    # Close fd3
    exec 3>&-
    clear
}

check_prereqs
call_dialog

# Convert the string to an array so we can easily check values, and pass them to build.sh
value_arr=($dialog_values)
if [[ ! "${value_arr[@]: -2: 1}" == "${value_arr[@]: -1}" ]]; then
    echo "ERROR: Entered SSH passwords don't match, please try again"
    exit 1
else
    # Slice elements from the end for the two passwords to pass to build.sh,
    # then unset them so they won't be visibly passed on the command line.
    proxmox_password="${value_arr[@]: -3: 1}"
    ssh_password="${value_arr[@]: -1}"
    value_arr=("${value_arr[@]: 0: 10}")
fi

export proxmox_password
export ssh_password

source ../build.sh proxmox "${value_arr[@]}"

unset proxmox_password
unset ssh_password