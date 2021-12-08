#!/bin/bash
myname=vismitha
timestamp=`date '+%d%m%Y-%H%M%S'`
s3_bucket=$1
echo "Updating packages"
sudo apt update -y > /tmp/update_${timestamp}.log
echo "Installing Apache2"
sudo apt install apache2 -y > /tmp/apache2Install_${timestamp}.log
echo "Installing awscli"
sudo apt install awscli -y  > /tmp/awscliInstall_${timestamp}.log
echo "Check the package install logs in /tmp"
if [ $(dpkg --get-selections | grep -i apache2 | grep -vc grep) -ge 0 ];then
	echo "Apache2 is installed."
else
	echo "Apache2 is not installed!!"
	exit 1
fi
status=$(sudo systemctl status apache2.service | grep -i active | grep -vc grep)
if [ ${status} -eq 0];then
	echo "Apache is not running! Restarting Apache2"
	sudo systemctl restart apache2.service
	status=$(sudo systemctl status apache2.service | grep -i active | grep -vc grep)
	if [ ${status} -eq 0];then
		echo "Apache failed to restarted!"
		exit 1
	fi
fi
echo "Apache is running"
cd /var/log/apache2/ 
logfolder=/tmp/${myname}-http-logs-${timestamp}
mkdir -p ${logfolder}
cp *.log ${logfolder}
tar -cf ${logfolder}.tar ${logfolder} > /dev/null
if [ -f $logfolder.tar ];then
	echo "Tar file created successfully."
else
	echo "Failed to create tar file"
	exit 1
fi
aws s3 cp ${logfolder}.tar s3://${s3_bucket}/${logfolder}.tar
if [ $? -eq 0 ];then
	echo "Tar file uploaded to storage s3://${s3_bucket}"
fi
