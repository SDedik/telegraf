<#
    Configuration example1 shows how telegraf can be completely removed from the system
#>
configuration example1 {

    Import-DscResource -ModuleName Telegraf

    node localhost {
        Telegraf removeTelegraf {
            IsSingleInstance = 'Yes'
            Ensure = 'Absent'
        }
    }
}


<#
    Configuration example2 shows how telegraf can be installed with required configuration file
#>
configuration example2 {

    Import-DscResource -ModuleName Telegraf

    node localhost {
        Telegraf installTelegraf {
            IsSingleInstance = 'Yes'
            Ensure = 'Present'
            ExecutableURL = 'http://common-data.imagemaster.local/data/telegraf/telegraf_1.11.2.exe'
            ExecutableMD5Hash = 'B595C7F8177993440A3C99DF14004D18'
            ConfigData = (Get-Content -Raw -Path "$PSScriptRoot\roleFiles\telegraf\default.config")
        }
    }
}

<#
    Configuration example3 shows how telegraf can be installed with the set of additional scripts
    It is expected that provided configuration file already references those scripts and telegraf
    knows what to do with them. Sample scenario - telegraf is configured to launch custom script
    to gather additional metrics not covered by standard plugins.
#>
configuration example3 {

    Import-DscResource -ModuleName Telegraf

    node localhost {
        Telegraf installCustomizedTelegraf {
            IsSingleInstance = 'Yes'
            Ensure = 'Present'
            ExecutableURL = 'http://common-data.imagemaster.local/data/telegraf/telegraf_1.11.2.exe'
            ExecutableMD5Hash = 'B595C7F8177993440A3C99DF14004D18'
            ConfigData = (Get-Content -Raw -Path "$PSScriptRoot\roleFiles\telegraf\perf_msxCoordinator.config")
            AdditionalFiles = @{
                'exchangemetrics.ps1' = (Get-Content -Raw -Path "$PSScriptRoot\roleFiles\telegraf\exchangemetrics.ps1")
                'perf_msx_monitor_ima_rest.ps1' = (Get-Content -Raw -Path "$PSScriptRoot\roleFiles\telegraf\perf_msx_monitor_ima_rest.ps1")
            }
        }
    }
}