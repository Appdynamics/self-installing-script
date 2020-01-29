param (
    [int]$ProxyEnabled = 0,#0=no proxy,1=user IE, 2=inform proxy adddress manually 
    [string]$ProxyAddress = ""
)

if ($ProxyEnabled -ne 0){
    if ($ProxyEnabled -eq 2){
        if($ProxyAddress -eq ""){
            Write-Output "Proxy address not informed. Usage: build_installer.ps1 -ProxyEnabled 2 -ProxyAddress <host>:<port>"
            exit 1
        }
    } 
    else{
        $HKCU_exist = Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        if ($HKCU_exist -eq $true){
            $ProxyAddress=(get-itemproperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyServer
        }
        else{
            Write-Output "Proxy system configuration does not exist. Please make sure you have this on the registry and try again..."
            Write-Output "Aborting..."
            exit 1
        }
    }
    $credentials = Get-Credential
    $proxy = new-object System.Net.WebProxy
    $proxy.Address = $ProxyAddress
    $proxy.BypassProxyOnLocal = $false
    $proxy.BypassList = "" 
    $proxy.Credentials = $credentials
}

Write-Output "Starting to generate script installer..."
Write-Output "Getting the current directory.."
$location = Get-Location
$directory_separator = $([System.IO.Path]::DirectorySeparatorChar)

$download_successful = 0
$download_tries = 0
$full_file_name = $location.path+$directory_separator+"AppServerAgent-4.5.18.29239.zip"

$java_agent_name = "AppServerAgent-4.5.18.29239.zip"
$java_full_file_name = $location.path+$directory_separator+$java_agent_name
$java_full_version = "4.5.18.29239"
$java_download_url = "https://download-files.appdynamics.com/download-file/sun-jvm/"
$java_hash = "00481c89fe2153bc203a38a8cc143b1da1b769255367c75b71d06cb580461cd6"

$machine_agent_name = "machineagent-bundle-64bit-linux-4.5.18.2430.zip"
$machine_full_file_name = $location.path+$directory_separator+$machine_agent_name
$machine_full_version = "4.5.18.2430"
$machine_download_url = "https://download-files.appdynamics.com/download-file/machine-bundle/"
$machine_hash = "fb37a98ffc5274c5f33d10e88727e9a07897a79d6d0b55a67bb8b338a19933ea"

$network_agent_name = "appd-netviz-x64-linux-4.5.11.2100.zip"
$network_full_file_name = $location.path+$directory_separator+$network_agent_name
$network_full_version = "4.5.11.2100"
$network_download_url = "https://download-files.appdynamics.com/download-file/netviz-linux/"
$network_hash = "0e967a554a3b246944a2033ee57901dd4d0ff05a0e9d290020457ada08e71703"

$agent_downloaded = Test-Path $java_full_file_name

if ($agent_downloaded -ne "TRUE"){
    Write-Output "Downloading Java agent from $java_download_url$java_full_version/$java_agent_name"
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("$java_download_url$java_full_version/$java_agent_name",$java_full_file_name)
        $hash_info = Get-FileHash $java_full_file_name -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing hashes..."
        if ($hash -eq $java_hash){
            $download_successful = 1
            Write-Output "Hashes match..."
        } 
        else {
            Write-Output "Hashes don't match, will download again."
            $download_tries = $download_tries + 1
            if ($download_tries -eq 2){
                Write-Output "Tried downloading 3 times and hashes do not match, please review connection and try again."
                exit 1
            }
        }
    } While ($download_successful –eq 0)
}
else{
    Write-Output "Java agent already present, skiping download and continuing.."
}

$download_successful  = 0

$agent_downloaded = Test-Path $machine_full_file_name

if ($agent_downloaded -ne "TRUE"){
    Write-Output "Downloading Machine agent from $machine_download_url$machine_full_version/$machine_agent_name"
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("$machine_download_url$machine_full_version/$machine_agent_name",$machine_full_file_name)
        $hash_info = Get-FileHash $machine_full_file_name -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing hashes..."
        if ($hash -eq $machine_hash){
            $download_successful = 1
            Write-Output "Hashes match..."
        }
        else {
            Write-Output "Hashes don't match, will download again."
            $download_tries = 1
            if ($download_tries -eq 2){
                Write-Output "Tried downloading 3 times and hashes do not match, please review connection and try again."
                exit 1
            }
        } 
    } While ($download_successful –eq 0)
}
else{
    Write-Output "Machine agent already present, skiping download and continuing.."
}
$download_successful = 0

$agent_downloaded = Test-Path $network_full_file_name

if ($agent_downloaded -ne "TRUE"){
    Write-Output "Downloading Network agent $network_download_url$network_full_version/$network_agent_name"
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("$network_download_url$network_full_version/$network_agent_name",$network_full_file_name)
        $hash_info = Get-FileHash $network_full_file_name -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing hashes..."
        if ($hash -eq $network_hash){
            $download_successful = 1
            Write-Output "Hashes match..."
        }
        else {
            Write-Output "Hashes don't match, will download again."
            if ($download_tries -eq 2){
                Write-Output "Tried downloading 3 times and hashes do not match, please review connection and try again."
                exit 1
            }
        } 
    } While ($download_successful –eq 0)
}
else{
    Write-Output "Network agent already present, skiping download and continuing.."
}

$destination_path = $location.path+$directory_separator+"agents.zip"

$compress = @{
    LiteralPath = $java_full_file_name, $machine_full_file_name, $network_full_file_name 
    CompressionLevel = "Fastest"
    DestinationPath = $destination_path
}

Write-Output "Compressing download files..."
$archive_exist = Test-Path $destination_path
if ($archive_exist -eq "TRUE"){
    Remove-Item $destination_path
}
Compress-Archive @compress

$final_script_path = $location.path+$directory_separator+"agent_installer.sh"
$script_exists = Test-Path $final_script_path
if ($script_exists -eq "TRUE"){
    Write-Output "Removing previously generated installer script..."
    Remove-Item $final_script_path      
}

Write-Output "Writing installation commands.."
$streamWriter = [System.IO.StreamWriter]::new($final_script_path)
$script_template_path=$location.path+$directory_separator+"script_template.txt"
$streamWriter.Write([System.IO.File]::ReadAllText($script_template_path))
$streamWriter.Close()
$streamWriter.Dispose()

Write-Output "Writing agent installers.."
$fsStream = New-Object IO.FileStream $final_script_path,6
$binWriter = New-Object System.IO.BinaryWriter $fsStream
$binWriter.Write([System.IO.File]::ReadAllBytes($destination_path))
$binWriter.Close()
$binWriter.Dispose()

Write-Output "Removing temp items..."
Remove-Item $java_full_file_name
Remove-Item $machine_full_file_name
Remove-Item $network_full_file_name
Remove-Item $destination_path
Write-Output "Done."

exit 0

