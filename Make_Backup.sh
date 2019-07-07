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
#														23.03.2019 - 07.07.2019

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
# CO_GO_TOP_LEFT CO_UP_1
#
################################################################################################################################################################

#==============================================================================#
#==     Constants Definition                                                 ==#
#==============================================================================#

declare -r PATH_BACKUP_FOLDER='/root/BackupFolder/TEST'		# The path of the backup folder in the BackupSystem virtual machine...
PATH_HOST_BACKUPED_FOLDER='/root/HostBackuped'				# The path of the backup folder in the BackupSystem virtual machine...

declare -r STATUS_FOLDER="_Backup_Status_"
declare -r TRASH_FOLDER="_Trashed_"
declare -r VARIABLES_FOLDER="Variables_State"

declare -r PATHFILE_LAST_BACKUP_DATE="$PATH_BACKUP_FOLDER/$STATUS_FOLDER/_LastBackupDate"
declare -r PATH_WORKING_DIRECTORY="$PATH_BACKUP_FOLDER/$STATUS_FOLDER/WorkingDirectory"

CAT_STATUS="Status"
CAT_VARIABLES_STATE="VarState"
CAT_STATISTICS="Statistics"
CAT_FILESLIST="FilesList"

# declare -ar HOSTS_LIST=( 'BravoTower' 'Router' )
declare -ar HOSTS_LIST=( 'Router' )

declare -ri BRUTAL=0		# 1 = Force a whole files backup to syncronize all !! (can be very very looooong...)


################################################################################
################################################################################
####                                                                        ####
####     Functions definition                                               ####
####                                                                        ####
################################################################################
################################################################################

function takeWorkingDirectory
{
# 	[[ -d "$PATH_WORKING_DIRECTORY" ]] &&
# 		cp -r "$PATH_WORKING_DIRECTORY/" "$PATH_TMP"

	return 0
}

function backupWorkingDirectory
{
	mkdir -p "$PATH_WORKING_DIRECTORY"
	cp -Lr "$PATH_TMP/" "$PATH_WORKING_DIRECTORY"
}

function clearWorkingDirectory
{
	[[ -d "$PATH_WORKING_DIRECTORY" ]] &&
		rm --preserve-root -fr "$PATH_WORKING_DIRECTORY"

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

function getPercentageV()
{
	local -r return_var_name="${1}"
	local _value="${2}"
	local _divisor="${3}"

	local _t1 _t2 _P1 _P2

	(( _divisor = _divisor ? _divisor : 1, _t1 = _value * 100, _t2 = _t1 % _divisor, _P1 = _t1 / _divisor, _P2 = (_t2 * 10000) / _divisor, 1 ))

	printf -v $return_var_name '%3d.%04d%%' $_P1 $_P2
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
	local _full_relative_folder_name="${1}"

	if [ "$(checkStatus "Count_$_full_relative_folder_name")" == 'Uncompleted' ]; then

		local source_folder="$PATH_BACKUP_FOLDER/$_full_relative_folder_name"
		local _skip_output=0

		local _count_full_file_name="$(getBackupFileName "Count_$_full_relative_folder_name" "$CAT_STATISTICS" 0)"
		local _log_full_file_name="$(getBackupFileName "Count_LOG_$_full_relative_folder_name" "$CAT_STATISTICS")"
		echo -n '' > "$_log_full_file_name"

		local file_data file_size count_files=0 count_size=0

		showProgress_CountFiles

		exec {pipe_id[1]}<>"$MAIN_PIPE"
		exec {pipe_id[2]}>"$_log_full_file_name"

		{
			find -P "$source_folder" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n'
			echo ':END:'
		} >&${pipe_id[1]} &

		while IFS= read -u ${pipe_id[1]} file_data; do
			if [ ':END:' == "$file_data" ]; then
				break
			fi

			echo "$file_data" >&${pipe_id[2]}

			file_size=${file_data:0:12}

			(( count_size += file_size, ++count_files ))

			if [ $(( ++_skip_output % 653 )) -eq 0 ]; then
				showProgress_CountFiles
			fi
		done

		exec {pipe_id[1]}>&-
		exec {pipe_id[2]}>&-

		showProgress_CountFiles
		if [ $count_files -ne 0 ]; then
			echo
		fi

		echo "$count_files $count_size" > "$_count_full_file_name"
		keepBackupFile "Count_log_$_full_relative_folder_name" "$CAT_STATISTICS"

		makeStatusDone "Count_$_full_relative_folder_name"
	fi
}

function showProgress_Rotation()
{
	local timer file_name_text size1 size2 size3 size4

	getTimerV 'timer'
	shortenFileNameV 'file_name_text' "/$filename" $max_file_name_size
	formatSizeV 'size1' $file_size 15
	formatSizeV 'size2' $count_size_trashed
	formatSizeV 'size3' $count_size
	formatSizeV 'size4' $count_size_rotation

	echo -e "$timer $action $size1 ${action_color}$file_name_text${S_R_AL}${ES_CURSOR_TO_LINE_END}"
	echo -e "$timer $action_context : ${S_NORED}${count_files_trashed} $size2 - ${S_NOWHI}${count_files} $size3 / ${S_NOWHI}${count_files_rotation} $size4 ${S_R_AL}${ES_CURSOR_TO_LINE_END}"
	echo -ne "$timer $rotationStatus $backupLastDateText\r${CO_UP_1}"
}

function removeTrashedContent
{
	if checkSectionStatus 'Rotation-Trash' "$hostBackuped"; then
		local -r source="$PATH_BACKUP_FOLDER/$TRASH_FOLDER"

		local -i canal canal_stat

		local -r log_filename="Rotation-Trashed.files.log"

		local max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "

		(( max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

		exec {canal_stat}>"$pathWorkingDirectoryRAM/$log_filename"

		local action="${A_REMOVED_R}"
		local action_color="${S_NORED}"
		local action_context="Cleaning the trashed content"

		local    file_data filename
		local -i file_size count_files=0 count_size=0

		while IFS= read -u ${canal} file_data; do
			echo "$file_data" >&${canal_stat}

			file_size=${file_data:0:12}	# TODO : in read
			filename="$TRASH_FOLDER/${file_data:19}"

			(( count_size_trashed += file_size, ++count_files_trashed ))

			showProgress_Rotation
		done {canal}< <(find -P "$source" -type f,l,p,s,b,c -printf "%12s %y %3d %P\n" -delete)

		exec {canal_stat}>&-

		echo "$count_files_trashed $count_size_trashed" >> "$PATHFILE_ROTATION_STATISTICS"
		mv "$pathWorkingDirectoryRAM/$log_filename" "$pathWorkingDirectory/$log_filename"

		echo -ne "${ES_ENTIRE_LINE}\n${ES_ENTIRE_LINE}\r"

		makeSectionStatusDone 'Rotation-Trash' "$hostBackuped"
	fi
}

function rotateFolder()
{
	local -r source="${1}"
	local -r destination="${2}"

	if checkSectionStatus "Rotation-$source" "$hostBackuped"; then
		local host_folder source_folder destination_folder overwrited_files_folder log_filename
		local -i canal canal_stat conflict

		local max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "

		(( max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

		local action action_color action_context file_data filename path_name check_dest
		local -i file_size count_files count_size


		for host_folder in "${HOSTS_LIST[@]}"; do
			if checkSectionStatus "Rotation-$host_folder-$source" "$hostBackuped"; then
				source_folder="$PATH_BACKUP_FOLDER/$host_folder/${source}"
				[[ "$destination" == "$TRASH_FOLDER" ]] &&
					destination_folder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/Year-5" ||
					destination_folder="$PATH_BACKUP_FOLDER/$host_folder/${destination}"
				overwrited_files_folder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/${destination}"

				log_filename="Rotation-$host_folder-$source.files.log"

				exec {canal_stat}>"$pathWorkingDirectoryRAM/$log_filename"

				action_context="Rotation of ($host_folder) ${S_NOWHI}${source}${S_R_AL} in ${destination}"

				count_files=0
				count_size=0

				while IFS= read -u ${canal} file_data; do
					file_size=${file_data:0:12}
					filename="${file_data:19}"
					path_name="${filename%/*}"
					getFileTypeV 'check_dest' "$destination_folder/$filename"

					if [[ "$check_dest" != '   ' ]]; then
						clonePathDetails "$destination_folder" "$overwrited_files_folder" "$path_name"
						mv -f "$destination_folder/$filename" "$overwrited_files_folder/$filename"

						conflict=1
						action="${A_BACKUPED_G}"
						action_color="${S_BOLGR}"
					else
						conflict=0
						action="${A_MOVED_G}"
						action_color="${S_NOGRE}"
					fi

					echo "$conflict $file_data" >&${canal_stat}

					(( count_size_rotation += file_size, ++count_files_rotation, count_size += file_size, ++count_files ))

					[[ -n "$path_name" ]] &&
						clonePathDetails "$source_folder" "$destination_folder" "$path_name"
					mv -f "$source_folder/$filename" "$destination_folder/$filename"

					filename="$host_folder/$source/$filename"
					showProgress_Rotation
				done {canal}< <(find -P "$source_folder" -type f,l,p,s,b,c -printf '%12s %y %3d %P\n')

				exec {canal_stat}>&-

				echo "$count_files_rotation $count_size_rotation" >> "$PATHFILE_ROTATION_STATISTICS"
				mv "$pathWorkingDirectoryRAM/$log_filename" "$pathWorkingDirectory/$log_filename"

				echo -ne "${ES_ENTIRE_LINE}\n${ES_ENTIRE_LINE}\r"

				makeSectionStatusDone "Rotation-$host_folder-$source" "$hostBackuped"
			fi
		done

		makeSectionStatusDone "Rotation-$source" "$hostBackuped"
	fi
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

function updateLastAction()
{
	local action="${1}"

	if (( lastAction != action )); then
		lastAction=$action
		case $action in
			1)
				action_tag="$A_UP_TO_DATE_G"
				action_color="${S_NOGRE}"
				action__flags='      '
				;;
			2)
				action_tag="$A_UPDATED_Y"
				action_color="${S_NOYEL}"
				;;
			3)
				action_tag="$A_UPDATED_Y"
				action_color="${S_NOYEL}"
				;;
			4)
				action_tag="$A_SKIPPED"
				action_color="${S_NOCYA}"
				action__flags='      '
				;;
			51)
				action_tag="$A_REMOVED_R"
				action_color="${S_NORED}"
				action__flags='      '
				;;
			52)
				action_tag="$A_EXCLUDED_R"
				action_color="${S_NOLRE}"
				action__flags='      '
				;;
			6)
				action_tag="$A_ADDED_B"
				action_color="${S_NOLBL}"
				action__flags='      '
				;;

		esac
	fi
}

function showProgress_Step_1()
{
	local check_timer filename_text

	printf -v check_timer '%(%s)T'
	(( check_timer > lastTime )) && {
		lastTime=$check_timer

		local size_total size_uptodate size_updated size_removed size_excluded size_added align_size file_count_updated size_skipped

		getTimerV 'timer'

		formatSizeV 'size_total' "$fileCountSizeTotal" 15
		formatSizeV 'size_uptodate' "$fileCountSizeUptodate" 15
		formatSizeV 'size_updated' "$fileCountSizeUpdated1" 15
		formatSizeV 'size_removed' "$fileCountSizeRemoved" 15
		formatSizeV 'size_excluded' "$fileCountSizeExcluded" 15
		formatSizeV 'size_added' "$fileCountSizeAdded" 15
		formatSizeV 'size_skipped' "$fileCountSizeSkipped" 15

		max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE ?????? "
		(( file_count_updated = fileCountUpdated1 + fileCountUpdated2, align_size = ${#action_context_size} - ${#rotationStatusSize} - 1, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

		printf -v step_1_progress1 "${S_NOWHI}%15d ${S_GRE}%15d ${S_LBL}%15d ${S_YEL}%15d ${S_RED}%15d ${S_LRE}%15d ${S_CYA}%15d" ${fileCountTotal} ${fileCountUptodate} ${fileCountAdded} ${file_count_updated} ${fileCountRemoved} ${fileCountExcluded} ${fileCountSkipped}

		step_1_progress1="$timer $action_context $step_1_progress1"
		step_1_progress2="$timer $rotationStatus ${PADDING_SPACE:0:align_size} $size_total $size_uptodate $size_added $size_updated $size_removed $size_excluded $size_skipped"
	}

	shortenFileNameV 'filename_text' "/$filename" "$max_file_name_size"

	if (( file_type == TYPE_FOLDER )); then
		file_size="${action_color}${S_DA}$FOLDER_SIZE${S_R_AL}"
		filename_text="${action_color}${S_DA}$filename_text"
	elif (( file_type == TYPE_SYMLINK )); then
		file_size="${action_color}${S_IT}$SYMLINK_SIZE${S_R_AL}"
		filename_text="${action_color}${S_IT}$filename_text"
	else
		formatSizeV 'file_size' $file_size 15
		filename_text="${action_color}$filename_text"
	fi

	echo -e "$timer $action_tag $file_size $action__flags $filename_text${S_R_AL}${ES_CURSOR_TO_LINE_END}"
	echo -e "$step_1_progress1${S_R_AL}${ES_CURSOR_TO_LINE_END}"
	echo -ne "$step_1_progress2${S_R_AL}\r${CO_UP_1}"
}

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

takeWorkingDirectory

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare hostBackuped='INITIALIZATION'

################################################################################
##      Initialize bases fonlders                                             ##
################################################################################

mkdir -p "$PATH_BACKUP_FOLDER"
mkdir -p "$PATH_BACKUP_FOLDER/$STATUS_FOLDER"

for hostFolder in "$hostBackuped" "${HOSTS_LIST[@]}" "PIPES"; do # TODO Check pipes ??
	mkdir -p "$PATH_TMP/$hostFolder"
	mkdir -p "$PATH_TMP/$hostFolder/$VARIABLES_FOLDER"
	mkdir -p "$PATH_TMP/MEMORY/$hostFolder"
# 	rm -rf $PATH_RamDisk/$STATUS_FOLDER/$hostFolder/[!_]*
done

for hostFolder in "${HOSTS_LIST[@]}"; do
	for dateFolder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5} Current; do
		mkdir -p "$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$hostFolder/$dateFolder"
		mkdir -p "$PATH_BACKUP_FOLDER/_Trashed_/Rotation/$hostFolder/$dateFolder"
		mkdir -p "$PATH_BACKUP_FOLDER/$hostFolder/$dateFolder"
	done
done

# pipe_id=( )
# MAIN_PIPE="$(getBackupFileName "Main-Stream" "PIPE" 1 "PIPES")"
#
# rm -f "$MAIN_PIPE"
# mkfifo "$MAIN_PIPE"

if checkSectionStatus 'Backup-Started'; then
	rm --preserve-root -f "$PATH_TMP/brutal.mode"

	(( BRUTAL > 0 )) && {
		echo
		echo -e "${A_WARNING_NR} The backup is in ${S_NORED}BRUTAL MODE${S_NO}, this will take a VERY LONG time !!"
		echo -ne "${A_TAG_LENGTH_SIZE} Do you want to continue anyway ? "; getWordUserChoiceV 'selected' 'Yes No'
		case $selected in
			1)
				echo -e "\r${A_OK}"
				echo 'Activated' > "$PATH_TMP/brutal.mode"
				;;
			2)
				echo -e "\r${A_ABORTED_NY}"
				exit 1
				;;
		esac
		sleep 2
	}

	makeSectionStatusDone 'Backup-Started'
else
	echo
	choice='New Continue'
	choice2=''
	echo -e "${A_WARNING_NY} A backup is already ${S_NORED}IN PROGRESS${S_NO}, but has probably crashed..."
	[[ ($BRUTAL == 1 && ! -f "$PATH_TMP/brutal.mode") || -f "$PATH_TMP/brutal.mode" && $BRUTAL == 0 ]] && {
		echo -e "${S_NORED}! you can't choose continue because the BRUTAL MODE was not the same in this backup...${S_NO}"
		choice='New'
		choice2="${S_BA}${S_DA}${S_YEL}Continue${S_NO} "
	}
	echo -ne "${A_TAG_LENGTH_SIZE} Do you want to try to continue, or start a new one ? $choice2"; getWordUserChoiceV 'selected' $choice
	case $selected in
		1)
			echo -e "\r${A_ABORTED_NY}"
			for hostFolder in "$hostBackuped" "${HOSTS_LIST[@]}"; do
				rm -rf "$PATH_BACKUP_FOLDER/$STATUS_FOLDER/$hostFolder/"*
			done
			;;
		2)
			echo -e "\r${A_OK}"
			;;
	esac
	sleep 2
fi

# for hostFolder in "$hostBackuped" "${HOSTS_LIST[@]}"; do
# 	if [ "$(find "$PATH_BACKUP_FOLDER/$STATUS_FOLDER/$hostFolder/" -type f -name "[!_]*" -print)" != '' ]; then
# 		cp -rf --remove-destination $PATH_BACKUP_FOLDER/$STATUS_FOLDER/$hostFolder/[!_]* $PATH_RamDisk/$STATUS_FOLDER/$hostFolder/
# 	fi
# done

clear





################################################################################
##      Make rotation of archived files                                       ##
################################################################################

declare pathWorkingDirectory="$(getHostWorkingDirectory)"
declare pathWorkingDirectoryRAM="$(getHostWorkingDirectory 1)"

if checkSectionStatus 'Rotation-Finished' "$hostBackuped"; then
	updateScreenCurrentAction 'Rotation of the archived files'



#==============================================================================#
#==     Find who need to be rotated                                          ==#
#==============================================================================#

	if checkSectionStatus 'Rotation-Details' "$hostBackuped"; then
		updateScreenCurrentAction 'Rotation of the archived files :' 'Check date'

		declare -i isNewDay=0 isNewWeek=0 isNewMonth=0 isNewYear=0 isYesterday dayOfWeek

		declare     backupLastDateText=''
		declare -ai backupLastDate backupCurrentDate

		if [ -f "$PATHFILE_LAST_BACKUP_DATE" ]; then
			read -a backupLastDate < "$PATHFILE_LAST_BACKUP_DATE"

# 			(( LastBackupSince = SCRIPT_START_TIME - backupLastDate[4], Days = LastBackupSince / 86400, Hours = (LastBackupSince % 86400) / 3600, Minutes = ((LastBackupSince % 86400) % 3600) / 60, 1 ))
			declare -a backupLastSince=( $(TZ=UTC printf '%(%-j %H %M %S)T' $((SCRIPT_START_TIME - backupLastDate[0]))) )

			backupLastDateText="The last backup was at $(cat "$PATHFILE_LAST_BACKUP_DATE.txt"), ${S_BOWHI}${backupLastSince[0]}${S_NOWHI}D ${S_BOWHI}${backupLastSince[1]}${S_NOWHI}H${S_BOWHI}${backupLastSince[2]}${S_NOWHI}:${S_BOWHI}${backupLastSince[3]}${S_NOWHI}${S_R_AL} ago"

			unset 'backupLastSince'
		else
			backupLastDate=( 0 0 0 0 0 )
			backupLastDateText="This backup is the first one !"
		fi

		(( isYesterday = $(date '+%-H') <= 5 ? 1 : 0, isYesterday )) &&
			declare yesterday='-d yesterday' ||
			declare yesterday=''

		backupCurrentDate=( $(date '+%s') $(date $yesterday '+%-j +%-V %-d %-m %-Y') )
		dayOfWeek="$(date $yesterday '+%w')"

		unset 'yesterday'

		((	isNewYear  = backupCurrentDate[5] > backupLastDate[5] ? 1 : 0,
			isNewMonth = backupCurrentDate[4] > backupLastDate[4] ? 1 : 0 | isNewYear,
			isNewDay   = backupCurrentDate[3] > backupLastDate[3] ? 1 : 0 | isNewMonth,

			isNewWeek  = ((backupCurrentDate[2] > backupLastDate[2]) ||
						  ((backupCurrentDate[2] == 1) && (backupLastDate[2] != 1))) ? 1 : 0	)) || :

# 		if [ "${backupCurrentDate[3]}" -gt "${backupLastDate[3]}" ]; then
# 			isNewYear=1
# 			isNewMonth=1
# 			isNewDay=1
# 		else
# 			if [ "${backupCurrentDate[2]}" -gt "${backupLastDate[2]}" ]; then
# 				isNewMonth=1
# 				isNewDay=1
# 			elif [ "${backupCurrentDate[1]}" -gt "${backupLastDate[1]}" ]; then
# 				isNewDay=1
# 			fi
# 		fi
#
# 		if [ "${backupCurrentDate[0]}" -gt "${backupLastDate[0]}" ]; then
# 			isNewWeek=1
# 		elif [ "${backupCurrentDate[0]}" -eq 1 ] && [ "${backupLastDate[0]}" -ne 1 ]; then
# 			isNewWeek=1
# 		fi

# 		{ # FOR DEBUG
			isNewDay=1
# 		}
		declare rotationStatus=''

		(( isNewDay   == 1 )) && rotationStatus="${S_NOGRE}NEW-DAY"
		(( isNewMonth == 1 )) && rotationStatus="${S_NOGRE}NEW-MONTH"
		(( isNewYear  == 1 )) && rotationStatus="${S_NOGRE}NEW-YEAR"
		(( isNewWeek  == 1 )) && rotationStatus+=" ${S_NOYEL}${S_B_RED} NEW-WEEK "
		rotationStatus+="${S_R_AL}"

		declare -i rotationStatusSize=$(getCSI_StringLength "$rotationStatus")

		echo "${backupCurrentDate[*]}"   			>| "$PATHFILE_LAST_BACKUP_DATE"
		echo "$(date '+%A %-d %B %Y @ %H:%M:%S')"	>| "$PATHFILE_LAST_BACKUP_DATE.txt"

		unset 'backupLastDate' 'backupCurrentDate'

		declare -p isNewDay isNewWeek isNewMonth isNewYear isYesterday dayOfWeek backupLastDateText rotationStatus rotationStatusSize > "$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Details.var"

		makeSectionStatusDone 'Rotation-Details' "$hostBackuped"
	else
		. "$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Details.var"
	fi

	echo -e "$(getCSI_CursorMove Position 2 1)$backupLastDateText"



#==============================================================================#
#==     Rotate all files that need it                                        ==#
#==============================================================================#

	declare -i count_size_trashed=0 count_files_trashed=0 count_size_rotation=0 count_files_rotation=0	# TODO : change name
	declare -r PATHFILE_ROTATION_STATISTICS="$pathWorkingDirectory/$VARIABLES_FOLDER/Rotation-Statistics.var"

	if [[ -f "$PATHFILE_ROTATION_STATISTICS" ]]; then
		. "$PATHFILE_ROTATION_STATISTICS"
	else
		echo -n '' > "$PATHFILE_ROTATION_STATISTICS"
	fi

# 	if [ "$(checkStatus 'RotationStatisticsInit')" == 'Uncompleted' ]; then
# 		initVariablesState_Rotation_Statistics
#
# 		makeStatusDone 'RotationStatisticsInit'
# 	else
# 		loadVariablesState_Rotation_Statistics
# 	fi

	removeTrashedContent

	(( isNewYear == 1 )) && {
		rotateFolder 'Year-5' "$TRASH_FOLDER"

		rotateFolder 'Year-4' 'Year-5'
		rotateFolder 'Year-3' 'Year-4'
		rotateFolder 'Year-2' 'Year-3'
	}

	(( isNewMonth == 1 )) && {
		rotateFolder 'Month-12' 'Year-2'
		rotateFolder 'Month-11' 'Month-12'
		rotateFolder 'Month-10' 'Month-11'
		rotateFolder 'Month-9'  'Month-10'
		rotateFolder 'Month-8'  'Month-9'
		rotateFolder 'Month-7'  'Month-8'
		rotateFolder 'Month-6'  'Month-7'
		rotateFolder 'Month-5'  'Month-6'
		rotateFolder 'Month-4'  'Month-5'
		rotateFolder 'Month-3'  'Month-4'
		rotateFolder 'Month-2'  'Month-3'
	}

	(( isNewWeek == 1 )) && {
		rotateFolder 'Week-4' 'Month-2'
		rotateFolder 'Week-3' 'Week-4'
		rotateFolder 'Week-2' 'Week-3'
	}

	(( isNewDay == 1 )) && {
		rotateFolder 'Day-7' 'Week-2'
		rotateFolder 'Day-6' 'Day-7'
		rotateFolder 'Day-5' 'Day-6'
		rotateFolder 'Day-4' 'Day-5'
		rotateFolder 'Day-3' 'Day-4'
		rotateFolder 'Day-2' 'Day-3'
		rotateFolder 'Day-1' 'Day-2'
	}

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

					#/media/foophoenix/DataCenter/.Trash
					#/media/foophoenix/AppKDE/.Trash
			echo '	/home/foophoenix/Data/Router/DataSierra
					/home/foophoenix/Data/Router/Home-FooPhoenix
					/home/foophoenix/Data/Router/Root
					/home/foophoenix/Data/BackupSystem/BackupFolder
					/home/foophoenix/Data/BackupSystem/Root
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

					#/media/foophoenix/DataCenter/.Trash
					#/media/foophoenix/AppKDE/.Trash
			echo '	/home/foophoenix/VirtualBox/BackupSystem/Snapshots
					/home/foophoenix/tmp
				' > "$pathWorkingDirectory/Exclude.items"
			;;
		*)
			errcho "Backup of '$hostBackuped' failed and skipped because no include/exclude configuration is made..."
			continue
			;;
	esac

	sed -i 's/^[[:blank:]]*//;/^[[:blank:]]*$/d' "$pathWorkingDirectory/Include.items"
	sed -i 's/^[[:blank:]]*//;/^[[:blank:]]*$/d' "$pathWorkingDirectory/Exclude.items"

	case "$hostBackuped" in
		'BravoTower')
			compress_details='-zz --compress-level=6 --skip-compress=rar'
			;;
		*)
			compress_details=''	# --bwlimit=30M
			;;
	esac

	echo
	echo -e "${S_BOWHI}              Start to make the backup of $hostBackuped...${S_R_AL}"

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

	if checkSectionStatus 'Step_1' "$hostBackuped"; then
		showTitle "$hostBackuped : Make the lists of files..."

		action_context="${S_NOWHI}${hostBackuped}${S_R_AL} - Build the files list -"
		action_context_size="${hostBackuped} - Build the files list -"

		declare -i fileCountTotal=0		fileCountSizeTotal=0
		declare -i fileCountAdded=0		fileCountSizeAdded=0		canalAdded
		declare -i fileCountUpdated1=0	fileCountSizeUpdated1=0		canalUpdate1
		declare -i fileCountUpdated2=0	fileCountSizeUpdated2=0		canalUpdate2
		declare -i fileCountRemoved=0	fileCountSizeRemoved=0		canalRemoved
		declare -i fileCountExcluded=0	fileCountSizeExcluded=0		canalExcluded
		declare -i fileCountUptodate=0	fileCountSizeUptodate=0
		declare -i fileCountSkipped=0	fileCountSizeSkipped=0		canalSkipped  # TODO : still usefull ???

		openFilesListsSpliter 'canalAdded'    'Added'
		openFilesListsSpliter 'canalUpdate1'  'Updated1' 		# Data update
		openFilesListsSpliter 'canalUpdate2'  'Updated2' 		# Permission update
		openFilesListsSpliter 'canalRemoved'  'Removed'
		openFilesListsSpliter 'canalExcluded' 'Excluded'
		openFilesListsSpliter 'canalSkipped'  'Skipped'	# TODO : Add uptodate for brutal mode !

		fileMaxSize='--max-size=150MB'
		fileMaxSize='--max-size=500KB'
		fileMaxSize='--max-size=50KB'

		(( isNewWeek == 1 || BRUTAL == 1 )) &&
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

		lastAction=0
		lastTime=0
		countProgress=0

		pipeReceivedEnd=0
		pipeExpectedEnd=2

		while IFS= read -u ${canalMain} file_data || checkLoopFail; do
			[[ -z "$file_data" ]] && continue
			checkLoopEnd "$file_data" || {
				(( $? == 1 )) && break

				echo "$LOOP_END_TAG" >&${canalSkippedOut}
				echo "$LOOP_END_TAG" >&${canalRemovedOut}

				continue
			}

			if [ "${file_data:0:1}" != '>' ]; then
				if [ "${#file_data}" -le 17 ]; then
					continue
				fi

				if [ "${file_data:(-17)}" != ' is over max-size' ]; then
					continue
				fi

				# Here we have a skipped file
				echo "${file_data:0:$(( ${#file_data} - 17 ))}" >&${canalSkippedOut}
				continue
			fi

			filename="${file_data:27}"
			fileAction="${file_data:15:1}"

			if [ "$fileAction" == '*' ]; then
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

			case $fileAction in
			'.')
				actionFlags="${file_data:17:9}"
				if [ "$actionFlags" == '         ' ]; then
					updateLastAction 1

					if (( file_type != TYPE_FOLDER )); then
						(( fileCountSizeUptodate += file_size, ++fileCountUptodate, fileCountSizeTotal += file_size, ++fileCountTotal ))
					fi
				else
					updateLastAction 2

					getUpdateFlagsV 'action__flags' "$actionFlags"

					if (( file_type != TYPE_FOLDER )); then
						(( fileCountSizeUpdated2 += file_size, ++fileCountUpdated2, fileCountSizeTotal += file_size, ++fileCountTotal ))
					fi
					echo "$file_size $filename" >&${canalUpdate2}
				fi		;;
			's')
				updateLastAction 4

				(( fileCountSizeSkipped += file_size, ++fileCountSkipped, fileCountSizeTotal += file_size, ++fileCountTotal ))
				echo "$file_size $filename" >&${canalSkipped}			;;
			'r')
				updateLastAction 51

				if (( file_type != TYPE_FOLDER )); then
					(( fileCountSizeRemoved += file_size, ++fileCountRemoved, fileCountSizeTotal += file_size, ++fileCountTotal ))
					echo "$file_size $filename" >&${canalRemoved}
				fi			;;
			'e')
				updateLastAction 52

				if (( file_type != TYPE_FOLDER )); then
					(( fileCountSizeExcluded += file_size, ++fileCountExcluded, fileCountSizeTotal += file_size, ++fileCountTotal ))
					echo "$file_size $filename" >&${canalExcluded}
				fi			;;
			*)
				actionFlags="${file_data:17:9}"

				if [[ "$actionFlags" == '+++++++++' ]]; then
					updateLastAction 6

					if (( file_type != TYPE_FOLDER )); then
						(( fileCountSizeAdded += file_size, ++fileCountAdded, fileCountSizeTotal += file_size, ++fileCountTotal ))
						echo "$file_size $filename" >&${canalAdded}
					fi
				else
					updateLastAction 3

					getUpdateFlagsV 'action__flags' "$actionFlags"

					(( fileCountSizeUpdated1 += file_size, ++fileCountUpdated1, fileCountSizeTotal += file_size, ++fileCountTotal ))
					echo "$file_size $filename" >&${canalUpdate1}
				fi			;;
			esac

			if (( ++countProgress % 25 == 0 )); then
				showProgress_Step_1
			fi
		done

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

		lastTime=0
		showProgress_Step_1
		echo
		echo
		echo

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

	if checkSectionStatus 'Step_2' "$hostBackuped"; then
		showTitle "$hostBackuped : Remove all excluded files..."

		step_2_progress1=''
		step_2_progress2=''

		if checkSectionStatus 'Step_2-Current' "$hostBackuped"; then # TODO : do it at the same time that others
			if (( fileCountExcluded > 0 )); then

				progress_total_item_1=$fileCountExcluded
				progress_total_size_1=$fileCountSizeExcluded
				progress_current_item_1_processed=0
				progress_current_size_1_processed=0
				progress_current_item_1_remaining=$progress_total_item_1
				progress_current_size_1_remaining=$progress_total_size_1

				source_folder="$PATH_BACKUP_FOLDER/$hostBackuped/Current"
				excluded_folder="$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$hostBackuped/Current"

				action_tag="$A_EXCLUDED_R"
				action_color="${S_NOLRE}"

				action_context="${S_NOWHI}${hostBackuped}${S_R_AL} - Trash excluded files -"
				action_context_size="${hostBackuped} - Trash excluded files -"

				max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "
				(( align_size = ${#action_context_size} - ${#rotationStatusSize}, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

				cp -t "$pathWorkingDirectoryRAM" "$pathWorkingDirectory/Excluded-"{1..9}".files"

				while IFS= read -u ${canal} file_data; do

					file_size="${file_data:0:12}"
					filename="${file_data:13}"
					getFileTypeV 'file_type' "$source_folder/$filename"

					(( progress_current_size_1_remaining -= file_size, --progress_current_item_1_remaining, progress_current_size_1_processed += file_size, ++progress_current_item_1_processed ))

					[[ "$file_type" == '   ' ]] && continue

					getTimerV timer

					shortenFileNameV 'filename_text' "/$filename" "$max_file_name_size"
					filename_text="${action_color}$filename_text"
					formatSizeV 'file_size' $file_size 15

					formatSizeV 'size_1' $progress_current_size_1_remaining 15
					formatSizeV 'size_2' $progress_current_size_1_processed 15

					getPercentageV 'progress_current_item_p1_remaining' $progress_current_item_1_remaining $progress_total_item_1
					getPercentageV 'progress_current_size_p1_remaining' $progress_current_size_1_remaining $progress_total_size_1
					getPercentageV 'progress_current_item_p1_processed' $progress_current_item_1_processed $progress_total_item_1
					getPercentageV 'progress_current_size_p1_processed' $progress_current_size_1_processed $progress_total_size_1

					printf -v step_2_progress1 "${S_NOLRE}%15d %s >>> ${S_LRE}%15d %s" ${progress_current_item_1_remaining} "${progress_current_item_p1_remaining}" ${progress_current_item_1_processed} "${progress_current_item_p1_processed}"

					echo -e "$timer $action_tag $file_size $filename_text${S_R_AL}${ES_CURSOR_TO_LINE_END}"
					echo -e "$timer $action_context $step_2_progress1${S_R_AL}"
					echo -ne "$timer $rotationStatus ${PADDING_SPACE:0:align_size} $progress_current_size_1_remaining $progress_current_size_p1_remaining $progress_current_size_1_processed $progress_current_size_p1_processed${S_R_AL}\r${CO_UP_1}"

					clonePathDetails "$source_folder" "$excluded_folder" "${filename%/*}"
					mv -f "$source_folder/$filename" "$excluded_folder/$filename"
				done {canal}< <(cat "$pathWorkingDirectoryRAM/Excluded-"{1..9}".files")

				printf -v step_2_progress1 "${S_NOLRE}%15d %s >>> ${S_LRE}%15d %s" ${progress_current_item_1_remaining} "${progress_current_item_p1_remaining}" ${progress_current_item_1_processed} "${progress_current_item_p1_processed}"
				step_2_progress2="$progress_current_size_1_remaining $progress_current_size_p1_remaining $progress_current_size_1_processed $progress_current_size_p1_processed$" # TODO $ ???

				echo
				echo
				echo

				rm -f "$pathWorkingDirectoryRAM/Excluded-"{1..9}".files"
			fi

			makeSectionStatusDone 'Step_2-Current' "$hostBackuped"
		fi

		for checked_folder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do # TODO : make a constant with this
			getTimerV timer
# 			echo -ne "\n\n$timer Searching $checked_folder...${ES_CURSOR_TO_LINE_END}\r${CO_UP_1}${CO_UP_1}"

			if checkSectionStatus "Step_2-$checked_folder" "$hostBackuped"; then
				source_folder="$PATH_BACKUP_FOLDER/$hostBackuped/$checked_folder"
				excluded_folder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$hostBackuped/$checked_folder"

				action_tag="$A_EXCLUDED_R"
				action_color="${S_NOLRE}"

				action_context="${S_NOWHI}${hostBackuped}${S_R_AL} - Trash excluded files -"
				action_context_size="${hostBackuped} - Trash excluded files -"

				progress_total_item_2=0
				progress_total_size_2=0

				max_file_name_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} $EMPTY_SIZE "
				(( align_size = ${#action_context_size} - ${#rotationStatusSize}, max_file_name_size = $(tput cols) - ${#max_file_name_size} ))

				while read excludedItem; do
					[[ -z "$excludedItem" ]] && continue

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

							(( progress_total_size_2 += file_size, ++progress_total_item_2 ))

							clonePathDetails "$searched_item" "$destination_item" "$file_path"
							mv -f "$searched_item/$filename" "$destination_item/$filename"

							showProgress_Step_2
						done {canal}< <(find -P "$searched_item" -type f,l,p,s,b,c -printf '%12s %P\n')
					else
						echo 'else'
						getFileSizeV 'file_size' "$source_folder/$excludedItem"
						filename="$excludedItem"

						(( progress_total_size_2 += file_size, ++progress_total_item_2 ))

						clonePathDetails "$source_folder" "$excluded_folder" "${excludedItem/*}"
						mv -f "$source_folder/$excludedItem" "$excluded_folder/$excludedItem"

						showProgress_Step_2
					fi

				done < "$pathWorkingDirectory/Exclude.items"

				makeSectionStatusDone "Step_2-$checked_folder" "$hostBackuped"
			fi
		done

		echo
		echo
		echo

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
		showTitle "$hostBackuped : Archive modified or removed files..."



#==============================================================================#
#==     Initialize some used variables                                       ==#
#==============================================================================#

		PROGRESS_TOTAL_ITEM=$(( ${fileCountRemoved} + ${fileCountUpdated1} ))
		PROGRESS_TOTAL_SIZE=$(( ${fileCountSizeRemoved} + ${fileCountSizeUpdated1} ))
		PROGRESS_CURRENT_FILES_ITEM=${fileCountUpdated1}
		PROGRESS_CURRENT_FILES_SIZE=${fileCountSizeUpdated1}

		PROGRESS_CURRENT_ITEM=0
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

			if (( isNewDay == 1 )); then
				Action="$A_BACKUPED_G"
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

				screenSize="$(tput cols)"

				cp -t "$pathWorkingDirectoryRAM/" "$pathWorkingDirectory/Updated1-"{1..9}".files"

				while IFS= read -u ${canal} file_data; do

					size="${file_data:0:12}"
					filename="${file_data:13}"

					if [[ ! -f "$SrcArchive/$filename" ]]; then
						continue
					fi

					(( PROGRESS_CURRENT_FILES_SIZE -= size, --PROGRESS_CURRENT_FILES_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))

					getTimerV Time

					getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
					getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

					header_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} : $EMPTY_SIZE /"
					(( filenameLength = screenSize - ${#header_size} ))

					shortenFileNameV 'filenameText' "$filename" "$filenameLength"

					filenameText="${ActionColor}$filenameText${S_R_AL}"
					formatSizeV 'size' $size
					formatSizeV 'Size1' ${PROGRESS_CURRENT_SIZE} 15
					formatSizeV 'Size2' ${PROGRESS_CURRENT_FILES_SIZE} 15

					echo -e "$Time $Action : $size $filenameText${ES_CURSOR_TO_LINE_END}"
					echo -ne "$Time ${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Archive modified files : ${S_NOWHI}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${S_NOYEL}${PROGRESS_CURRENT_FILES_ITEM}${S_R_AL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

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
			if (( fileCountRemoved > 0 )); then

				PROGRESS_CURRENT_FILES_ITEM=${fileCountRemoved}
				PROGRESS_CURRENT_FILES_SIZE=${fileCountSizeRemoved}

				Action="$A_BACKUPED_G"
				ActionColor="${S_NOYEL}"

				screenSize="$(tput cols)"

				cp -t "$pathWorkingDirectoryRAM" "$pathWorkingDirectory/Removed-"{1..9}".files"

				while IFS= read -u ${canal} file_data; do

					size="${file_data:0:12}"
					filename="${file_data:13}"

					if [[ ! -f "$SrcArchive/$filename" ]]; then
						continue
					fi

					(( PROGRESS_CURRENT_FILES_SIZE -= size, --PROGRESS_CURRENT_FILES_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))

					getTimerV Time

					getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
					getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
					getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

					header_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} : $EMPTY_SIZE /"
					(( filenameLength = screenSize - ${#header_size} ))

					shortenFileNameV 'filenameText' "$filename" "$filenameLength"

					filenameText="${ActionColor}$filenameText${S_R_AL}"
					formatSizeV 'size' $size
					formatSizeV 'Size1' ${PROGRESS_CURRENT_SIZE} 15
					formatSizeV 'Size2' ${PROGRESS_CURRENT_FILES_SIZE} 15

					echo -e "$Time $Action : $size $filenameText${ES_CURSOR_TO_LINE_END}"
					echo -ne "$Time ${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Archive removed files : ${S_NOWHI}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${S_NORED}${PROGRESS_CURRENT_FILES_ITEM}${S_R_AL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

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
			if (( isNewDay == 1 && fileCountUpdated1 > 0 )); then

				PROGRESS_TOTAL_ITEM=${fileCountUpdated1}
				PROGRESS_TOTAL_SIZE=${fileCountSizeUpdated1}
				PROGRESS_CURRENT_FILES_ITEM=${fileCountUpdated1}
				PROGRESS_CURRENT_FILES_SIZE=${fileCountSizeUpdated1}

				PROGRESS_CURRENT_ITEM=0
				PROGRESS_CURRENT_SIZE=0

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
						getTimerV Time

						getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
						getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
						getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
						getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

						formatSizeV 'Size1' ${PROGRESS_CURRENT_SIZE} 15
						formatSizeV 'Size2' ${PROGRESS_CURRENT_FILES_SIZE} 15

						echo -ne "$Time ${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Checksum of archive ($SizeLimitText :: 0) : ${S_NOGRE}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${S_NOYEL}${PROGRESS_CURRENT_FILES_ITEM}${S_R_AL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"

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
									if [[ $lastAction -ne 1 ]]; then # 1 = Successed
										Action="$A_SUCCESSED"

										ActionColor="${S_NOGRE}"

										lastAction=1
									fi

									(( PROGRESS_CURRENT_FILES_SIZE -= size, --PROGRESS_CURRENT_FILES_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))
								else
									if [[ $lastAction -ne 2 ]]; then # 2 = Resended
										Action="$A_RESENDED"

										ActionColor="${S_NOYEL}"

										lastAction=2
									fi

									(( ++PROGRESS_CURRENT_RESENDED ))
									echo "$filename" >> "$pathWorkingDirectoryRAM/ToReCheck.files"
								fi

								getTimerV Time

								getPercentageV P_ExcludingProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
								getPercentageV P_ExcludingProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
								getPercentageV P_ExcludingProgressFilesItem  ${PROGRESS_CURRENT_FILES_ITEM}  ${PROGRESS_TOTAL_ITEM}
								getPercentageV P_ExcludingProgressFilesSize  ${PROGRESS_CURRENT_FILES_SIZE}  ${PROGRESS_TOTAL_SIZE}

								header_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} : $EMPTY_SIZE /"
								(( filenameLength = screenSize - ${#header_size} ))

								shortenFileNameV 'filenameText' "$filename" "$filenameLength"

								filenameText="${ActionColor}$filenameText${S_R_AL}"
								formatSizeV 'size' $size
								formatSizeV 'Size1' ${PROGRESS_CURRENT_SIZE} 15
								formatSizeV 'Size2' ${PROGRESS_CURRENT_FILES_SIZE} 15

								echo -e "$Time $Action : $size $filenameText${ES_CURSOR_TO_LINE_END}"
								echo -ne "$Time ${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Checksum of archive ($SizeLimitText :: $Index) : ${S_NORED}${PROGRESS_CURRENT_RESENDED}${S_R_AL} ${S_NOGRE}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_ExcludingProgressItem ($Size1 $P_ExcludingProgressSize) - ${S_NOYEL}${PROGRESS_CURRENT_FILES_ITEM}${S_R_AL} $P_ExcludingProgressFilesItem ($Size2 $P_ExcludingProgressFilesSize)\r"
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
		showTitle "$hostBackuped : Make the backup for real now..."



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

		screenSize="$(tput cols)"



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

			getTimerV Time

			getPercentageV P_BackupProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
			getPercentageV P_BackupProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
			getPercentageV P_BackupProgressFilesAItem  ${PROGRESS_CURRENT_FILESA_ITEM}  ${PROGRESS_TOTAL_ITEM}
			getPercentageV P_BackupProgressFilesASize  ${PROGRESS_CURRENT_FILESA_SIZE}  ${PROGRESS_TOTAL_SIZE}
			getPercentageV P_BackupProgressFilesUItem  ${PROGRESS_CURRENT_FILESU_ITEM}  ${PROGRESS_TOTAL_ITEM}
			getPercentageV P_BackupProgressFilesUSize  ${PROGRESS_CURRENT_FILESU_SIZE}  ${PROGRESS_TOTAL_SIZE}

			formatSizeV 'size_total' "${PROGRESS_CURRENT_SIZE}" 15
			formatSizeV 'size_added' "${PROGRESS_CURRENT_FILESA_SIZE}" 15
			formatSizeV 'size_updated' "${PROGRESS_CURRENT_FILESU_SIZE}" 15

			if [ "$BRUTAL" -ne 0 ]; then
				:
# 				progress="${S_BOWHI}>>>${S_R_AL} ${S_NOYEL}${TB__RED} BRUTAL ${S_R_AL} $rotationStatus ($hostBackuped) Make the backup for real ($SizeLimitText) : ${S_NOWHI}${PROGRESS_CURRENT_ITEM]}${S_R_AL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${S_NOGRE}${PROGRESS_CURRENT_FILESA_ITEM]} ${S_DA}$P_BackupProgressFilesAItem${S_R_AL} ($size_added ${S_NOGRE}${S_DA}$P_BackupProgressFilesASize${S_R_AL}) - ${S_NOYEL}${PROGRESS_CURRENT_FILESU_ITEM]} ${S_DA}$P_BackupProgressFilesUItem${S_R_AL} ($size_updated ${S_NOYEL}${S_DA}$P_BackupProgressFilesUSize${S_R_AL})"
			else
				progress="${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Make the backup for real ($SizeLimitText) : ${S_NOWHI}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${S_NOLBL}${PROGRESS_CURRENT_FILESA_ITEM} ${S_NOBLU}$P_BackupProgressFilesAItem${S_R_AL} ($size_added ${S_NOBLU}$P_BackupProgressFilesASize${S_R_AL}) - ${S_NOYEL}${PROGRESS_CURRENT_FILESU_ITEM} ${S_DA}$P_BackupProgressFilesUItem${S_R_AL} ($size_updated ${S_NOYEL}${S_DA}$P_BackupProgressFilesUSize${S_R_AL})"
			fi

			echo -ne "$Time $progress\r"

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
							if [[ $lastAction -ne 1 ]]; then # 1 = UpToDate
								Action="$A_UP_TO_DATE_G"
								Flags='      '
								ActionColor="${S_NOGRE}"

								lastAction=1
							fi

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
							if [[ $lastAction -ne 2 ]]; then # 2 = Update With Flags
								Action="$A_UPDATED_Y"
								ActionColor="${S_NOYEL}"

								lastAction=2
							fi

							ActionFlags="${ActionFlags//./ }"
							getUpdateFlagsV 'Flags' "$ActionFlags"

							if [[ $IsDirectory -ne 1 ]]; then
								(( PROGRESS_CURRENT_FILESU_SIZE -= size, --PROGRESS_CURRENT_FILESU_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM ))
								if [[ "$BRUTAL" -ne 0 ]]; then
									(( PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
									echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"
								fi
							fi
						fi
					else
						if [[ "$ActionFlags" == '+++++++++' ]]; then
							if [[ $lastAction -ne 6 ]]; then # 6 = Added
								Action="$A_ADDED_B"

								Flags='      '
								ActionColor="${S_NOLBL}"

								lastAction=6
							fi

							if [[ $IsDirectory -ne 1 ]]; then
								if [[ "$BRUTAL" -ne 0 ]]; then
									(( PROGRESS_CURRENT_FILESU_SIZE -= size, --PROGRESS_CURRENT_FILESU_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
								else
									(( PROGRESS_CURRENT_FILESA_SIZE -= size, --PROGRESS_CURRENT_FILESA_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
								fi
								echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"
							fi
						else
							if [[ $lastAction -ne 3 ]]; then # 3 = Updated without flags
								Action="$A_UPDATED_Y"

								Flags='      '
								ActionColor="${S_NOYEL}"

								lastAction=3
							fi

							(( PROGRESS_CURRENT_FILESU_SIZE -= size, --PROGRESS_CURRENT_FILESU_ITEM, PROGRESS_CURRENT_SIZE += size, ++PROGRESS_CURRENT_ITEM, PROGRESS2_TOTAL_SIZE += size, ++PROGRESS2_TOTAL_ITEM ))
							echo "$filename" >> "$pathWorkingDirectoryRAM/ToCheck.files"
						fi
						lastTime=0
					fi

					printf -v CheckTime '%(%s)T'
					if (( CheckTime > lastTime )); then
						lastTime=$CheckTime

						getTimerV Time

						getPercentageV P_BackupProgressItem  ${PROGRESS_CURRENT_ITEM}  ${PROGRESS_TOTAL_ITEM}
						getPercentageV P_BackupProgressSize  ${PROGRESS_CURRENT_SIZE}  ${PROGRESS_TOTAL_SIZE}
						getPercentageV P_BackupProgressFilesAItem  ${PROGRESS_CURRENT_FILESA_ITEM}  ${PROGRESS_TOTAL_ITEM}
						getPercentageV P_BackupProgressFilesASize  ${PROGRESS_CURRENT_FILESA_SIZE}  ${PROGRESS_TOTAL_SIZE}
						getPercentageV P_BackupProgressFilesUItem  ${PROGRESS_CURRENT_FILESU_ITEM}  ${PROGRESS_TOTAL_ITEM}
						getPercentageV P_BackupProgressFilesUSize  ${PROGRESS_CURRENT_FILESU_SIZE}  ${PROGRESS_TOTAL_SIZE}

						formatSizeV 'size_total' "${PROGRESS_CURRENT_SIZE}" 15
						formatSizeV 'size_added' "${PROGRESS_CURRENT_FILESA_SIZE}" 15
						formatSizeV 'size_updated' "${PROGRESS_CURRENT_FILESU_SIZE}" 15

						header_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} : $EMPTY_SIZE ?????? /"
						(( filenameLength = screenSize - ${#header_size} ))
						if [[ "$BRUTAL" -ne 0 ]]; then
							:
# 							progress="${S_BOWHI}>>>${S_R_AL} ${S_NOYEL}${TB__RED} BRUTAL ${S_R_AL} $rotationStatus ($hostBackuped) Make the backup for real ($SizeLimitText) : ${S_NOWHI}${PROGRESS_CURRENT_ITEM]}${S_R_AL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${S_NOGRE}${PROGRESS_CURRENT_FILESA_ITEM]} ${S_DA}$P_BackupProgressFilesAItem${S_R_AL} ($size_added ${S_NOGRE}${S_DA}$P_BackupProgressFilesASize${S_R_AL}) - ${S_NOYEL}${PROGRESS_CURRENT_FILESU_ITEM]} ${S_DA}$P_BackupProgressFilesUItem${S_R_AL} ($size_updated ${S_NOYEL}${S_DA}$P_BackupProgressFilesUSize${S_R_AL})"
						else
							progress="${S_BOWHI}>>>${S_R_AL} $rotationStatus ($hostBackuped) Make the backup for real ($SizeLimitText) : ${S_NOWHI}${PROGRESS_CURRENT_ITEM}${S_R_AL} $P_BackupProgressItem ($size_total $P_BackupProgressSize) - ${S_NOLBL}${PROGRESS_CURRENT_FILESA_ITEM} ${S_NOBLU}$P_BackupProgressFilesAItem${S_R_AL} ($size_added ${S_NOBLU}$P_BackupProgressFilesASize${S_R_AL}) - ${S_NOYEL}${PROGRESS_CURRENT_FILESU_ITEM} ${S_DA}$P_BackupProgressFilesUItem${S_R_AL} ($size_updated ${S_NOYEL}${S_DA}$P_BackupProgressFilesUSize${S_R_AL})"
						fi
					fi

					shortenFileNameV 'filenameText' "$filename" "$filenameLength"
					if [[ $IsDirectory -eq 1 ]]; then
						size="$FOLDER_SIZE"
					elif [[ $IsFile -eq 0 ]]; then
						size="$SYMLINK_SIZE"
					else
						formatSizeV 'size' "$size" 15
					fi

					filenameText="${ActionColor}${TypeColor}$filenameText"
					size="${ActionColor}${TypeColor}$size"

					echo -e "$Time $Action : $size $Flags $filenameText${ES_CURSOR_TO_LINE_END}"
					echo -ne "$Time $progress\r"
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

				getTimerV Time

				getPercentageV P_ChecksumProgressItem  ${PROGRESS2_CURRENT_ITEM}  ${PROGRESS2_TOTAL_ITEM}
				getPercentageV P_ChecksumProgressSize  ${PROGRESS2_CURRENT_SIZE}  ${PROGRESS2_TOTAL_SIZE}
				getPercentageV P_ChecksumProgressFilesItem  ${PROGRESS2_CURRENT_FILES_ITEM}  ${PROGRESS2_TOTAL_ITEM}
				getPercentageV P_ChecksumProgressFilesSize  ${PROGRESS2_CURRENT_FILES_SIZE}  ${PROGRESS2_TOTAL_SIZE}

				formatSizeV 'Size1' ${PROGRESS2_CURRENT_SIZE} 15
				formatSizeV 'Size2' ${PROGRESS2_CURRENT_FILES_SIZE} 15

				PROGRESS2_CURRENT_RESENDED=0

				echo -ne "$Time $progress -- -- -- Checksum (?) : ${S_NORED}${PROGRESS2_CURRENT_RESENDED}${S_R_AL} ${S_NOGRE}${PROGRESS2_CURRENT_ITEM}${S_R_AL} $P_ChecksumProgressItem ($Size1 $P_ChecksumProgressSize) - ${S_NOYEL}${PROGRESS2_CURRENT_FILES_ITEM}${S_R_AL} $P_ChecksumProgressFilesItem ($Size2 $P_ChecksumProgressFilesSize)\r"

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
							else
								if [[ $lastAction -ne 2 ]]; then # 2 = Resended
									Action="$A_RESENDED"

									ActionColor="${S_NOYEL}"

									lastAction=2
								fi

								(( ++PROGRESS2_CURRENT_RESENDED ))
								echo "$filename" >> "$pathWorkingDirectoryRAM/ToReCheck.files"
							fi

							getTimerV Time

							getPercentageV P_ChecksumProgressItem  ${PROGRESS2_CURRENT_ITEM}  ${PROGRESS2_TOTAL_ITEM}
							getPercentageV P_ChecksumProgressSize  ${PROGRESS2_CURRENT_SIZE}  ${PROGRESS2_TOTAL_SIZE}
							getPercentageV P_ChecksumProgressFilesItem  ${PROGRESS2_CURRENT_FILES_ITEM}  ${PROGRESS2_TOTAL_ITEM}
							getPercentageV P_ChecksumProgressFilesSize  ${PROGRESS2_CURRENT_FILES_SIZE}  ${PROGRESS2_TOTAL_SIZE}

							header_size="$TIME_SIZE ${A_TAG_LENGTH_SIZE} : $EMPTY_SIZE /"
							(( filenameLength = screenSize - ${#header_size} ))

							shortenFileNameV 'filenameText' "$filename" "$filenameLength"

							filenameText="${ActionColor}$filenameText${S_R_AL}"
							formatSizeV 'size' $size
							formatSizeV 'Size1' ${PROGRESS2_CURRENT_SIZE} 15
							formatSizeV 'Size2' ${PROGRESS2_CURRENT_FILES_SIZE} 15

							echo -e "$Time $Action : $size $filenameText${ES_CURSOR_TO_LINE_END}"
							echo -ne "$Time $progress -- -- -- Checksum ($Index) : ${S_NORED}${PROGRESS2_CURRENT_RESENDED}${S_R_AL} ${S_NOGRE}${PROGRESS2_CURRENT_ITEM}${S_R_AL} $P_ChecksumProgressItem ($Size1 $P_ChecksumProgressSize) - ${S_NOYEL}${PROGRESS2_CURRENT_FILES_ITEM}${S_R_AL} $P_ChecksumProgressFilesItem ($Size2 $P_ChecksumProgressFilesSize)\r"

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

backupWorkingDirectory

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
	for dateFolder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5} Current; do
		for hostFolder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$dateFolder/$hostFolder" ]; then
				countFiles "_Trashed_/Excluded/$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for dateFolder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
		for hostFolder in "${HOSTS_LIST[@]}"; do
			if [ -d "$PATH_BACKUP_FOLDER/_Trashed_/Rotation/$dateFolder/$hostFolder" ]; then
				countFiles "_Trashed_/Rotation/$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for dateFolder in Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5}; do
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
