#Universal Driver Copy Script - Generation 2. Version 2.0.9 Last Revised 03/31/2016 by Benjamin Simon
#TODO: Rewrite error handling to use try{} catch{} blocks, and align error codes with ones used in current HII scripts where possible
#TODO: Generate Folder manifests for each driver package, and create more thorough verification algorithim
#TODO: Automatic Target update script?

#Begin Script Parameter Declaration
[CmdletBinding(DefaultParameterSetName="CopyDrivers")]
    Param 
        (
            [Parameter(Mandatory=$true,ParameterSetName="CopyDrivers")]
            [Parameter(Mandatory=$true,ParameterSetName="CheckOnly")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet('x86','x64','ARM')]
            [string]$architecture,

            [Parameter(Mandatory=$true,ParameterSetName="CheckOnly")]
            [switch]$checkOnly,

            [Parameter(Mandatory=$false,ParameterSetName="CopyDrivers")]
            [Parameter(Mandatory=$false,ParameterSetName="CheckOnly")]
            [ValidateNotNullOrEmpty()]
            [string]$dsname,

            [Parameter(Mandatory=$true,ParameterSetName="ListPlatforms")]
            [switch]$listPlatforms,

            [Parameter(Mandatory=$true,ParameterSetName="CopyDrivers")]
            [Parameter(Mandatory=$true,ParameterSetName="CheckOnly")]
            [ValidateNotNullOrEmpty()]
            [string]$platform,

            [Parameter(Mandatory=$false,ParameterSetName="ListPlatforms")]
            [switch]$showBeta,

            [Parameter(Mandatory=$false,ParameterSetName="ListPlatforms")]
            [switch]$showDisabled,

            [Parameter(Mandatory=$false,ParameterSetName="CheckOnly")]
            [switch]$skipIntegrityCheck
        )

Push-Location $(Split-Path $Script:MyInvocation.MyCommand.Path) #Set the current working directory to where the script is so file references work
#Begin Script Settings Load
try
    {
        $script_settings = Import-Csv ".\script_settings.csv" -ErrorAction Stop #Load CSV Settings File
        
        #Begin Core settings
        $platform_file = $script_settings.platform_filename
        $functions_file = $script_settings.functions_filename
        $help_filename = $script_settings.help_filename
        $DS_share_name = $script_settings.DS_share_name
        $DS_IMG_Pkg_Root = $script_settings.DS_IMG_Pkg_Root
        $platform_targets_folder = $script_settings.platform_targets_folder
        $hide_beta_platforms = $script_settings.hide_beta_platforms
        $hide_disabled_platforms = $script_settings.hide_disabled_platforms
        $automation_drive_letter = $script_settings.automation_drive_letter
        $distribution_point_drive_letter = $script_settings.distribution_point_drive_letter
        $drive_target_searchlist_file = $script_settings.drive_target_searchlist_file
        $organization = $script_settings.organization
        $drivers_root_folder_name = $script_settings.drivers_root_folder_name
        $global_state = $script_settings.global_state
        #End Core Settings

        #Begin 32-bit target file settings
        $x86_target_list_filename = $script_settings.x86_target_list_filename
        $x86_custom_target_list_filename = $script_settings.x86_custom_target_list_filename
        #End 32-bit target file settings

        #Begin 64-bit target file settings
        $x64_target_list_filename = $script_settings.x64_target_list_filename
        $x64_custom_target_list_filename = $script_settings.x64_custom_target_list_filename
        #End 64-bit target file settings

    }
catch
    {
        Write-Host -ForegroundColor Red -BackgroundColor Black "FATAL ERROR. Unable to load settings file, cannot continue"
        Write-Host $_.Exception.Message
        Pop-Location
        exit       
    }
#End Script Settings Load

#Begin Script Functions Load
try
    {
        . ".\$functions_file"
    }
catch
    {
        Write-Host -ForegroundColor Red -BackgroundColor Black "FATAL ERROR. Unable to load script function definitions, cannot continue`n"
        Write-Host -ForegroundColor Red -BackgroundColor Black "More Information:`n"
        Write-Host -ForegroundColor Red -BackgroundColor Black "Error Message:`n $($_.exception.message)`n"
        Write-Host -ForegroundColor Red -BackgroundColor Black "Error Type: $($_.categoryinfo.category)"
        Pop-Location
        exit
    } 

#Begin Help File Load
if (Test-Path $help_filename)
{
#.ExternalHelp $help_filename
}
else
{
    Write-Host -ForegroundColor Yellow -BackgroundColor Black "Warning! The Help File is Missing! Script Help will be unavailable during this run, please check that the file `"$help_filename`" is present in the script location."
}
#End Help File Load

#Begin Platforms List Load
try
    {
        $script:platforms = Import-CSV $platform_file -ErrorAction Stop
        $activeparameters = $PSBoundParameters.GetEnumerator() | Where-Object -FilterScript {$_.Value -eq $true}
        switch($activeparameters.Key)
            {
                'checkOnly'
                    {
                        $match_return = match_platform($PSBoundParameters);
                        if($match_return -Eq 999)
                            {
                                Write-Warning "No match found in OEM/Manufactured Targets. Attempting Component/Custom-Built Target Matching...`n`n"
                                $custom_match_return = match_custom_platform($PSBoundParameters);
                                if($custom_match_return -Ne 0)
                                    {
                                        Write-Warning "This system does not match any supported targets. Continuing without driver support, manual action may be required"
                                        Pop-Location
                                        exit 5417
                                    }
                            }
                        if($PSBoundParameters.ContainsKey('skipIntegrityCheck'))
                            {
                                Write-Host -ForegroundColor Yellow -BackgroundColor Black "Skipping Driver Package Verification..."
                                break;
                            }
                        else
                            {
                                determine_driver_package($PSBoundParameters);
                                identify_launch_environment($PSBoundParameters);
                                if($production -eq $true)
                                    {
                                        identify_deployment_server($PSBoundParameters);
                                        connect_to_server($PSBoundParameters);
                                    }
                                verify_driver_package($PSBoundParameters);
                                break;
                            }
                    }
                'listPlatforms'
                    {
                        list_platforms($PSBoundParameters);
                        break;
                    }
                default
                    {
                        match_platform($PSBoundParameters);
                        determine_driver_package($PSBoundParameters);
                        identify_launch_environment($PSBoundParameters);
                        verify_driver_package($PSBoundParameters);
                        find_drive_target($PSBoundParameters);
                        copy_driver_package($PSBoundParameters);
                        break;
                    }

            }
    }
catch [System.IO.FileNotFoundException]
    {
        Write-Host -ForegroundColor Red -BackgroundColor Black "FATAL ERROR. Unable to load platforms list, cannot continue`a`n"
        Write-Host -ForegroundColor Red -BackgroundColor Black "More Information: `n"
        Write-Host -ForegroundColor Red -BackgroundColor Black "Error Message: `n $($_.exception.message) `n"
        Write-Host -ForegroundColor Red -BackgroundColor Black "Error Type: $($_.categoryinfo.category)"
        Pop-Location
        exit   
    }