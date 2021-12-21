set -ex

echo "Activate authorized key for SSH login and disable Password Authentication"
mkdir -pv /home/deploy/.ssh

cat > /home/deploy/.ssh/authorized_keys << "EOF"
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQClHs7Rk29cYGqh8jS1tkq42h1bWJfMKLvWQ5pgnxIWar4Z+ehNJyefRSL4zuYj+SZVnd2sTycSHlcFBfLEwnZNbkJ1szY6+qMXExYZBDbeZElMZZWkjTDX4tDgVAOgIGUkIkWHbwZrpbqKEzAQYuqv7vU0bRW2EXKsBX+oYYTD0w6MMA9hLih4DlSEg9ZH0W3UIyzV1+tWGWD1cWhPtPO9JSAk3IOnX9Y5FXuqgECKkiNZRM7j3AarI/AKSpqnr5x/ArrlUube67VTBCa9i/jcglMcuCvRooX1IyMEwAeXINfCwzl+yQOefvoWM6/KPfMwx9jBaxAn86ecQfO0oo9nYLBMZ7H5HvKvcyTUice8e+LXdjeGicBwRpTHarIEh9WSKL383LIk3rHWaqpMO3WTd5AZy/OV1q/Yj7IoqLoGM7mzbgEqbMe9nmxnCujERjBYrYhixHQ++GBo6XLTHGEuVhykugKalnlHuzJkmWyibssVR2zXIz3vS4plMVYBN0k= sgarland@Stephan’s-MacBook-Pro
EOF

chown -Rv deploy:deploy /home/deploy/.ssh
chmod -v 700 /home/deploy/.ssh
chmod -v 600 /home/deploy/.ssh/authorized_keys

# UseDNS value is No which avoids login delays when the remote client's DNS cannot be resolved
sed -i "/^#UseDNS/c\UseDNS no" /etc/ssh/sshd_config
sed -i "/^#PermitRootLogin/c\PermitRootLogin no" /etc/ssh/sshd_config
sed -i "/^#PasswordAuthentication/c\PasswordAuthentication no" /etc/ssh/sshd_config
