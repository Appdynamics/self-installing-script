#!/bin/bash
#basic configuration

java_agent_url="http://download-files.appdynamics.com/download-file/java-jdk8/20.8.0.30686/AppServerAgent-1.8-20.8.0.30686.zip"
java_jdk8_agent_url="http://download-files.appdynamics.com/download-file/java-jdk8/20.8.0.30686/AppServerAgent-1.8-20.8.0.30686.zip"
java_ibm_agent_url="http://download-files.appdynamics.com/download-file/ibm-jvm/20.8.0.30686/AppServerAgent-ibm-20.8.0.30686.zip"
machine_agent_url="http://download-files.appdynamics.com/download-file/machine-bundle/20.8.0.2713/machineagent-bundle-64bit-linux-20.8.0.2713.zip"

ca_cert_url="http://site.domain.com/path/cacerts.jks"

temp_dir="/tmp/appd_temp"

args=("$@")
args_size=$#

java_agent_local_file_name="java-agent.zip"
java_ibm_agent_local_file_name="java-ibm-agent.zip"
java_jdk8_agent_local_file_name="java-jdk8-agent.zip"
machine_agent_local_file_name="machine-agent.zip"

#initializin vars
AppDAgentList=()
AppDAgentListExist=0
AppDHome=""
AppDHomeExist=0
MAContURL=""
MAContURLExist=0
MAContport=""
MAContportExist=0
MAContSSL=""
MAContSSLExist=0
MAContAccessKey=""
MAContAccessKeyExist=0
MAContAccount=""
MAContAccountExist=0
MASIMEnabled=""
MASIMEnabledExist=0
MAHierarchy=""
MAHierarchyExist=0
MAUser=""
MAUserExist=0
MAGroup=""
MAGroupExist=0
MAInit=""
MAInitExists=0
Local=""
LocalExists=0
Cacerts=""
CacertsExists=0



all=0
java=0
java_ibm=0
java_jdk8=0
machine=0
network=0
sed_command=""

function test_sed(){
    if [ ! -d "$temp_dir" ]; then
		echo "Creating temp directory."
		mkdir -p $temp_dir
		echo "Temp Directory: $temp_dir"
		if [ $? -ne 0 ]; then
			echo "Error: Could not create temp directory: $dest_dir. Please check that and re run the installation."
			exit 1
		fi
	fi
	test_file="${temp_dir}/test_file"
	echo "<controller-host>somehostname</controller-host>" > $test_file
	cat $test_file | sed -r "s/(<controller-host>)(.*)*(<\/controller-host>)/<controller-host>12345<\/controller-host>/g" > "${test_file}2"
	file_contents=`cat ${test_file}2`
	if [[ $? -eq 0 && "$file_contents" == "<controller-host>12345</controller-host>" ]]; then
		sed_command="sed -r "
        echo "Using sed -r version"
	else
		cat $test_file | sed -E "s/(<controller-host>)(.*)*(<\/controller-host>)/<controller-host>12345<\/controller-host>/g" > "${test_file}2"
		if [[ $? -eq 0 && "$file_contents" == "<controller-host>12345</controller-host>" ]]; then
			sed_command="sed -E "
            echo "Using sed -E version"
		else
			echo "Warning: sed command is not available, configuration files will not be changed. Please change them manually."
		fi
	fi
}

function check_parameter_list(){
	#echo ${args[$i+2]}
	#echo ${args[$i+1]}
	if [[ ${args[$i]} == "-"* && ${args[$i]} != "-AppDAgentList" ]]; then
		if [[ ${args[$i+2]} != "-"* &&  ${args[$i+2]} != "" ]]; then
			echo "Error: parameter '${args[$i]}' accepts only one argument, please adjust the command line."
			exit 1
		fi
		if [[ ${args[$i+1]} == "-"* ]]; then
			echo "Error: parameter '${args[$i]}' is missing its argument, please adjust the command line."
			exit 1
		fi
	fi
}

read_parameters(){
for ((i=0; i < $args_size; i++)){
			#echo "Processing param ${args[$i]}"
			check_parameter_list
			case ${args[$i]} in
                        "-AppDAgentList")
				AppDAgentListExist=1;
				for ((j=$i+1; j < $args_size; j++)){
					if [[ ${args[$j]} == "-"* ]]; then
						echo "App list ended..."
						break
					else
						AppDAgentList+=(${args[$j]})
						#echo "Parameter found  ${args[$j]}"
					fi
				};
				for ((k=0; k < ${#AppDAgentList[@]}; k++)){
					if [ "${AppDAgentList[$k]}" == "all" ]; then
						all=1
						java=1
					else
						if [ "${AppDAgentList[$k]}" == "all-ibm" ]; then
							all=1
							java_ibm=1
						else
                            if [ "${AppDAgentList[$k]}" == "all-jdk8" ]; then
                                all=1
                                java_jdk8=1
                            else
                                other=1
                            fi
					    fi 
					fi 

					if [ "${AppDAgentList[$k]}" == "java" ]; then
						java=1
					fi
					
					if [ "${AppDAgentList[$k]}" == "java-ibm" ]; then
						java_ibm=1
					fi

                    if [ "${AppDAgentList[$k]}" == "java-jdk8" ]; then
						java_jdk8=1
					fi

					if [ "${AppDAgentList[$k]}" == "machine" ]; then
						machine=1
					fi

					if [ "${AppDAgentList[$k]}" == "network" ]; then
						network=1
					fi
					
					

					if [[ ( $all -eq 1 && $other -eq 1) ]]; then
						echo "Error: 'all' parameter and the others (java, java-ibm, machine and network) cannot be used together. Please use either 'all' or specify each of the agents to be installed (java, java-ibm, machine and network)"
						exit 1
					fi
					
					if [[ ( $java -eq 1 && $java_ibm -eq 1) ]]; then
						echo "Error: 'java' and 'java-ibm' parameters cannot be used together. Please use either 'java' or 'java-ibm' to specify the java agent to be installed."
						exit 1
					fi
					if [[ ( "${AppDAgentList[$k]}" != "java" && "${AppDAgentList[$k]}" != "java-ibm" && "${AppDAgentList[$k]}" != "machine" && "${AppDAgentList[$k]}" != "network" && "${AppDAgentList[$k]}" != "all" ) ]]; then
						echo "Error: Parameter ${AppDAgentList[$k]} is invalid, please use one of the following: 'java', 'java-ibm', 'machine', 'network' or 'all'. Aborting."
						exit 1
					fi

				};
				if [ $network -eq 1 ]; then
					if [ $machine -ne 1 ]; then
						echo "Error: network parameter requires the machine agent to also be installed, please add 'machine' to your list of agents to be installed. Aborting."
						exit 1
					fi
				fi;;
			"-AppDHome")
				AppDHome=${args[$i+1]}
                BarCheck="${AppDHome: -1}"
                if [ $BarCheck != "/" ]; then
                    AppDHome="$AppDHome/"
                fi
				AppDHomeExist=1;;
			"-MAContURL")
				MAContURL=${args[$i+1]}
				MAContURLExist=1;;
			"-MAContport")
				MAContport=${args[$i+1]}
				MAContportExist=1;;
			"-MAContSSL")
				MAContSSL=${args[$i+1]}
				MAContSSLExist=1;;
			"-MAContAccessKey")
				MAContAccessKey=${args[$i+1]}
				MAContAccessKeyExist=1;;
			"-MAContAccount")
				MAContAccount=${args[$i+1]}
				MAContAccountExist=1;;
			"-MASIMEnabled")
				MASIMEnabled=${args[$i+1]}
				MASIMEnabledExist=1;;
			"-MAHierarchy")
				MAHierarchy=${args[$i+1]}
				MAHierarchyExist=1;;
			"-MAUser")
				MAUser=${args[$i+1]}
				MAUserExist=1;;
			"-MAGroup")
				MAGroup=${args[$i+1]}
				MAGroupExist=1;;
			"-MAInit")
				MAInit=${args[$i+1]};
				MAInitExists=1;;
			"-Local")
				Local=${args[$i+1]};
				LocalExists=1;;
            "-Cacerts")
				Cacerts=${args[$i+1]};
				CacertsExists=1;;
			esac
}
	if [[ ( $AppDAgentListExist -eq 1 &&  $AppDHomeExist -eq 1 && $MAContURLExist -eq 1 && $MAContportExist -eq 1 && $MAContSSLExist -eq 1 && $MAContAccessKeyExist -eq 1 && $MAContAccessKeyExist -eq 1 && $MAContAccountExist -eq 1 && $MASIMEnabledExist -eq 1  && $MAUserExist -eq 1 && $MAGroupExist -eq 1 ) ]]; then
		echo "All parameters are properly informed"
		if [ $LocalExists -eq 1 ]; then
			echo "You chose to use local files, please rename the installers with these names: java = java-agent.zip, java-bm = java-ibm-agent.zip, machine-agent = machine-agent.zip, cacerts = cacerts.jks "   
		fi
	else 
		echo "Some required parameters are missing, aborting."
		exit 1
	fi
}

function check_downloader(){
	#echo "Checking if wget or curl is present."
	downloader=`which wget`
    if [ $? -eq 0 ]; then 
        echo "$downloader -O "
	else
		downloader=`which curl`
		if [ $? -eq 0 ]; then
			echo "$downloader -o "
		else
			echo ""
		fi

	fi
}

function download_agent(){
	download_command=`check_downloader`
	#echo $download_command
	printf "\nHandling download for $1 agent...\n"

	case $1 in
 	"java-jdk8")
	 	if [ $LocalExists -ne 1 ]; then
            echo "Downloading Java JDK8+ agent"
			full_command="$download_command $java_jdk8_agent_local_file_name $java_jdk8_agent_url";
			`$full_command`
            echo "Java JDK8+ agent downloaded"
		fi
		;;
    "java")
	 	if [ $LocalExists -ne 1 ]; then
            echo "Downloading Java SUN agent"
			full_command="$download_command $java_agent_local_file_name $java_agent_url";
			`$full_command`
            echo "Java SUN agent downloaded"
		fi
		;;
 	"java-ibm")
	 	if [ $LocalExists -ne 1 ]; then
            echo "Downloading Java IBM agent"
			full_command="$download_command $java_ibm_agent_local_file_name $java_ibm_agent_url";
			`$full_command`
            echo "Java IBM agent downloaded"
		fi
		;;
 	"machine")
	 	if [ $LocalExists -ne 1 ]; then
            echo "Downloading Machine agent"
			full_command="$download_command $machine_agent_local_file_name $machine_agent_url";
			`$full_command`
            echo "Machine agent downloaded"
		fi
		;;
    "all-jdk8")
	 	if [ $LocalExists -ne 1 ]; then
            echo "Downloading Java JDK8+ agent"
			full_command="$download_command $java_jdk8_agent_local_file_name $java_jdk8_agent_url";
			`$full_command`
            echo "Java JDK8+ agent downloaded"
            echo "Downloading Machine agent"
			full_command="$download_command $machine_agent_local_file_name $machine_agent_url";
			`$full_command`
            echo "Machine agent downloaded"
		fi
		;;
 	"all")
	 	if [ $LocalExists -ne 1 ]; then
            echo "Downloading Java SUN agent"
			full_command="$download_command $java_agent_local_file_name $java_agent_url";
			`$full_command`;
            echo "Java SUN agent downloaded"
            echo "Downloading Machine agent"
			full_command="$download_command $machine_agent_local_file_name $machine_agent_url";
			`$full_command`
            echo "Machine agent downloaded"
		fi
		;;
	"all-ibm")
		if [ $LocalExists -ne 1 ]; then
            echo "Downloading Java IBM agent"
			full_command="$download_command $java_ibm_agent_local_file_name $java_ibm_agent_url";
			`$full_command`;
            echo "Java IBM agent downloaded"
            echo "Downloading Machine agent"
			full_command="$download_command $machine_agent_local_file_name $machine_agent_url";
			`$full_command`
            echo "Machine agent downloaded"
		fi
		;;
	"network")
		echo "Warning: Network agent is part of the machine agent, no need to download it. Skipping download.";;

	"ca")
		if [[ $LocalExists -ne 1 && $CacertsExists -ne 1 ]]; then
            echo "Downloading cacerts.jks"
			full_command="$download_command cacerts.jks $ca_cert_url";
			`$full_command`
            echo "cacerts.jks downloaded"
		fi
		;;
	*)
		echo "Error: $1 is a invalid parameter for download function.";
		exit 1;;
	esac
	
	if [ $? -ne 0 ]; then
		echo "There was an error while downloading the $1 agent. Aborting."
		exit 1
	fi

}

function download_handler(){
    if [ $LocalExists -ne 1 ]; then
        echo "Downloading agents..."
        for ((i=0; i < ${#AppDAgentList[@]}; i++)){
            #echo  ${AppDAgentList[$i]}
            download_agent ${AppDAgentList[$i]}
        }
        download_agent "ca"
    else
        echo "Using local files in ${temp_dir}, agent file names: java = java-agent.zip, java-bm = java-ibm-agent.zip, machine-agent = machine-agent.zip, cacerts = cacerts.jks"
    fi
}

function unpack(){
	if [ "$1" == "java" ]; then
		dest_dir="${AppDHome}java-agent"
		echo "Java destination folder: $dest_dir"
		agent_file=$java_agent_local_file_name
	else
		if [ "$1" == "java-ibm" ]; then
			dest_dir="${AppDHome}java-agent"
			echo "Java IBM destination folder: $dest_dir"
			agent_file=$java_ibm_agent_local_file_name
		else
			if [ "$1" == "java-jdk8" ]; then
                dest_dir="${AppDHome}java-agent"
                echo "Java JDK8 destination folder: $dest_dir"
                agent_file=$java_jdk8_agent_local_file_name
            else
                if [ "$1" == "machine" ]; then
                    dest_dir="${AppDHome}machine-agent"
                    echo "Machine Agent destination folder: $dest_dir"
                    agent_file=$machine_agent_local_file_name
                else
                    if [ "$1" == "network" ]; then
                        echo "No need to unpack $1 as it is part of the machine agent. Continuing."
                        return 0
                    else
                        echo "Error: Invalid parameter ($1) passed to unpack fucntion. Aborting."
                        exit 1
                    fi
                fi
            fi
		fi
	fi
	if [ ! -d "$dest_dir" ]; then
		echo "Creating agent directory."
		mkdir -p $dest_dir
		echo "Agent Directory: $dest_dir"
		if [ $? -ne 0 ]; then
			echo "Error: Could not create agent directory: $dest_dir. Please check that and re run the installation."
			exit 1
		fi
	fi

	#$dest_dir
	
	echo "Unzipping $1 agent to $dest_dir"
	echo "unzip command -q ${temp_dir}/$agent_file -d $dest_dir"
	unzip -q "${temp_dir}/$agent_file" -d $dest_dir
	echo "Unzip result $?"
	if [ $? -ne 0 ]; then
		echo "Error: there was an error unpacking the $1 agent, please review the error messages and re run installation. Aborting."
		exit 1
	else
		echo "$1 agent unpack succesfully, continuing." 
	fi

    if [ $CacertsExists -ne 1 ]; then
        echo "Copying cacerts.jks for $1 agent"
        echo "cp \"${temp_dir}/cacerts.jks\" \"${dest_dir}/conf/\""			
        cp "${temp_dir}/cacerts.jks" "${dest_dir}/conf/"
	fi
	
	
	if [ $? -ne 0 ]; then
		echo "Error: there was an error copying the cacerts.jks. Aborting."
		exit 1
	fi
	
}

function install(){
	echo "Installing $1"
	unpack $1
	case $1 in
	"machine")
		machine_agent_config;
		install_svc;;
	"network")
		install_network;;
	esac

}

function install_sysv(){
	echo "Configuring SysV"
	appd_home_sed=${AppDHome//\//\\\/}
	full_sed_command="cat \"${AppDHome}machine-agent/etc/sysconfig/appdynamics-machine-agent\" | $sed_command 's/MACHINE_AGENT_HOME=.*?/MACHINE_AGENT_HOME=${appd_home_sed}machine-agent/g' > \"${temp_dir}/appdynamics-machine-agent\""
	eval $full_sed_command

	full_sed_command="cat \"${temp_dir}/appdynamics-machine-agent\" | $sed_command 's/JAVA_HOME=.*/JAVA_HOME=${appd_home_sed}machine-agent\/jre/g' > \"${temp_dir}/appdynamics-machine-agent2\""
	eval $full_sed_command
	
	full_sed_command="cat \"${temp_dir}/appdynamics-machine-agent2\" | $sed_command 's/MACHINE_AGENT_USER=.*/MACHINE_AGENT_USER=${MAUser}/g' > \"${temp_dir}/appdynamics-machine-agent3\""
	eval $full_sed_command

	full_sed_command="cat \"${temp_dir}/appdynamics-machine-agent3\" | $sed_command 's/MACHINE_AGENT_GROUP=.*/MACHINE_AGENT_GROUP=${MAGroup}/g' > \"${temp_dir}/appdynamics-machine-agent4\""
	eval $full_sed_command
	
	mv "${temp_dir}/appdynamics-machine-agent4" "${AppDHome}machine-agent/etc/sysconfig/appdynamics-machine-agent"
	ln -sf "${AppDHome}machine-agent/etc/sysconfig/appdynamics-machine-agent" "/etc/sysconfig/appdynamics-machine-agent"
	cp "${AppDHome}machine-agent/etc/init.d/appdynamics-machine-agent" "/etc/init.d/appdynamics-machine-agent"
	chkconfig --add appdynamics-machine-agent
}

function install_systemd(){
	echo "Configuring Systemd"
	systemctl=`which systemctl`
	if [ $? -ne 0 ]; then
		echo "Error: systemctl command not present, please configure machine-agent init manually."
		return 1
	fi
	appd_home_sed=${AppDHome//\//\\\/}
	full_sed_command="cat \"${AppDHome}machine-agent/etc/systemd/system/appdynamics-machine-agent.service\" | $sed_command 's/MACHINE_AGENT_HOME=.*/MACHINE_AGENT_HOME=${appd_home_sed}machine-agent/g' > \"${temp_dir}/appdynamics-machine-agent.service1\""
	echo $full_sed_command
	eval $full_sed_command

	full_sed_command="cat \"${temp_dir}/appdynamics-machine-agent.service1\" | $sed_command 's/JAVA_HOME=.*/JAVA_HOME=${appd_home_sed}machine-agent\/jre/g' > \"${temp_dir}/appdynamics-machine-agent.service2\""
	echo $full_sed_command
	eval $full_sed_command

	full_sed_command="cat \"${temp_dir}/appdynamics-machine-agent.service2\" | $sed_command 's/MACHINE_AGENT_USER=.*/MACHINE_AGENT_USER=$MAUser/g' > \"${temp_dir}/appdynamics-machine-agent.service3\""
	echo $full_sed_command
	eval $full_sed_command
	
	cp "${temp_dir}/appdynamics-machine-agent.service3" "/etc/systemd/system/appdynamics-machine-agent.service"
	if [ $? -ne 0 ]; then
		echo "Error: could not copy the appdynamics-machine-agent.service file to /etc/systemd/system/appdynamics-machine-agent.service, please review systemd configuration for this system and adjust init configuration manually."
		return 1
	fi
	eval "$systemctl enable appdynamics-machine-agent"
	
	if [ $? -eq 1 ]; then
		echo "Warning: systemd configuration presented an error. Please review the messages and configured it manually."
	else
		echo "Systemd configuration succesful."
	fi
}

function machine_agent_config(){
	if [ "$sed_command" != "" ]; then
	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml\" | $sed_command 's/(<controller-host>)(.*)*(<\/controller-host>)/<controller-host>${MAContURL}<\/controller-host>/g' > \"${AppDHome}machine-agent/conf/controller-info.xml.temp\""
	#echo "Conroller host: $full_sed_command"
	eval $full_sed_command 
	#cat  "${AppDHome}machine-agent/conf/controller-info.xml.temp"
	
	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml.temp\" |  $sed_command 's/(<controller-port>)(.*)*(<\/controller-port>)/<controller-port>${MAContport}<\/controller-port>/g' > \"${AppDHome}machine-agent/conf/controller-info.xml.temp2\""
	#echo "Controller port $full_sed_command"
	eval  $full_sed_command 
	#cat "${AppDHome}machine-agent/conf/controller-info.xml.temp"
	
	if [ $MAContSSL -eq 0 ]; then
		ssl="false"
	else
		ssl="true"
	fi
	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml.temp2\" | $sed_command 's/(<controller-ssl-enabled>)(true|false)(<\/controller-ssl-enabled>)/<controller-ssl-enabled>$ssl<\/controller-ssl-enabled>/g' > \"${AppDHome}machine-agent/conf/controller-info.xml.temp3\""
	#echo "SSL $full_sed_command"
	eval $full_sed_command

	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml.temp3\" | $sed_command 's/(<account-access-key>)(.*)*(<\/account-access-key>)/<account-access-key>${MAContAccessKey}<\/account-access-key>/g' > \"${AppDHome}machine-agent/conf/controller-info.xml.temp4\""
	#echo $full_sed_command
	eval $full_sed_command

	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml.temp4\" | $sed_command 's/(<account-name>)(.*)*(<\/account-name>)/<account-name>${MAContAccount}<\/account-name>/g'  > \"${AppDHome}machine-agent/conf/controller-info.xml.temp5\""
	#echo $full_sed_command
	eval $full_sed_command

	if [ $MASIMEnabled -eq 0 ]; then
		sim="false"
	else
		sim="true"
	fi

	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml.temp5\" | $sed_command 's/(<sim-enabled>)(true|false)(<\/sim-enabled>)/<sim-enabled>$sim<\/sim-enabled>/g' > \"${AppDHome}machine-agent/conf/controller-info.xml.temp6\""
	#echo $full_sed_command
	eval $full_sed_command

	full_sed_command="cat \"${AppDHome}machine-agent/conf/controller-info.xml.temp6\" | $sed_command 's/<machine-path><\/machine-path>/<machine-path>${MAHierarchy}<\/machine-path>/g' > \"${AppDHome}machine-agent/conf/controller-info.xml.temp7\""
	#echo $full_sed_command
	eval $full_sed_command

	mv     "${AppDHome}machine-agent/conf/controller-info.xml.temp7"  "${AppDHome}machine-agent/conf/controller-info.xml"
	rm -rf "${AppDHome}machine-agent/conf/controller-info.xml.*"

	if [ $? -eq 0 ]; then
		echo "Machine agent configuration update sucessfully."
	else
		echo "Error: there was an error while updating the machine agent configuration file. Please update the file controller-info.xml manually."
	fi
	else
		echo "Warning: sed command not available, skiping controller-info.xml configuration."
	fi
}

function install_svc(){
	if [ $MAInitExists -eq 1 ]; then
		echo "Configuring $MAInit for machine-agent."
		case $MAInit in 
		"systemd")
			install_systemd;;
		"sysv")
			install_sysv;;
		*)
			echo "Error: Invalid parameter informed for the init configuration, please choose either 'systemd' or 'sysv'. If you prefer to configure init manually, please re run the install script, WHITHOUT the the -MAInit option."
		esac

	else
		echo "Warning: -MAInit parameter has not been informed, script will not configure machine-agent start up. Please configure machine-agent start up manually."
	fi
}

function install_network(){
	echo "Installing network visibility."
	echo "start: true" > "${AppDHome}machine-agent/extensions/NetVizExtension/conf/netVizExtensionConf.yml"
	current_user=`whoami`
	if [ $current_user == "root" ]; then
		eval "${AppDHome}machine-agent/extensions/NetVizExtension/install-extension.sh"
	else
		echo "Warning: NetViz installation must be executed as root. Please re execute the installer as root, using sudo or activate the NetViz module manually (sudo or root also required)."
	fi
}

function installation_handler(){
if [[ $all -eq 1 && $java -eq 1 ]]; then
	echo "Starting Handler to install All agents"
	install "java"
	install "machine"
	install "network"
else
	if [[ $all -eq 1 && $java_ibm -eq 1 ]]; then
	echo "Starting Handler to install All agents for IBM"
		install "java-ibm"
		install "machine"
		install "network"
	else
		if [ $java -eq 1 ]; then
			install "java"
		fi
		if [ $java_ibm -eq 1 ]; then
			install "java-ibm"
		fi
        if [ $java_jdk8 -eq 1 ]; then
			install "java-jdk8"
		fi
		if [ $machine -eq 1 ]; then
			install "machine"
		fi
		if [ $network -eq 1 ]; then
			install "network"
		fi
	fi

fi
}

function define_machine_start_message(){
	case $MAInit in
	"sysv")
		echo "Installation was successful, please start the machine agent using the comand:";
		echo "/etc/init.d/appdynamics-machine-agent start or service appdynamics-machine-agent start";;
	"systemd")
		echo "Installation was successful, please start the machine agent using the comand:";
		echo "systemctl start appdynamics-machine-agent";;
	*)
		echo "Installation was executed without configuring init system, please start the machine-agent manually. It is also recomended to configure the init system so the machine agent restarts in case of a system reboot.";;
	esac
}

function finalize_installation(){
	if [ $? -eq 0 ]; then
		echo "Finishing..."
		cd $initial_dir
		if [ $LocalExists -ne 1 ];then
			echo "Cleaning up temp files..."
			rm -rf $temp_dir
		fi
		
		if [[ $java -ne 1 && $java_ibm -ne 1 && $java_jdk8 -ne 1 && $all -ne 0 ]]; then
            echo "Changing machine agent owner folder to $MAUser:$MAGroup"
			define_machine_start_message
			chown -R $MAUser:$MAGroup "${AppDHome}"
		else
			echo "Java Installation was successful"
		fi
	else
		echo "Installation had problems, please review error messages and re execute the installation."
		exit 1
	fi
}

############################ MAIN ####################################

#configuring sed command present on the system
test_sed

#reading command line parameters
read_parameters

#Clean or use local install
initial_dir=`pwd`
if [ $LocalExists -ne 1 ];then
	rm -rf $temp_dir
	mkdir $temp_dir
fi

cd $temp_dir

#handling agent donwload
download_handler

#handling agent installation
installation_handler

#finalizing script
finalize_installation
