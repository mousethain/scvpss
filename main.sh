#!/bin/bash

### Change Environment System
echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config
timedatectl set-timezone Asia/Jakarta
wget -O /etc/banner https://pastebin.com/raw/vwVpFfGE >/dev/null 2>&1
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

### System Information
TANGGAL=$(date '+%Y-%m-%d')
TIMES="10"
NAMES=$(whoami)
IMP="wget -q -O"    
CHATID="1036440597"
LOCAL_DATE="/usr/bin/"
MYIP=$(wget -qO- ipinfo.io/ip)
CITY=$(curl -s ipinfo.io/city)
TIME=$(date +'%Y-%m-%d %H:%M:%S')
RAMMS=$(free -m | awk 'NR==2 {print $2}')
KEY="2145515560:AAE9WqfxZzQC-FYF1VUprICGNomVfv6OdTU"
URL="https://api.telegram.org/bot$KEY/sendMessage"
REPO="https://raw.githubusercontent.com/manssizz/scriptvps/master/"
APT="apt-get -y install "

### Status
function print_ok() {
    echo -e "${OK} ${BLUE} $1 ${FONT}"
}

function print_error() {
    echo -e "${ERROR} ${REDBG} $1 ${FONT}"
}

function print_success() {
    if [[ 0 -eq $? ]]; then
        print_ok "$1 Complete Installing"
        sleep 1
    fi
}

### Cek root
function is_root() {
    if [[ 0 == "$UID" ]]; then
        print_ok "Root user Start installation process"
    else
        print_error "The current user is not the root user, please switch to the root user and run the script again"
    fi

}

### Update and remove packages
function base_package() {
    sudo apt-get remove && autoremove --purge -y apache2 ufw exim4 firewalld -y
    sudo add-apt-repository ppa:vbernat/haproxy-2.7 -y
    sudo apt update && apt upgrade -y
    sudo apt-get install -y --no-install-recommends software-properties-common
    sudo apt install nginx zip pwgen openssl netcat socat cron bash-completion dropbear \
    curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release \
    tar wget curl ruby zip unzip p7zip-full python3-pip haproxy libc6 util-linux build-essential \
    msmtp-mta ca-certificates bsd-mailx iptables iptables-persistent netfilter-persistent \
    net-tools openssl ca-certificates gnupg gnupg2 ca-certificates lsb-release \
    git xz-utils apt-transport-https gnupg1 dnsutils cron bash-completion ntpdate chrony jq \
    openvpn easy-rsa python3-certbot-nginx -y
    sudo apt-get remove && autoremove -y
    apt-get clean all
}
clear

### Buat direktori xray
function dir_xray() {
    mkdir -p /etc/xray
    mkdir -p /etc/vmess
    mkdir -p /etc/websocket
    mkdir -p /etc/vless
    mkdir -p /etc/trojan
    mkdir -p /etc/shadowsocks
    mkdir -p /usr/sbin/xray/
    mkdir -p /var/log/xray/
    mkdir -p /var/www/html
    chmod +x /var/log/xray
    touch /var/log/xray/access.log
    touch /var/log/xray/error.log
}

### Tambah domain
function add_domain() {
    read -rp "Input Your Domain For This Server :" -e SUB_DOMAIN
    echo "Host : $SUB_DOMAIN"
    echo $SUB_DOMAIN > /root/domain
    cp /root/domain /etc/xray/domain
}

### Pasang SSL
function pasang_ssl() {
    STOPWEBSERVER=$(lsof -i:80 | cut -d' ' -f1 | awk 'NR==2 {print $1}')
    print_success "SSL Certificate"
    rm -rf /root/.acme.sh
    mkdir /root/.acme.sh
    systemctl stop $STOPWEBSERVER
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
}

### Install Xray
function install_xray(){
    curl -s ipinfo.io/city >> /etc/xray/city
    curl -s ipinfo.io/org | cut -d " " -f 2-10 >> /etc/xray/isp
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/install-release.sh)" @ install -u www-data --version v1.7.0
    print_success "Xray Core"
    cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/xray.pem
    wget -O /etc/xray/config.json "${REPO}/xray/config.json" >/dev/null 2>&1 
    wget -O /usr/sbin/xray/xray "${REPO}/bin/xray" >/dev/null 2>&1
    wget -O /usr/sbin/websocket "${REPO}/bin/ws" >/dev/null 2>&1
    wget -O /etc/websocket/tun.conf "${REPO}/xray/tun.conf" >/dev/null 2>&1 
    wget -O /etc/systemd/system/ws.service "${REPO}/xray/ws.service" >/dev/null 2>&1 
    wget -q -O /etc/ipserver "${REPO}/server/ipserver" && bash /etc/ipserver >/dev/null 2>&1

    # > Set Permission
    chmod +x /usr/sbin/xray/xray
    chmod +x /usr/sbin/websocket
    chmod 644 /etc/websocket/tun.conf
    chmod +x /etc/systemd/system/ws.service

    # > Create Service
    rm -rf /etc/systemd/system/xray.service.d
    cat >/etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/sbin/xray/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

EOF
}

### Pasang OpenVPN
function install_ovpn(){
    source <(curl -sL ${REPO}openvpn/openvpn)
    wget -O /etc/pam.d/common-password "${REPO}openvpn/common-password" >/dev/null 2>&1
    chmod +x /etc/pam.d/common-password
    # > BadVPN
    source <(curl -sL ${REPO}badvpn/ins-badvpn)
}

### Pasang SlowDNS
function install_slowdns(){
    print_success "SlowDNS Server"
    wget -q -O /etc/nameserver "${REPO}slowdns/nameserver" && bash /etc/nameserver >/dev/null 2>&1

}

### Pasang Rclone
function pasang_rclone() {
    print_success "Rclone service"
    curl https://pastebin.com/raw/akZrwfuZ | bash
    wget -O /root/.config/rclone/rclone.conf "${REPO}rclone/rclone.conf" >/dev/null 2>&1
}

### Ambil Konfig
function download_config(){
    wget -O /etc/haproxy/haproxy.cfg "${REPO}config/haproxy.cfg" >/dev/null 2>&1
    wget -O /etc/nginx/conf.d/xray.conf "${REPO}config/xray.conf" >/dev/null 2>&1
    wget -O /etc/nginx/nginx.conf "${REPO}config/nginx.conf" >/dev/null 2>&1
    wget -q -O /etc/squid/squid.conf "${REPO}config/squid.conf" >/dev/null 2>&1
    wget -q -O /etc/default/dropbear "${REPO}config/dropbear" >/dev/null 2>&1
    wget -q -O /etc/banner "${REPO}config/banner" >/dev/null 2>&1
    
    # > Add menu, thanks to Bhoikfost Yahya <3
    wget -O ~/menu.zip "${REPO}config/XrayFT.zip" >/dev/null 2>&1
    mkdir /root/menu
    7z e -pKarawang123@bhoikfostyahya  ~/menu-master.zip -o/root/menu/ >/dev/null 2>&1
    chmod +x /root/menu/*
    mv /root/menu/* /usr/sbin/

    # > Create rc.local services
        cat >/root/.profile <<END
# ~/.profile: executed by Bourne-compatible login shells.
if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
menu
END
    cat >/etc/cron.d/xp_all <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		2 0 * * * root /usr/bin/xp
	END
    cat >/etc/cron.d/logclean <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		*/1 * * * * root /usr/bin/logclean
	END
    chmod 644 /root/.profile

    cat >/etc/cron.d/daily_reboot <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		0 5 * * * root /sbin/reboot
	END

    echo "*/1 * * * * root echo -n > /var/log/nginx/access.log" >/etc/cron.d/log.nginx
    echo "*/1 * * * * root echo -n > /var/log/xray/access.log" >>/etc/cron.d/log.xray
    service cron restart
    cat >/home/daily_reboot <<-END
		5
	END

    cat >/etc/systemd/system/rc-local.service <<-END
		[Unit]
		Description=/etc/rc.local
		ConditionPathExists=/etc/rc.local
		[Service]
		Type=forking
		ExecStart=/etc/rc.local start
		TimeoutSec=0
		StandardOutput=tty
		RemainAfterExit=yes
		SysVStartPriority=99
		[Install]
		WantedBy=multi-user.target
	END

    echo "/bin/false" >>/etc/shells
    echo "/usr/sbin/nologin" >>/etc/shells
    cat >/etc/rc.local <<-END
		#!/bin/sh -e
		# rc.local
		# By default this script does nothing.
		iptables -I INPUT -p udp --dport 5300 -j ACCEPT
		iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
		systemctl restart netfilter-persistent
		exit 0
	END
    chmod +x /etc/rc.local
}

### Tambahan
function tambahan(){
    wget -O /usr/sbin/speedtest "${REPO}bin/speedtest" >/dev/null 2>&1
    chmod +x /usr/sbin/speedtest
cat >/etc/msmtprc <<EOF
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account default
host smtp.gmail.com
port 587
auth on
user taibabihutan17@lompat.ga
from taibabihutan17@lompat.ga
password romanisti
logfile ~/.msmtp.log

EOF

chgrp mail /etc/msmtprc
chown 0600 /etc/msmtprc
touch /var/log/msmtp.log
chown syslog:adm /var/log/msmtp.log
chmod 660 /var/log/msmtp.log
ln -s /usr/bin/msmtp /usr/sbin/sendmail >/dev/null 2>&1
ln -s /usr/bin/msmtp /usr/bin/sendmail >/dev/null 2>&1
ln -s /usr/bin/msmtp /usr/lib/sendmail >/dev/null 2>&1
}


########## SETUP FROM HERE ##########
# ORIGINAL SCRIPT BY FIGHTER TUNNEL #
#####################################
echo "INSTALLING SCRIPT..."

touch /root/.install.log
cat >/root/tmp <<-END
#!/bin/bash
#vps
### taibabi $TANGGAL $MYIP
END
####
FIGHTERTUNNEL() {
    data=($(cat /root/tmp | grep -E "^### " | awk '{print $2}'))
    for user in "${data[@]}"; do
        exp=($(grep -E "^### $user" "/root/tmp" | awk '{print $3}'))
        d1=($(date -d "$exp" +%s))
        d2=($(date -d "$Date_list" +%s))
        exp2=$(((d1 - d2) / 86400))
        if [[ "$exp2" -le "0" ]]; then
            echo $user >/etc/.$user.ini
        else
            rm -f /etc/.$user.ini
        fi
    done
    rm -f /root/tmp
}

function install_all() {
    base_package
    dir_xray
    add_domain
    pasang_ssl >> /root/install.log
    install_xray >> /root/install.log
    install_ovpn >> /root/install.log
    install_slowdns >> /root/install.log
    pasang_rclone >> /root/install.log
    download_config >> /root/install.log
}

function finish(){
    TEXT="
<u>INFORMATION VPS INSTALL SC</u>
<code>TIME    : </code><code>${TIME}</code>
<code>IPVPS   : </code><code>${MYIP}</code>
<code>DOMAIN  : </code><code>${domain}</code>
<code>IP VPS  : </code><code>${MYIP}</code>
<code>LOKASI  : </code><code>${CITY}</code>
<code>USER    : </code><code>${NAMES}</code>
<code>RAM     : </code><code>${RAMMS}MB</code>
<code>LINUX   : </code><code>${OS}</code>
"
    curl -s --max-time $TIMES -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null
    cp /etc/openvpn/*.ovpn /var/www/html/
    sed -i "s/xxx/${domain}/g" /var/www/html/index.html
    sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf
    sed -i "s/xxx/${domain}/g" /etc/haproxy/haproxy.cfg
    sed -i "s/xxx/${MYIP}/g" /etc/squid/squid.conf
    chown -R www-data:www-data /etc/msmtprc
    systemctl daemon-reload
    systemctl enable client
    systemctl enable server
    systemctl enable netfilter-persistent
    systemctl enable ws
    systemctl enable expose
    systemctl start client
    systemctl start server
    systemctl start netfilter-persistent
    systemctl restart nginx
    systemctl restart xray
    systemctl restart rc-local
    systemctl restart client
    systemctl restart server
    systemctl restart dropbear
    systemctl restart ws
    systemctl restart openvpn
    systemctl restart cron
    systemctl restart haproxy
    systemctl restart netfilter-persistent
    systemctl restart ws
    systemctl restart squid
    clear
    echo "    ┌─────────────────────────────────────────────────────┐"
    echo "    │       >>> Service & Port                            │"
    echo "    │   - Open SSH                : 443, 80, 22           │"
    echo "    │   - DNS (SLOWDNS)           : 443, 80, 53           │"
    echo "    │   - Dropbear                : 443, 109, 80          │"
    echo "    │   - Dropbear Websocket      : 443, 109              │"
    echo "    │   - SSH Websocket SSL       : 443                   │"
    echo "    │   - SSH Websocket           : 80                    │"
    echo "    │   - OpenVPN SSL             : 443                   │"
    echo "    │   - OpenVPN Websocket SSL   : 443                   │"
    echo "    │   - OpenVPN TCP             : 443, 1194             │"
    echo "    │   - OpenVPN UDP             : 2200                  │"
    echo "    │   - Nginx Webserver         : 443, 80, 81           │"
    echo "    │   - Haproxy Loadbalancer    : 443, 80               │"
    echo "    │   - DNS Server              : 443, 53               │"
    echo "    │   - DNS Client              : 443, 88               │"
    echo "    │   - XRAY DNS (SLOWDNS)      : 443, 80, 53           │"
    echo "    │   - XRAY Vmess TLS          : 443                   │"
    echo "    │   - XRAY Vmess gRPC         : 443                   │"
    echo "    │   - XRAY Vmess None TLS     : 80                    │"
    echo "    │   - XRAY Vless TLS          : 443                   │"
    echo "    │   - XRAY Vless gRPC         : 443                   │"
    echo "    │   - XRAY Vless None TLS     : 80                    │"
    echo "    │   - Trojan gRPC             : 443                   │"
    echo "    │   - Trojan WS               : 443                   │"
    echo "    │   - Shadowsocks WS          : 443                   │"
    echo "    │   - Shadowsocks gRPC        : 443                   │"
    echo "    │                                                     │"
    echo "    │      >>> Server Information & Other Features        │"
    echo "    │   - Timezone                : Asia/Jakarta (GMT +7) │"
    echo "    │   - Autoreboot On           : $AUTOREB:00 $TIME_DATE GMT +7        │"
    echo "    │   - Auto Delete Expired Account                     │"
    echo "    │   - Fully automatic script                          │"
    echo "    │   - VPS settings                                    │"
    echo "    │   - Admin Control                                   │"
    echo "    │   - Restore Data                                    │"
    echo "    │   - Full Orders For Various Services                │"
    echo "    └─────────────────────────────────────────────────────┘"
    secs_to_human "$(($(date +%s) - ${start}))"
    echo -ne "         ${YELLOW}Please Reboot Your Vps${FONT} (y/n)? "
    read REDDIR
    if [ "$REDDIR" == "${REDDIR#[Yy]}" ]; then
        exit 0
    else
        reboot
    fi

}