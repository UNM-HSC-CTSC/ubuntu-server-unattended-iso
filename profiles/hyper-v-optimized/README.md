# Hyper-V Optimized Profile

Ubuntu Server optimized for Microsoft Hyper-V virtualization platform.

## Optimizations

- **Kernel**: linux-virtual for Hyper-V
- **Integration Services**: Full Hyper-V daemons
- **Network**: Synthetic adapter support
- **Memory**: Optimized swappiness
- **Storage**: LVM for dynamic disks

## Hyper-V Features Enabled

- Key-Value Pair Exchange
- VSS Snapshot support
- File Copy service
- Heartbeat
- Time Synchronization
- Shutdown integration

## Performance Tuning

- Reduced swappiness (10)
- Optimized dirty page ratios
- Increased network buffers
- tuned profile: virtual-guest

## Post-Installation

1. Enable Dynamic Memory in Hyper-V settings
2. Install Hyper-V GPU if using RemoteFX
3. Configure backup with VSS integration
4. Set up monitoring with Windows Admin Center
