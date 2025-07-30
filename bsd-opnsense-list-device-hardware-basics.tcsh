#!/bin/tcsh

echo "=== System Info ==="
uname -a
echo

echo "=== CPU ==="
set cpu_model = `sysctl -n hw.model`
set cpu_cores = `sysctl -n hw.ncpu`
echo "$cpu_model"
echo "Cores: $cpu_cores"
echo

echo "=== Memory ==="
set mem = `sysctl -n hw.physmem`
@ mem_gb = $mem / 1073741824
echo "Physical Memory: $mem_gb GB"

# Add RAM module info if available
if (`id -u` == 0 && -x /usr/local/sbin/dmidecode) then
    set dimms = `dmidecode -t memory | grep -i 'Size:' | grep -v 'No Module Installed'`
    set total_modules = `echo "$dimms" | wc -l`
    set speed = `dmidecode -t memory | grep -m1 'Speed:' | awk '{print $2, $3}'`

    echo "Memory Modules: $total_modules"
    echo "Module Speed: $speed"
else
    echo "Run as root with dmidecode installed to see module count and speed"
endif
echo

echo "=== Storage Devices ==="
if (`id -u` != 0) then
    echo "Permission denied (run as root to see storage devices)"
    echo
else
    printf "%-10s | %-20s | %-10s | %-10s | %-10s | %-s\n" "Device" "Description" "Size" "Used" "Free" "ZFS Pool"
    printf "%-10s-+-%-20s-+-%-10s-+-%-10s-+-%-10s-+-%-s\n" "----------" "--------------------" "----------" "----------" "----------" "----------"

    # Get list of physical disks
    foreach disk (`geom disk list | grep "Geom name:" | awk '{print $3}'`)
        # Basic info
        set descr = `geom disk list $disk | grep "descr:" | sed 's/.*descr: //'`
        set size_bytes = `geom disk list $disk | grep "Mediasize:" | head -n1 | awk '{print $2}'`
        @ size_gb = $size_bytes / 1073741824

        # Default values
        set pool = "-"
        set zfs_used = "-"
        set zfs_free = "-"

        # Check if part of a ZFS pool
        foreach zp (`zpool list -H -o name`)
            set member = `zpool status $zp | grep $disk`
            if ("$member" != "") then
                set pool = $zp
                set zfs_stats = `zfs list -H -o used,avail $zp`
                set zfs_used = "$zfs_stats[1]"
                set zfs_free = "$zfs_stats[2]"
                break
            endif
        end

        # If not in ZFS, try to find `df` usage for mounted slice
        if ("$pool" == "-") then
            set mount = `mount | grep $disk | awk '{print $3}' | head -n1`
            if ("$mount" != "") then
                set df_stats = `df -h $mount | tail -1`
                set zfs_used = `echo $df_stats | awk '{print $3}'`
                set zfs_free = `echo $df_stats | awk '{print $4}'`
            endif
        endif

        # Output row
        printf "%-10s | %-20s | %-10s | %-10s | %-10s | %-s\n" "$disk" "$descr" "${size_gb} GB" "$zfs_used" "$zfs_free" "$pool"
    end
    echo
endif

echo

echo "=== Network Interfaces ==="
printf "%-12s | %-25s | %-17s | %-15s | %-s\n" "Interface" "Description" "MAC Address" "IPv4 Address" "Members"
printf "%-12s-+-%-25s-+-%-17s-+-%-15s-+-%-s\n" "------------" "-------------------------" "-----------------" "---------------" "----------------"

foreach iface (`ifconfig -l`)
    set desc = "-"
    set mac = "-"
    set ip = "-"
    set members = "-"

    # Grab interface config
    set info = `ifconfig $iface`

    # Get description
    set line = `ifconfig $iface | grep "description:"`
    if ("$status" == 0) then
        set desc = `echo $line | sed 's/^[^:]*: //'`
    endif

    # Get MAC
    set line = `ifconfig $iface | grep "ether "`
    if ("$status" == 0) then
        set mac = `echo $line | awk '{print $2}'`
    endif

    # Get IP
    set line = `ifconfig $iface | grep "inet " | grep -v inet6`
    if ("$status" == 0) then
        set ip = `echo $line | awk '{print $2}'`
    endif

    # Get members if bridge or lagg
    set line = `ifconfig $iface | grep "member:"`
    if ("$status" == 0) then
        set members = `ifconfig $iface | grep "member:" | awk '{print $2}' | tr '\n' ',' | sed 's/,$//'`
    endif

    # Print row
    printf "%-12s | %-25s | %-17s | %-15s | %-s\n" "$iface" "$desc" "$mac" "$ip" "$members"
end
