<#
.SYNOPSIS
    Remove built-in apps (modern apps) from Windows 11 for All Users.
.DESCRIPTION
    This script will remove all built-in apps with a provisioning package that are specified in the 'blacklistedapps' variable.
    The Black list is hosted in Azure Blob storage so it can be dynamically updated

    ##WARNING## 
    Use with caution, restoring deleted proisioning packages is not a simple process.

    ##TIP##
    If removing "MicrosoftTeams", also consider disabling the "Chat" icon on the taskbar as clicking this will re-install the appxpackage for the user.

    .EXAMPLE
    .\Remove-Appx-AllUsers.ps1
.NOTES

    Based on original script / Credit to: Nickolaj Andersen @ MSEndpointMgr
    Modifications to original script to Black list Appx instead of Whitelist

    FileName:    Remove-Appx-AllUsers.ps1
    Author:      Ben Whitmore
    Contact:     @byteben
    Date:        23rd May 2022

###### Windows 11 Apps######

Microsoft.549981C3F5F10 (Cortana Search)
Microsoft.BingNews
Microsoft.BingWeather
Microsoft.DesktopAppInstaller
Microsoft.GamingApp
Microsoft.GetHelp
Microsoft.Getstarted
Microsoft.HEIFImageExtension
Microsoft.MicrosoftEdge.Stable
Microsoft.MicrosoftOfficeHub
Microsoft.MicrosoftSolitaireCollection
Microsoft.MicrosoftStickyNotes
Microsoft.Paint
Microsoft.People
Microsoft.PowerAutomateDesktop
Microsoft.ScreenSketch
Microsoft.SecHealthUI
Microsoft.StorePurchaseApp
Microsoft.Todos
Microsoft.UI.Xaml.2.4
Microsoft.VCLibs.140.00
Microsoft.VP9VideoExtensions
Microsoft.WebMediaExtensions
Microsoft.WebpImageExtension
Microsoft.Windows.Photos
Microsoft.WindowsAlarms
Microsoft.WindowsCalculator
Microsoft.WindowsCamera
microsoft.windowscommunicationsapps
Microsoft.WindowsFeedbackHub
Microsoft.WindowsMaps
Microsoft.WindowsNotepad
Microsoft.WindowsSoundRecorder
Microsoft.WindowsStore
Microsoft.WindowsTerminal
Microsoft.Xbox.TCUI
Microsoft.XboxGameOverlay
Microsoft.XboxGamingOverlay
Microsoft.XboxIdentityProvider
Microsoft.XboxSpeechToTextOverlay
Microsoft.YourPhone
Microsoft.ZuneMusic
Microsoft.ZuneVideo
MicrosoftTeams
MicrosoftWindows.Client.WebExperience
#>

Begin {

    # Black List of Appx Provisioned Packages to Remove for All Users
    $BlackListedAppsURL = "https://raw.githubusercontent.com/byteben/Windows-11/main/BuiltInApps/blacklist.xml"

    Try {
        [xml]$BlackListedAppsXML = (New-Object System.Net.WebClient).DownloadString($BlackListedAppsURL)
        $BlackListedApps = $BlackListedAppsXML.xml.app
    } 
    Catch {
        Write-Warning "$($Error[0])"
        Write-Warning "Unable to obtain BlackListedApps from "$($BlackListedAppsURL)""
    }
    
    

    #Static array before using the XML method in Azure storage
    <# $BlackListedApps = New-Object -TypeName System.Collections.ArrayList
    $BlackListedApps.AddRange(@(
            "Microsoft.BingNews",
            "Microsoft.GamingApp",
            "Microsoft.MicrosoftSolitaireCollection",
            "Microsoft.WindowsCommunicationsApps",
            "Microsoft.WindowsFeedbackHub",
            "Microsoft.XboxGameOverlay",
            "Microsoft.XboxGamingOverlay",
            "Microsoft.XboxIdentityProvider",
            "Microsoft.XboxSpeechToTextOverlay",
            "Microsoft.YourPhone",
            "Microsoft.ZuneMusic",
            "Microsoft.ZuneVideo",
            "MicrosoftTeams"
        ))
        #>

    #Define Icons
    $CheckIcon = @{
        Object          = [Char]8730
        ForegroundColor = 'Green'
        NoNewLine       = $true
    }

    #Define App Count
    [int]$AppCount = 0

    #Function to Remove AppxProvisionedPackage
    Function Remove-AppxProvisionedPackageCustom {

        # Attempt to remove AppxProvisioningPackage
        if (!([string]::IsNullOrEmpty($BlackListedApp))) {
            try {
            
                # Get Package Name
                $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $BlackListedApp } | Select-Object -ExpandProperty PackageName -First 1
                Write-Host "$($BlackListedApp) found. Attempting removal ... " -NoNewline

                # Attempt removeal
                $RemoveAppx = Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -AllUsers
                
                #Re-check existence
                $AppProvisioningPackageNameReCheck = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $BlackListedApp } | Select-Object -ExpandProperty PackageName -First 1

                If ([string]::IsNullOrEmpty($AppProvisioningPackageNameReCheck) -and ($RemoveAppx.Online -eq $true)) {
                    Write-Host @CheckIcon
                    Write-Host " (Removed)"
                }
            }
            catch [System.Exception] {
                Write-Host " (Failed)"
            }
        }
    }

    #OS Check
    $OS = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    Switch -Wildcard ( $OS ) {
        '21*' {
            $OSVer = "Windows 10"
            Write-Warning "This script is intended for use on Windows 11 devices. $($OSVer) was detected..."
            Exit 1
        }
    }
}

Process {

    If ($($BlackListedApps.Count) -ne 0) {

        Write-Output `n"The following $($BlackListedApps.Count) apps were targeted for removal from the device:-"
        Write-Output ""
        $BlackListedApps

        #Initialize list for apps not targeted
        $AppNotTargetedList = New-Object -TypeName System.Collections.ArrayList

        # Get Appx Provisioned Packages
        Write-Output `n"Gathering installed Appx Provisioned Packages..."
        Write-Output ""
        $AppArray = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

        # Loop through each Provisioned Package
        foreach ($BlackListedApp in $BlackListedApps) {

            # Function call to Remove Appx Provisioned Packages defined in the Black List
            if (($BlackListedApp -in $AppArray)) {
                $AppCount ++
                Remove-AppxProvisionedPackageCustom -BlackListedApp $BlackListedApp
            }
            else {
                $AppNotTargetedList.AddRange(@($BlackListedApp))
            }
        }

        #Update Output Information
        If (!([string]::IsNullOrEmpty($AppNotTargetedList))) { 
            Write-Output `n"The following apps were not removed. Either they were already moved or the Package Name is invalid:-"
            Write-Output ""
            $AppNotTargetedList
        }
        If ($AppCount -eq 0) {
            Write-Output `n"No apps were removed. Most likely reason is they had been removed previously."
        }
    }
    else {
        Write-Output "No Black List Apps defined in array"
    }
}