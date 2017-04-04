#!/usr/bin/env bash

# This basically just takes all of the instructions from DigitalOcean's "How To Set Up an OpenVPN Server on Ubuntu 16.04" and puts them into a single script.

# Define functions.

    function exportReplace {
        ek="export KEY_${1}="
        sed -i "s/${ek}\".*\"/${ek}\"${2}\"/g" vars
    }

    function getPublicInterface {
        pubInterface="$(ip route | grep default)"
        pubInterface="$(echo $pubInterface | grep -oP -m 1 "dev .*?( |$)" | head -1)"
        pubInterfaceLen=${#pubInterface};
        if [ "${pubInterface:$pubInterfaceLen:1}" = " " ]; then
            ((pubInterfaceLen--))
        fi
        ((pubInterfaceLen-=4))
        pubInterface=${pubInterface:4:$pubInterfaceLen}
        echo $pubInterface
    }

    function getIPAddress {
        ip route get 1.1.1.1 | awk '{print $NF; exit}'
    }

    function getAdditionToBeforeRules {
        pubInterface="$(getPublicInterface)"
        echoStr=""
        echoStr=$echoStr"\n# START OPENVPN RULES"
        echoStr=$echoStr"\n# NAT table rules"
        echoStr=$echoStr"\n*nat"
        echoStr=$echoStr"\n:POSTROUTING ACCEPT [0:0]"
        echoStr=$echoStr"\n# Allow traffic from OpenVPN client to ${pubInterface}"
        echoStr=$echoStr"\n-A POSTROUTING -s 10.8.0.0/8 -o ${pubInterface} -j MASQUERADE"
        echoStr=$echoStr"\nCOMMIT"
        echoStr=$echoStr"\n# END OPENVPN Rules"
        echoStr=$echoStr"\n"
        echoStr=$echoStr"\n"
        echo -e $echoStr
    }

# Check root privileges.

    if [[ $(id -u) -ne 0 ]] ; then 
        echo "This script must be run as root."
        exit 1
    fi

# Step 1: Install OpenVPN

    apt-get update
    apt-get install -y openvpn easy-rsa

# Step 2: Set up the CA directory and switch to it.

    make-cadir ~/openvpn-ca
    cd ~/openvpn-ca

# Step 3: Configure the CA Variables

    # Get information from user to customize vars.

        printf "\n\nSetup will need to customize the VPN server.  Some information will need"
        printf "\nto be collected."
        printf "\nDon't use quotation marks in any of these.  It'll mess stuff up."
        printf "\nDon't leave anything blank."

        printf "\n\nPlease enter email address:"
        read emailAddress

        printf "\n\nPlease enter country code (i.e., \"US\",\"CA\", etc):"
        read countryCode

        printf "\n\nPlease enter state or province code (i.e., \"NY\",\"MI\"):"
        read provinceCode

        printf "\n\nPlease enter city name (but remove spaces, i.e., SanFrancisco):"
        read cityName

        printf "\n\nPlease enter organization name (could be The Illuminati for all I care):"
        read orgName

        printf "\n\nPlease enter organizational unit (Seriously, what does that even mean?):"
        read OUName

        printf "\n\nIn a short while, another program is going to ask you to confirm these."
        printf "\nIt will do this multiple times.  You can just press Enter on all of them."
        printf "\nto confirm."
        printf "\nIMPORTANT!  One of the setup programs will ask you to enter a"
        printf "\n\"challenge\" password.  Leave it blank and just hit [Enter]."
        #printf "\nHowever, when asked to create a PEM password, be sure to use a strong one."
        printf "\nWhen a setup program asks you a y/n question, respond with \"y\"."
        printf "\nPress [Enter] now to continue with install."
        read -p ""

    # Customize vars file and run it.

        exportReplace "COUNTRY" $countryCode
        exportReplace "PROVINCE" $provinceCode
        exportReplace "CITY" $cityName
        exportReplace "ORG" $orgName
        exportReplace "EMAIL" $emailAddress
        exportReplace "OU" $OUName
        exportReplace "NAME" "server"

# Step 4: Build the Certificate Authority

    source vars

    ./clean-all
    ./build-ca

# Step 5: Create the Server Certificate, Key, and Encryption Files

    ./build-key-server server
    ./build-dh

    openvpn --genkey --secret keys/ta.key

# Step 6: Generate a Client Certificate and Key Pair

    source vars
    ./build-key client1

# Step 7: Configure the OpenVPN Service

    # Copy the Files to the OpenVPN Directory
        cd ~/openvpn-ca/keys
        sudo cp ca.crt ca.key server.crt server.key ta.key dh2048.pem /etc/openvpn
        gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/server.conf

    # Adjust the OpenVPN Configuration

        confFile='/etc/openvpn/server.conf' #Note!  This var is used later in the script, not just in this section.

        subString="tls-auth ta.key 0 # This file is secret"
        oldString=";${subString}"
        newString="${subString}\nkey-direction 0"
        sed -i "s/${oldString}/${newString}/g" $confFile

        subString="cipher AES-128-CBC"
        oldString=";${subString}"
        newString="${subString}\nauth SHA256"
        sed -i "s/${oldString}/${newString}/g" $confFile

        subString="user nobody"
        oldString=";${subString}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $confFile

        subString="group nogroup"
        oldString=";${subString}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $confFile

        subString="push \"redirect-gateway def1 bypass-dhcp\""
        oldString=";${subString}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $confFile

        subString='push "dhcp-option DNS 208.67.222.222"'
        oldString=";${subString//./\\.}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $confFile

        subString="push \"dhcp-option DNS 208.67.220.220\""
        oldString=";${subString//./\\.}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $confFile

# Step 8: Adjust the Server Networking Configuration.

    # Allow IP Forwarding

        subString="net.ipv4.ip_forward=1"
        oldString="#${subString//./\\.}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" /etc/sysctl.conf
        
        sudo sysctl -p

    # Adjust the UFW Rules to Masquerade Client Connections

        fileName="/etc/ufw/before.rules"
        newRules="$(getAdditionToBeforeRules)"
        fileContents="$(awk -v "n=10" -v "s=${newRules}" '(NR==n) { print s } 1' ${fileName})"
        echo "${fileContents}" > $fileName

        oldString="DEFAULT_FORWARD_POLICY=\"DROP\""
        newString="DEFAULT_FORWARD_POLICY=\"ACCEPT\""
        sed -i "s/${oldString}/${newString}/g" /etc/default/ufw

    # Open the OpenVPN Port and Enable the Changes

        ufw allow 1194/udp
        ufw allow OpenSSH
        ufw disable
        ufw enable

# Step 9: Start and Enable the OpenVPN Service

    systemctl start openvpn@server
    systemctl enable openvpn@server

# Step 10: Create Client Configuration Infrastructure

    # Creating the Client Config Directory Structure

        mkdir -p ~/client-configs/files
        chmod 700 ~/client-configs/files

    # Creating a Base Configuration

        fileName="${HOME}/client-configs/base.conf"
        cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf $fileName
        ipAddress="$(getIPAddress)"

        sed -i "s/my-server-1/${ipAddress}/g" $fileName

        subString="user"
        oldString=";${subString}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $fileName

        subString="group"
        oldString=";${subString}"
        newString="${subString}"
        sed -i "s/${oldString}/${newString}/g" $fileName

        subString="ca ca.crt"
        oldString="${subString/\./\\.}"
        newString="#${subString}"
        sed -i "s/${oldString}/${newString}/g" $fileName

        subString="cert client.crt"
        oldString="${subString/\./\\.}"
        newString="#${subString}"
        sed -i "s/${oldString}/${newString}/g" $fileName

        subString="key client.key"
        oldString="${subString/\./\\.}"
        newString="#${subString}"
        sed -i "s/${oldString}/${newString}/g" $fileName

        echo "">> "${fileName}"
        echo "cipher AES-128-CBC">> "${fileName}"
        echo "auth SHA256" >> "${fileName}"
        echo "key-direction 1" >> "${fileName}"
        echo "#script-security 2" >> "${fileName}"
        echo "#up /etc/openvpn/update-resolv-conf" >> "${fileName}"
        echo "#down /etc/openvpn/update-resolv-conf" >> "${fileName}"

    # Creating a Configuration Generation Script

        makeConfigStr="
            # First argument: Client identifier

            KEY_DIR=~/openvpn-ca/keys
            OUTPUT_DIR=~/client-configs/files
            BASE_CONFIG=~/client-configs/base.conf

            cat \${BASE_CONFIG} \\
                <(echo -e '<ca>') \\
                \${KEY_DIR}/ca.crt \\
                <(echo -e '</ca>\n<cert>') \\
                \${KEY_DIR}/\${1}.crt \\
                <(echo -e '</cert>\n<key>') \\
                \${KEY_DIR}/\${1}.key \\
                <(echo -e '</key>\n<tls-auth>') \\
                \${KEY_DIR}/ta.key \\
                <(echo -e '</tls-auth>') \\
                > \${OUTPUT_DIR}/\${1}.ovpn
        "

        echo "#!/bin/bash" > "${HOME}/client-configs/make_config.sh"
        echo "${makeConfigStr}" >> "${HOME}/client-configs/make_config.sh"

        chmod 700 ~/client-configs/make_config.sh

# Step 11: Generate Client Configurations

    cd ~/client-configs
    ./make_config.sh client1

# Copy VPN configuration to /root, so it's the same path for everyone.

    cp ~/client-configs/files/client1.ovpn /root
