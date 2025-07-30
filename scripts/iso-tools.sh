#!/bin/bash

# ISO Tools Abstraction Layer
# Provides a unified interface for ISO manipulation using native Linux tools

# Global variables
ISO_BACKEND=""
MOUNT_POINT=""
TEMP_DIR=""

# Detect available ISO backend
detect_iso_backend() {
    # Check for mount/umount (preferred native method)
    if command -v mount >/dev/null 2>&1 && command -v umount >/dev/null 2>&1; then
        # Check if we can use loop devices
        if [ -e /dev/loop0 ] || losetup -f >/dev/null 2>&1; then
            ISO_BACKEND="mount"
            return 0
        fi
    fi
    
    # Check for Python as fallback
    if command -v python3 >/dev/null 2>&1; then
        # Check Python version
        local python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))" 2>/dev/null || echo "0.0")
        local major=$(echo "$python_version" | cut -d. -f1)
        local minor=$(echo "$python_version" | cut -d. -f2)
        if [ "$major" -gt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -ge 6 ]); then
            ISO_BACKEND="python"
            return 0
        fi
    fi
    
    # No suitable backend found
    ISO_BACKEND=""
    return 1
}

# Extract ISO using mount
extract_iso_mount() {
    local iso_path="$1"
    local extract_dir="$2"
    
    # Create temporary mount point
    MOUNT_POINT=$(mktemp -d /tmp/iso_mount.XXXXXX)
    
    # Mount the ISO
    if sudo mount -o loop,ro "$iso_path" "$MOUNT_POINT" 2>/dev/null; then
        # Copy contents
        cp -a "$MOUNT_POINT"/* "$extract_dir"/ 2>/dev/null
        cp -a "$MOUNT_POINT"/.??* "$extract_dir"/ 2>/dev/null || true
        
        # Unmount
        sudo umount "$MOUNT_POINT"
        rmdir "$MOUNT_POINT"
        return 0
    else
        # Try without sudo if possible
        if mount -o loop,ro "$iso_path" "$MOUNT_POINT" 2>/dev/null; then
            cp -a "$MOUNT_POINT"/* "$extract_dir"/ 2>/dev/null
            cp -a "$MOUNT_POINT"/.??* "$extract_dir"/ 2>/dev/null || true
            umount "$MOUNT_POINT"
            rmdir "$MOUNT_POINT"
            return 0
        fi
    fi
    
    rmdir "$MOUNT_POINT" 2>/dev/null
    return 1
}

# Extract ISO using Python
extract_iso_python() {
    local iso_path="$1"
    local extract_dir="$2"
    
    # Use the Python ISO builder script
    if [ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/pyiso.py" ]; then
        python3 "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/pyiso.py" extract "$iso_path" "$extract_dir"
    else
        return 1
    fi
}

# Generic extract function
extract_iso() {
    local iso_path="$1"
    local extract_dir="$2"
    
    if [ -z "$ISO_BACKEND" ]; then
        detect_iso_backend
    fi
    
    case "$ISO_BACKEND" in
        mount)
            extract_iso_mount "$iso_path" "$extract_dir"
            ;;
        python)
            extract_iso_python "$iso_path" "$extract_dir"
            ;;
        *)
            echo "Error: No suitable ISO extraction method found" >&2
            return 1
            ;;
    esac
}

# Create ISO using native tools
create_iso_native() {
    local source_dir="$1"
    local output_iso="$2"
    local volume_label="${3:-Ubuntu Server Unattended}"
    
    # Check for genisoimage or mkisofs
    local iso_creator=""
    if command -v genisoimage >/dev/null 2>&1; then
        iso_creator="genisoimage"
    elif command -v mkisofs >/dev/null 2>&1; then
        iso_creator="mkisofs"
    else
        # Fallback to Python
        create_iso_python "$source_dir" "$output_iso" "$volume_label"
        return $?
    fi
    
    # Create ISO with UEFI and BIOS boot support
    $iso_creator \
        -r \
        -V "$volume_label" \
        -cache-inodes \
        -J -l \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -o "$output_iso" \
        "$source_dir" 2>/dev/null
}

# Create ISO using Python
create_iso_python() {
    local source_dir="$1"
    local output_iso="$2"
    local volume_label="${3:-Ubuntu Server Unattended}"
    
    # Use the Python ISO builder script
    if [ -f "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/pyiso.py" ]; then
        python3 "${SCRIPT_DIR:-$(dirname "${BASH_SOURCE[0]}")}/pyiso.py" create "$source_dir" "$output_iso" --label "$volume_label"
    else
        return 1
    fi
}

# Generic create ISO function
create_iso() {
    local source_dir="$1"
    local output_iso="$2"
    local volume_label="${3:-Ubuntu Server Unattended}"
    
    create_iso_native "$source_dir" "$output_iso" "$volume_label"
}

# Cleanup function
cleanup_iso_tools() {
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        umount "$MOUNT_POINT" 2>/dev/null || sudo umount "$MOUNT_POINT" 2>/dev/null
        rmdir "$MOUNT_POINT" 2>/dev/null
    fi
    
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap for cleanup
trap cleanup_iso_tools EXIT INT TERM

# Export functions for use by other scripts
export -f detect_iso_backend
export -f extract_iso
export -f create_iso
export -f cleanup_iso_tools