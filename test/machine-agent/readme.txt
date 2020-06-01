****************************************************************************

   Please consult the documentation online for up-to-date information

       https://docs.appdynamics.com/display/PRO45/Standalone+Machine+Agent

****************************************************************************

Machine Agent Installation
--------------------------

A machine needs one active machine agent installation. The machine agent is automatically
associated with app server agents running on that machine using the same unique host ID. The
unique host ID is automatically selected based on the IP address of the machine. It is recommended
to use a custom unique host ID for both machine agents and app agents. See the specifying a
custom unique host ID section for why this is recommended.

1. Edit the controller-info.xml file to point to the installed controller host and controller port.

Go to <machine-agent-home>/conf/controller-info.xml and change the following tags:

        <controller-host></controller-host>
        <controller-port></controller-port>

The account access key is used to authenticate the agent with the Controller. This key is generated
at installation time. Set the account access key to the one provided by the Controller in the
Controller settings (please consult online documentation to find the key):

        <account-access-key></account-access-key>

If the Machine Agent is connecting to a multi-tenant controller or the AppDynamics SaaS controller
set the account name (This value is optional on-premises):

        <account-name></account-name>

To enable HTTPS between the agent and the Controller, consult the online documentation

        https://docs.appdynamics.com/display/PRO45/Enable+SSL+for+Standalone+Machine+Agent

2. Depending on the downloaded package, the machine agent may or may not ship with a JRE (you can
   check if you have a "jre" directory under the machine agent directory). The machine agent
   requires JRE version 1.8 or later.

The following command will start the Machine Agent on POSIX systems:

        bin/machine-agent

or on Windows:

        cscript bin\machine-agent.vbs


The bin directory is in the directory where you extracted the machine agent.

Consult the online documentation for installing the machine agent as a service.

3. Verify that the agent has been installed correctly.

Check that you have received the following message that the machine agent was started successfully
in the machine-agent.log file in your <machine-agent-home>/logs folder.
This message is also printed on the stdout of the process.

Started APPDYNAMICS Machine Agent Successfully.


4. If you are installing the Machine Agent on a machine which has a running app server agent, the
   hardware data is automatically assigned to the app server node(s) running on the machine.

5. If you are installing the Machine Agent on a machine which does not have a running app server agent,
for example, on a database server/ message server, you can see all metrics for the machine only if you
have a Server Monitoring license or a legacy Machine Agent license.

Connecting to the Controller through a Proxy Server
---------------------------------------------------

Use the following system properties to set the host and port of the proxy server so that it can route requests
to the Controller.

        com.singularity.httpclientwrapper.proxyHost=<host>
        com.singularity.httpclientwrapper.proxyPort=<port>

Specifying unique host ID
--------------------------------
The host ID for the machine on which the Agent is running is used as an identifying property for
the Agent Node. Specifying a unique host ID is not required, however it is recommended in the
following scenarios:

 - The machine host ID is not constant
 - You prefer to use a specific name in the UI
 - The machine has both a Machine Agent and app agents on it


If you do not define a unique host ID, the Machine Agent uses the Java API to get the host name. The
results from the API can be inconsistent and in fact, the same JVM can sometimes return a different
value for the same machine each time the Machine Agent is restarted. To avoid problems of this
nature, we recommend that you set the value of unique host id to the host id that you want to see in the UI.

One way to specify the host ID is by using the system property as part of your startup command.

        appdynamics.agent.uniqueHostId=<host-name>

Troubleshooting
---------------

- Machine metrics are not showing up for my application

The unique host ID used by App Agents must match the host ID used by the Machine Agent. When in doubt, set both to a custom value.

- I'm have trouble starting the Machine Agent

Please check the logs in the log directory for information that can help. Are you using the
bundled JRE? If not, is the JRE version you are using 1.8 or later? You can check by
executing `java -version`.

- I am still having issues

More issues are discussed online here:

        https://docs.appdynamics.com/display/PRO45/FAQs+and+Troubleshooting

Need help? Technical support is available through [AppDynamics Support](https://www.appdynamics.com/support).
