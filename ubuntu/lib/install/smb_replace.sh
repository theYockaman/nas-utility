sudo apt update
sudo apt install samba -y


sudo mkdir -p /srv/samba/share
sudo chown -R nobody:nogroup /srv/samba/share
sudo chmod -R 0775 /srv/samba/share

sudo adduser smbuser
sudo smbpasswd -a smbuser


sudo nano /etc/samba/smb.conf


[Shared]
   path = /srv/samba/share
   browseable = yes
   read only = no
   valid users = smbuser





sudo systemctl restart smbd
sudo systemctl enable smbd



sudo ufw allow samba

sudo systemctl status smbd


sudo apt update
sudo apt install smbclient -y

smbclient //localhost/shared -U smbuser

