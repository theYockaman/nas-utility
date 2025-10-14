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
    exit_app
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
            "Install Backup CRON" "" \
            "Install Python" "" \
            "Install Cron Manager" "" \
            "Install Cron Manager Refresh" "" \
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
            "Install Backup CRON") install_backup_cron ;;
            "Install Python") install_python ;;
            "Install Cron Manager") install_cron_manager ;;
            "Install Cron Manager Refresh") install_cron_manager_refresh ;;
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
            "python")
                install_python "$@" &
                ;;
            "cron-manager")
                install_cron_manager "$@" &
                ;;
            "cron-manager-refresh")
                install_cron_manager_refresh "$@" &
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

upload_all(){
    sudo bash /usr/local/lib/$APP_NAME/upload.sh --target "/" --all --allow-root --date "$(date +%F)" --services-file /etc/backup_restore_services.list --confirm
}

install_all() {
    install_nextcloud
    install_filebrowser
    install_smb
    install_backup_cron
}

install_backup_cron() {
    sudo bash /usr/local/lib/$APP_NAME/install/backup.sh "$@"
}

install_nextcloud() {
    # If interactive whiptail helper exists and WHIPTAIL was requested, prefer it
    if [[ ${WHIPTAIL:-false} == true ]] && [ -f /usr/local/lib/$APP_NAME/install/nextcloud_whiptail.sh ]; then
        sudo bash /usr/local/lib/$APP_NAME/install/nextcloud_whiptail.sh
    else
        sudo bash /usr/local/lib/$APP_NAME/install/nextcloud.sh "$@"
    fi
}

install_filebrowser() {
    if [[ ${WHIPTAIL:-false} == true ]] && [ -f /usr/local/lib/$APP_NAME/install/filebrowser_whiptail.sh ]; then
        sudo bash /usr/local/lib/$APP_NAME/install/filebrowser_whiptail.sh
    else
        sudo bash /usr/local/lib/$APP_NAME/install/filebrowser.sh "$@"
    fi
}

install_smb() {
    if [[ ${WHIPTAIL:-false} == true ]] && [ -f /usr/local/lib/$APP_NAME/install/smb_whiptail.sh ]; then
        sudo bash /usr/local/lib/$APP_NAME/install/smb_whiptail.sh
    else
        sudo bash /usr/local/lib/$APP_NAME/install/smb.sh "$@"
    fi
}

install_python() {
    if [[ ${WHIPTAIL:-false} == true ]] && [ -f /usr/local/lib/$APP_NAME/install/python_whiptail.sh ]; then
        sudo bash /usr/local/lib/$APP_NAME/install/python_whiptail.sh
    else
        sudo bash /usr/local/lib/$APP_NAME/install/python.sh "$@"
    fi
}

install_cron_manager() {
    if [[ ${WHIPTAIL:-false} == true ]] && [ -f /usr/local/lib/$APP_NAME/install/cron-manager_whiptail.sh ]; then
        sudo bash /usr/local/lib/$APP_NAME/install/cron-manager_whiptail.sh
    else
        sudo bash /usr/local/lib/$APP_NAME/install/cron-manager.sh "$@"
    fi
}

install_cron_manager_refresh() {
    if [[ ${WHIPTAIL:-false} == true ]] && [ -f /usr/local/lib/$APP_NAME/install/cron-manager-refresh_whiptail.sh ]; then
        sudo bash /usr/local/lib/$APP_NAME/install/cron-manager-refresh_whiptail.sh
    else
        sudo bash /usr/local/lib/$APP_NAME/install/cron-manager-refresh.sh "$@"
    fi
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
            "Uninstall Python" "" \
            "Uninstall Cron Manager" "" \
            "Uninstall Cron Manager Refresh" "" \
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
            "Uninstall Python") uninstall_python ;;
            "Uninstall Cron Manager") uninstall_cron_manager ;;
            "Uninstall Cron Manager Refresh") uninstall_cron_manager_refresh ;;
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
            "python")
                uninstall_python &
                ;;
            "cron-manager")
                uninstall_cron_manager &
                ;;
            "cron-manager-refresh")
                uninstall_cron_manager_refresh &
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
    sudo bash /usr/local/lib/$APP_NAME/uninstall/nextcloud.sh "$@"
}

uninstall_filebrowser() {
    sudo bash /usr/local/lib/$APP_NAME/uninstall/filebrowser.sh "$@"
}

uninstall_smb() {
    sudo bash /usr/local/lib/$APP_NAME/uninstall/smb.sh "$@"
}

uninstall_python() {
    sudo bash /usr/local/lib/$APP_NAME/uninstall/python.sh "$@"
}

uninstall_cron_manager() {
    sudo bash /usr/local/lib/$APP_NAME/uninstall/cron-manager.sh "$@"
}

uninstall_cron_manager_refresh() {
    sudo bash /usr/local/lib/$APP_NAME/uninstall/cron-manager-refresh.sh "$@"
}
