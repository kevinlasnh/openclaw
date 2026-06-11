# spark-f153 收工后安全清理指南

## 目标

收工后，把这次为了维护建立的入口尽量清干净，确保：

- 远端机器不能继续通过这次维护链路接近你
- 你也不能继续通过这次临时入口登录远端
- 远端机器上尽量少留与你相关的痕迹

## 关键事实

只删远端 `authorized_keys` 还不够。

要真正把这次维护链路收掉，至少要处理两层：

1. **远端机器本身**
   - 删除你的 SSH 公钥
   - 让远端退出 tailnet
   - 删除这次维护留下的报告和脚本
2. **你自己的 Tailscale 后台**
   - 如果你要“最大安全保证”，还要撤销或轮换 reusable auth key

原因：

- 远端 `authorized_keys` 里放的是你的公钥，只影响“你能不能登录他”
- 真正能让远端重新进入你 tailnet 的敏感物是：
  - 你的 reusable auth key

## 已准备好的文件

- 远端硬清理脚本：
  - `spark_f153_security_cleanup_hard.sh`

## 第 1 步：让远端运行硬清理脚本

运行：

- `spark_f153_security_cleanup_hard.sh`

默认动作：

- 删除远端 `authorized_keys` 中属于你的公钥
- `tailscale logout`
- 停止并禁用 Tailscale 服务
- 清除 Tailscale state
- 卸载 Tailscale
- 删除桌面 / 家目录 / `/tmp` 下这次维护产生的报告文件
- 删除常见的临时脚本文件
- 清理 `~/.ssh/known_hosts` 中与你有关的条目
- 清理 `~/.bash_history` 中与本次维护相关的命令痕迹

## 第 2 步：在你自己的 Tailscale 后台做 1 个动作

如果你只是想“这台机器现在先断开”，远端硬清理通常就够了。

如果你要的是更强的“保证”，还要做下面这一步：

- 去 Tailscale Keys 页面：
  - <https://login.tailscale.com/admin/settings/keys>
- 把这次维护用的 reusable auth key：
  - `revoke` 或 `rotate`

为什么这一步重要：

- 如果那把 reusable auth key 未来泄露，单靠远端删文件并不能阻止再次入网
- 撤销或轮换后，这把旧 key 就彻底废了

## 第 3 步：可选，在 Machines 页面确认设备已消失

- <https://login.tailscale.com/admin/machines>

确认：

- `spark-f153` 已经离线或已不再出现在当前活跃设备列表里

## 你最该记住的结论

想要“快速维护 + 收工后断开”，真正要保住的是：

1. 你的 SSH 私钥只留在你自己电脑
2. 你的 reusable auth key 只留在你自己手里
3. 收工时远端运行 `spark_f153_security_cleanup_hard.sh`
4. 如果你要最高安全等级，再去后台撤销或轮换 auth key
