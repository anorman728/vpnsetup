# vpnsetup

Some scripts to (partially) automate creating an OpenVPN server on Digital Ocean.

These scripts go along with [a YouTube video series](https://www.youtube.com/playlist?list=PL04PA2q0LfJIWfXOc_Iw_4qUJUdSlIo8N).

Once you have a have a DigitalOcean droplet up-and-running (should be Ubuntu 16.04), the process is pretty simple:

    Get "initialserversetup.sh" onto the droplet.  This can be done with `wget https://anorman728.com/vpnsetup/initialserversetup.sh` or by whatever method you like.

    Run the "initialiserversetup.sh" file with something like `sudo bash initialserversetup.sh`.

    Follow the on-screen instructions.

    Log out, then log back in as the new user that was created while running initialserversetup.sh.

    Get "vpnsetup.sh" onto the droplet.  This can be done with `wget https://anorman728.com/vpnsetup/vpnsetup.sh` or by whatever method you like.

    Run "vpnsetup.sh" with something like `sudo bash vpnsetup.sh`.

    Follow the on-screen instructions.

The script creates an OVPN file in the /root directory.  Get that file off of the server using sftp and you should be able to use it with an OpenVPN client.
