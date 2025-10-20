# Quick Reference - System Health Monitoring

## 🚀 Quick Start

```bash
cd /home/sem/prog/flutter/hypr_flutter
flutter run -d linux
# Navigate to Health tab (left sidebar, 3rd icon)
```

## 📊 What Gets Checked

| Component | What's Monitored | Update Frequency |
|-----------|------------------|------------------|
| 📦 Packages | Updates available, security patches | Every 30 min |
| 🐧 Kernel | Current vs latest version | Every 30 min |
| 🔋 Battery | Health %, cycles, capacity | Every 30 min |
| 💾 Disks | Usage %, SMART status | Every 30 min |
| ⚙️ Services | Failed systemd services | Every 30 min |
| 🌡️ System | CPU temp, memory usage | Every 30 min |

## 🎨 Status Colors

- 🟢 **Green** = Excellent (all good!)
- 🔵 **Blue** = Good (minor issues)
- 🟠 **Orange** = Warning (needs attention)
- 🔴 **Red** = Critical (urgent!)

## 💻 Package Manager Commands

```bash
# Debian/Ubuntu
sudo apt update && sudo apt upgrade

# Arch/Manjaro
sudo pacman -Syu

# Fedora/RHEL
sudo dnf upgrade

# openSUSE
sudo zypper update

# NixOS
nix-channel --update && nix-env -u
```

## 🔧 Quick Fixes

### Enable SMART monitoring
```bash
sudo apt install smartmontools  # or pacman -S, dnf install, etc.
```

### Allow package checks without password
```bash
sudo visudo
# Add: yourusername ALL=(ALL) NOPASSWD: /usr/bin/apt update
```

### Check failed services manually
```bash
systemctl --failed
systemctl status service-name
```

## 📱 Integrate with Notifications

```dart
// Send notification for critical issues
if (health.packages.securityUpdates > 0) {
  NotificationService().addNotification(AppNotification(
    title: 'Security Updates Available',
    body: '${health.packages.securityUpdates} critical updates',
    category: NotificationCategory.security,
    priority: NotificationPriority.critical,
    timestamp: DateTime.now(),
  ));
}
```

## 🎯 Health Thresholds

### Battery
- 🟢 ≥90% | 🔵 75-89% | 🟠 60-74% | 🔴 <60%

### Disk Usage
- 🟢 <70% | 🔵 70-84% | 🟠 85-94% | 🔴 ≥95%

### Package Updates
- 🟢 0 security, <20 total
- 🔵 0 security, 20-50 total  
- 🟠 1-10 security or >50 total
- 🔴 >10 security updates

### Services
- 🟢 0 failed | 🔵 1-2 failed | 🟠 3-5 failed | 🔴 >5 failed

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| No battery shown | Normal for desktops (laptops only) |
| 0 updates but know there are | Run package manager update manually first |
| SMART data unavailable | Install smartmontools package |
| Kernel shows outdated | LTS distros intentionally use older kernels |
| Failed services listed | Review with `systemctl status`, some are expected |

## 📚 Documentation

- **Full docs**: `docs/SYSTEM_HEALTH.md`
- **Implementation**: `SYSTEM_HEALTH_IMPLEMENTATION.md`
- **Config system**: `docs/CONFIG_SYSTEM.md`

## ⚡ Performance

- Initial check: **2-5 seconds**
- Memory: **<10 MB**
- Auto-check: **Every 30 minutes**
- Manual refresh: **Anytime**

## 🎉 Features

✅ Auto-detects package manager (apt/pacman/dnf/zypper/nix)  
✅ Tracks battery health & cycles  
✅ Monitors disk space & SMART status  
✅ Detects failed systemd services  
✅ Checks kernel version  
✅ Shows security updates  
✅ Beautiful color-coded UI  
✅ Pull-to-refresh  
✅ Integration with notifications  

---

**Need help?** Check the full documentation in `docs/SYSTEM_HEALTH.md`
