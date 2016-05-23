function match_platform($ParametersPassed)
    {
        if($hide_beta_platforms -like "Yes")
            {
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "Beta Platforms are NOT AVAILABLE for script opperations at this time due to administrative settings`a"
                if($hide_disabled_platforms -like "Yes")
                    {
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "Disabled Platforms are NOT AVAILABLE for script opperations at this time due to administrative settings`a`n"
                        $usable_platforms = $platforms | Where-Object {($_.platform_status -like "Active")}
                    }
                elseif($hide_disabled_platforms -like "No")
                    {
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "Disabled Platforms are AVAILABLE for script opperations`a`n"
                        $usable_platforms = $platforms | Where-Object {($_.platform_status -like "Active") -or ($_.platform_status -like "Disabled")}
                    }
            }
        elseif($hide_beta_platforms -like "No")
            {
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "Beta Platforms are AVAILABLE for script opperations`a"
                    if($hide_disabled_platforms -like "Yes")
                        {
                            Write-Host -ForegroundColor Magenta -BackgroundColor Black "Disabled Platforms are NOT AVAILABLE for script opperations at this time due to administrative settings`a`n"
                            $usable_platforms = $platforms | Where-Object {($_.platform_status -like "Active") -or ($_.platform_status -like "Beta")}
                        }
                    elseif($hide_disabled_platforms -like "No")
                        {
                            Write-Host -ForegroundColor Magenta -BackgroundColor Black "Disabled Platforms are AVAILABLE for script opperations`a`n"
                            $usable_platforms = $platforms | Where-Object {($_.platform_status -like "Active") -or ($_.platform_status -like "Beta") -or ($_.platform_status -like "Disabled")}
                        }
            }
        $script:current_platform = $null #Initial variable setting to null value to prevent improper id matching.
        foreach($valid_platform in $usable_platforms)
            {
                if($platform -like $($valid_platform.platform_id))
                    {
                        $script:current_platform = $valid_platform
                        break
                    }
            }

        if($current_platform -ne $null)
            {
                Write-Host -ForegroundColor Green "Match found! The specified platform ID matches a usable platform in the database."
                Write-Host -ForegroundColor Green "OS Specified: $($current_platform.platform_name)`n"
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Checking Available Architectures for Specified Platform...`n"
                Start-Sleep 2
                if($current_platform.$architecture -like "Yes")
                    {
                        Write-Host -ForegroundColor Green "Match found! The specified architecture is available for the selected platform."
                        Write-Host -ForegroundColor Green "Platform and Architecture Specified: $($current_platform.platform_name) $architecture`n"
                        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Checking System Compatibility with specified platform and architecture...`n"
                        Start-Sleep 2

                        $system_targets_filepath = "$platform_targets_folder\$($current_platform.platform_id)\"+(Get-Variable "${architecture}_target_list_filename" -ValueOnly)
                        $supported_targets = (Import-CSV $system_targets_filepath)
                        $system_model_information=Get-WmiObject win32_computersystem model | select -Expand Model #sets the "raw" model name to the value returned by the WMI query

                        foreach ($target In $supported_targets) #loops through each element of supported targets for driver matching (terminates at end of array)
                            {
                                if($system_model_information -like "*$($target.target_id)*") #if the "raw" model number matched a supported desktop target
                                    {
                                        $script:systemmodel=$target #sets the model to the matching target
                                        break
                                    }
                            }

                        if($systemmodel -ne $null)
                            {
                                Write-Host -ForegroundColor Green "Success! A match for the model was found in the Driver Database"
                                Write-Host -ForegroundColor Green "Full System Model      : $system_model_information"
                                Write-Host -ForegroundColor Green "System Model Identifier: $($systemmodel.target_id)"
                                Write-Host -ForegroundColor Green "Identified System Type : $($systemmodel.system_type)"
                                Write-Host -ForegroundColor Green "OS to be Deployed      :" $current_platform.platform_name $architecture "`n"
                            }
                        else
                            {
                                if($ParametersPassed.ContainsKey('checkOnly'))
                                    {
                                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "The proposed configuration is not a currently supported OEM/Manufactured target. Add an OEM target for the deployment scenario displayed below and try again`a"
                                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "If the system is in the Custom-Built targets list, this message may be ignored`n"
                                        Write-Host "Deployment Scenario:"
                                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "Full System Model: $system_model_information"
                                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "OS to be Deployed:" $current_platform.platform_name $architecture "`n"
                                    }
                                else
                                    {
                                        Write-Warning "This system does not match a currently supported OEM/Manufactured target for the specified platform.`a"
                                        Write-Host -ForegroundColor Yellow -BackgroundColor Black "This system may not be compatible with the selected deployment configuration, `"$($current_platform.platform_name) $architecture`""
                                    }
                                return 999
                            }
                    }
                else
                    {
                        Write-Host -ForegroundColor Red -BackgroundColor Black "ERROR. The specified architecture, `"$architecture`", is not currently available for the selected platform, `"$($current_platform.platform_name)`". Please try a different architecture or platform.`a"
                        Write-Host -ForegroundColor Red -BackgroundColor Black "Fatal Error encounteted, unable to continue.`a"
                        Pop-Location
                        exit
                    }
            }
        else
            {
                Write-Host -ForegroundColor Red -BackgroundColor Black "The specified platform ID $platform, does not match a currently available platform. Please check the platform ID and try again.`a"
                Write-Host -ForegroundColor Red -BackgroundColor Black "If the platform ID you specified corresponds to a Beta or Disabled platform, you will need to check with your administrator to enable access to these platforms."
                Pop-Location
                exit
            }
    }

function match_custom_platform($ParametersPassed)
    {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Loading Custom-Build Target Matching..."
        #Begin Variable Loading
        $custom_system_targets_filepath = "$platform_targets_folder\$($current_platform.platform_id)\"+(Get-Variable "${architecture}_custom_target_list_filename" -ValueOnly)
        $supported_custom_targets = (Import-CSV $custom_system_targets_filepath);
        $system_motherboard_maker = Get-WmiObject win32_baseboard | Select -Expand Manufacturer
        #Grab the manufacturer of Motherboard via WMI
        $system_motherboard_model = Get-WmiObject win32_baseboard | Select -Expand Product
        #Grab motherboard's model information via WMI
        $system_graphics_info = Get-WmiObject win32_videocontroller | Select -Expand Name
        #Grab Video Card info via WMI
        #End Variable Loading
        foreach($custom_platform in $supported_custom_targets)
            {
                
            }

    }

function determine_driver_package($ParametersPassed)
    {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Identifying Driver Package for Identified Target and Platform...`n"
        Start-Sleep 2
        if($($systemmodel.driver_folder_name) -ne $null)
            {
                $script:driver_folder = $systemmodel.driver_folder_name
                Write-Host -ForegroundColor Green "Match Found! The driver folder was successfully determined for the specified model and platform"
                Write-Host -ForegroundColor Green "Driver Folder Name: $driver_folder`n"
            }
        else
            {
                Write-Host -ForegroundColor Red -BackgroundColor Black "ERROR! Unable to find a driver folder for the identified target! Please make sure the identified target is listed in the driver folders list and try again."
                Write-Host -ForegroundColor Red -BackgroundColor Black "Fatal Error encountered, unable to continue."
                Pop-Location
                exit
            } 
    }

function identify_launch_environment($ParametersPassed)
    {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Determining Script Execution Environment...`n"
        Start-Sleep 2
        try
        {
            if(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinPE")
                {
                    $script:production = $false
                    Write-Host "Automation Environment Identified. Determining Type..."
                    if(Test-Path "X:\Program Files\Symantec\Deployment\PECTAgent.exe")
                        {
                            Write-Host "Automation Environment Identified as Symantec Management Platform (Altiris 7.x) Type"
                            Write-Host "Setting SMP Variables...`n"
                            if($current_platform."${architecture}_SMP_Pkg" -like "No")
                                {
                                    Throw [System.NullReferenceException]
                                }
                            elseif(($current_platform."${architecture}_SMP_Pkg_GUID" -eq $null) -or ($current_platform."${architecture}_SMP_Pkg_GUID" -eq ""))
                                {
                                    Throw [System.IO.FileNotFoundException]
                                }
                            else
                                {
                                    $script:root_path = "$automation_drive_letter\"+(Get-Variable "$current_platform.${architecture}_SMP_Pkg_GUID" -ValueOnly)+"\cache\"
                                    $env:ALTIRIS_SHARE = $null
                                }
                        }
                    elseif($env:ALTIRIS_SHARE -ne $null)
                        {
                            Write-Host "Automation Environment Identified as Altiris Deployment Solution (Altiris 6.9) Type"
                            Write-Host "Setting Altiris DS 6.9 Variables...`n"
                            $script:root_path = "$automation_drive_letter\$DS_Img_Pkg_Root\"+($current_platform | Select -Expand "$($architecture)_DS_IMG_Pkg_Folder")
                        }
                    if(Test-Path $distribution_point_drive_letter)
                        {
                            Write-Host "Distribution Point Connection Detected. Setting Distribution Point Variables..."
                            $script:root_path = "$distribution_point_drive_letter\$DS_Img_Pkg_Root\"+($current_platform | Select -Expand "$($architecture)_DS_IMG_Pkg_Folder")
                        }
                    if($env:BOOTDRIVE -ne $null -and !(Test-Path $automation_drive_letter))
                        {
                            Write-Host "USB Boot Mode Detected. Setting USB Drive Variables..."
                            $script:root_path = "$env:BOOTDRIVE\$DS_Img_Pkg_Root\"+($current_platform | Select -Expand "$($architecture)_DS_IMG_Pkg_Folder")
                        }
                    if($env:NetBoot -ne $null)
                        {
                            Write-Host "Netboot Environment Detected. Setting NetBoot Variables..."
                            $script:root_path = "$automation_drive_letter\$DS_Img_Pkg_Root\"+($current_platform | Select -Expand "$($architecture)_DS_IMG_Pkg_Folder")
                        }
                    if($env:DCNetBoot -ne $null)
                        {
                            Write-Host "DC Netboot Environment Detected. Setting DC Netboot Variables..."
                            $script:root_path = "$automation_drive_letter\"+(Get-Variable "$current_platform.${architecture}_SMP_Pkg_GUID" -ValueOnly)+"\cache\"
                        }
                }
            elseif(!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WinPE") -and (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"))
                {
                    $script:production = $true
                    Write-Warning "You are running this script in a production environment!!"
                    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Driver Injection is not possible in production, only Driver Copying. Manual Action will be required for Injection.`n"  
                }
        }
        catch [System.IO.FileNotFoundException]
            {
                Write-Host -ForegroundColor Red -BackgroundColor Black "Error! The SMP Package GUID for the identified platform is missing!!"
                Write-Host -ForegroundColor Red -BackgroundColor Black "Missing SMP Package GUID, Unable to continue"
                Pop-Location
                exit
            }
        catch [System.NullReferenceException]
            {
                Write-Host -ForegroundColor Red -BackgroundColor Black "Error! The identified platform does not have an SMP Package!!"
                Write-Host -ForegroundColor Red -BackgroundColor Black "Missing SMP Package, Unable to continue"
                Pop-Location
                exit
            }
    }

function identify_deployment_server($ParametersPassed)
    {
        try
            {
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Production Environment Detected. Attempting to contact local Deployment Server...`n"
                Start-Sleep 2
                if($ParametersPassed.ContainsKey('dsname'))
                    {
                        $script:deployment_server = $dsname
                        Write-Host "Deployment Server was Specified as: $dsname`n"
                    }
                else
                    {
                        Write-Warning "Deployment Server not specified on Script Launch. Attempting to identify server from computer name...`n"
                        $site_id = $env:COMPUTERNAME.Substring(0,4)
                        if($site_id -match "\d{4}")
                            {
                                Write-Host "Site ID detected as: $site_id"
                                if($env:COMPUTERNAME -like "*-SVR*")
                                    {
                                        throw [System.Data.ConstraintException] "Server Detected" 
                                    }
                                else
                                    {
                                        $script:deployment_server = $site_id + "-SVR-ADS"
                                        Write-Host "Deployment Server has been Detected as: $deployment_server"
                                    }
                            }
                        else
                            {
                                throw [System.Data.ConstraintException] "Invalid Name Format"
                            }
                    }
            }
        catch [System.Data.ConstraintException]
            {
                Write-Host -ForegroundColor Red -BackgroundColor Black "We were not able to identify the correct Deployment Server"
                Write-Host -ForegroundColor Red -BackgroundColor Black "Try re-running with the -dsname parameter to manually specify it.`n"
                Write-Host -ForegroundColor Red -BackgroundColor Black "More Information:`n"
                Write-Host -ForegroundColor Red -BackgroundColor Black "Error Message: $($_.exception.message) `n"
                Write-Host -ForegroundColor Red -BackgroundColor Black "Error Type: $($_.categoryinfo.category)"
                Pop-Location
                exit
            }
    }

function connect_to_server($ParametersPassed)
    {
        try
            {
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Connecting to Deployment Server...`n"
                Start-Sleep 2
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Checking Connection to $deployment_server...`n"
                Test-Connection $deployment_server -Count 5 -ErrorAction Stop
                Write-Host -ForegroundColor Green "The Server $deployment_server is up and reachable by this system.`n"
                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Connecting to Deployment Share..."
                if($PSVersionTable.PSVersion.Major -lt 2)
                    {
                        Write-Warning "This System is using Powershell 2.x or lower. This may result in some improper script behavior."
                        Write-Host -ForegroundColor Yellow -BackgroundColor Black "For best performance, make sure you are using Powershell 3.x or newer`n"
                        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Using PS 2.x compatible Mode"
                        $server = New-Object -ComObject WScript.Network
                        if([System.IO.Directory]::Exists("$automation_drive_letter"))
                            {
                                Write-Host "Deleting Already in use drive $automation_drive_letter ..."
                                net use $automation_drive_letter /delete /Y
                            }
                        $connection_credentials = Get-Credential
                        $server_path = "\\$deployment_server\$DS_share_name\$DS_IMG_Pkg_Root\" +($current_platform | Select -Expand "$($architecture)_DS_IMG_Pkg_Folder")
                        $server.MapNetworkDrive($automation_drive_letter,$server_path, $false, $connection_credentials.UserName, $connection_credentials.GetNetworkCredential().Password)
                        $script:root_path = "$automation_drive_letter"
                    }
            }
        catch [System.Net.NetworkInformation.PingException]
            {
                Write-Host -ForegroundColor Red -BackgroundColor Black "Unable to Contact $deployment_server. Make sure the system is on and not blocking ICMP Messages."
                Write-Host -ForegroundColor Red -BackgroundColor Black "Unable to proceed, please verify your network connectivity and try again."
                exit
            }
    }

function verify_driver_package($ParametersPassed)
    {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Verifying Driver Package Integrity...`n"
        if($root_path -ne $null)
            {
                try
                {
                    if(Test-Path "$root_path\$drivers_root_folder_name\$driver_folder")
                        {
                            Write-Host -ForegroundColor Green "Verification Successful! The specified Driver folder exists in the correct location"
                            if($ParametersPassed.ContainsKey('checkOnly'))
                                {
                                    Write-Host -ForegroundColor Green "Pre-Check complete! The target is compatible with the selected platform, and the driver folder exists on the server"
                                    Write-Host -ForegroundColor Green "Imaging can Proceed with Driver support. If you would like to perform driver injection, re-run the script without the -checkOnly flag"
                                }
                            #TODO: Generate Folder manifests for each driver folder and write a more thorough checking algorithim
                        }
                    else
                        {
                            Throw [System.IO.FileNotFoundException] "Missing Driver Folder"
                        }
                }
                catch [System.IO.FileNotFoundException]
                    {
                        Write-Host -ForegroundColor Red -BackgroundColor Black "The Driver Folder is missing. Verify that `"$root_path\$drivers_root_folder_name\$driver_folder`" exists on the server and try again.`n"
                        Pop-Location
                        exit 5418   
                    }
            }
    }

function find_drive_target($ParametersPassed)
    {
        try
        {
            Write-Host -ForegroundColor Yellow -BackgroundColor Black "Identifying Drive Target for Driver Injection..."
            if(Test-Path "X:\post_drive_target.txt")
                {
                    $script:drivetarget=(Get-Content X:\post_drive_target.txt)
                    Write-Host "Drive Target has been Identified as $drivetarget"
                }
            elseif(Test-Path "X:\Program Files")
                {
                    Write-Warning "You appear to be running in an automation environment, but we were unable to determine your Production drive target"
                    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Attempting Alternative Drive Target Identification..."
                    [System.Collections.ArrayList]$search_drives = (Get-Content $drive_target_searchlist_file)
                    $search_drives.Remove($automation_drive_letter)
		    $search_drives.Remove($distribution_point_drive_letter)
                    foreach($drive in $search_drives)
                        {
                            if(Test-Path "$drive\Windows\System32\config\SOFTWARE")
                                {
                                    $script:drivetarget = $drive
                                    Write-Host -ForegroundColor Green "Alternate Drive Target Identification Successful!"
                                    Write-Host -ForegroundColor Green "Drive Target Has Been Identified as: $drivetarget"
                                    break
                                }
                        }
                }
            elseif($production -eq $true)
                {
                    Write-Host "Drive Target Identified as C:"
                    Write-Warning "Production Environment Detected. Very bad things could happen!"
                    $script:drivetarget = "C:"
                }
            elseif($drivetarget -eq $null)
                {
                    Throw [System.IO.DriveNotFoundException]
                }
        }
        catch [System.IO.DriveNotFoundException]
            {
                
                Write-Host -ForegroundColor Red -BackgroundColor Black "Unable to Identify Drive Target, cannot proceed."
                Pop-Location
                exit 5420
            }
    }

function copy_driver_package($ParametersPassed)
    {
        Write-Host -ForegroundColor Yellow -BackgroundColor Black "Initiating Driver Copy..."
        Start-Sleep 2
	Write-Host "$root_path\$driver_folder"
        xcopy "$root_path\$drivers_root_folder_name\$driver_folder\*" $drivetarget\Drivers /e /f /c /i /h /y
        Write-Host "Driver Copy Complete!"
        Write-Host "Copy Drivers Script Completed Successfully!"
    }

function list_platforms($ParametersPassed)
    {
        if($ParametersPassed.ContainsKey('showBeta')) #If the showBeta switch was included
            {
                if($ParametersPassed.ContainsKey('showDisabled')) #If the showDisabled switch was ALSO included
                    {
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "Platforms currently marked as ACTIVE, BETA, or DISABLED are listed below`a"
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "To show only platforms marked as ACTIVE, or BETA, re-run the script without the -showDisabled option"
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "To show only platforms marked as ACTIVE, re-run the script without the -showBeta and -showDisabled options`n"
                        $platforms | Where-Object {($_.platform_status -like "Active") -or ($_.platform_status -like "Beta") -or ($_.platform_status -like "Disabled")} | Sort-Object -Property platform_name -Descending | Sort-Object -Property platform_status | Format-Table -Property platform_id,platform_name,x86,x64,x86_SMP_Pkg,x64_SMP_Pkg,x86_DS_IMG_PKG,x64_DS_IMG_PKG,platform_status    
                    }
                else #If the showDisabled flag was NOT included
                    {
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "Platforms currently marked as ACTIVE or BETA are listed below`a"
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "If you would like to view platforms marked as DISABLED, re-run the script with the -showDisabled option."
                        Write-Host -ForegroundColor Magenta -BackgroundColor Black "To show only platforms marked as ACTIVE, re-run the script without the -showBeta option`n"
                        $platforms | Where-Object {($_.platform_status -like "Active") -or ($_.platform_status -like "Beta")} | Sort-Object -Property platform_name -Descending | Sort-Object -Property platform_status | Format-Table -Property platform_id,platform_name,x86,x64,x86_SMP_Pkg,x64_SMP_Pkg,x86_DS_IMG_PKG,x64_DS_IMG_PKG,platform_status
                    }
            }
        elseif($ParametersPassed.ContainsKey('showDisabled')) #If ONLY the showDisabled switch was included
            {
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "Platforms currently marked as ACTIVE or DISABLED are listed below`a"
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "If you would like to view platforms marked as BETA, re-run the script with the -showBeta option."
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "To show only platforms marked as ACTIVE, re-run the script without the -showDisabled option`n"
                $platforms | Where-Object {($_.platform_status -like "Active") -or ($_.platform_status -like "Disabled")} | Sort-Object -Property platform_name -Descending | Sort-Object -Property platform_status | Format-Table -Property platform_id,platform_name,x86,x64,x86_SMP_Pkg,x64_SMP_Pkg,x86_DS_IMG_PKG,x64_DS_IMG_PKG,platform_status
            }
                                
        else
            {
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "Platforms currently marked as ACTIVE are listed below`a"
                Write-Host -ForegroundColor Magenta -BackgroundColor Black "If you would like to view platforms marked as BETA, or DISABLED, re-run the script with the `"-showBeta`" and/or `"-showDisabled`" options, respectively.`n"
                $platforms | Where-Object {($_.platform_status -like "Active")} | Sort-Object -Property platform_name -Descending | Sort-Object -Property platform_status | Format-Table -Property platform_id,platform_name,x86,x64,x86_SMP_Pkg,x64_SMP_Pkg,x86_DS_IMG_PKG,x64_DS_IMG_PKG,platform_status
            }

    }