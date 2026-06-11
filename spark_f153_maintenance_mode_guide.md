# spark-f153 维护模式操作指南

## 这套方案解决什么问题

你这次要的是一套更简单的维护模式：

- 维护期间：
  - 临时把 `spark-f153` 拉进你的 Tailscale 网络
  - 临时把你的 SSH 公钥写进对方 `authorized_keys`
  - 这样你们在维护窗口里可以快速互通
- 维护结束：
  - 一键让 `spark-f153` 退出你的 tailnet
  - 一键把你的 SSH 公钥从对方机器删掉
  - 这样你不能再 SSH 到他，他也不能继续通过这条 Tailscale 路径接近你
- 未来再维护：
  - 继续用同一套脚本
  - 不需要每次重新设计方案

## 先说边界

这套方案可以做到“以后不用每次都去网站新建一堆东西”，但有一个底线：

- **不能把可重复使用的 Tailscale auth key 长期留在对方机器上**

原因很直接：

- 如果那个 key 留在对方机器上，对方未来随时都能重新加入你的 tailnet
- 这就不叫“收工后断开”，而是留下了长期后门

所以最稳妥的设计是：

- 你只在 Tailscale 后台做 **一次** 初始化
- 生成一把 **可重复使用的 auth key**
- 这把 key 只保留在你自己手里
- 以后每次开维护，只是在对方机器运行脚本时临时输入这把 key

这样以后不需要每次再去网站生成新东西，但密钥也不会留在对方机器。

## 仓库里已经准备好的文件

- 启用维护模式：
  - `spark_f153_maintenance_mode_enable.sh`
- 关闭维护模式：
  - `spark_f153_maintenance_mode_disable.sh`

## 你只需要做一次的网站操作

### 第 1 步：登录 Tailscale 后台

- <https://login.tailscale.com/admin>

### 第 2 步：去 Keys 页面

- <https://login.tailscale.com/admin/settings/keys>

### 第 3 步：生成一把可重复使用的 Auth Key

建议参数：

- Description：
  - `spark-f153-maintenance`
- Reusable：
  - `On`
- Expiry：
  - 选一个你能接受的周期
  - 如果你非常在意风险，就设短一点
- Ephemeral：
  - `Off`
- Pre-approved：
  - 如果你的 tailnet 开了设备审批，就开 `On`

这一步做完后，把这把 key 保存在你自己安全的位置。

不要把这把 key 写死到对方机器里。

官方文档：

- Auth keys：
  - <https://tailscale.com/docs/features/access-control/auth-keys>

## 每次开始维护时怎么做

### 第 1 步：让对方运行启用脚本

运行：

- `spark_f153_maintenance_mode_enable.sh`

脚本会做这些事：

- 确认 `sudo`
- 把你的 SSH 公钥写入对方 `~/.ssh/authorized_keys`
- 安装并启动 Tailscale
- 提示输入你手里的 reusable auth key
- 让这台机子加入你的 tailnet
- 输出它的 Tailscale IP、SSH 状态、OpenClaw 状态

### 第 2 步：你开始维护

这时你就可以：

- 走 Tailscale IP 去 SSH 它
- 看日志
- 改 OpenClaw 配置
- 重启服务

## 每次维护结束时怎么做

### 第 1 步：让对方运行关闭脚本

运行：

- `spark_f153_maintenance_mode_disable.sh`

脚本会做这些事：

- 删除对方 `authorized_keys` 里属于你的那一行公钥
- `tailscale logout`
- `systemctl disable --now tailscaled`

执行完之后：

- 你不能再通过这条 SSH 入口连他
- 这台机子也不再留在你的 tailnet 里

### 第 2 步：可选更彻底清理

如果你希望断得更干净，可以在运行关闭脚本前加环境变量：

- `PURGE_TAILSCALE_STATE=true`

这会额外删掉本地 Tailscale state 文件。

代价是：

- 下次再开启维护模式时，会更像一次全新加入

## 这套方案里什么是“后路”

真正安全的“后路”不是把秘密留在他电脑里，而是保留这三样：

1. 你本地的 SSH 私钥
2. 你本地保存的 reusable Tailscale auth key
3. 仓库里的启用/关闭脚本

这样以后要重新打通时，你只需要：

1. 让对方运行启用脚本
2. 在脚本提示时输入你手里那把 reusable auth key

这就已经够快了，而且不会把长期入网凭据丢在对方机器上。

## 你必须知道的一个事实

“删除他电脑上的 SSH 文件，让他不能连我电脑” 这句话里有一半是误区。

准确说法是：

- 对方机器上的 `authorized_keys` 里放的是 **你的公钥**
- 这只会决定“你能不能登录他”
- **不会**让“他能登录你”

真正会让他重新进入你网络的敏感东西是：

- 你的 Tailscale auth key
- 你的 SSH 私钥

这两样都不应该留在他机器上。

## 你现在该怎么做

按这个顺序：

1. 只去一次：
   - <https://login.tailscale.com/admin/settings/keys>
   生成一把 reusable auth key
2. 保存好这把 key
3. 以后每次维护开始：
   - 让对方运行 `spark_f153_maintenance_mode_enable.sh`
4. 维护结束：
   - 让对方运行 `spark_f153_maintenance_mode_disable.sh`

## 官方链接

- Tailscale Admin：
  - <https://login.tailscale.com/admin>
- Keys：
  - <https://login.tailscale.com/admin/settings/keys>
- Linux 安装：
  - <https://tailscale.com/docs/install/linux>
- Auth keys：
  - <https://tailscale.com/docs/features/access-control/auth-keys>
