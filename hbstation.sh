#!/bin/bash
#
# Hackbright Desktop Station Sync Script
#
# Run this script on a newly installed pair programming station or 
#   at any time to make sure all the settings and installed programs
#   are consistant.
#
# Author: Nick Avgerinos (nicka@hackbrightacademy.com)
#         September 2013
#

# Below is the list of all the packages that are required for a 
#   Hackbright Pair Programming Station.
declare -a PACKAGES=(
  curl
  openssh-server
  git
  vim
  python-dev python-pip
  bpython
  sqlite3
  libxml2-dev libxslt1-dev
  wireshark tshark
  xchat
  spark
  gimp
  libffi-dev
  nodejs
);


RUN_BACKUP=0
RUN_PACKAGE=0
RUN_USER=0
DISPLAY_HELP=0
FORCE_LOGOUT=0

SOURCE_URL='http://nuc-install.int.hackbrightacademy.com/'
USER="user"
USER_DIR="/home/user"
DATE=`date +%Y%m%d`
HOSTNAME=`/bin/uname -n`
ARCH=`uname -p`

# Which version of Ubuntu?
UBUNTU_VERSION=`/usr/bin/lsb_release -r | awk '{ print $2 }'`
if [[ $UBUNTU_VERSION == *14.* ]]; then
  UBUNTU_14=Yes
fi

  echo -e "

Hackbright Pair-Programming Station Setup
-----------------------------------------

This script will configure an Ubuntu-based Pair Programming 
Station for Hackbright Academy Student Use.

Use -h for help.
"


# Only root can run this script
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with root privileges" 1>&2
  exit 1
fi


# Check Command-Line Arguments
while getopts ":abhfpu" opt; do
  case $opt in
    a)
      RUN_BACKUP=1
      RUN_PACKAGE=1
      RUN_USER=1
      ;;
    b)
      RUN_BACKUP=1
      ;;
    f)
      FORCE_LOGOUT=1
      ;;
    p)
      RUN_PACKAGE=1
      ;;
    u)
      RUN_USER=1
      ;;
    h)
      DISPLAY_HELP=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      DISPLAY_HELP=1
      ;;
    :)
      echo "Option -$OPTARG requires an arguement." >&2
      DISPLAY_HELP=1
      ;;
  esac
done



if [ $DISPLAY_HELP -eq 1 ]; then
  echo -e "
  Usage:
    hbstation.sh [-a] [-b] [-p]
  
  Where:
    -a : Run Everything (Same as -bp)
    -b : Backup Existing User Directory
    -p : Check Installed System Packages
  
"
  exit 1

fi


# Check if the "user" is currently logged into the desktop.  
if [ $RUN_BACKUP -eq 1 ] || [ $RUN_USER -eq 1 ]; then
    # Get the PID for the user's desktop tty session
    if [ $UBUNTU_14 ]; then
      PID=`who -u | grep ' :0 ' | grep $USER | awk '{ print $6}'`
    else
      PID=`who -u | grep tty | grep $USER | awk '{ print $6}'`
    fi
    #echo "PID: $PID"

    # If we got a PID, we need to log it out
    if [ "$PID" != "" ] && [ $PID -gt 0 ]; then
      if [ $FORCE_LOGOUT -ne 1 ]; then
        echo ""
        echo "*** User Desktop Login Detected ***"
        echo "If you would like to continue, this will log the user out"
        echo "  of their current desktop session."
        echo ""
        echo "Do not run this script from the local desktop (or you will"
        echo "  be logged out if you continue!)"
        echo ""

        read -p "Force 'user' logout of desktop tty? " -n 1 -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          exit 1
        fi
      fi

      # Force the user to log out
      echo "Forcing logout..."
      kill $PID

    fi

fi


# Package Installation
if [ $RUN_PACKAGE -eq 1 ]; then
    echo "Checking Installed Packages"
 
    # Check repos are added
    REPOCHK=`find /etc/apt -name *.list | xargs cat | grep ^[[:space:]]*deb | grep chris-lea`
    if [ $? -ne 0 ]; then
      echo "Adding NodeJS Repo"
      # Add Repository for NodeJS Packages
      add-apt-repository -y ppa:chris-lea/node.js
    fi
    
    # Make sure package definitions are up to date
    apt-get -y update
    
    
    # Check which packages need to be installed
    for p in ${PACKAGES[@]}
    do
      PKG_CHECK=`/usr/bin/dpkg-query -W --showformat='${Status}\n' $p | grep "ok installed"`
      if [ $? -ne 0 ]; then
        TO_INSTALL=("${TO_INSTALL[@]}" $p)
        echo "${p} is not installed"
      else
        echo "${p} is installed"
      fi
    done
    
    # Install any packages that failed the check
    if [ ${#TO_INSTALL[@]} -gt 0 ]; then
      echo ""
      echo "The following packages are missing and will be installed:"
      echo ${TO_INSTALL[@]}
    
      apt-get install -y ${TO_INSTALL[@]}
    else
      echo "No packages to install!"
    fi

    # Install Additional Python packages with PIP
    wget -O /tmp/python_requirements.txt $SOURCE_URL/python_requirements.txt
    pip install -r /tmp/python_requirements.txt

    # Check that Sublime Text is installed
    if [ ! -d "/opt/Sublime Text 2" ]; then
      echo "Sublime Text not found, installing..."
      pushd /opt

      if [ "$ARCH" == "x86_64" ]; then
        echo "Downloading Sublimt Text (64-bit)"
        SUBL_URL="http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.2%20x64.tar.bz2"
      else
        echo "Downloading Sublimt Text"
        SUBL_URL="http://c758482.r82.cf2.rackcdn.com/Sublime%20Text%202.0.2.tar.bz2"
      fi
  
      CMD='wget "'${SUBL_URL}'" 2>&1 | grep "Saving to:" | tail -1 | sed "s/^Saving to:\s*\`\(.*\)'"'"'$/\1/"'
      SUBL_ARCHIVE=$(eval $CMD)
 
      echo "Downloaded: ${SUBL_ARCHIVE}"

      tar xvf "$SUBL_ARCHIVE"

      popd
    fi
    # Check Sublime icon/launcher configured
    if [ ! -f /usr/share/applications/sublime.desktop ]; then
      cat > /usr/share/applications/sublime.desktop << EOF
[Desktop Entry]
Version=1.0
Name=Sublime Text 2
# Only KDE 4 seems to use GenericName, so we reuse the KDE strings.
# From Ubuntu's language-pack-kde-XX-base packages, version 9.04-20090413.
GenericName=Text Editor

Exec=sublime
Terminal=false
Icon=/opt/Sublime Text 2/Icon/48x48/sublime_text.png
Type=Application
Categories=TextEditor;IDE;Development
X-Ayatana-Desktop-Shortcuts=NewWindow

[NewWindow Shortcut Group]
Name=New Window
Exec=sublime -n
TargetEnvironment=Unity
EOF
    fi
 
    # Sublime symlinks
    unlink /usr/bin/sublime; ln -s /opt/Sublime\ Text\ 2/sublime_text /usr/bin/sublime
    unlink /usr/bin/subl; ln -s /opt/Sublime\ Text\ 2/sublime_text /usr/bin/subl
    unlink /usr/bin/sublime-text; ln -s /opt/Sublime\ Text\ 2/sublime_text /usr/bin/sublime-text
    unlink /usr/bin/sublime-text-2; ln -s /opt/Sublime\ Text\ 2/sublime_text /usr/bin/sublime-text-2

 
fi
  

# Turn of the display of the Update Manager
/bin/sed -i 's/NoDisplay=true/NoDisplay=false/g' /etc/xdg/autostart/update-notifier.desktop


# Backup User Home Directory 
if [ $RUN_BACKUP -eq 1 ]; then
    BACKUP_FILE="/root/backup/${DATE}_${HOSTNAME}_user.tar"
    echo "Backing Up ${USER_DIR} to ${BACKUP_FILE}"
    
    mkdir -p /root/backup
    pushd /home
    tar -cvf ${BACKUP_FILE} --exclude=.gvfs user
    gzip ${BACKUP_FILE}
    popd
fi

# Rebuild User Account/Home Directory
if [ $RUN_USER -eq 1 ]; then
    echo "Rebuilding User Home Directory"

    # Set User Account Name
    /bin/sed -i 's/1000:1000:[^,]*,/1000:1000:Hackbright Student,/' /etc/passwd 

    # Delete the existing home directory
    rm -rf ${USER_DIR}

    pushd /home
    # Download "Clean" user home directory
    wget -O /tmp/user-clean.tar.gz $SOURCE_URL/user-clean.tar.gz

    # Extract "clean" home directory
    /bin/gzip -cd /tmp/user-clean.tar.gz | tar -xvf -
    
    # Download Sublime License File
    wget -O /home/user/.config/sublime-text-2/Settings/License.sublime_license $SOURCE_URL/License.sublime_license

    # Set ownership
    chown -R user:user /home/user
    popd

    # Set the root ssh keys
    mkdir -p /root/.ssh
    wget -O /root/.ssh/authorized_keys $SOURCE_URL/hbstation_root_keys
    chown -R root:root /root/.ssh
    chmod 600 /root/.ssh/authorized_keys

fi

