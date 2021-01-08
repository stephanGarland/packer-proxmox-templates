# Proxmox Builder

### Acknowledgement
This is forked from [Christian Wagner's work](https://github.com/chriswayg/packer-proxmox-templates).

### Limitations
Only the debian10-amd64 role has been modified. If you want to use another one, either use the original above, or submit a PR.

### Prerequisites

-  [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) - tested on 2.10.

-  [j2cli](https://github.com/kolypto/j2cli)

-  [dialog](https://invisible-island.net/dialog/) - optional, but it lets you use a glorious 90s menu.

-  [Packer](https://github.com/hashicorp/packer/releases) - tested on v1.55 and v1.66.

-  [Proxmox](https://www.proxmox.com/en/downloads/category/iso-images-pve) VE 6

### Usage
From within `debian-10-amd64-proxmox`, execute either `../build.sh` or `../build_menu.sh`. The former is from the original repo, with some modifications to support extra customizations. The latter requires dialog (might work with whiptail) to be installed, but is arguably easier to use than remembering 10 positional arguments. It includes the same default values as the non-TUI script, which you can modify as desired.

#### Arguments

- VM_NODE       - Name of the Proxmox node to look up - defaults to pve
- VM_NET_BRIDGE - Network bridge to use - defaults to vmbr0
- VM_ROLE       - (prod|dev) - dev loads extra packages - defaults to prod
- VM_SOCKETS    - Number of sockets for template - defaults to 1
- VM_CORES      - Number of cores for template - defaults to 4
- VM_MEM        - Size of RAM (in kilobytes) - defaults to 2048
- VM_DISK       - Size of disk (with suffix) - defaults to 8G
- VM_ZFS        - Build support for ZFS - defaults to false
- VM_ZSH        - Add zsh customized with Oh My Zsh and some plugins - defaults to false
- VM_ID         - ID for template - defaults to 999

#### Things You Need To Change
- In `debian-10-amd64-proxmox/playbook/server-template-vars.yml`, you'll need to replace my public key with yours. This sets up password-less SSH auth, so without a key, you're gonna have a bad time.

#### Things You Might Want To Change
- `vmbr0` is usually the default network bridge in Proxmox. You may not want VMs being built to get an IP address handed out from there.
- You may want to set a static IP. That's actually not handled here, it's in the `ansible-initial-server` repo that this one calls.
- Speaking of, you may need to bump the version in `debian-10-amd64-proxmox/playbook/requirements.yml`. Check releases for [ansible-initial-server](https://github.com/stephanGarland/ansible-initial-server/releases).
- Still speaking of, the above repo, in `files/20-motd-welcome` will create a lovely ASCII art image for you. Your terminal should be >= 125 columns wide to see it correctly. If you think 80 is the right number, please don't use my repos. Also, if you want to change it, clone that repo and edit the file, or clone that repo and remove the Ansible task.

#### Things This Doesn't Do
- Set a user password. It could if you wanted to modify the user Ansible task, or run `passwd` as a shell task, or any other number of ways. Set it manually if you don't want to do those; also of note, this sets up password-less sudo so it's not really needed for most tasks.

#### Packages This May Install
If you select the dev role, you'll get things that I think are important.

- awscli
- build-essential
- consul
- docker
- gcloud
- golang
- kubectx
- linux-headers
- terraform
- terragrunt
- packer
- vault

Also, the following Python libraries:

- ipython
- jupyter
- matplotlib
- mypy
- numpy
- pandas
- requests
- seaborn
- scipy
- virtualenv

Regardless of whether you select prod or dev, you're still getting things I think are important.

 - fail2ban
 - git
 - glances
 - htop
 - jq
 - mc
 - micro
 - ncdu
 - parallel
 - pigz
 - pv
 - python3
 - rclone
 - screen
 - silversearcher-ag
 - tmux
 - tree
 - zsh
 
### Questions and Answers
Q: Will you do this for another distribution?
A: No, I stan Debian.

Q: Really?
A: Mostly. I might do RancherOS or pfSense eventually.

Q: What about Ubuntu?
A: [Debian, you peasant.](http://ars.userfriendly.org/cartoons/?id=19990301)

Q: Will you do this for ESXi/Hyper-V/whatever-FreeNAS-calls-its-hypervisor?
A: No.

Q: Was this a tremendous waste of time for a task that you do maybe once every few years?
A: Yes.