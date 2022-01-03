#!/bin/bash

# backup-mysql.sh v1.5.2
# JR. Lambea 
#---

excludedDB="information_schema|performance_schema|test"
configFile="${HOME}/.mysql.cfg"
backupFolder="/tmp"
S3Bucket=backup-test
mysqlBinFolder="/usr/bin"
bold="\e[1m"
default="\e[0m"

if [[ $1 == "--config" || $1 == "--configure" ]]; then
    echo "Configuration mode..."

    echo -e "${bold}Alert!${default} Execute this script with the user wich will launch the backup!"
    read -p "Which MySQL user will launch the backup: " mysqlUser
    read -sp "And the ${mysqlUser} password is...: " mysqlPasswd
    echo
    echo -e "[mysqldump]\nuser=${mysqlUser}\npassword=\"${mysqlPasswd}\"\n\n[client]\nuser=${mysqlUser}\npassword=\"${mysqlPasswd}\"" > "${configFile}"
    sleep 1
    chmod 600 "${configFile}"

    read -p "To which bucket the backup will be saved: " S3Bucket
    sed "s/^S3Bucket=.*/S3Bucket="${S3Bucket}"/" "$0" > "/tmp/$0"

    read -p "Which week days you want to execute the backup (ex: \"1-5\" = weekdays)? " backupDays
    read -p "To which hour? " backupHour

    echo "Writing on crontab..."
    
    if ! crontab -l &>/dev/null; then
        echo "0 ${backupHour} * * ${backupDays} $(realpath $0)" | crontab -
    else
        (echo "0 ${backupHour} * * ${backupDays} $(realpath $0)" ; crontab -l) | crontab -
    fi

    echo "Launching the replacement of the current script, wait 2 seconds..."
    nohup /tmp/$0 --copy $(realpath $0) &>/dev/null &
    exit 0
fi

if [[ $1 == "--copy" && $# == 2 ]]; then
    sleep 2
    cp -p "$0" "$2"
    exit 0
fi

if [ ! -s $configFile ]; then
    echo "The config file ${configFile} not exist. Please, execute \"$0 --config\"."
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
dbCount=$(echo $databases | wc -w)

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
        /usr/local/bin/aws s3 cp ${outputFile} s3://${S3Bucket}/mysql/
        echo "$(GetLogTimestamp) Upload of ${outputFile} finished."
        echo "$(GetLogTimestamp) Deleting ${outputFile}..."
        rm ${outputFile}
        
    else
        echo "$(GetLogTimestamp) Something goes wrong with the ${db} backup..."
    fi
done
