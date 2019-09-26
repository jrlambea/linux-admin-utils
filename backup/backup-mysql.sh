#!/bin/bash

# backup-mysql.sh v1.0.1
# JR. Lambea 
#---

excludedDB="information_schema|performance_schema|test"
configFile="~/.mysql.cfg"
backupFolder="/tmp"
S3Bucket="contoso-backups"
mysqlBinFolder="/opt/bitnami/mysql/bin"

if [ -s $configFile ]; then
    echo "The config file ${configFile} not exist."
    exit 5
fi

function GetTimestamp {
    printf '%(%Y%m%d.%H%M%S)T\n' -1
}

function GetLogTimestamp {
    printf '%(%Y-%m-%d %H:%M:%S)T\n' -1
}

function GetDatabases {
    "${mysqlBinFolder}/mysqlshow" --defaults-extra-file=$configFile | sed -n '4,$p' | egrep -v "\+|${excludedDB}" | cut -d" " -f2
}

databases=$(GetDatabases)
dbCount=$(echo $databases | wc -l)

echo "$(GetLogTimestamp) ${dbCount} databases to backup."

for db in $databases; do
    echo "$(GetLogTimestamp) Backing up ${db} database..."
    timestamp="$(GetTimestamp)"
    outputFile="${backupFolder}/${db}.${timestamp}.sql.gz"
    "${mysqlBinFolder}/mysqldump" --defaults-extra-file=$configFile -B "${db}" --add-drop-database --add-drop-table | gzip -9 -c >> "${outputFile}"

    echo "$(GetLogTimestamp) Backup of ${db} finished."
    
    if [ -s "${outputFile}" ]; then
        echo "$(GetLogTimestamp) The file has been created, following the process."
        fileSize=$(du -k ${outputFile} | awk '{print $1}')

        echo "$(GetLogTimestamp) Uploading ${outputFile} to S3 (${S3Bucket})..."
        aws s3 cp ${outputFile} s3://${S3Bucket}/mysql/ 2> /dev/null
        echo "$(GetLogTimestamp) Upload of ${outputFile} finished."
        echo "$(GetLogTimestamp) Deleting ${outputFile}..."
        rm ${outputFile}
        
    else
        echo "$(GetLogTimestamp) Something goes wrong with the ${db} backup..."
    fi
done
