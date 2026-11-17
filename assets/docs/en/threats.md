# Threat reference

This reference describes examples of concealment techniques. Actual scan findings are shown in **Findings**. Compatibility depends on the implementation, kernel version and configuration. A project name in this document says nothing about the computer's infection status.

## Diamorphine

A loadable kernel module demonstrating hidden processes and modules through system call interception. Source: `m0nad/Diamorphine`.

## Reptile

A kernel rootkit demonstrating concealment of files, processes and network activity. Source: `m0nad/Reptile`.

## BDS LKM ftrace

An educational example of interception using ftrace. Unexpected hooks and unfamiliar modules warrant investigation. Source: `bluedragonsecurity/bds_lkm_ftrace`.

## Singularity

A research kernel rootkit. Its supported kernel versions depend on the specific revision. Source: `CaptainBoggle/Singularity`.

## eBPF and io_uring techniques

Malicious programs can misuse kernel facilities to hide activity. Investigating them may require behavioral monitoring, module inspection, and an audit of loaded BPF programs. Signature scans alone have limited coverage.
