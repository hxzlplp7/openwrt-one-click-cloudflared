# OpenWrt / iStoreOS Cloudflared 一键安装及管理脚本

这是一个适用于 OpenWrt 和 iStoreOS 设备的 Cloudflare Tunnel (cloudflared) 一键安装与管理脚本。

## 功能特点
- **自动检测架构**：支持 amd64 (x86_64), arm64 (aarch64), arm (armv7) 架构。
- **自动安装依赖**：自动安装 `wget-ssl`, `ca-certificates` 等必要组件。
- **服务管理**：通过 OpenWrt 标准的 PROCD 进行管理（启动/停止/重启/开机自启）。
- **交互式菜单**：简单易用的中文管理界面。
- **快捷指令**：安装后支持通过 `cloudflared-menu` 命令随时唤起。

## 使用方法

1.  **下载脚本**
    使用 SSH 连接到你的路由器，运行以下命令（请将 URL 替换为实际文件的下载链接）：
    ```bash
    wget -O cloudflared_install.sh https://raw.githubusercontent.com/hxzlplp7/openwrt-one-click-cloudflared/main/cloudflared_install.sh
    chmod +x cloudflared_install.sh
    ```

2.  **运行脚本**
    ```bash
    ./cloudflared_install.sh
    ```

3.  **安装步骤**
    - 在菜单中选择 **1. 安装 Cloudflared**。
    - 安装完成后，选择 **2. 配置 Token**，粘贴你在 Cloudflare Zero Trust 面板获取的 Tunnel Token。
    - 选择 **3. 启动服务**。

4.  **后续管理**
    - 安装成功后，可以直接在终端输入以下命令唤起菜单：
      ```bash
      cloudflared-menu
      ```

## 注意事项
- 脚本默认从 GitHub 官方 Releases 下载二进制文件。如果你的网络环境无法连接 GitHub，可能需要挂梯子或者手动下载对应架构的二进制文件上传到 `/usr/bin/cloudflared`。
- Cloudflared 运行时内存占用可能在 30MB 以上，请确保设备有足够的剩余内存。

## 文件路径说明
- **二进制文件**: `/usr/bin/cloudflared`
- **配置文件/Token**: `/etc/cloudflared/token`
- **启动脚本**: `/etc/init.d/cloudflared`
- **快捷指令**: `/usr/bin/cloudflared-menu`
