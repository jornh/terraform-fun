#region Initialize

function Initialize
{
    # Enum for Ensure
    Add-Type -TypeDefinition @"
        public enum EnsureType
        {
            Present,
            Absent
        }
"@ -ErrorAction SilentlyContinue
    
    # Import [System.ServiceProcess.ServiceControllerStatus] and other types.....
    Get-Service > $null
}

. Initialize

#endregion

#region Message Definition

$verboseMessages = Data {
    ConvertFrom-StringData -StringData @"
        KillingConcoleTopShelf = Console TopShelf running detected. Killing....
        StoppedServiceMayBeTopShelf = Stopped Service may be TopShelf Service.
        StoppedServiceMayNotBeTopShelf = Stopped Service may NOT be TopShelf Service.
"@
}

$debugMessages = Data {
    ConvertFrom-StringData -StringData @"
        CheckingServicePathAndParameterPathMatching = Checking Service Path equals parameter Path
        PathFound = Successfully found path '{0}'.
        PathNotExist = Be sure you have download or set target path '{0}' in advance.
        ProcessNotFound = Process not found.
        ProcessPathNotDesired = Process path not detected. ProcessPath '{0}', Path '{1}'.
        ServiceNotExists = Service not exist
"@
}

$errorMessages = Data {
    ConvertFrom-StringData -StringData @"
"@
}

#endregion

#region *-TargetResource

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path,

        [parameter(Mandatory = $true)]
        [System.String]$ServiceName,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure
    )
    
    # validate path is correct.
    ValidatePathExists -Path $Path

    # Check existing is TopShelfService or not
    if (-not (IsServiceExists -Name $ServiceName))
    {
        Write-Debug $debugMessages.ServiceNotExists
        $ensureResult = [EnsureType]::Absent.ToString()
    }
    else
    {
        # service exist. Validate if it is TopShelf Service or not
        if (IsTopShelfServiceValid -Name $ServiceName -Path $Path)
        {
            $ensureResult = [EnsureType]::Present.ToString()
        }
        else
        {
            $ensureResult = [EnsureType]::Absent.ToString()
        }
    }

    $returnValue = @{
        Path = $Path
        ServiceName = $ServiceName
        Ensure = $ensureResult
    }

    return $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path,

        [parameter(Mandatory = $true)]
        [System.String]$ServiceName,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure
    )

    #region Uninstall Service
    if ($Ensure -eq [EnsureType]::Absent.ToString())
    {
        UninstallTopShelfService -Path $Path;
        return;
    }

    #endregion

    #region Install Service

    # Even install process but uninstall is neccesary for in case TopShelf Process path is changed.
    UninstallTopShelfService -Path $Path;

    # Detect TopShelf run as Console
    if ((IsServiceStopped -Name $ServiceName) -and (IsProcessUsing -Path $Path))
    {
        Write-Verbose $verboseMessages.KillingConcoleTopShelf;
        Get-Process -Name $ServiceName | Stop-Process -Force;
    }

    # Install Service
    InstallTopShelfService -Path $Path;
    return;    
    
    #endregion
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path,

        [parameter(Mandatory = $true)]
        [System.String]$ServiceName,

        [parameter(Mandatory = $true)]
        [ValidateSet("Present","Absent")]
        [System.String]$Ensure
    )

    $result = (Get-TargetResource -Path $Path -ServiceName $ServiceName -Ensure $Ensure).Ensure -eq $Ensure
    return $result
}

#endregion

#region TopShlef helper

function InstallTopShelfService
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )
    
    try
    {
        . $path install | Write-Verbose
    }
    catch
    {
        throw $_
    }
}

function UninstallTopShelfService
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )
    
    try
    {
        . $path uninstall | Write-Verbose
    }
    catch
    {
        throw $_
    }
}

#endregion

#region Service helper

function IsServiceExists
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name
    )
    
    # Name or DisplayName checking
    return (Get-Service | where {($_.Name -eq $Name) -or ($_.DisplayName -eq $Name)} | measure).Count -ne 0
}

function GetServiceStatusSafe
{
    [CmdletBinding()]
    [OutputType([System.ServiceProcess.ServiceControllerStatus])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name
    )
    
    # Name or DisplayName checking
    return (Get-Service | where {($_.Name -eq $Name) -or ($_.DisplayName -eq $Name)}).Status
}

function IsServiceRunning
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name
    )
    
    return (GetServiceStatusSafe -Name $Name) -eq [System.ServiceProcess.ServiceControllerStatus]::Running
}

function IsServiceStopped
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name
    )
    
    return (GetServiceStatusSafe -Name $Name) -eq [System.ServiceProcess.ServiceControllerStatus]::Stopped
}

function IsTopShelfServiceValid
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name,

        [parameter(Mandatory = $true)]
        [System.String]$Path
    )
    
    # make sure : this function NOT expecting to pass invalid service. Be sure to filter invalid input in-advance.

    # Check Service Path is valid
    Write-Debug ($debugMessages.CheckingServicePathAndParameterPathMatching);
    if (-not (IsServicePathValid -Name $Name -Path $Path))
    {
        # Service Path != Request Path immediately return false
        return $false;
    }
    return $true;
}

function IsServicePathValid
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Name,

        [parameter(Mandatory = $true)]
        [System.String]$Path
    )

    # Get Service Instance detail
    $service = Get-CimInstance -ClassName Win32_Service | where Name -eq $Name;

    # Service executable Path Check - Pick up exe path. TopShelf Service PathName Format will be : 
    # "xxx.exe"  -displayname "xxx" -servicename "xxx"
    if ($null -ne $service.PathName)
    {
        $servicePath = $service.PathName.Split(" ") | select -First 1;
        return $servicePath.Replace('"',"") -eq $Path;        
    }
    return $false;
}

#endregion

#region Process helper

function IsProcessUsing
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )
    
    # pickup process from executable file name
    $processName = (Get-Item -Path $Path).BaseName
    $processInfo = Get-Process | where Name -eq $processName
    
    # validate Process exist - if service stopped, then process will not shown
    if (($processInfo | measure).Count -eq 0)
    {
        Write-Debug ($debugMessages.ProcessNotFound -f $processName)
        return $false
    }

    # validate service path is as desired
    if (($processInfo).Path -ne $Path)
    {
        Write-Debug ($debugMessages.ProcessPathNotDesired -f $processInfo.Path, $Path)
        return $false
    }

    # Name and Path matches TopShelf execute Path
    return $true
}

#endregion

#region Path helder

function ValidatePathExists
{
    [CmdletBinding()]
    [OutputType([Void])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]$Path
    )
    
    if (-not (Test-Path -Path $Path))
    {
        Write-Debug ($debugMessages.PathNotExist -f $Path)
        throw New-Object System.IO.FileNotFoundException
    }
    Write-Debug ($debugMessages.PathFound -f $Path)
}

#endregion

Export-ModuleMember -Function *-TargetResource
