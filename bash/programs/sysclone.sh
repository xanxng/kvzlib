#!/bin/bash
#/**
# * Clones a system's: database, config, files, etc. Extremely dangerous!!!
# * 
# * @author    Kevin van Zonneveld <kevin@vanzonneveld.net>
# * @copyright 2007 Kevin van Zonneveld (http://kevin.vanzonneveld.net)
# * @license   http://www.opensource.org/licenses/bsd-license.php New BSD Licence
# * @version   SVN: Release: $Id$
# * @link      http://kevin.vanzonneveld.net/
# */

# Includes
###############################################################

# (make::included from '/../functions/log.sh')
#/**
# * Logs a message
# * 
# * @param string $1 String
# * @param string $2 Log level. EMERG exists app.
# */
function log(){
    # Levels:
    # EMERG
    # ALERT
    # CRIT
    # ERR
    # WARNING
    # NOTICE
    # INFO
    # DEBUG
    
    # Init
    local line="${1}"
    local levl="${2}"

    # Defaults
    [ -n "${levl}" ] || levl="INFO"
    local show=0
    
    # Allowed to show?  
    if [ "${levl}" == "DEBUG" ]; then
        if [ "${OUTPUT_DEBUG}" = 1 ]; then
            show=1
        fi
    else
        show=1
    fi
    
    # Show
    if [ "${show}" = 1 ];then
        echo "${levl}: ${1}"
    fi
    
    # Die?
    if [ "${levl}" = "EMERG" ]; then
        exit 1
    fi
}

# (make::included from '/../functions/toUpper.sh')
#/**
# * Converts a string to uppercase
# * 
# * @param string $1 String
# */
function toUpper(){
   echo "$(echo ${1} |tr '[:lower:]' '[:upper:]')"
}

# (make::included from '/../functions/commandTestHandle.sh')
#/**
# * Tests if a command exists, tries to install package,
# * resorts to 'handler' argument on fail. 
# *
# * @param string $1 Command name
# * @param string $2 Package name. Optional. Defaults to Command name
# * @param string $3 Handler. Optional. (Any of the loglevels. Defaults to emerg to exit app)
# * @param string $4 Additional option. Optional.
# */
function commandTestHandle(){
    # Init
    local command="${1}"
    local package="${2}"
    local handler="${3}"
    local optionl="${4}"
    local success="0"
    local varname="CMD_$(toUpper ${command})"
    
    # Checks
    [ -n "${command}" ] || log "testcommand_handle needs a command" "EMERG"
    
    # Defaults
    [ -n "${package}" ] || package=${command}
    [ -n "${handler}" ] || handler="EMERG"
    [ -n "${optionl}" ] || optionl=""
    
    # Test command
    local located="$(commandTest ${command} ${package})"
    if [ ! -x "${located}" ]; then
        if [ "${optionl}" != "NOINSTALL" ]; then
            # Try automatic install
            commandInstall ${command} ${package}
             
            # Re-Test command
            located="$(commandTest ${command} ${package})"
            if [ ! -x "${located}" ]; then
                # Still not found
                log "${located}" "${handler}"
            else
                success=1
            fi
        else
            # Not found, but not going to install
            log "${located}" "${handler}"            
        fi
    else
        success=1
    fi
    
    if [ "${success}" == 1 ]; then
        log "Testing for ${command} succeeded" "DEBUG"
        # Okay, Save location in CMD_XXX variable 
        eval ${varname}="${located}"
    fi
}

# (make::included from '/../functions/commandInstall.sh')
#/**
# * Tries to install a package
# * Also saved command location in CMD_XXX
# *
# * @param string $1 Command name
# */
function commandInstall() {
    # Init
    local command=${1}
    local package=${2}
    
    # Show
    echo "Trying to install ${package}"
    
    if [ -z "${CMD_APTITUDE}" ]; then
        aptitude -y install ${package}
    fi
}

# (make::included from '/../functions/commandTest.sh')
#/**
# * Tests if a command exists, and returns it's location or an error string.
# * Also saved command location in CMD_XXX.
# *
# * @param string $1 Command name
# * @param string $2 Package name
# */
function commandTest(){
    # Init
    local command=${1}
    local package=${2}
    local located=$(which ${command})
    
    # Checks
    if [ ! -n "${located}" ]; then
        echo "Command ${command} not found at all, please install before running this program."
    elif [ ! -x "${located}" ]; then
        echo "Command ${command} not executable at ${located}, please install before running this program."
    else
        echo "${located}" 
    fi
}

# Config
###############################################################
OUTPUT_DEBUG=0

# Check for program requirements
###############################################################
commandTestHandle "bash" "bash" "EMERG" "NOINSTALL"
commandTestHandle "aptitude" "aptitude" "DEBUG" "NOINSTALL" # Just try to set CMD_APTITUDE, produces DEBUG msg if not found
commandTestHandle "egrep" "pcregrep"
commandTestHandle "awk"
commandTestHandle "sort"
commandTestHandle "uniq"
commandTestHandle "awk"
commandTestHandle "lsof"

# Config file found?
[ -f ./sysclone.conf ] || log "No config file found. Maybe: cp -af ./sysclone.conf.default ./sysclone.conf && nano ./sysclone.conf"


log "sad" "EMERG"
exit 1;  


exit 1

# Run
###############################################################


#echo "package source sync"
#rsync -a --progress ${HOST_SRC}:/etc/apt/sources.list ${HOST_DST}:/etc/apt/

echo "package upgrade"
ssh ${HOST_DST} 'aptitude -y update && aptitude -y dist-upgrade'

echo "package sync"
ssh ${HOST_SRC} 'dpkg --get-selections > /tmp/dpkglist.txt'
scp ${HOST_SRC}:/tmp/dpkglist.txt ${HOST_DST}:/tmp
dpkg --set-selections < /tmp/dpkglist.txt
apt-get -y update
apt-get -y dselect-upgrade

echo "account sync"
rsync -a --progress ${HOST_SRC}:/etc/passwd  ${HOST_DST}:/etc/
rsync -a --progress ${HOST_SRC}:/etc/passwd- ${HOST_DST}:/etc/
rsync -a --progress ${HOST_SRC}:/etc/shadow  ${HOST_DST}:/etc/
rsync -a --progress ${HOST_SRC}:/etc/shadow- ${HOST_DST}:/etc/
rsync -a --progress ${HOST_SRC}:/etc/group   ${HOST_DST}:/etc/

echo "config sync"
rsync -a --progress --delete ${HOST_SRC}:/etc/mysql/   ${HOST_DST}:/etc/mysql
rsync -a --progress --delete ${HOST_SRC}:/etc/apache2/ ${HOST_DST}:/etc/apache2
rsync -a --progress --delete ${HOST_SRC}:/etc/php5/    ${HOST_DST}:/etc/php5
rsync -a --progress --delete ${HOST_SRC}:/etc/postfix/ ${HOST_DST}:/etc/postfix

echo "database sync"
DATABASES=`echo "SHOW DATABASES;" | ${CMD_MYSQL} -p${DB_PASS_SRC} -u ${DB_USER_SRC} -h ${DB_HOST_SRC}`
for DATABASE in $DATABASES; do
  if [ "${DATABASE}" != "Database" ]; then
    echo "transmitting ${DATABASE}"
    echo "CREATE DATABASE IF NOT EXISTS ${DATABASE}" | ${CMD_MYSQL} -p${DB_PASS_DST} -u ${DB_USER_DST} -h ${DB_HOST_DST}
    ${CMD_MYSQLDUMP} -Q -B --create-options --delayed-insert --complete-insert --quote-names --add-drop-table -p${DB_PASS_SRC} -u${DB_USER_SRC} -h${DB_HOST_SRC} ${DATABASE} | ${CMD_MYSQL} -p${DB_PASS_DST} -u ${DB_USER_DST} -h ${DB_HOST_DST} ${DATABASE}
  fi
done

echo "directory sync"
# geen etc want dan gaat host, md0 naar de kloten!
rsync -a --progress --delete ${HOST_SRC}:/root/    ${HOST_DST}:/root
rsync -a --progress --delete ${HOST_SRC}:/home/    ${HOST_DST}:/home
rsync -a --progress --delete ${HOST_SRC}:/var/www/ ${HOST_DST}:/var/www