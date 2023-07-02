#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
     echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
     echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
     echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "ERROR: You must run this script as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
     release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
     release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
     release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
     release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
     release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
     release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
     release="centos"
else
     LOGE "System version not detected, please contact the script author!\n" && exit 1
the fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
     os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
the fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
     os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
the fi

if [[ x"${release}" == x"centos" ]]; then
     if [[ ${os_version} -le 6 ]]; then
         LOGE "Please use CentOS 7 or higher!\n" && exit 1
     the fi
elif [[ x"${release}" == x"ubuntu" ]]; then
     if [[ ${os_version} -lt 16 ]]; then
         LOGE "Please use Ubuntu 16 or higher!\n" && exit 1
     the fi
elif [[ x"${release}" == x"debian" ]]; then
     if [[ ${os_version} -lt 8 ]]; then
         LOGE "Please use Debian 8 or higher!\n" && exit 1
     the fi
the fi

confirm() {
     if [[ $# > 1 ]]; then
         echo && read -p "$1 [default $2]: " temp
         if [[ x"${temp}" == x"" ]]; then
             temp=$2
         the fi
     else
         read -p "$1 [y/n]: " temp
     the fi
     if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
         return 0
     else
         return 1
     the fi
}

confirm_restart() {
     confirm "Whether to restart the panel, restarting the panel will also restart xray" "y"
     if [[ $? == 0 ]]; then
         restart
     else
         show_menu
     the fi
}

before_show_menu() {
     echo && echo -n -e "${yellow} press Enter to return to the main menu: ${plain}" && read temp
     show_menu
}

install() {
     bash <(curl -Ls https://raw.githubusercontent.com/majidgaravand/x-ui/master/install.sh)
     if [[ $? == 0 ]]; then
         if [[ $# == 0 ]]; then
             start
         else
             start 0
         the fi
     the fi
}

update() {
     confirm "This function will force the latest version to be reinstalled, and the data will not be lost. Do you want to continue?" "n"
     if [[ $? != 0 ]]; then
         LOGE "Cancelled"
         if [[ $# == 0 ]]; then
             before_show_menu
         the fi
         return 0
     the fi
     bash <(curl -Ls https://raw.githubusercontent.com/majidgaravand/x-ui/master/install.sh)
     if [[ $? == 0 ]]; then
         LOGI "Update completed, panel restarted automatically"
         exit 0
     the fi
}

uninstall() {
     confirm "Are you sure you want to uninstall the panel, xray will also be uninstalled?" "n"
     if [[ $? != 0 ]]; then
         if [[ $# == 0 ]]; then
             show_menu
         the fi
         return 0
     the fi
     systemctl stop x-ui
     systemctl disable x-ui
     rm /etc/systemd/system/x-ui.service -f
     systemctl daemon-reload
     systemctl reset-failed
     rm /etc/x-ui/ -rf
     rm /usr/local/x-ui/ -rf

     echo ""
     echo -e "Uninstallation is successful, if you want to delete this script, run ${green}rm /usr/bin/x-ui -f${plain} after exiting the script to delete"
     echo ""

     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

reset_user() {
     confirm "Are you sure you want to reset username and password to admin" "n"
     if [[ $? != 0 ]]; then
         if [[ $# == 0 ]]; then
             show_menu
         the fi
         return 0
     the fi
     /usr/local/x-ui/x-ui setting -username admin -password admin
     echo -e "Username and password have been reset to ${green}admin${plain}, please restart the panel now"
     confirm_restart
}

reset_config() {
     confirm "Are you sure you want to reset all panel settings, account data will not be lost, user name and password will not change" "n"
     if [[ $? != 0 ]]; then
         if [[ $# == 0 ]]; then
             show_menu
         the fi
         return 0
     the fi
     /usr/local/x-ui/x-ui setting -reset
     echo -e "All panel settings have been reset to default, please restart the panel now and use the default ${green}54321${plain} port to access the panel"
     confirm_restart
}

check_config() {
     info=$(/usr/local/x-ui/x-ui setting -show true)
     if [[ $? != 0 ]]; then
         LOGE "get current settings error, please check logs"
         show_menu
     the fi
     LOGI "${info}"
}

set_port() {
     echo && echo -n -e "Enter port number [1-65535]: " && read port
     if [[ -z "${port}" ]]; then
         LOGD "Cancelled"
         before_show_menu
     else
         /usr/local/x-ui/x-ui setting -port ${port}
         echo -e "The port is set, please restart the panel now, and use the newly set port ${green}${port}${plain} to access the panel"
         confirm_restart
     the fi
}

start() {
     check_status
     if [[ $? == 0 ]]; then
         echo ""
         LOGI "The panel is already running, no need to start again, if you need to restart, please select restart"
     else
         systemctl start x-ui
         sleep 2
         check_status
         if [[ $? == 0 ]]; then
             LOGI "x-ui started successfully"
         else
             LOGE "Panel failed to start, it may be because the startup time exceeds two seconds, please check the log information later"
         the fi
     the fi

     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

stop() {
     check_status
     if [[ $? == 1 ]]; then
         echo ""
         LOGI "panel stopped, no need to stop again"
     else
         systemctl stop x-ui
         the sleep 2
         check_status
         if [[ $? == 1 ]]; then
             LOGI "x-ui and xray stopped successfully"
         else
             LOGE "The panel failed to stop, probably because the stop time exceeded two seconds, please check the log information later"
         the fi
     the fi

     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

restart() {
     systemctl restart x-ui
     sleep 2
     check_status
     if [[ $? == 0 ]]; then
         LOGI "x-ui and xray restarted successfully"
     else
         LOGE "Panel failed to restart, probably because the startup time exceeds two seconds, please check the log information later"
     the fi
     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

status() {
     systemctl status x-ui -l
     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

enable() {
     systemctl enable x-ui
     if [[ $? == 0 ]]; then
         LOGI "x-ui is set to start automatically at boot"
     else
         LOGE "x-ui setting boot self-start failed"
     the fi

     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

disable() {
     systemctl disable x-ui
     if [[ $? == 0 ]]; then
         LOGI "x-ui cancel boot autostart successfully"
     else
         LOGE "x-ui failed to cancel boot autostart"
     the fi

     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

show_log() {
     journalctl -u x-ui.service -e --no-pager -f
     if [[ $# == 0 ]]; then
         before_show_menu
     the fi
}

migrate_v2_ui() {
     /usr/local/x-ui/x-ui v2-ui

     before_show_menu
}

install_bbr() {
     # temporary workaround for installing bbr
     bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
     echo ""
     before_show_menu
}

update_shell() {
     wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/majidgaravand/x-ui/raw/master/x-ui.sh
     if [[ $? != 0 ]]; then
         echo ""
         LOGE "Failed to download the script, please check whether the machine can connect to Github"
         before_show_menu
     else
         chmod +x /usr/bin/x-ui
         LOGI "The upgrade script is successful, please run the script again" && exit 0
     the fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
     if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
         return 2
     the fi
     temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
     if [[ x"${temp}" == x"running" ]]; then
         return 0
     else
         return 1
     the fi
}

check_enabled() {
     temp=$(systemctl is-enabled x-ui)
     if [[ x"${temp}" == x"enabled" ]]; then
         return 0
     else
         return 1
     the fi
}

check_uninstall() {
     check_status
     if [[ $? != 2 ]]; then
         echo ""
         LOGE "panel already installed, please do not reinstall"
         if [[ $# == 0 ]]; then
             before_show_menu
         the fi
         return 1
     else
         return 0
     the fi
}

check_install() {
     check_status
     if [[ $? == 2 ]]; then
         echo ""
         LOGE "Please install the panel first"
         if [[ $# == 0 ]]; then
             before_show_menu
         the fi
         return 1
     else
         return 0
     the fi
}

show_status() {
     check_status
     case $? in
     0)
         echo -e "panel status: ${green} running ${plain}"
         show_enable_status
         ;;
     1)
         echo -e "Panel status: ${yellow} not running ${plain}"
         show_enable_status
         ;;
     2)
         echo -e "panel status: ${red} is not installed ${plain}"
         ;;
     esac
     show_xray_status
}

show_enable_status() {
     check_enabled
     if [[ $? == 0 ]]; then
         echo -e "Whether to boot automatically: ${green} is ${plain}"
     else
         echo -e "Whether to boot automatically: ${red}No ${plain}"
     the fi
}

check_xray_status() {
     count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
     if [[ count -ne 0 ]]; then
         return 0
     else
         return 1
     the fi
}

show_xray_status() {
     check_xray_status
     if [[ $? == 0 ]]; then
         echo -e "xray status: ${green} running ${plain}"
     else
         echo -e "xray status: ${red} not running ${plain}"
     the fi
}

ssl_cert_issue() {
     echo -E ""
     LOGD "******Instructions******"
     LOGI "This script will use the Acme script to apply for a certificate. When using it, you must ensure:"
     LOGI "1. Know the Cloudflare registered email address"
     LOGI "2. Know Cloudflare Global API Key"
     LOGI "3. The domain name has been resolved to the current server by Cloudflare"
     LOGI "4. The default installation path for this script to apply for a certificate is the /root/cert directory"
     confirm "I have confirmed the above [y/n]" "y"
     if [ $? -eq 0 ]; then
         cd ~
         LOGI "Install Acme Script"
         curl https://get.acme.sh | sh
         if [ $? -ne 0 ]; then
             LOGE "Failed to install acme script"
             exit 1
         the fi
         CF_Domain=""
         CF_GlobalKey=""
         CF_AccountEmail=""
         certPath=/root/cert
         if [ ! -d "$certPath" ]; then
             mkdir $certPath
         else
             rm -rf $certPath
             mkdir $certPath
         the fi
         LOGD "Please set domain name:"
         read -p "Input your domain here:" CF_Domain
         LOGD "Your domain name is set to: ${CF_Domain}"
         LOGD "Please set API key:"
         read -p "Input your key here:" CF_GlobalKey
         LOGD "Your API key is: ${CF_GlobalKey}"
         LOGD "Please set the registered email address:"
         read -p "Input your email here:" CF_AccountEmail
         LOGD "Your registered email address is: ${CF_AccountEmail}"
         ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
         if [ $? -ne 0 ]; then
             LOGE "Failed to change the default CA to Lets'Encrypt, the script exited"
             exit 1
         the fi
         export CF_Key="${CF_GlobalKey}"
         export CF_Email=${CF_AccountEmail}
         ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
         if [ $? -ne 0 ]; then
             LOGE "Failed to issue certificate, script exited"
             exit 1
         else
         LOGI "Certificate issued successfully, installing..."
         the fi
         ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
         --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key\
         --fullchain-file /root/cert/fullchain.cer
         if [ $? -ne 0 ]; then
             LOGE "Certificate installation failed, script exited"
             exit 1
         else
             LOGI "Certificate installed successfully, enable automatic update..."
         the fi
         ~/.acme.sh/acme.sh --upgrade --auto-upgrade
         if [ $? -ne 0 ]; then
             LOGE "Automatic update setup failed, script exited"
             ls -lah cert
             chmod 755 $certPath
             exit 1
         else
             LOGI "The certificate has been installed and automatic renewal has been enabled, the specific information is as follows"
             ls -lah cert
             chmod 755 $certPath
         the fi
     else
         show_menu
     the fi
}

show_usage() {
     echo "How to use x-ui management script: "
     echo "------------------------------------------"
     echo "x-ui - show admin menu (more features)"
     echo "x-ui start - start x-ui panel"
     echo "x-ui stop - stop x-ui panel"
     echo "x-ui restart - restart the x-ui panel"
     echo "x-ui status - view x-ui status"
     echo "x-ui enable - set x-ui to boot automatically"
     echo "x-ui disable - cancel x-ui boot automatically"
     echo "x-ui log - view x-ui log"
     echo "x-ui v2-ui - migrate the v2-ui account data of this machine to x-ui"
     echo "x-ui update - update x-ui panel"
     echo "x-ui install - install x-ui panel"
     echo "x-ui uninstall - uninstall x-ui panel"
     echo "------------------------------------------"
}

show_menu() {
     echo -e "
   ${green}x-ui panel management script ${plain}
   ${green}0.${plain} exit script
———————————————
   ${green}1.${plain} install x-ui
   ${green}2.${plain} update x-ui
   ${green}3.${plain} uninstall x-ui
———————————————
   ${green}4.${plain} Reset username and password
   ${green}5.${plain} Reset panel settings
   ${green}6.${plain} set the panel port
   ${green}7.${plain} View the current panel settings
———————————————
   ${green}8.${plain} start x-ui
   ${green}9.${plain} stop x-ui
   ${green}10.${plain} restart x-ui
   ${green}11.${plain} View x-ui status
   ${green}12.${plain} View x-ui logs
———————————————
   ${green}13.${plain} set x-ui to boot automatically
   ${green}14.${plain} cancel x-ui autostart
———————————————
   ${green}15.${plain} One-click installation of bbr (latest kernel)
   ${green}16.${plain} One-click application for SSL certificate (acme application)
  "
     show_status
     echo && read -p "Please enter selection [0-16]: " num

     case "${num}" in
     0)
         exit 0
         ;;
     1)
         check_uninstall && install
         ;;
     2)
         check_install && update
         ;;
     3)
         check_install && uninstall
         ;;
     4)
         check_install && reset_user
         ;;
     5)
         check_install && reset_config
         ;;
     6)
         check_install && set_port
         ;;
     7)
         check_install && check_config
         ;;
     8)
         check_install && start
         ;;
     9)
         check_install && stop
         ;;
     10)
         check_install && restart
         ;;
     11)
         check_install && status
         ;;
     12)
         check_install && show_log
         ;;
     13)
         check_install && enable
         ;;
     14)
         check_install && disable
         ;;
     15)
         install_bbr
         ;;
     16)
         ssl_cert_issue
         ;;
     *)
         LOGE "Please enter the correct number [0-16]"
         ;;
     esac
}

if [[ $# > 0 ]]; then
     case $1 in
     "start")
         check_install 0 && start 0
         ;;
     "stop")
         check_install 0 && stop 0
         ;;
     "restart")
         check_install 0 && restart 0
         ;;
     "status")
         check_install 0 && status 0
         ;;
     "enable")
         check_install 0 && enable 0
         ;;
     "disable")
         check_install 0 && disable 0
         ;;
     "log")
         check_install 0 && show_log 0
         ;;
     "v2-ui")
         check_install 0 && migrate_v2_ui 0
         ;;
     "update")
         check_install 0 && update 0
         ;;
     "install")
         check_uninstall 0 && install 0
         ;;
     "uninstall")
         check_install 0 && uninstall 0
         ;;
     *) show_usage;;
     esac
else
     show_menu
the fi
