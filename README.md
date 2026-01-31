
# Remote Tmux Workflow (RTW)

[English] | [中文版](README_CN.md)

A powerful remote development toolkit optimized for Mac users. This repository provides a seamless experience for managing remote tmux sessions with a customized configuration and an automated synchronization script.

## 🚀 Features

### 1. Enhanced `.tmux.conf`
* **Dual Prefix Support**: Supports both `Ctrl + b` and `Ctrl + a` to fit different muscle memories.
* **Mac-Friendly Splits**: Use `\` for vertical splits (side-by-side) and `-` for horizontal splits (up/down). No more `Shift` key gymnastics.
* **Touchpad Optimized**: Full mouse/trackpad support enabled. Scroll through history smoothly with two-finger gestures.
* **Visual Focus**: Features a classic green status bar and a **Bright Red border** for the active pane, making it impossible to lose your cursor.
* **Persistent Highlight**: Text remains highlighted after selection, allowing for easy copying without the selection immediately disappearing.

### 2. `stmux` Automation Script
* **Config Syncing**: One-click synchronization of your local `.tmux.conf` to any remote server.
* **Smart Session Management**: Automatically attaches to an existing session or creates a new one—preventing redundant session clutter.
* **Stay Connected**: After detaching (`Ctrl+a, d`), the script offers an option to stay in the remote shell instead of closing the connection.
* **Colorized Output**: Clear, color-coded terminal feedback for all key operations.

---

## 📦 Installation

### Automatic Installation (Recommended)
Clone this repository and run the installer:
```bash
chmod +x install.sh
./install.sh

```

### Manual Installation

1. Copy `.tmux.conf` to your home directory:
```bash
cp .tmux.conf ~/.tmux.conf

```


2. Move the `stmux` script to your local bin and set permissions:
```bash
sudo cp stmux /usr/local/bin/stmux
sudo chmod +x /usr/local/bin/stmux

```



---

## 🛠 Usage

The `stmux` command follows this syntax:
`stmux <ssh-alias> [session_name] [sync]`

* **Quick Connect**: `stmux my-server`
*(Connects to the 'main' session on 'my-server')*
* **Specific Task**: `stmux my-server dev-logs`
*(Connects to or creates a session named 'dev-logs')*
* **Sync & Login**: `stmux my-server main sync`
*(Syncs your local config to the server before entering the session)*

---

## ⚠️ Prerequisites

* **SSH Config**: This script relies on hosts defined in your `~/.ssh/config`.
* **SSH Keys**: Key-based authentication is highly recommended for a seamless "sync & login" experience without multiple password prompts.


