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
$full_file_name = $location.path+$directory_separator+"AppServerAgent-4.5.16.28759.zip"

$agent_downloaded = Test-Path $full_file_name

if ($agent_downloaded -ne "TRUE"){
    Write-Output "Downloading Java agent..."
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("https://download-files.appdynamics.com/download-file/sun-jvm/4.5.16.28759/AppServerAgent-4.5.16.28759.zip",$location.path+$directory_separator+"AppServerAgent-4.5.16.28759.zip")
        $full_path=$location.path
        $full_path=$full_path+$directory_separator+"AppServerAgent-4.5.16.28759.zip"
        $hash_info = Get-FileHash $full_path -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing hashes..."
        if ($hash -eq "1dd6a145a0233e22999dc51ea3b923786033dd9467dd71a42e1e8228f55542bb"){
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

$full_file_name = $location.path+$directory_separator+"machineagent-bundle-64bit-linux-4.5.16.2357.zip"
$agent_downloaded = Test-Path $full_file_name

if ($agent_downloaded -ne "TRUE"){
    Write-Output "Downloading Machine agent..."
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("https://download-files.appdynamics.com/download-file/machine-bundle/4.5.16.2357/machineagent-bundle-64bit-linux-4.5.16.2357.zip",$location.path+$directory_separator+"machineagent-bundle-64bit-linux-4.5.16.2357.zip")
        $full_path=$location.path
        $full_path=$full_path+$directory_separator+"machineagent-bundle-64bit-linux-4.5.16.2357.zip"
        $hash_info = Get-FileHash $full_path -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing hashes..."
        if ($hash -eq "a447e8bc176358c16a453b90768bb2d40cfb868f43a92fdbd4180602b4cee3ce"){
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

$full_file_name = $location.path+$directory_separator+"appd-netviz-x64-linux-4.5.10.2050.zip"
$agent_downloaded = Test-Path $full_file_name

if ($agent_downloaded -ne "TRUE"){
    Write-Output "Downloading Network agent..."
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("https://download-files.appdynamics.com/download-file/netviz-linux/4.5.10.2050/appd-netviz-x64-linux-4.5.10.2050.zip",$location.path+$directory_separator+"appd-netviz-x64-linux-4.5.10.2050.zip")
        $full_path=$location.path
        $full_path=$full_path+$directory_separator+"appd-netviz-x64-linux-4.5.10.2050.zip"
        $hash_info = Get-FileHash $full_path -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing hashes..."
        if ($hash -eq "982e26ff18def73952f2b9f6276e3855b85bd09efe1c66dad67e2a13faf8d579"){
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

$java_agent_path=$location.path+$directory_separator+"AppServerAgent-4.5.16.28759.zip"
$machine_agent_path=$location.path+$directory_separator+"machineagent-bundle-64bit-linux-4.5.16.2357.zip"
$network_agent_path=$location.path+$directory_separator+"appd-netviz-x64-linux-4.5.10.2050.zip"
$destination_path = $location.path+$directory_separator+"agents.zip"

$compress = @{
    LiteralPath = $java_agent_path, $machine_agent_path, $network_agent_path 
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

#$rootPath = "/Users/igor.simoes/Documents/Customers/InternalProjects/agent_installer/agents.zip"
#   $outputPath = "/Users/igor.simoes/Documents/Customers/InternalProjects/agent_installer/teste_igor"
#$streamWriter = [System.IO.StreamWriter]$outputPath
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
Remove-Item $java_agent_path
Remove-Item $machine_agent_path
Remove-Item $network_agent_path
Remove-Item $destination_path
Write-Output "Done."

exit 0

