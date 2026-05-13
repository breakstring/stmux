# stmux

[English](README.md) | [中文版]

`stmux` 是一个本地启动脚本，适合通过 `tmux` 在远程服务器上长期跑多任务的人使用。
它把 `ssh`、`tmux attach/new-session` 和 tmux 配置同步串起来，目标是让你更快进入远端会话，并把状态栏里的 CPU、内存、IP 信息一起带过去。

这份文档按当前仓库里的真实实现整理，已经覆盖现在的 `status.sh` 状态脚本和 `sync` 的实际行为。

## 仓库里现在有什么

- `stmux`：本地命令入口。连接远端 SSH 主机后，自动接入 tmux 会话；如果会话不存在就新建。
- `.tmux.conf`：共享 tmux 配置，包含双前缀、鼠标支持、OSC 52 剪贴板和更顺手的分屏快捷键。
- `.tmux/status.sh`：状态栏脚本，用于在远端 tmux 状态栏里显示 CPU、内存和轮播 IP。
- `install.sh`：基础安装脚本，负责安装 `stmux` 和 `~/.tmux.conf`。

## 当前工作流

`stmux` 现在做两件事：

1. 可选地把你本地的 `~/.tmux/` 和 `~/.tmux.conf` 同步到远端服务器。
2. 进入远端 SSH 会话后执行：
   - `tmux attach -t <session>`
   - 如果会话不存在，则执行 `tmux new-session -s <session>`

当你从 tmux 里 detach 之后，脚本还会再问一次，要不要继续留在远端 shell，而不是立刻断开 SSH。

## 安装

### 1. 基础安装

```bash
chmod +x install.sh
./install.sh
```

当前这个安装脚本会安装：

- `~/.tmux.conf`
- `/usr/local/bin/stmux`

### 2. 安装脚本现在会安装什么

当前的 `install.sh` 已经会把这三样东西一次装好：

- `~/.tmux.conf`
- `~/.tmux/status.sh`
- `/usr/local/bin/stmux`

也就是说，安装完成后，你本地的 `~/.tmux/status.sh` 已经就位，后续直接执行 `stmux <host> <session> sync` 就可以把它同步到远端。

### 3. 手动安装方式

如果你不想跑 `install.sh`，可以直接手工安装完整组件：

```bash
cp .tmux.conf ~/.tmux.conf
mkdir -p ~/.tmux
cp .tmux/status.sh ~/.tmux/status.sh
chmod +x ~/.tmux/status.sh
sudo cp stmux /usr/local/bin/stmux
sudo chmod +x /usr/local/bin/stmux
```

## 命令格式

```bash
stmux <ssh-alias> [session_name] [sync]
```

- `ssh-alias`：你本地 `~/.ssh/config` 里定义的主机别名
- `session_name`：可选，tmux 会话名，默认是 `main`
- `sync`：可选，但必须放在第三个位置；表示连接前先同步本地 tmux 文件

这里有一个很重要的现状：

- `sync` 现在是位置参数，不是真正的命令行 flag
- 如果你想“用默认会话名并且先同步”，要显式写出 `main`

正确写法：

```bash
stmux my-server main sync
```

如果你写成下面这样：

```bash
stmux my-server sync
```

脚本会把 `sync` 当成会话名，而不是同步开关。

## 常见用法

### 首次使用的推荐命令

```bash
stmux my-server main sync
```

新机器首次安装后，或者第一次连接某台服务器时，建议先执行这一条。
这样可以先把你本地的 `~/.tmux.conf` 和 `~/.tmux/status.sh` 推到远端，再进入 tmux。

### 连接默认会话

```bash
stmux my-server
```

这会连接到 `my-server`，并接入 `main` 会话；如果不存在就创建。

### 连接指定会话

```bash
stmux my-server logs
```

### 先同步再连接

```bash
stmux my-server dev sync
```

## `sync` 现在实际会做什么

当第三个参数是 `sync` 时，`stmux` 当前实现会：

- 先在远端执行 `mkdir -p ~/.tmux`
- 优先尝试 `rsync -avz ~/.tmux/ <host>:~/.tmux/`
- 如果 `rsync` 不可用或失败，则回退到 `scp -r ~/.tmux/* <host>:~/.tmux/`
- 把本地 `~/.tmux.conf` 复制到远端 `~/.tmux.conf`
- 在远端执行 `chmod +x ~/.tmux/status.sh`

补充说明：

- `rsync` 会排除匹配 `*_index_*` 的文件
- `sync` 的同步源是你本机 Home 目录下的 `~/.tmux/` 和 `~/.tmux.conf`，不是当前仓库目录
- 如果你本地没有 `~/.tmux/status.sh`，那远端也不会凭空得到这个脚本

## `.tmux.conf` 当前提供的行为

当前配置已经包含这些能力：

- 双前缀：默认 `Ctrl+b` 仍然可用，同时额外支持 `Ctrl+a`
- 鼠标支持
- 通过 OSC 52 做 tmux 剪贴板集成
- 鼠标选中文本后复制，但不立刻清掉高亮
- 分屏快捷键：
  - `Prefix + \\`：左右分屏，对应 `split-window -h`
  - `Prefix + -`：上下分屏，对应 `split-window -v`
- 新开的 pane 会继承当前 pane 的工作目录
- `Prefix + r`：重新加载 `~/.tmux.conf`
- 当前活动 pane 使用红色边框
- 绿色状态栏，右侧显示状态脚本输出、主机名、pane 编号和时间

## 状态栏脚本会显示什么

`.tmux.conf` 当前会在状态栏右侧调用 `bash $HOME/.tmux/status.sh`。
这个脚本现在会输出：

- CPU 使用率
- 内存使用情况
- 一个 IPv4 地址，按检测到的网卡轮播显示

当前网卡标签规则：

- `enp*` 显示为 `LAN`
- `eth*` 显示为 `ETH`
- `zt*` 显示为 `ZT`
- 其他网卡统一显示为 `NET`

如果没有找到合适的 IPv4 地址，就会显示 `No IP`。

## 环境要求

### 本地机器

- `bash`
- `ssh`
- `scp`
- 可选的 `rsync`
- 已在 `~/.ssh/config` 中配置好远端别名

### 远端服务器

- `bash`
- `tmux`
- 状态脚本依赖的一些常见 Linux 命令，尤其是 `top`、`free`、`ip`、`hostname`

虽然 `status.sh` 里有一部分 macOS 兼容逻辑，但它的主要目标仍然是 Linux 远端服务器。

## 终端兼容性说明

当前 `stmux` 在启动远端 tmux 之前，会先发送一段关闭鼠标上报的转义序列。
这是当前脚本里为 Ghostty 相关终端噪声准备的兼容处理。

## 排障建议

### 状态栏没有显示 CPU、内存或 IP

优先检查：

- 远端 `~/.tmux/status.sh` 是否存在
- 远端 `~/.tmux/status.sh` 是否有执行权限
- 远端是否安装了 `free`、`ip`、`top`
- 是否已经执行过 `Prefix + r` 重载配置，或者重新用 `sync` 连过一次

### `sync` 从 `rsync` 回退到了 `scp`

这是正常的兜底逻辑。常见原因是本地或远端没有安装 `rsync`，或者 `rsync` 执行失败。
脚本会继续使用 `scp`。

### 找不到 SSH 主机

确认你传给 `stmux` 的第一个参数，确实是本地 `~/.ssh/config` 里定义的别名。

## 仓库结构

```text
.
├── .tmux.conf
├── .tmux/
│   └── status.sh
├── install.sh
└── stmux
```
