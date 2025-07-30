#!/usr/bin/env python3

"""
Python-based ISO builder for Ubuntu Server Unattended ISO
This provides a fallback when native tools aren't available
"""

import os
import sys
import shutil
import tempfile
import subprocess
import argparse
import struct
from pathlib import Path

class ISOBuilder:
    """Simplified ISO builder using Python"""
    
    def __init__(self):
        self.verbose = False
    
    def extract_iso(self, iso_path, extract_dir):
        """Extract ISO contents using available methods"""
        iso_path = Path(iso_path)
        extract_dir = Path(extract_dir)
        
        if not iso_path.exists():
            print(f"Error: ISO file not found: {iso_path}")
            return False
        
        # Method 1: Try using subprocess with 7z (if available)
        if shutil.which('7z'):
            try:
                result = subprocess.run(
                    ['7z', 'x', '-y', f'-o{extract_dir}', str(iso_path)],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    if self.verbose:
                        print("Extracted using 7z")
                    return True
            except Exception as e:
                if self.verbose:
                    print(f"7z extraction failed: {e}")
        
        # Method 2: Try mounting (requires permissions)
        if os.path.exists('/bin/mount'):
            mount_point = tempfile.mkdtemp(prefix='iso_mount_')
            try:
                # Try to mount
                result = subprocess.run(
                    ['mount', '-o', 'loop,ro', str(iso_path), mount_point],
                    capture_output=True
                )
                if result.returncode == 0:
                    # Copy files
                    shutil.copytree(mount_point, extract_dir, dirs_exist_ok=True)
                    subprocess.run(['umount', mount_point], capture_output=True)
                    os.rmdir(mount_point)
                    if self.verbose:
                        print("Extracted using mount")
                    return True
            except Exception as e:
                if self.verbose:
                    print(f"Mount extraction failed: {e}")
            finally:
                if os.path.exists(mount_point):
                    subprocess.run(['umount', mount_point], capture_output=True)
                    os.rmdir(mount_point)
        
        # Method 3: Basic ISO9660 parsing (limited functionality)
        print("Warning: Using basic Python ISO extraction (limited functionality)")
        return self._extract_iso_basic(iso_path, extract_dir)
    
    def _extract_iso_basic(self, iso_path, extract_dir):
        """Basic ISO extraction - reads primary files only"""
        try:
            with open(iso_path, 'rb') as iso:
                # Skip to primary volume descriptor (sector 16)
                iso.seek(16 * 2048)
                
                # Read and verify it's a primary volume descriptor
                descriptor = iso.read(2048)
                if descriptor[0:6] != b'\x01CD001':
                    print("Error: Not a valid ISO9660 image")
                    return False
                
                # This is a very simplified extraction
                # In practice, you'd need to parse the directory structure
                print("Basic extraction not fully implemented")
                print("Consider installing 7z or using mount")
                return False
                
        except Exception as e:
            print(f"Error reading ISO: {e}")
            return False
    
    def create_iso(self, source_dir, output_iso, volume_label="Ubuntu Server"):
        """Create ISO from directory"""
        source_dir = Path(source_dir)
        output_iso = Path(output_iso)
        
        if not source_dir.exists():
            print(f"Error: Source directory not found: {source_dir}")
            return False
        
        # Method 1: Try using genisoimage/mkisofs
        for tool in ['genisoimage', 'mkisofs']:
            if shutil.which(tool):
                return self._create_iso_native(tool, source_dir, output_iso, volume_label)
        
        # Method 2: Try using xorriso
        if shutil.which('xorriso'):
            return self._create_iso_xorriso(source_dir, output_iso, volume_label)
        
        # Method 3: Python fallback (very basic)
        print("Warning: No native ISO creation tools found")
        print("Cannot create bootable ISO without genisoimage, mkisofs, or xorriso")
        return False
    
    def _create_iso_native(self, tool, source_dir, output_iso, volume_label):
        """Create ISO using genisoimage or mkisofs"""
        cmd = [
            tool,
            '-r',
            '-V', volume_label,
            '-cache-inodes',
            '-J', '-l',
            '-b', 'isolinux/isolinux.bin',
            '-c', 'isolinux/boot.cat',
            '-no-emul-boot',
            '-boot-load-size', '4',
            '-boot-info-table',
            '-o', str(output_iso),
            str(source_dir)
        ]
        
        # Add UEFI support if EFI image exists
        efi_img = source_dir / 'boot' / 'grub' / 'efi.img'
        if efi_img.exists():
            cmd.extend([
                '-eltorito-alt-boot',
                '-e', 'boot/grub/efi.img',
                '-no-emul-boot'
            ])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                if self.verbose:
                    print(f"Created ISO using {tool}")
                return True
            else:
                print(f"Error creating ISO: {result.stderr}")
                return False
        except Exception as e:
            print(f"Error running {tool}: {e}")
            return False
    
    def _create_iso_xorriso(self, source_dir, output_iso, volume_label):
        """Create ISO using xorriso"""
        cmd = [
            'xorriso',
            '-as', 'mkisofs',
            '-r',
            '-V', volume_label,
            '-J', '-joliet-long',
            '-b', 'isolinux/isolinux.bin',
            '-c', 'isolinux/boot.cat',
            '-no-emul-boot',
            '-boot-load-size', '4',
            '-boot-info-table'
        ]
        
        # Add UEFI support if EFI image exists
        efi_img = source_dir / 'boot' / 'grub' / 'efi.img'
        if efi_img.exists():
            cmd.extend([
                '-eltorito-alt-boot',
                '-e', 'boot/grub/efi.img',
                '-no-emul-boot'
            ])
        
        cmd.extend(['-o', str(output_iso), str(source_dir)])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                if self.verbose:
                    print("Created ISO using xorriso")
                return True
            else:
                print(f"Error creating ISO: {result.stderr}")
                return False
        except Exception as e:
            print(f"Error running xorriso: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Python ISO Builder for Ubuntu Server')
    parser.add_argument('action', choices=['extract', 'create'],
                       help='Action to perform')
    parser.add_argument('source', help='Source ISO (extract) or directory (create)')
    parser.add_argument('destination', help='Destination directory (extract) or ISO (create)')
    parser.add_argument('--label', default='Ubuntu Server',
                       help='Volume label for created ISO')
    parser.add_argument('-v', '--verbose', action='store_true',
                       help='Verbose output')
    
    args = parser.parse_args()
    
    builder = ISOBuilder()
    builder.verbose = args.verbose
    
    if args.action == 'extract':
        success = builder.extract_iso(args.source, args.destination)
    else:  # create
        success = builder.create_iso(args.source, args.destination, args.label)
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()