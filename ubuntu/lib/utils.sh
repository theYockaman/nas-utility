#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'


# --- Global argument parser ---
parse_global_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --whiptail)
                WHIPTAIL=true
                shift
                ARGS=("$@")
                break
                ;;
            --*)
                echo "Unknown global option: $1" >&2
                exit 1
                ;;
            *)
                ARGS=("$@")
                break
                ;;
        esac
    done
}


# General utility functions
exit_app() {
    echo "Exiting program."
    exit 0
}

delete_app() {
    sudo rm -rf /usr/local/lib/$APP_NAME
    sudo rm -f /usr/local/bin/$APP_NAME
    echo "$APP_NAME has been deleted."
}

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

show_help(){
    echo "Usage: $0 [global options] <command> [command options]"
    echo
    echo "Global Options:"
    echo "  --whiptail          Use whiptail for interactive prompts"
    echo
    echo "Commands:"
    echo "  -i, install         Install a service (nextcloud, filebrowser, smb, all)"
    echo "  -u, uninstall       Uninstall a service (nextcloud, filebrowser, smb, all)"
    echo "  -d, delete          Delete the nas-utility application"
    echo "  -h, help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --whiptail install nextcloud"
    echo "  $0 install filebrowser /mnt/server/ /mnt/server/backups/"
    echo "  $0 uninstall smb"
    echo "  $0 delete"
}

reset_ubuntu() {
    source /usr/local/lib/$APP_NAME/reset.sh
}



# Installation of services
install_menu() {
    if [[ $WHIPTAIL == true ]]; then

        # Check if Whiptail is installed
        if ! command -v whiptail &> /dev/null; then
            sudo apt update
            sudo apt install whiptail -y
        fi

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
    else

        # If no arguments provided, show help
        if [ $# -eq 0 ]; then
            show_help
            exit 0
        fi


        cmd=$1
        shift

        case $cmd in
            "nextcloud")
                install_nextcloud "$@" &
                ;;
            "filebrowser")
                install_filebrowser "$@" &
                ;;
            "smb")
                install_smb "$@" &
                ;;
            "all")
                install_all &
                ;;
            *)
                echo "Unknown command: $cmd"
                exit 1
                ;;
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



# Uninstallation of services
uninstall_menu() {
    if [[ $WHIPTAIL == true ]]; then

        # Check if Whiptail is installed
        if ! command -v whiptail &> /dev/null; then
            sudo apt update
            sudo apt install whiptail -y
        fi

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
        
    else

        # If no arguments provided, show help
        if [ $# -eq 0 ]; then
            show_help
            exit 0
        fi


        cmd=$1
        shift

        case $cmd in
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
        
    fi
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
