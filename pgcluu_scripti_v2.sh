#!/bin/bash

# Please Note: this script provides running pgcluu and generating reports. 
# And this script maintenance pgcluu and its reporting folders also. 
# If the server you run on it, does not have pgcluu installed, it does not work.
#
#
# Pgcluu is one of monitoring tool for Postgres. You can see more information
# about this http://pgcluu.darold.net/
# This script help us to run pgcluu periodicaly like monthly. 
# This script is also ready to run in cron. 
#
# Crontab example
# 30 5 1 * * bash /var/lib/pgsql/bin/runpgcluu.sh
#
#


# [GLOBAL]
# Use DATE vairable for giving folder name in remote. 
DATE=`date +%Y-%m -d "1 month ago"`
ARCHIVING="LOCAL"

# Define pglcuu variables.
PID_FILE="/tmp/pgcluu_collectd.pid"
PGCLUU_DIR="/var/lib/pgsql/pgcluu/"
PGCLUU_REPORT_DIR="/var/lib/pgsql/pgcluu/pgcluu-report"
PGCLUU_ARCHIVE_DIR="/var/lib/pgsql/pgcluu/$DATE"

# Define connection information for your Postgres.
HOSTNAME="localhost"
PORT="54113"
DBUSER="postgres"

# Use TIME_RANGE for your pgcluu script. Default is 60.
TIME_RANGE=3

# Define remote server informations if require move your html files
# to REMOTE. Input values of following parameters if you require
# archiving remotely. 
#
# This script does not provide connection between local and remote server
# for SSH. Before using this feature be sure there is a connection between both of
# servers. 
REMOTE_HOST=""
REMOTE_USER=""
PGCLUU_REMOTE_REPORT_DIR="/var/www/html/pgcluu/pgcluu-report-primary/"
PGCLUU_REMOTE_ARCHIVE_DIR="/var/www/html/pgcluu/pgcluu-report-primary/$DATE"

echo ""
mkdir -m 755 -p $PGCLUU_DIR $PGCLUU_REPORT_DIR $PGCLUU_ARCHIVE_DIR
echo "[INFO] $PGCLUU_DIR , $PGCLUU_REPORT_DIR and $PGCLUU_ARCHIVE_DIR folders are generated."
echo ""

# If $PID_FILE does not exists that meaning is pgcluu is not working on this server. 
# And stop running this shell script.
if [ -f $PID_FILE ]

# Check process id number in $PID_FILE. If exists pgcluu works. If not, that meaning 
# there is any pgcluu works on this server. And stop running this shell script. 
then
    if [ -s $PID_FILE ]
    then
	echo ""
        echo "[INFO] $PID_FILE - pgcluu_collectd works.."
	echo "[INFO] Collecting data is terminating to generate reports.. "
	echo ""
    else
	echo ""
        echo "[ERROR] $PID_FILE - pgcluu_collectd doesn't work now. It will be run again.."
	/bin/pgcluu_collectd -D -i $TIME_RANGE $PGCLUU_DIR -h $HOSTNAME -p $PORT -U $DBUSER
	echo " |__ [INFO] Executed: pgcluu_collectd -D -i $TIME_RANGE /var/lib/pgsql/pgcluu/ "
	echo " |__ [INFO] Terminating this shell script.. "
	echo ""
	exit 1
    fi
else
    echo ""
    echo "[ERROR] Could not find pid file: $PID_FILE"
    echo " |__ [INFO] Could not find running pgcluu in this server.."
    echo " |__ [INFO] Terminating this shell script.. "
    echo " |__ [INFO] Run following command: "
    echo ""
    echo "/bin/pgcluu_collectd -D -i $TIME_RANGE $PGCLUU_DIR -h $HOSTNAME -p $PORT -U $DBUSER"
    echo ""
    exit 1
fi

# Terminate collecting report.
/bin/pgcluu_collectd -k
echo "[INFO] Collecting data process is stopped."
echo ""

# Remove old output files before moving output of reports.
rm -vf $PGCLUU_REPORT_DIR/*
echo "[INFO] Executed: rm -vf $PGCLUU_REPORT_DIR/*"
echo ""

# Generate reports in output folder.
/bin/pgcluu -o $PGCLUU_REPORT_DIR $PGCLUU_DIR -v
echo "[INFO] All reports were generated in $PGCLUU_REPORT_DIR folder.. "
echo ""

if [ $? -eq 0 ]; then

############################################################
# Optional: You may want to archive report's outputs. If you want to archive your 
# outputs locally, you follow [LOCAL]. If you want to archive your outputs remotely
# follow [REMOTE].
############################################################

    if [ $ARCHIVING == "LOCAL" ]; then 
	
	# [LOCAL]
	# Move reports to a sufficient folder.
	mv $PGCLUU_REPORT_DIR/* $PGCLUU_ARCHIVE_DIR/
	echo "[INFO] Reports is archived to this folder: $PGCLUU_ARCHIVE_DIR"
	echo ""
    elif [ $ARCHIVING == "REMOTE" ]; then 
	echo "Transferring to REMOTE.. "
	# [REMOTE]
	# Generate required folders in REMOTE.
	ssh $REMOTE_PORT@$REMOTE_HOST "mkdir -m 755 $PGCLUU_REMOTE_REPORT_DIR $PGCLUU_REMOTE_ARCHIVE_DIR"

	# Move reports to REMOTE. If occured any problem stop shell script.
	scp $PGCLUU_REPORT_DIR/* $REMOTE_PORT@$REMOTE_HOST:$PGCLUU_REMOTE_ARCHIVE_DIR/

		# If there is some error, you need to run pgcluu_collectd command to collect data again.
	       if [ $? -eq 0 ]; then
			rm -vf /var/lib/pgsql/pgcluu/*
			/bin/pgcluu_collectd -D -i $TIME_RANGE $PGCLUU_DIR -h $HOSTNAME -p $PORT -U $DBUSER
			exit 0
	       else
			echo ""
			echo " [ERROR] could not run SCP command bellow: "
			echo " |__ [INFO] command: scp $PGCLUU_REPORT_DIR/* $REMOTE_PORT@$REMOTE_HOST:$PGCLUU_REMOTE_ARCHIVE_DIR/ "
			echo ""
			exit 1
	       fi
    fi
else 
	echo "[ERROR] Check command following: /bin/pgcluu -o $PGCLUU_REPORT_DIR $PGCLUU_DIR -v "
	echo ""
	exit 0
fi


# For generating new reports, pgcluu_collectd command starts again.
/bin/pgcluu_collectd -D -i $TIME_RANGE $PGCLUU_DIR -h $HOSTNAME -p $PORT -U $DBUSER
echo ""
echo "[INFO] Started to collecting data again.."
echo ""
