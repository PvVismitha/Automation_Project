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
if [ ! -f /etc/cron.d/automation ];then
	echo "0 0 * * * sudo /root/Automation_Project/automation.sh $s3_bucket" > /etc/cron.d/automation
fi
aws s3 cp ${logfolder}.tar s3://${s3_bucket}/${logfolder}.tar
if [ $? -eq 0 ];then
	echo "Tar file uploaded to storage s3://${s3_bucket}"
fi
size=$(ls -lh $logfolder.tar | cut -d ' ' -f 5)
if [ ! -f /var/www/html/inventory.html ];then
	echo -e "<html>\n<body>\n<table>\n\t<tr>" > /var/www/html/inventory.html
	echo -e "\t\t<th>Log Type</th>\n\t\t<th>Time Created</th>\n\t\t<th>Type</th>\n\t\t<th>Size</th>" >> /var/www/html/inventory.html
	echo -e "\t</tr>" >> /var/www/html/inventory.html
	echo -e "\t<tr>\n\t\t<td>http-logs</td>\n\t\t<td>${timestamp}</td>\n\t\t<td>tar</td>\n\t\t<td>${size}</td>\n\t</tr>\n" >> /var/www/html/inventory.html
	echo -e "</table>\n</body>\n</html>" >> /var/www/html/inventory.html
else
	sed -i '/<\/table>/ i \t<tr>\n\t\t<td>http-logs</td>\n\t\t<td>${timestamp}</td>\n\t\t<td>tar</td>\n\t\t<td>${size}</td>\n\t</tr>\n' /var/www/html/inventory.html
fi

