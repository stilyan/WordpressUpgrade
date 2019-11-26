#!/bin/bash

# =================== README ===================

# The script checks local version of wordpress and compares it to the version of latest release taken from WordPress site.
# If the latest version is newer than currently installed the following process occurs:
# 1) Newest is downloaded and extracted to the path where script is ran from.
# Usually that is different path from WordPress installation.
# 2) Directories and files from the old WordPress path are copied to the path of the latest WordPress.
# Those are configurable and usually contain: wp-content/ directory and wp-config.php file.
# Permissions and ownership of the copied data is kept intact.
# 3) The old WordPress directory is archived to archive in path where script is ran from.
# 4) The old Wordpress directory is replaced by the latest.

# Dependencies:
#
# Rsync installed.
# Directory from where script is ran must be clean - there is no 'wordpress' directory, no 'latest.tar.gz',
# no 'WordPress_CurrVer.tar.gz

# =================== End of README ===================

# =================== User configurations ===================

# Do not include '/' at end of path.
WpPath="/home/stilyan/websites/homepage/blog"
WpDownloadLink="https://wordpress.org/latest.tar.gz"

# Directories and files relative to WpPath.
# Those will be copied to the new intallation.
WpContentCopy=("wp-content" "wp-config.php")

# =================== End of configurations ===================

# Debug
#WpVersionCurrent="5.2.2"
#WpVersionLatest="5.2.2"

WpVersionCurrent=$(cat $WpPath/wp-includes/version.php | \
grep '$wp_version =' | \
grep -oP "(?<=').*?(?=')" \
)

WpVersionLatest=$(curl --silent https://wordpress.org/download/ | \
grep 'Download WordPress' | \
tail -n 1 | sed 's/[[:space:]]//g' | \
sed -e 's/DownloadWordPress\(.*\)<\/span>/\1/' \
)

echo -e "\n=== WordPress Upgrader ===\n"
echo "Current Version:" $WpVersionCurrent
echo "Latest Version:" $WpVersionLatest

# VersionCompare $Latest $Current
# Determines if $Latest > $Current
function VersionCompare() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

echo -e "\nChecking if latest version is newer than currently installed..."
if VersionCompare $WpVersionLatest $WpVersionCurrent; then
	echo "---> $WpVersionLatest from WordPress site is newer than currently installed $WpVersionCurrent"

	echo -e "Downloading WordPress $WpVersionLatest...\n"
	wget --quiet $WpDownloadLink

	echo -e "Extracting the archive...\n"
	# Todo: Last part of WpDownloadLink (till the '/') instead of hardcode.
	tar zxvf ./latest.tar.gz

	echo -e "\nCopying data from $WpVersionCurrent directory to the new $WpVersionLatest directory..."

	CurrentPath=$(pwd)

	for content in ${WpContentCopy[@]}; do
		# Todo: Replace 'wordpress' with variable that has value of directory extracted from archive.
		# Todo: Copying makes no sense with big data. Possibly refactor with exclusion of certain paths
		# from 'copy' and directly force the newest wordpress to replace the older while keeping away from the exclusions.
		echo "---> Copying $WpPath/$content to $CurrentPath/wordpress"
		#cp --recursive --preserve $WpPath/$content $CurrentPath/wordpress
		rsync --ignore-times --quiet --times --recursive --perms --owner $WpPath/$content $CurrentPath/wordpress
	done

	echo -e "\nArchiving $WpPath to $CurrentPath/WordPress_$WpVersionCurrent.tar.gz...\n"
	# To debug: --verbose
	# Preserving ownership is only availabie if ran as root: --same-owner
	tar --create --gzip --preserve-permissions --file $CurrentPath/WordPress_$WpVersionCurrent.tar.gz $WpPath

	echo -e "Replacing $WpPath with $CurrentPath/wordpress...\n"
	#cp --recursive --preserve $CurrentPath/wordpress $WpPath
	# Overwriting not occuring without the ending '/'
	rsync --ignore-times --quiet --times --recursive --perms --owner $CurrentPath/wordpress/ $WpPath/

	echo "Cleaning up..."
	rm --recursive $CurrentPath/wordpress
	rm $CurrentPath/latest.tar.gz

	echo -e "\nFinished upgrading WordPress to version $WpVersionLatest\n\nGoodbye.\n"
else

	echo -e "---> Current version $WpVersionCurrent is the latest available.\n\nNothing to do.\nGoodbye.\n"

fi
