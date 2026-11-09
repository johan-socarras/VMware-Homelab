# Runs once at the first (automatic) logon of windows-server-2025-core, from the answer CD.
# VMware Tools (vmxnet3 driver), static network on both NICs, OpenSSH with key login only, WinRM off, cleanup, power off.
# Log: C:\Windows\Temp\setup.log. On an error the VM stays on, so the console shows what went wrong.
$ErrorActionPreference = 'Stop'
Start-Transcript -Path C:\Windows\Temp\setup.log
try {
    # 1. VMware Tools: Windows has no vmxnet3 driver of its own
    $tools = Get-ChildItem "$PSScriptRoot\vmware-tools" -Filter 'setup64.exe' | Select-Object -First 1
    if (-not $tools) { $tools = Get-Item "$PSScriptRoot\vmware-tools\setup.exe" }
    Start-Process -FilePath $tools.FullName -ArgumentList '/S /v "/qn REBOOT=R"' -Wait

    # 2. Network: the MACs are fixed in the .vmx, so each NIC is found by its MAC
    $nics = @{ '00-50-56-10-08-16' = 'nat'; '00-50-56-10-10-16' = 'lab' }
    $deadline = (Get-Date).AddMinutes(5)
    while ((Get-NetAdapter | Where-Object { $nics.ContainsKey($_.MacAddress) }).Count -lt 2) {
        if ((Get-Date) -gt $deadline) { throw 'The two vmxnet3 adapters never showed up' }
        Start-Sleep -Seconds 5
    }
    foreach ($a in Get-NetAdapter | Where-Object { $nics.ContainsKey($_.MacAddress) }) {
        Rename-NetAdapter -Name $a.Name -NewName $nics[$a.MacAddress]
    }
    foreach ($name in 'nat', 'lab') {
        Disable-NetAdapterBinding -Name $name -ComponentID ms_tcpip6
        Set-NetIPInterface -InterfaceAlias $name -Dhcp Disabled
    }
    # nat (vmnet8): updates, activation, SSH from the host
    New-NetIPAddress -InterfaceAlias nat -IPAddress 10.10.8.16 -PrefixLength 24 -DefaultGateway 10.10.8.2 | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias nat -ServerAddresses 10.10.8.2
    Set-DnsClient -InterfaceAlias nat -ConnectionSpecificSuffix lab.internal
    # lab (vmnet10): isolated, no gateway, not registered in DNS
    New-NetIPAddress -InterfaceAlias lab -IPAddress 10.10.10.16 -PrefixLength 24 | Out-Null
    Set-DnsClient -InterfaceAlias lab -RegisterThisConnectionsAddress $false

    # 3. OpenSSH Server (ships with Windows Server 2025, disabled): key login only, PowerShell as the shell
    $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*'
    if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $cap.Name | Out-Null }
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd   # the first start writes C:\ProgramData\ssh\sshd_config
    $keys = 'C:\ProgramData\ssh\administrators_authorized_keys'
    Copy-Item "$PSScriptRoot\authorized_keys" $keys
    icacls.exe $keys /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F' | Out-Null   # Administrators, SYSTEM
    $cfg = 'C:\ProgramData\ssh\sshd_config'
    # Must go above the "Match Group administrators" block at the end of the file, so it replaces the commented default
    (Get-Content $cfg) -replace '^#?PasswordAuthentication .*', 'PasswordAuthentication no' | Set-Content $cfg -Encoding ascii
    if (-not (Select-String -Path $cfg -Pattern '^PasswordAuthentication no' -Quiet)) { throw 'PasswordAuthentication not set' }
    New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -PropertyType String -Force `
        -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null
    $rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    if ($rule) { Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True -Profile Any }
    else {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Direction Inbound `
            -Protocol TCP -LocalPort 22 -Action Allow -Profile Any | Out-Null
    }
    Restart-Service sshd

    # 4. WinRM: on by default in Windows Server (5985/tcp); this server is managed over SSH only
    Disable-PSRemoting -Force -WarningAction SilentlyContinue
    Stop-Service WinRM -Force
    Set-Service WinRM -StartupType Disabled
    Disable-NetFirewallRule -DisplayGroup 'Windows Remote Management'

    # 5. Cleanup: no password left on disk from the answer file or the automatic logon
    Remove-Item C:\Windows\Panther\unattend*.xml -Force -ErrorAction SilentlyContinue
    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -Path $winlogon -Name AutoAdminLogon -Value '0'
    Remove-ItemProperty -Path $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue

    Write-Output 'setup.ps1 finished'
    Stop-Transcript
    Stop-Computer -Force
}
catch {
    Write-Output "setup.ps1 FAILED: $_"
    Stop-Transcript
}
