#!/usr/bin/env bash

check_prereqs() {
    for i in ansible dialog j2 mkpasswd packer; do
        command -v $i &> /dev/null
        if [[ ! $? -eq 0 ]]; then
            printf "\nThe following programs are required to be installed:\n\n"
            printf "ansible\ndialog\nj2cli\nmkpasswd\npacker\n"
            printf "\nPlease install them, and try again\n"
            exit 1
        fi
    done
}

call_dialog() {
    vm_node="pve"
    vm_net_bridge="vmbr0"
    vm_role="prod"
    vm_sockets="2"
    vm_cores="4"
    vm_mem="8192"
    vm_disk="8G"
    vm_zfs="false"
    vm_id="999"
    proxmox_pass=""
    ssh_pass1=""
    ssh_pass2=""

    # Get a new fd and redirect it to stdout
    exec 3>&1

    dialog_values=$(dialog \
            --backtitle "Proxmox Template Creation" \
            --title "Create A New Template" \
            --form "Template Options" 20 50 0 \
                "Node: "       1  1 "$vm_node"       1 15 10 0 \
                "Net Bridge: " 2  1 "$vm_net_bridge" 2 15 10 0 \
                "Role: "       3  1 "$vm_role"       3 15 10 0 \
                "Sockets: "    4  1 "$vm_sockets"    4 15 10 0 \
                "Cores: "      5  1 "$vm_cores"      5 15 10 0 \
                "Memory: "     6  1 "$vm_mem"        6 15 10 0 \
                "Disk: "       7  1 "$vm_disk"       7 15 10 0 \
                "ZFS: "        8  1 "$vm_zfs"        8 15 10 0 \
                "VM ID: "      9  1 "$vm_id"         9 15 10 0 \
            --and-widget --insecure \
            --title "Create A New Template" \
            --passwordform "Template Passwords" 20 50 0 \
                "Proxmox Password: " 1 1 "$proxmox_pass" 1 20 32 0 \
                "New SSH Password: " 2 1 "$ssh_pass1"    2 20 32 0 \
                "New SSH Password: " 3 1 "$ssh_pass2"    3 20 32 0 \
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
    # then unset them so they won't be hanging around in the shell.
    proxmox_password="${value_arr[@]: -3: 1}"
    ssh_password="${value_arr[@]: -1}"
    # This must be updated if options are added or removed to the list
    value_arr=("${value_arr[@]: 0: 9}")
fi

export proxmox_password
export ssh_password

source ../build.sh proxmox "${value_arr[@]}"

unset proxmox_password
unset ssh_password