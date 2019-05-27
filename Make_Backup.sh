#!/bin/bash

################################################################################
################################################################################
####                                                                        ####
####     Make_Backup.sh                                                     ####
####                                                                        ####
################################################################################
################################################################################
#																			   #
#	A script to make an incremental backup of all modified files each day...   #
#	This script can backup some hosts each time and keep archive over time.	   #
#																			   #
################################################################################
#														23.03.2019 - 24.04.2019


. /data/.script_common.sh

#==============================================================================#
#==     Ensure we are in a terminal                                          ==#
#==============================================================================#

if [ "$1" != 'SkipTermCheck' ]; then
	ParentProcess="`ps -p $PPID -o comm=`"

#	if [ "$ParentProcess" != "xfce4-terminal" ] && [ "$ParentProcess" != "bash" ]; then
# 		xfce4-terminal --geometry 80x25 -x $0 $*
#	fi

	if [ "$ParentProcess" != 'konsole' ] && [ "$ParentProcess" != 'bash' ]; then
		konsole --profile FooPhoenix --noclose -e $0 SkipTermCheck $*
		exit
	fi
else
	shift
fi



#==============================================================================#
#==     Ensure that the script is executed with root access                  ==#
#==============================================================================#

if [ `id -nu` != "root" ]; then
	sudo "$0" SkipTermCheck $*
	exit
fi


set -eE	# = -o errexit -o errtrace

function getProcessTree()
{
	local _var_name="${1}"
	local _pid _ppid _command  _ppids=( ) _commands=( )

	# Take all elements given by `ps` and store it in arrays.
	# The index of elements is its PID !
	while IFS= read -r _command ; do
		_pid=${_command:0:5}
		_ppid=${_command:6:5}
		_command=${_command:12}

		_ppids[$_pid]="$_ppid"
		_commands[$_pid]="$_command"

# 		printf '%5d %5d %s\n' $_pid $_ppid "$_command"
	done <<< $(ps --no-headers -ax -o pid:5,ppid:5,command ) # For debug : ps --no-headers --forest -ax -o pid:5,ppid:5,command

	#---------------------------------------------------------------------------

	# Build the list of parents process and children process and store it in _pids[]
	# The _children[] array will store how many children has each process
	# The _relationship[] array will manage the output color, 0 = no relation, 1 = parent tree, 2 = myself, 3 = children tree

	local _current_pid="$BASHPID" _pids=( ) _children=( ) _relationship=( )

	# Build parents process list here
	_pid=$_current_pid
	while (( 1 )); do
		_pids+=( $_pid ) # add the current pid
		_pid=${_ppids[$_pid]} # retreive the ppid of the current pid
		_children[$_pid]=1
		_relationship[$_pid]=1
		if (( _pid == 1 )); then
			break
		fi
	done

	local _index _check_pid _children_pids

	# Build children process list here
	_children_pids=( $_current_pid ) # Contain the list of all pid waiting to be evaluated
	_children[$_current_pid]=0
	_relationship[$_current_pid]=2
	_index=0
	while (( _index < ${#_children_pids} )); do
		_pid=${_children_pids[$_index]}
		if (( _pid != 0 )); then
			for _check_pid in ${!_ppids[@]}; do # ${!_ppids[@]} return the list of all pid because each ppid has their own pid as key
				if (( _pid == _ppids[_check_pid] )); then
					_pids+=( $_check_pid ) # add the current checked pid
					_relationship[$_check_pid]=3
					_children[$_check_pid]=0
					(( ++_children[_pid] )) # add one children
					_children_pids+=( $_check_pid ) # add this pid to be evaluated later
				fi
			done
		fi
		(( ++_index ))
	done

	#---------------------------------------------------------------------------

	# sort all pid
	_pids=( $(printf "%s\n" "${_pids[@]}" | sort -n ) )

	# Build children process of the root process in the tree
	_children_pids=( ${_pids[0]} ) # Contain the list of all pid waiting to be evaluated
	_index=0
	while (( _index < ${#_children_pids} )); do
		_pid=${_children_pids[$_index]}
		if (( _pid != 0 )); then
			for _check_pid in ${!_ppids[@]}; do # ${!_ppids[@]} return the list of all pid because each ppid has their own pid as key
				if (( _pid == _ppids[_check_pid] )); then
					if (( _relationship[_check_pid] == 0 )); then # if _relationship[_check_pid] is not 0, so this pid is already in the list, just do nothing
						_pids+=( $_check_pid ) # add the current checked pid
						_relationship[$_check_pid]=0
						_children[$_check_pid]=${_children[$_check_pid]:-0}
						(( ++_children[_pid] )) # add one children
					fi
					_children_pids+=( $_check_pid ) # add this pid to be evaluated later
				fi
			done
		fi
		(( ++_index ))
	done

	#---------------------------------------------------------------------------

	# sort all pid
	_pids=( $(printf "%s\n" "${_pids[@]}" | sort -n ) )

	#---------------------------------------------------------------------------

	local _level _output='' _screen_size=$(( $(tput cols) - 6 ))

	_children_pids=( ${_pids[0]} )
	_index=0
	while (( ${#_children_pids} > 0 )); do

		_pid=${_children_pids[$_index]}
		unset -v _children_pids[$_index]
		_index=$(( _index - 1 ))
		_children_pids=( ${_children_pids[@]} )

		_check_pid=${_ppids[$_pid]}
		_children[$_check_pid]=$(( _children[$_check_pid] - 1 ))

		for _check_pid in ${_pids[@]}; do
			if (( _pid == _ppids[_check_pid] )); then
				_children_pids+=( $_check_pid )
				_index=$(( _index + 1 ))
			fi
		done

		_command=''

		_check_pid=$_pid
		_level=0
		while (( 1 )); do
			_check_pid=${_ppids[$_check_pid]}
			if (( _check_pid == 1 )); then
				break
			fi
			if (( _children[_check_pid] > 0 )); then
				if (( _level == 0 )); then
					_command="├─$_command"
				else
					_command="│ $_command"
				fi
			else
				if (( _level == 0 )); then
					_command="└─$_command"
				else
					_command="  $_command"
				fi
			fi
			(( ++_level ))
		done

		(( _level = _screen_size - ((_level * 2) + 4) ))

		case ${_relationship[$_pid]} in
			0)
				_command="${_command}⬥┈┈ ${_commands[$_pid]:0:$_level}"	;;
			1)
				_command="${_command}\e[2;33m⬥\e[0m┈┈ \e[2;33m${_commands[$_pid]:0:$_level}\e[0m"	;;
			2)
				_command="${_command}\e[0;31m⬥\e[0m┈┈ \e[0;31m${_commands[$_pid]:0:$_level}\e[0m"	;;
			3)
				_command="${_command}\e[0;33m⬥\e[0m┈┈ \e[0;33m${_commands[$_pid]:0:$_level}\e[0m"	;;
		esac

		printf -v _pid '%5d' $_pid
		_output="${_output}${_pid} ${_command}\n"
# 		echo -e "${_pid} ${_command}"
	done

	printf -v $_var_name '%s' "$_output"
}

function error_report()
{
	local _crash_time _crash_after _data _index

	printf -v _crash_time '%(%A %-d %B %Y @ %X)T' -1
	TZ=UTC printf -v _crash_after '%(%X)T' $SECONDS

	local _line_number="${1}"
	local _subshell_level="${2}"
	local _last_exit_status="${3}"
	local _last_command="${4}"

	{
		echo -e "\r\e[0J\n"

		echo -ne "\e[97m[\e[25;31m ERROR \e[97m]\e[0m " # echo a blinking [ ERROR ]
		echo -e "The script has crashed at [\e[1;97m $_crash_time \e[0m] after running [\e[1;97m $_crash_after \e[0m]"
		echo
		echo "  PID   Commands"

		getProcessTree _data
		echo -e "$_data"

		echo
		echo "Calls history :"
		for _index in ${!BASH_LINENO[@]}; do
			printf '%5d ' ${BASH_LINENO[$_index]}
			echo -e "${FUNCNAME[$_index]} \e[2m( in ${BASH_SOURCE[$_index]} )\e[0m"
		done

		echo
		echo -e "Error reported at line \e[0;31m$_line_number\e[0m, last known exit status was \e[0;31m$_last_exit_status\e[0m, the crashed command is :\n"
		echo -e "\t\e[1;31m\e[2m$_last_command\e[0m"

		echo
		echo
	}

	exit 1
}
trap 'error_report "$LINENO" "$BASH_SUBSHELL" "$?" "$BASH_COMMAND" ' ERR QUIT INT TERM


function Toto()
{
	Test1 "${1}" 'to' &

	sleep 2

}

function Test1()
{
	echo $BASH_SUBSHELL $BASH_COMMAND
	echo ${BASH_LINENO[@]} $LINENO
	echo ${FUNCNAME[@]} $LINENO
	echo ${BASH_SOURCE[@]} $LINENO
# 	echo "Error Test" >&2
# 	return 1
{
	(( toto = 10 / titi ))
}
	echo ${BASH_ARGC[@]} ${BASH_ARGV[@]} $LINENO
	sleep 2
}

ps -p ${PARENT_PID:-32760} -ho pid || echo 0



PARENT_PID="$BASHPID"
{
	index=0
	while (( ++index < 100 )); do
		echo -n ''
		sleep 0.5
		echo "toto -- $index"

		if (( $(ps -p ${PARENT_PID:-32760} -ho pid || echo 0) != $PARENT_PID )); then
			echo "I break now !"
			break
		fi
	done
	echo "I exit now !"
} &

sleep 0.5

Toto 12 &

sleep 0.5

echo "ok here $BASHPID"
var="$BASHPID"


sleep 2

exit

# echo -n '' > /dev/shm/test.txt
#
#
# foo="test"
#
# rm -f $foo
# mkfifo $foo
#
# canal=( )
# id=2
#
# exec {canal[$id]}<> "${foo}"
#
# for process in {1..60}; do
# 	{
# 		index=0
# 		while [ $index -lt 1000 ]; do
# 			(( index++ ))
# 			echo "Je suis la ligne n° $index du process $process"  # >> /dev/shm/test.txt
# # 			sleep 0.2
# 		done >&${canal[$id]}; echo ":END:" >&${canal[$id]}
# 	} &
# done
#
#
# end=0
# index=0
# # cat "/dev/shm/test.txt" |
# while read -u ${canal[$id]} Line; do
# 	if [ "$Line" == ":END:" ]; then
# 		if [ $(( ++end )) -eq 60 ]; then
# 			break
# 		fi
# 		continue
# 	fi
# 	if [ $(( ++index % 731 )) -eq 0 ]; then
# 		echo "$Line"
# 	fi
# done
#
# echo "canal : ${canal[$id]}"
#
# exec {canal[$id]}>&-
#
# echo "Index : $index"



# declare -A pipe
#
# pipe[4]=25
# pipe[7]=24
# pipe["toto"]=22
# pipe[titi]=21
#
# echo "${pipe[@]} : ${!pipe[@]}"

#
#
# find -P /root/BackupFolder/TEST -type f,l,p,s,b,c,d -printf '%12s %y %3d %p\n' |
# while IFS= read file_data; do
#
# 	rw=''
# 	type=''
# 	exist=0
#
# 	file_size=${file_data:0:12}
# 	file_type=${file_data:13:1}
# 	file_depth=${file_data:15:3}
# 	file_name=${file_data:19}
#
#
# 	if [ "$type" == 'f' ] || [ "$type" == 'd' ]; then
# 		continue
# 	fi
# 	echo "$file_size - $file_type <> $type ($exist) - ${rw} $file_depth $file_name"
#
# done
#
# exit




#==============================================================================#
#==     Constants Definition                                                 ==#
#==============================================================================#

set -eE	# = -o errexit -o errtrace
printf -v SCRIPT_START_TIME '%(%s)T'		# The script start time

PATH_CurrentScript="${0%/*}"
PATH_LOG='/var/log'
PATH_TMP='/tmp'
PATH_RamDisk='/dev/shm'
PATH_Infrastructures='/root/Infrastructures'
# PATH_Infrastructures='/media/foophoenix/AppKDE/Infrastructures'

#==============================================================================#

PATH_BackupFolder='/root/BackupFolder/TEST'		# The path of the backup folder in the BackupSystem virtual machine...
PATH_HostBackupedFolder='/root/HostBackuped'		# The path of the backup folder in the BackupSystem virtual machine...

STATUS_FOLDER="_Backup_Status_"
CAT_STATUS="Status"
CAT_VARIABLES_STATE="VarState"
CAT_STATISTICS="Statistics"
CAT_FILESLIST="FilesList"


PATH_BackupStatus="/////"
PATH_BackupStatusRAM="/////"
StatisticsFile="/////"
StatisticsFileRAM="/////"

FilesList="////"
FilesListRAM="/////"
IncludeList="////"
ExcludeList="/////"

HOSTS_LIST=( "BravoTower" "Router" )
HOSTS_LIST=( "Router" )

PADDING='                                                                                                                                                                '



#==============================================================================#
#==     Include bases sub-scripts                                            ==#
#==============================================================================#

. $PATH_Infrastructures/BashColors.sh
. $PATH_Infrastructures/BashActions.sh



################################################################################
################################################################################
####                                                                        ####
####     Functions definition                                               ####
####                                                                        ####
################################################################################
################################################################################

function error_report()
{
	echo
	echo -e "$(buildTimer) ${A_Error} Script error (${3}) at line ${1} with command : "
	echo -e "$(buildTimer) ${A_NoAction} ${2}"
	echo

# 	saveCurrentState

	exit 1
}

function getSelectableWord()
{
	local _word _words_list=( ${1,,} )

	local _char_index _char _chars=''
	local _selectable_words="${TF_YELLOW}"

	for _word in ${_words_list[@]}; do
		_char_index=0
		while [ $_char_index -lt ${#_word} ]; do
			_char=${_word:$_char_index:1}
			if [[ $_chars == *${_char^^}* ]]; then
				_selectable_words="${_selectable_words}${_char}"
			else
				_chars="${_chars}${_char^^}"
				_selectable_words="${_selectable_words}${TS_DARK}[${TF_LYELLOW}${TS_BOLD}${_char^^}${TF_YELLOW}${TS_DARK}]${TF_YELLOW}"
				if [ $(( ++_char_index )) -lt ${#_word} ]; then
					_selectable_words="${_selectable_words}${_word:$_char_index}"
				fi
				_selectable_words="${_selectable_words} "
				break
			fi
			(( ++_char_index ))
		done
	done

	_selectable_words="${_selectable_words}${TR_ALL}: "

	echo -en "$_selectable_words"

	local readed_key
	selected_word=0
	while true; do
		read -sn 1 readed_key
		readed_key="${readed_key^^}"

		_char_index=0
		while [ $_char_index -lt ${#_chars} ]; do
			_char=${_chars:$_char_index:1}
			(( ++_char_index ))
			if [ $_char == "$readed_key" ]; then
				selected_word=$_char_index
				break
			fi
		done
		if [ $selected_word -gt 0 ]; then
			break
		fi
	done
}

function getBackupFileName()
{
	local _file_name="${1//\//^}"	# The file name without path. Assume the parameter is not empty.
	local _file_cat="${2}"			# The categorie of the file. Assume the parameter is not empty.
	local _is_ramdisk="${3:-1}"		# 1 = RAM DISK, 0 = HARD DISK. 1 is the default value.
	local _host="${4:-$host_backuped}"

	local _var_name_ram="${5}"
	local _var_name_disk="${6}"

	if [ "$_var_name_ram$_var_name_disk" == '' ]; then
		local _root

		if (( _is_ramdisk == 1 )); then
			_root="$PATH_RamDisk"
		else
			_root="$PATH_BackupFolder"
		fi

		echo "$_root/$STATUS_FOLDER/$_host/${_file_cat}_${_file_name}"
	else
		if [ "$_var_name_ram" != '' ]; then
			printf -v $_var_name_ram "$PATH_RamDisk/$STATUS_FOLDER/$_host/${_file_cat}_${_file_name}"
		fi
		if [ "$_var_name_disk" != '' ]; then
			printf -v $_var_name_disk "$PATH_BackupFolder/$STATUS_FOLDER/$_host/${_file_cat}_${_file_name}"
		fi
	fi
}

function moveBackupFile()
{
	local _file_name="${1}"		# The file name without path. Assume the parameter is not empty.
	local _file_cat="${2}"		# The categorie of the file. Assume the parameter is not empty.
	local _move_direction="${3:-0}"  # 0 = Ram to Disk, 1 = Disk to Ram
	local _host="${3}"

	local _source _destination

	if (( _move_direction == 0 )); then
		getBackupFileName "$_file_name" "$_file_cat" '' "$_host" '_source' '_destination'
	else
		getBackupFileName "$_file_name" "$_file_cat" '' "$_host" '_destination' '_source'
	fi

	if [ -f "$_source" ]; then
		cp -f --remove-destination "$_source" "$_destination"
	fi
}

function checkStatus()
{
	local _status_name="${1}"
	local _full_file_name="$(getBackupFileName "$_status_name" $CAT_STATUS 0)"

	if [ -f "$_full_file_name" ]; then
		echo 'Done'
	else
		echo 'Uncompleted'
	fi
}

function makeStatusDone()
{
	local _status_name="${1}"
	local _full_file_name="$(getBackupFileName "$_status_name" $CAT_STATUS 0)"

	printf '%s %(%s)T\n' 'OK' -1 > "$_full_file_name"
	sync
}

function showTitle()
{
	local _title="${1}"
	local _state="${2:-"${A_NoAction}"}"

	echo -e "$(buildTimer) ${_state} ${TS__BOLD_WHITE}==-=-== ${_title} ==-=-==${TR_ALL}"
	if [ "$_state" != "${A_Skipped}" ]; then
		echo
		sleep 1
	fi
}

function makeBaseFolders()
{
	local _full_folder_name="${1}"

	mkdir -p "$PATH_BackupFolder/$_full_folder_name"
	mkdir -p "$PATH_RamDisk/$_full_folder_name"
	rm -rf "$PATH_RamDisk/$STATUS_FOLDER/$host_folder"/[!_]*
}

function copyFolder()
{
	# ALL Arguments are assumed to be correctly given !!

	#	${1} = Mandatory - STRING: Path        - The source full path.
	#	${2} = Mandatory - STRING: Path        - The destination full path.
	#	${3} = Mandatory - STRING: Folder Name - The full relative folder name to copy from source to destination.

	local _folder_name="${3}"
	local _source="${1}/$_folder_name"
	local _destination="${2}/$_folder_name"

	if [ -d "$_source" ]; then
		local _check_destination

		checkItemType "$_destination" '_check_destination'

		if [ "$_check_destination" == '?' ]; then
			mkdir "$_destination"
		fi

		if [ "$_check_destination" == '?' ] || [ "$_check_destination" == 'd' ]; then
			local _rights=( $(stat -c "%a %u %g" "$_source") )

			chown ${_rights[1]}:${_rights[2]} "$_destination"
			chmod ${_rights[0]} "$_destination"
		else
			echo "function copyFolder() : "
		fi
	fi
}

function copyFullPath()
{
	local _source_path="${1}"
	local _destination_path="${2}"
	local _full_relative_folder_name="${3}"

	if [ ! -d "$_destination_path/$_full_relative_folder_name" ]; then
		if [ -d "$_source_path/$_full_relative_folder_name" ]; then
			local _folders_list _folder_name

			IFS='/' read -a _folders_list <<< "$_full_relative_folder_name"

			_full_relative_folder_name=''
			for _folder_name in "${_folders_list[@]}"; do
				_full_relative_folder_name="$_full_relative_folder_name/$_folder_name"

				if [ ! -d "$_destination_path/${_full_relative_folder_name:1}" ]; then
					copyFolder "$_source_path" "$_destination_path" "${_full_relative_folder_name:1}"
				fi
			done
		fi
	fi
}

function getFileSizeV()
{
	local _full_file_name="${1}"
	local _var_name="${2}"

	local _file_size

	if [ -f "$_full_file_name" ]; then
		_file_size="$(stat --format=%s "$_full_file_name")"
	else
		_file_size=0
	fi

	printf -v ${_var_name} '%d' $_file_size
}

function getFileSize()
{
	local _full_file_name="${1}"

	local _file_size_

	getFileSize "$_full_file_name" '_file_size_'

	echo "$_file_size_"
}

EMPTY_SIZE='               '
FOLDER_SIZE="      directory"
SYMLINK_SIZE="       sym-link"
UNKNOWN_SIZE="        ??? ???"
function formatSizeV()
{
	local _size_="${1}"
	local _padding="${2}"
	local _var_name="${3}"

	printf -v _size_ '%15d' $_size_

	if [ "${_size_:9:3}" == '   ' ]; then
		_size_="            ${TF_WHITE}${_size_:12:3}${TR_ALL}"
	elif [ "${_size_:6:3}" == '   ' ]; then
		_size_="         ${TF_GREEN}${_size_:9:3}${TF__WHITE}${_size_:12:3}${TR_ALL}"
	elif [ "${_size_:3:3}" == '   ' ]; then
		_size_="      ${TF_YELLOW}${_size_:6:3}${TF__GREEN}${_size_:9:3}${TF__WHITE}${_size_:12:3}${TR_ALL}"
	elif [ "${_size_:0:3}" == '   ' ]; then
		_size_="   ${TF_RED}${_size_:3:3}${TF__YELLOW}${_size_:6:3}${TF__GREEN}${_size_:9:3}${TF__WHITE}${_size_:12:3}${TR_ALL}"
	else
		_size_="${TF_CYAN}${_size_:0:3}${TF__RED}${_size_:3:3}${TF__YELLOW}${_size_:6:3}${TF__GREEN}${_size_:9:3}${TF__WHITE}${_size_:12:3}${TR_ALL}"
	fi

	if (( _padding == 0 )); then
		_size_="${_size_// /}"
	fi

	printf -v $_var_name '%s' "$_size_"
}

function formatSize()
{
	local _size="${1}"
	local _padding="${2}"

	formatSizeV "$_size" $_padding '_size'

	echo "$_size"
}

function checkItemType()
{
	local _file_name="${1}" _type
	local _var_name="${2}"


	if [ -e "$_file_name" ]; then
		if [ -f "$_file_name" ]; then
			_type='f'
		elif [ -d "$_file_name" ]; then
			_type='d'
		elif [ -L "$_file_name" ]; then
			_type='L'
		elif [ -p "$_file_name" ]; then
			_type='p'
		elif [ -S "$_file_name" ]; then
			_type='s'
		elif [ -b "$_file_name" ]; then
			_type='b'
		elif [ -c "$_file_name" ]; then
			_type='c'
		fi
	else
		if [ -L "$_file_name" ]; then
			_type='L'
		else
			_type='?'
		fi
	fi

	printf -v $_var_name '%s' "$_type"
}

TIME_SIZE='[00:00:00]'
function buildTimerV()
{
	local _var_name="${1}"

	local __duration

	printf -v __duration '%(%s)T' -1
	__duration=$(( __duration - SCRIPT_START_TIME ))

	TZ=UTC printf -v "$_var_name" "%(${TF_WHITE}[${TF__YELLOW}%H${TF__WHITE}:${TF__LGRAY}%M:${TF__DGRAY}%S${TF__WHITE}]${TR_ALL})T" $__duration
}

function buildTimer()
{
	local _timer

	buildTimerV '_timer'

	echo "$_timer"
}

function getPercentageV()
{
	local _value="${1}"
	local _divisor="${2}"
	local _var_name="${3}"

	local _t1 _t2 _P1 _P2

	(( _divisor = _divisor ? _divisor : 1, _t1 = _value * 100, _t2 = _t1 % _divisor, _P1 = _t1 / _divisor, _P2 = (_t2 * 10000) / _divisor, 1 ))

	printf -v $_var_name '%3d.%04d%%' $_P1 $_P2
}

function shortenFileNameV()
{
	local _full_file_name="${1}"
	local _max_size="${2}"
	local _var_name="${3}"

	if [ ${#_full_file_name} -gt $_max_size ]; then
		local _folder_slash=''

		if [ "${_full_file_name:(-1)}" == '/' ]; then
			_folder_slash='/'
			_full_file_name="${_full_file_name%%/}"
		fi

		local _file_name="${_full_file_name##*/}$_folder_slash"
		local _path_name="${_full_file_name%/*}/"
		local _file_name_size=${#_file_name}
		local _path_name_size=${#_path_name}

		local _cut_size_part1 _cut_size_part2 _cut_size=$_file_name_size

		if [ $_file_name_size -gt 48 ]; then
			(( 	_cut_size = _max_size - (_path_name_size + 48),
				_cut_size = _cut_size > 0 ? _cut_size + 48 : 48,
				_cut_size_part1 = (_cut_size / 2) - 3 + (_cut_size % 2),
				_cut_size_part2 = (_cut_size / 2) ))

			_file_name="${_file_name:0:$_cut_size_part1}...${_file_name:(-$_cut_size_part2)}"
		fi

		(( _cut_size = _max_size - _cut_size ))

		if [ $_path_name_size -gt $_cut_size ]; then
			(( 	_cut_size_part1 = (_cut_size / 2) - 3 + (_cut_size % 2),
				_cut_size_part2 = (_cut_size / 2) ))

			_path_name="${_path_name:0:$_cut_size_part1}...${_path_name:(-$_cut_size_part2)}"
		fi

		printf -v $_var_name '%s%s' "$_path_name" "$_file_name"
	else
		printf -v $_var_name '%s' "$_full_file_name"
	fi
}

function getUpdateFlagsV()
{
	local _flags_="${1//./ }"
	local _var_name="${2}"

	if [ "${_flags_:0:6}" != '      ' ]; then
		_flags_="${_flags_^^}"
		printf -v $_var_name '%s' "${TF_RED}${_flags_:0:1}${TF__YELLOW}${_flags_:1:1}${TF__YELLOW}${_flags_:2:1}${TF__MAGENTA}${_flags_:3:1}${TF__LMAGENTA}${_flags_:4:1}${TF__LMAGENTA}${_flags_:5:1}${TR_ALL}"
	else
		printf -v $_var_name '%s' "${TB_RED}${TF__YELLOW}??????${TR_ALL}"
	fi
}

function getIsExcludedV()
{
	local _full_file_name="${1}"
	local _excluded_files_list="${2}"
	local _var_name="${3}"

	local _is_excluded='r'

	local _full_file_name_size=${#_full_file_name}
	local _excluded_path _excluded_path_size

	while read _excluded_path; do
		if [ "$_excluded_path" == '' ]; then
			continue
		fi

		_excluded_path_size=${#_excluded_path}

		if [ $_full_file_name_size -lt $_excluded_path_size ]; then
			continue
		fi

		if [ "$_excluded_path" == "${_full_file_name:0:$_excluded_path_size}" ]; then
			if [ "${_full_file_name:${_excluded_path_size}:1}" == '/' ]; then
				_is_excluded='e'
				break
			elif [ $_full_file_name_size -eq $_excluded_path_size ]; then
				_is_excluded='e'
				break
			fi
		fi
	done < "$_excluded_files_list"

	printf -v $_var_name '%s' $_is_excluded
}

function initVariablesState_Rotation()
{
	RotationNewDay=0
	RotationNewWeek=0
	RotationNewMonth=0
	RotationNewYear=0
	rotation_status=''
	rotation_status_size=''
	DayOfWeek=0
	RotationLastDate=''
}

function saveVariablesState_Rotation()
{
	local _full_file_name="$(getBackupFileName 'Rotation' "$CAT_VARIABLES_STATE" 0)"

	echo "
	$RotationNewDay
	$RotationNewWeek
	$RotationNewMonth
	$RotationNewYear
	${rotation_status// /%}
	${rotation_status_size// /%}
	$DayOfWeek
	${RotationLastDate// /%}" > "$_full_file_name"
}

function loadVariablesState_Rotation()
{
	local _full_file_name="$(getBackupFileName 'Rotation' "$CAT_VARIABLES_STATE" 0)"
	local _values

	_values=( $(cat "$_full_file_name") )
	RotationNewDay="${_values[0]}"
	RotationNewWeek="${_values[1]}"
	RotationNewMonth="${_values[2]}"
	RotationNewYear="${_values[3]}"
	rotation_status="${_values[4]//%/ }"
	rotation_status_size="${_values[5]//%/ }"
	DayOfWeek="${_values[6]}"
	RotationLastDate="${_values[7]//%/ }"
}

function initVariablesState_Rotation_Statistics()
{
	count_files_trashed=0
	count_size_trashed=0
	count_files_rotation=0
	count_size_rotation=0
}

function saveVariablesState_Rotation_Statistics()
{
	local _full_file_name="$(getBackupFileName "Count_GlobalRotation" "$CAT_VARIABLES_STATE" 0)"

	echo "
	$count_files_trashed
	$count_size_trashed
	$count_files_rotation
	$count_size_rotation" > "$_full_file_name"
}

function loadVariablesState_Rotation_Statistics()
{
	local _full_file_name="$(getBackupFileName "Count_GlobalRotation" "$CAT_VARIABLES_STATE" 0)"
	local _values

	_values=( $(cat "$_full_file_name") )
	count_files_trashed="${_values[0]}"
	count_size_trashed="${_values[1]}"
	count_files_rotation="${_values[2]}"
	count_size_rotation="${_values[3]}"
}

function initVariablesState_Step_1_Statistics()
{
	file_count_total=0
	file_count_added=0
	file_count_updated1=0
	file_count_updated2=0
	file_count_removed=0
	file_count_excluded=0
	file_count_uptodate=0
	file_count_skipped=0

	file_count_size_total=0
	file_count_size_added=0
	file_count_size_updated1=0
	file_count_size_updated2=0
	file_count_size_removed=0
	file_count_size_excluded=0
	file_count_size_uptodate=0
	file_count_size_skipped=0
}

function saveVariablesState_Step_1_Statistics()
{
	local _full_file_name="$(getBackupFileName "Count_Step_1" "$CAT_STATISTICS" 0)"

	echo "
	$file_count_total
	$file_count_added
	$file_count_updated1
	$file_count_updated2
	$file_count_removed
	$file_count_excluded
	$file_count_uptodate
	$file_count_skipped
	$file_count_size_total
	$file_count_size_added
	$file_count_size_updated1
	$file_count_size_updated2
	$file_count_size_removed
	$file_count_size_excluded
	$file_count_size_uptodate
	$file_count_size_skipped" > "$_full_file_name"
}

function loadVariablesState_Step_1_Statistics()
{
	local _full_file_name="$(getBackupFileName "Count_Step_1" "$CAT_STATISTICS" 0)"
	local _values

	_values=( $(cat "$_full_file_name") )
	file_count_total="${_values[0]}"
	file_count_added="${_values[1]}"
	file_count_updated1="${_values[2]}"
	file_count_updated2="${_values[3]}"
	file_count_removed="${_values[4]}"
	file_count_excluded="${_values[5]}"
	file_count_uptodate="${_values[6]}"
	file_count_skipped="${_values[7]}"

	file_count_size_total="${_values[8]}"
	file_count_size_added="${_values[9]}"
	file_count_size_updated1="${_values[10]}"
	file_count_size_updated2="${_values[11]}"
	file_count_size_removed="${_values[12]}"
	file_count_size_excluded="${_values[13]}"
	file_count_size_uptodate="${_values[14]}"
	file_count_size_skipped="${_values[15]}"
}

function initVariablesState_Step_2()
{
	progress_total_item_1=$file_count_excluded
	progress_total_size_1=$file_count_size_excluded
	progress_current_item_1_processed=0
	progress_current_size_1_processed=0
	progress_current_item_1_remaining=$progress_total_item_1
	progress_current_size_1_remaining=$progress_total_size_1
}

function initVariablesState_Step_2_Statistics()
{
	progress_total_item_2=0
	progress_total_size_2=0
}

function showProgress_CountFiles()
{
	local _timer _size _count

	buildTimerV _timer
	formatSizeV $_count_size 1 '_size'
	printf -v _count '%9d' $_count_files

	echo -ne "$_timer Count : $_count $_size - $_full_relative_folder_name${TM_ClearEndLine}\r"
}

function countFiles()
{
	local _full_relative_folder_name="${1}"

	if [ "$(checkStatus "Count_$_full_relative_folder_name")" == 'Uncompleted' ]; then

		local _source_folder="$PATH_BackupFolder/$_full_relative_folder_name"
		local _skip_output=0

		local _count_full_file_name="$(getBackupFileName "Count_$_full_relative_folder_name" "$CAT_STATISTICS" 0)"
		local _log_full_file_name="$(getBackupFileName "Count_LOG_$_full_relative_folder_name" "$CAT_STATISTICS")"
		echo -n '' > "$_log_full_file_name"

		local _file_data _file_size _count_files=0 _count_size=0

		showProgress_CountFiles

		exec {pipe_id[1]}<>"$MAIN_PIPE"
		exec {pipe_id[2]}>"$_log_full_file_name"

		{
			find -P "$_source_folder" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n'
			echo ':END:'
		} >&${pipe_id[1]} &

		while IFS= read -u ${pipe_id[1]} _file_data; do
			if [ ':END:' == "$_file_data" ]; then
				break
			fi

			echo "$_file_data" >&${pipe_id[2]}

			_file_size=${_file_data:0:12}

			(( _count_size += _file_size, ++_count_files ))

			if [ $(( ++_skip_output % 653 )) -eq 0 ]; then
				showProgress_CountFiles
			fi
		done

		exec {pipe_id[1]}>&-
		exec {pipe_id[2]}>&-

		showProgress_CountFiles
		if [ $_count_files -ne 0 ]; then
			echo
		fi

		echo "$_count_files $_count_size" > "$_count_full_file_name"
		keepBackupFile "Count_log_$_full_relative_folder_name" "$CAT_STATISTICS"

		makeStatusDone "Count_$_full_relative_folder_name"
	fi
}

function showProgress_Rotation()
{
	local _timer _file_name_text _size1 _size2 _size3 _size4

	buildTimerV _timer
	shortenFileNameV "/$_file_name" "$_max_file_name_size" '_file_name_text'
	formatSizeV $_file_size 1 _size1
	formatSizeV $count_size_trashed 0 _size2
	formatSizeV $_count_size 0 _size3
	formatSizeV $count_size_rotation 0 _size4

	echo -e "$_timer $_action $_size1 ${_action_color}$_file_name_text${TR_ALL}${TM_ClearEndLine}"
	echo -e "$_timer $_action_context : ${TF_RED}${count_files_trashed} $_size2 - ${TF_WHITE}${_count_files} $_size3 / ${TF_WHITE}${count_files_rotation} $_size4 ${TR_ALL}${TM_ClearEndLine}"
	echo -ne "$_timer $rotation_status $RotationLastDate\r${TM_Up1}"
}

function removeTrashedContent()
{
	if [ "$(checkStatus 'Rotation_Trashed')" == 'Uncompleted' ]; then
		local _source_folder="$PATH_BackupFolder/_Trashed_"
		local _file_data _file_name='/' _file_size=0 _count_files=0 _count_size=0

		local _count_full_file_name="$(getBackupFileName "Count_TrashedContent" "$CAT_STATISTICS" 0)"
		local _log_full_file_name="$(getBackupFileName "Count_LOG_TrashedContent" "$CAT_STATISTICS")"

		local _max_file_name_size="$TIME_SIZE ${A_ActionSpace} $EMPTY_SIZE "
		(( _max_file_name_size = $(tput cols) - ${#_max_file_name_size} ))

		exec {pipe_id[1]}<>"$MAIN_PIPE"
		exec {pipe_id[2]}>"$_log_full_file_name"

		{
			find -P "$_source_folder" -type f,l,p,s,b,c -printf "%12s %y %3d %P\n" -delete
			echo ':END:'
		} >&${pipe_id[1]} &

		local _action="${A_Removed}"
		local _action_color="${TF_RED}"
		local _action_context="Cleaning the trashed content"

		while IFS= read -u ${pipe_id[1]} _file_data; do
			if [ ':END:' == "$_file_data" ]; then
				break
			fi

			echo "$_file_data" >&${pipe_id[2]}

			_file_size=${_file_data:0:12}
			_file_name="_Trashed_/${_file_data:19}"

			(( count_size_trashed += _file_size, ++count_files_trashed ))

			rm -f "$_source_folder/$_file_name"

			showProgress_Rotation
		done

		exec {pipe_id[1]}>&-
		exec {pipe_id[2]}>&-

		echo "$count_files_trashed $count_size_trashed" > "$_count_full_file_name"
		keepBackupFile "Count_log_TrashedContent" "$CAT_STATISTICS"
		saveVariablesState_Rotation_Statistics

		echo -ne "${TM_ClearLine}\n${TM_ClearLine}\r"

		makeStatusDone 'Rotation_Trashed'
	else
		echo -e "$(buildTimer) ${A_Skipped} : Cleaning the trashed content"
	fi
}

function rotateFolder()
{
	local _source="${1}"
	local _destination="${2}"

	if [ "$(checkStatus "Rotation_$_source")" == 'Uncompleted' ]; then
		local _source_folder="$PATH_BackupFolder/${_source}"
		local _destination_folder="$PATH_BackupFolder/${_destination}"
		local _excluded_folder="$PATH_BackupFolder/_Trashed_/Rotation/${destination}"

		local _file_data _file_name='/' _file_size=0 _count_files=0 _count_size=0 _path_name _check_dest

		local _count_full_file_name="$(getBackupFileName "Count_Rotation_${_source}" "$CAT_STATISTICS" 0)"
		local _log_full_file_name="$(getBackupFileName "Count_LOG_Rotation_${_source}" "$CAT_STATISTICS")"

		local _action='' _conflict _action_color
		local _action_context="Rotation of ${TF_WHITE}${_source}${TR_ALL} in ${_destination}"

		local _max_file_name_size="$TIME_SIZE ${A_ActionSpace} $EMPTY_SIZE "
		(( _max_file_name_size = $(tput cols) - ${#_max_file_name_size} ))

		exec {pipe_id[1]}<>"$MAIN_PIPE"
		exec {pipe_id[2]}>"$_log_full_file_name"

		{
			find -P "$_source_folder" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n'
			echo ':END:'
		} >&${pipe_id[1]} &

		while IFS= read -u ${pipe_id[1]} _file_data; do
			if [ ':END:' == "$_file_data" ]; then
				break
			fi

			_file_size=${_file_data:0:12}
			_file_name="${_file_data:19}"
			_path_name="${_file_name%/*}"
			checkItemType "$_destination_folder/$_file_name" '_check_dest'

			if [ "$_check_dest" != "?" ]; then

				copyFullPath "$_destination_folder" "$_excluded_folder" "$_path_name"
				mv -f "$_destination_folder/$_file_name" "$_excluded_folder/$_file_name"

				_conflict=1
				_action="${A_Backuped}"
				_action_color="${TF_YELLOW}"
			else
				_conflict=0
				_action="${A_Moved}"
				_action_color="${TF_GREEN}"
			fi

			echo "$_conflict $_file_data" >&${pipe_id[2]}

			(( count_size_rotation += _file_size, ++count_files_rotation, _count_size += _file_size, ++_count_files ))

			copyFullPath "$_source_folder" "$_destination_folder" "$_path_name"
			mv -f "$_source_folder/$_file_name" "$_destination_folder/$_file_name"

			_file_name="$_source/$_file_name"
			showProgress_Rotation
		done

		exec {pipe_id[1]}>&-
		exec {pipe_id[2]}>&-

		echo "$_count_files $_count_size" > "$_count_full_file_name"
		keepBackupFile "Count_LOG_Rotation_${_source}" "$CAT_STATISTICS"
		saveVariablesState_Rotation_Statistics

		echo -ne "${TM_ClearLine}\n${TM_ClearLine}\r"

		makeStatusDone "Rotation_$_source"
	else
		echo -e "$(buildTimer) ${A_Skipped} : Rotation of ${TF_WHITE}${_source}${TR_ALL} in ${_destination}"
	fi
}

function openFilesListsSpliter()
{
	local _dest_file_name="${1}"
	local _dest_file_canal="${2}"

	local _pipes_file _canal _output_file_name
	local _file_data _file_name='/' _file_size=0 _min_size _max_size

	_pipes_file="$(getBackupFileName "${_dest_file_name}-${_dest_file_canal}" "PIPE" 1 "PIPES")"
	rm -f "$_pipes_file"
	mkfifo "$_pipes_file"
	exec {pipe_id[$_dest_file_canal]}<>"$_pipes_file"

	{
		for _canal in {1..9}; do
			_output_file_name="$(getBackupFileName "${_dest_file_name}-${_canal}" "$CAT_FILESLIST" 1)"

			echo -n '' > "$_output_file_name"
			exec {pipe_id[$_canal]}>"$_output_file_name"
		done

		while IFS= read -u ${pipe_id[$_dest_file_canal]} _file_data; do
			if [ ':END:' == "$_file_data" ]; then
				break
			fi
			_file_size="${_file_data:0:12}"
			_file_name="${_file_data:13}"

			if (( _file_size < 1000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[1]}
			elif (( _file_size < 10000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[2]}
			elif (( _file_size < 100000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[3]}
			elif (( _file_size < 1000000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[4]}
			elif (( _file_size < 10000000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[5]}
			elif (( _file_size < 100000000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[6]}
			elif (( _file_size < 1000000000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[7]}
			elif (( _file_size < 10000000000 )); then
				echo "$_file_size $_file_name" >&${pipe_id[8]}
			else
				echo "$_file_size $_file_name" >&${pipe_id[9]}
			fi
		done

		for _canal in {1..9}; do
			exec {pipe_id[$_canal]}>&-
		done
	} &
}

function closeFilesListsSpliter()
{
	local _dest_file_name="${1}"
	local _dest_file_canal="${2}"

	local _pipes_file _canal _output_file_name
	local _file_data _file_name='/' _file_size=0 _min_size _max_size

	_pipes_file="$(getBackupFileName "${_dest_file_name}-${_dest_file_canal}" "PIPE" 1 "PIPES")"
	exec {pipe_id[$_dest_file_canal]}>&-
	rm -f "$_pipes_file"

	for _canal in {1..9}; do
		keepBackupFile "${_dest_file_name}-${_canal}" "$CAT_FILESLIST"
	done
}

function updateLastAction()
{
	local _action="${1}"

	if (( __LastAction != _action )); then
		__LastAction=$_action
		case $_action in
			1)
				action_tag="$A_UpToDate"
				action_color="${TF_GREEN}"
				action__flags='      '
				;;
			2)
				action_tag="$A_Updated"
				action_color="${TF_YELLOW}"
				;;
			3)
				action_tag="$A_Updated"
				action_color="${TF_YELLOW}"
				;;
			4)
				action_tag="$A_Skipped"
				action_color="${TF_CYAN}"
				action__flags='      '
				;;
			51)
				action_tag="$A_Removed"
				action_color="${TF_RED}"
				action__flags='      '
				;;
			52)
				action_tag="$A_Excluded"
				action_color="${TF_LRED}"
				action__flags='      '
				;;
			6)
				action_tag="$A_Added"
				action_color="${TF_LBLUE}"
				action__flags='      '
				;;

		esac
	fi
}

function showProgress_Step_1()
{
	local _check_timer _file_name_text _file_size

	printf -v _check_timer '%(%s)T'
	if (( $_check_timer > $__LastTime )); then
		__LastTime=$_check_timer

		local _size_total _size_uptodate _size_updated _size_removed _size_excluded _size_added _align_size _file_count_updated

		buildTimerV timer

		formatSizeV "$file_count_size_total" 1 _size_total
		formatSizeV "$file_count_size_uptodate" 1 _size_uptodate
		formatSizeV "$file_count_size_updated1" 1 _size_updated
		formatSizeV "$file_count_size_removed" 1 _size_removed
		formatSizeV "$file_count_size_excluded" 1 _size_excluded
		formatSizeV "$file_count_size_added" 1 _size_added
		formatSizeV "$file_count_size_skipped" 1 _size_skipped

		max_file_name_size="$TIME_SIZE ${A_ActionSpace} $EMPTY_SIZE ?????? "
		(( _file_count_updated = file_count_updated1 + file_count_updated2, _align_size = ${#action_context_size} - ${#rotation_status_size} - 1, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

		printf -v step_1_progress1 "${TF_WHITE}%15d ${TF__GREEN}%15d ${TF__LBLUE}%15d ${TF__YELLOW}%15d ${TF__RED}%15d ${TF__LRED}%15d ${TF__CYAN}%15d" ${file_count_total} ${file_count_uptodate} ${file_count_added} ${_file_count_updated} ${file_count_removed} ${file_count_excluded} ${file_count_skipped}

		step_1_progress1="$timer $action_context $step_1_progress1"
		step_1_progress2="$timer $rotation_status ${PADDING:0:$_align_size} $_size_total $_size_uptodate $_size_added $_size_updated $_size_removed $_size_excluded $_size_skipped"
	fi

	shortenFileNameV "/$file_name" "$max_file_name_size" '_file_name_text'

	if (( file_type == TYPE_FOLDER )); then
		_file_size="${action_color}${TS_DARK}$FOLDER_SIZE${TR_ALL}"
		_file_name_text="${action_color}${TS_DARK}$_file_name_text"
	elif (( file_type == TYPE_SYMLINK )); then
		_file_size="${action_color}${TS_ITALIC}$SYMLINK_SIZE${TR_ALL}"
		_file_name_text="${action_color}${TS_ITALIC}$_file_name_text"
	else
		formatSizeV $file_size 1 '_file_size'
		_file_name_text="${action_color}$_file_name_text"
	fi

	echo -e "$timer $action_tag $_file_size $action__flags $_file_name_text${TR_ALL}${TM_ClearEndLine}"
	echo -e "$step_1_progress1${TR_ALL}"
	echo -ne "$step_1_progress2${TR_ALL}\r${TM_Up1}"
}

function showProgress_Step_2()
{
	local _timer _file_name_text _size_1 _size_2

	buildTimerV _timer

	shortenFileNameV "/$file_name" "$max_file_name_size" '_file_name_text'
	formatSize $file_size 1 '_size_1'
	formatSize $progress_total_size_2 1 '_size_2'

	printf -v step_2_progress3 "+ ${TF_LRED}%15d" ${progress_total_item_2}

	echo -e "$timer $action_tag $_size_1 $_file_name_text${TR_ALL}${TM_ClearEndLine}"
	echo -e "$timer $action_context $step_2_progress1 $step_2_progress3${TR_ALL}"
	echo -ne "$timer $rotation_status ${PADDING:0:$align_size} $step_2_progress2 $progress_total_size_2${TR_ALL}\r${TM_Up1}"
}



# host_backuped='INIT'
#
# for host_folder in "$host_backuped" "${HOSTS_LIST[@]}" "$CAT_FILESLIST" "PIPES"; do
# 	mkdir -p "$PATH_BackupFolder/$STATUS_FOLDER/$host_folder"
# 	mkdir -p "$PATH_RamDisk/$STATUS_FOLDER/$host_folder"
# 	rm -rf $PATH_RamDisk/$STATUS_FOLDER/$host_folder/[!_]*
# done
#
# host_backuped='Router'
#
# pipe_id=( )
# MAIN_PIPE="$(getBackupFileName "Main-Stream" "PIPE" 1 "PIPES")"
#
# rm -f "$MAIN_PIPE"
# mkfifo "$MAIN_PIPE"
#
# openFilesListsSpliter "data-10" 10
# openFilesListsSpliter "data-20" 20
# openFilesListsSpliter "data-30" 30
# openFilesListsSpliter "data-40" 40
# openFilesListsSpliter "data-50" 50
# openFilesListsSpliter "data-60" 60
#
# time {
# 	for num in {1..300000}; do
# 		printf -v time '%(%s)T' -1
# 		(( cat = (RANDOM % 13) + 2, range = 10 ** cat, number = ((RANDOM * RANDOM * RANDOM) + time) % range, 1 ))
# 		printf '%15d %s %d\n' $number "The file name of 10 is :" $number >&${pipe_id[10]}
# 		printf '%15d %s %d\n' $number "The file name of 20 is :" $number >&${pipe_id[20]}
# 		printf '%15d %s %d\n' $number "The file name of 30 is :" $number >&${pipe_id[30]}
# 		printf '%15d %s %d\n' $number "The file name of 40 is :" $number >&${pipe_id[40]}
# 		printf '%15d %s %d\n' $number "The file name of 50 is :" $number >&${pipe_id[50]}
# 		printf '%15d %s %d\n' $number "The file name of 60 is :" $number >&${pipe_id[60]}
# 	done
# 	echo ':END:'
# 	echo ':END:' >&${pipe_id[10]}
# }
# sleep 3
#
# closeFilesListsSpliter "data-10" 10
# closeFilesListsSpliter "data-20" 20
# closeFilesListsSpliter "data-30" 30
# closeFilesListsSpliter "data-40" 40
# closeFilesListsSpliter "data-50" 50
# closeFilesListsSpliter "data-60" 60
#
# exit


################################################################################
################################################################################
####                                                                        ####
####     The main script code                                               ####
####                                                                        ####
################################################################################
################################################################################

BRUTAL=0		# 1 = Force a whole files backup to syncronize all !! (can be very very looooong...)

host_backuped='INIT'

trap 'error_report $LINENO "$BASH_COMMAND" "$?"' ERR QUIT INT TERM

for host_folder in "$host_backuped" "${HOSTS_LIST[@]}" "PIPES"; do
	mkdir -p "$PATH_BackupFolder/$STATUS_FOLDER/$host_folder"
	mkdir -p "$PATH_RamDisk/$STATUS_FOLDER/$host_folder"
	rm -rf $PATH_RamDisk/$STATUS_FOLDER/$host_folder/[!_]*
done

pipe_id=( )
MAIN_PIPE="$(getBackupFileName "Main-Stream" "PIPE" 1 "PIPES")"

rm -f "$MAIN_PIPE"
mkfifo "$MAIN_PIPE"

if [ "$BRUTAL" -ne 0 ]; then
	echo
	echo -e "${A_Warning} Backup is in ${TF_RED}BRUTAL MODE${TR_ALL}, this will take a VERY LONG time !!"
	echo -ne "${A_NoAction} Do you want to continue anyway ? "; getSelectableWord "Yes No"
	case $selected_word in
		1)
			echo -e "\r${A_OK}"
			;;
		2)
			echo -e "\r${A_Aborted}"
			exit 1
			;;
	esac
fi

if [ "$(checkStatus 'Rotation')" == 'Done' ]; then
	echo
	echo -e "${A_Warning} A backup is already ${TF_RED}IN PROGRESS${TR_ALL} but has probably crash..."
	echo -ne "${A_NoAction} Do you want to try to continue, or start a new one ? "; getSelectableWord "Continue New"
	case $selected_word in
		1)
			echo -e "\r${A_OK}"
			;;
		2)
			echo -e "\r${A_Aborted}"
			for host_folder in "$host_backuped" "${HOSTS_LIST[@]}"; do
				rm -rf $PATH_BackupFolder/$STATUS_FOLDER/$host_folder/[!_]*
			done
			;;
	esac
fi
echo

sync
for host_folder in "$host_backuped" "${HOSTS_LIST[@]}"; do
	if [ "$(find "$PATH_BackupFolder/$STATUS_FOLDER/$host_folder/" -type f -name "[!_]*" -print)" != '' ]; then
		cp -rf --remove-destination $PATH_BackupFolder/$STATUS_FOLDER/$host_folder/[!_]* $PATH_RamDisk/$STATUS_FOLDER/$host_folder/
	fi
done



################################################################################
##      Make rotation of archived files                                       ##
################################################################################

if [ "$(checkStatus 'Rotation_Finished')" == 'Uncompleted' ]; then
	showTitle "Rotation of the archived files..."



#==============================================================================#
#==     Find who need to be rotated                                          ==#
#==============================================================================#

	if [ "$(checkStatus 'Rotation')" == 'Uncompleted' ]; then

		initVariablesState_Rotation

		buildTimerV timer
		if [ -f "$PATH_BackupFolder/$STATUS_FOLDER/_LastBackupDate" ]; then
			BackupLastDate=( $(cat "$PATH_BackupFolder/$STATUS_FOLDER/_LastBackupDate") )

			(( LastBackupSince = SCRIPT_START_TIME - BackupLastDate[4], Days = LastBackupSince / 86400, Hours = (LastBackupSince % 86400) / 3600, Minutes = ((LastBackupSince % 86400) % 3600) / 60, 1 ))

			echo -e "${timer} ${A_NoAction} : The last backup was at $(cat "$PATH_BackupFolder/$STATUS_FOLDER/_LastBackupDate.txt"), ${TS__BOLD_WHITE}$Days${TF_WHITE} day(s) ${TS__BOLD_WHITE}$Hours${TF_WHITE} hour(s) ${TS__BOLD_WHITE}$Minutes${TF_WHITE} minute(s)${TR_ALL} ago"
			RotationLastDate="The last backup was at $(cat "$PATH_BackupFolder/$STATUS_FOLDER/_LastBackupDate.txt"), ${TS__BOLD_WHITE}$Days${TF_WHITE} day(s) ${TS__BOLD_WHITE}$Hours${TF_WHITE} hour(s) ${TS__BOLD_WHITE}$Minutes${TF_WHITE} minute(s)${TR_ALL} ago"
		else
			BackupLastDate=( 0 0 0 0 0 )
			RotationLastDate="This backup is the first one !"
		fi

		BackupCurrentDateTXT="$(date '+%A %-d %B %Y @ %X')"
		BackupCurrentDate=( $(date '+%-V %-d %-m %-Y %s %-H') )
		DayOfWeek="$(date '+%w')"
		if [ "${BackupCurrentDate[5]}" -lt 5 ]; then
			BackupCurrentDate=( $(date -d yesterday '+%-V %-d %-m %-Y') $(date '+%s') )
			DayOfWeek="$(date -d yesterday '+%w')"
		fi

		if [ "${BackupCurrentDate[3]}" -gt "${BackupLastDate[3]}" ]; then
			RotationNewYear=1
			RotationNewMonth=1
			RotationNewDay=1
		else
			if [ "${BackupCurrentDate[2]}" -gt "${BackupLastDate[2]}" ]; then
				RotationNewMonth=1
				RotationNewDay=1
			elif [ "${BackupCurrentDate[1]}" -gt "${BackupLastDate[1]}" ]; then
				RotationNewDay=1
			fi
		fi

		if [ "${BackupCurrentDate[0]}" -gt "${BackupLastDate[0]}" ]; then
			RotationNewWeek=1
		elif [ "${BackupCurrentDate[0]}" -eq 1 ] && [ "${BackupLastDate[0]}" -ne 1 ]; then
			RotationNewWeek=1
		fi

# 		{
# 			RotationNewDay=1
# 		}

		if [ "$RotationNewDay" -eq 1 ]; then
			rotation_status="${TF_GREEN}NEW-DAY "
			rotation_status_size="NEW-DAY "
		fi
		if [ "$RotationNewMonth" -eq 1 ]; then
			rotation_status="${TF_GREEN}NEW-MONTH "
			rotation_status_size="NEW-MONTH "
		fi
		if [ "$RotationNewYear" -eq 1 ]; then
			rotation_status="${TF_GREEN}NEW-YEAR "
			rotation_status_size="NEW-YEAR "
		fi
		if [ "$RotationNewWeek" -eq 1 ]; then
			rotation_status="${rotation_status}${TF_RED}${TB__YELLOW} NEW-WEEK ${TR_ALL} "
			rotation_status_size="${rotation_status_size} NEW-WEEK  "
		fi
		rotation_status="${rotation_status}${TR_ALL}-"
		rotation_status_size="${rotation_status_size}-"

		echo -e "${timer} ${A_NoAction} : Rotation status : $rotation_status"
		echo

		saveVariablesState_Rotation
		echo "${BackupCurrentDate[@]}" > "$PATH_BackupFolder/$STATUS_FOLDER/_LastBackupDate"
		echo "${BackupCurrentDateTXT}" > "$PATH_BackupFolder/$STATUS_FOLDER/_LastBackupDate.txt"

		makeStatusDone 'Rotation'
		sleep 2
	else
		loadVariablesState_Rotation
	fi



#==============================================================================#
#==     Rotate all files that need it                                        ==#
#==============================================================================#

	# Ensure that bases folders exists
	if [ "$(checkStatus 'MakeBaseFolder')" == 'Uncompleted' ]; then
		for base_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
			for host_folder in "${HOSTS_LIST[@]}"; do
				makeBaseFolders "_Trashed_/Excluded/$base_folder/$host_folder"
				countFiles "_Trashed_/Excluded/$base_folder/$host_folder" "Start"
			done
		done
		for host_folder in "${HOSTS_LIST[@]}"; do
			makeBaseFolders "_Trashed_/Excluded/Current/$host_folder"
			countFiles "_Trashed_/Excluded/Current/$host_folder" "Start"
		done
		for base_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
			for host_folder in "${HOSTS_LIST[@]}"; do
				makeBaseFolders "_Trashed_/Rotation/$base_folder/$host_folder"
				countFiles "_Trashed_/Rotation/$base_folder/$host_folder" "Start"
			done
		done
		for base_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
			for host_folder in "${HOSTS_LIST[@]}"; do
				makeBaseFolders "$base_folder/$host_folder"
				countFiles "$base_folder/$host_folder" "Start"
			done
		done
		sleep 1
		for host_folder in "${HOSTS_LIST[@]}"; do
			makeBaseFolders "Current/$host_folder"
			countFiles "Current/$host_folder" "Start"
			sleep 1
		done

		makeStatusDone 'MakeBaseFolder'
		sleep 1
	fi

	if [ "$(checkStatus 'RotationStatisticsInit')" == 'Uncompleted' ]; then
		initVariablesState_Rotation_Statistics

		makeStatusDone 'RotationStatisticsInit'
	else
		loadVariablesState_Rotation_Statistics
	fi

	removeTrashedContent

	if [ "$RotationNewYear" -eq 1 ]; then
		rotateFolder 'Year-5' '_Trashed_/Rotation/Year-5'

		rotateFolder 'Year-4' 'Year-5'
		rotateFolder 'Year-3' 'Year-4'
		rotateFolder 'Year-2' 'Year-3'
	fi

	if [ "$RotationNewMonth" -eq 1 ]; then
		rotateFolder 'Month-12' 'Year-2'
		rotateFolder 'Month-11' 'Month-12'
		rotateFolder 'Month-10' 'Month-11'
		rotateFolder 'Month-9' 'Month-10'
		rotateFolder 'Month-8' 'Month-9'
		rotateFolder 'Month-7' 'Month-8'
		rotateFolder 'Month-6' 'Month-7'
		rotateFolder 'Month-5' 'Month-6'
		rotateFolder 'Month-4' 'Month-5'
		rotateFolder 'Month-3' 'Month-4'
		rotateFolder 'Month-2' 'Month-3'
	fi

	if [ "$RotationNewWeek" -eq 1 ]; then
		rotateFolder 'Week-4' 'Month-2'
		rotateFolder 'Week-3' 'Week-4'
		rotateFolder 'Week-2' 'Week-3'
	fi

	if [ "$RotationNewDay" -eq 1 ]; then
		rotateFolder 'Day-7' 'Week-2'
		rotateFolder 'Day-6' 'Day-7'
		rotateFolder 'Day-5' 'Day-6'
		rotateFolder 'Day-4' 'Day-5'
		rotateFolder 'Day-3' 'Day-4'
		rotateFolder 'Day-2' 'Day-3'
		rotateFolder 'Day-1' 'Day-2'
	fi

	makeStatusDone 'Rotation_Finished'
else
	showTitle "Rotation of the archived files..." "${A_Skipped}"
	loadVariablesState_Rotation
fi



################################################################################
################################################################################
####                                                                        ####
####     Make the backup of all hosts                                       ####
####                                                                        ####
################################################################################
################################################################################



################################################################################
##      Preparing all include and exclude files list                          ##
################################################################################

if [ "$(checkStatus 'Include-Exclude')" == 'Uncompleted' ]; then

#==============================================================================#
#==     BravoTower Host                                                      ==#
#==============================================================================#

# INCLUDE ----------------------------------------------------------------------
echo '
/bin
/etc
/usr
/var
/root
/home/foophoenix
/data
/media/foophoenix/AppKDE
/media/foophoenix/DataCenter
' # > "$(getBackupFileName 'Include' "$CAT_FILESLIST" 0 'BravoTower')"



# EXCLUDE ----------------------------------------------------------------------
#/media/foophoenix/DataCenter/.Trash
#/media/foophoenix/AppKDE/.Trash
echo '
/home/foophoenix/Data/Router/DataSierra
/home/foophoenix/Data/Router/Home-FooPhoenix
/home/foophoenix/Data/Router/Root
/home/foophoenix/Data/BackupSystem/BackupFolder
/home/foophoenix/Data/BackupSystem/Root
' # > "$(getBackupFileName 'Exclude' "$CAT_FILESLIST" 0 'BravoTower')"



#==============================================================================#
#==     Router Host                                                          ==#
#==============================================================================#

# INCLUDE ----------------------------------------------------------------------
echo '
/bin
/etc
/usr
/var
/root
/home/foophoenix
/data
' > "$(getBackupFileName 'Include' "$CAT_FILESLIST" 0 'Router')"



# EXCLUDE ----------------------------------------------------------------------
#/media/foophoenix/DataCenter/.Trash
#/media/foophoenix/AppKDE/.Trash
echo '
/home/foophoenix/VirtualBox/BackupSystem/Snapshots
' > "$(getBackupFileName 'Exclude' "$CAT_FILESLIST" 0 'Router')"


	makeStatusDone 'Include-Exclude'
fi

################################################################################
##      Launch the backup now !!                                              ##
################################################################################

TYPE_FILE=1
TYPE_FOLDER=2
TYPE_SYMLINK=3

for host_backuped in "${HOSTS_LIST[@]}"; do
	echo
	echo -e "${TS__BOLD_WHITE}              Start to make the backup of $host_backuped...${TR_ALL}"

	case $host_backuped in
		BravoTower)
			COMPRESS='-zz --compress-level=6 --skip-compress=rar'
			;;
		*)
			COMPRESS=''	# --bwlimit=30M
			;;
	esac

	if [ -d "$PATH_HostBackupedFolder" ]; then
		fusermount -u -z -q "$PATH_HostBackupedFolder" &2> /dev/null
	fi

	sleep 2
	if [ -d "$PATH_HostBackupedFolder" ]; then
		rmdir "$PATH_HostBackupedFolder"
	fi
	mkdir "$PATH_HostBackupedFolder"
	sync
	sshfs $host_backuped:/ "$PATH_HostBackupedFolder" -o follow_symlinks -o ro -o cache=no -o ssh_command='ssh -c chacha20-poly1305@openssh.com -o Compression=no'
	sleep 2



################################################################################
################################################################################
####                                                                        ####
####     STEP 1 : Build the files list                                      ####
####                                                                        ####
################################################################################
################################################################################

#==============================================================================#
#==     Initialize some used variables                                       ==#
#==============================================================================#

	if [ "$(checkStatus 'Step_1')" == 'Uncompleted' ]; then
		showTitle "$host_backuped : Make the lists of files..."

		action_context="${TF_WHITE}${host_backuped}${TR_ALL} - Build the files list -"
		action_context_size="${host_backuped} - Build the files list -"

		initVariablesState_Step_1_Statistics

		openFilesListsSpliter "Added" 10
		openFilesListsSpliter "Updated1" 20		# Data update
		openFilesListsSpliter "Updated2" 30		# Permission update
		openFilesListsSpliter "Removed" 40
		openFilesListsSpliter "Excluded" 50
		openFilesListsSpliter "Skipped" 60

		if [ "$RotationNewWeek" -eq 1 ] || [ $BRUTAL -ne 0 ]; then
			FILE_MAX_SIZE=''
		else
			FILE_MAX_SIZE='--max-size=150MB'
			FILE_MAX_SIZE='--max-size=500KB'
		fi



#==============================================================================#
#==     Build the files list                                                 ==#
#==============================================================================#

		__LastAction=0
		__LastTime=0
		__showProgress=0
		__recieved_end=0

		SKIPPED_PIPE="$(getBackupFileName "Skipped-Files" "PIPE" 1 "PIPES")"
		REMOVED_PIPE="$(getBackupFileName "Removed-Files" "PIPE" 1 "PIPES")"
		RESOLVED_PIPE="$(getBackupFileName "Resolved-Files" "PIPE" 1 "PIPES")"

		echo -n '' > "$SKIPPED_PIPE"
		echo -n '' > "$REMOVED_PIPE"
		echo -n '' > "$RESOLVED_PIPE"

		exec {pipe_id[1]}<>"$MAIN_PIPE"
		exec {pipe_id[2]}>"$SKIPPED_PIPE"
		exec {pipe_id[3]}<"$SKIPPED_PIPE"
		exec {pipe_id[4]}>"$REMOVED_PIPE"
		exec {pipe_id[5]}<"$REMOVED_PIPE"
		exec {pipe_id[6]}>"$RESOLVED_PIPE"
		exec {pipe_id[7]}<"$RESOLVED_PIPE"

		{
			rsync -vvirtpoglDmn --files-from="$(getBackupFileName 'Include' "$CAT_FILESLIST" 0)" --exclude-from="$(getBackupFileName 'Exclude' "$CAT_FILESLIST" 0)" \
							$FILE_MAX_SIZE --delete-during --delete-excluded -M--munge-links --modify-window=5 \
							--info=name2,backup,del,copy --out-format="> %12l %i %n" $host_backuped:"/" "$PATH_BackupFolder/Current/$host_backuped/"
			echo ':END:'
		} >&${pipe_id[1]} &

		{
			while (( 1 == 1 )); do
				while IFS= read -u ${pipe_id[7]} file_data; do
					if [ ':END:' == "$file_data" ]; then
						(( ++__recieved_end ))
						if (( __recieved_end == 2 )); then
							break
						fi
						continue
					fi

					echo "$file_data" >&${pipe_id[1]}
				done
				if [ ':END:' == "$file_data" ]; then
					if (( __recieved_end == 2 )); then
						break
					fi
				fi
				sleep 1
			done
			echo ':END:' >&${pipe_id[1]}
		} &

		{
			while (( 1 == 1 )); do
				while IFS= read -u ${pipe_id[3]} file_name; do
					if [ ':END:' == "$file_name" ]; then
						break
					fi

					file_size="$(stat -c "%12s" "$PATH_HostBackupedFolder/${file_name}")"

					echo "> $file_size sf--------- ${file_name}" >&${pipe_id[6]}
				done
				if [ ':END:' == "$file_name" ]; then
					break
				fi
				sleep 1
			done
			echo ':END:' >&${pipe_id[6]}
		} &

		{
			excluded_files_list="$(getBackupFileName 'Exclude' "$CAT_FILESLIST" 0)"
			while (( 1 == 1 )); do
				while IFS= read -u ${pipe_id[5]} file_name; do
					if [ ':END:' == "$file_name" ]; then
						break
					fi

					getIsExcludedV "/$file_name" "$excluded_files_list" 'status'
					file_type="$(stat -c "%F" "$PATH_BackupFolder/Current/$host_backuped/${file_name}")"
					file_size="$(stat -c "%12s" "$PATH_BackupFolder/Current/$host_backuped/${file_name}")"

					case "$file_type" in
						'regular file')
							file_type='f' ;;
						'directory')
							file_type='d' ;;
						'symbolic link')
							file_type='L' ;;
					esac
					echo "> $file_size ${status}${file_type}--------- ${file_name}" >&${pipe_id[6]}
				done
				if [ ':END:' == "$file_name" ]; then
					break
				fi
				sleep 1
			done
			echo ':END:' >&${pipe_id[6]}
		} &

		while IFS= read -u ${pipe_id[1]} file_data; do
			if [ "${file_data:0:1}" != '>' ]; then
				if [ "${#file_data}" -le 17 ]; then
					if [ ':END:' == "$file_data" ]; then
						(( ++__recieved_end ))
						if (( __recieved_end == 1 )); then
							echo ':END:' >&${pipe_id[2]}
							echo ':END:' >&${pipe_id[4]}
						elif (( __recieved_end == 2 )); then
							echo ':END:' >&${pipe_id[10]}
							echo ':END:' >&${pipe_id[20]}
							echo ':END:' >&${pipe_id[30]}
							echo ':END:' >&${pipe_id[40]}
							echo ':END:' >&${pipe_id[50]}
							echo ':END:' >&${pipe_id[60]}
							break
						fi
					fi
					continue
				fi

				if [ "${file_data:(-17)}" != ' is over max-size' ]; then
					continue
				fi

				# Here we have a skipped file
				echo "${file_data:0:$(( ${#file_data} - 17 ))}" >&${pipe_id[2]}
				continue
			fi

			file_name="${file_data:27}"
			file_action="${file_data:15:1}"

			if [ "$file_action" == '*' ]; then
				echo "$file_name" >&${pipe_id[4]}
				continue
			fi

			file_size="${file_data:2:12}"
			file_type="${file_data:16:1}"

			case "$file_type" in
				'f')
					file_type=$TYPE_FILE	;;
				'd')
					file_type=$TYPE_FOLDER	;;
				'L')
					file_type=$TYPE_SYMLINK	;;
			esac

			case $file_action in
			'.')
				action_flags="${file_data:17:9}"
				if [ "$action_flags" == '         ' ]; then
					updateLastAction 1

					if (( file_type != TYPE_FOLDER )); then
						(( file_count_size_uptodate += file_size, ++file_count_uptodate, file_count_size_total += file_size, ++file_count_total ))
					fi
				else
					updateLastAction 2

					getUpdateFlagsV "$action_flags" 'action__flags'

					if (( file_type != TYPE_FOLDER )); then
						(( file_count_size_updated2 += file_size, ++file_count_updated2, file_count_size_total += file_size, ++file_count_total ))
					fi
					echo "$file_size $file_name" >&${pipe_id[30]}
				fi		;;
			's')
				updateLastAction 4

				(( file_count_size_skipped += file_size, ++file_count_skipped, file_count_size_total += file_size, ++file_count_total ))
				echo "$file_size $file_name" >&${pipe_id[60]}			;;
			'r')
				updateLastAction 51

				if (( file_type != TYPE_FOLDER )); then
					(( file_count_size_removed += file_size, ++file_count_removed, file_count_size_total += file_size, ++file_count_total ))
					echo "$file_size $file_name" >&${pipe_id[40]}
				fi			;;
			'e')
				updateLastAction 52

				if (( file_type != TYPE_FOLDER )); then
					(( file_count_size_excluded += file_size, ++file_count_excluded, file_count_size_total += file_size, ++file_count_total ))
					echo "$file_size $file_name" >&${pipe_id[50]}
				fi			;;
			*)
				action_flags="${file_data:17:9}"

				if [ "$action_flags" == '+++++++++' ]; then
					updateLastAction 6

					if (( file_type != TYPE_FOLDER )); then
						(( file_count_size_added += file_size, ++file_count_added, file_count_size_total += file_size, ++file_count_total ))
						echo "$file_size $file_name" >&${pipe_id[10]}
					fi
				else
					updateLastAction 3

					getUpdateFlagsV "$action_flags" 'action__flags'

					(( file_count_size_updated1 += file_size, ++file_count_updated1, file_count_size_total += file_size, ++file_count_total ))
					echo "$file_size $file_name" >&${pipe_id[20]}
				fi			;;
			esac

			if (( ++__showProgress % 25 == 0 )); then
				showProgress_Step_1
			fi
		done

		exec {pipe_id[1]}>&-
		exec {pipe_id[2]}>&-
		exec {pipe_id[3]}>&-
		exec {pipe_id[4]}>&-
		exec {pipe_id[5]}>&-
		exec {pipe_id[6]}>&-
		exec {pipe_id[7]}>&-

		__LastTime=0
		showProgress_Step_1
		echo
		echo
		echo

		saveVariablesState_Step_1_Statistics

		closeFilesListsSpliter "Added" 10
		closeFilesListsSpliter "Updated1" 20		# Data update
		closeFilesListsSpliter "Updated2" 30		# Permission update
		closeFilesListsSpliter "Removed" 40
		closeFilesListsSpliter "Excluded" 50
		closeFilesListsSpliter "Skipped" 60

		for canal in {1..9}; do
			output_file_name="$(getBackupFileName "Skipped-${_canal}" "$CAT_FILESLIST" 1)"
			rm -f "$output_file_name"
		done

		makeStatusDone 'Step_1'
	else
		showTitle "$host_backuped : Make the lists of files..." "${A_Skipped}"
		loadVariablesState_Step_1_Statistics
	fi



################################################################################
################################################################################
####                                                                        ####
####     STEP 2 : Puts all excluded files into Trash                         ####
####                                                                        ####
################################################################################
################################################################################

	if [ "$(checkStatus 'Step_2')" == 'Uncompleted' ]; then
		showTitle "$host_backuped : Remove all excluded files..."

		step_2_progress1=''
		step_2_progress2=''

		if [ "$(checkStatus 'Step_2_Current')" == 'Uncompleted' ]; then
			if (( file_count_excluded > 0 )); then

				initVariablesState_Step_2

				source_folder="$PATH_BackupFolder/Current/$host_backuped"
				excluded_folder="$PATH_BackupFolder/_Trashed_/Excluded/Current/$host_backuped"

				action_tag="$A_Excluded"
				action_color="${TF_LRED}"

				action_context="${TF_WHITE}${host_backuped}${TR_ALL} - Trash excluded files -"
				action_context_size="${host_backuped} - Trash excluded files -"

				max_file_name_size="$TIME_SIZE ${A_ActionSpace} $EMPTY_SIZE "
				(( align_size = ${#action_context_size} - ${#rotation_status_size}, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

				exec {pipe_id[1]}<>"$MAIN_PIPE"

				{
					for canal in {1..9}; do
						output_file_name="$(getBackupFileName "Excluded-${_canal}" "$CAT_FILESLIST" 1)"
						cat "${FilesListRAM}_${host_backuped}_Excluded" >&${pipe_id[1]}
					done
					echo ':END:' >&${pipe_id[1]}
				} &

				while IFS= read -u ${pipe_id[1]} file_data; do
					if [ ':END:' == "$file_data" ]; then
						break
					fi

					file_size="${file_data:0:12}"
					file_name="${file_data:13}"
					checkItemType "$source_folder/$file_name" 'file_type'

					(( progress_current_size_1_remaining -= file_size, --progress_current_item_1_remaining, progress_current_size_1_processed += file_size, ++progress_current_item_1_processed ))

					if [ "$file_type" == '?' ]; then
						continue
					fi

					buildTimerV timer

					shortenFileNameV "/$file_name" "$max_file_name_size" 'file_name_text'
					file_name_text="${action_color}$file_name_text"
					formatSizeV $file_size 1 'file_size'

					formatSizeV $progress_current_size_1_remaining 1 size_1
					formatSizeV $progress_current_size_1_processed 1 size_2

					getPercentageV $progress_current_item_1_remaining $progress_total_item_1 'progress_current_item_p1_remaining'
					getPercentageV $progress_current_size_1_remaining $progress_total_size_1 'progress_current_size_p1_remaining'
					getPercentageV $progress_current_item_1_processed $progress_total_item_1 'progress_current_item_p1_processed'
					getPercentageV $progress_current_size_1_processed $progress_total_size_1 'progress_current_size_p1_processed'

					printf -v step_2_progress1 "${TF_LRED}%15d %s >>> ${TF__LRED}%15d %s" ${progress_current_item_1_remaining} "${progress_current_item_p1_remaining}" ${progress_current_item_1_processed} "${progress_current_item_p1_processed}"

					echo -e "$timer $action_tag $file_size $_file_name_text${TR_ALL}${TM_ClearEndLine}"
					echo -e "$timer $action_context $step_2_progress1${TR_ALL}"
					echo -ne "$timer $rotation_status ${PADDING:0:$align_size} $progress_current_size_1_remaining $progress_current_size_p1_remaining $progress_current_size_1_processed $progress_current_size_p1_processed${TR_ALL}\r${TM_Up1}"

					copyFullPath "$source_folder" "$excluded_folder" "${file_name%/*}"
					mv -f "$source_folder/$file_name" "$excluded_folder/$file_name"
				done

				exec {pipe_id[1]}>&-

				printf -v step_2_progress1 "${TF_LRED}%15d %s >>> ${TF__LRED}%15d %s" ${progress_current_item_1_remaining} "${progress_current_item_p1_remaining}" ${progress_current_item_1_processed} "${progress_current_item_p1_processed}"
				step_2_progress2="$progress_current_size_1_remaining $progress_current_size_p1_remaining $progress_current_size_1_processed $progress_current_size_p1_processed$"

				echo
				echo
				echo
			fi

			makeStatusDone 'Step_2_Current'
		fi

		for checked_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
			buildTimerV timer
			echo -ne "\n\n$timer Searching $checked_folder...${TM_ClearEndLine}\r${TM_Up1}${TM_Up1}"

			if [ "$(checkStatus "Step_2_$checked_folder")" == 'Uncompleted' ]; then
				source_folder="$PATH_BackupFolder/$checked_folder/$host_backuped"
				excluded_folder="$PATH_BackupFolder/_Trashed_/Excluded/$checked_folder/$host_backuped"

				action_tag="$A_Excluded"
				action_color="${TF_LRED}"

				action_context="${TF_WHITE}${host_backuped}${TR_ALL} - Trash excluded files -"
				action_context_size="${host_backuped} - Trash excluded files -"

				initVariablesState_Step_2_Statistics

				max_file_name_size="$TIME_SIZE ${A_ActionSpace} $EMPTY_SIZE "
				(( align_size = ${#action_context_size} - ${#rotation_status_size}, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

				exec {pipe_id[1]}<>"$MAIN_PIPE"

				while read excluded_item; do
					if [ "$excluded_item" == '' ]; then
						continue
					fi

					excluded_item="${excluded_item:1}"

					searched_item="$source_folder/$excluded_item"
					destination_item="$excluded_folder/$excluded_item"
					checkItemType "$source_folder/$excluded_item" 'searched_item_type'

					if [ "$searched_item_type" == '?' ]; then
						continue
					elif [ "$searched_item_type" == 'd' ]; then
						copyFullPath "$source_folder" "$excluded_folder" "$excluded_item"

						{
							find -P "$searched_item" -type f,l,p,s,b,c -printf '%12s %P'
							echo ':END:'
						} >&${pipe_id[1]} &

						while IFS= read -u ${pipe_id[1]} file_data; do
							if [ ':END:' == "$file_data" ]; then
								break
							fi

							file_size="${file_data:0:12}"
							file_name="${file_data:13}"
							file_path="${file_name%/*}"

							(( progress_total_size_2 += file_size, ++progress_total_item_2 ))

							copyFullPath "$searched_item" "$destination_item" "$file_path"
							mv -f "$searched_item/$file_name" "$destination_item/$file_name"

							showProgress_Step_2
						done
					else
						file_size=$(getFileSize "$source_folder/$excluded_item")
						file_name="$excluded_item"

						(( progress_total_size_2 += file_size, ++progress_total_item_2 ))

						copyFullPath "$source_folder" "$excluded_folder" "${excluded_item/*}"
						mv -f "$source_folder/$excluded_item" "$excluded_folder/$excluded_item"

						showProgress_Step_2
					fi

				done < "$(getBackupFileName 'Exclude' "$CAT_FILESLIST" 0)"

				exec {pipe_id[1]}>&-

				makeStatusDone "Step_2_$checked_folder"
			fi
		done

		echo
		echo
		echo

		for canal in {1..9}; do
			output_file_name="$(getBackupFileName "Excluded-${_canal}" "$CAT_FILESLIST" 1)"
			rm -f "$output_file_name"
		done

		makeStatusDone "Step_2"
	else
		showTitle "$host_backuped : Remove all excluded files..." "${A_Skipped}"
	fi


################################################################################
################################################################################
####                                                                        ####
####     STEP 3 : Make an archive of modified files or removed files        ####
####                                                                        ####
################################################################################
################################################################################

	if [ "$(checkStatus 'Step_3')" == 'Done' ]; then
		showTitle "$host_backuped : Archive modified or removed files..." "${A_Skipped}"
	else
		showTitle "$host_backuped : Archive modified or removed files..."



#==============================================================================#
#==     Initialize some used variables                                       ==#
#==============================================================================#

		initStatistics 'step_3' 6
		if [ $init_stat -eq 1 ]; then
			stat_step_3[$PROGRESS_TOTAL_ITEM]=$(( ${stat_step_1[$FILE_REMOVED]} + ${stat_step_1[$FILE_UPDATED1]} ))
			stat_step_3[$PROGRESS_TOTAL_SIZE]=$(( ${stat_step_1[$FILE_SIZE_REMOVED]} + ${stat_step_1[$FILE_SIZE_UPDATED1]} ))
			stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]=${stat_step_1[$FILE_UPDATED1]}
			stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]=${stat_step_1[$FILE_SIZE_UPDATED1]}
			eval "$save_stat_step_3"
		fi

		DstExcluded="$PATH_BackupFolder/_Trashed_/Rotation/Day-1/$host_backuped"
		DstArchive="$PATH_BackupFolder/Day-1/${host_backuped}"
		SrcArchive="$PATH_BackupFolder/Current/$host_backuped"

		if [ "$(checkStatus 'Step_3_Update')" != 'Done' ]; then

			if [ "$RotationNewDay" -eq 1 ]; then
				Action="$A_Backuped"
				ActionColor="${TF_YELLOW}"
			else
				Action="$A_Skipped"
				ActionColor="${TF_CYAN}"
			fi



#==============================================================================#
#==     Just copy modified files with cp                                     ==#
#==============================================================================#
# Using cp to ensure permission are keeped with this local copy...

			if [ "${stat_step_1[$FILE_UPDATED1]}" -gt 0 ]; then

				__screen_size="$(tput cols)"

				cat "${FilesListRAM}_${host_backuped}_Updated1" |
				while read FileName; do
					if [ ! -f "$SrcArchive/$FileName" ]; then
						continue
					fi

					getFileSize "$SrcArchive/$FileName" Size

					(( stat_step_3[$PROGRESS_CURRENT_FILES_SIZE] -= Size, --stat_step_3[$PROGRESS_CURRENT_FILES_ITEM], stat_step_3[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_3[$PROGRESS_CURRENT_ITEM] ))

					buildTimer Time

					getPercentage P_ExcludingProgressItem  ${stat_step_3[$PROGRESS_CURRENT_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
					getPercentage P_ExcludingProgressSize  ${stat_step_3[$PROGRESS_CURRENT_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}
					getPercentage P_ExcludingProgressFilesItem  ${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
					getPercentage P_ExcludingProgressFilesSize  ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}

					header_size="$Time_NC ${A_ActionSpace} : $EMPTY_SIZE /"
					(( __file_name_length = __screen_size - ${#header_size} ))

					shortenFileName 'file_name_text' "$FileName" "$__file_name_length"

					file_name_text="${ActionColor}$file_name_text${TR_ALL}"
					formatSize $Size Size
					formatSize ${stat_step_3[$PROGRESS_CURRENT_SIZE]} Size1 1
					formatSize ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]} Size2 1

					echo -e "$Time $Action : $Size $file_name_text${TM_ClearEndLine}"
					echo -ne "$Time ${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status ($host_backuped) Archive modified files : ${TF_WHITE}${stat_step_3[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${TF_YELLOW}${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}${TR_ALL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

					if [ "$RotationNewDay" -eq 1 ]; then
						copyFullPath "$SrcArchive" "$DstArchive" "${FileName%/*}"
						if [ -f "$DstArchive/$FileName" ]; then
							copyFullPath "$DstArchive" "$DstExcluded" "${FileName%/*}"
							mv -f "$DstArchive/$FileName" "$DstExcluded/$FileName"
						fi
						cp -fP --preserve=mode,ownership,timestamps,links --remove-destination "$SrcArchive/$FileName" "$DstArchive/$FileName"
						eval "$save_stat_step_3"
					fi
				done
				eval "$save_stat_step_3"
			fi

			eval "$keep_stat_step_3"
			makeStatusDone 'Step_3_Update'
		fi

		eval "$load_stat_step_3"



#==============================================================================#
#==     Move the removed files to the archive                                ==#
#==============================================================================#

		if [ "$(checkStatus 'Step_3_Remove')" != 'Done' ]; then
			if [ "${stat_step_1[$FILE_REMOVED]}" -gt 0 ]; then

				if [ "$(checkStatus 'Step_3_Remove_Init')" != 'Done' ]; then
					stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]=${stat_step_1[$FILE_REMOVED]}
					stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]=${stat_step_1[$FILE_SIZE_REMOVED]}

					makeStatusDone 'Step_3_Remove_Init'
				fi

				Action="$A_Backuped"
				ActionColor="${TF_YELLOW}"

				__screen_size="$(tput cols)"

				cat "${FilesListRAM}_${host_backuped}_Removed" |
				while read FileName; do
					if [ ! -f "$SrcArchive/$FileName" ]; then
						continue
					fi

					getFileSize "$SrcArchive/$FileName" Size

					(( stat_step_3[$PROGRESS_CURRENT_FILES_SIZE] -= Size, --stat_step_3[$PROGRESS_CURRENT_FILES_ITEM], stat_step_3[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_3[$PROGRESS_CURRENT_ITEM] ))

					buildTimer Time

					getPercentage P_ExcludingProgressItem  ${stat_step_3[$PROGRESS_CURRENT_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
					getPercentage P_ExcludingProgressSize  ${stat_step_3[$PROGRESS_CURRENT_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}
					getPercentage P_ExcludingProgressFilesItem  ${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
					getPercentage P_ExcludingProgressFilesSize  ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}

					header_size="$Time_NC ${A_ActionSpace} : $EMPTY_SIZE /"
					(( __file_name_length = __screen_size - ${#header_size} ))

					shortenFileName 'file_name_text' "$FileName" "$__file_name_length"

					file_name_text="${ActionColor}$file_name_text${TR_ALL}"
					formatSize $Size Size
					formatSize ${stat_step_3[$PROGRESS_CURRENT_SIZE]} Size1 1
					formatSize ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]} Size2 1

					echo -e "$Time $Action : $Size $file_name_text${TM_ClearEndLine}"
					echo -ne "$Time ${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status ($host_backuped) Archive removed files : ${TF_WHITE}${stat_step_3[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${TF_RED}${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}${TR_ALL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

					copyFullPath "$SrcArchive" "$DstArchive" "${FileName%/*}"
					if [ -f "$DstArchive/$FileName" ]; then
						copyFullPath "$DstArchive" "$DstExcluded" "${FileName%/*}"
						mv -f "$DstArchive/$FileName" "$DstExcluded/$FileName"
					fi
					mv -f "$SrcArchive/$FileName" "$DstArchive/$FileName"
					eval "$save_stat_step_3"
				done
			fi

			eval "$keep_stat_step_3"
			makeStatusDone 'Step_3_Remove'
		fi



#==============================================================================#
#==     Check integrity of files copied in the archive                       ==#
#==============================================================================#

		if [ "$(checkStatus 'Step_3_Checksum')" != 'Done' ]; then
			if [ "$RotationNewDay" -eq 1 ] && [ "${stat_step_1[$FILE_UPDATED1]}" -gt 0 ]; then

				if [ "$(checkStatus 'Step_3_Checksum_Init')" != 'Done' ]; then
					stat_step_3[$PROGRESS_TOTAL_ITEM]=${stat_step_1[$FILE_UPDATED1]}
					stat_step_3[$PROGRESS_TOTAL_SIZE]=${stat_step_1[$FILE_SIZE_UPDATED1]}
					stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]=${stat_step_1[$FILE_UPDATED1]}
					stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]=${stat_step_1[$FILE_SIZE_UPDATED1]}

					cp -f --remove-destination "${FilesListRAM}_${host_backuped}_Updated1" "${FilesListRAM}_${host_backuped}_ToCheck"
					echo -n '' > "${FilesListRAM}_${host_backuped}_ToReCheck"
					cp -f --remove-destination "${FilesListRAM}_${host_backuped}_ToCheck" "${FilesList}_${host_backuped}_ToCheck" &

					makeStatusDone 'Step_3_Checksum_Init'
					eval "$save_stat_step_3"
				fi

				for SizeIndex in {1..5}; do

					if [ "$(checkStatus "Step_3_Checksum_$SizeIndex")" == 'Done' ]; then
						continue
					fi

					eval "$load_stat_step_3"

					case $SizeIndex in
						1)
							SizeLimit='--max-size=1MB-1'
							OffsetSize='200'
							SizeLimitText='<1MB'
						;;
						2)
							SizeLimit='--min-size=1MB --max-size=10MB-1'
							OffsetSize='40'
							SizeLimitText='1MB ~ 10MB'
						;;
						3)
							SizeLimit='--min-size=10MB --max-size=100MB-1'
							OffsetSize='10'
							SizeLimitText='10MB ~ 100MB'
						;;
						4)
							SizeLimit='--min-size=100MB --max-size=1GB-1'
							OffsetSize='5'
							SizeLimitText='100MB ~ 1GB'
						;;
						5)
							SizeLimit='--min-size=1GB'
							OffsetSize='1'
							SizeLimitText='>1GB'
						;;
					esac

					if [ ${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]} -gt 0 ]; then
						buildTimer Time

						getPercentage P_ExcludingProgressItem  ${stat_step_3[$PROGRESS_CURRENT_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
						getPercentage P_ExcludingProgressSize  ${stat_step_3[$PROGRESS_CURRENT_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}
						getPercentage P_ExcludingProgressFilesItem  ${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
						getPercentage P_ExcludingProgressFilesSize  ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}

						formatSize ${stat_step_3[$PROGRESS_CURRENT_SIZE]} Size1 1
						formatSize ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]} Size2 1

						echo -ne "$Time ${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status ($host_backuped) Checksum of archive ($SizeLimitText :: $Index) : ${TF_GREEN}${stat_step_3[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${TF_YELLOW}${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}${TR_ALL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

						for Index in {1..10}; do
							freeCache > /dev/null
							ssh $host_backuped 'freeCache > /dev/null'

							stat_step_3[$PROGRESS_CURRENT_RESENDED]=0

							__LastAction=0

							rsync -vvitpoglDmc --files-from="${FilesListRAM}_${host_backuped}_ToCheck" --modify-window=5 \
										--preallocate --inplace --no-whole-file --block-size=32768 $SizeLimit \
										--info=name2,backup,del,copy --out-format="> %12l %i %n" "$PATH_BackupFolder/Current/$host_backuped" "$PATH_BackupFolder/Day-1/$host_backuped/" |
							while read Line; do
								if [ "${Line:0:1}" != '>' ]; then
									continue
								fi

								FileName="${Line:27}"

								if [ "${FileName:(-1)}" == '/' ]; then
									continue
								fi

								Size="${Line:2:12}"

								if [ "${Line:16:1}" == 'L' ]; then
									IsFile=0
									TypeColor="${TS_ITALIC}"
								else
									IsFile=1
									TypeColor=''
								fi

								ActionUpdateType="${Line:15:1}"

								if [ "$ActionUpdateType" == '.' ]; then
									if [ $__LastAction -ne 1 ]; then # 1 = Successed
										Action="$A_Successed"

										ActionColor="${TF_GREEN}"

										__LastAction=1
									fi

									(( stat_step_3[$PROGRESS_CURRENT_FILES_SIZE] -= Size, --stat_step_3[$PROGRESS_CURRENT_FILES_ITEM], stat_step_3[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_3[$PROGRESS_CURRENT_ITEM] ))
								else
									if [ $__LastAction -ne 2 ]; then # 2 = Resended
										Action="$A_Resended"

										ActionColor="${TF_YELLOW}"

										__LastAction=2
									fi

									(( ++stat_step_3[$PROGRESS_CURRENT_RESENDED] ))
									echo "$FileName" >> "${FilesListRAM}_${host_backuped}_ToReCheck"
								fi

								buildTimer Time

								getPercentage P_ExcludingProgressItem  ${stat_step_3[$PROGRESS_CURRENT_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
								getPercentage P_ExcludingProgressSize  ${stat_step_3[$PROGRESS_CURRENT_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}
								getPercentage P_ExcludingProgressFilesItem  ${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}  ${stat_step_3[$PROGRESS_TOTAL_ITEM]}
								getPercentage P_ExcludingProgressFilesSize  ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]}  ${stat_step_3[$PROGRESS_TOTAL_SIZE]}

								header_size="$Time_NC ${A_ActionSpace} : $EMPTY_SIZE /"
								(( __file_name_length = __screen_size - ${#header_size} ))

								shortenFileName 'file_name_text' "$FileName" "$__file_name_length"

								file_name_text="${ActionColor}$file_name_text${TR_ALL}"
								formatSize $Size Size
								formatSize ${stat_step_3[$PROGRESS_CURRENT_SIZE]} Size1 1
								formatSize ${stat_step_3[$PROGRESS_CURRENT_FILES_SIZE]} Size2 1

								echo -e "$Time $Action : $Size $file_name_text${TM_ClearEndLine}"
								echo -ne "$Time ${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status ($host_backuped) Checksum of archive ($SizeLimitText :: $Index) : ${TF_RED}${stat_step_3[$PROGRESS_CURRENT_RESENDED]}${TR_ALL} ${TF_GREEN}${stat_step_3[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${TF_YELLOW}${stat_step_3[$PROGRESS_CURRENT_FILES_ITEM]}${TR_ALL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"
								eval "$save_stat_step_3"
							done

							eval "$load_stat_step_3"

							if [ $(wc -l < "${FilesListRAM}_${host_backuped}_ToReCheck") -eq 0 ]; then
								break
							fi

							cp -f --remove-destination "${FilesListRAM}_${host_backuped}_ToReCheck" "${FilesListRAM}_${host_backuped}_ToCheck"
							echo -n '' > "${FilesListRAM}_${host_backuped}_ToReCheck"
							cp -f --remove-destination "${FilesListRAM}_${host_backuped}_ToCheck" "${FilesList}_${host_backuped}_ToCheck" &
						done
					fi

					sleep 1
					cp -f --remove-destination "${FilesListRAM}_${host_backuped}_Updated1" "${FilesListRAM}_${host_backuped}_ToCheck"
					echo -n '' > "${FilesListRAM}_${host_backuped}_ToReCheck"
					cp -f --remove-destination "${FilesListRAM}_${host_backuped}_ToCheck" "${FilesList}_${host_backuped}_ToCheck" &

					makeStatusDone "Step_3_Checksum_$SizeIndex"
				done
			fi
			makeStatusDone 'Step_3_Checksum'
		fi

		makeStatusDone 'Step_3'
	fi

	rm -f "${FilesListRAM}_${host_backuped}_Removed"



################################################################################
################################################################################
####                                                                        ####
####     STEP 4 : Make the backup for real now                              ####
####                                                                        ####
################################################################################
################################################################################

	PROGRESS_TOTAL_ITEM=0
	PROGRESS_TOTAL_SIZE=1
	PROGRESS_CURRENT_ITEM=2
	PROGRESS_CURRENT_SIZE=3
	PROGRESS_CURRENT_FILESA_ITEM=4
	PROGRESS_CURRENT_FILESA_SIZE=5
	PROGRESS_CURRENT_FILESU_ITEM=6
	PROGRESS_CURRENT_FILESU_SIZE=7
	PROGRESS2_TOTAL_ITEM=8
	PROGRESS2_TOTAL_SIZE=9
	PROGRESS2_CURRENT_ITEM=10
	PROGRESS2_CURRENT_SIZE=11
	PROGRESS2_CURRENT_FILES_ITEM=12
	PROGRESS2_CURRENT_FILES_SIZE=13
	PROGRESS2_CURRENT_RESENDED=14


	if [ "$(checkStatus 'Step_4')" == 'Done' ]; then
		showTitle "$host_backuped : Make the backup for real now..." "${A_Skipped}"
	else
		showTitle "$host_backuped : Make the backup for real now..."



#==============================================================================#
#==     Initialize some used variables                                       ==#
#==============================================================================#

		initStatistics 'step_4' 15
		if [ $init_stat -eq 1 ]; then
			echo -n '' > "${FilesListRAM}_${host_backuped}_ToReCheck"

			if [ "$BRUTAL" -ne 0 ]; then
				cp -f --remove-destination "${IncludeList}_$host_backuped" "${FilesListRAM}_${host_backuped}_ToBackup"
				stat_step_4[$PROGRESS_TOTAL_ITEM]=${stat_step_1[$FILE_TOTAL]}
				stat_step_4[$PROGRESS_TOTAL_SIZE]=${stat_step_1[$FILE_SIZE_TOTAL]}
				stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]=${stat_step_1[$FILE_UPTODATE]}
				stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE]=${stat_step_1[$FILE_SIZE_UPTODATE]}
				stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]=$(( stat_step_1[$FILE_UPDATED1] + stat_step_1[$FILE_UPDATED2] + stat_step_1[$FILE_ADDED] ))
				stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE]=$(( stat_step_1[$FILE_SIZE_UPDATED1] + stat_step_1[$FILE_SIZE_UPDATED2] + stat_step_1[$FILE_SIZE_ADDED] ))
			else
				cp -f --remove-destination "${FilesListRAM}_${host_backuped}_Updated2" "${FilesListRAM}_${host_backuped}_ToBackup"
				cat "${FilesListRAM}_${host_backuped}_Updated1" >> "${FilesListRAM}_${host_backuped}_ToBackup"
				cat "${FilesListRAM}_${host_backuped}_Added" >> "${FilesListRAM}_${host_backuped}_ToBackup"
				stat_step_4[$PROGRESS_TOTAL_ITEM]=$(( stat_step_1[$FILE_UPDATED1] + stat_step_1[$FILE_UPDATED2] + stat_step_1[$FILE_ADDED] ))
				stat_step_4[$PROGRESS_TOTAL_SIZE]=$(( stat_step_1[$FILE_SIZE_UPDATED1] + stat_step_1[$FILE_SIZE_UPDATED2] + stat_step_1[$FILE_SIZE_ADDED] ))
				stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]=${stat_step_1[$FILE_ADDED]}
				stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE]=${stat_step_1[$FILE_SIZE_ADDED]}
				stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]=$(( stat_step_1[$FILE_UPDATED1] + stat_step_1[$FILE_UPDATED2] ))
				stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE]=$(( stat_step_1[$FILE_SIZE_UPDATED1] + stat_step_1[$FILE_SIZE_UPDATED2] ))
			fi

			eval "$save_stat_step_4"
			cp -f --remove-destination "${FilesListRAM}_${host_backuped}_ToBackup" "${FilesList}_${host_backuped}_ToBackup"
		fi

		if [ "$BRUTAL" -ne 0 ]; then
			r='r'
			Exclude="--exclude-from=\"${ExcludeList}_BravoTower\""
		else
			r=''
			Exclude=''
		fi

		rm -f "${FilesListRAM}_${host_backuped}_Updated1"
		rm -f "${FilesListRAM}_${host_backuped}_Updated2"
		rm -f "${FilesListRAM}_${host_backuped}_Added"

		__screen_size="$(tput cols)"



#==============================================================================#
#==     Backup all files in the backup files list                            ==#
#==============================================================================#

		for SizeIndex in {1..5}; do
			if [ "$(checkStatus "Step_4_${SizeIndex}")" == 'Done' ]; then
				continue
			fi

			eval "$load_stat_step_4"

			case $SizeIndex in
				1)
					SizeLimit='--max-size=1MB-1'
					OffsetSize='200'
					SizeLimitText='<1MB'
					sleep_duration="$(echo 'scale=4; 0.5/200' | bc)"
				;;
				2)
					SizeLimit='--min-size=1MB --max-size=10MB-1'
					OffsetSize='40'
					SizeLimitText='1MB ~ 10MB'
					sleep_duration="$(echo 'scale=4; 1/40' | bc)"
				;;
				3)
					SizeLimit='--min-size=10MB --max-size=100MB-1'
					OffsetSize='10'
					SizeLimitText='10MB ~ 100MB'
					sleep_duration="$(echo 'scale=4; 1/10' | bc)"
				;;
				4)
					SizeLimit='--min-size=100MB --max-size=1GB-1'
					OffsetSize='5'
					SizeLimitText='100MB ~ 1GB'
					sleep_duration="$(echo 'scale=4; 1.5/5' | bc)"
				;;
				5)
					SizeLimit='--min-size=1GB'
					OffsetSize='1'
					SizeLimitText='>1GB'
					sleep_duration='2'
				;;
			esac

			buildTimer Time $CheckTime

			getPercentage P_BackupProgressItem  ${stat_step_4[$PROGRESS_CURRENT_ITEM]}  ${stat_step_4[$PROGRESS_TOTAL_ITEM]}
			getPercentage P_BackupProgressSize  ${stat_step_4[$PROGRESS_CURRENT_SIZE]}  ${stat_step_4[$PROGRESS_TOTAL_SIZE]}
			getPercentage P_BackupProgressFilesAItem  ${stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]}  ${stat_step_4[$PROGRESS_TOTAL_ITEM]}
			getPercentage P_BackupProgressFilesASize  ${stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE]}  ${stat_step_4[$PROGRESS_TOTAL_SIZE]}
			getPercentage P_BackupProgressFilesUItem  ${stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]}  ${stat_step_4[$PROGRESS_TOTAL_ITEM]}
			getPercentage P_BackupProgressFilesUSize  ${stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE]}  ${stat_step_4[$PROGRESS_TOTAL_SIZE]}

			formatSize "${stat_step_4[$PROGRESS_CURRENT_SIZE]}" size_total 1
			formatSize "${stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE]}" size_added 1
			formatSize "${stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE]}" size_updated 1

			if [ "$BRUTAL" -ne 0 ]; then
				progress="${TS__BOLD_WHITE}>>>${TR_ALL} ${TF_YELLOW}${TB__RED} BRUTAL ${TR_ALL} $rotation_status ($host_backuped) Make the backup for real ($SizeLimitText) : ${TF_WHITE}${stat_step_4[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${TF_GREEN}${stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]} ${TS_DARK}$P_BackupProgressFilesAItem${TR_ALL} ($size_added ${TF_GREEN}${TS_DARK}$P_BackupProgressFilesASize${TR_ALL}) - ${TF_YELLOW}${stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]} ${TS_DARK}$P_BackupProgressFilesUItem${TR_ALL} ($size_updated ${TF_YELLOW}${TS_DARK}$P_BackupProgressFilesUSize${TR_ALL})"
			else
				progress="${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status ($host_backuped) Make the backup for real ($SizeLimitText) : ${TF_WHITE}${stat_step_4[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${TF_LBLUE}${stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]} ${TF_BLUE}$P_BackupProgressFilesAItem${TR_ALL} ($size_added ${TF_BLUE}$P_BackupProgressFilesASize${TR_ALL}) - ${TF_YELLOW}${stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]} ${TS_DARK}$P_BackupProgressFilesUItem${TR_ALL} ($size_updated ${TF_YELLOW}${TS_DARK}$P_BackupProgressFilesUSize${TR_ALL})"
			fi

			echo -ne "$Time $progress\r"

			__LastAction=0
			__LastTime=0

			if [ "$(checkStatus "Step_4_${SizeIndex}_Rsync")" != 'Done' ]; then

				stat_step_4[$PROGRESS2_TOTAL_ITEM]=0
				stat_step_4[$PROGRESS2_TOTAL_SIZE]=0

				echo -n '' > "${FilesListRAM}_${host_backuped}_ToCheck"

				rsync -vvi${r}tpoglDm --files-from="${FilesList}_${host_backuped}_ToBackup" $Exclude --modify-window=5 -M--munge-links \
							--preallocate --inplace --no-whole-file $SizeLimit $Compress \
							--info=name2,backup,del,copy --out-format="> %12l %i %n" $host_backuped:"/" "$PATH_BackupFolder/Current/$host_backuped/" |
				while read Line; do
					if [ "${Line:0:1}" != '>' ]; then
						continue
					fi

					FileName="${Line:27}"
					Size="${Line:2:12}"

					if [ "${FileName:(-1)}" != '/' ]; then
						if [ "${Line:16:1}" == 'L' ]; then
							IsFile=0
							TypeColor="${TS_ITALIC}"
						else
							IsFile=1
							TypeColor=''
						fi
						IsDirectory=0
					else
						IsDirectory=1
						IsFile=0
						TypeColor="${TS_DARK}"
					fi

					ActionUpdateType="${Line:15:1}"
					ActionFlags="${Line:17:9}"

					if [ "$ActionUpdateType" == '.' ]; then
						if [ "$ActionFlags" == '         ' ]; then
							if [ $__LastAction -ne 1 ]; then # 1 = UpToDate
								Action="$A_UpToDate"
								Flags='      '
								ActionColor="${TF_GREEN}"

								__LastAction=1
							fi

							if [ $IsDirectory -ne 1 ]; then
								if [ "$BRUTAL" -ne 0 ]; then
									(( stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE] -= Size, --stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM], stat_step_4[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_4[$PROGRESS_CURRENT_ITEM], stat_step_4[$PROGRESS2_TOTAL_SIZE] += Size, ++stat_step_4[$PROGRESS2_TOTAL_ITEM] ))
									echo "$FileName" >> "${FilesListRAM}_${host_backuped}_ToCheck"
								else
									continue
								fi
							else
								continue
							fi
						else
							if [ $__LastAction -ne 2 ]; then # 2 = Update With Flags
								Action="$A_Updated"
								ActionColor="${TF_YELLOW}"

								__LastAction=2
							fi

							ActionFlags="${ActionFlags//./ }"
							getUpdateFlags 'Flags' "$ActionFlags"

							if [ $IsDirectory -ne 1 ]; then
								(( stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE] -= Size, --stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM], stat_step_4[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_4[$PROGRESS_CURRENT_ITEM] ))
								if [ "$BRUTAL" -ne 0 ]; then
									(( stat_step_4[$PROGRESS2_TOTAL_SIZE] += Size, ++stat_step_4[$PROGRESS2_TOTAL_ITEM] ))
									echo "$FileName" >> "${FilesListRAM}_${host_backuped}_ToCheck"
								fi
							fi
						fi
					else
						if [ "$ActionFlags" == '+++++++++' ]; then
							if [ $__LastAction -ne 6 ]; then # 6 = Added
								Action="$A_Added"

								Flags='      '
								ActionColor="${TF_LBLUE}"

								__LastAction=6
							fi

							if [ $IsDirectory -ne 1 ]; then
								if [ "$BRUTAL" -ne 0 ]; then
									(( stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE] -= Size, --stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM], stat_step_4[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_4[$PROGRESS_CURRENT_ITEM], stat_step_4[$PROGRESS2_TOTAL_SIZE] += Size, ++stat_step_4[$PROGRESS2_TOTAL_ITEM] ))
								else
									(( stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE] -= Size, --stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM], stat_step_4[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_4[$PROGRESS_CURRENT_ITEM], stat_step_4[$PROGRESS2_TOTAL_SIZE] += Size, ++stat_step_4[$PROGRESS2_TOTAL_ITEM] ))
								fi
								echo "$FileName" >> "${FilesListRAM}_${host_backuped}_ToCheck"
							fi
						else
							if [ $__LastAction -ne 3 ]; then # 3 = Updated without flags
								Action="$A_Updated"

								Flags='      '
								ActionColor="${TF_YELLOW}"

								__LastAction=3
							fi

							(( stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE] -= Size, --stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM], stat_step_4[$PROGRESS_CURRENT_SIZE] += Size, ++stat_step_4[$PROGRESS_CURRENT_ITEM], stat_step_4[$PROGRESS2_TOTAL_SIZE] += Size, ++stat_step_4[$PROGRESS2_TOTAL_ITEM] ))
							echo "$FileName" >> "${FilesListRAM}_${host_backuped}_ToCheck"
						fi
						__LastTime=0
					fi

					printf -v CheckTime '%(%s)T'
					if [ $CheckTime -gt $__LastTime ]; then
						__LastTime=$CheckTime

						buildTimer Time $CheckTime

						getPercentage P_BackupProgressItem  ${stat_step_4[$PROGRESS_CURRENT_ITEM]}  ${stat_step_4[$PROGRESS_TOTAL_ITEM]}
						getPercentage P_BackupProgressSize  ${stat_step_4[$PROGRESS_CURRENT_SIZE]}  ${stat_step_4[$PROGRESS_TOTAL_SIZE]}
						getPercentage P_BackupProgressFilesAItem  ${stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]}  ${stat_step_4[$PROGRESS_TOTAL_ITEM]}
						getPercentage P_BackupProgressFilesASize  ${stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE]}  ${stat_step_4[$PROGRESS_TOTAL_SIZE]}
						getPercentage P_BackupProgressFilesUItem  ${stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]}  ${stat_step_4[$PROGRESS_TOTAL_ITEM]}
						getPercentage P_BackupProgressFilesUSize  ${stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE]}  ${stat_step_4[$PROGRESS_TOTAL_SIZE]}

						formatSize "${stat_step_4[$PROGRESS_CURRENT_SIZE]}" size_total 1
						formatSize "${stat_step_4[$PROGRESS_CURRENT_FILESA_SIZE]}" size_added 1
						formatSize "${stat_step_4[$PROGRESS_CURRENT_FILESU_SIZE]}" size_updated 1

						header_size="$Time_NC ${A_ActionSpace} : $EMPTY_SIZE ?????? /"
						(( __file_name_length = __screen_size - ${#header_size} ))
						if [ "$BRUTAL" -ne 0 ]; then
							progress="${TS__BOLD_WHITE}>>>${TR_ALL} ${TF_YELLOW}${TB__RED} BRUTAL ${TR_ALL} $rotation_status ($host_backuped) Make the backup for real ($SizeLimitText) : ${TF_WHITE}${stat_step_4[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${TF_GREEN}${stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]} ${TS_DARK}$P_BackupProgressFilesAItem${TR_ALL} ($size_added ${TF_GREEN}${TS_DARK}$P_BackupProgressFilesASize${TR_ALL}) - ${TF_YELLOW}${stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]} ${TS_DARK}$P_BackupProgressFilesUItem${TR_ALL} ($size_updated ${TF_YELLOW}${TS_DARK}$P_BackupProgressFilesUSize${TR_ALL})"
						else
							progress="${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status ($host_backuped) Make the backup for real ($SizeLimitText) : ${TF_WHITE}${stat_step_4[$PROGRESS_CURRENT_ITEM]}${TR_ALL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${TF_LBLUE}${stat_step_4[$PROGRESS_CURRENT_FILESA_ITEM]} ${TF_BLUE}$P_BackupProgressFilesAItem${TR_ALL} ($size_added ${TF_BLUE}$P_BackupProgressFilesASize${TR_ALL}) - ${TF_YELLOW}${stat_step_4[$PROGRESS_CURRENT_FILESU_ITEM]} ${TS_DARK}$P_BackupProgressFilesUItem${TR_ALL} ($size_updated ${TF_YELLOW}${TS_DARK}$P_BackupProgressFilesUSize${TR_ALL})"
						fi
					fi

					shortenFileName 'file_name_text' "$FileName" "$__file_name_length"
					if [ $IsDirectory -eq 1 ]; then
						Size="$FOLDER_SIZE"
					elif [ $IsFile -eq 0 ]; then
						Size="$SYMLINK_SIZE"
					else
						formatSize "$Size" Size
					fi

					file_name_text="${ActionColor}${TypeColor}$file_name_text"
					Size="${ActionColor}${TypeColor}$Size"

					echo -e "$Time $Action : $Size $Flags $file_name_text${TM_ClearEndLine}"
					echo -ne "$Time $progress\r"

					eval "$save_stat_step_4"
					echo "$progress" > "$PATH_BackupStatusRAM/progress"
				done

				echo -n '' > "${FilesListRAM}_${host_backuped}_ToReCheck"

				eval "$load_stat_step_4"

				(( stat_step_4[$PROGRESS2_CURRENT_ITEM] = 0, stat_step_4[$PROGRESS2_CURRENT_SIZE] = 0, stat_step_4[$PROGRESS2_CURRENT_FILES_ITEM] = stat_step_4[$PROGRESS2_TOTAL_ITEM], stat_step_4[$PROGRESS2_CURRENT_FILES_SIZE] = stat_step_4[$PROGRESS2_TOTAL_SIZE] , 1 ))

				eval "$save_stat_step_4"
				eval "$keep_stat_step_4"

				if [ -f "$PATH_BackupStatusRAM/progress" ]; then
					progress="$(cat "$PATH_BackupStatusRAM/progress")"
				else
					progress=''
				fi

				makeStatusDone "Step_4_${SizeIndex}_Rsync"
			fi



#==============================================================================#
#==     Check integrity of files copied or modified in the backup            ==#
#==============================================================================#

			eval "$load_stat_step_4"

			if [ ${stat_step_4[$PROGRESS2_TOTAL_ITEM]} -gt 0 ]; then

				buildTimer Time

				getPercentage P_ChecksumProgressItem  ${stat_step_4[$PROGRESS2_CURRENT_ITEM]}  ${stat_step_4[$PROGRESS2_TOTAL_ITEM]}
				getPercentage P_ChecksumProgressSize  ${stat_step_4[$PROGRESS2_CURRENT_SIZE]}  ${stat_step_4[$PROGRESS2_TOTAL_SIZE]}
				getPercentage P_ChecksumProgressFilesItem  ${stat_step_4[$PROGRESS2_CURRENT_FILES_ITEM]}  ${stat_step_4[$PROGRESS2_TOTAL_ITEM]}
				getPercentage P_ChecksumProgressFilesSize  ${stat_step_4[$PROGRESS2_CURRENT_FILES_SIZE]}  ${stat_step_4[$PROGRESS2_TOTAL_SIZE]}

				formatSize ${stat_step_4[$PROGRESS2_CURRENT_SIZE]} Size1 1
				formatSize ${stat_step_4[$PROGRESS2_CURRENT_FILES_SIZE]} Size2 1

				echo -ne "$Time $progress -- -- -- Checksum (?) : ${TF_RED}${stat_step_4[$PROGRESS2_CURRENT_RESENDED]}${TR_ALL} ${TF_GREEN}${stat_step_4[$PROGRESS2_CURRENT_ITEM]}${TR_ALL} $P_ChecksumProgressItem ($Size1 $P_ChecksumProgressSize) - ${TF_YELLOW}${stat_step_4[$PROGRESS2_CURRENT_FILES_ITEM]}${TR_ALL} $P_ChecksumProgressFilesItem ($Size2 $P_ChecksumProgressFilesSize)\r"

				for Index in {1..10}; do
					freeCache > /dev/null
					ssh $host_backuped 'freeCache > /dev/null'

					stat_step_4[$PROGRESS2_CURRENT_RESENDED]=0

					Offset=1
					while true; do
						if [ "$(checkStatus "Step_4_${SizeIndex}_Checksum_$Index-$Offset")" == 'Done' ]; then
							Offset=$(( Offset + OffsetSize ))
							continue
						fi

						tail -qn +$Offset "${FilesListRAM}_${host_backuped}_ToCheck" | head -qn $OffsetSize > "${FilesListRAM}_${host_backuped}_ToCheck_Offset"
						LineCount="$(wc -l < "${FilesListRAM}_${host_backuped}_ToCheck_Offset")"

						if [ "$LineCount" -eq 0 ]; then
							break
						fi

						__LastAction=0

						rsync -vvitpoglDmc --files-from="${FilesListRAM}_${host_backuped}_ToCheck_Offset" --modify-window=5 \
									--preallocate --inplace --no-whole-file --block-size=32768 $Compress -M--munge-links \
									--info=name2,backup,del,copy --out-format="> %12l %i %n" $host_backuped:"/" "$PATH_BackupFolder/Current/$host_backuped/" |
						while read Line; do
							if [ "${Line:0:1}" != '>' ]; then
								continue
							fi

							FileName="${Line:27}"

							if [ "${FileName:(-1)}" == '/' ]; then
								continue
							fi

							Size="${Line:2:12}"

							if [ "${Line:16:1}" == 'L' ]; then
								IsFile=0
								TypeColor="${TS_ITALIC}"
							else
								IsFile=1
								TypeColor=''
							fi

							ActionUpdateType="${Line:15:1}"

							if [ "$ActionUpdateType" == '.' ]; then
								if [ $__LastAction -ne 1 ]; then # 1 = Successed
									Action="$A_Successed"

									ActionColor="${TF_GREEN}"

									__LastAction=1
								fi

								(( stat_step_4[$PROGRESS2_CURRENT_FILES_SIZE] -= Size, --stat_step_4[$PROGRESS2_CURRENT_FILES_ITEM], stat_step_4[$PROGRESS2_CURRENT_SIZE] += Size, ++stat_step_4[$PROGRESS2_CURRENT_ITEM] ))
							else
								if [ $__LastAction -ne 2 ]; then # 2 = Resended
									Action="$A_Resended"

									ActionColor="${TF_YELLOW}"

									__LastAction=2
								fi

								(( ++stat_step_4[$PROGRESS2_CURRENT_RESENDED] ))
								echo "$FileName" >> "${FilesListRAM}_${host_backuped}_ToReCheck"
							fi

							buildTimer Time

							getPercentage P_ChecksumProgressItem  ${stat_step_4[$PROGRESS2_CURRENT_ITEM]}  ${stat_step_4[$PROGRESS2_TOTAL_ITEM]}
							getPercentage P_ChecksumProgressSize  ${stat_step_4[$PROGRESS2_CURRENT_SIZE]}  ${stat_step_4[$PROGRESS2_TOTAL_SIZE]}
							getPercentage P_ChecksumProgressFilesItem  ${stat_step_4[$PROGRESS2_CURRENT_FILES_ITEM]}  ${stat_step_4[$PROGRESS2_TOTAL_ITEM]}
							getPercentage P_ChecksumProgressFilesSize  ${stat_step_4[$PROGRESS2_CURRENT_FILES_SIZE]}  ${stat_step_4[$PROGRESS2_TOTAL_SIZE]}

							header_size="$Time_NC ${A_ActionSpace} : $EMPTY_SIZE /"
							(( __file_name_length = __screen_size - ${#header_size} ))

							shortenFileName 'file_name_text' "$FileName" "$__file_name_length"

							file_name_text="${ActionColor}$file_name_text${TR_ALL}"
							formatSize $Size Size
							formatSize ${stat_step_4[$PROGRESS2_CURRENT_SIZE]} Size1 1
							formatSize ${stat_step_4[$PROGRESS2_CURRENT_FILES_SIZE]} Size2 1

							echo -e "$Time $Action : $Size $file_name_text${TM_ClearEndLine}"
							echo -ne "$Time $progress -- -- -- Checksum ($Index) : ${TF_RED}${stat_step_4[$PROGRESS2_CURRENT_RESENDED]}${TR_ALL} ${TF_GREEN}${stat_step_4[$PROGRESS2_CURRENT_ITEM]}${TR_ALL} $P_ChecksumProgressItem ($Size1 $P_ChecksumProgressSize) - ${TF_YELLOW}${stat_step_4[$PROGRESS2_CURRENT_FILES_ITEM]}${TR_ALL} $P_ChecksumProgressFilesItem ($Size2 $P_ChecksumProgressFilesSize)\r"

							eval "$save_stat_step_4"
							sleep $sleep_duration
						done

						eval "$keep_stat_step_4"
						eval "$load_stat_step_4"

						makeStatusDone "Step_4_${SizeIndex}_Checksum_$Index-$Offset"
					done

					eval "$load_stat_step_4"

					if [ $(wc -l < "${FilesListRAM}_${host_backuped}_ToReCheck") -eq 0 ]; then
						break
					fi

					cp --remove-destination "${FilesListRAM}_${host_backuped}_ToReCheck" "${FilesListRAM}_${host_backuped}_ToCheck"
					echo -n '' > "${FilesListRAM}_${host_backuped}_ToReCheck"
					cp -f --remove-destination "${FilesListRAM}_${host_backuped}_ToCheck" "${FilesList}_${host_backuped}_ToCheck" &
				done
				eval "$load_stat_step_4"
				stat_step_4[$PROGRESS2_CURRENT_RESENDED]=0
				eval "$save_stat_step_4"
			fi
			makeStatusDone "Step_4_${SizeIndex}"
		done

		makeStatusDone 'Step_4'
	fi

	echo

################################################################################
################################################################################
####                                                                        ####
####     STEP 5 : Check archived files for excluded files removal            ####
####                                                                        ####
################################################################################
################################################################################



done



################################################################################
################################################################################
####                                                                        ####
####     STEP 6 : Removing all empty folders                                ####
####                                                                        ####
################################################################################
################################################################################

Action="$A_Removed"
ActionColor="${TF_GREEN}${TS_DARK}"
Size="${TF_GREEN}${TS_DARK}$FOLDER_SIZE"

if [ $DayOfWeek -eq 4 ]; then
	showTitle "Remove all empty folders..."

	__screen_size="$(tput cols)"

	count=0

	find -P "$PATH_BackupFolder" -type d -empty -print -delete |
	while read Folder; do
		buildTimer Time

		FileName="${Folder:${#PATH_BackupFolder}}"

		header_size="$Time_NC : $EMPTY_SIZE [ UP TO DATE ] /"
		(( __file_name_length = __screen_size - ${#header_size}, ++count ))

		shortenFileName 'file_name_text' "${FileName:1}" "$__file_name_length"

		file_name_text="${ActionColor}${TypeColor}$file_name_text${TR_ALL}"

		echo -e "$Time $Size $Action $file_name_text${TM_ClearEndLine}"
		echo -ne "$Time ${TS__BOLD_WHITE}>>>${TR_ALL} $rotation_status Remove empty folders : ${TF_WHITE}$count${TR_ALL}\r"
	done
	echo
else
	showTitle "Remove all empty folders..." "$A_Skipped"
fi

################################################################################
################################################################################
####                                                                        ####
####     STEP 7 : Show statistics                                           ####
####                                                                        ####
################################################################################
################################################################################

if [ "$(checkStatus 'CountFileEnd')" != 'Done' ]; then
	echo
	for base_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5} Current; do
		for host_folder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BackupFolder/_Trashed_/Excluded/$base_folder/$host_folder" ]; then
				countFiles "_Trashed_/Excluded/$base_folder/$host_folder" "End"
			fi
		done
	done
	for base_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
		for host_folder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BackupFolder/_Trashed_/Rotation/$base_folder/$host_folder" ]; then
				countFiles "_Trashed_/Rotation/$base_folder/$host_folder" "End"
			fi
		done
	done
	for base_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
		for host_folder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BackupFolder/$base_folder/$host_folder" ]; then
				countFiles "$base_folder/$host_folder" "End"
			fi
		done
	done
	for host_folder in "${HOSTS_LIST[@]}"; do
		if [ -d "$PATH_BackupFolder/Current/$host_folder" ]; then
			countFiles "Current/$host_folder" "End"
		fi
	done

	makeStatusDone 'CountFileEnd'
fi

FilesCount=$(find "$PATH_BackupFolder/_Trashed_" -type f -printf '.' | wc -c)

if [ "$FilesCount" -gt 0 ]; then
	echo
	echo -e "${TF_YELLOW}${TB__RED}*** LAST CHANCE TO RECOVER ***${TR_ALL}"
	echo -e "${TF_RED}This is your last chance to recover excluded files from the backup,"
	echo -e "or overwrited files during the rotation... There is ${TF_LRED}$FilesCount${TF_RED} files in the Trash.${TR_ALL}"
fi

rm -rf $PATH_BackupStatusRAM/*
rm -rf $PATH_BackupStatus/[!_]*


# -z --compress-level=9 --skip-compress=gz/jpg/mp[34]/7z/bz2/zip/rar
# (7z ace avi bz2 deb gpg gz iso jpeg jpg lz lzma lzo mov mp3 mp4 ogg png rar rpm rzip tbz tgz tlz txz xz z zip)
