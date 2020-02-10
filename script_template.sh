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
                zip="AppServerAgent-4.5.18.29239.zip"
                
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
                        mv cacerts.jks "ver4.5.18.29239/conf"
                fi

                chmod -R a+w "ver4.5.18.29239/logs"
        fi

        if [ $1 == "machine" ]; then
                zip="machineagent-bundle-64bit-linux-4.5.18.2430.zip"
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
                                controller_info=`echo $controller_info | sed -E "s/(<controller-host>)(.*)(<\/controller-host>)/<controller-host>${args[$i+1]}<\/controller-host>/g"`
                        fi
                        if [ "${args[$i]}" == "-MAContport" ]; then
                                echo "Setting controller port to ${args[$i+1]}"
                                controller_info=`echo $controller_info | sed -E "s/(<controller-port>)(.*)(<\/controller-port>)/<controller-port>${args[$i+1]}<\/controller-port>/g"` 
                        fi
                        if [ "${args[$i]}" == "-MAContSSL" ]; then
                                if [ "${args[$i+1]}" -eq 1 ]; then
                                        echo "Setting controllerSSL to ${args[$i+1]}"
                                        controller_info=`echo $controller_info | sed -E "s/(<controller-ssl-enabled>)(true|false)(<\/controller-ssl-enabled>)/<controller-ssl-enabled>>true<\/controller-ssl-enabled>/g"`
                                else
                                        if [ "${args[$i+1]}" -eq 0 ]; then
                                                echo "Setting servervisibility to ${args[$i+1]}"
                                                controller_info=`echo $controller_info | sed -E "s/(<controller-ssl-enabled>)(true|false)(<\/controller-ssl-enabled>)/<controller-ssl-enabled>false<\/controller-ssl-enabled>/g"`
                                        else
                                                echo "Invalid controllerSSL configuration, please make sure value is either 1 (enabled) or 0 (disabled)."
                                        fi
                                fi 
                        fi
                        if [ "${args[$i]}" == "-MAContAccessKey" ]; then
                                echo "Setting agent access key to ${args[$i+1]}"
                                controller_info=`echo $controller_info | sed -E "s/(<account-access-key>)(.*)(<\/account-access-key>)/<account-access-key>${args[$i+1]}<\/account-access-key>/g"` 
                        fi
                        if [ "${args[$i]}" == "-MAContAccount" ]; then
                                echo "Setting controller account to ${args[$i+1]}"
                                controller_info=`echo $controller_info | sed -E "s/(<account-name>)(.*)(<\/account-name>)/<account-name>${args[$i+1]}<\/account-name>/g"`
                        fi
                        if [ "${args[$i]}" == "-MASIMEnabled" ]; then
                                if [ "${args[$i+1]}" -eq 1 ]; then
                                        echo "Setting servervisibility to ${args[$i+1]}"
                                        controller_info=`echo $controller_info | sed -E "s/(<sim-enabled>)(true|false)(<\/sim-enabled>)/<sim-enabled>true<\/sim-enabled>/g"`
                                else
                                        if [ "${args[$i+1]}" -eq 0 ]; then
                                                echo "Setting servervisibility to ${args[$i+1]}"
                                                controller_info=`echo $controller_info | sed -E "s/(<sim-enabled>)(true|false)(<\/sim-enabled>)/<sim-enabled>false<\/sim-enabled>/g"`
                                        else
                                                echo "Invalid SIM configuration, please make sure value is either 1 (enabled) or 0 (disabled)."
                                        fi
                                fi
                        fi
                        if [ "${args[$i]}" == "-MAHierarchy" ]; then
                                echo "Setting controller URL to ${args[$i+1]}"
                                controller_info=`echo $controller_info | sed "s/<machine-path>false<\/machine-path>/<machine-path>${args[$i+1]}<\/machine-path>/g"` 
                        fi
                }
        fi

        if [ $1 == "network" ]; then
                zip="appd-netviz-x64-linux-4.5.11.2100.zip"
                echo "Unziping..."
                unzip -q /tmp/agents.zip $zip
		chmod u+rw $zip
                chmod a+r $zip
                unzip -q $zip
                rm -rf $zip
                sudo ./install.sh
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
