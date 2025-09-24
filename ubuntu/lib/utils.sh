#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

$APP_NAME="nas-utility"



install_menu() {
    if [ $# -ge 1 ]; then

        case $1 in
            "nextcloud")
                install_nextcloud $2 $3 &
                ;;
            "filebrowser")
                install_filebrowser $2 $3 $4 &
                ;;
            "smb")
                install_smb $2 $3 $4 $5 &
                ;;
            "all")
                install_all &
                ;;
            *)
                echo "Unknown command: $1"
                exit 1
                ;;
        esac



    else


        CHOICE=$(whiptail --title "Select an Action" --menu "Choose an option:" 20 60 10 \
            "Install Nextcloud" "" \
            "Install FileBrowser" "" \
            "Install SMB" "" \
            "Install All" "" \
            3>&1 1>&2 2>&3)

        exitstatus=$?
        if [ $exitstatus -ne 0 ] || [ -z "$CHOICE" ]; then
            echo "No selection made. Exiting."
            break
        fi

        case "$CHOICE" in
            "Install Nextcloud") install_nextcloud ;;
            "Install FileBrowser") install_filebrowser ;;
            "Install SMB") install_smb ;;
            "Install All") install_all ;;
            *) whiptail --title "Error" --msgbox "Invalid option selected!" 10 50 ;;
        esac

    fi
}



uninstall_menu() {

    if [ $# -ge 1 ]; then

        case $1 in
            "nextcloud")
                uninstall_nextcloud &
                ;;
            "filebrowser")
                uninstall_filebrowser &
                ;;
            "smb")
                uninstall_smb &
                ;;
            "all")
                uninstall_all &
                ;;
            *)
                echo "Unknown command: $1"
                exit 1
                ;;
        esac



    else
        CHOICE=$(whiptail --title "Select an Action" --menu "Choose an option:" 20 60 10 \
            "Uninstall Nextcloud" "" \
            "Uninstall FileBrowser" "" \
            "Uninstall SMB" "" \
            "Uninstall All" "" \
            3>&1 1>&2 2>&3)

        exitstatus=$?
        if [ $exitstatus -ne 0 ] || [ -z "$CHOICE" ]; then
            echo "No selection made. Exiting."
            break
        fi

        case "$CHOICE" in
            "Uninstall Nextcloud") uninstall_nextcloud ;;
            "Uninstall FileBrowser") uninstall_filebrowser ;;
            "Uninstall SMB") uninstall_smb ;;
            "Uninstall All") uninstall_all ;;
            *) whiptail --title "Error" --msgbox "Invalid option selected!" 10 50 ;;
        esac
    fi
}


install_all() {
    install_nextcloud
    install_filebrowser
    install_smb
}

install_nextcloud() {
    source /usr/local/lib/$APP_NAME/install/nextcloud.sh
}

install_filebrowser() {
    source /usr/local/lib/$APP_NAME/install/filebrowser.sh
}

install_smb() {
    source /usr/local/lib/$APP_NAME/install/smb.sh
}

uninstall_all() {
    uninstall_nextcloud
    uninstall_filebrowser
    uninstall_smb
}

uninstall_nextcloud() {
    source /usr/local/lib/$APP_NAME/uninstall/nextcloud.sh
}

uninstall_filebrowser() {
    source /usr/local/lib/$APP_NAME/uninstall/filebrowser.sh
}

uninstall_smb() {
    source /usr/local/lib/$APP_NAME/uninstall/smb.sh
}


exit_program() {
    echo "Exiting program."
    exit 0
}

delete_app() {
    source /usr/local/lib/$APP_NAME/delete_app.sh
}


log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}