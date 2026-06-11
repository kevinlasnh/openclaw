# spark-f153 接入 Kevin Tailnet 操作指南

## 目标

- 把对方的 `spark-f153` 拉进你的 Tailscale tailnet
- 让你可以通过 Tailscale 访问对方机器
- 不让对方机器通过 Tailscale 反向访问你的其它设备
- 继续使用标准 `sshd + authorized_keys`
- **不启用** Tailscale SSH

## 已准备好的仓库文件

- 远端采集脚本：
  - `collect_ubuntu_host_probe.sh`
- 第一阶段 SSH 准备脚本：
  - `spark_f153_stage1_prepare_ssh.sh`
- 第二阶段安装 Tailscale 脚本：
  - `spark_f153_stage2_install_tailscale.sh`
- 第三阶段加入 Kevin tailnet 的脚本：
  - `spark_f153_stage3_join_kevin_tailnet.sh`
- 单向权限策略模板：
  - `spark_f153_tailnet_policy_template.hujson`

## 你现在的真实状态

- `spark-f153` 已经写入了给本机准备的 SSH 公钥
- 远端 `sudo -v` 已通过
- 远端公网出口 IP 是 `180.158.6.88`
- 远端 `22` 端口在本机监听
- 但我从本地实测：
  - `ssh admin@180.158.6.88:22` 超时
- 结论：
  - 公网 SSH 路径目前不通
  - 当前最稳方案是改走 Tailscale

## 第 1 步：登录 Tailscale 管理后台

- 后台首页：
  - <https://login.tailscale.com/admin>
- 机器列表：
  - <https://login.tailscale.com/admin/machines>
- Access controls：
  - <https://login.tailscale.com/admin/acls>
- Keys：
  - <https://login.tailscale.com/admin/settings/keys>

## 第 2 步：在 Access controls 里创建专用 Tag

打开：

- <https://login.tailscale.com/admin/acls>

然后按这个值创建一个 Tag：

- Tag 名：
  - `client-spark-f153`
- 完整 Tag：
  - `tag:client-spark-f153`

说明：

- 这是给对方机器用的专用设备身份
- 后面的访问控制全部靠这个 tag 收口
- 不要复用成泛用大 tag，例如 `tag:server`

官方参考：

- Tailscale Tags 文档：
  - <https://tailscale.com/docs/features/tags>
- Visual editor 里添加 Tag：
  - <https://tailscale.com/docs/reference/visual-editor>

## 第 3 步：在 Access controls 里加“单向访问”规则

还是在：

- <https://login.tailscale.com/admin/acls>

新增一条 General access rule：

- Source：
  - 你的 Tailscale 登录邮箱
- Destination：
  - `tag:client-spark-f153`
- Port and protocol：
  - `All ports and protocols`

这条规则的含义是：

- 只允许“你”访问这台 tagged device
- 不给 `tag:client-spark-f153 -> 你的设备` 的反向规则

注意两点：

- Tailscale 的访问控制是 **默认拒绝**
- 但如果你当前 policy 里已经有很宽的放行规则，例如“所有设备互通”，那必须把这类宽规则收紧，否则会冲掉你的单向隔离目标

如果你喜欢改文本，不想用可视化界面，就参考：

- `spark_f153_tailnet_policy_template.hujson`

把其中这项替换掉：

- `REPLACE_WITH_YOUR_TAILSCALE_EMAIL`

改成你自己的 Tailscale 登录身份。

官方参考：

- Access control 总览：
  - <https://tailscale.com/docs/features/access-control>
- Grants：
  - <https://tailscale.com/docs/features/access-control/grants>
- Tailnet policy file：
  - <https://tailscale.com/docs/features/tailnet-policy-file>

## 第 4 步：生成一把给 `spark-f153` 专用的 Auth Key

打开：

- <https://login.tailscale.com/admin/settings/keys>

点击：

- `Generate auth key`

建议你这样填：

- Description：
  - `spark-f153`
- Reusable：
  - `Off`
- Expiry：
  - `1 day` 或者你能接受的最短时长
- Ephemeral：
  - `Off`
- Pre-approved：
  - 如果你的 tailnet 开了 device approval，就开 `On`
- Tags：
  - `tag:client-spark-f153`

不要勾选或切到任何 Tailscale SSH 相关选项。我们当前设计是：

- Tailscale 只负责网络连通
- SSH 还是走标准 `sshd`

官方参考：

- Auth keys：
  - <https://tailscale.com/docs/features/access-control/auth-keys>
- Add a device：
  - <https://tailscale.com/docs/features/access-control/device-management/how-to/set-up>

## 第 5 步：让对方执行第 3 阶段脚本

让对方运行仓库里的：

- `spark_f153_stage3_join_kevin_tailnet.sh`

执行时会要求输入：

- 你刚生成的 Auth Key

脚本会自动做这些事：

- 安装 Tailscale
- 启动 `tailscaled`
- 用你提供的 Auth Key 把 `spark-f153` 加入你的 tailnet
- 给它套上：
  - `tag:client-spark-f153`
- 保持：
  - `--ssh=false`

也就是说，它**不会**启用 Tailscale SSH，只会加入你的 Tailscale 网络。

跑完后，对方桌面会生成一个结果文件，类似：

- `~/Desktop/spark_f153_stage3_join_kevin_tailnet_时间戳.txt`

把这个结果文件发回来。

## 第 6 步：到 Machines 页面确认设备已进网

打开：

- <https://login.tailscale.com/admin/machines>

你应该能看到一台新设备，名字大概率会是：

- `spark-f153`

你要检查 4 件事：

1. 设备已经加入你的 tailnet
2. 设备带有 tag：
   - `tag:client-spark-f153`
3. 设备状态是在线
4. 没有卡在 `Needs approval`

如果卡在 `Needs approval`：

- 说明你的 tailnet 开了 device approval，但刚才生成 key 时没开 `Pre-approved`
- 你就在 Machines 页手工批准它

## 第 7 步：验证“你能连它，它不能反打你”

你这边验证：

1. 先看它分到的 Tailscale IP
2. 用这个 Tailscale IP 走 SSH
3. 读它的 OpenClaw 状态

验证通过标准：

- 你能用 Tailscale IP 连到 `spark-f153`
- 你能访问它的服务，例如 SSH 或 OpenClaw 端口
- 它没有拿到访问你其它设备的 grant

如果你发现它仍能访问你自己的设备，说明不是脚本问题，而是你 tailnet policy 里还有“过宽”的旧规则没删干净。

## 最重要的判断标准

只要满足下面 3 条，这套就算做成了：

1. `spark-f153` 出现在你的 Machines 页
2. `spark-f153` 带着 `tag:client-spark-f153`
3. Access controls 里只有：
   - 你的身份 -> `tag:client-spark-f153`
   没有：
   - `tag:client-spark-f153` -> 你的设备

## 官方文档链接汇总

- Tailscale Admin Console：
  - <https://login.tailscale.com/admin>
- Access controls：
  - <https://login.tailscale.com/admin/acls>
- Keys：
  - <https://login.tailscale.com/admin/settings/keys>
- Machines：
  - <https://login.tailscale.com/admin/machines>
- Install Tailscale on Linux：
  - <https://tailscale.com/docs/install/linux>
- Auth keys：
  - <https://tailscale.com/docs/features/access-control/auth-keys>
- Tags：
  - <https://tailscale.com/docs/features/tags>
- Access control：
  - <https://tailscale.com/docs/features/access-control>
- Grants：
  - <https://tailscale.com/docs/features/access-control/grants>
- Tailnet policy file：
  - <https://tailscale.com/docs/features/tailnet-policy-file>
- Visual policy editor：
  - <https://tailscale.com/docs/reference/visual-editor>

## 你下一步该做什么

按顺序做，不要跳：

1. 去 Tailscale Access controls 建 `tag:client-spark-f153`
2. 加一条：
   - 你的邮箱 -> `tag:client-spark-f153`
3. 去 Keys 页面生成一把 tagged auth key
4. 让对方运行：
   - `spark_f153_stage3_join_kevin_tailnet.sh`
5. 把执行结果文件发回来

只要你把第 5 步的结果贴回来，我下一步就能继续给你做“本机验证脚本”和后续的 OpenClaw 故障排查。
