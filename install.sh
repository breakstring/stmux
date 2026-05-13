#!/bin/bash

# install.sh
# 职责与边界：安装本仓库提供的本地 tmux 配置、状态栏脚本和 `stmux` 启动命令；不负责安装 tmux/ssh/rsync 等系统依赖。
# 关键副作用：写入 `~/.tmux.conf`、`~/.tmux/status.sh` 和 `/usr/local/bin/stmux`，会覆盖这些目标路径上的同名文件。
# 关键依赖与约束：依赖当前目录存在 `.tmux.conf`、`.tmux/status.sh`、`stmux`；写入 `/usr/local/bin` 需要 `sudo` 权限。

set -euo pipefail

echo "Installing .tmux.conf to ~/.tmux.conf..."
cp .tmux.conf ~/.tmux.conf

echo "Installing status script to ~/.tmux/status.sh..."
mkdir -p ~/.tmux
cp .tmux/status.sh ~/.tmux/status.sh
chmod +x ~/.tmux/status.sh

echo "Installing stmux to /usr/local/bin/stmux..."
sudo cp stmux /usr/local/bin/stmux
sudo chmod +x /usr/local/bin/stmux

echo "---------------------------------------"
echo "Installation complete!"
echo "Installed:"
echo "  - ~/.tmux.conf"
echo "  - ~/.tmux/status.sh"
echo "  - /usr/local/bin/stmux"
