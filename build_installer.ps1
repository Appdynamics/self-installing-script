param (
    [int]$ProxyEnabled = 0,#0=no proxy,1=user IE, 2=inform proxy adddress manually 
    [string]$ProxyAddress = "",
    [boolean]$RemoveIntermediateFiles = $true,
    [string]$cacertsFile = ""
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
Write-Output "Getting the current directory..."
$location = Get-Location
$directory_separator = $([System.IO.Path]::DirectorySeparatorChar)

function addCacerts([string]$caFile, [string]$agent_file, [string]$version){
    if ($caFile -ne ""){
        $cacerts_exist = Test-Path $cacertsFile
        $agent_archive_exist = Test-Path $agent_file
        if ($cacerts_exist -eq "TRUE" -and $agent_archive_exist -eq "TRUE"){
            $zip = [System.IO.Compression.ZipFile]::Open($agent_file,"Update")
            if ($agent_type -eq "machine"){
                $cacertsEntry = $zip.CreateEntry("conf/cacerts.jks")
            }
            if ($agent_file.Substring(0,3) -eq "App"){                
                $cacertsEntry = $zip.CreateEntry("ver$version/conf/cacerts.jks")
            }
            $streamWriter = [System.IO.StreamWriter]::new($cacertsEntry.Open())
            $streamReader = [System.IO.StreamWriter]::new($caFile)
            $caContents = $streamReader.ReadToEnd()
            $streamWriter.Write($caContents)
            $streamWriter.Flush()
            $streamWriter.Close()
            $streamWriter.Dispose()

            $zip.Dispose()
        }
    }
}

Write-Output "Getting list of recent files..."
$download_base_url = "https://download.appdynamics.com/download/downloadfilelatest/"
$WebClient = New-Object System.Net.WebClient
if ($ProxyEnabled -ne 0){
    $WebClient.Proxy=$proxy
}

$reply = $WebClient.DownloadString($download_base_url) | ConvertFrom-Json;

$i = 0;
while ($reply[$i]) {
    if (($reply[$i].filetype -eq "sun-jvm")) {
        $java_agent_name = $reply[$i].filename
        $java_full_file_name = $location.path+$directory_separator+$java_agent_name
        $java_full_version = $reply[$i].version
        #https://download-files.appdynamics.com/download-file/sun-jvm/
        $java_download_url="https://download-files.appdynamics.com/download-file/sun-jvm/$java_full_version/$java_agent_name"
        $java_hash = $reply[$i].sha256_checksum
        Write-Output "Java hash: $java_hash"
    }

    if (($reply[$i].filetype -eq "machine-bundle") -and ($reply[$i].extension -eq "zip") -and ($reply[$i].bit -eq "64") -and ($reply[$i].os -eq "linux")) {
        $machine_agent_name = $reply[$i].filename
        $machine_full_file_name = $location.path+$directory_separator+$machine_agent_name
        $machine_full_version = $reply[$i].version
        $machine_download_url = "https://download-files.appdynamics.com/download-file/machine-bundle/$machine_full_version/$machine_agent_name"
        $machine_hash = $reply[$i].sha256_checksum
        Write-Output "Machine hash: $machine_hash"
    }

    if (($reply[$i].filetype -eq "netviz-linux") -and ($reply[$i].extension -eq "zip") -and ($reply[$i].bit -eq "64") -and ($reply[$i].os -eq "linux")) {
        $network_agent_name = $reply[$i].filename
        $network_full_file_name = $location.path+$directory_separator+$network_agent_name
        $network_full_version = $reply[$i].version
        $network_download_url = "https://download-files.appdynamics.com/download-file/netviz-linux/$network_full_version/$network_agent_name"
        $network_hash = $reply[$i].sha256_checksum
        Write-Output "Network hash: $network_hash"
    }
    $i++
}

function CheckHashes([string]$inputFile, [string]$AppDhash) {
    $hashes_match = 0
    if (($inputFile -ne "") -and ($AppDhash -ne "")){
        $hash_info = Get-FileHash $inputFile -Algorithm SHA256
        $hash = $hash_info.hash.ToUpper()
        $AppDhash = $AppDhash.ToUpper()

        if ($hash -eq $AppDhash){
            $hashes_match = 1
        } 
        else {
            $hashes_match = 0
        }
    }
    return $hashes_match
}

$download_successful = 0


$agent_downloaded = Test-Path $java_full_file_name
if ($agent_downloaded -eq "TRUE") {
    Write-Output "Java Agent already present, checking hashes."
    Write-Output "Java Agent location: $java_full_file_name"
    $downloaded_hashes_match = CheckHashes -inputFile $java_full_file_name -AppDhash $java_hash
    Write-Output "Hashes match: $downloaded_hashes_match."
}

if ($downloaded_hashes_match -ne 1){
    $download_tries = 0
    Write-Output "Downloading Java agent from $java_download_url"
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("$java_download_url",$java_full_file_name)
        $hash_info = Get-FileHash $java_full_file_name -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing JavaAgent hashes..."
        $hashes_match =  CheckHashes $java_full_file_name $java_hash
        if ($hashes_match = 1){
            $download_successful = 1
            Write-Output "Hashes match. Continuing..."
        } 
        else {
            Write-Output "Hashes don't match, will download again."
            $download_tries++
            if ($download_tries -eq 2){
                Write-Output "Tried downloading 3 times and hashes do not match, please review connection and try again."
                exit 1
            }
        }
    } While ($download_successful –eq 0)
}
else{
    Write-Output "Java agent already present, skiping download and continuing."
}

$download_successful  = 0
$downloaded_hashes_match = 0

$agent_downloaded = Test-Path $machine_full_file_name
if ($agent_downloaded -eq "TRUE") {
    Write-Output "Machine Agent already present, checking hashes."
    Write-Output "Machine Agent location: $machine_full_file_name"
    $downloaded_hashes_match = CheckHashes -inputFile $machine_full_file_name -AppDhash $machine_hash
    Write-Output "Hashes match: $downloaded_hashes_match."
}

if ($downloaded_hashes_match -ne 1){
    $download_tries = 0
    Write-Output "Downloading Machine agent from $machine_download_url"
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("$machine_download_url",$machine_full_file_name)
        $hash_info = Get-FileHash $machine_full_file_name -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing MachineAgent hashes..."
        $hashes_match =  CheckHashes $machine_full_file_name $machine_hash
        if ($hashes_match = 1){
            $download_successful = 1
            Write-Output "Hashes match. Continuing..."
        }
        else {
            Write-Output "Hashes don't match, will download again."
            $download_tries++
            if ($download_tries -eq 2){
                Write-Output "Tried downloading 3 times and hashes do not match, please review connection and try again."
                exit 1
            }
        } 
    } While ($download_successful –eq 0)
}
else{
    Write-Output "Machine agent already present, skiping download and continuing."
}
$download_successful = 0
$downloaded_hashes_match = 0

$agent_downloaded = Test-Path $network_full_file_name
if ($agent_downloaded -eq "TRUE") {
    Write-Output "Network Agent already present, checking hashes."
    Write-Output "Network Agent location: $network_full_file_name"
    $downloaded_hashes_match =  CheckHashes -inputFile $network_full_file_name -AppDhash $network_hash
    Write-Output "Hashes match: $downloaded_hashes_match."
}

if ($downloaded_hashes_match -ne 1){
    $download_tries = 0
    Write-Output "Downloading Network agent $network_download_url"
    Do{
        $WebClient = New-Object System.Net.WebClient
        if ($ProxyEnabled -ne 0){
            $WebClient.Proxy=$proxy
        }
        $WebClient.DownloadFile("$network_download_url",$network_full_file_name)
        $hash_info = Get-FileHash $network_full_file_name -Algorithm SHA256
        $hash = $hash_info.hash
        Write-Output "Comparing NetworkAgent hashes..."
        $hashes_match =  CheckHashes $machine_full_file_name $machine_hash
        if ($hashes_match = 1){
            $download_successful = 1
        }
        else {
            Write-Output "Hashes don't match, will download again."
            $download_tries++
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

if ($cacertsFile -ne ""){
    Write-Output "Generating archive with the cacerts file."
    Write-Output "Renaming cert file from $cacertsFile to ./cacerts.jks."
    Move-Item -Path $cacertsFile -Destination "./cacerts.jks" -Force
    $compress = @{
        LiteralPath = $java_full_file_name, $machine_full_file_name, $network_full_file_name, "./cacerts.jks"
        CompressionLevel = "Fastest"
        DestinationPath = $destination_path
    }
}
else{
    Write-Output "Generating archive with NO cacerts file."
    $compress = @{
        LiteralPath = $java_full_file_name, $machine_full_file_name, $network_full_file_name
        CompressionLevel = "Fastest"
        DestinationPath = $destination_path
    }
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
$script_template_path=$location.path+$directory_separator+"script_template.sh"
$streamWriter.Write([System.IO.File]::ReadAllText($script_template_path))
$streamWriter.Close()
$streamWriter.Dispose()

Write-Output "Writing agent installers.."
$fsStream = New-Object IO.FileStream $final_script_path,6
$binWriter = New-Object System.IO.BinaryWriter $fsStream
$binWriter.Write([System.IO.File]::ReadAllBytes($destination_path))
$binWriter.Close()
$binWriter.Dispose()

if ($RemoveIntermediateFiles -eq $true){
    Write-Output "Removing temp items..."
    Remove-Item $java_full_file_name
    Remove-Item $machine_full_file_name
    Remove-Item $network_full_file_name
    Remove-Item $destination_path
    Write-Output "Done."
}
else{
    Write-Output "Intermediate files not removed..."
}

exit 0

