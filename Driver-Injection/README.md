Driver Injection Script
-----------------------
This script automatically detects the model information of the computer system and copies the drivers to the system's hard drive, for subsequent injection via DISM.

### Compatible Environments ###
This script was designed to run in one of the following environments:
* Altiris Deployment Solution 6.9 SP6
* Altiris Deployment Solution 7.x (Symantec Management Platform)

### Run Requirements ###
In order for the script to run successfully, the environment must meet the following requirements:
* WinPE 4.0 or higher.
  
  Your WinPE environment should be configured as follows:
    * The following WinPE optional packages need to be installed:
        1.  WinPE-EnhancedStorage
        2.  WinPE-WMI
        3.  WinPE-SecureStartup
        3.  WinPE-NetFx
        4.  WinPE-Scripting
        5.  WinPE-Powershell
        6.  WinPE-DismCmdlets
        7.  WinPE-SecureBootCmdlets
        8.  WinPE-StorageWMI
    * Your WinPE environment should establish a network connection to a deployment share to copy drivers during deployment. The specific drive letter is configurable in the settings file.

### Notes ###
* This script is theoretically compatible with Ghost Solution Suite 3.0 and higher, since its code is derived from the 6.9 series of Deployment Solution. However, testing with this solution has not been conducted.

* This script is also theoretically compatible with other deployment systems using WinPE, including standalone or custom deployment solutions. However, testing with these environments has also not been conducted. If you have used another environment, please send information on how the script performed in this environment.
