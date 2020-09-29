function Test-TelegrafExecutable {
    <#
        This function tests if telegraf executable exists and its hash matches
        to what is provided in ExecutableMD5Hash parameter
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ExecutableMD5Hash
    )

    $ErrorActionPreference = "Stop"

    if (Test-Path -Path "$env:ProgramFiles\Telegraf\telegraf.exe" -PathType Leaf) {

        Write-Verbose "Telegraf executable exists"
        
        [string] $currHash = (Get-FileHash -Path "$env:ProgramFiles\Telegraf\telegraf.exe" -Algorithm MD5).Hash
        
        if ($currHash -eq $ExecutableMD5Hash) {
            Write-Verbose "Telegraf executable MD5 hash matches the requested one"
            return $true
        }
        else {
            Write-Verbose "Telegraf executable MD5 hash does not match the requested one"
            return $false
        }
    }
    else {
        Write-Verbose "Telegraf executable does not exist"
        return $false
    }
}


function Test-FileContent {
    <#
        This finction checks if requested filename exists under the
        "$env:ProgramFiles\Telegraf\ folder and if file content matches
        to what is provided in Data parameter. File is expected to be in
        text format (config files, scripts, etc).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FileName,

        [Parameter(Mandatory = $true)]
        [string]
        $Data
    )

    $ErrorActionPreference = "Stop"

    Write-Verbose "Testing contents of [$FileName]"
    if (Test-Path -Path "$env:ProgramFiles\Telegraf\$FileName" -PathType Leaf) {

        Write-Verbose "File exists"

        [string] $existingData = Get-Content -Raw -Path "$env:ProgramFiles\Telegraf\$FileName"

        if ($existingData -eq $Data) {
            Write-Verbose "File content matches to what is defined in DSC configuration"
            return $true
        }
        else {
            Write-Verbose "File content does not match to what is defined in DSC configuration"
            return $false
        }
    }
    else {
        Write-Verbose "File does not exist"
        return $false
    }
}


function Test-TelegrafServiceExists {
    <#
        This function checks if Windows Service named 'telegraf' exists
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $ErrorActionPreference = "Stop"

    if (Get-Service -Name "telegraf" -ErrorAction SilentlyContinue) {
        Write-Verbose "Windows Service named [telegraf] exists"
        return $true
    }
    else {
        Write-Verbose "Windows Service named [telegraf] does not exist"
        return $false
    }
}


function Test-TelegrafServiceConfig {
    <#
        This function checks if Telegraf Service uses 'telegraf.conf'
        configuration file, or some other custom config
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    $ErrorActionPreference = "Stop"

    [string] $expectedStr = ("$env:ProgramFiles\Telegraf\telegraf.conf").ToLower()

    $pathName = (Get-WmiObject -Query "SELECT * from win32_service WHERE name like 'telegraf'").PathName
    $pathName = $pathName.ToLower()

    if ($pathName.Contains($expectedStr)) {
        Write-Verbose "Service is correctly configured to use 'telegraf.conf'"
        return $true
    }
    else {
        Write-Verbose "Service is configured to use some custom configuration file"
        return $false
    }
}


function Remove-TelegrafService {
    <#
        This function removes Telegraf Windows Service
    #>

    Write-Verbose "Attempting to stop [telegraf] service"
    Stop-Service -Name telegraf -Force
            
    if (Test-Path -Path "$env:ProgramFiles\Telegraf\telegraf.exe" -PathType Leaf) {
        Write-Verbose "Gracefully uninstalling [telegraf] service"
        & "$env:ProgramFiles\Telegraf\telegraf.exe" "-service" "uninstall"
    }
    else {
        Write-Verbose "Removing [telegraf] service hard way"
        & sc.exe "delete" "telegraf"
        Remove-Item -Path "HKLM:SYSTEM\CurrentControlSet\Services\EventLog\Application\telegraf" -Force
    }
}


function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Yes")]
        [string]
        $IsSingleInstance,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [string]
        $Ensure,

        [string]
        $ExecutableURL,

        [string]
        $ExecutableMD5Hash,

        [string]
        $ConfigData,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $AdditionalFiles
    )

    <#
        function is not yet implemented
    #>

    <#
    Example of reporting hashtable property
    taken from https://powershell.org/forums/topic/hashtable-as-resource-parameter/ 

    return @{
            AdditionalFiles = New-CimInstance -ClassName MSFT_KeyValuePair -Namespace root/microsoft/Windows/DesiredStateConfiguration -Property @{
                Key = 'Some key'
                Value = 'Some value'
            } -ClientOnly
        }
    #>

    return @{}
}


function Set-TargetResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Yes")]
        [string]
        $IsSingleInstance,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [string]
        $Ensure,

        [string]
        $ExecutableURL,

        [string]
        $ExecutableMD5Hash,

        [string]
        $ConfigData,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $AdditionalFiles
    )

    $ErrorActionPreference = "Stop"

    if ($Ensure -eq "Present") {

        # Validate parameters required when Ensure = Present
        if ($ExecutableURL -eq "") {
            throw "ExecutableURL parameter cannot be empty"
        }

        if ($ExecutableMD5Hash -eq "") {
            throw "ExecutableMD5Hash parameter cannot be empty"
        }

        if ($ConfigData -eq "") {
            throw "ConfigData parameter cannot be empty"
        }

        <#
            Installing telegraf, which includes:
             - Telegraf executable
             - Telegraf config
             - Telegraf Windows service
             - Service has to use correct configuration file
             - Testing each element independently is required because only elements that aren't conform
               to required state should be installed/replaced
        #>

        # Before any change is made, if service exists and is running, it has to be stopped
        if ((Test-TelegrafServiceExists) -eq $true) {
            [string] $svcStatus = (Get-Service -Name "telegraf").Status

            if ($svcStatus -ne "Stopped") {
                Write-Verbose "Stopping [telegraf] Windows Service before making any changes"
                Stop-Service -Name "telegraf" -Force
            }
        }

        # Telegraf folder should exist
        if ((Test-Path -Path "$env:ProgramFiles\Telegraf" -PathType Container) -eq $false) {
            Write-Verbose "Creating $env:ProgramFiles\Telegraf folder"
            New-Item -Path "$env:ProgramFiles\Telegraf" -ItemType Directory
        }

        # Telegraf executable should exist and have correct MD5 hash
        if ((Test-TelegrafExecutable -ExecutableMD5Hash $ExecutableMD5Hash) -eq $false) {
            Remove-Item -Path "$env:ProgramFiles\Telegraf\telegraf.exe" -Force -ErrorAction SilentlyContinue

            Write-Verbose "Downloading fresh [telegraf.exe] from $ExecutableURL"

            $currProgressPreference = $ProgressPreference
            # Disable progress bar for Invoke-WebRequest to greatly speed up download speed
            $ProgressPreference = "SilentlyContinue"
            try {
                Invoke-WebRequest -Uri $ExecutableURL -OutFile "$env:ProgramFiles\telegraf\telegraf.exe" -UseBasicParsing
            }
            catch {
                throw $ExecutableURL + "`n" + $_.ToString()
            }
            # Restore $ProgressPreference
            $ProgressPreference = $currProgressPreference

            [string] $freshFileHash = (Get-FileHash -Path "$env:ProgramFiles\telegraf\telegraf.exe" -Algorithm MD5).Hash
            if ($freshFileHash -ne $ExecutableMD5Hash) {
                [string] $text = "New telegraf executable has been downloaded from [$ExecutableURL], but its MD5 hash "
                $text += "does not match to what is specified in [ExecutableMD5Hash] Configuration parameter. "
                $text += "Such configuration inconsistense will lead to executable being constantly removed and "
                $text += "redownloaded. Please report this issue to Infrastructure department to fix DSC Configuration"
                throw $text
            }
        }

        # Telegraf config should exist and its contents should match to what is defined in DSC configuration
        if ((Test-FileContent -FileName "telegraf.conf" -Data $ConfigData) -eq $false) {
            Remove-Item -Path "$env:ProgramFiles\Telegraf\telegraf.conf" -Force -ErrorAction SilentlyContinue

            Write-Verbose "Writing new [telegraf.conf]"
            Set-Content -Path "$env:ProgramFiles\Telegraf\telegraf.conf" -Value $ConfigData -NoNewline
        }

        # Telegraf service needs to be registered
        if ((Test-TelegrafServiceExists) -eq $false) {
            Write-Verbose "Registering [telegraf] Windows Service"
            & "$env:ProgramFiles\Telegraf\telegraf.exe" "-service" "install" "-config" "$env:ProgramFiles\Telegraf\telegraf.conf"
        }
        else {
            if ((Test-TelegrafServiceConfig) -eq $false) {
                Remove-TelegrafService

                Write-Verbose "Registering [telegraf] Windows Service"
                & "$env:ProgramFiles\Telegraf\telegraf.exe" "-service" "install" "-config" "$env:ProgramFiles\Telegraf\telegraf.conf"
            }
        }

        [string[]] $monitoredFiles = @("telegraf.exe", "telegraf.conf")

        # If Additional files are configured, they should exist and their contents should match to what is defined in DSC configuration
        if ($AdditionalFiles) {
            foreach ($file in $AdditionalFiles) {
                if ((Test-FileContent -FileName $file.Key -Data $file.Value) -eq $false) {
                    Remove-Item -Path "$env:ProgramFiles\Telegraf\$($file.Key)" -Force -ErrorAction SilentlyContinue

                    Write-Verbose "Writing new [$($file.Key)]"
                    Set-Content -Path "$env:ProgramFiles\Telegraf\$($file.Key)" -Value $file.Value -NoNewline
                }

                $monitoredFiles += $file.Key
            }
        }

        # All files/folders aren't covered by configuration should be removed
        Write-Verbose "Monitored files: $($monitoredFiles -join ', ')"

        $existingItems = (Get-ChildItem -Path "$env:ProgramFiles\Telegraf").Name
        foreach ($item in $existingItems) {
            if ($item -notin $monitoredFiles) {
                Write-Verbose "Removing [$item]"
                Remove-Item -Path "$env:ProgramFiles\Telegraf\$item" -Force -Recurse
            }
        }

        # Service is started regardless of it's initial status. Debatable, but for now I feel like it is better approach
        Write-Verbose "Starting [telegraf] Windows Service"
        Start-Service -Name "telegraf"
    }
    else {
        <#
            Removing telegraf, which includes:
             - remove service
             - remove Telegraf folder from $env:ProgramFiles
        #>

        if ((Test-TelegrafServiceExists) -eq $true) {
            Remove-TelegrafService
        }

        if (Test-Path "$env:ProgramFiles\Telegraf" -PathType Container) {
            Write-Verbose "Removing [$env:ProgramFiles\Telegraf] folder"
            Remove-Item -Path "$env:ProgramFiles\Telegraf" -Force -Recurse
        }
    }
}


function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Yes")]
        [string]
        $IsSingleInstance,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [string]
        $Ensure,

        [string]
        $ExecutableURL,

        [string]
        $ExecutableMD5Hash,

        [string]
        $ConfigData,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $AdditionalFiles
    )

    $ErrorActionPreference = "Stop"

    if ($Ensure -eq "Present") {

        # Validate parameters required when Ensure = Present
        if ($ExecutableMD5Hash -eq "") {
            throw "ExecutableMD5Hash parameter cannot be empty"
        }

        if ($ConfigData -eq "") {
            throw "ConfigData parameter cannot be empty"
        }

        <#
            Testing for Telegraf Presense
            Definition of Presense:
             - Telegraf executable exists under $env:ProgramFiles\Telegraf
             - Executable MD5 hash equals the one specified in SourceMD5Hash parameter
             - Telegraf config exists under $env:ProgramFiles\Telegraf
             - Telegraf config contents matches to what is defined in DSC configuration
             - Windows Service exists
             - Windows Service uses 'telegraf.conf' alongside 'telegraf.exe'
             - Additional files listed in AdditionalFiles parameter keys exists
             - Additional files contents matches to what is provided in AdditionalFiles parameter values
             - No other files/folders except telegraf.exe, telegraf.conf and AdditionalFiles exists
        #>

        if ((Test-TelegrafExecutable -ExecutableMD5Hash $ExecutableMD5Hash) -eq $false) {
            return $false
        }

        if ((Test-FileContent -FileName "telegraf.conf" -Data $ConfigData) -eq $false) {
            return $false
        }

        if ((Test-TelegrafServiceExists) -eq $false) {
            return $false
        }

        if ((Test-TelegrafServiceConfig) -eq $false) {
            return $false
        }

        [string[]] $monitoredFiles = @("telegraf.exe", "telegraf.conf")

        if ($AdditionalFiles) {
            # Testing additional files contents
            foreach ($file in $AdditionalFiles) {
                if ((Test-FileContent -FileName $file.Key -Data $file.Value) -eq $false) {
                    return $false
                }

                # Adding to monitored files list
                $monitoredFiles += $file.Key
            }
        }

        Write-Verbose "Monitored files: $($monitoredFiles -join ', ')"

        $existingItems = (Get-ChildItem -Path "$env:ProgramFiles\Telegraf").Name
        foreach ($item in $existingItems) {
            if ($item -notin $monitoredFiles) {
                Write-Verbose "[$item] is not part of the Telegraf configuration"
                return $false
            }
        }

        return $true
    }
    else {
        <#
            Testing for Telegraf Absense
            Definition of Absense:
                - Windows Service does not exist
                - Telegraf folder under $env:ProgramFiles does not exist
        #>

        if ((Test-TelegrafServiceExists) -eq $true) {
            return $false
        }
        
        if (Test-Path "$env:ProgramFiles\Telegraf" -PathType Container) {
            Write-Verbose "[$env:ProgramFiles\Telegraf] folder exists"
            return $false
        }
        else {
            Write-Verbose "[$env:ProgramFiles\Telegraf] folder does not exist"
        }

        return $true
    }
}

Export-ModuleMember -Function *-TargetResource