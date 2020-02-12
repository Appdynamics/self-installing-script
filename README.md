# self-installing-script
This is a self installing script to facilitate installation of agents. Just run the script and it will generate the corresponding directories with the right permissions.

This is basically composed of a powershell script that downloads the agents and generates the installer to be executed on the Linux boxes. Later versions will generate installers to other systems and technologies.

On this current version script works just for Linux, script will only self extract itself, create the right folders under <appdynamics-home> directory and set the right permissions. For network-agent, script will also try to install it using sudo.

Still there is a lot to do, but this is a first version of the script.

## How to use this script

Download the release package and run the powershell script build_installer.ps1. This script will connect to the AppDynamics website, download the agents and generate the agents_installer.sh script.

Transfer this script to the linux boxes and proceed with the installation. This will place all the three agents on the right directories with the right permissions. Just the start of the applications will need to be added manually later so apps can load the agent during initialiation.

## New to this version

Powershell now has 4 parameters that can be used: 

```
-ProxyEnabled
    0=no proxy
    1=use IE configuration
    2=inform proxy adddress manually 
-ProxyAddress
    Full proxy address and port
-DoNotRemoveIntermediateFiles
    This tells for the downloaded installers not to be removed. On next execution powershell will check locally and if installers are present they will not be downloaded again.
-cacertsFile
    Location of the JKS file for use with the agents
````

Bash script now has a lot of new features through parameters

First parameter should be "all", meaning to install the 3 agents: java, machine and network. Other options for this parameter the other options have not been tested and should not be used.

```
-AppDHome
    This now lets you change the installation directory. If this is not set it will default to /opt/appdynamics
-MAContURL
    Sets the controller address for the Machine Agent, this won't change configuration for the Java agent, as these should be configured as parameters
-MAContport
    Sets the controller port for the Machine Agent, this won't change configuration for the Java agent, as these should be configured as parameters
-MAContSSL
    Sets the controller SSL options for the Machine Agent, this won't change configuration for the Java agent, as these should be configured as parameters
-MAContAccessKey
    Sets the controller access key for the Machine Agent, this won't change configuration for the Java agent, as these should be configured as parameters
-MAContAccount
    Sets the controller account for the Machine Agent, this won't change configuration for the Java agent, as these should be configured as parameters
-MASIMEnabled
    Enables or disables the server visibility for the Machine Agent
-MAHierarchy
    Sets Machine Agent hierarchy
-MAUser
    Sets the user that will run machine agent, if not provided root will be used
-MAGroup
    Sets the group that will run machine agent, if not provided will be used the default group for the user.
```

Machine Agent startup now is configured upon installation. Script will look for systemctl, and if present will configure SystemD, if not present will try using chkconfig. If chkonfig is not present than will try update-rc.d. If none are present a message will be presented to the user, telling that configuration will have to be done manually.