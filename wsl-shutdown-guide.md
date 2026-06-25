This file explains the "why" and the exact sequence of a graceful shutdown discovery, warning users exactly why background jobs must be closed first.

When you type exit or logout, the Linux kernel inside WSL2 sends a graceful termination signal down the entire process tree. Docker receives this signal and systematically spins down its runtime engine, allowing its internal storage drivers and network bridges to unmount safely. Active TCP sockets like a kubectl port-forward keep the network state machine open, which prevents the WSL2 instance from entering its final power-down sequence in Windows Task Manager.

# 🛑 Graceful Subsystem Shutdown Guide

To prevent virtual hard disk (VHDX) corruption and avoid scrambling the internal Docker IPAM table leases, **never use `wsl --shutdown` while your cluster is active.** 

Follow this explicit, zero-corruption sequence to safely park your environment before running the cleanup optimization script:

### 1. Close Active Network Sockets
Ensure all background terminal jobs, proxies, or active port-forwards are fully closed:
```bash
# Terminate lingering port-forwards that block VM power-down loops
sudo killall kubectl 2>/dev/null || true
```

### 2. Broadcast Native Kernel Termination Signals
From your WSL2 Linux command line shell, explicitly type:
```bash
exit
# or
logout
```
* **Why this works:** This broadcasts a native `SIGTERM` signal down the OS process tree. Docker intercepts this signal and systematically spins down its runtime engines, ensuring container distributed states and storage drivers are safely unmounted. 

### 3. Verify the Hyper-V State
Monitor your Windows Task Manager. It can take **30 to 60 seconds** (depending on the size and complexity of your running Kubernetes deployments) for the Windows virtual machine process to completely exit memory. 

Once the VM process is absent from Task Manager, your storage blocks are safely parked, and you are ready to execute the `wsl-cleanup.ps1` storage script.

