# self-installing-script
This is a self installing script to facilitate installation of agents. Just run the script and it will generate the corresponding directories with the right permissions.

This is basically composed of a powershell script that downloads the agents and generates the installer to be executed on the Linux boxes. Later versions will generate installers to other systems and technologies.

On this current version script works just for Linux, script will only self extract itself, create the right folders under <appdynamics-home> directory and set the right permissions. For network-agent, script will also try to install it using sudo.

Still there is a lot to do, but this is a first version of the script.

# How to use this script

Download the release package and run the powershell script build_installer.ps1. This script will connect to the AppDynamics website, downlaod the agents and generate the agents_installer.sh script.

Transfer this script to the linux boxes and proceed with the installation. This will place all the three agents on the right directories with the right permissions. Just the start of the applications will need to be added manually later so apps can load the agent during initialiation.
