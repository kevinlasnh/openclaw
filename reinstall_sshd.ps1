# OpenSSH Server 重新安装脚本
# 需要管理员权限运行

Write-Host "=== 检查 OpenSSH 文件 ===" -ForegroundColor Cyan
$sshPath = "C:\Windows\System32\OpenSSH\sshd.exe"
if (Test-Path $sshPath) {
    Write-Host "✓ sshd.exe 存在" -ForegroundColor Green
} else {
    Write-Host "✗ sshd.exe 不存在！需要重新安装 OpenSSH" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== 方法1: 使用 Add-WindowsCapability ===" -ForegroundColor Cyan
try {
    # 先尝试安装（如果已安装会报错但能触发修复）
    $result = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 2>&1
    Write-Host "结果: $result" -ForegroundColor Yellow
} catch {
    Write-Host "Add-WindowsCapability 失败: $_" -ForegroundColor Red
}

Write-Host "`n=== 检查服务状态 ===" -ForegroundColor Cyan
$service = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "✓ sshd 服务存在，状态: $($service.Status), 启动类型: $($service.StartType)" -ForegroundColor Green
} else {
    Write-Host "✗ sshd 服务不存在，尝试手动创建..." -ForegroundColor Yellow

    try {
        New-Service -Name sshd -BinaryPathName 'C:\Windows\System32\OpenSSH\sshd.exe' -DisplayName 'OpenSSH SSH Server' -StartupType Automatic
        Write-Host "✓ 服务创建成功" -ForegroundColor Green
    } catch {
        Write-Host "✗ 创建服务失败: $_" -ForegroundColor Red
        Write-Host "`n请尝试方法2: 设置 → 应用 → 可选功能 → 添加功能 → OpenSSH Server" -ForegroundColor Yellow
    }
}

Write-Host "`n=== 配置防火墙规则 ===" -ForegroundColor Cyan
try {
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
    Write-Host "✓ 防火墙规则已配置" -ForegroundColor Green
} catch {
    Write-Host "防火墙规则可能已存在" -ForegroundColor Yellow
}

Write-Host "`n=== 启动服务 ===" -ForegroundColor Cyan
try {
    Start-Service sshd
    Write-Host "✓ sshd 服务已启动" -ForegroundColor Green
} catch {
    Write-Host "启动失败: $_" -ForegroundColor Red
}

Write-Host "`n=== 验证服务 ===" -ForegroundColor Cyan
Get-Service -Name sshd, ssh-agent | Format-Table Name, Status, StartType

Write-Host "`n=== 检查端口监听 ===" -ForegroundColor Cyan
Get-NetTCPConnection -LocalPort 22 -ErrorAction SilentlyContinue | Select-Object LocalAddress, LocalPort, State

Write-Host "`n完成！" -ForegroundColor Green
