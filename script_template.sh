#!/bin/bash
is_parameter_valid(){
        if [ "$1" != "" ]; then
                if [ "$1" == "java" ] | [ "$1" == "" ]; then
                        return 1
                else
                        if [ "$1" == "machine" ] | [ "$1" == "" ]; then
                                return 1
                        else
                                if [ "$1" == "network" ] | [ "$1" == "" ]; then
                                        return 1
                                else
                                        return 0
                                fi
                        fi
                fi
        fi
}

unpack(){
        echo "Generating agents.zip.."
        if [ -f "/tmp/agents.zip" ]; then
                rm -rf "/tmp/agents.zip"
        fi
        archive=$(grep --text --line-number 'archive:$' $0)
        archive=$(echo $archive | sed 's/:archive://') 
        tail -n +$((archive + 1)) $0 > /tmp/agents.zip
}

remove_pack(){
        echo "Removing /tmp/agents.zip"
        rm -rf "/tmp/agents.zip"
}

install(){
        echo "Installing $1..."
        
        if [ ! -d "$appd_home$1-agent/" ]; then
                mkdir -p "$appd_home$1-agent/"
        fi
        initial_dir=`pwd`
        cd "$appd_home$1-agent/"
        if [ "$?" != "0" ]; then
                echo "Could not cd into $appd_home$1-agent/, stopping installation."
                exit 1
        fi

        if [ $1 == "java" ]; then
                zip="JAVA_AGENT_FULL_NAME" 
                java_version="JAVA_FULL_VERSION"               
                
                echo "Unziping..."
                unzip -q /tmp/agents.zip $zip
		chmod u+rw $zip
		chmod a+r $zip
                unzip -q $zip                
                rm -rf $zip
                cacerts_exist=`unzip -l /tmp/agents.zip | grep cacerts | wc -l`
                if [ $cacerts_exist == "1" ]; then
                        echo "Found cacerts.jks file, lets move to the conf directory."
                        unzip -q /tmp/agents.zip cacerts.jks
                        chmod a+r cacerts.jks
                        chmod u+rw cacerts.jks
                        mv cacerts.jks "ver$java_version/conf"
                fi

                chmod -R a+w "ver4.5.18.29239/logs"
        fi

        if [ $1 == "machine" ]; then
                zip="MACHINE_AGENT_FULL_NAME"
                echo "Unziping..."
                unzip -q /tmp/agents.zip $zip
		chmod u+rw $zip
                chmod a+r $zip
                unzip -q $zip
                rm -rf $zip

                cacerts_exist=`unzip -l /tmp/agents.zip | grep cacerts | wc -l`
                if [ $cacerts_exist == "1" ]; then
                        echo "Found cacerts.jks file, lets move to the conf directory."
                        unzip -q /tmp/agents.zip cacerts.jks
                        chmod a+r cacerts.jks
                        chmod u+rw cacerts.jks
                        mv cacerts.jks "conf"
                fi
     
                controller_info=`cat conf/controller-info.xml`
                for ((i=0; i < $args_size; i++)){
                        if [ "${args[$i]}" == "-MAContURL" ]; then
                                echo "Setting controller URL to ${args[$i+1]}"
                                cat conf/controller-info.xml | sed -E "s/(<controller-host>)(.*)(<\/controller-host>)/<controller-host>${args[$i+1]}<\/controller-host>/g" > conf/controller-info.xml.temp
				mv conf/controller-info.xml.temp conf/controller-info.xml
                        fi
                        if [ "${args[$i]}" == "-MAContport" ]; then
                                echo "Setting controller port to ${args[$i+1]}"
                                cat conf/controller-info.xml | sed -E "s/(<controller-port>)(.*)(<\/controller-port>)/<controller-port>${args[$i+1]}<\/controller-port>/g" > conf/controller-info.xml.temp
				mv conf/controller-info.xml.temp conf/controller-info.xml
                        fi
                        if [ "${args[$i]}" == "-MAContSSL" ]; then
                                if [ ${args[$i+1]} -eq 1 ]; then
                                        echo "Setting controllerSSL to ${args[$i+1]}"
                                        cat conf/controller-info.xml | sed -E "s/(<controller-ssl-enabled>)(true|false)(<\/controller-ssl-enabled>)/<controller-ssl-enabled>true<\/controller-ssl-enabled>/g" > conf/controller-info.xml.temp
				  	mv conf/controller-info.xml.temp conf/controller-info.xml
                                else
                                        if [ ${args[$i+1]} -eq 0 ]; then
                                                echo "Setting servervisibility to ${args[$i+1]}"
                                                cat conf/controller-info.xml | sed -E "s/(<controller-ssl-enabled>)(true|false)(<\/controller-ssl-enabled>)/<controller-ssl-enabled>false<\/controller-ssl-enabled>/g" > conf/controller-info.xml.temp
						mv conf/controller-info.xml.temp conf/controller-info.xml
                                        else
                                                echo "Invalid controllerSSL configuration, please make sure value is either 1 (enabled) or 0 (disabled)."
                                        fi
                                fi 
                        fi
                        if [ "${args[$i]}" == "-MAContAccessKey" ]; then
                                echo "Setting agent access key to ${args[$i+1]}"
                                cat conf/controller-info.xml | sed -E "s/(<account-access-key>)(.*)(<\/account-access-key>)/<account-access-key>${args[$i+1]}<\/account-access-key>/g" > conf/controller-info.xml.temp
				mv conf/controller-info.xml.temp conf/controller-info.xml
                        fi
                        if [ "${args[$i]}" == "-MAContAccount" ]; then
                                echo "Setting controller account to ${args[$i+1]}"
                                cat conf/controller-info.xml | sed -E "s/(<account-name>)(.*)(<\/account-name>)/<account-name>${args[$i+1]}<\/account-name>/g" > conf/controller-info.xml.temp
				mv conf/controller-info.xml.temp conf/controller-info.xml
                        fi
                        if [ "${args[$i]}" == "-MASIMEnabled" ]; then
                                if [ ${args[$i+1]} -eq 1 ]; then
                                        echo "Setting servervisibility to ${args[$i+1]}"
                                        cat conf/controller-info.xml | sed -E "s/(<sim-enabled>)(true|false)(<\/sim-enabled>)/<sim-enabled>true<\/sim-enabled>/g" > conf/controller-info.xml.temp
					mv conf/controller-info.xml.temp conf/controller-info.xml
                                else
                                        if [ ${args[$i+1]} -eq 0 ]; then
                                                echo "Setting servervisibility to ${args[$i+1]}"
                                                cat conf/controller-info.xml | sed -E "s/(<sim-enabled>)(true|false)(<\/sim-enabled>)/<sim-enabled>false<\/sim-enabled>/g" > conf/controller-info.xml.temp
						mv conf/controller-info.xml.temp conf/controller-info.xml
                                        else
                                                echo "Invalid SIM configuration, please make sure value is either 1 (enabled) or 0 (disabled)."
                                        fi
                                fi
                        fi
                        if [ "${args[$i]}" == "-MAHierarchy" ]; then
                                echo "Setting controller URL to ${args[$i+1]}"
                                cat conf/controller-info.xml | sed "s/<machine-path><\/machine-path>/<machine-path>${args[$i+1]}<\/machine-path>/g" > conf/controller-info.xml.temp
				mv conf/controller-info.xml.temp conf/controller-info.xml
                        fi
                        if [ "${args[$i]}" == "-MAUser" ]; then
                                echo "Setting machine agent user to ${args[$i+1]}"
                                ma_user=${args[$i+1]}
                        fi
                        if [ "${args[$i]}" == "-MAGroup" ]; then
                                echo "Setting machine agent group to ${args[$i+1]}"
                                ma_group=${args[$i+1]}
                        fi

                }
                echo "Configuring agent init script..."
                #echo "MA home: $appd_home$1..."
                machine_agent_home=`pwd | sed "s/\//\\\\\ \//g"`
                machine_agent_home=`echo $machine_agent_home | sed "s/ //g"`
                #echo "MA home: $machine_agent_home..."
                which "systemctl"
                if [ $? -eq 0 ]; then   
                        #systemctl exists, so lets use it
                        echo "Unziping Machine Agent unit file..."
                        unzip -q /tmp/agents.zip "MachineAgentTemplate.service"
			if [ "$ma_user" != "" ]; then
				id -u $ma_user > /dev/null
				if [ $? -eq 1 ]; then
					echo "User $ma_user does not exist, systemd configuration will not continue. Please configure it manually later."
					return 1
				else
					group_exists=`id -gn $ma_user | grep $ma_group | wc -l`
					if [ $group_exists -eq 1 ]; then
						echo "Supplied user $ma_user does not belong to the supplied group, aborting systemd configuration. Please configure it manually later."
						return 1
					fi
				fi
			else
                        	ma_user="root"
			fi                        
                        if [ "$ma_group" == "" ]; then
				echo "Group not supplied, defaulting to $ma_user"
                                ma_group="$ma_user"                       
                        fi
                        cat MachineAgentTemplate.service | sed "s/ma_executable/$machine_agent_home\/bin\/machine-agent -d -p $machine_agent_home\/pidfile/g" | sed "s/path_to_pidfile/$machine_agent_home\/pidfile/g" | sed "s/ma_user/$ma_user/g" | sed "s/ma_group/$ma_group/g" > /etc/systemd/system/machine_agent.service
			echo "Writing unit file machine_agent.service"
			cat /etc/systemd/system/machine_agent.service
                        chmod 664 /etc/systemd/system/machine_agent.service
                        systemctl daemon-reload
                        systemctl start machine_agent.service
			systemctl enable machine_agent.service
			if [ $? -eq 1 ]; then
				echo "There was a problem configuring Machine Agent on systemd, please check systemd logs and status for troubleshooting."
				return 1
			fi
                else
                        which "chkconfig"
                        if [ $? -eq 0 ]; then
                                #chkconfig exists, so lets use it
                                echo "Unziping Machine Agent init script..."
                                unzip -q /tmp/agents.zip "ma_init.sh"
                                MAInitScript=`cat ma_init.sh`
                                if [ "$ma_user" == "" ]; then
                                        $ma_user="root"                        
                                fi
                                MAInitScript=`echo $MAInitScript | sed "s/USER=\"\"/USER=\"$ma_user\"/g"`
                                MAInitScript=`echo $MAInitScript | sed "s/AGENT_HOME=\"\"/AGENT_HOME=\"$machine_agent_home\"/g"`
                                echo $MAInitScript > /etc/init.d/machine_agent
                                chmod +x /etc/init.d/machine_agent
                                chkconfig machine_agent on
                        else
                                which "update-rc.d"
                                if [ $? -eq 0 ]; then
                                        #update-rc.d exists, so lets use it
                                        MAInitScript=`cat ma_init.sh`
                                        if [ "$ma_user" == "" ]; then
                                                $ma_user="root"                        
                                        fi
                                        MAInitScript=`echo $MAInitScript | sed "s/USER=\"\"/USER=\"$ma_user\"/g"`
                                        MAInitScript=`echo $MAInitScript | sed "s/AGENT_HOME=\"\"/AGENT_HOME=\"$machine_agent_home\"/g"`
                                        echo $MAInitScript > /etc/init.d/machine_agent
                                        chmod +x /etc/init.d/machine_agent
                                        update-rc.d AppDynamicsController defaults 80 
                                else
                                        echo "Could not find any of these commands: systemctl, chkconfig, update-rc.d. Agent startup configuration must be done manually."
                                fi
                        fi
                fi
        fi

        if [ $1 == "network" ]; then
                zip="NETWORK_AGENT_FULL_NAME"
                echo "Unziping..."
                unzip -q /tmp/agents.zip $zip
		chmod u+rw $zip
                chmod a+r $zip
                unzip -q $zip
                rm -rf $zip
                sudo ./install.sh
        fi
        echo "Adjusting directory ownership for all agents. User: $ma_user, Group: $ma_group"
        chown -R "$ma_user":"$ma_group" $appd_home
        if [ $? -ne 1 ]; then
                echo "Directories ownership successfully set."
        else
                echo "There was a problem manually setting the directories ownership, please do it manually."
        fi
        #echo "tail -n +$((archive + 1)) ../$0 > /tmp/agents.zip"

        cd $initial_dir
}

### BEGIN MAIN SCRIPT ###
if [ "$2" == "-AppDHome" ]; then
        appd_home=$3
else
        appd_home="/opt/appdynamics/"
fi

echo "AppD home set to $appd_home."

args=("$@")
args_size=$#

if [ "$1" == "all" ];  then
        echo "Installing all the agents: Java, Machine and Network"

        unpack

        install "java"
        install "machine"
        install "network"

        #remove_pack

else
#checking if parameters are valid
        is_parameter_valid "$1"
        #echo "is valid: $?..."
        if [ $? != "1" ]; then
                echo "Parameter 1 is invalid.."
                exit 1
        fi
        is_parameter_valid "$2"
        if [ "$?" != "1" ]; then
                echo "Parameter 2 is invalid.."
                exit 1
        fi
        is_parameter_valid "$3"
        if [ "$?" != "1" ]; then
                echo "Parameter 3 is invalid.."
                exit 1
        fi
        unpack
        while [ "$1" != "" ]; do
                install "$1"
                # Shift all the parameters down by one
                shift
        done
        #remove_pack
fi
exit 0
archive:
