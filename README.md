# OpenWrt / iStoreOS Cloudflared 一键安装管理脚本

[![GitHub](https://img.shields.io/github/license/hxzlplp7/openwrt-one-click-cloudflared)](LICENSE)

这是一个适用于 **OpenWrt** 和 **iStoreOS** 设备的 Cloudflare Tunnel (cloudflared) 一键安装与管理脚本。

## ✨ 功能特点

- 🔧 **自动检测架构** - 支持 amd64 (x86_64), arm64 (aarch64), arm (armv7) 架构
- 📦 **一键安装** - 自动下载官方二进制文件并安装依赖
- 🚀 **服务管理** - 通过 OpenWrt 标准的 PROCD 进行管理（启动/停止/重启/开机自启）
- 🎯 **交互式菜单** - 简单易用的中文管理界面
- ⌨️ **命令行支持** - 支持命令行参数直接操作
- 📋 **日志查看** - 方便查看运行日志排查问题
- 🔐 **Token 管理** - 安全存储 Cloudflare Tunnel Token

## 📋 系统要求

- OpenWrt 18.06+ 或 iStoreOS
- 至少 50MB 可用存储空间
- 可访问 GitHub 的网络连接（用于下载二进制文件）
- Root 权限

## 🚀 快速开始

### 一键安装

使用 SSH 连接到你的路由器，运行以下命令：

```bash
wget -O /tmp/cloudflared.sh https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-cloudflared/main/cloudflared_install.sh && chmod +x /tmp/cloudflared.sh && sh /tmp/cloudflared.sh
```

或者分步执行：

```bash
# 下载脚本
wget -O /tmp/cloudflared.sh https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-cloudflared/main/cloudflared_install.sh

# 添加执行权限
chmod +x /tmp/cloudflared.sh

# 运行脚本
sh /tmp/cloudflared.sh
```

### 使用步骤

1. 在菜单中选择 **1. 安装 Cloudflared**
2. 安装完成后，选择 **2. 配置 Token**
3. 粘贴你在 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) 面板获取的 Tunnel Token
4. 选择 **4. 启动服务**

### 快捷命令

安装成功后，可以直接在终端输入以下命令唤起管理菜单：

```bash
cloudflared-menu
```

## 📖 命令行用法

脚本支持命令行参数，方便自动化操作：

```bash
# 安装
cloudflared-menu install

# 配置 Token
cloudflared-menu token

# 启动服务
cloudflared-menu start

# 停止服务
cloudflared-menu stop

# 重启服务
cloudflared-menu restart

# 查看状态
cloudflared-menu status

# 查看日志
cloudflared-menu logs

# 卸载
cloudflared-menu uninstall

# 显示帮助
cloudflared-menu help
```

## 📁 文件路径

| 文件 | 路径 |
|------|------|
| 二进制文件 | `/usr/bin/cloudflared` |
| 配置目录 | `/etc/cloudflared/` |
| Token 文件 | `/etc/cloudflared/token` |
| 启动脚本 | `/etc/init.d/cloudflared` |
| 快捷命令 | `/usr/bin/cloudflared-menu` |

## 🔧 如何获取 Tunnel Token

1. 登录 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) 面板
2. 进入 **Networks** → **Tunnels**
3. 点击 **Create a tunnel**
4. 选择 **Cloudflared** 类型
5. 给 Tunnel 起个名字
6. 在安装页面复制显示的 Token（一长串字符）

## ⚠️ 注意事项

- **网络问题**: 脚本默认从 GitHub 官方 Releases 下载二进制文件。如果你的网络环境无法连接 GitHub，可以：
  - 挂梯子
  - 手动下载对应架构的二进制文件上传到 `/usr/bin/cloudflared`
  
- **内存占用**: Cloudflared 运行时内存占用在 30-100MB 左右，请确保设备有足够的剩余内存

- **存储空间**: cloudflared 二进制文件约 40MB，请确保有足够空间

## 🐛 问题排查

如果服务无法启动，可以查看日志：

```bash
# 通过脚本查看
cloudflared-menu logs

# 或直接使用 logread
logread | grep cloudflared
```

## 📜 许可证

MIT License

## 🙏 致谢

- [Cloudflare](https://www.cloudflare.com/) - 提供免费的 Tunnel 服务
- [OpenWrt](https://openwrt.org/) - 开源路由器固件
