#!/bin/bash

working_ips=""  # Initialize the variable for reachable IPs
port=2049  # Set the default port to check

# Function to check port status on an IP
function_port_check() {
    local ip="$1"
    local port="$2"  # Fixed: Use $2 for the port argument

    if nc -zvw5 "$ip" "$port" &> /dev/null; then
        working_ips+="$ip "
    fi
}

# Function to display the menu
display_menu() {
    echo "Choose an option:"
    echo "1. Perform port check"
    echo "2. Mount NFS share from reachable IPs (requires sudo)"
    echo "3. Exit"
    echo "4. Unmount NFS share by IP (requires sudo)"
}

# Main script logic
while true; do
    display_menu
    read -p "Enter your choice: " choice

    case "$choice" in
        1)  # Perform port check
            read -p "Enter IP addresses (space-separated): " ips

            # Check each IP entered by the user
            for ip in $ips; do
                if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    function_port_check "$ip" "$port"  # Pass port as argument
                else
                    echo "Invalid IP: $ip"
                fi
            done

            working_ips=${working_ips%?}  # Remove trailing space

            if [[ -n "$working_ips" ]]; then
                echo "Reachable IPs on port $port: $working_ips"
            else
                echo "No reachable IPs found on port $port."
            fi
            ;;

        2)  # Mount NFS share from reachable IPs
            if [[ -z "$working_ips" ]]; then
                echo "No reachable IPs found. Please perform a port check first."
                continue  # Skip to the next iteration of the loop
            fi

            read -p "Enter remote export path: " remote_export
            read -p "Enter local mount point: " local_mount

            # Create local mount point if it doesn't exist
            sudo mkdir -p "$local_mount"

            for ip in $working_ips; do  # Iterate over reachable IPs
                # Mount the NFS share from each IP
                sudo mount -t nfs "$ip:$remote_export" "$local_mount"

                if [[ $? -eq 0 ]]; then
                    echo "NFS share from $ip mounted successfully!"
                else
                    echo "Failed to mount NFS share from $ip. Check export path and permissions."
                fi
            done
            ;;

        3)  # Exit
            echo "Exiting..."
            exit 0
            ;;

        4)  # Unmount NFS share by IP
            read -p "Enter IP address to unmount: " unmount_ip

            # Find the mount point for the specified IP
            mount_point=$(sudo findmnt -T nfs -o TARGET -s --source "$unmount_ip")
            if [[ -z "$mount_point" ]]; then
                echo "No NFS share found mounted from $unmount_ip"
            else
                # Unmount the NFS share
                sudo umount "$mount_point"
                if [[ $? -eq 0 ]]; then
                    echo "NFS share from $unmount_ip unmounted successfully!"
                else
                    echo "Failed to unmount NFS share from $unmount_ip"
                fi
            fi
            ;;

        *)  # Invalid choice
            echo "Invalid choice. Please try again."
            ;;
    esac
done
