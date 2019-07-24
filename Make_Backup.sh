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
#														23.03.2019 - 24.07.2019

PATH_INFRASTRUCTURES='/root/Infrastructures'

SCRIPT_ENSURE_LOCKFILE=1
SCRIPT_ENSURE_ROOT=1
SCRIPT_ENSURE_TTY=1
SCRIPT_NEW_TTY_NO_CLOSE='NO-CLOSE'

. /data/.script_common.sh

################################################################################################################################################################
#
# SCRIPT_START_TIME SCRIPT_NAME SCRIPT_FULLNAME SCRIPT_REAL_FULLNAME SCRIPT_TTY SCRIPT_ENSURE_LOCKFILE SCRIPT_ENSURE_ROOT SCRIPT_ENSURE_TTY SCRIPT_NEW_TTY_NO_CLOSE
# SCRIPT_PID SCRIPT_WINDOWED_STDERR SCRIPT_DARKEN_BOLD PATH_LOG PATH_LOCK PATH_RAM_DISK PATH_TMP PATH_INFRASTRUCTURES PADDING_SPACE PADDING_ZERO ACTION_TAG_SIZE
# LOOP_END_TAG FILENAME_FORBIDEN_CHARS FILENAME_FORBIDEN_NAMES debugTimeIteration debugTimeResults debugTimeResult scriptPostRemoveFiles pipeExpectedEnd pipeReceivedEnd
# pipeParentProcessID removeArrayItem removeArrayDuplicate SCRIPT_DARKEN_BOLD_TAG S_NO S_BO S_DA S_IT S_UN S_BL S_BA S_R_AL S_R_BO S_R_DA S_R_IT S_R_UN S_R_BL S_R_BA
# S_R_CF S_R_CB S_BLA S_RED S_GRE S_YEL S_BLU S_MAG S_CYA S_LGY S_DGY S_LRE S_LGR S_LYE S_LBL S_LMA S_LCY S_WHI S_B_BLA S_B_RED S_B_GRE S_B_YEL S_B_BLU S_B_MAG S_B_CYA
# S_B_LGY S_B_DGY S_B_LRE S_B_LGR S_B_LYE S_B_LBL S_B_LMA S_B_LCY S_B_WHI S_NOBLA S_NORED S_NOGRE S_NOYEL S_NOBLU S_NOMAG S_NOCYA S_NOLGY S_NODGY S_NOLRE S_NOLGR S_NOLYE
# S_NOLBL S_NOLMA S_NOLCY S_NOWHI S_BOBLA S_BORED S_BOGRE S_BOYEL S_BOBLU S_BOMAG S_BOCYA S_BOLGY S_BODGY S_BOLRE S_BOLGR S_BOLYE S_BOLBL S_BOLMA S_BOLCY S_BOWHI
# CO_HIDE CO_SHOW CO_SAVE_POS CO_RESTORE_POS ES_CURSOR_TO_SCREEN_END ES_CURSOR_TO_SCREEN_START ES_ENTIRE_SCREEN ES_CURSOR_TO_LINE_END ES_CURSOR_TO_LINE_START
# ES_ENTIRE_LINE getCSIm getCSI_RGB getCSI_GRAY showRGB_Palette getCSI_CursorMove getCSI_ScreenMove A_IN_PROGRESS A_OK A_FAILED_R A_FAILED_Y A_SUCCESSED A_SKIPPED
# A_ABORTED_NR A_ABORTED_RR A_ABORTED_NY A_WARNING_NR A_WARNING_RR A_WARNING_NY A_ERROR_NR A_ERROR_BR A_ERROR_RR A_UP_TO_DATE_G A_MODIFIED_Y A_UPDATED_Y A_UPDATED_G
# A_ADDED_B A_COPIED_G A_MOVED_G A_REMOVED_R A_EXCLUDED_R A_BACKUPED_G A_EMPTY_TAG A_TAG_LENGTH_SIZE getActionTag errcho checkLoopFail checkLoopEnd getProcessTree safeExit
# formatSizeV_Colors getFileTypeV checkFilename cloneFolderDetails clonePathDetails shortenFileNameV formatSizeV getFileSizeV checkLockfileOwned takeLockfile releaseLockfile
# checkSectionStatus makeSectionStatusDone makeSectionStatusUncompleted ensureTTY ensureRoot getWordUserChoiceV getTimerV processTimeResultsV removeCSI_Tag getCSI_StringLength
# CO_GO_TOP_LEFT CO_UP_1 PADDING_EQUAL A_BACKUPED_Y SO_INSERT_1 screenWidth
#
################################################################################################################################################################

#==============================================================================#
#==     Constants Definition                                                 ==#
#==============================================================================#

declare -r PATH_BACKUP_FOLDER='/root/BackupFolder/TEST'			# The path of the backup folder in the BackupSystem virtual machine...
declare -r PATH_HOST_BACKUPED_FOLDER='/root/HostBackuped'		# The path of the backup folder in the BackupSystem virtual machine...

declare -r STATUS_FOLDER="_Backup_Status_"
declare -r TRASH_FOLDER="_Trashed_"
declare -r VARIABLES_FOLDER="Variables_State"

declare -r PATHFILE_LAST_BACKUP_DATE="$PATH_BACKUP_FOLDER/$STATUS_FOLDER/_LastBackupDate"
declare -r PATH_STATIC_WORKING_DIRECTORY="$PATH_BACKUP_FOLDER/$STATUS_FOLDER/WorkingDirectory"

# CAT_STATUS="Status"
# CAT_VARIABLES_STATE="VarState"
# CAT_STATISTICS="Statistics"
# CAT_FILESLIST="FilesList"

# declare -ar HOSTS_LIST=( 'BravoTower' 'Router' )
declare -ar HOSTS_LIST=( 'Router' )
declare -ar PERIOD_FOLDERS=( Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5} )

declare -ri BRUTAL=0		# 1 = Force a whole files backup to syncronize all !! (can be very very looooong...)

declare -ri SKIP_INTERVAL=31



#==============================================================================#
#==     Globals variables definition                                         ==#
#==============================================================================#

declare posFilename=''



################################################################################
################################################################################
####                                                                        ####
####     Functions definition                                               ####
####                                                                        ####
################################################################################
################################################################################

function takeWorkingDirectory
{
# 	[[ -d "$PATH_STATIC_WORKING_DIRECTORY" ]] &&
# 		cp -r "$PATH_STATIC_WORKING_DIRECTORY/" "$PATH_TMP"

	return 0
}

function backupWorkingDirectory
{
	mkdir -p "$PATH_STATIC_WORKING_DIRECTORY"
	cp -Lr "$PATH_TMP/" "$PATH_STATIC_WORKING_DIRECTORY"
}

function clearWorkingDirectory
{
	[[ -d "$PATH_STATIC_WORKING_DIRECTORY" ]] &&
		rm --preserve-root -fr "$PATH_STATIC_WORKING_DIRECTORY"

	return 0
}

function getHostWorkingDirectory
{
	local -ir in_memory=${1:-0}

	(( in_memory > 0 )) &&
		echo "$PATH_TMP/MEMORY/$hostBackuped" ||
		echo "$PATH_TMP/$hostBackuped"
}

function getBackupFileName()
{
	local filename="${1//\//^}"	# The file name without path. Assume the parameter is not empty.
	local _file_cat="${2}"			# The categorie of the file. Assume the parameter is not empty.
	local _is_ramdisk="${3:-1}"		# 1 = RAM DISK, 0 = HARD DISK. 1 is the default value.
	local _host="${4:-$hostBackuped}"

	local _var_name_ram="${5}"
	local _var_name_disk="${6}"

	if [ "$_var_name_ram$_var_name_disk" == '' ]; then
		local _root

		if (( _is_ramdisk == 1 )); then
			_root="$PATH_RamDisk"
		else
			_root="$PATH_BACKUP_FOLDER"
		fi

		echo "$_root/$STATUS_FOLDER/$_host/${_file_cat}_${filename}"
	else
		if [ "$_var_name_ram" != '' ]; then
			printf -v $_var_name_ram "$PATH_RamDisk/$STATUS_FOLDER/$_host/${_file_cat}_${filename}"
		fi
		if [ "$_var_name_disk" != '' ]; then
			printf -v $_var_name_disk "$PATH_BACKUP_FOLDER/$STATUS_FOLDER/$_host/${_file_cat}_${filename}"
		fi
	fi
}

function moveBackupFile()
{
	local filename="${1}"		# The file name without path. Assume the parameter is not empty.
	local _file_cat="${2}"		# The categorie of the file. Assume the parameter is not empty.
	local _move_direction="${3:-0}"  # 0 = Ram to Disk, 1 = Disk to Ram
	local _host="${3}"

	local _source _destination

	if (( _move_direction == 0 )); then
		getBackupFileName "$filename" "$_file_cat" '' "$_host" '_source' '_destination'
	else
		getBackupFileName "$filename" "$_file_cat" '' "$_host" '_destination' '_source'
	fi

	if [ -f "$_source" ]; then
		cp -f --remove-destination "$_source" "$_destination"
	fi
}

function updateScreenCurrentAction
{
	local -r action="${1:-}"
	local -r sub_action="${2:-}"

	echo -en "${CO_GO_TOP_LEFT}$(getTimerV) ${rotationStatus:-?} ${S_BOLMA}${hostBackuped:-?}${S_NO} ${S_BOWHI}${action}${S_NO} ${S_NOWHI}${sub_action}${S_NO}${ES_CURSOR_TO_LINE_END}"
}

declare -r CO_GO_SIZE="$(getCSI_CursorMove Down 1)$(getCSI_CursorMove Left 15)"

function getPercentageV()
{
	local -r return_var_name="${1}"
	local _value="${2}"
	local _divisor="${3}"

	local _t1 _t2 _P1 _P2

	(( _divisor = _divisor ? _divisor : 1, _t1 = _value * 100, _t2 = _t1 % _divisor, _P1 = _t1 / _divisor, _P2 = (_t2 * 10000) / _divisor )) || :

	printf -v $return_var_name '%3d.%04d%%' $_P1 $_P2
}

function echoStat
{
	local count=${1}
	local size=${2}

	local position="${3}"
	local color="${4:-}"

	printf -v count '%15d' $count
	formatSizeV size $size 15

	echo -en "${position}${color}${count}${CO_GO_SIZE}${size}"
}

declare -r CO_GO_SIZE2="$(getCSI_CursorMove Down 1)$(getCSI_CursorMove Left 25)"

function echoStatPercent
{
	local count=${1}
	local size=${2}

	local percent1="${5}"
	local percent2="${6}"

	local position="${3:-}"
	local color="${4:-}"

	printf -v count '%15d' $count
	formatSizeV size $size 15

	echo -en "${position}${color}${count} ${percent1}${CO_GO_SIZE2}${size} ${percent2}"
}

function echoFilename
{
	local filename="${1}"
	local size=${2}
	local tag="${3}"
	local color="${4}"

	local timer

	getTimerV timer
	formatSizeV size $size 12
	shortenFileNameV filename "$filename" $filenameMaxSize

	echo -en "${posFilename}${SO_INSERT_1}${timer} ${tag} ${size} ${color}${filename}${S_R_AL}"
}

function showTitle()
{
	local _title="${1}"
	local _state="${2:-"${A_EMPTY_TAG}"}"

	echo -e "$(getTimerV)"

	echo -e "$(buildTimer) ${_state} ${S_BOWHI}==-=-== ${_title} ==-=-==${S_R_AL}"
	if [ "$_state" != "${A_SKIPPED}" ]; then
		echo
		sleep 1
	fi
}

function makeBaseFolders()
{
	local _full_folder_name="${1}"

	mkdir -p "$PATH_BACKUP_FOLDER/$_full_folder_name"
	mkdir -p "$PATH_RamDisk/$_full_folder_name"
	rm -rf "$PATH_RamDisk/$STATUS_FOLDER/$hostFolder"/[!_]*
}

function getFileSize()
{
	local fullFilename="${1}"

	local _file_size_

	getFileSize "$fullFilename" '_file_size_'

	echo "$_file_size_"
}

EMPTY_SIZE='               '
FOLDER_SIZE="      directory"
SYMLINK_SIZE="       sym-link"
UNKNOWN_SIZE="        ??? ???"

function formatSize()
{
	local _size="${1}"
	local _padding="${2}"

	formatSizeV "$_size" $_padding '_size'

	echo "$_size"
}

TIME_SIZE='[00:00:00]'
function buildTimer()
{
	local timer

	getTimerV 'timer'

	echo "$timer"
}

function getUpdateFlagsV()
{
	local -r  return_var_name="${1}"
	local flags_="${2//./ }"

	if [ "${flags_:0:6}" != '      ' ]; then
		flags_="${flags_^^}"
		printf -v $return_var_name '%s' "${S_NORED}${flags_:0:1}${S_YEL}${flags_:1:1}${S_YEL}${flags_:2:1}${S_MAG}${flags_:3:1}${S_LMA}${flags_:4:1}${S_LMA}${flags_:5:1}${S_R_AL}"
	else
		printf -v $return_var_name '%s' "${S_NOYEL}${S_B_RED}??????${S_R_AL}"
	fi
}

function getIsExcludedV()
{
	local -r  return_var_name="${1}"
	local full_filename="${2}"
	local excluded_files_list="${3}"

	local is_excluded='r'

	local full_filename_size=${#full_filename}
	local excluded_path excluded_path_size

	while read excluded_path; do
		[[ -z "$excluded_path" ]] && continue

		excluded_path_size=${#excluded_path}

		(( full_filename_size < excluded_path_size )) && continue

		[[ "$excluded_path" == "${full_filename:0:excluded_path_size}" ]] && {
			if [[ "${full_filename:excluded_path_size:1}" == '/' ]]; then
				is_excluded='e'
				break
			elif (( full_filename_size == excluded_path_size )); then
				is_excluded='e'
				break
			fi
		}
	done < "$excluded_files_list"

	printf -v $return_var_name '%s' $is_excluded
}

function saveVariablesState_Rotation()
{
	local fullFilename="$(getBackupFileName 'Rotation' "$CAT_VARIABLES_STATE" 0)"

	echo "
	$isNewDay
	$isNewWeek
	$isNewMonth
	$isNewYear
	${rotationStatus// /%}
	${rotationStatusSize// /%}
	$dayOfWeek
	${backupLastDateText// /%}" > "$fullFilename"
}

function loadVariablesState_Rotation()
{
	local fullFilename="$(getBackupFileName 'Rotation' "$CAT_VARIABLES_STATE" 0)"
	local _values

	_values=( $(cat "$fullFilename") )
	isNewDay="${_values[0]}"
	isNewWeek="${_values[1]}"
	isNewMonth="${_values[2]}"
	isNewYear="${_values[3]}"
	rotationStatus="${_values[4]//%/ }"
	rotationStatusSize="${_values[5]//%/ }"
	dayOfWeek="${_values[6]}"
	backupLastDateText="${_values[7]//%/ }"
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
	local fullFilename="$(getBackupFileName "Count_GlobalRotation" "$CAT_VARIABLES_STATE" 0)"

	echo "
	$count_files_trashed
	$count_size_trashed
	$count_files_rotation
	$count_size_rotation" > "$fullFilename"
}

function loadVariablesState_Rotation_Statistics()
{
	local fullFilename="$(getBackupFileName "Count_GlobalRotation" "$CAT_VARIABLES_STATE" 0)"
	local _values

	_values=( $(cat "$fullFilename") )
	count_files_trashed="${_values[0]}"
	count_size_trashed="${_values[1]}"
	count_files_rotation="${_values[2]}"
	count_size_rotation="${_values[3]}"
}

function initVariablesState_Step_1_Statistics()
{
	fileCountTotal=0
	fileCountAdded=0
	fileCountUpdated1=0
	fileCountUpdated2=0
	fileCountRemoved=0
	fileCountExcluded=0
	fileCountUptodate=0
	fileCountSkipped=0

	fileCountSizeTotal=0
	fileCountSizeAdded=0
	fileCountSizeUpdated1=0
	fileCountSizeUpdated2=0
	fileCountSizeRemoved=0
	fileCountSizeExcluded=0
	fileCountSizeUptodate=0
	fileCountSizeSkipped=0
}

function saveVariablesState_Step_1_Statistics()
{
	local fullFilename="$(getBackupFileName "Count_Step_1" "$CAT_STATISTICS" 0)"

	echo "
	$fileCountTotal
	$fileCountAdded
	$fileCountUpdated1
	$fileCountUpdated2
	$fileCountRemoved
	$fileCountExcluded
	$fileCountUptodate
	$fileCountSkipped
	$fileCountSizeTotal
	$fileCountSizeAdded
	$fileCountSizeUpdated1
	$fileCountSizeUpdated2
	$fileCountSizeRemoved
	$fileCountSizeExcluded
	$fileCountSizeUptodate
	$fileCountSizeSkipped" > "$fullFilename"
}

function loadVariablesState_Step_1_Statistics()
{
	local fullFilename="$(getBackupFileName "Count_Step_1" "$CAT_STATISTICS" 0)"
	local _values

	_values=( $(cat "$fullFilename") )
	fileCountTotal="${_values[0]}"
	fileCountAdded="${_values[1]}"
	fileCountUpdated1="${_values[2]}"
	fileCountUpdated2="${_values[3]}"
	fileCountRemoved="${_values[4]}"
	fileCountExcluded="${_values[5]}"
	fileCountUptodate="${_values[6]}"
	fileCountSkipped="${_values[7]}"

	fileCountSizeTotal="${_values[8]}"
	fileCountSizeAdded="${_values[9]}"
	fileCountSizeUpdated1="${_values[10]}"
	fileCountSizeUpdated2="${_values[11]}"
	fileCountSizeRemoved="${_values[12]}"
	fileCountSizeExcluded="${_values[13]}"
	fileCountSizeUptodate="${_values[14]}"
	fileCountSizeSkipped="${_values[15]}"
}

function initVariablesState_Step_2()
{
	progress_total_item_1=$fileCountExcluded
	progress_total_size_1=$fileCountSizeExcluded
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
	local timer _size _count

	getTimerV timer
	formatSizeV $count_size 1 '_size'
	printf -v _count '%9d' $count_files

	echo -ne "$timer Count : $_count $_size - $_full_relative_folder_name${ES_CURSOR_TO_LINE_END}\r"
}

function countFiles()
{
	updateScreenCurrentAction 'Rotation of the archived files :' "Count current backup size..."

	if checkSectionStatus "Rotation-Count" "$hostBackuped"; then

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		local    pos_value pos_total
		local -i column_index=9 skip_output=0

		local path_source
		local log_filename

		local -i max_filename_size
		local -i canal canal_stat

		local -i count_files count_size total_files=0 total_size=0
		local    padded_count_files padded_count_size padded_filename padded_size_file timer

		echo -en "$(getCSI_CursorMove Position $lineIndex 1)Current"

		for host_folder in "${HOSTS_LIST[@]}"; do
			if checkSectionStatus "Rotation-$host_folder-Count" "$hostBackuped"; then
				pos_value="$(getCSI_CursorMove Position $lineIndex $(( column_index + 15 )))"
				pos_total="$(getCSI_CursorMove Position $(( lineIndex + 3 )) 9)"
				posFilename="$(getCSI_CursorMove Position $(( lineIndex + 6 )) 1)"

				path_source="$PATH_BACKUP_FOLDER/$host_folder/Current"
				log_filename="Rotation-$host_folder-Count.files.log"

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 '' '')") ))

				exec {canal_stat}>>"$pathWorkingDirectoryRAM/$log_filename"

				count_files=0
				count_size=0

				echo -en "${pos_total}$(getCSI_CursorMove Column 1)${S_BOWHI}Total${S_NO}"
				echoStat 0 0 "${pos_value}"

				while IFS= read -u ${canal} file_data; do	# TODO use multi vars - check whole source code for this...
					echo "$file_data" >&${canal_stat}

					file_size=${file_data:0:12}
					filename="${file_data:19}"

					(( count_size += file_size, ++count_files, total_size += file_size, ++total_files ))

					(( ++skip_output % SKIP_INTERVAL == 0 )) && {
						echoStat $count_files $count_size "${pos_value}" "${S_NOWHI}"
						echoStat $total_files $total_size "${pos_total}" "${S_NOWHI}"

						echoFilename "/$host_folder/Current/$filename" $file_size '' ''
					}
				done {canal}< <(find -P "$path_source" -type f,l,p,s,b,c -printf "%12s %y %3d %P\n")

				echoStat $count_files $count_size "${pos_value}" "${S_NOWHI}"

				exec {canal_stat}>&-
				mv "$pathWorkingDirectoryRAM/$log_filename" "$pathWorkingDirectory/$log_filename"

				makeSectionStatusDone "Rotation-$host_folder-Count" "$hostBackuped"
			fi

			(( column_index += 45 ))
		done

		echoStat $total_files $total_size "${pos_total}" "${S_NOWHI}"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		makeSectionStatusDone "Rotation-Count" "$hostBackuped"
	fi


# 	local _full_relative_folder_name="${1}"
#
# 	if [ "$(checkStatus "Count_$_full_relative_folder_name")" == 'Uncompleted' ]; then
#
# 		local source_folder="$PATH_BACKUP_FOLDER/$_full_relative_folder_name"
# 		local _skip_output=0
#
# 		local _count_full_file_name="$(getBackupFileName "Count_$_full_relative_folder_name" "$CAT_STATISTICS" 0)"
# 		local _log_full_file_name="$(getBackupFileName "Count_LOG_$_full_relative_folder_name" "$CAT_STATISTICS")"
# 		echo -n '' > "$_log_full_file_name"
#
# 		local file_data file_size count_files=0 count_size=0
#
# 		showProgress_CountFiles
#
# 		exec {pipe_id[1]}<>"$MAIN_PIPE"
# 		exec {pipe_id[2]}>"$_log_full_file_name"
#
# 		{
# 			find -P "$source_folder" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n'
# 			echo ':END:'
# 		} >&${pipe_id[1]} &
#
# 		while IFS= read -u ${pipe_id[1]} file_data; do
# 			if [ ':END:' == "$file_data" ]; then
# 				break
# 			fi
#
# 			echo "$file_data" >&${pipe_id[2]}
#
# 			file_size=${file_data:0:12}
#
# 			(( count_size += file_size, ++count_files ))
#
# 			if [ $(( ++_skip_output % 653 )) -eq 0 ]; then
# 				showProgress_CountFiles
# 			fi
# 		done
#
# 		exec {pipe_id[1]}>&-
# 		exec {pipe_id[2]}>&-
#
# 		showProgress_CountFiles
# 		if [ $count_files -ne 0 ]; then
# 			echo
# 		fi
#
# 		echo "$count_files $count_size" > "$_count_full_file_name"
# 		keepBackupFile "Count_log_$_full_relative_folder_name" "$CAT_STATISTICS"
#
# 		makeStatusDone "Count_$_full_relative_folder_name"
# 	fi
}

# function showProgress_Rotation()
# {
# 	local timer file_name_text size1 size2 size3 size4
#
# 	getTimerV 'timer'
# 	shortenFileNameV 'file_name_text' "/$filename" $max_file_name_size
# 	formatSizeV 'size1' $file_size 15
# 	formatSizeV 'size2' $count_size_trashed
# 	formatSizeV 'size3' $count_size
# 	formatSizeV 'size4' $count_size_rotation
#
# 	echo -e "$timer $action $size1 ${action_color}$file_name_text${S_R_AL}${ES_CURSOR_TO_LINE_END}"
# 	echo -e "$timer $action_context : ${S_NORED}${count_files_trashed} $size2 - ${S_NOWHI}${count_files} $size3 / ${S_NOWHI}${count_files_rotation} $size4 ${S_R_AL}${ES_CURSOR_TO_LINE_END}"
# 	echo -ne "$timer $rotationStatus $backupLastDateText\r${CO_UP_1}"
# }

# function removeTrashedContent
# {
# 	updateScreenCurrentAction 'Rotation of the archived files :' 'Remove the trashed content'
#
# 	if checkSectionStatus 'Rotation-Trash' "$hostBackuped"; then
# 		local -r source="$PATH_BACKUP_FOLDER/$TRASH_FOLDER"
#
# 		local -i canal canal_stat
#
# 		local -r log_filename="Rotation-Trashed.files.log"
#
# 		local max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "
#
# 		(( max_file_name_size = $(tput cols) - ${#max_file_name_size} ))
#
# 		exec {canal_stat}>"$pathWorkingDirectoryRAM/$log_filename"
#
# 		local action="${A_REMOVED_R}"
# 		local action_color="${S_NORED}"
# 		local action_context="Cleaning the trashed content"
#
# 		local    file_data filename
# 		local -i file_size count_files=0 count_size=0
#
# 		while IFS= read -u ${canal} file_data; do
# 			echo "$file_data" >&${canal_stat}
#
# 			file_size=${file_data:0:12}	# TODO : in read
# 			filename="$TRASH_FOLDER/${file_data:19}"
#
# 			(( count_size_trashed += file_size, ++count_files_trashed ))
#
# 			showProgress_Rotation
# 		done {canal}< <(find -P "$source" -type f,l,p,s,b,c -printf "%12s %y %3d %P\n" -delete)
#
# 		exec {canal_stat}>&-
#
# 		echo "$count_files_trashed $count_size_trashed" >> "$PATHFILE_ROTATION_STATISTICS"
# 		mv "$pathWorkingDirectoryRAM/$log_filename" "$pathWorkingDirectory/$log_filename"
#
# 		echo -ne "${ES_ENTIRE_LINE}\n${ES_ENTIRE_LINE}\r"
#
# 		makeSectionStatusDone 'Rotation-Trash' "$hostBackuped"
# 	fi
# }

function rotateFolder
{
	local -r source="${1}"
	local -r destination="${2}"

	updateScreenCurrentAction 'Rotation of the archived files :' "Rotation of $source..."

	if checkSectionStatus "Rotation-$source" "$hostBackuped"; then

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		local    pos_title
		local    pos_value1 pos_value2 pos_value3
		local    pos_total1 pos_total2 pos_total3
		local -i column_index=9 skip_output=0

		function _setPositionVar
		{
			local -i line_index=${1} column_index=${2}

			pos_value2="$(getCSI_CursorMove Position $(( line_index - 2 )) $(( column_index + 15 )))"

			pos_title="$(getCSI_CursorMove Position $line_index 1)"

			pos_value1="$(getCSI_CursorMove Position $line_index $column_index)"
			pos_value3="$(getCSI_CursorMove Position $line_index $(( column_index + 30 )))"

			(( line_index += 4 ))

			pos_total1="$(getCSI_CursorMove Position $line_index $column_index)"
			pos_total2="$(getCSI_CursorMove Position $line_index $(( column_index + 15 )))"
			pos_total3="$(getCSI_CursorMove Position $line_index $(( column_index + 30 )))"

			(( line_index += 3 ))

			posFilename="$(getCSI_CursorMove Position $line_index 1)"
		}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		local path_source path_destination path_removed_r path_removed_e path_overwrited

		local 	 log_filename
		local -i max_filename_size

		local -i count_removed_files count_overwrited_files count_moved_files
		local -i count_removed_files_size count_overwrited_files_size count_moved_files_size

		local    padded_count_files padded_size_files padded_filename timer period

		local    host_folder file_data filename
		local -i file_size
		local -i canal canal_stat

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		for host_folder in "${HOSTS_LIST[@]}"; do
			_setPositionVar $lineIndex $column_index

			echo -en "${pos_title}$source"
			echoStat 0 0 "${pos_value1}"
			(( index < ${#PERIOD_FOLDERS[@]} - 1 )) &&
				echoStat 0 0 "${pos_value2}"
			echoStat 0 0 "${pos_value3}"

			if checkSectionStatus "Rotation-$host_folder-$source" "$hostBackuped"; then

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				if [[ "$destination" == "$TRASH_FOLDER" ]]; then
					path_source="$PATH_BACKUP_FOLDER/$host_folder/$source"
					path_destination="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"

					path_removed_e="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$host_folder/$source"
					path_removed_r="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"
					path_overwrited="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"
				else
					path_source="$PATH_BACKUP_FOLDER/$host_folder/$source"
					path_destination="$PATH_BACKUP_FOLDER/$host_folder/$destination"

					path_removed_e="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$host_folder/$source"
					path_removed_r="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"
					path_overwrited="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$destination"
				fi

				log_filename="Rotation-$host_folder-$source.files.log"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				(( max_filename_size = $(tput cols) - $(getCSI_StringLength "$(getTimerV '') $A_TAG_LENGTH_SIZE $(formatSizeV '' 0 12) ") ))

				exec {canal_stat}>>"$pathWorkingDirectoryRAM/$log_filename"

				count_removed_files=0
				count_overwrited_files=0
				count_moved_files=0
				count_removed_files_size=0
				count_overwrited_files_size=0
				count_moved_files_size=0

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				if checkSectionStatus "Rotation-$host_folder-$source-Trash" "$hostBackuped"; then
					(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

					while IFS= read -u ${canal} file_data; do	# TODO use multi vars - check whole source code for this...
						echo "R $file_data" >&${canal_stat}	# TODO put the R in the find ??

						file_size=${file_data:0:12}
						filename="${file_data:19}" # TODO find how to show a better path...

						(( count_removed_files_size += file_size, ++count_removed_files, totalSizeRemoved += file_size, ++totalFilesRemoved ))

						(( ++skip_output % SKIP_INTERVAL == 0 )) && {
							echoStat $count_removed_files $count_removed_files_size "${pos_value1}" "${S_NOLRE}"
							echoStat $totalFilesRemoved $totalSizeRemoved "${pos_total1}" "${S_NOLRE}"
							echoFilename "$filename" $file_size "$A_REMOVED_R" "$S_NOLRE"
						}
					done {canal}< <(find -P "$path_removed_r" -type f,l,p,s,b,c -printf "%12s %y %3d %P\n" -delete; find -P "$path_removed_e" -type f,l,p,s,b,c -printf "%12s %y %3d %P\n" -delete)

					echoStat $count_removed_files $count_removed_files_size "${pos_value1}" "${S_NOLRE}"
					echoStat $totalFilesRemoved $totalSizeRemoved "${pos_total1}" "${S_NOLRE}"

					(( count_operation[index] += count_removed_files )) || :

					makeSectionStatusDone "Rotation-$host_folder-$source-Trash" "$hostBackuped"
				fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				if checkSectionStatus "Rotation-$host_folder-$source-Move" "$hostBackuped"; then
					[[ "$source" =~ ^(Day|Week|Month|Year)-[0-9]+$ ]] &&
						period="${BASH_REMATCH[1]}"

					if 	[[ "$period" == 'Year'  && $isNewYear == 1  ]] ||
						[[ "$period" == 'Month' && $isNewMonth == 1 ]] ||
						[[ "$period" == 'Week'  && $isNewWeek == 1  ]] ||
						[[ "$period" == 'Day'   && $isNewDay == 1   ]]; then

						(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

						while IFS= read -u ${canal} file_data; do
							file_size=${file_data:0:12}
							filename="${file_data:19}"
							path_name="${filename%/*}"

							getFileTypeV 'check_dest' "$path_destination/$filename"
							if [[ "$check_dest" != '   ' ]]; then
								[[ -n "$path_name" ]] &&
									clonePathDetails "$path_destination" "$path_overwrited" "$path_name" # TODO : Do this in a asynchron subshell ??
								mv -f "$path_destination/$filename" "$path_overwrited/$filename"

								echo "O $file_data" >&${canal_stat}

								(( count_overwrited_files_size += file_size, ++count_overwrited_files, totalSizeOverwrited += file_size, ++totalFilesOverwrited ))	# BUG : correct the file_size !

								(( ++skip_output % SKIP_INTERVAL == 0 )) && {
									echoStat $count_overwrited_files $count_overwrited_files_size "${pos_value2}" "${S_NOYEL}"
									echoStat $totalFilesOverwrited $totalSizeOverwrited "${pos_total2}" "${S_NOYEL}"
									echoFilename "$filename" $file_size "$A_BACKUPED_Y" "$S_NOYEL"
								}
							fi

							[[ -n "$path_name" ]] &&
								clonePathDetails "$path_source" "$path_destination" "$path_name"
							mv -f "$path_source/$filename" "$path_destination/$filename"

							echo "M $file_data" >&${canal_stat}

							(( count_moved_files_size += file_size, ++count_moved_files, totalSizeMoved += file_size, ++totalFilesMoved ))

							(( ++skip_output % SKIP_INTERVAL == 0 )) && {
								echoStat $count_moved_files $count_moved_files_size "${pos_value3}"
								echoStat $totalFilesMoved $totalSizeMoved "${pos_total3}"
								[[ "$check_dest" == '   ' ]] &&
									echoFilename "$filename" $file_size "$A_MOVED_G" ''
							}
						done {canal}< <(find -P "$path_source" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n')

						echoStat $count_overwrited_files $count_overwrited_files_size "${pos_value2}" "${S_NOYEL}"
						echoStat $totalFilesOverwrited $totalSizeOverwrited "${pos_total2}" "${S_NOYEL}"
						echoStat $count_moved_files $count_moved_files_size "${pos_value3}"
						echoStat $totalFilesMoved $totalSizeMoved "${pos_total3}"

						(( count_operation[index] += count_moved_files, count_operation[index + 1] += count_overwrited_files)) || :
					fi

					makeSectionStatusDone "Rotation-$host_folder-$source-Move" "$hostBackuped"
				fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				exec {canal_stat}>&-
				mv "$pathWorkingDirectoryRAM/$log_filename" "$pathWorkingDirectory/$log_filename"

				makeSectionStatusDone "Rotation-$host_folder-$source" "$hostBackuped"
			fi

			(( column_index += 45 ))
		done

		makeSectionStatusDone "Rotation-$source" "$hostBackuped"

		unset -f _setPositionVar
	fi

# 		local host_folder source_folder destination_folder overwrited_files_folder log_filename
# 		local -i canal canal_stat conflict
#
# 		local max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "
#
# 		(( max_file_name_size = $(tput cols) - ${#max_file_name_size} ))
#
# 		local action action_color action_context file_data filename path_name check_dest
# 		local -i file_size count_files count_size
#
#
# 		for host_folder in "${HOSTS_LIST[@]}"; do
# 			if checkSectionStatus "Rotation-$host_folder-$source" "$hostBackuped"; then
# 				source_folder="$PATH_BACKUP_FOLDER/$host_folder/${source}"
# 				[[ "$destination" == "$TRASH_FOLDER" ]] &&
# 					destination_folder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/Year-5" ||
# 					destination_folder="$PATH_BACKUP_FOLDER/$host_folder/${destination}"
# 				overwrited_files_folder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/${destination}"
#
# 				log_filename="Rotation-$host_folder-$source.files.log"
#
# 				exec {canal_stat}>"$pathWorkingDirectoryRAM/$log_filename"
#
# 				action_context="Rotation of ($host_folder) ${S_NOWHI}${source}${S_R_AL} in ${destination}"
#
# 				count_files=0
# 				count_size=0
#
# 				while IFS= read -u ${canal} file_data; do
# 					file_size=${file_data:0:12}
# 					filename="${file_data:19}"
# 					path_name="${filename%/*}"
# 					getFileTypeV 'check_dest' "$destination_folder/$filename"
#
# 					if [[ "$check_dest" != '   ' ]]; then
# 						clonePathDetails "$destination_folder" "$overwrited_files_folder" "$path_name"
# 						mv -f "$destination_folder/$filename" "$overwrited_files_folder/$filename"
#
# 						conflict=1
# 						action="${A_BACKUPED_G}"
# 						action_color="${S_BOLGR}"
# 					else
# 						conflict=0
# 						action="${A_MOVED_G}"
# 						action_color="${S_NOGRE}"
# 					fi
#
# 					echo "$conflict $file_data" >&${canal_stat}
#
# 					(( count_size_rotation += file_size, ++count_files_rotation, count_size += file_size, ++count_files ))
#
# 					[[ -n "$path_name" ]] &&
# 						clonePathDetails "$source_folder" "$destination_folder" "$path_name"
# 					mv -f "$source_folder/$filename" "$destination_folder/$filename"
#
# 					filename="$host_folder/$source/$filename"
# 					showProgress_Rotation
# 				done {canal}< <(find -P "$source_folder" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n')
#
# 				exec {canal_stat}>&-
#
# 				echo "$count_files_rotation $count_size_rotation" >> "$PATHFILE_ROTATION_STATISTICS"
# 				mv "$pathWorkingDirectoryRAM/$log_filename" "$pathWorkingDirectory/$log_filename"
#
# 				echo -ne "${ES_ENTIRE_LINE}\n${ES_ENTIRE_LINE}\r"
#
# 				makeSectionStatusDone "Rotation-$host_folder-$source" "$hostBackuped"
# 			fi
# 		done
#
# 		makeSectionStatusDone "Rotation-$source" "$hostBackuped"
# 	fi

}

function openFilesListsSpliter()
{
	local -r return_var_name="${1}"
	local -r dest_file_name="${2}"

	local -i canal_main

	local -r pipe_filename="$pathWorkingDirectoryRAM/${dest_file_name}.pipe"

	rm -f "$pipe_filename"
	mkfifo "$pipe_filename"
	exec {canal_main}<>"$pipe_filename"

	printf -v $return_var_name '%d' $canal_main

	{	# in a subshell here...
		declare -i index
		declare    output_filename
		declare -ai canals=( )

		for index in {1..9}; do
			output_filename="$pathWorkingDirectoryRAM/${dest_file_name}-$index.files"

# 			echo -n '' > "$output_filename"
			rm -f "$output_filename"
			exec {canals[index]}>"$output_filename"
		done

		declare file_data filename
		declare file_size

		pipeReceivedEnd=0
		pipeExpectedEnd=1

		while IFS= read -t 60 -u ${canal_main} file_data || checkLoopFail; do
			[[ -z "$file_data" ]] && continue
			checkLoopEnd "$file_data" || { (( $? == 1 )) && break || continue; }

			file_size="${file_data:0:12}"
			filename="${file_data:13}"

			if (( file_size < 1000 )); then
				echo "$file_size $filename" >&${canals[1]}
			elif (( file_size < 10000 )); then
				echo "$file_size $filename" >&${canals[2]}
			elif (( file_size < 100000 )); then
				echo "$file_size $filename" >&${canals[3]}
			elif (( file_size < 1000000 )); then
				echo "$file_size $filename" >&${canals[4]}
			elif (( file_size < 10000000 )); then
				echo "$file_size $filename" >&${canals[5]}
			elif (( file_size < 100000000 )); then
				echo "$file_size $filename" >&${canals[6]}
			elif (( file_size < 1000000000 )); then
				echo "$file_size $filename" >&${canals[7]}
			elif (( file_size < 10000000000 )); then
				echo "$file_size $filename" >&${canals[8]}
			else
				echo "$file_size $filename" >&${canals[9]}
			fi
		done

		for index in {1..9}; do
			exec {canals[index]}>&-
		done
	} &
}

function closeFilesListsSpliter()
{
	local -r dest_file_name="${1}"
	local -r canal_main="${2}"

	local -r pipe_filename="$pathWorkingDirectoryRAM/${dest_file_name}.pipe"

	echo "$LOOP_END_TAG" >&${canal_main}
	sleep 0.5
	exec {canal_main}>&-
	rm -f "$pipe_filename"

	local -i index
	local    output_filename

	for index in {1..9}; do
		output_filename="${dest_file_name}-$index.files"
		mv "$pathWorkingDirectoryRAM/$output_filename" "$pathWorkingDirectory/$output_filename"
	done
}

# function updateLastAction()
# {
# 	local action="${1}"
#
# 	if (( lastAction != action )); then
# 		lastAction=$action
# 		case $action in
# 			1)
# 				action_tag="$A_UP_TO_DATE_G"
# 				action_color="${S_NOGRE}"
# 				action__flags='      '
# 				;;
# 			2)
# 				action_tag="$A_UPDATED_Y"
# 				action_color="${S_NOYEL}"
# 				;;
# 			3)
# 				action_tag="$A_UPDATED_Y"
# 				action_color="${S_NOYEL}"
# 				;;
# 			4)
# 				action_tag="$A_SKIPPED"
# 				action_color="${S_NOCYA}"
# 				action__flags='      '
# 				;;
# 			51)
# 				action_tag="$A_REMOVED_R"
# 				action_color="${S_NORED}"
# 				action__flags='      '
# 				;;
# 			52)
# 				action_tag="$A_EXCLUDED_R"
# 				action_color="${S_NOLRE}"
# 				action__flags='      '
# 				;;
# 			6)
# 				action_tag="$A_ADDED_B"
# 				action_color="${S_NOLBL}"
# 				action__flags='      '
# 				;;
#
# 		esac
# 	fi
# }

# function showProgress_Step_1()
# {
# 	local check_timer filename_text
#
# 	printf -v check_timer '%(%s)T'
# 	(( check_timer > lastTime )) && {
# 		lastTime=$check_timer
#
# 		local size_total size_uptodate size_updated size_removed size_excluded size_added align_size file_count_updated size_skipped
#
# 		getTimerV 'timer'
#
# 		formatSizeV 'size_total' "$fileCountSizeTotal" 15
# 		formatSizeV 'size_uptodate' "$fileCountSizeUptodate" 15
# 		formatSizeV 'size_updated' "$fileCountSizeUpdated1" 15
# 		formatSizeV 'size_removed' "$fileCountSizeRemoved" 15
# 		formatSizeV 'size_excluded' "$fileCountSizeExcluded" 15
# 		formatSizeV 'size_added' "$fileCountSizeAdded" 15
# 		formatSizeV 'size_skipped' "$fileCountSizeSkipped" 15
#
# 		max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE ?????? "
# 		(( file_count_updated = fileCountUpdated1 + fileCountUpdated2, align_size = ${#action_context_size} - ${#rotationStatusSize} - 1, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))
#
# 		printf -v step_1_progress1 "${S_NOWHI}%15d ${S_GRE}%15d ${S_LBL}%15d ${S_YEL}%15d ${S_RED}%15d ${S_LRE}%15d ${S_CYA}%15d" ${fileCountTotal} ${fileCountUptodate} ${fileCountAdded} ${file_count_updated} ${fileCountRemoved} ${fileCountExcluded} ${fileCountSkipped}
#
# 		step_1_progress1="$timer $action_context $step_1_progress1"
# 		step_1_progress2="$timer $rotationStatus ${PADDING_SPACE:0:align_size} $size_total $size_uptodate $size_added $size_updated $size_removed $size_excluded $size_skipped"
# 	}
#
# 	shortenFileNameV 'filename_text' "/$filename" "$max_file_name_size"
#
# 	if (( file_type == TYPE_FOLDER )); then
# 		file_size="${action_color}${S_DA}$FOLDER_SIZE${S_R_AL}"
# 		filename_text="${action_color}${S_DA}$filename_text"
# 	elif (( file_type == TYPE_SYMLINK )); then
# 		file_size="${action_color}${S_IT}$SYMLINK_SIZE${S_R_AL}"
# 		filename_text="${action_color}${S_IT}$filename_text"
# 	else
# 		formatSizeV 'file_size' $file_size 15
# 		filename_text="${action_color}$filename_text"
# 	fi
#
# 	echo -e "$timer $action_tag $file_size $action__flags $filename_text${S_R_AL}${ES_CURSOR_TO_LINE_END}"
# 	echo -e "$step_1_progress1${S_R_AL}${ES_CURSOR_TO_LINE_END}"
# 	echo -ne "$step_1_progress2${S_R_AL}\r${CO_UP_1}"
# }

function showProgress_Step_2
{
	local timer filename_text size_1 size_2

	getTimerV timer

	shortenFileNameV 'filename_text' "/$filename" "$max_file_name_size"
	formatSizeV 'size_1' $file_size 15
	formatSizeV 'size_2' $progress_total_size_2 15

	printf -v step_2_progress3 "+ ${S_NOLRE}%15d" ${progress_total_item_2}

	echo -e "$timer $action_tag $size_1 $filename_text${S_R_AL}${ES_CURSOR_TO_LINE_END}"
	echo -e "$timer $action_context $step_2_progress1 $step_2_progress3${S_R_AL}"
	echo -ne "$timer $rotationStatus ${PADDING_SPACE:0:align_size} $step_2_progress2 $progress_total_size_2${S_R_AL}\r${CO_UP_1}"
}



################################################################################################################################################################
################################################################################################################################################################
####                              ##############################################################################################################################
####     The main script code     ##############################################################################################################################
####                              ##############################################################################################################################
################################################################################################################################################################
################################################################################################################################################################

declare hostBackuped pathWorkingDirectory pathWorkingDirectoryRAM

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

hostBackuped='INITIALIZATION'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Day-1/home
# echo "Day-1 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Day-3/home
# echo "Day-3 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Day-5/home
# echo "Day-5 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Day-6/home
# echo "Day-6 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Day-7/home
# echo "Day-7 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Week-4/home
# echo "Week-4 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Month-11/home
# echo "Month-11 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Month-12/home
# echo "Month-12 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Year-3/home
# echo "Year-3 OK"
# cp -rfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Year-5/home
# echo "Year-5 OK"
#
# safeExit

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --



################################################################################
##      Initialize bases fonlders                                             ##
################################################################################

mkdir -p "$PATH_BACKUP_FOLDER"
mkdir -p "$PATH_BACKUP_FOLDER/$STATUS_FOLDER"

for hostFolder in "$hostBackuped" "${HOSTS_LIST[@]}"; do
	mkdir -p "$PATH_TMP/$hostFolder"
	mkdir -p "$PATH_TMP/$hostFolder/$VARIABLES_FOLDER"
	mkdir -p "$PATH_TMP/MEMORY/$hostFolder"
done

for hostFolder in "${HOSTS_LIST[@]}"; do
	for periodFolder in ${PERIOD_FOLDERS[@]} Current; do
		mkdir -p "$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$hostFolder/$periodFolder"
		mkdir -p "$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$hostFolder/$periodFolder"
		mkdir -p "$PATH_BACKUP_FOLDER/$hostFolder/$periodFolder"
	done
done

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# takeWorkingDirectory TODO

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# == unset later ==
declare selected choice choice2

echo

if checkSectionStatus 'Backup-Started'; then
# 	rm --preserve-root -f "$PATH_TMP/brutal.mode"

	(( BRUTAL > 0 )) && {
		echo -e "${A_WARNING_NR} The backup is in ${S_NORED}BRUTAL MODE${S_NO}, this will take a VERY LONG time !!"
		echo -ne "${A_TAG_LENGTH_SIZE} Do you want to continue anyway ? "; getWordUserChoiceV 'selected' 'Yes No'

		case $selected in
			1)
				echo -e "\r${A_OK}"
				echo 'Activated' > "$PATH_TMP/brutal.mode"
				;;
			2)
				echo -e "\r${A_ABORTED_NY}"
				safeExit 1
				;;
		esac

		sleep 2
	}

	makeSectionStatusDone 'Backup-Started'
else
	choice='New Continue'
	choice2=''

	echo -e "${A_WARNING_NY} A backup is already ${S_NORED}IN PROGRESS${S_NO}, but has probably crashed..."

	[[ ($BRUTAL == 1 && ! -f "$PATH_TMP/brutal.mode") || (-f "$PATH_TMP/brutal.mode" && $BRUTAL == 0) ]] && {
		echo -e "${S_NORED}! you can't choose continue because the BRUTAL MODE was not the same in this backup...${S_NO}"
		choice='New'
		choice2="${S_BA}${S_DA}${S_YEL}Continue${S_NO} "
	}

	echo -ne "${A_TAG_LENGTH_SIZE} Do you want to try to continue, or start a new one ? $choice2"; getWordUserChoiceV 'selected' $choice

	case $selected in
		1)
			echo -e "\r${A_ABORTED_NY}"
# 			for hostFolder in "$hostBackuped" "${HOSTS_LIST[@]}"; do # TODO
# 				rm -rf "$PATH_BACKUP_FOLDER/$STATUS_FOLDER/$hostFolder/"*
# 			done
			;;
		2)
			echo -e "\r${A_OK}"
			;;
	esac

	sleep 2
fi

unset selected choice choice2

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

clear



################################################################################
##      Make rotation of archived files                                       ##
################################################################################

pathWorkingDirectory="$(getHostWorkingDirectory)"
pathWorkingDirectoryRAM="$(getHostWorkingDirectory 1)"

if checkSectionStatus 'Rotation-Finished' "$hostBackuped"; then
	updateScreenCurrentAction 'Rotation of the archived files'



#==============================================================================#
#==     Find who need to be rotated                                          ==#
#==============================================================================#

	if checkSectionStatus 'Rotation-Details' "$hostBackuped"; then
		updateScreenCurrentAction 'Rotation of the archived files :' 'Check date'

		# == keeped ==
		declare -i isNewDay=0 isNewWeek=0 isNewMonth=0 isNewYear=0
		declare -i isYesterday dayOfWeek rotationStatusSize

		declare		backupLastDateText='This backup is the first one !'
		declare		rotationStatus=''

		# == unset later ==
		declare		yesterday=''
		declare -ai backupLastDate=( 0 0 0 0 0 ) backupCurrentDate backupLastSince

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		[[ -f "$PATHFILE_LAST_BACKUP_DATE" ]] && {
			read -a backupLastDate < "$PATHFILE_LAST_BACKUP_DATE"

# 			(( LastBackupSince = SCRIPT_START_TIME - backupLastDate[4], Days = LastBackupSince / 86400, Hours = (LastBackupSince % 86400) / 3600, Minutes = ((LastBackupSince % 86400) % 3600) / 60, 1 ))
			backupLastSince=( $(TZ=UTC printf '%(%-j %-H %-M %-S)T' $(( SCRIPT_START_TIME - backupLastDate[0] )) ) )
			(( backupLastSince[0]-- ))

# 			TODO : show day only if > 0 ?
			# BUG : pad the time here...
			backupLastDateText="The last backup was at $(cat "$PATHFILE_LAST_BACKUP_DATE.txt"), ${S_BOWHI}${backupLastSince[0]}${S_NOWHI}D ${S_BOWHI}${backupLastSince[1]}${S_NOWHI}H${S_BOWHI}${backupLastSince[2]}${S_NOWHI}:${S_BOWHI}${backupLastSince[3]}${S_NOWHI}${S_R_AL} ago"
		}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		(( isYesterday = $(date '+%-H') <= 5 ? 1 : 0, isYesterday )) &&
			yesterday='-d yesterday'

		backupCurrentDate=( $(date '+%s') $(date $yesterday '+%-j +%-V %-d %-m %-Y') )
		dayOfWeek="$(date $yesterday '+%w')"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		((	isNewYear  = backupCurrentDate[5] > backupLastDate[5] ? 1 : 0,
			isNewMonth = backupCurrentDate[4] > backupLastDate[4] ? 1 : 0 | isNewYear,
			isNewDay   = backupCurrentDate[3] > backupLastDate[3] ? 1 : 0 | isNewMonth,

			isNewWeek  = ((backupCurrentDate[2] > backupLastDate[2]) ||
						  ((backupCurrentDate[2] == 1) && (backupLastDate[2] != 1))) ? 1 : 0	)) || :

# 		{ # FOR DEBUG		####################################################################################################################################

			isNewDay=1

# 		}					####################################################################################################################################

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		(( isNewDay   == 1 )) && rotationStatus="${S_NOGRE}NEW-DAY"
		(( isNewMonth == 1 )) && rotationStatus="${S_NOGRE}NEW-MONTH"
		(( isNewYear  == 1 )) && rotationStatus="${S_NOGRE}NEW-YEAR"
		(( isNewWeek  == 1 )) && rotationStatus+=" ${S_NOYEL}${S_B_RED} NEW-WEEK "
		rotationStatus+="${S_R_AL}"

		rotationStatusSize=$(getCSI_StringLength "$rotationStatus")

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		echo "${backupCurrentDate[*]}"   			>| "$PATHFILE_LAST_BACKUP_DATE"
		echo "$(date '+%A %-d %B %Y @ %H:%M:%S')"	>| "$PATHFILE_LAST_BACKUP_DATE.txt"

		declare -p isNewDay isNewWeek isNewMonth isNewYear isYesterday dayOfWeek backupLastDateText rotationStatus rotationStatusSize > "$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Details.var"

		makeSectionStatusDone 'Rotation-Details' "$hostBackuped"

		unset backupLastDate backupCurrentDate yesterday backupLastSince
	else
		. "$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Details.var"
	fi

	# pass this variables as constants...
	declare -ir isNewDay isNewWeek isNewMonth isNewYear
	declare -ir isYesterday dayOfWeek rotationStatusSize
	declare	-r	backupLastDateText rotationStatus


	echo -e "$(getCSI_CursorMove Position 2 1)$backupLastDateText"



#==============================================================================#
#==     Rotate all files that need it                                        ==#
#==============================================================================#

	declare -i count_size_trashed=0 count_files_trashed=0 count_size_rotation=0 count_files_rotation=0	# TODO : change name
	declare -r PATHFILE_ROTATION_STATISTICS="$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Statistics.var"

	if [[ -f "$PATHFILE_ROTATION_STATISTICS" ]]; then	# TODO
		. "$PATHFILE_ROTATION_STATISTICS"
	else
		echo -n '' > "$PATHFILE_ROTATION_STATISTICS"
	fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	# == unset later ==
	declare 	hostName title padding="$(printf '%8s' ' ')"
	declare -i	spaceBefore spaceAfter

	echo -en "$(getCSI_CursorMove Position 4 1)$padding"
	for hostName in ${HOSTS_LIST[@]}; do

		hostName=" $hostName "

		(( spaceAfter = ${#hostName} / 2, spaceBefore = 22 - spaceAfter, spaceAfter = spaceBefore + (${#hostName} % 2) ))

		printf "%s${S_BOWHI}%s${S_NO}%s " "${PADDING_EQUAL:0:spaceBefore}" "$hostName" "${PADDING_EQUAL:0:spaceAfter}"
	done
	echo

	printf -v title '%-15s%-15s%-15s' '   Deleted' '   Trashed' '    Moved'
	echo -en "$padding"
	for hostName in ${HOSTS_LIST[@]}; do
		printf '%s' "$title"
	done

	unset hostName spaceBefore spaceAfter

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


# 	removeTrashedContent

	# == unset later ==
	declare -i	index=${#PERIOD_FOLDERS[@]} lineIndex=4
	declare 	periodFrom periodTo
	declare -ai count_operation
	declare -i  totalSizeRemoved=0    totalFilesRemoved=0
	declare -i  totalSizeOverwrited=0 totalFilesOverwrited=0
	declare -i  totalSizeMoved=0      totalFilesMoved=0

	echo -en "$(getCSI_CursorMove Position $(( lineIndex + 5 )) 1)$padding"
	for hostName in ${HOSTS_LIST[@]}; do
		printf '%s ' "$(echo "${PADDING_EQUAL:0:44}" | tr '=' '-')"
	done
	printf "\n${S_BOWHI}%-8s${S_NO}" "Total"
	for hostName in ${HOSTS_LIST[@]}; do
		printf "${S_NOWHI}%15d%15d%15d${S_NO}" 0 0 0
	done
	echo -en "\n$padding"
	for hostName in ${HOSTS_LIST[@]}; do
		echo -en "$(formatSizeV '' 0 15)$(formatSizeV '' 0 15)$(formatSizeV '' 0 15)"
	done

	count_operation[index]=0
	while (( lineIndex += 2, --index >= 0 )); do
		count_operation[index]=0

		periodFrom="${PERIOD_FOLDERS[index]}"
		periodTo="${PERIOD_FOLDERS[index+1]:-$TRASH_FOLDER}"

		rotateFolder "$periodFrom" "$periodTo"

		(( index > 0 )) &&
			echo -en "$(getCSI_CursorMove Position $(( lineIndex + 3 )) 1)$(getCSI_ScreenMove Insert 2)"

		(( index + 1 < ${#PERIOD_FOLDERS[@]} && count_operation[index + 1] == 0 )) && {
			(( lineIndex -= 2 ))
			echo -en "$(getCSI_CursorMove Position $lineIndex 1)$(getCSI_ScreenMove Remove 2)"
		}
	done

	(( count_operation[index + 1] == 0 )) && {
		(( lineIndex -= 2 ))
		echo -en "$(getCSI_CursorMove Position $lineIndex 1)$(getCSI_ScreenMove Remove 2)"
	}

	(( lineIndex += 5 ))
	echo -en "$(getCSI_CursorMove Position $lineIndex 1)$(getCSI_ScreenMove Insert 7)"

	unset index periodFrom periodTo  count_operation totalSizeRemoved totalFilesRemoved totalSizeOverwrited totalFilesOverwrited totalSizeMoved totalFilesMoved

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	printf -v title '%-15s%-15s%-15s' ' ' '    Count' ' '
	echo -en "$padding"
	for hostName in ${HOSTS_LIST[@]}; do
		printf '%s' "$title"
	done

	(( ++lineIndex ))

	countFiles

	updateScreenCurrentAction 'Rotation finished :' 'Press a key...'	# TODO : Blink ?
	read noKey

	unset title padding lineIndex noKey

# 	(( isNewYear == 1 )) && {
# 		rotateFolder 'Year-5' "$TRASH_FOLDER"
#
# 		rotateFolder 'Year-4' 'Year-5'
# 		rotateFolder 'Year-3' 'Year-4'
# 		rotateFolder 'Year-2' 'Year-3'
# 	}
#
# 	(( isNewMonth == 1 )) && {
# 		rotateFolder 'Month-12' 'Year-2'
# 		rotateFolder 'Month-11' 'Month-12'
# 		rotateFolder 'Month-10' 'Month-11'
# 		rotateFolder 'Month-9'  'Month-10'
# 		rotateFolder 'Month-8'  'Month-9'
# 		rotateFolder 'Month-7'  'Month-8'
# 		rotateFolder 'Month-6'  'Month-7'
# 		rotateFolder 'Month-5'  'Month-6'
# 		rotateFolder 'Month-4'  'Month-5'
# 		rotateFolder 'Month-3'  'Month-4'
# 		rotateFolder 'Month-2'  'Month-3'
# 	}
#
# 	(( isNewWeek == 1 )) && {
# 		rotateFolder 'Week-4' 'Month-2'
# 		rotateFolder 'Week-3' 'Week-4'
# 		rotateFolder 'Week-2' 'Week-3'
# 	}
#
# 	(( isNewDay == 1 )) && {
# 		rotateFolder 'Day-7' 'Week-2'
# 		rotateFolder 'Day-6' 'Day-7'
# 		rotateFolder 'Day-5' 'Day-6'
# 		rotateFolder 'Day-4' 'Day-5'
# 		rotateFolder 'Day-3' 'Day-4'
# 		rotateFolder 'Day-2' 'Day-3'
# 		rotateFolder 'Day-1' 'Day-2'
# 	}

	makeSectionStatusDone 'Rotation-Finished' "$hostBackuped"
else
	. "$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Details.var"
fi



################################################################################
################################################################################
####                                                                        ####
####     Make the backup of all hosts                                       ####
####                                                                        ####
################################################################################
################################################################################

TYPE_FILE=1
TYPE_FOLDER=2
TYPE_SYMLINK=3

for hostBackuped in "${HOSTS_LIST[@]}"; do
	updateScreenCurrentAction 'Initialize remote filesystem...'

	declare pathWorkingDirectory="$(getHostWorkingDirectory)"
	declare pathWorkingDirectoryRAM="$(getHostWorkingDirectory 1)"

	case "$hostBackuped" in
		'BravoTower')
			echo '	/bin
					/etc
					/usr
					/var
					/root
					/home/foophoenix
					/data
					/media/foophoenix/AppKDE
					/media/foophoenix/DataCenter
				' > "$pathWorkingDirectory/Include.items"

			echo '	/home/foophoenix/Data/Router/DataSierra
					/home/foophoenix/Data/Router/Home-FooPhoenix
 					/home/foophoenix/Data/Router/Root
					/home/foophoenix/Data/BackupSystem/BackupFolder
					/home/foophoenix/Data/BackupSystem/Root
# 					/media/foophoenix/DataCenter/.Trash
# 					/media/foophoenix/AppKDE/.Trash
				' > "$pathWorkingDirectory/Exclude.items"
			;;
		'Router')
			echo '	/bin
					/etc
					/usr
					/var
					/root
					/home/foophoenix
					/data
				' > "$pathWorkingDirectory/Include.items"

			echo '	/home/foophoenix/VirtualBox/BackupSystem/Snapshots
# 					/home/foophoenix/tmp
# 					/home/foophoenix/tmp/config-test-4
# 					/media/foophoenix/DataCenter/.Trash
# 					/media/foophoenix/AppKDE/.Trash
				' > "$pathWorkingDirectory/Exclude.items"
			;;
		*)
			errcho "Backup of '$hostBackuped' failed and skipped because no include/exclude configuration is made..."
			continue
			;;
	esac

	sed -i 's/^[[:blank:]]*//;/^[[:blank:]]*$/d;/^#/d' "$pathWorkingDirectory/Include.items"
	sed -i 's/^[[:blank:]]*//;/^[[:blank:]]*$/d;/^#/d' "$pathWorkingDirectory/Exclude.items"

	case "$hostBackuped" in
		'BravoTower')
			compress_details='-zz --compress-level=6 --skip-compress=rar'
			;;
		*)
			compress_details=''	# --bwlimit=30M
			;;
	esac

# 	echo
# 	echo -e "${S_BOWHI}              Start to make the backup of $hostBackuped...${S_R_AL}"

	# Check if the host is connected
	[[ "$(ssh $hostBackuped "echo 'ok'")" != 'ok' ]] && {
		# TODO : Show a message ??
		continue
	}

	mkdir -p "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped"
	[[ "$(ls -A "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped")" == '' ]] &&
		sshfs $hostBackuped:/ "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped" -o follow_symlinks -o ro -o cache=no -o ssh_command='ssh -c chacha20-poly1305@openssh.com -o Compression=no'

# 		fusermount -u -z -q "$PATH_HOST_BACKUPED_FOLDER" &2> /dev/null
# 		rmdir "$PATH_HOST_BACKUPED_FOLDER"
		sync
		sleep 1



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

	echo -en "$(getCSI_CursorMove Position 2 1)$(getCSI_ScreenMove Insert 6)"

	if checkSectionStatus 'Step_1' "$hostBackuped"; then
		updateScreenCurrentAction 'Make the lists of files...'

		lineIndex=4

		declare -i fileCountTotal=0		fileCountSizeTotal=0
		declare -i fileCountAdded=0		fileCountSizeAdded=0		canalAdded
		declare -i fileCountUpdated1=0	fileCountSizeUpdated1=0		canalUpdate1
		declare -i fileCountUpdated2=0	fileCountSizeUpdated2=0		canalUpdate2
		declare -i fileCountRemoved=0	fileCountSizeRemoved=0		canalRemoved
		declare -i fileCountExcluded=0	fileCountSizeExcluded=0		canalExcluded
		declare -i fileCountUptodate=0	fileCountSizeUptodate=0
		declare -i fileCountSkipped=0	fileCountSizeSkipped=0		canalSkipped  # TODO : still usefull ???

		declare posTotal="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 0) )))"
		declare posExcuded="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 1) )))"
		declare posRemoved="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 2) )))"
		declare posUpdated="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 3) )))"
		declare posAdded="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 4) )))"
		declare posUptodate="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 5) )))"
		declare posSkipped="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 6) )))"

		declare posChecked="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 8) )))"	# TODO : make a to Archive too... (for step 3) ... Change the tag backuped with archived

		posFilename="$(getCSI_CursorMove Position $(( lineIndex + 4)) 1 )"
		(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

		echo -en "$(getCSI_CursorMove Position 3 1)"
		printf "${S_BOWHI}   %-22s${S_BOLRE}   %-22s${S_BORED}   %-22s${S_BOYEL}   %-22s${S_BOLBL}   %-22s${S_BOGRE}   %-22s${S_BOCYA}   %-22s${S_BOBLA}   %-22s${S_BOYEL}   %-22s${S_R_AL}\n" 'Total' 'Excluded' 'Removed' 'Updated' 'Added' 'Up to date' 'Skipped' '#' 'To check'

		echoStat $fileCountTotal $fileCountSizeTotal "$posTotal" "$S_NOWHI"
		echoStat $fileCountAdded $fileCountSizeAdded "$posAdded" "$S_NOLBL"
		echoStat $(( fileCountUpdated1 + fileCountUpdated2 )) $fileCountSizeUpdated1 "$posUpdated" "$S_NOYEL"
		echoStat $fileCountRemoved $fileCountSizeRemoved "$posRemoved" "$S_NORED"
		echoStat $fileCountExcluded $fileCountSizeExcluded "$posExcuded" "$S_NOLRE"
		echoStat $fileCountUptodate $fileCountSizeUptodate "$posUptodate" "$S_NOGRE"
		echoStat $fileCountSkipped $fileCountSizeSkipped "$posSkipped" "$S_NOCYA"

# 		action_context="${S_NOWHI}${hostBackuped}${S_R_AL} - Build the files list -"
# 		action_context_size="${hostBackuped} - Build the files list -"

		openFilesListsSpliter 'canalAdded'    'Added'
		openFilesListsSpliter 'canalUpdate1'  'Updated1' 		# Data update
		openFilesListsSpliter 'canalUpdate2'  'Updated2' 		# Permission update
		openFilesListsSpliter 'canalRemoved'  'Removed'
		openFilesListsSpliter 'canalExcluded' 'Excluded'
		openFilesListsSpliter 'canalSkipped'  'Skipped'	# TODO : Add uptodate for brutal mode !

		fileMaxSize='--max-size=150MB'
		fileMaxSize='--max-size=500KB'
		fileMaxSize='--max-size=50KB'

		(( isNewWeek == 1 || BRUTAL == 1 )) &&	# TODO : and what about a "soft" brutal mode that don't cancel the size limitation ?
			fileMaxSize=''

		declare -i canalMain canalSkippedIn canalRemovedIn canalResolvedIn canalSkippedOut canalRemovedOut canalResolvedOut		# TODO : Verify all unset variables
		declare    mainPipe="$pathWorkingDirectoryRAM/Main.pipe"
		declare    skippedPipe="$pathWorkingDirectoryRAM/Skipped.fake.pipe"
		declare    removedPipe="$pathWorkingDirectoryRAM/Removed.fake.pipe"
		declare    resolvedPipe="$pathWorkingDirectoryRAM/Resolved.fake.pipe"

		rm -f  "$mainPipe"
		mkfifo "$mainPipe"	# TODO : think about scriptPostRemoveFiles for all file in this script...

# 		echo -n '' >| "$skippedPipe"
# 		echo -n '' >| "$removedPipe"
# 		echo -n '' >| "$resolvedPipe"

		exec {canalMain}<>"$mainPipe"
		exec {canalSkippedOut}>"$skippedPipe"
		exec {canalSkippedIn}<"$skippedPipe"
		exec {canalRemovedOut}>"$removedPipe"
		exec {canalRemovedIn}<"$removedPipe"
		exec {canalResolvedOut}>"$resolvedPipe"
		exec {canalResolvedIn}<"$resolvedPipe"

		declare -i skipOutput=0 refreshOutput=0



#==============================================================================#
#==     Build the files list                                                 ==#
#==============================================================================#

		{
			rsync -vvirtpoglDmn --files-from="$pathWorkingDirectory/Include.items" --exclude-from="$pathWorkingDirectory/Exclude.items" $fileMaxSize --delete-during --delete-excluded -M--munge-links --modify-window=5 --info=name2,backup,del,copy --out-format="> %12l %i %n" $hostBackuped:"/" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/"
			echo "$LOOP_END_TAG"
		} >&${canalMain} &

		{	# Resolved IN
			pipeReceivedEnd=0
			pipeExpectedEnd=2

			while IFS= read -u ${canalResolvedIn} file_data || checkLoopFail; do
				[[ -z "$file_data" ]] && continue
				checkLoopEnd "$file_data" || { (( $? == 1 )) && break || continue; }

				echo "$file_data" >&${canalMain}
			done
			echo "$LOOP_END_TAG" >&${canalMain}
		} &

		{	# Skipped IN
			pipeReceivedEnd=0
			pipeExpectedEnd=1

			while IFS= read -u ${canalSkippedIn} filename || checkLoopFail; do
				[[ -z "$filename" ]] && continue
				checkLoopEnd "$filename" || { (( $? == 1 )) && break || continue; }

				file_size="$(stat -c "%12s" "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped/${filename}")"

				echo "> $file_size sf--------- ${filename}" >&${canalResolvedOut}
			done
			echo "$LOOP_END_TAG" >&${canalResolvedOut}
		} &

		{	# Removed IN
			excludedFilesList="$pathWorkingDirectory/Exclude.items"

			pipeReceivedEnd=0
			pipeExpectedEnd=1

			while IFS= read -u ${canalRemovedIn} filename || checkLoopFail; do
				[[ -z "$filename" ]] && continue
				checkLoopEnd "$filename" || { (( $? == 1 )) && break || continue; }

				getIsExcludedV 'status' "/$filename" "$excludedFilesList"
				file_type="$(stat -c "%F" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/${filename}")"
				file_size="$(stat -c "%12s" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/${filename}")"

				case "$file_type" in
					'regular file'|'regular empty file')
						file_type='f' ;;
					'directory')
						file_type='d' ;;
					'symbolic link')
						file_type='L' ;;
					*)
						errcho ':EXIT:' "Type inconnu !! ($file_type)"
						;;
				esac
				echo "> $file_size ${status}${file_type}--------- ${filename}" >&${canalResolvedOut}
			done
			echo ':END:' >&${canalResolvedOut}
		} &

		declare -i currentTime=0 lastTime=0

		lastAction=0
		countProgress=0

		pipeReceivedEnd=0
		pipeExpectedEnd=2

	time {
		while IFS= read -u ${canalMain} file_data || checkLoopFail; do
			[[ -z "$file_data" ]] && continue
			checkLoopEnd "$file_data" || {
				(( $? == 1 )) && break

				echo "$LOOP_END_TAG" >&${canalSkippedOut}
				echo "$LOOP_END_TAG" >&${canalRemovedOut}

				continue
			}

			(( refreshOutput = ++skipOutput % SKIP_INTERVAL == 0 ? 1 : 0 )) || :

			if [[ "${file_data:0:1}" != '>' ]]; then
				if [[ "${#file_data}" -le 17 ]]; then
					continue
				fi

				if [[ "${file_data:(-17)}" != ' is over max-size' ]]; then
					continue
				fi

				# Here we have a skipped file
				echo "${file_data:0:$(( ${#file_data} - 17 ))}" >&${canalSkippedOut}
				continue
			fi

			filename="${file_data:27}"
			fileAction="${file_data:15:1}"

			if [[ "$fileAction" == '*' ]]; then
				echo "$filename" >&${canalRemovedOut}
				continue
			fi

			file_size="${file_data:2:12}"
			file_type="${file_data:16:1}"

			case "$file_type" in
				'f'|'S')
					file_type=$TYPE_FILE	;;
				'd')
					file_type=$TYPE_FOLDER	;;
				'L')
					file_type=$TYPE_SYMLINK	;;
				*)
					echo "$file_data"
					errcho ':EXIT:' "Type inconnu !! ($file_type)"
			esac

			(( file_type != TYPE_FOLDER )) && {
				(( fileCountSizeTotal += file_size, ++fileCountTotal, refreshOutput )) &&
					echoStat $fileCountTotal $fileCountSizeTotal "$posTotal" "$S_NOWHI"
			}

			case $fileAction in
			'.')
				actionFlags="${file_data:17:9}"
				if [[ "$actionFlags" == '         ' ]]; then
					if (( file_type != TYPE_FOLDER )); then
						(( fileCountSizeUptodate += file_size, ++fileCountUptodate, refreshOutput )) &&
							echoStat $fileCountUptodate $fileCountSizeUptodate "$posUptodate" "$S_NOGRE"
					fi

					(( refreshOutput )) &&
						echoFilename "/$filename" $file_size "$A_UP_TO_DATE_G" "$S_NOGRE"
				else
					getUpdateFlagsV 'action__flags' "$actionFlags"

					if (( file_type != TYPE_FOLDER )); then
						(( fileCountSizeUpdated2 += file_size, ++fileCountUpdated2, refreshOutput )) &&
							echoStat $(( fileCountUpdated1 + fileCountUpdated2 )) $fileCountSizeUpdated1 "$posUpdated" "$S_NOYEL"
					fi
					echo "$file_size $filename" >&${canalUpdate2}

					(( refreshOutput )) &&
						echoFilename "/$filename" $file_size "$A_UPDATED_Y" "$S_NOYEL"
				fi
				;;
			's')
				(( fileCountSizeSkipped += file_size, ++fileCountSkipped, refreshOutput )) &&
					echoStat $fileCountSkipped $fileCountSizeSkipped "$posSkipped" "$S_NOCYA"

				echo "$file_size $filename" >&${canalSkipped}

				(( refreshOutput )) &&
					echoFilename "/$filename" $file_size "$A_SKIPPED" "$S_NOCYA"
				;;
			'r')
				if (( file_type != TYPE_FOLDER )); then
					(( fileCountSizeRemoved += file_size, ++fileCountRemoved, refreshOutput )) &&
						echoStat $fileCountRemoved $fileCountSizeRemoved "$posRemoved" "$S_NORED"
					echo "$file_size $filename" >&${canalRemoved}
				fi

				(( refreshOutput )) &&
					echoFilename "/$filename" $file_size "$A_REMOVED_R" "$S_NORED"
				;;
			'e')
				if (( file_type != TYPE_FOLDER )); then
					(( fileCountSizeExcluded += file_size, ++fileCountExcluded, refreshOutput )) &&
						echoStat $fileCountExcluded $fileCountSizeExcluded "$posExcuded" "$S_NOLRE"
					echo "$file_size $filename" >&${canalExcluded}
				fi

				(( refreshOutput )) &&
					echoFilename "/$filename" $file_size "$A_EXCLUDED_R" "$S_NOLRE"
				;;
			*)
				actionFlags="${file_data:17:9}"

				if [[ "$actionFlags" == '+++++++++' ]]; then
					if (( file_type != TYPE_FOLDER )); then
						(( fileCountSizeAdded += file_size, ++fileCountAdded, refreshOutput )) &&
							echoStat $fileCountAdded $fileCountSizeAdded "$posAdded" "$S_NOLBL"
						echo "$file_size $filename" >&${canalAdded}
					fi

					(( refreshOutput )) &&
						echoFilename "/$filename" $file_size "$A_ADDED_B" "$S_NOLBL"
				else
					getUpdateFlagsV 'action__flags' "$actionFlags"

					(( fileCountSizeUpdated1 += file_size, ++fileCountUpdated1, refreshOutput )) &&
						echoStat $(( fileCountUpdated1 + fileCountUpdated2 )) $fileCountSizeUpdated1 "$posUpdated" "$S_NOYEL"
					echo "$file_size $filename" >&${canalUpdate1}

					(( refreshOutput )) &&
						echoFilename "/$filename" $file_size "$A_UPDATED_Y" "$S_NOYEL"
				fi
				;;
			esac

			printf -v currentTime '%(%s)T'
			(( currentTime != lastTime )) && {
				lastTime=$currentTime

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

				echoStat $fileCountTotal $fileCountSizeTotal "$posTotal" "$S_NOWHI"
				echoStat $fileCountAdded $fileCountSizeAdded "$posAdded" "$S_NOLBL"
				echoStat $(( fileCountUpdated1 + fileCountUpdated2 )) $fileCountSizeUpdated1 "$posUpdated" "$S_NOYEL"
				echoStat $fileCountRemoved $fileCountSizeRemoved "$posRemoved" "$S_NORED"
				echoStat $fileCountExcluded $fileCountSizeExcluded "$posExcuded" "$S_NOLRE"
				echoStat $fileCountUptodate $fileCountSizeUptodate "$posUptodate" "$S_NOGRE"
				echoStat $fileCountSkipped $fileCountSizeSkipped "$posSkipped" "$S_NOCYA"
			}
		done
	}

		echoStat $fileCountTotal $fileCountSizeTotal "$posTotal" "$S_NOWHI"
		echoStat $fileCountAdded $fileCountSizeAdded "$posAdded" "$S_NOLBL"
		echoStat $(( fileCountUpdated1 + fileCountUpdated2 )) $fileCountSizeUpdated1 "$posUpdated" "$S_NOYEL"
		echoStat $fileCountRemoved $fileCountSizeRemoved "$posRemoved" "$S_NORED"
		echoStat $fileCountExcluded $fileCountSizeExcluded "$posExcuded" "$S_NOLRE"
		echoStat $fileCountUptodate $fileCountSizeUptodate "$posUptodate" "$S_NOGRE"
		echoStat $fileCountSkipped $fileCountSizeSkipped "$posSkipped" "$S_NOCYA"

		exec {canalMain}>&-
		exec {canalSkippedOut}>&-
		exec {canalSkippedIn}>&-
		exec {canalRemovedOut}>&-
		exec {canalRemovedIn}>&-
		exec {canalResolvedOut}>&-
		exec {canalResolvedIn}>&-

		rm -f "$mainPipe"
		rm -f "$skippedPipe"
		rm -f "$removedPipe"
		rm -f "$resolvedPipe"

# 		lastTime=0
# 		showProgress_Step_1
# 		echo
# 		echo
# 		echo

		closeFilesListsSpliter "Added" $canalAdded
		closeFilesListsSpliter "Updated1" $canalUpdate1		# Data update
		closeFilesListsSpliter "Updated2" $canalUpdate2		# Permission update
		closeFilesListsSpliter "Removed" $canalRemoved
		closeFilesListsSpliter "Excluded" $canalExcluded
		closeFilesListsSpliter "Skipped" $canalSkipped

# 		for canal in {1..9}; do
# 			output_file_name="$(getBackupFileName "Skipped-${index}" "$CAT_FILESLIST" 1)"
# 			rm -f "$output_file_name"
# 		done

		declare -p fileCountTotal fileCountSizeTotal fileCountAdded	fileCountSizeAdded fileCountUpdated1 fileCountSizeUpdated1 fileCountUpdated2 fileCountSizeUpdated2 fileCountRemoved fileCountSizeRemoved fileCountExcluded fileCountSizeExcluded fileCountUptodate fileCountSizeUptodate fileCountSkipped fileCountSizeSkipped >| "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_1.var"

		makeSectionStatusDone 'Step_1' "$hostBackuped"
	else
		. "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_1.var"
	fi



################################################################################
################################################################################
####                                                                        ####
####     STEP 2 : Puts all excluded files into Trash                        ####
####                                                                        ####
################################################################################
################################################################################

	echo -en "$(getCSI_CursorMove Position 7 1)$(getCSI_ScreenMove Insert 4)"

	if checkSectionStatus 'Step_2' "$hostBackuped"; then
		updateScreenCurrentAction 'Remove all excluded files...'

# 		step_2_progress1=''
# 		step_2_progress2=''

		progress_current_item_1_processed=0
		progress_current_size_1_processed=0

		lineIndex=7

		declare posExcuded2="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 1) )))"
		posFilename="$(getCSI_CursorMove Position $(( lineIndex + 4)) 1 )"

		if checkSectionStatus 'Step_2-Current' "$hostBackuped"; then # TODO : do it at the same time that others
			if (( fileCountExcluded > 0 )); then

				updateScreenCurrentAction 'Remove all excluded files :' 'Current'

				progress_total_item_1=$fileCountExcluded
				progress_total_size_1=$fileCountSizeExcluded
				progress_current_item_1_remaining=$progress_total_item_1
				progress_current_size_1_remaining=$progress_total_size_1

				source_folder="$PATH_BACKUP_FOLDER/$hostBackuped/Current"
				excluded_folder="$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$hostBackuped/Current"	# TODO : Current is not deleted while the Rotation !!!

# 				action_tag="$A_EXCLUDED_R"
# 				action_color="${S_NOLRE}"

# 				action_context="${S_NOWHI}${hostBackuped}${S_R_AL} - Trash excluded files -"
# 				action_context_size="${hostBackuped} - Trash excluded files -"

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

# 				max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "
# 				(( align_size = ${#action_context_size} - ${#rotationStatusSize}, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

				cp -t "$pathWorkingDirectoryRAM" "$pathWorkingDirectory/Excluded-"{1..9}".files"

				while IFS= read -u ${canal} file_data; do

					file_size="${file_data:0:12}"
					filename="${file_data:13}"
					getFileTypeV file_type "$source_folder/$filename"

					(( progress_current_size_1_remaining -= file_size, --progress_current_item_1_remaining, progress_current_size_1_processed += file_size, ++progress_current_item_1_processed ))

					[[ "$file_type" == '   ' ]] && continue

					echoFilename "/$filename" $file_size "$A_EXCLUDED_R" "$S_NOLRE"

					getPercentageV 'progress_current_item_p1_remaining' $progress_current_item_1_remaining $progress_total_item_1
					getPercentageV 'progress_current_size_p1_remaining' $progress_current_size_1_remaining $progress_total_size_1
					getPercentageV 'progress_current_item_p1_processed' $progress_current_item_1_processed $progress_total_item_1
					getPercentageV 'progress_current_size_p1_processed' $progress_current_size_1_processed $progress_total_size_1

					echoStatPercent $progress_current_item_1_remaining $progress_current_size_1_remaining "$posExcuded" "$S_NOLRE" "$progress_current_item_p1_remaining" "$progress_current_size_p1_remaining"
					echoStatPercent $progress_current_item_1_processed $progress_current_size_1_processed "$posExcuded2" "$S_NOLRE" "$progress_current_item_p1_processed" "$progress_current_size_p1_processed"

					clonePathDetails "$source_folder" "$excluded_folder" "${filename%/*}"
					mv -f "$source_folder/$filename" "$excluded_folder/$filename"
				done {canal}< <(cat "$pathWorkingDirectoryRAM/Excluded-"{1..9}".files")

				rm -f "$pathWorkingDirectoryRAM/Excluded-"{1..9}".files"
			fi

			makeSectionStatusDone 'Step_2-Current' "$hostBackuped"
		fi

		for checked_folder in ${PERIOD_FOLDERS[@]}; do
			updateScreenCurrentAction 'Remove all excluded files :' "$checked_folder"
# 			getTimerV timer
# 			echo -ne "\n\n$timer Searching $checked_folder...${ES_CURSOR_TO_LINE_END}\r${CO_UP_1}${CO_UP_1}"

			if checkSectionStatus "Step_2-$checked_folder" "$hostBackuped"; then
				source_folder="$PATH_BACKUP_FOLDER/$hostBackuped/$checked_folder"
				excluded_folder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$hostBackuped/$checked_folder"

# 				action_tag="$A_EXCLUDED_R"
# 				action_color="${S_NOLRE}"
#
# 				action_context="${S_NOWHI}${hostBackuped}${S_R_AL} - Trash excluded files -"
# 				action_context_size="${hostBackuped} - Trash excluded files -"

# 				max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "
# 				(( align_size = ${#action_context_size} - ${#rotationStatusSize}, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

				while read excludedItem; do
					[[ -z "$excludedItem" ]] && continue	# TODO : useless now ?

					excludedItem="${excludedItem:1}"

					searched_item="$source_folder/$excludedItem"
					destination_item="$excluded_folder/$excludedItem"
					getFileTypeV 'searched_item_type' "$source_folder/$excludedItem"

# 					echo ":: CHECK $searched_item ($checked_folder) [$searched_item_type]"

					[[ "$searched_item_type" == '   ' ]] && continue

					regex='^E[ l]d$'
					if [[ "$searched_item_type" =~ $regex ]]; then
						clonePathDetails "$source_folder" "$excluded_folder" "$excludedItem"

						while IFS= read -u ${canal} file_data; do
# 							echo ":: $file_data"
							file_size="${file_data:0:12}"
							filename="${file_data:13}"
							file_path="${filename%/*}"

							(( progress_current_size_1_processed += file_size, ++progress_current_item_1_processed ))

							clonePathDetails "$searched_item" "$destination_item" "$file_path"
							mv -f "$searched_item/$filename" "$destination_item/$filename"

							echoStat $progress_current_item_1_processed $progress_current_size_1_processed "$posExcuded2" "$S_NOLRE"
							echoFilename "/$filename" $file_size "$A_EXCLUDED_R" "$S_NOLRE"
						done {canal}< <(find -P "$searched_item" -type f,l,p,s,b,c -printf '%12s %P\n')
					else
# 						echo 'else'
						getFileSizeV 'file_size' "$source_folder/$excludedItem"
						filename="$excludedItem"

						(( progress_current_size_1_processed += file_size, ++progress_current_item_1_processed ))

						clonePathDetails "$source_folder" "$excluded_folder" "${excludedItem/*}"
						mv -f "$source_folder/$excludedItem" "$excluded_folder/$excludedItem"

						echoStat $progress_current_item_1_processed $progress_current_size_1_processed "$posExcuded2" "$S_NOLRE"
						echoFilename "/$filename" $file_size "$A_EXCLUDED_R" "$S_NOLRE"
					fi

				done < "$pathWorkingDirectory/Exclude.items"

				makeSectionStatusDone "Step_2-$checked_folder" "$hostBackuped"
			fi
		done

# 		echo
# 		echo
# 		echo

# 		for canal in {1..9}; do
# 			output_file_name="$(getBackupFileName "Excluded-${index}" "$CAT_FILESLIST" 1)"
# 			rm -f "$output_file_name"
# 		done

		makeSectionStatusDone 'Step_2' "$hostBackuped"
	else
		showTitle "$hostBackuped : Remove all excluded files..." "${A_SKIPPED}"
	fi


################################################################################
################################################################################
####                                                                        ####
####     STEP 3 : Make an archive of modified files or removed files        ####
####                                                                        ####
################################################################################
################################################################################

	if checkSectionStatus 'Step_3' "$hostBackuped"; then
		updateScreenCurrentAction 'Archive modified or removed files...'
		showTitle "$hostBackuped : "



#==============================================================================#
#==     Initialize some used variables                                       ==#
#==============================================================================#

		lineIndex=7

		declare posUpdated2="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 3) )))"
		posFilename="$(getCSI_CursorMove Position $(( lineIndex + 4)) 1 )"

# 		PROGRESS_TOTAL_ITEM=$(( ${fileCountRemoved} + ${fileCountUpdated1} ))
# 		PROGRESS_TOTAL_SIZE=$(( ${fileCountSizeRemoved} + ${fileCountSizeUpdated1} ))
		PROGRESS_TOTAL_ITEM=${fileCountUpdated1}
		PROGRESS_TOTAL_SIZE=${fileCountSizeUpdated1}
		PROGRESS_CURRENT_FILES_ITEM=${fileCountUpdated1}
		PROGRESS_CURRENT_FILES_SIZE=${fileCountSizeUpdated1}

		PROGRESS_CURRENT_ITEM=0	# TODO : not a constant... so no uppercase
		PROGRESS_CURRENT_SIZE=0


# 		if [ $init_stat -eq 1 ]; then
# 			PROGRESS_TOTAL_ITEM]=$(( ${FILE_REMOVED]} + ${FILE_UPDATED1]} ))
# 			PROGRESS_TOTAL_SIZE]=$(( ${FILE_SIZE_REMOVED]} + ${FILE_SIZE_UPDATED1]} ))
# 			PROGRESS_CURRENT_FILES_ITEM]=${FILE_UPDATED1]}
# 			PROGRESS_CURRENT_FILES_SIZE]=${FILE_SIZE_UPDATED1]}
# 			eval "$save_stat_step_3"
# 		fi

		if [[ -f "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_3.var" ]]; then
			. "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"
		else
			declare -p PROGRESS_TOTAL_ITEM PROGRESS_TOTAL_SIZE PROGRESS_CURRENT_FILES_ITEM PROGRESS_CURRENT_FILES_SIZE >| "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"
		fi

		DstExcluded="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$hostBackuped/Day-1"
		DstArchive="$PATH_BACKUP_FOLDER/$hostBackuped/Day-1"
		SrcArchive="$PATH_BACKUP_FOLDER/$hostBackuped/Current"

		if checkSectionStatus 'Step_3-Update' "$hostBackuped"; then
			updateScreenCurrentAction 'Archive modified files...'

			if (( isNewDay == 1 )); then
				Action="$A_BACKUPED_Y"			# TODO change this, it just can append if this is not a new day... (ensure this too !!)
				ActionColor="${S_NOYEL}"
			else
				Action="$A_SKIPPED"
				ActionColor="${S_NOCYA}"
			fi



#==============================================================================#
#==     Just copy modified files with cp                                     ==#
#==============================================================================#
# Using cp to ensure permission are keeped with this local copy...

			if (( fileCountUpdated1 > 0 )); then

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

				cp -t "$pathWorkingDirectoryRAM/" "$pathWorkingDirectory/Updated1-"{1..9}".files"

				while IFS= read -u ${canal} file_data; do

					size="${file_data:0:12}"	# TODO : fileSize ??
					filename="${file_data:13}"

					if [[ ! -f "$SrcArchive/$filename" ]]; then	# BUG ! : this bug with pipe or socket file...
						continue
					fi

					(( PROGRESS_CURRENT_FILES_SIZE -= size, --PROGRESS_CURRENT_FILES_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))

					getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}		# TODO : What excluding ??? Oo
					getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
					getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

					echoFilename "/$filename" $size "$Action" "$ActionColor"

					echoStatPercent $PROGRESS_CURRENT_FILES_ITEM $PROGRESS_CURRENT_FILES_SIZE "$posUpdated" "$S_NOYEL" "$P_ExcludingProgressFilesItem" "$P_ExcludingProgressFilesSize"
					echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posUpdated2" "$S_NOYEL" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"

					if (( isNewDay == 1 )); then
						clonePathDetails "$SrcArchive" "$DstArchive" "${filename%/*}"
						if [[ -f "$DstArchive/$filename" ]]; then
							clonePathDetails "$DstArchive" "$DstExcluded" "${filename%/*}"
							mv -f "$DstArchive/$filename" "$DstExcluded/$filename"
						fi
						cp -fP --preserve=mode,ownership,timestamps,links --remove-destination "$SrcArchive/$filename" "$DstArchive/$filename"
					fi
				done {canal}< <(cat "$pathWorkingDirectoryRAM/Updated1-"{1..9}".files")

				rm -f "$pathWorkingDirectoryRAM/Updated1-"{1..9}".files"

				declare -p PROGRESS_TOTAL_ITEM PROGRESS_TOTAL_SIZE PROGRESS_CURRENT_FILES_ITEM PROGRESS_CURRENT_FILES_SIZE >| "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"
			fi

			makeSectionStatusDone 'Step_3-Update' "$hostBackuped"
		fi



#==============================================================================#
#==     Move the removed files to the archive                                ==#
#==============================================================================#

		if checkSectionStatus 'Step_3-Remove' "$hostBackuped"; then
			updateScreenCurrentAction 'Archive removed files...'

			if (( fileCountRemoved > 0 )); then

				PROGRESS_TOTAL_ITEM=${fileCountRemoved}
				PROGRESS_TOTAL_SIZE=${fileCountSizeRemoved}
				PROGRESS_CURRENT_FILES_ITEM=${fileCountRemoved}
				PROGRESS_CURRENT_FILES_SIZE=${fileCountSizeRemoved}

				PROGRESS_CURRENT_ITEM=0	# TODO : not a constant... so no uppercase
				PROGRESS_CURRENT_SIZE=0

				lineIndex=7

				declare posRemoved2="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 2) )))"
				posFilename="$(getCSI_CursorMove Position $(( lineIndex + 4)) 1 )"

# 				Action="$A_BACKUPED_G"
# 				ActionColor="${S_NOYEL}"

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

				cp -t "$pathWorkingDirectoryRAM" "$pathWorkingDirectory/Removed-"{1..9}".files"

				while IFS= read -u ${canal} file_data; do	# TODO : Make a function with this loop ?? (used in excluded files, backuped files and here...)

					size="${file_data:0:12}"
					filename="${file_data:13}"

					if [[ ! -f "$SrcArchive/$filename" ]]; then
						continue
					fi

					(( PROGRESS_CURRENT_FILES_SIZE -= size, --PROGRESS_CURRENT_FILES_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))

					getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
					getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

					echoFilename "/$filename" $size "$A_BACKUPED_Y" "$S_NORED"

					echoStatPercent $PROGRESS_CURRENT_FILES_ITEM $PROGRESS_CURRENT_FILES_SIZE "$posRemoved" "$S_NORED" "$P_ExcludingProgressFilesItem" "$P_ExcludingProgressFilesSize"
					echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posRemoved2" "$S_NORED" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"

					clonePathDetails "$SrcArchive" "$DstArchive" "${filename%/*}"
					if [[ -f "$DstArchive/$filename" ]]; then
						clonePathDetails "$DstArchive" "$DstExcluded" "${filename%/*}"
						mv -f "$DstArchive/$filename" "$DstExcluded/$filename"
					fi
					mv -f "$SrcArchive/$filename" "$DstArchive/$filename"
				done  {canal}< <(cat "$pathWorkingDirectoryRAM/Removed-"{1..9}".files")

				declare -p PROGRESS_TOTAL_ITEM PROGRESS_TOTAL_SIZE PROGRESS_CURRENT_FILES_ITEM PROGRESS_CURRENT_FILES_SIZE >| "$pathWorkingDirectory/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"

				rm -f "$pathWorkingDirectoryRAM/Removed-"{1..9}".files"
			fi

			makeSectionStatusDone 'Step_3-Remove' "$hostBackuped"
		fi



#==============================================================================#
#==     Check integrity of files copied in the archive                       ==#
#==============================================================================#

		declare -r A_RESENDED="$(getActionTag 'RESENDED' "$S_NOYEL")"

		if checkSectionStatus 'Step_3-Checksum' "$hostBackuped"; then
			updateScreenCurrentAction 'Check new archived files...'

			if (( isNewDay == 1 && fileCountUpdated1 > 0 )); then

				PROGRESS_TOTAL_ITEM=${fileCountUpdated1}
				PROGRESS_TOTAL_SIZE=${fileCountSizeUpdated1}
				PROGRESS_CURRENT_FILES_ITEM=${fileCountUpdated1}
				PROGRESS_CURRENT_FILES_SIZE=${fileCountSizeUpdated1}

				PROGRESS_CURRENT_ITEM=0
				PROGRESS_CURRENT_SIZE=0

				lineIndex=7

				declare posChecked2="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 8) )))"
				posFilename="$(getCSI_CursorMove Position $(( lineIndex + 4)) 1 )"

				(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

				cat "$pathWorkingDirectory/Updated1-"{1..9}".files" > "$pathWorkingDirectoryRAM/ToCheck.files"
				sed -ir 's/^ *[0-9]\+ //' "$pathWorkingDirectoryRAM/ToCheck.files"
				echo -n '' > "$pathWorkingDirectoryRAM/ToReCheck.files"

				for SizeIndex in {1..5}; do

					if ! checkSectionStatus "Step_3-Checksum-$SizeIndex" "$hostBackuped"; then
						continue
					fi

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

					if (( PROGRESS_CURRENT_FILES_ITEM > 0 )); then
# 						getTimerV Time
#
# 						getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
# 						getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
# 						getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
# 						getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}
#
# 						formatSizeV 'Size1' ${PROGRESS_CURRENT_SIZE} 15
# 						formatSizeV 'Size2' ${PROGRESS_CURRENT_FILES_SIZE} 15

# 						echo -ne "$Time ${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Checksum of archive ($SizeLimitText :: 0) : ${S_NOGRE}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${S_NOYEL}${PROGRESS_CURRENT_FILES_ITEM}${S_R_AL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

						for Index in {1..10}; do
# 							freeCache > /dev/null
# 							ssh $hostBackuped 'freeCache > /dev/null'

							PROGRESS_CURRENT_RESENDED=0

							lastAction=0

							while read -u ${canal} Line; do
								if [[ "${Line:0:1}" != '>' ]]; then
									continue
								fi

								filename="${Line:27}"

								if [[ "${filename:(-1)}" == '/' ]]; then
									continue
								fi

								size="${Line:2:12}"

								if [[ "${Line:16:1}" == 'L' ]]; then
									IsFile=0
									TypeColor="${S_IT}"
								else
									IsFile=1
									TypeColor=''
								fi

								ActionUpdateType="${Line:15:1}"

								if [[ "$ActionUpdateType" == '.' ]]; then
# 									if [[ $lastAction -ne 1 ]]; then # 1 = Successed
# 										Action="$A_SUCCESSED"
#
# 										ActionColor="${S_NOGRE}"
#
# 										lastAction=1
# 									fi

									(( PROGRESS_CURRENT_FILES_SIZE -= size, --PROGRESS_CURRENT_FILES_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))

									echoFilename "/$filename" $size "$A_SUCCESSED" "$S_NOGRE"

									getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
									getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
									getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
									getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

									echoStatPercent $PROGRESS_CURRENT_FILES_ITEM $PROGRESS_CURRENT_FILES_SIZE "$posChecked" "$S_NOYEL" "$P_ExcludingProgressFilesItem" "$P_ExcludingProgressFilesSize"
									echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posChecked2" "$S_NOYEL" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"
								else
# 									if [[ $lastAction -ne 2 ]]; then # 2 = Resended
# 										Action="$A_RESENDED"
#
# 										ActionColor="${S_NOYEL}"
#
# 										lastAction=2
# 									fi

									(( ++PROGRESS_CURRENT_RESENDED ))
									echo "$filename" >> "$pathWorkingDirectoryRAM/ToReCheck.files"

									echoFilename "/$filename" $size "$A_RESENDED" "$S_NOYEL"
								fi
							done {canal}< <(rsync -vvitpoglDmc --files-from="$pathWorkingDirectoryRAM/ToCheck.files" --modify-window=5 \
										--preallocate --inplace --no-whole-file --block-size=32768 $SizeLimit \
										--info=name2,backup,del,copy --out-format="> %12l %i %n" "$PATH_BACKUP_FOLDER/$hostBackuped/Current" "$PATH_BACKUP_FOLDER/$hostBackuped/Day-1/")

							if (( $(wc -l < "$pathWorkingDirectoryRAM/ToReCheck.files") == 0 )); then
								break
							fi

							cp -f --remove-destination "$pathWorkingDirectoryRAM/ToReCheck.files" "$pathWorkingDirectoryRAM/ToCheck.files" # TODO : move ???
							echo -n '' >| "$pathWorkingDirectoryRAM/ToReCheck.files"
						done
					fi

					sleep 1
					cat "$pathWorkingDirectory/Updated1-"{1..9}".files" >| "$pathWorkingDirectoryRAM/ToCheck.files"
					sed -ir 's/^ *[0-9]\+ //' "$pathWorkingDirectoryRAM/ToCheck.files"
					echo -n '' >| "$pathWorkingDirectoryRAM/ToReCheck.files"

					makeSectionStatusDone "Step_3-Checksum-$SizeIndex" "$hostBackuped"
				done
			fi
			# TODO : remove ToCheck.files ??

			makeSectionStatusDone 'Step_3-Checksum' "$hostBackuped"
		fi

		makeSectionStatusDone 'Step_3' "$hostBackuped"
	fi

# 	rm -f "${FilesListRAM}_${hostBackuped}_Removed"



################################################################################
################################################################################
####                                                                        ####
####     STEP 4 : Make the backup for real now                              ####
####                                                                        ####
################################################################################
################################################################################

# 	PROGRESS_TOTAL_ITEM=0
# 	PROGRESS_TOTAL_SIZE=1
# 	PROGRESS_CURRENT_ITEM=2
# 	PROGRESS_CURRENT_SIZE=3
# 	PROGRESS_CURRENT_FILESA_ITEM=4
# 	PROGRESS_CURRENT_FILESA_SIZE=5
# 	PROGRESS_CURRENT_FILESU_ITEM=6
# 	PROGRESS_CURRENT_FILESU_SIZE=7
# 	PROGRESS2_TOTAL_ITEM=8
# 	PROGRESS2_TOTAL_SIZE=9
# 	PROGRESS2_CURRENT_ITEM=10
# 	PROGRESS2_CURRENT_SIZE=11
# 	PROGRESS2_CURRENT_FILES_ITEM=12
# 	PROGRESS2_CURRENT_FILES_SIZE=13
# 	PROGRESS2_CURRENT_RESENDED=14


	if checkSectionStatus 'Step_4' "$hostBackuped"; then
		updateScreenCurrentAction 'Make the backup for real now...'



#==============================================================================#
#==     Initialize some used variables                                       ==#
#==============================================================================#

		echo -n '' >| "$pathWorkingDirectoryRAM/ToCheck.files"

		if [ "$BRUTAL" -ne 0 ]; then
			:
# 			cp -f --remove-destination "${IncludeList}_$hostBackuped" "${FilesListRAM}_${hostBackuped}_ToBackup"
# 			PROGRESS_TOTAL_ITEM]=${FILE_TOTAL]}
# 			PROGRESS_TOTAL_SIZE]=${FILE_SIZE_TOTAL]}
# 			PROGRESS_CURRENT_FILESA_ITEM]=${FILE_UPTODATE]}
# 			PROGRESS_CURRENT_FILESA_SIZE]=${FILE_SIZE_UPTODATE]}
# 			PROGRESS_CURRENT_FILESU_ITEM]=$(( FILE_UPDATED1] + FILE_UPDATED2] + FILE_ADDED] ))
# 			PROGRESS_CURRENT_FILESU_SIZE]=$(( FILE_SIZE_UPDATED1] + FILE_SIZE_UPDATED2] + FILE_SIZE_ADDED] ))
		else
			cat "$pathWorkingDirectory/Updated1-"{1..9}".files" "$pathWorkingDirectory/Updated2-"{1..9}".files" "$pathWorkingDirectory/Added-"{1..9}".files" > "$pathWorkingDirectoryRAM/ToBackup.files"
			sed -ir 's/^ *[0-9]\+ //' "$pathWorkingDirectoryRAM/ToBackup.files"
# 			cp -f --remove-destination "${FilesListRAM}_${hostBackuped}_Updated2" "${FilesListRAM}_${hostBackuped}_ToBackup"
# 			cat "${FilesListRAM}_${hostBackuped}_Updated1" >> "${FilesListRAM}_${hostBackuped}_ToBackup"
# 			cat "${FilesListRAM}_${hostBackuped}_Added" >> "${FilesListRAM}_${hostBackuped}_ToBackup"
			PROGRESS_TOTAL_ITEM=$(( fileCountUpdated1 + fileCountUpdated2 + fileCountAdded ))
			PROGRESS_TOTAL_SIZE=$(( fileCountSizeUpdated1 + fileCountSizeUpdated2 + fileCountSizeAdded ))
			PROGRESS_CURRENT_FILESA_ITEM=${fileCountAdded}
			PROGRESS_CURRENT_FILESA_SIZE=${fileCountSizeAdded}
			PROGRESS_CURRENT_FILESU_ITEM=$(( fileCountUpdated1 + fileCountUpdated2 ))
			PROGRESS_CURRENT_FILESU_SIZE=$(( fileCountSizeUpdated1 + fileCountSizeUpdated2 ))
		fi

		PROGRESS_CURRENT_ITEM=0
		PROGRESS_CURRENT_SIZE=0

		if [ "$BRUTAL" -ne 0 ]; then
			r='r'
			Exclude="--exclude-from=\"${ExcludeList}_BravoTower\""
		else
			r=''
			Exclude=''
		fi

# 		rm -f "${FilesListRAM}_${hostBackuped}_Updated1"
# 		rm -f "${FilesListRAM}_${hostBackuped}_Updated2"
# 		rm -f "${FilesListRAM}_${hostBackuped}_Added"

		(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

		lineIndex=7

		declare posAdded2="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 4) )))"
		declare posUpdated2="$(getCSI_CursorMove Position $lineIndex $(( 1 + (25 * 3) )))"
		posFilename="$(getCSI_CursorMove Position $(( lineIndex + 4)) 1 )"



#==============================================================================#
#==     Backup all files in the backup files list                            ==#
#==============================================================================#

		for SizeIndex in {1..5}; do
			if ! checkSectionStatus "Step_4-$SizeIndex" "$hostBackuped"; then
				continue
			fi

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

# 			getTimerV Time
#
# 			getPercentageV P_BackupProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
# 			getPercentageV P_BackupProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
# 			getPercentageV P_BackupProgressFilesAItem  ${PROGRESS_CURRENT_FILESA_ITEM}  ${PROGRESS_TOTAL_ITEM}
# 			getPercentageV P_BackupProgressFilesASize  ${PROGRESS_CURRENT_FILESA_SIZE}  ${PROGRESS_TOTAL_SIZE}
# 			getPercentageV P_BackupProgressFilesUItem  ${PROGRESS_CURRENT_FILESU_ITEM}  ${PROGRESS_TOTAL_ITEM}
# 			getPercentageV P_BackupProgressFilesUSize  ${PROGRESS_CURRENT_FILESU_SIZE}  ${PROGRESS_TOTAL_SIZE}
#
# 			formatSizeV 'size_total' "${PROGRESS_CURRENT_SIZE}" 15
# 			formatSizeV 'size_added' "${PROGRESS_CURRENT_FILESA_SIZE}" 15
# 			formatSizeV 'size_updated' "${PROGRESS_CURRENT_FILESU_SIZE}" 15
#
# 			if [ "$BRUTAL" -ne 0 ]; then
# 				:
# # 				progress="${S_BOWHI}>>>${S_R_AL} ${S_NOYEL}${TB__RED} BRUTAL ${S_R_AL} $rotationStatus ($hostBackuped) Make the backup for real ($SizeLimitText) : ${S_NOWHI}${PROGRESS_CURRENT_ITEM]}${S_R_AL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${S_NOGRE}${PROGRESS_CURRENT_FILESA_ITEM]} ${S_DA}$P_BackupProgressFilesAItem${S_R_AL} ($size_added ${S_NOGRE}${S_DA}$P_BackupProgressFilesASize${S_R_AL}) - ${S_NOYEL}${PROGRESS_CURRENT_FILESU_ITEM]} ${S_DA}$P_BackupProgressFilesUItem${S_R_AL} ($size_updated ${S_NOYEL}${S_DA}$P_BackupProgressFilesUSize${S_R_AL})"
# 			else
# 				progress="${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Make the backup for real ($SizeLimitText) : ${S_NOWHI}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${S_NOLBL}${PROGRESS_CURRENT_FILESA_ITEM} ${S_NOBLU}$P_BackupProgressFilesAItem${S_R_AL} ($size_added ${S_NOBLU}$P_BackupProgressFilesASize${S_R_AL}) - ${S_NOYEL}${PROGRESS_CURRENT_FILESU_ITEM} ${S_DA}$P_BackupProgressFilesUItem${S_R_AL} ($size_updated ${S_NOYEL}${S_DA}$P_BackupProgressFilesUSize${S_R_AL})"
# 			fi
#
# 			echo -ne "$Time $progress\r"

			lastAction=0
			lastTime=0

			if checkSectionStatus "Step_4-$SizeIndex-Rsync" "$hostBackuped"; then

				PROGRESS2_TOTAL_ITEM=0
				PROGRESS2_TOTAL_SIZE=0

				echo -n '' >| "$pathWorkingDirectoryRAM/ToCheck.files"

				while read -u ${canal} Line; do
					if [[ "${Line:0:1}" != '>' ]]; then
						continue
					fi

					filename="${Line:27}"
					size="${Line:2:12}"

					if [[ "${filename:(-1)}" != '/' ]]; then
						if [[ "${Line:16:1}" == 'L' ]]; then
							IsFile=0
							TypeColor="${S_IT}"
						else
							IsFile=1
							TypeColor=''
						fi
						IsDirectory=0
					else
						IsDirectory=1
						IsFile=0
						TypeColor="${S_DA}"
					fi

					ActionUpdateType="${Line:15:1}"
					ActionFlags="${Line:17:9}"

					if [[ "$ActionUpdateType" == '.' ]]; then
						if [[ "$ActionFlags" == '         ' ]]; then
# 							if [[ $lastAction -ne 1 ]]; then # 1 = UpToDate
# 								Action="$A_UP_TO_DATE_G"
# 								Flags='      '
# 								ActionColor="${S_NOGRE}"
#
# 								lastAction=1
# 							fi

							if [[ $IsDirectory -ne 1 ]]; then
								if [[ "$BRUTAL" -ne 0 ]]; then
									(( PROGRESS_CURRENT_FILESA_SIZE -= size, --PROGRESS_CURRENT_FILESA_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
									echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"
								else
									continue
								fi
							else
								continue
							fi
						else
# 							if [[ $lastAction -ne 2 ]]; then # 2 = Update With Flags
# 								Action="$A_UPDATED_Y"
# 								ActionColor="${S_NOYEL}"
#
# 								lastAction=2
# 							fi

							ActionFlags="${ActionFlags//./ }"
							getUpdateFlagsV 'Flags' "$ActionFlags"

							if [[ $IsDirectory -ne 1 ]]; then
								(( PROGRESS_CURRENT_FILESU_SIZE -= size, --PROGRESS_CURRENT_FILESU_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))
								if [[ "$BRUTAL" -ne 0 ]]; then
									(( PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
									echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"
								fi

								getPercentageV P_BackupProgressFilesUItem  ${PROGRESS_CURRENT_FILESU_ITEM}  ${PROGRESS_TOTAL_ITEM}
								getPercentageV P_BackupProgressFilesUSize  ${PROGRESS_CURRENT_FILESU_SIZE}  ${PROGRESS_TOTAL_SIZE}

								echoStatPercent $PROGRESS_CURRENT_FILESU_ITEM $PROGRESS_CURRENT_FILESU_SIZE "$posUpdated" "$S_NOYEL" "$P_BackupProgressFilesUItem" "$P_BackupProgressFilesUSize"
#	 							TODO echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posChecked2" "$S_NOYEL" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"

								echoFilename "/$filename" $size "$A_UPDATED_Y" "$S_NOYEL"
							fi
						fi
					else
						if [[ "$ActionFlags" == '+++++++++' ]]; then
# 							if [[ $lastAction -ne 6 ]]; then # 6 = Added
# 								Action="$A_ADDED_B"
#
# 								Flags='      '
# 								ActionColor="${S_NOLBL}"
#
# 								lastAction=6
# 							fi

							if [[ $IsDirectory -ne 1 ]]; then
								if [[ "$BRUTAL" -ne 0 ]]; then
									(( PROGRESS_CURRENT_FILESU_SIZE -= size, --PROGRESS_CURRENT_FILESU_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
								else
									(( PROGRESS_CURRENT_FILESA_SIZE -= size, --PROGRESS_CURRENT_FILESA_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
								fi
								echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"

								getPercentageV P_BackupProgressFilesUItem  ${PROGRESS_CURRENT_FILESA_ITEM}  ${PROGRESS_TOTAL_ITEM}
								getPercentageV P_BackupProgressFilesUSize  ${PROGRESS_CURRENT_FILESA_SIZE}  ${PROGRESS_TOTAL_SIZE}

								echoStatPercent $PROGRESS_CURRENT_FILESA_ITEM $PROGRESS_CURRENT_FILESA_SIZE "$posUpdated" "$S_NOYEL" "$P_BackupProgressFilesUItem" "$P_BackupProgressFilesUSize"
#	 							TODO echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posChecked2" "$S_NOYEL" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"

								echoFilename "/$filename" $size "$A_ADDED_B" "$S_NOLBL"
							fi
						else
# 							if [[ $lastAction -ne 3 ]]; then # 3 = Updated without flags
# 								Action="$A_UPDATED_Y"
#
# 								Flags='      '
# 								ActionColor="${S_NOYEL}"
#
# 								lastAction=3
# 							fi

							(( PROGRESS_CURRENT_FILESU_SIZE -= size, --PROGRESS_CURRENT_FILESU_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
							echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"

							getPercentageV P_BackupProgressFilesUItem  ${PROGRESS_CURRENT_FILESU_ITEM}  ${PROGRESS_TOTAL_ITEM}
							getPercentageV P_BackupProgressFilesUSize  ${PROGRESS_CURRENT_FILESU_SIZE}  ${PROGRESS_TOTAL_SIZE}

							echoStatPercent $PROGRESS_CURRENT_FILESU_ITEM $PROGRESS_CURRENT_FILESU_SIZE "$posUpdated" "$S_NOYEL" "$P_BackupProgressFilesUItem" "$P_BackupProgressFilesUSize"
# 							TODO echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posChecked2" "$S_NOYEL" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"

							echoFilename "/$filename" $size "$A_UPDATED_Y" "$S_NOYEL"
						fi
						lastTime=0
					fi
				done {canal}< <(rsync -vvi${r}tpoglDm --files-from="$pathWorkingDirectoryRAM/ToBackup.files" $Exclude --modify-window=5 -M--munge-links \
							--preallocate --inplace --no-whole-file $SizeLimit $compress_details \
							--info=name2,backup,del,copy --out-format="> %12l %i %n" $hostBackuped:"/" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/")

				echo -n '' >| "$pathWorkingDirectoryRAM/ToReCheck.files"

				(( PROGRESS2_CURRENT_ITEM = 0, PROGRESS2_CURRENT_SIZE = 0, PROGRESS2_CURRENT_FILES_ITEM = PROGRESS2_TOTAL_ITEM, PROGRESS2_CURRENT_FILES_SIZE = PROGRESS2_TOTAL_SIZE , 1 ))

# 				if [ -f "$PATH_BackupStatusRAM/progress" ]; then
# 					progress="$(cat "$PATH_BackupStatusRAM/progress")"
# 				else
# 					progress=''
# 				fi

				makeSectionStatusDone "Step_4-${SizeIndex}-Rsync" "$hostBackuped"
			fi



#==============================================================================#
#==     Check integrity of files copied or modified in the backup            ==#
#==============================================================================#

			if (( PROGRESS2_TOTAL_ITEM > 0 )); then

# 				getTimerV Time
#
# 				getPercentageV P_ChecksumProgressItem  ${PROGRESS2_CURRENT_ITEM}  ${PROGRESS2_TOTAL_ITEM}
# 				getPercentageV P_ChecksumProgressSize  ${PROGRESS2_CURRENT_SIZE}  ${PROGRESS2_TOTAL_SIZE}
# 				getPercentageV P_ChecksumProgressFilesItem  ${PROGRESS2_CURRENT_FILES_ITEM}  ${PROGRESS2_TOTAL_ITEM}
# 				getPercentageV P_ChecksumProgressFilesSize  ${PROGRESS2_CURRENT_FILES_SIZE}  ${PROGRESS2_TOTAL_SIZE}
#
# 				formatSizeV 'Size1' ${PROGRESS2_CURRENT_SIZE} 15
# 				formatSizeV 'Size2' ${PROGRESS2_CURRENT_FILES_SIZE} 15

				PROGRESS2_CURRENT_RESENDED=0

# 				echo -ne "$Time $progress -- -- -- Checksum (?) : ${S_NORED}${PROGRESS2_CURRENT_RESENDED}${S_R_AL} ${S_NOGRE}${PROGRESS2_CURRENT_ITEM}${S_R_AL} $P_ChecksumProgressItem ($Size1 $P_ChecksumProgressSize) - ${S_NOYEL}${PROGRESS2_CURRENT_FILES_ITEM}${S_R_AL} $P_ChecksumProgressFilesItem ($Size2 $P_ChecksumProgressFilesSize)\r"

				for Index in {1..10}; do
					freeCache > /dev/null
					ssh $hostBackuped 'freeCache > /dev/null'

					PROGRESS2_CURRENT_RESENDED=0

					Offset=1
					while [[ 1 ]]; do
						if ! checkSectionStatus "Step_4-$SizeIndex-Checksum_$Index-$Offset" "$hostBackuped"; then
							Offset=$(( Offset + OffsetSize ))
							continue
						fi

						tail -qn +$Offset "$pathWorkingDirectoryRAM/ToCheck.files" | head -qn $OffsetSize >| "$pathWorkingDirectoryRAM/ToCheck-Offset.files"
						LineCount="$(wc -l < "$pathWorkingDirectoryRAM/ToCheck-Offset.files")"

						if (( LineCount == 0 )); then
							break
						fi

						lastAction=0

						while read -u ${canal} Line; do
							if [[ "${Line:0:1}" != '>' ]]; then
								continue
							fi

							filename="${Line:27}"

							if [[ "${filename:(-1)}" == '/' ]]; then
								continue
							fi

							size="${Line:2:12}"

							if [[ "${Line:16:1}" == 'L' ]]; then
								IsFile=0
								TypeColor="${S_IT}"
							else
								IsFile=1
								TypeColor=''
							fi

							ActionUpdateType="${Line:15:1}"

							if [[ "$ActionUpdateType" == '.' ]]; then
								if [[ $lastAction -ne 1 ]]; then # 1 = Successed
									Action="$A_SUCCESSED"

									ActionColor="${S_NOGRE}"

									lastAction=1
								fi

								(( PROGRESS2_CURRENT_FILES_SIZE -= size, --PROGRESS2_CURRENT_FILES_ITEM, PROGRESS2_CURRENT_SIZE += size, ++PROGRESS2_CURRENT_ITEM ))

								echoFilename "/$filename" $size "$A_SUCCESSED" "$S_NOGRE"

								getPercentageV P_ExcludingProgressItem  ${PROGRESS2_CURRENT_ITEM}  ${PROGRESS2_TOTAL_ITEM}
								getPercentageV P_ExcludingProgressSize  ${PROGRESS2_CURRENT_SIZE}  ${PROGRESS2_TOTAL_SIZE}
								getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS2_CURRENT_FILES_ITEM}  ${PROGRESS2_TOTAL_ITEM}
								getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS2_CURRENT_FILES_SIZE}  ${PROGRESS2_TOTAL_SIZE}

								echoStatPercent $PROGRESS_CURRENT_FILES_ITEM $PROGRESS_CURRENT_FILES_SIZE "$posChecked" "$S_NOYEL" "$P_ExcludingProgressFilesItem" "$P_ExcludingProgressFilesSize"
								echoStatPercent $PROGRESS_CURRENT_ITEM $PROGRESS_CURRENT_SIZE "$posChecked2" "$S_NOYEL" "$P_ExcludingProgressItem" "$P_ExcludingProgressSize"
							else
								if [[ $lastAction -ne 2 ]]; then # 2 = Resended
									Action="$A_RESENDED"

									ActionColor="${S_NOYEL}"

									lastAction=2
								fi

								(( ++PROGRESS2_CURRENT_RESENDED ))
								echo "$filename" >> "$pathWorkingDirectoryRAM/ToReCheck.files"

								echoFilename "/$filename" $size "$A_RESENDED" "$S_NOYEL"
							fi

							sleep $sleep_duration
						done {canal}< <(rsync -vvitpoglDmc --files-from="$pathWorkingDirectoryRAM/ToCheck-Offset.files" --modify-window=5 \
									--preallocate --inplace --no-whole-file --block-size=32768 $compress_details -M--munge-links \
									--info=name2,backup,del,copy --out-format="> %12l %i %n" $hostBackuped:"/" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/")

						makeSectionStatusDone "Step_4-$SizeIndex-Checksum_$Index-$Offset" "$hostBackuped"
					done

					if (( $(wc -l < "$pathWorkingDirectoryRAM/ToReCheck.files") == 0 )); then
						break
					fi

					cp --remove-destination "$pathWorkingDirectoryRAM/ToReCheck.files" "$pathWorkingDirectoryRAM/ToCheck.files"
					echo -n '' >| "$pathWorkingDirectoryRAM/ToReCheck.files"
				done
				PROGRESS2_CURRENT_RESENDED=0
			fi
			makeSectionStatusDone "Step_4-$SizeIndex" "$hostBackuped"
		done

		makeSectionStatusDone 'Step_4' "$hostBackuped"
	fi

	echo
done

# backupWorkingDirectory

echo -e "\n\n\nscript finished..."

safeExit # need to debug more the next part... But lazy to do it now xD

################################################################################
################################################################################
####                                                                        ####
####     STEP 6 : Removing all empty folders                                ####
####                                                                        ####
################################################################################
################################################################################

Action="$A_Removed"
ActionColor="${S_NOGRE}${S_DA}"
size="${S_NOGRE}${S_DA}$FOLDER_SIZE"

if (( dayOfWeek == 4 )); then
	showTitle "Remove all empty folders..."

	screenSize="$(tput cols)"

	count=0

	find -P "$PATH_BACKUP_FOLDER" -type d -empty -print -delete |
	while read Folder; do
		getTimerV Time

		filename="${Folder:${#PATH_BACKUP_FOLDER}}"

		header_size="$TIME_SIZE : $EMPTY_SIZE [ UP TO DATE ] /"
		(( filenameLength = screenSize - ${#header_size}, ++count ))

		shortenFileNameV 'filenameText' "${filename:1}" "$filenameLength"

		filenameText="${ActionColor}${TypeColor}$filenameText${S_R_AL}"

		echo -e "$Time $size $Action $filenameText${ES_CURSOR_TO_LINE_END}"
		echo -ne "$Time ${S_BOWHI}>>>${S_R_AL} $rotationStatus Remove empty folders : ${S_NOWHI}$count${S_R_AL}\r"
	done
	echo
else
	showTitle "Remove all empty folders..." "$A_SKIPPED"
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
	for dateFolder in ${PERIOD_FOLDERS[@]} Current; do
		for hostFolder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$dateFolder/$hostFolder" ]; then
				countFiles "_Trashed_/Excluded/$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for dateFolder in ${PERIOD_FOLDERS[@]}; do
		for hostFolder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BACKUP_FOLDER/_Trashed_/Rotation/$dateFolder/$hostFolder" ]; then
				countFiles "_Trashed_/Rotation/$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for dateFolder in ${PERIOD_FOLDERS[@]}; do
		for hostFolder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BACKUP_FOLDER/$dateFolder/$hostFolder" ]; then
				countFiles "$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for hostFolder in "${HOSTS_LIST[@]}"; do
		if [ -d "$PATH_BACKUP_FOLDER/Current/$hostFolder" ]; then
			countFiles "Current/$hostFolder" "End"
		fi
	done

	makeStatusDone 'CountFileEnd'
fi

FilesCount=$(find "$PATH_BACKUP_FOLDER/_Trashed_" -type f -printf '.' | wc -c)

if [ "$FilesCount" -gt 0 ]; then
	echo
	echo -e "${S_NOYEL}${S_B_RED}*** LAST CHANCE TO RECOVER ***${S_R_AL}"
	echo -e "${S_NORED}This is your last chance to recover excluded files from the backup,"
	echo -e "or overwrited files during the rotation... There is ${S_NOLRE}$FilesCount${S_NORED} files in the Trash.${S_R_AL}"
fi

# rm -rf $PATH_BackupStatusRAM/*
# rm -rf $PATH_BackupStatus/[!_]*


# -z --compress-level=9 --skip-compress=gz/jpg/mp[34]/7z/bz2/zip/rar
# (7z ace avi bz2 deb gpg gz iso jpeg jpg lz lzma lzo mov mp3 mp4 ogg png rar rpm rzip tbz tgz tlz txz xz z zip)

################################################################################################################################################################
################################################################################################################################################################

function __change_log__
{
	: << 'COMMENT'

	24.07.2019
		Just finished the big transition of the up-down screen output. Not perfect, but working in most cases.

	23.07.2019
		Add the echoStat function to print a count number with a size aligned at the line below.
		Add the echoFilename to print a filename with time, tag, size, etc...
		Fix : Correct some [...] test to [[...]].
		Remove the updateLastAction function that is useless now.
		Remove the showProgress_Step_1 function that is useless now.
		Add the echoStatPercent function.

	22.07.2019
		Fix : the backupLastSince array bug with value starting with 0... Error was "value too great for base"...
		Rewrite the countFiles function.

	21.07.2019
		Merge removeTrashedContent function into the rotateFolder function.
		Remove showProgress_Rotation function that is useless now.

	19.07.2019
		Showing Rotation details in a table.

	08.07.2019
		Rename PATH_WORKING_DIRECTORY constant to PATH_STATIC_WORKING_DIRECTORY to not confuse with the pathWorkingDirectory variable.
		Add PERIOD_FOLDERS constant that contains now all period folders Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}.
		Check unset variables on the whole source code.
		Add an indicator of late backup in the rotation status. (ie a backup is counting for yesterday if after midnight but before 5 am)
		Rebuild the rotateFolder call list with a loop.

	07.07.2019
		Rebuild since few days all parts of the source code to make it executable again. It work now, but it's just a transition before the commit...

	29.06.2019
		Add getHostWorkingDirectory function to replace getBackupFileName function.

	28.06.2019
		Remove initVariablesState_Rotation functions.
		Renormalize some variables names.

	27.06.2019
		Remove formatSizeV function that is now in .script_common.sh.
		Add takeWorkingDirectory, backupWorkingDirectory and clearWorkingDirectory functions to manage
				temporaries files between sessions (ie if the script crash)
		Renormalize some variables names.

	26.06.2019
		Replace the TTY detection with that of .script_common.sh.
		Remove all the first source code part reserved for testing purpose.
		Remove all constants that are now contained in .script_common.sh.
		Remove old actions and colors sub-scripts.
		Remove error_report function and trap command.
		Remove getSelectableWord function that is now in .script_common.sh.
		Remove checkStatus and makeStatusDone functions that is now in .script_common.sh.
		Remove getFileSizeV, getFileTypeV, getTimerV, copyFolder and clonePathDetails functions that is now in .script_common.sh.
		Remove shortenFileNameV function that is now in .script_common.sh.

COMMENT
}
