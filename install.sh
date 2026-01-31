#!/bin/bash

# --- Simple Installer for Remote Tmux Workflow (RTW) ---

# 1. 安装 tmux 配置文件
echo "Installing .tmux.conf to ~/.tmux.conf..."
cp .tmux.conf ~/.tmux.conf

# 2. 安装 stmux 脚本到系统路径
echo "Installing stmux to /usr/local/bin/..."
# 使用 sudo 确保有权限写入系统 bin 目录
sudo cp stmux /usr/local/bin/stmux
sudo chmod +x /usr/local/bin/stmux

echo "---------------------------------------"
echo "Installation complete!"
echo "You can now use 'stmux' command to manage your sessions."
