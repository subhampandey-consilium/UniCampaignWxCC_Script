$projectName = "UniCampaign_WxCC"
$localPath = "C:\inetpub\wwwroot\UniCampaignWxCC"
$siteName = "UniCampaignWxCC"  # Change this if you want the site name to be different
$appPoolName = $projectName
$repoUrl = "https://github.com/subhampandey-consilium/UniCampaign_CareSource.git"
$expandedPath = "C:\$projectName"
$certificateFriendlyName = "UniCampaignWxCCCert"

# Node.js and MySQL installer URLs
$nodeJsUrl = "https://nodejs.org/dist/v14.17.0/node-v14.17.0-x64.msi"
$mysqlUrl = "https://dev.mysql.com/get/Downloads/MySQLInstaller/mysql-installer-web-community-8.0.26.0.msi"

# Define download paths for Node.js and MySQL
$nodeJsInstallerPath = "$env:TEMP\node-v14.17.0-x64.msi"
$mysqlInstallerPath = "$env:TEMP\mysql-installer-web-community-8.0.26.0.msi"

# URLs for ASP.NET Core SDK and Hosting Bundle
$aspNetCoreSdkUrl = "https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/sdk-7.0.100-windows-x64-installer"
$aspNetCoreHostingBundleUrl = "https://dotnet.microsoft.com/en-us/download/dotnet/thank-you/runtime-aspnetcore-7.0.10-windows-hosting-bundle-installer"

# Define download paths for ASP.NET Core SDK and Hosting Bundle
$aspNetCoreSdkInstallerPath = "$env:TEMP\dotnet-sdk-7.0.100-win-x64.exe"
$aspNetCoreHostingBundleInstallerPath = "$env:TEMP\aspnetcore-runtime-7.0.10-win.exe"

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-ExecutionPolicyIfNeeded {
    $currentPolicy = Get-ExecutionPolicy
    if ($currentPolicy -ne "RemoteSigned" -and $currentPolicy -ne "Unrestricted") {
        Write-Output "Current Execution Policy: $currentPolicy. Setting it to RemoteSigned and then Unrestricted."
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
        Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -Force
    } else {
        Write-Output "Current Execution Policy: $currentPolicy. No changes needed."
    }
}


function Install-EXE {
    param (
        [string]$exePath,
        [string]$arguments = "/quiet /norestart"
    )

    $process = Start-Process -FilePath $exePath -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -eq 0) {
        Write-Output "$exePath installation completed successfully."
    } else {
        Write-Output "$exePath installation failed with exit code $($process.ExitCode)."
    }
}

function Ensure-EnvironmentVariable {
    param (
        [string]$variable,
        [string]$value
    )

    $currentValue = [System.Environment]::GetEnvironmentVariable($variable, [System.EnvironmentVariableTarget]::Machine)
    if ($currentValue -notlike "*$value*") {
        $newValue = "$currentValue;$value"
        [System.Environment]::SetEnvironmentVariable($variable, $newValue, [System.EnvironmentVariableTarget]::Machine)
    }
}

if (-not (Test-Admin)) {
    Write-Output "This script needs to be run as an administrator."
    exit 1
}

try {
    Set-ExecutionPolicyIfNeeded

    # Check if Node.js is installed
    try {
        $nodeVersion = node -v
        Write-Output "Node.js is already installed. Version: $nodeVersion"
    } catch {
        Write-Output "Node.js is not installed. Installing Node.js..."
        Invoke-WebRequest -Uri $nodeJsUrl -OutFile $nodeJsInstallerPath

        # Verify Node.js installation
        try {
            $nodeVersion = node -v
            Write-Output "Node.js installation successful. Version: $nodeVersion"
        } catch {
            Write-Output "Node.js is not recognized as an internal or external command. Adding Node.js to PATH..."
            Ensure-EnvironmentVariable -variable "PATH" -value "C:\Program Files\nodejs"
        }
    }

    # Check if Angular CLI is installed
    try {
        $ngVersion = ng version
        Write-Output "Angular CLI is already installed."
    } catch {
        Write-Output "Angular CLI is not installed. Installing Angular CLI..."
        npm install -g @angular/cli@13.0.0
    }

    # Check if MySQL is installed
    try {
        $mysqlVersion = mysql --version
        Write-Output "MySQL is already installed. Version: $mysqlVersion"
    } catch {
        Write-Output "MySQL is not installed. Installing MySQL..."
        Invoke-WebRequest -Uri $mysqlUrl -OutFile $mysqlInstallerPath
    }

    # Check if ASP.NET Core SDK is installed
    try {
        $dotnetVersion = dotnet --version
        Write-Output "ASP.NET Core SDK is already installed. Version: $dotnetVersion"
    } catch {
        Write-Output "ASP.NET Core SDK is not installed. Installing ASP.NET Core SDK..."
        Invoke-WebRequest -Uri $aspNetCoreSdkUrl -OutFile $aspNetCoreSdkInstallerPath
        Install-EXE -exePath $aspNetCoreSdkInstallerPath

        # Verify ASP.NET Core SDK installation
        try {
            $dotnetVersion = dotnet --version
            Write-Output "ASP.NET Core SDK installation successful. Version: $dotnetVersion"
        } catch {
            Write-Output "ASP.NET Core SDK installation failed."
        }
    }

    # Check if ASP.NET Core Hosting Bundle is installed
    try {
        $hostingBundleInstalled = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "Microsoft ASP.NET Core*" }
        if ($hostingBundleInstalled) {
            Write-Output "ASP.NET Core Hosting Bundle is already installed."
        } else {
            throw "Not Installed"
        }
    } catch {
        Write-Output "ASP.NET Core Hosting Bundle is not installed. Installing ASP.NET Core Hosting Bundle..."
        Invoke-WebRequest -Uri $aspNetCoreHostingBundleUrl -OutFile $aspNetCoreHostingBundleInstallerPath
        Install-EXE -exePath $aspNetCoreHostingBundleInstallerPath
    }

    # Check if IIS is installed and install if not using DISM
    $iisInstalled = (dism /online /get-features /format:table | Select-String -Pattern "IIS-WebServerRole" | Select-String -Pattern "Enabled")
    if (-not $iisInstalled) {
        Write-Output "IIS is not installed. Installing IIS..."
        Start-Process -FilePath "dism" -ArgumentList "/online /enable-feature /featurename:IIS-WebServerRole /all" -Wait -NoNewWindow
        Start-Process -FilePath "dism" -ArgumentList "/online /enable-feature /featurename:IIS-WebServerManagementTools /all" -Wait -NoNewWindow
        Start-Process -FilePath "dism" -ArgumentList "/online /enable-feature /featurename:IIS-ManagementConsole /all" -Wait -NoNewWindow

        # Additional IIS features
        Start-Process -FilePath "dism" -ArgumentList "/Online /Enable-Feature /FeatureName:IIS-DefaultDocument /All" -Wait -NoNewWindow
        Start-Process -FilePath "dism" -ArgumentList "/Online /Enable-Feature /FeatureName:IIS-ISAPIFilter /All" -Wait -NoNewWindow
        Start-Process -FilePath "dism" -ArgumentList "/Online /Enable-Feature /FeatureName:IIS-ISAPIExtensions /All" -Wait -NoNewWindow
        Start-Process -FilePath "dism" -ArgumentList "/Online /Enable-Feature /FeatureName:IIS-ManagementService /All" -Wait -NoNewWindow
        Start-Process -FilePath "dism" -ArgumentList "/Online /Enable-Feature /FeatureName:IIS-ManagementScriptingTools /All" -Wait -NoNewWindow

        # Install ASP.NET if needed
        Start-Process -FilePath "dism" -ArgumentList "/Online /Enable-Feature /FeatureName:IIS-ASPNET45 /All" -Wait -NoNewWindow

        # Restart IIS
        Restart-Service W3SVC

        if ($?) {
            Write-Output "IIS and features installed successfully."
        } else {
            throw "Failed to install IIS and features."
        }
    } else {
        Write-Output "IIS is already installed."
    }

    # Ensure WebAdministration module is available
    Import-Module WebAdministration -ErrorAction Stop

    # Ensure the localPath directory exists and is empty
    if (Test-Path $localPath) {
        Remove-Item -Path "$localPath\*" -Recurse -Force
    } else {
        New-Item -Path $localPath -ItemType Directory
    }

    # Clone the application from GitHub repository
    if (Test-Path $expandedPath) {
        Remove-Item -Path $expandedPath -Recurse -Force
    }
    git clone $repoUrl $expandedPath

    # Copy all files and folders from the UniCampaign_WxCC\UniCampaignWxCC folder to the localPath
    $sourcePath = "$expandedPath\UniCampaignWxCC"
    Get-ChildItem -Path $sourcePath -Recurse | ForEach-Object {
        $destinationPath = $_.FullName.Replace($sourcePath, $localPath)
        if ($_.PSIsContainer) {
            if (-not (Test-Path $destinationPath)) {
                New-Item -ItemType Directory -Path $destinationPath
            }
        } else {
            Copy-Item -Path $_.FullName -Destination $destinationPath -Force
        }
    }

  # Create self-signed certificate for HTTPS
    $cert = New-SelfSignedCertificate -CertStoreLocation "Cert:\LocalMachine\My" -DnsName "localhost" -FriendlyName $certificateFriendlyName -NotAfter (Get-Date).AddYears(5)

    # Create Application Pool if it doesn't exist
    if (-not (Test-Path "IIS:\AppPools\$appPoolName")) {
        $appPool = New-WebAppPool -Name $appPoolName
        $appPool | Set-ItemProperty -Name "ManagedPipelineMode" -Value "Integrated"
        $appPool | Set-ItemProperty -Name "ManagedRuntimeVersion" -Value ""
        $appPool | Set-ItemProperty -Name "processModel.identityType" -Value "ApplicationPoolIdentity"
    }

    # Check if the website already exists
    $existingSite = Get-WebSite -Name $siteName -ErrorAction SilentlyContinue
    if ($existingSite) {
        Write-Output "Website '$siteName' already exists. Removing and recreating..."
        Remove-WebSite -Name $siteName -Force
    }

    # Create Site in IIS
    New-WebSite -Name $siteName -PhysicalPath $localPath -Port 44305 -ApplicationPool $appPoolName -Force

    # Create HTTPS binding for the site
    New-WebBinding -Name $siteName -IPAddress "*" -Port 44305 -Protocol "https"
    $binding = Get-WebBinding -Name $siteName -Port 44305 -Protocol "https"
    $binding.AddSslCertificate($cert.Thumbprint, "My")

    Write-Output "Deployment completed successfully!"
} catch {
    Write-Output "An error occurred: $_"
}
