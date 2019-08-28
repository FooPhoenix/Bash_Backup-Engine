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
#														23.03.2019 - 28.08.2019

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


################################################################################
################################################################################
####                                                                        ####
####     Functions definition                                               ####
####                                                                        ####
################################################################################
################################################################################

function makeSectionStatusDoneX
{
	local -r section_name="${1}"
	local    section_path="${2:-.}"

	local -i canal
	local    filename

	makeSectionStatusDone "$section_name" "$section_path"

	while read filename; do
		cp "$PATH_TMP/$filename" "$PATH_STATIC_WORKING_DIRECTORY/$filename"
	done < <(find "$PATH_TMP/" -type f -name 'section-*.txt' -printf '%P\n')
	showMemoryUsage
}
function updateScreenCurrentAction
{
	local -r action="${1:-}"
	local -r sub_action="${2:-}"

	echo -en "${CO_GO_TOP_LEFT}$(getTimerV) ${rotationStatus:-?} ${S_BOLMA}${hostBackuped:-?}${S_NO} ${S_BOWHI}${action}${S_NO} ${S_NOWHI}${sub_action}${S_NO}${ES_CURSOR_TO_LINE_END}"
	showMemoryUsage f
}

function getPercentageV
{
	local -r return_var_name="${1}"
	local _value="${2}"
	local _divisor="${3}"

	local _t1 _t2 _P1 _P2

	if ((	_divisor = _divisor ? _divisor : 1,
		_t1 = _value * 100,
		_t2 = _t1 % _divisor,
		_P1 = _t1 / _divisor,
		_P2 = (_t2 * 10000) / _divisor,

	_P1 < 0 || _P2 < 0 )); then
		printf -v $return_var_name '%3d.%04d%%' 0 0
	elif (( _P1 > 999 )); then
		printf -v $return_var_name '+%3d.%04d%%' ${_P1:(-2)} $_P2
	else
		printf -v $return_var_name '%3d.%04d%%' $_P1 $_P2
	fi
}

declare -r CO_GO_SIZE="$(getCSI_CursorMove Down 1)$(getCSI_CursorMove Left 15)"

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

	local position="${3:-}"
	local color="${4:-}"

	local total1="${5}"
	local total2="${6}"

	local percent1 percent2

	getPercentageV percent1 $count $total1
	getPercentageV percent2 $size  $total2

	printf -v count '%15d' $count
	formatSizeV size $size 15

	echo -en "${position}${color}${count} ${percent1}${CO_GO_SIZE2}${size} ${percent2}"
}

function echoStatNoPercent
{
	local count=${1}
	local size=${2}

	local position="${3:-}"
	local color="${4:-}"

	printf -v count '%15d' $count
	formatSizeV size $size 15

	echo -en "${position}${color}${count}          ${CO_GO_SIZE2}${size}          "
}

function echoFilename
{
	local filename="${1}"
	local file_size=${2}
	local tag="${3}"
	local color="${4}"

	local timer

	getTimerV timer
	formatSizeV file_size $file_size 12
	shortenFileNameV filename "$filename" ${filenameMaxSize:-80}

	echo -en "${posFilename}${SO_INSERT_1}${timer} ${tag} ${file_size} ${color}${filename}${S_R_AL}"
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

function getIsExcludedV
{
	local -r  return_var_name="${1}"
	local full_filename="${2}"
	local excluded_files_list="${3}"

	local is_excluded='r'

	local full_filename_size=${#full_filename}
	local excluded_path excluded_path_size

	while read excluded_path; do
		[[ -z "${excluded_path:-}" ]] && continue

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

function showRotationTitle
{
	local    host_name title padding="$(printf '%8s' ' ')"
	local -i spaceBefore spaceAfter

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	# Show title here
	getCSI_CursorMove Position $lineIndex 1

	echo -en "$padding"
	for host_name in Totals ${HOSTS_LIST[@]}; do

		host_name=" $host_name "

		((	spaceAfter = ${#host_name} / 2,
			spaceBefore = 22 - spaceAfter,
			spaceAfter = spaceBefore + (${#host_name} % 2) ))

		printf "%s${S_BOWHI}%s${S_NO}%s " "${PADDING_EQUAL:0:spaceBefore}" "$host_name" "${PADDING_EQUAL:0:spaceAfter}"
	done
	echo

	printf -v title "${S_NOLRE}%-15s${S_NORED}%-15s${S_NOYEL}%-15s${S_R_AL}" '    Deleted' '    Trashed' '      Moved'

	echo -en "$padding"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		echo -en "$title"
	done

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	# show total title here
	getCSI_CursorMove Position $(( lineIndex + 5 )) 1

	printf -v title '%s' "$(echo "${PADDING_EQUAL:0:44}" | tr '=' '-')"

	echo -en "$padding"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		echo -en "$title"
	done

	printf "\n${S_BOWHI}%-8s${S_NO}" "Total"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		printf "${S_NOWHI}%15d%15d%15d${S_NO}" 0 0 0
	done

	formatSizeV title 0 15

	echo -en "\n$padding"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		echo -en "${title}${title}${title}"
	done

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	# show count title here
	getCSI_CursorMove Position $(( lineIndex + 9 )) 1

	printf -v title "%-15s${S_NOWHI}%-15s${S_NO}%-15s" '' '      Count' ''

	echo -en "$padding"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		echo -en "$title"
	done

	printf "\n%-8s" "Current"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		printf "${S_NOWHI}%15s%15d%15s${S_NO}" ' ' 0 ' '
	done

	printf -v title '%-15s%-15s%-15s' ' ' "$(formatSizeV '' 0 15)" ' '

	echo -en "\n$padding"
	for host_name in Totals ${HOSTS_LIST[@]}; do
		echo -en "${title}"
	done
}

function countFiles
{
	updateScreenCurrentAction 'Rotation of the archived files :' 'Count current backup size...'

	if checkSectionStatus 'Rotation-Count' $hostBackuped; then

		local -i canal canal_stat host_index=0

		local -i column_index=9 skip_output=0
		local    host_folder

		local    pos_total="$(getCSI_CursorMove Position $lineIndex $(( column_index + 15 )))"
		local -i total_files=0 total_size=0

		local -i security_sleep=0

		(( column_index += 45 ))

		local filenameMaxSize=$(( screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 '' '')") ))	# temporary override this global variable.

		for host_folder in ${HOSTS_LIST[@]}; do
			hostEstimatedTotalFiles[host_index]=0
			hostEstimatedTotalSize[host_index]=0

			if checkSectionStatus "Rotation-$host_folder-Count" $hostBackuped; then
				local pos_value="$(getCSI_CursorMove Position $lineIndex $(( column_index + 15 )))"
				posFilename="$(getCSI_CursorMove Position $(( lineIndex + 6 )) 1)"

				local path_source="$PATH_BACKUP_FOLDER/$host_folder/Current"
				local log_filename="Rotation-$host_folder-Count.files.log"

				exec {canal_stat}>"$pathHWDR/$log_filename"

				local filename file_type
				local -i file_size file_depth
				local -i count_files=0 count_size=0

				while read file_size file_type file_depth filename; do
					echo "$file_size $file_type $file_depth $filename" >&${canal_stat}

					((	count_size += file_size,
						++count_files,
						total_size += file_size,
						++total_files,

					++skip_output % SKIP_INTERVAL == 0 )) && {
						echoStat $count_files $count_size "${pos_value}" "${S_NOWHI}"
						echoStat $total_files $total_size "${pos_total}" "${S_NOWHI}"

						echoFilename "/$host_folder/Current/$filename" $file_size '' ''
						showMemoryUsage
					}

					(( ++security_sleep % 100000 != 0 )) || sleep 1
				done < <(find -P "$path_source" -type f,l,p,s,b,c -printf "%s %y %d %P\n")

				echoStat $count_files $count_size "${pos_value}" "${S_NOWHI}"

				hostEstimatedTotalFiles[host_index]=$count_files
				hostEstimatedTotalSize[host_index]=$count_size

				exec {canal_stat}>&-
				mv "$pathHWDR/$log_filename" "$pathHWDS/$log_filename"

				makeSectionStatusDoneX "Rotation-$host_folder-Count" $hostBackuped
			fi

			(( column_index += 45, ++host_index ))
		done

		echoStat $total_files $total_size "${pos_total}" "${S_NOWHI}"

		makeSectionStatusDoneX 'Rotation-Count' $hostBackuped
	fi
}

function rotateFolders
{
	local     period_from period_to
	local -ai count_operation

	local -i  totalSizeRemoved=0    totalFilesRemoved=0			# TODO : uppercase ??
	local -i  totalSizeOverwrited=0 totalFilesOverwrited=0
	local -i  totalSizeMoved=0      totalFilesMoved=0

	local -ai totalHostSizeRemoved		totalHostFilesRemoved
	local -ai totalHostSizeOverwrited	totalHostFilesOverwrited
	local -ai totalHostSizeMoved		totalHostFilesMoved

	local -ai totalPeriodSizeRemoved	totalPeriodFilesRemoved
	local -ai totalPeriodSizeOverwrited	totalPeriodFilesOverwrited
	local -ai totalPeriodSizeMoved		totalPeriodFilesMoved

	local -i  index=${#HOSTS_LIST[@]}

	while (( --index >= 0 )); do
		totalHostSizeRemoved[index]=0
		totalHostFilesRemoved[index]=0
		totalHostSizeOverwrited[index]=0
		totalHostFilesOverwrited[index]=0
		totalHostSizeMoved[index]=0
		totalHostFilesMoved[index]=0
	done

	index=${#PERIOD_FOLDERS[@]}

	count_operation[index]=0
	while (( lineIndex += 2, --index >= 0 )); do
		count_operation[index]=0

		totalPeriodSizeRemoved[index]=0
		totalPeriodFilesRemoved[index]=0
		totalPeriodSizeOverwrited[index]=0
		totalPeriodFilesOverwrited[index]=0
		totalPeriodSizeMoved[index]=0
		totalPeriodFilesMoved[index]=0

		period_from=${PERIOD_FOLDERS[index]}
		period_to=${PERIOD_FOLDERS[index+1]:-$TRASH_FOLDER}

		rotateFolder $period_from $period_to
		sleep 0.5

		getCSI_CursorMove Position $(( lineIndex + 3 )) 1
		getCSI_ScreenMove Insert 2

		(( index + 1 < ${#PERIOD_FOLDERS[@]} && count_operation[index + 1] == 0 )) && {
			(( lineIndex -= 2 ))
			getCSI_CursorMove Position $lineIndex 1
			getCSI_ScreenMove Remove 2
		}
	done

	count_operation[index]=0

	rotateFolder Current Day-1

	(( count_operation[index + 1] == 0 )) && {
		(( lineIndex -= 2 ))
		getCSI_CursorMove Position $lineIndex 1
		getCSI_ScreenMove Remove 2
	}

	(( count_operation[index] == 0 )) && {
		getCSI_CursorMove Position $lineIndex 1
		getCSI_ScreenMove Remove 2
	}

	(( lineIndex += 6 ))
}

function rotateFolder
{
	local -r source="${1}"
	local -r destination="${2}"

	updateScreenCurrentAction 'Rotation of the archived files :' "Rotation of $source..."

	if checkSectionStatus "Rotation-$source" $hostBackuped; then

		local -i canal canal_stat

		local -i column_index=9 skip_output=0 host_index=0
		local    host_folder

		local pos_total_period_1="$(getCSI_CursorMove Position $lineIndex $column_index)"
		local pos_total_period_2="$(getCSI_CursorMove Position $(( lineIndex - 2 )) $(( column_index + 15 )))"
		local pos_total_period_3="$(getCSI_CursorMove Position $lineIndex $(( column_index + 30 )))"

		local pos_total_supreme_1="$(getCSI_CursorMove Position $(( lineIndex + 4 )) $column_index)"
		local pos_total_supreme_2="$(getCSI_CursorMove Position $(( lineIndex + 4 )) $(( column_index + 15 )))"
		local pos_total_supreme_3="$(getCSI_CursorMove Position $(( lineIndex + 4 )) $(( column_index + 30 )))"

		local -i security_sleep

		(( column_index += 45 ))

		for host_folder in ${HOSTS_LIST[@]}; do
			security_sleep=0

			getCSI_CursorMove Position $lineIndex 1
			echo -en "$source"

			local pos_value1="$(getCSI_CursorMove Position $lineIndex $column_index)"
			local pos_value2="$(getCSI_CursorMove Position $(( lineIndex - 2 )) $(( column_index + 15 )))"
			local pos_value3="$(getCSI_CursorMove Position $lineIndex $(( column_index + 30 )))"

			local pos_total_host_1="$(getCSI_CursorMove Position $(( lineIndex + 4 )) $column_index)"
			local pos_total_host_2="$(getCSI_CursorMove Position $(( lineIndex + 4 )) $(( column_index + 15 )))"
			local pos_total_host_3="$(getCSI_CursorMove Position $(( lineIndex + 4 )) $(( column_index + 30 )))"

			local posFilename="$(getCSI_CursorMove Position $(( lineIndex + 14 )) 1)"

			echoStat 0 0 "${pos_value1}"
			(( lineIndex > 6 )) &&
				echoStat 0 0 "${pos_value2}"
			echoStat 0 0 "${pos_value3}"

			if checkSectionStatus "Rotation-$host_folder-$source" $hostBackuped; then

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				if [[ "$destination" == "$TRASH_FOLDER" ]]; then
					local path_source="$PATH_BACKUP_FOLDER/$host_folder/$source"
					local path_destination="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"

					local path_removed_e="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$host_folder/$source"
					local path_removed_r="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"

					local path_overwrited="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"
				else
					local path_source="$PATH_BACKUP_FOLDER/$host_folder/$source"
					local path_destination="$PATH_BACKUP_FOLDER/$host_folder/$destination"

					local path_removed_e="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$host_folder/$source"
					local path_removed_r="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$source"

					local path_overwrited="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$host_folder/$destination"
				fi

				local log_filename="Rotation-$host_folder-$source.files.log"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				exec {canal_stat}>>"$pathHWDR/$log_filename"

				local -i count_removed_files=0		count_removed_files_size=0
				local -i count_overwrited_files=0	count_overwrited_files_size=0
				local -i count_moved_files=0		count_moved_files_size=0

				local    filename file_type remove_type
				local -i file_size file_depth

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				if checkSectionStatus "Rotation-$host_folder-$source-Trash" $hostBackuped; then
					(( $isNewDay == 1 )) && {
						while read file_size file_type file_depth remove_type filename; do
							echo "$remove_type $file_size $file_type $file_depth $filename" >&${canal_stat}

							((	count_removed_files_size += file_size,
								++count_removed_files,
								totalHostSizeRemoved[host_index] += file_size,
								++totalHostFilesRemoved[host_index],
								totalPeriodSizeRemoved[index] += file_size,
								++totalPeriodFilesRemoved[index],
								totalSizeRemoved += file_size,
								++totalFilesRemoved,
								++security_sleep,

							++skip_output % SKIP_INTERVAL == 0 )) && {
								echoStat $count_removed_files $count_removed_files_size "${pos_value1}" "${S_NOLRE}"
								echoStat ${totalHostFilesRemoved[host_index]} ${totalHostSizeRemoved[host_index]} "${pos_total_host_1}" "${S_NOLRE}"
								echoStat ${totalPeriodFilesRemoved[index]} ${totalPeriodSizeRemoved[index]} "${pos_total_period_1}" "${S_NOLRE}"
								echoStat $totalFilesRemoved $totalSizeRemoved "${pos_total_supreme_1}" "${S_NOLRE}"

								if [[ "$remove_type" == 'R' ]]; then
									filename="/Rotation/$host_folder/$source/$filename"
								else
									filename="/Excluded/$host_folder/$source/$filename"
								fi

								echoFilename "$filename" $file_size "$A_REMOVED_R" "$S_NOLRE"
								showMemoryUsage
							}
						done < <(find -P "$path_removed_r" -type f,l,p,s,b,c -printf "%s %y %d R %P\n" -delete; find -P "$path_removed_e" -type f,l,p,s,b,c -printf "%s %y %d E %P\n" -delete)
						(( security_sleep > 25000 )) && sleep 1
					}

					echoStat $count_removed_files $count_removed_files_size "${pos_value1}" "${S_NOLRE}"
					echoStat ${totalHostFilesRemoved[host_index]} ${totalHostSizeRemoved[host_index]} "${pos_total_host_1}" "${S_NOLRE}"
					echoStat ${totalPeriodFilesRemoved[index]} ${totalPeriodSizeRemoved[index]} "${pos_total_period_1}" "${S_NOLRE}"
					echoStat $totalFilesRemoved $totalSizeRemoved "${pos_total_supreme_1}" "${S_NOLRE}"

					(( count_operation[index] += count_removed_files )) || :

					makeSectionStatusDoneX "Rotation-$host_folder-$source-Trash" $hostBackuped
				fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				if checkSectionStatus "Rotation-$host_folder-$source-Move" $hostBackuped; then
					[[ "$source" != "Current" ]] && {

						[[ "$source" =~ ^(Day|Week|Month|Year)-[0-9]+$ ]]			|| errcho ':EXIT:' 'Function rotateFolder, Oops, something buggy with $source variable...'
						local period="${BASH_REMATCH[1]}"

						if 	[[ "$period" == 'Year'		&& $isNewYear == 1  ]] ||
							[[ "$period" == 'Month'		&& $isNewMonth == 1 ]] ||
							[[ "$period" == 'Week'		&& $isNewWeek == 1  ]] ||
							[[ "$period" == 'Day'		&& $isNewDay == 1   ]]; then

							local -i file_size2

							while read file_size file_type file_depth filename; do
								path_name="${filename%/*}"

								getFileTypeV check_dest "$path_destination/$filename"
								if [[ "$check_dest" != '   ' ]]; then
									getFileSizeV file_size2 "$path_destination/$filename"

									[[ -n "$path_name" ]] &&
										clonePathDetails "$path_destination" "$path_overwrited" "$path_name"
									mv -f "$path_destination/$filename" "$path_overwrited/$filename"


									echo "O $file_size2 $file_type $file_depth $filename" >&${canal_stat}

									((	count_overwrited_files_size += file_size2,
										++count_overwrited_files,
										totalHostSizeOverwrited[host_index] += file_size2,
										++totalHostFilesOverwrited[host_index],
										totalPeriodSizeOverwrited[index] += file_size2,
										++totalPeriodFilesOverwrited[index],
										totalSizeOverwrited += file_size2,
										++totalFilesOverwrited,
										++security_sleep,


									++skip_output % SKIP_INTERVAL == 0 )) && {
										echoStat $count_overwrited_files $count_overwrited_files_size "${pos_value2}" "${S_NORED}"
										echoStat ${totalHostFilesOverwrited[host_index]} ${totalHostSizeOverwrited[host_index]} "${pos_total_host_2}" "${S_NORED}"
										echoStat ${totalPeriodFilesOverwrited[index]} ${totalPeriodSizeOverwrited[index]} "${pos_total_period_2}" "${S_NORED}"
										echoStat $totalFilesOverwrited $totalSizeOverwrited "${pos_total_supreme_2}" "${S_NORED}"
										showMemoryUsage
									}
									echoFilename "/$filename" $file_size2 "$A_BACKUPED_Y" "$S_NORED"
								else
									echoFilename "/$filename" $file_size "$A_MOVED_G" "$S_NOYEL"
								fi

								[[ -n "$path_name" ]] &&
									clonePathDetails "$path_source" "$path_destination" "$path_name"
								mv -f "$path_source/$filename" "$path_destination/$filename"

								echo "M $file_size $file_type $file_depth $filename" >&${canal_stat}

								((	count_moved_files_size += file_size,
									++count_moved_files,
									totalHostSizeMoved[host_index] += file_size,
									++totalHostFilesMoved[host_index],
									totalPeriodSizeMoved[index] += file_size,
									++totalPeriodFilesMoved[index],
									totalSizeMoved += file_size,
									++totalFilesMoved,

								++skip_output % SKIP_INTERVAL == 0 )) && {
									echoStat $count_moved_files $count_moved_files_size "${pos_value3}" "$S_NOYEL"
									echoStat ${totalHostFilesMoved[host_index]} ${totalHostSizeMoved[host_index]} "${pos_total_host_3}" "$S_NOYEL"
									echoStat ${totalPeriodFilesMoved[index]} ${totalPeriodSizeMoved[index]} "${pos_total_period_3}" "$S_NOYEL"
									echoStat $totalFilesMoved $totalSizeMoved "${pos_total_supreme_3}" "$S_NOYEL"
									showMemoryUsage
								}

								(( ++security_sleep % 25000 != 0 )) || sleep 1
							done < <(find -P "$path_source" -type f,l,p,s,b,c -printf '%s %y %d %P\n')

							echoStat $count_overwrited_files $count_overwrited_files_size "${pos_value2}" "${S_NORED}"
							echoStat ${totalHostFilesOverwrited[host_index]} ${totalHostSizeOverwrited[host_index]} "${pos_total_host_2}" "${S_NORED}"
							echoStat ${totalPeriodFilesOverwrited[index]} ${totalPeriodSizeOverwrited[index]} "${pos_total_period_2}" "${S_NORED}"
							echoStat $totalFilesOverwrited $totalSizeOverwrited "${pos_total_supreme_2}" "${S_NORED}"
							echoStat $count_moved_files $count_moved_files_size "${pos_value3}" "${S_NOYEL}"
							echoStat ${totalHostFilesMoved[host_index]} ${totalHostSizeMoved[host_index]} "${pos_total_host_3}" "$S_NOYEL"
							echoStat ${totalPeriodFilesMoved[index]} ${totalPeriodSizeMoved[index]} "${pos_total_period_3}" "$S_NOYEL"
							echoStat $totalFilesMoved $totalSizeMoved "${pos_total_supreme_3}" "$S_NOYEL"

							((	count_operation[index]     += count_moved_files,
								count_operation[index + 1] += count_overwrited_files)) || :
						fi
					}

					makeSectionStatusDoneX "Rotation-$host_folder-$source-Move" $hostBackuped
				fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

				exec {canal_stat}>&-
				mv "$pathHWDR/$log_filename" "$pathHWDS/$log_filename"

				makeSectionStatusDoneX "Rotation-$host_folder-$source" $hostBackuped
			fi

			(( column_index += 45, ++host_index ))
		done

		makeSectionStatusDoneX "Rotation-$source" $hostBackuped
	fi
}

function checkFilesIntegrity
{
	local host_source="${1}"
	local starting_point="$2"
	local destination_point="$3"

	(( $(wc -l < "$pathHWDR/ToCheck.files") == 0 )) && {
		echoStatNoPercent 0 0 "$POS_CHECKED_1" "$S_NOYEL"
		echoStatNoPercent 0 0 "$POS_CHECKED_2" "$S_NOYEL"
		return 0
	}

	mv -f "$pathHWDR/ToCheck.files" "$pathHWDR/ToCheck.files.tmp"
	sort -n -k 1 "$pathHWDR/ToCheck.files.tmp" > "$pathHWDR/ToCheck.files"
	rm -f "$pathHWDR/ToCheck.files.tmp"

	local -i count_files_checked_p=0	count_files_checked_r=$stepA_T_CountFilesChecked
	local -i count_size_checked_p=0		count_size_checked_r=$stepA_T_CountSizeChecked

	echoStatPercent $count_files_checked_r $count_size_checked_r "$POS_CHECKED_1" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked
	echoStatPercent $count_files_checked_p $count_size_checked_p "$POS_CHECKED_2" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked

	local -i canal_to_check canal_to_recheck canal_to_check_now
	local    rsync_config=''

	[[ -n "$host_source" ]] &&
		rsync_config="$compressConfig -M--munge-links"

	# TOTO : add filenameMaxSize ??

	local -i try
	for try in {1..10}; do
		freeCache > /dev/null
		[[ -n "$host_source" ]] &&
			ssh $host_source 'freeCache > /dev/null'

		rm -f "$pathHWDR/ToReCheck.files"

		exec {canal_to_check}<"$pathHWDR/ToCheck.files"
		exec {canal_to_recheck}>"$pathHWDR/ToReCheck.files"

		local -i files_count size_count
		local filename file_size

		while [[ 1 ]]; do
			rm -f "$pathHWDR/ToCheckNow.files"

			exec {canal_to_check_now}>"$pathHWDR/ToCheckNow.files"

			files_count=0
			size_count=0
			while read -u ${canal_to_check} file_size filename; do
				((	size_count += file_size,
					++files_count	))
				echo "$filename" >&${canal_to_check_now}

				(( size_count > 1000000000 || files_count > 200 )) && break
			done

			exec {canal_to_check_now}>&-

			(( files_count == 0 )) && break

			local file_data file_flags sleep_time

			sleep_time="$(printf '%1.4f' $(echo "scale=4; $size_count * 0.000000002" | bc))"
			(( ${sleep_time%.*} <= 3 )) || sleep_time=3

			while read file_data file_flags file_size filename; do
				[[ "${file_data:0:1}" == '>' ]] || continue
				[[ "${file_flags:1:1}" != 'd' ]] || continue

				if [[ "${file_flags:0:1}" == '.' ]]; then
					((	count_size_checked_r -= file_size,  --count_files_checked_r,
						count_size_checked_p += file_size,  ++count_files_checked_p,

						stepA_R_CountSizeTotal -= file_size, --stepA_R_CountFilesTotal,
						stepA_P_CountSizeTotal += file_size, ++stepA_P_CountFilesTotal	))

					echoStatPercent $count_files_checked_r $count_size_checked_r "$POS_CHECKED_1" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked
					echoStatPercent $count_files_checked_p $count_size_checked_p "$POS_CHECKED_2" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked

					echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
					echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

					echoFilename "/$filename" $file_size "$A_SUCCESSED" "$S_NOGRE"
				else
					echo "$file_size $filename" >&${canal_to_recheck}

					echoFilename "/$filename" $file_size "$A_RESENDED" "$S_NOYEL"
				fi

				showMemoryUsage
			done < <(rsync -vvitpoglDmc --files-from="$pathHWDR/ToCheckNow.files" --modify-window=5 \
						--preallocate --inplace --no-whole-file --block-size=32768 $rsync_config \
						--out-format="> %i %l %n" ${host_source:+$host_source:}"${starting_point}" "$destination_point")

			sleep $sleep_time
		done

		exec {canal_to_check}<&-
		exec {canal_to_recheck}>&-

		rm -f "$pathHWDR/ToCheck.files"
		mv -f "$pathHWDR/ToReCheck.files" "$pathHWDR/ToCheck.files"

		(( $(wc -l < "$pathHWDR/ToCheck.files") == 0 )) && break
	done

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	(( count_files_checked_r > 0 )) && {
		while read file_size filename; do
			((	count_size_checked_r -= file_size,  --count_files_checked_r,
				count_size_checked_p += file_size,  ++count_files_checked_p,

				stepA_R_CountSizeTotal -= file_size, --stepA_R_CountFilesTotal,
				stepA_P_CountSizeTotal += file_size, ++stepA_P_CountFilesTotal	))

			echoStatPercent $count_files_checked_r $count_size_checked_r "$POS_CHECKED_1" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked
			echoStatPercent $count_files_checked_p $count_size_checked_p "$POS_CHECKED_2" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked

			echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
			echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

			echoFilename "/$filename" 0 "$A_ABORTED_NR" "$S_NORED"

		done < <(cat "$pathHWDR/ToCheck.files")
	}

	rm -f "$pathHWDR/ToCheck.files"

	echoStatNoPercent 0 0 "$POS_CHECKED_1" "$S_NOYEL"
	echoStatNoPercent 0 0 "$POS_CHECKED_2" "$S_NOYEL"

	stepA_T_CountFilesChecked=0
	stepA_T_CountSizeChecked=0

	showMemoryUsage
}

function showMemoryUsage
{
	if (( lastSecond != SECONDS )) || [[ "${1:-}" == 'f' ]]; then
		lastSecond=$SECONDS

		local -i file_size
		local    files_size_r=0 files_count_r=0
		local    files_size_s=0 files_count_s=0

		while read file_size; do
			((	files_size_r += file_size,
				++files_count_r	))
		done < <(find "$PATH_TMP/MEMORY/" -type f -printf '%s\n')

		while read file_size; do
			((	files_size_s += file_size,
				++files_count_s	))
		done < <(find "$PATH_STATIC_WORKING_DIRECTORY/" -type f -printf '%s\n')

		local void memory="$(free -bw | grep Mem:)"
		local memory_total memory_used memory_buffer memory_cache
		local files_size_percent memory_used_percent memory_buffer_percent memory_cache_percent

		read void memory_total memory_used void void memory_buffer memory_cache void <<<"$memory"

		getPercentageV files_size_percent $files_size_r $memory_total
		getPercentageV memory_used_percent $memory_used $memory_total
		getPercentageV memory_buffer_percent $memory_buffer $memory_total
		getPercentageV memory_cache_percent $memory_cache $memory_total

		formatSizeV files_size_r $files_size_r 9
		formatSizeV files_size_s $files_size_s 9
		formatSizeV memory_used $memory_used 10
		formatSizeV memory_buffer $memory_buffer 11
		formatSizeV memory_cache $memory_cache 11

		echo -en "${POS_MEMORY_USAGE}${S_BOYEL}Files (S/R) : ${S_NOWHI}$files_count_s $files_size_s ${S_BOYEL}/${S_NOWHI} $files_count_r $files_size_r $files_size_percent ${S_BOYEL}Used : $memory_used $memory_used_percent ${S_BOYEL}Buffer : $memory_buffer $memory_buffer_percent ${S_BOYEL}Cache : $memory_cache $memory_cache_percent ${sleepTime:+  (sleep ${sleepTime}s)}${sleep_time:+  (sleep ${sleep_time}s)}                   "
	fi
}

function setBackupedHostConfiguration
{
	local host_backuped="${1:-$hostBackuped}"

	local -i canal_include canal_exclude

	exec {canal_include}>|"$pathHWDR/Include.items"
	exec {canal_exclude}>|"$pathHWDR/Exclude.items"

	{	# ========== INCLUDE PART ===========
		case $host_backuped in
			'BravoTower')
				echo '
					/bin
					/etc
					/usr
					/var
					/root
					/home/foophoenix
# 					/data
# 					/media/foophoenix/AppKDE
# 					/media/foophoenix/DataCenter'
				;;

			'Router')
				echo '
					/bin
					/etc
					/usr
					/var
					/root
					/home/foophoenix
					/data'
				;;

			*)
				errcho "Backup of '$host_backuped' failed and skipped because no include/exclude configuration is made..."
				echo -n ''
				;;
		esac
	} >&${canal_include}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	{	# ========== EXCLUDE PART ===========
		case $host_backuped in
			'BravoTower')
				echo '
					/home/foophoenix/Data/Router/DataSierra
					/home/foophoenix/Data/Router/Home-FooPhoenix
					/home/foophoenix/Data/Router/Root
					/home/foophoenix/Data/BackupSystem/BackupFolder
					/home/foophoenix/Data/BackupSystem/Root
#	 				/media/foophoenix/DataCenter/.Trash
#	 				/media/foophoenix/AppKDE/.Trash'
				;;

			'Router')
				echo '
# 					/home/foophoenix/VirtualBox/BackupSystem/Snapshots
# 	 				/home/foophoenix/tmp
# 					/home/foophoenix/tmp/config-test-1
# 					/home/foophoenix/tmp/config-test-5
#	 				/media/foophoenix/DataCenter/.Trash
#	 				/media/foophoenix/AppKDE/.Trash'
				;;
			*)
				echo -n ''
				;;
		esac
	} >&${canal_exclude}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	exec {canal_include}>&-
	exec {canal_exclude}>&-

	sed -i 's/^[[:blank:]]*//;/^[[:blank:]]*$/d;/^[[:blank:]]*#/d' "$pathHWDR/Include.items"
	sed -i 's/^[[:blank:]]*//;/^[[:blank:]]*$/d;/^[[:blank:]]*#/d' "$pathHWDR/Exclude.items"

	(( $(wc -l < "$pathHWDR/Include.items") != 0 )) ||
		return 1

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	declare -g compressConfig=''	# --bwlimit=30M
	declare -g hostSource="$host_backuped"
	declare -g startingPoint='/'
	declare -g destinationPoint=''

	case $host_backuped in
		'BravoTower')
			compressConfig='-zz --compress-level=6 --skip-compress=rar'
			;;
	esac

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	[[ "$(ssh $hostSource "echo 'ok'")" == 'ok' ]] ||
		return 1
}

#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWM                                                                                                                                                        WMWM
#WMW     Script Initialization                                                                                                                              MWMW
#MWM                                                                                                                                                        WMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM

################################################################################################################################################################
##                                                                                                                                                            ##
##      Constants Definition                                                                                                                                  ##
##                                                                                                                                                            ##
################################################################################################################################################################

declare -r PATH_BACKUP_FOLDER='/root/BackupFolder/TEST'			# The path of the backup folder in the BackupSystem virtual machine...
declare -r PATH_HOST_BACKUPED_FOLDER='/root/HostBackuped'

declare -r STATUS_FOLDER="_Backup_Status_"
declare -r TRASH_FOLDER="_Trashed_"
declare -r VARIABLES_FOLDER="Variables_State"

declare -r PATHFILE_LAST_BACKUP_DATE="$PATH_BACKUP_FOLDER/$STATUS_FOLDER/_LastBackupDate"
declare -r PATH_STATIC_WORKING_DIRECTORY="$PATH_BACKUP_FOLDER/$STATUS_FOLDER/WorkingDirectory"

declare -ar HOSTS_LIST=( 'BravoTower' 'Router' )
# declare -ar HOSTS_LIST=( 'Router' )
declare -ar PERIOD_FOLDERS=( Day-{1..7} Week-{2..4} Month-{2..12} Year-{2..5} )

declare -ri BRUTAL=0		# 1 = Force a whole files backup to syncronize all !! (can be very very looooong...)

declare -r A_RESENDED="$(getActionTag 'RESENDED' "$S_NOYEL")"

declare -ri TYPE_FILE=1
declare -ri TYPE_FOLDER=2
declare -ri TYPE_SYMLINK=3

declare -r INITIALIZATION_NAME='INITIALIZATION'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -ri SKIP_INTERVAL=31

declare -r POS_TOTAL_1="$(getCSI_CursorMove    Position 4 $(( 1 + (25 * 0) )) )"
declare -r POS_TOTAL_2="$(getCSI_CursorMove    Position 7 $(( 1 + (25 * 0) )) )"
declare -r POS_EXCUDED_1="$(getCSI_CursorMove  Position 4 $(( 1 + (25 * 1) )) )"
declare -r POS_EXCUDED_2="$(getCSI_CursorMove  Position 7 $(( 1 + (25 * 1) )) )"
declare -r POS_REMOVED_1="$(getCSI_CursorMove  Position 4 $(( 1 + (25 * 2) )) )"
declare -r POS_REMOVED_2="$(getCSI_CursorMove  Position 7 $(( 1 + (25 * 2) )) )"
declare -r POS_UPDATED_1="$(getCSI_CursorMove  Position 4 $(( 1 + (25 * 3) )) )"
declare -r POS_UPDATED_2="$(getCSI_CursorMove  Position 7 $(( 1 + (25 * 3) )) )"
declare -r POS_ADDED_1="$(getCSI_CursorMove    Position 4 $(( 1 + (25 * 4) )) )"
declare -r POS_ADDED_2="$(getCSI_CursorMove    Position 7 $(( 1 + (25 * 4) )) )"
declare -r POS_UPTODATE_1="$(getCSI_CursorMove Position 4 $(( 1 + (25 * 5) )) )"
declare -r POS_UPTODATE_2="$(getCSI_CursorMove Position 7 $(( 1 + (25 * 5) )) )"
declare -r POS_SKIPPED_1="$(getCSI_CursorMove  Position 4 $(( 1 + (25 * 6) )) )"
declare -r POS_SKIPPED_2="$(getCSI_CursorMove  Position 7 $(( 1 + (25 * 6) )) )"
declare -r POS_ARCHIVED_1="$(getCSI_CursorMove Position 4 $(( 1 + (25 * 8) )) )"
declare -r POS_ARCHIVED_2="$(getCSI_CursorMove Position 7 $(( 1 + (25 * 8) )) )"
declare -r POS_CHECKED_1="$(getCSI_CursorMove  Position 4 $(( 1 + (25 * 9) )) )"
declare -r POS_CHECKED_2="$(getCSI_CursorMove  Position 7 $(( 1 + (25 * 9) )) )"

declare -r POS_MEMORY_USAGE="$(getCSI_CursorMove  Position 1 120 )"

################################################################################################################################################################
##                                                                                                                                                            ##
##      Variables Definition                                                                                                                                  ##
##                                                                                                                                                            ##
################################################################################################################################################################

declare hostBackuped="$INITIALIZATION_NAME"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare posFilename=''
declare -i lastSecond=-1

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

formatSizeV_Colors=( "$S_WHI" "$S_GRE" "$S_YEL" "$S_LRE" "$S_RED" "$S_MAG" "$S_LMA" )

# cp -vrfP --preserve=mode,ownership,timestamps,links --remove-destination /root/BackupFolder/TEST/Router/Current/home /root/BackupFolder/TEST/Router/Day-7/home
# echo "Day-7 OK"
#
# safeExit

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --


################################################################################################################################################################
##                                                                                                                                                            ##
##      Create Bases Folders                                                                                                                                  ##
##                                                                                                                                                            ##
################################################################################################################################################################

mkdir -p "$PATH_BACKUP_FOLDER"
mkdir -p "$PATH_BACKUP_FOLDER/$STATUS_FOLDER"

mkdir -p "$PATH_STATIC_WORKING_DIRECTORY"

for hostFolder in $hostBackuped ${HOSTS_LIST[@]}; do
	mkdir -p "$PATH_STATIC_WORKING_DIRECTORY/$hostFolder"
	mkdir -p "$PATH_STATIC_WORKING_DIRECTORY/$hostFolder/$VARIABLES_FOLDER"

	mkdir -p "$PATH_TMP/$hostFolder"
	mkdir -p "$PATH_TMP/$hostFolder/$VARIABLES_FOLDER"

	mkdir -p "$PATH_TMP/MEMORY/$hostFolder"
done

for hostFolder in ${HOSTS_LIST[@]}; do
	for periodFolder in ${PERIOD_FOLDERS[@]} Current; do
		mkdir -p "$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$hostFolder/$periodFolder"
		mkdir -p "$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$hostFolder/$periodFolder"
		mkdir -p "$PATH_BACKUP_FOLDER/$hostFolder/$periodFolder"
	done
done

unset hostFolder periodFolder

declare pathHWDD="$PATH_TMP/$hostBackuped"
declare pathHWDR="$PATH_TMP/MEMORY/$hostBackuped"
declare pathHWDS="$PATH_STATIC_WORKING_DIRECTORY/$hostBackuped"

################################################################################################################################################################
##                                                                                                                                                            ##
##      Pre-Backup Initialization                                                                                                                             ##
##                                                                                                                                                            ##
################################################################################################################################################################

echo
while (( screenWidth = $(tput cols), screenWidth < 380 )); do
	echo -en "${S_NOYEL}please enlarge the screen size now... ( ${S_BORED}$screenWidth${S_NOYEL}/380 ) \r"
	sleep 0.1
done

(( screenWidth = $(tput cols), filenameMaxSize = screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -i selected

clear
updateScreenCurrentAction 'Script initialization'
getCSI_CursorMove Position 4 1
posFilename="$(getCSI_CursorMove Position 10 1)${SO_INSERT_1}"

cp "$PATH_STATIC_WORKING_DIRECTORY/section-Backup-Started.txt" "$PATH_TMP/section-Backup-Started.txt"

if checkSectionStatus 'Backup-Started'; then
	(( BRUTAL > 0 )) && {
		echo -e "\n${A_WARNING_NR} The backup is in ${S_NORED}BRUTAL MODE${S_NO}, this will take a VERY LONG time !!"
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
else
	declare choice1='New Continue' choice2='' filename

	echo -e "\n${A_WARNING_NY} A backup is already ${S_NORED}IN PROGRESS${S_NO}, but has probably crashed..."

	[[ ($BRUTAL == 1 && ! -f "$PATH_TMP/brutal.mode") || (-f "$PATH_TMP/brutal.mode" && $BRUTAL == 0) ]] && {
		echo -e "${S_NORED}! you can't choose continue because the BRUTAL MODE was not the same in this backup...${S_NO}"
		choice1='New'
		choice2="${S_BA}${S_DA}${S_YEL}Continue${S_NO} "
	}

	echo -ne "${A_TAG_LENGTH_SIZE} Do you want to try to continue, or start a new one ? $choice2"; getWordUserChoiceV 'selected' $choice1

	case $selected in
		1)
			echo -e "\r${A_ABORTED_NY}"
			echo -e "\n${S_BORED}Removed files :${S_NOLRE}\n"

			while read filename; do
				echo -en "${posFilename}$filename"
			done < <(find "$PATH_TMP" -type f -name "section-*.txt" -print -delete; find "$PATH_STATIC_WORKING_DIRECTORY" -type f -print -delete)

			echo -e "${S_R_AL}"
			;;
		2)
			echo -e "\r${A_OK}"

			# restore all previous section status
			while read filename; do
				cp "$PATH_STATIC_WORKING_DIRECTORY/$filename" "$PATH_TMP/$filename"
			done < <(find "$PATH_STATIC_WORKING_DIRECTORY/" -type f -name 'section-*.txt' -printf '%P\n')

			;;
	esac

	sleep 5
	unset choice1 choice2 filename
fi

posFilename=''
unset selected

makeSectionStatusDoneX 'Backup-Started'

#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWM                                                                                                                                                        WMWM
#WMW     Build each backuped hosts files cache in background                                                                                                MWMW
#MWM                                                                                                                                                        WMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM

declare -a startingPoints excludedPoints
declare    hostName excludedPointsParameter
declare -i index

declare OIFS="$IFS"

updateScreenCurrentAction 'Build files cache in background now'

for hostName in ${HOSTS_LIST[@]}; do

	setBackupedHostConfiguration $hostName || continue

	[[ "$startingPoint" == '/' ]] &&
		startingPoint=''

	sed -i "s#^/#$startingPoint/#;s/ /\\ /g" "$pathHWDR/Include.items"
	sed -i "s#^/#$startingPoint/#;s/ /\\ /g;s/^/-path /" "$pathHWDR/Exclude.items"

	IFS=$'\n'
	startingPoints=( $(cat "$pathHWDR/Include.items") )
	excludedPoints=( $(cat "$pathHWDR/Exclude.items") )
	IFS="$OIFS"

	excludedPointsParameter=''
	[[ -n "${excludedPoints[*]}" ]] && {
		index=-1
		while (( ++index < ${#excludedPoints[@]} - 1 )); do
			excludedPoints[index]+=' -o'
		done

		excludedPointsParameter="-type d \\( ${excludedPoints[*]} \\) -prune -o"
	}

	{
 		ssh $hostSource "find -P ${startingPoints[@]} $excludedPointsParameter -printf '%s %y %d %p\n'" > "$pathHWDR/build_cache_$hostName.files" || :
		mv -f "$pathHWDR/build_cache_$hostName.files" "$pathHWDS/build_cache_$hostName.files"
	} &
done

rm -f "$pathHWDR/Include.items" "$pathHWDR/Exclude.items"

unset startingPoints excludedPoints hostName excludedPointsParameter index OIFS

#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWM                                                                                                                                                        WMWM
#WMW     Rotation of Archived Files                                                                                                                         MWMW
#MWM                                                                                                                                                        WMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM

if checkSectionStatus 'Rotation-Finished' $hostBackuped; then
	updateScreenCurrentAction 'Rotation of the archived files'

	if checkSectionStatus 'Rotation-Details' $hostBackuped; then

################################################################################################################################################################
##                                                                                                                                                            ##
##      Find who need to be rotated                                                                                                                           ##
##                                                                                                                                                            ##
################################################################################################################################################################

		updateScreenCurrentAction 'Rotation of the archived files :' 'Check date'

		declare     backupLastDateText='This backup is the first one !'
		declare -ai backupLastDate=( 0 0 0 0 0 )

		[[ -f "$PATHFILE_LAST_BACKUP_DATE" ]] && {
			read -a backupLastDate < "$PATHFILE_LAST_BACKUP_DATE"

			declare days hours minutes seconds
			read days hours minutes seconds < <( TZ=UTC printf '%(%-j %-H %-M %-S)T\n' $(( SCRIPT_START_TIME - backupLastDate[0] )) )

			printf -v seconds "${S_BOWHI}%02d${S_NOWHI} second%s" $seconds "$( (( seconds > 1 )) && echo 's' )"

			(( --days + hours + minutes != 0 )) &&
				printf -v minutes "${S_BOWHI}%02d${S_NOWHI} minute%s " $minutes "$( (( minutes > 1 )) && echo 's' )" ||
				minutes=''

			(( days + hours != 0 )) &&
				printf -v hours "${S_BOWHI}%02d${S_NOWHI} hour%s " $hours "$( (( hours > 1 )) && echo 's' )" ||
				hours=''

			(( days != 0 )) &&
				printf -v days "${S_BOWHI}%d${S_NOWHI} day%s " $days "$( (( days > 1 )) && echo 's' )" ||
				days=''

			backupLastDateText="The last backup was at ${S_NOWHI}$(cat "$PATHFILE_LAST_BACKUP_DATE.txt")${S_NO}, $days$hours$minutes$seconds${S_R_AL} ago."

			unset days hours minutes seconds
		}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		declare -i isYesterday
		declare    yesterday=''

		(( isYesterday = $(date '+%-H') <= 5 ? 1 : 0,

		isYesterday )) &&
			yesterday='-d yesterday'

		declare -ai backupCurrentDate=( $(date '+%s') $(date $yesterday '+%-j +%-V %-d %-m %-Y') )
		declare -i  dayOfWeek="$(date $yesterday '+%w')"

		unset yesterday

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		declare -i isNewDay=0 isNewWeek=0 isNewMonth=0 isNewYear=0

		((	isNewYear  = backupCurrentDate[5] > backupLastDate[5] ? 1 : 0,
			isNewMonth = backupCurrentDate[4] > backupLastDate[4] ? 1 : 0 | isNewYear,
			isNewDay   = backupCurrentDate[3] > backupLastDate[3] ? 1 : 0 | isNewMonth,

			isNewWeek  = ((backupCurrentDate[2] > backupLastDate[2]) ||
						  ((backupCurrentDate[2] == 1) && (backupLastDate[2] != 1))) ? 1 : 0	)) || :

		echo "${backupCurrentDate[*]}"   			>| "$PATHFILE_LAST_BACKUP_DATE"
		echo "$(date '+%A %-d %B %Y @ %H:%M:%S')"	>| "$PATHFILE_LAST_BACKUP_DATE.txt"

		unset backupCurrentDate backupLastDate

#===============================================================================================================================================================

#		== FOR DEBUG ==
		isNewDay=1

#===============================================================================================================================================================

		declare rotationStatus=''

		(( isNewDay    == 1 )) && rotationStatus="${S_NOGRE}NEW-DAY"
		(( isNewMonth  == 1 )) && rotationStatus="${S_NOGRE}NEW-MONTH"
		(( isNewYear   == 1 )) && rotationStatus="${S_NOGRE}NEW-YEAR"
		(( isYesterday == 1 )) && rotationStatus+="${S_NOGRE}${S_BL} <<"
		(( isNewWeek   == 1 )) && rotationStatus+=" ${S_NOYEL}${S_B_RED} NEW-WEEK "
		rotationStatus+="${S_R_AL}"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		declare -p	isNewDay isNewWeek isNewMonth isNewYear \
					isYesterday dayOfWeek backupLastDateText \
					rotationStatus > "$pathHWDS/$VARIABLES_FOLDER/Rotation-Details.var"

		makeSectionStatusDoneX 'Rotation-Details' $hostBackuped
	else
		[[ -f "$pathHWDS/$VARIABLES_FOLDER/Rotation-Details.var" ]] ||
			errcho ':EXIT:' 'Something wrong here with a variables files...'

		. "$pathHWDS/$VARIABLES_FOLDER/Rotation-Details.var"
	fi

	# pass this variables as constants...
	declare -ir isNewDay isNewWeek isNewMonth isNewYear
	declare -ir isYesterday dayOfWeek
	declare	-r	backupLastDateText rotationStatus

	getCSI_CursorMove Position 2 1
	getCSI_ScreenMove Insert 15
	getCSI_CursorMove Position 2 1
	echo -e "$backupLastDateText"

################################################################################################################################################################
##                                                                                                                                                            ##
##      Make the Rotation                                                                                                                                     ##
##                                                                                                                                                            ##
################################################################################################################################################################

	declare -i lineIndex=4

	showRotationTitle

	rotateFolders

	declare -ai hostEstimatedTotalFiles hostEstimatedTotalSize

	countFiles

	unset lineIndex

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	updateScreenCurrentAction 'Rotation finished :' "${S_BL}${S_BOYEL}██████ Press a key...${S_R_AL}"
	read noKey

	makeSectionStatusDoneX 'Rotation-Finished' $hostBackuped
else
	[[ -f "$pathHWDS/$VARIABLES_FOLDER/Rotation-Details.var" ]] ||
		errcho ':EXIT:' 'Something wrong here with a variables files...'

	. "$pathHWDS/$VARIABLES_FOLDER/Rotation-Details.var"

	# pass this variables as constants...
	declare -ir isNewDay isNewWeek isNewMonth isNewYear
	declare -ir isYesterday dayOfWeek
	declare	-r	backupLastDateText rotationStatus
fi

unset pathHWDD pathHWDR pathHWDS

#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWM                                                                                                                                                        WMWM
#WMW     Make the backup of all hosts (Main Loop)                                                                                                           MWMW
#MWM                                                                                                                                                        WMWM
#WMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMW
#MWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWMWM

################################################################################################################################################################
##                                                                                                                                                            ##
##      Backup Initialization                                                                                                                                 ##
##                                                                                                                                                            ##
################################################################################################################################################################

declare -i hostIndex=0

for hostBackuped in ${HOSTS_LIST[@]}; do
	# Wait the `find` command of the host files caching to finish
	while [[ -f "$PATH_TMP/MEMORY/$INITIALIZATION_NAME/build_cache_$hostBackuped.files" ]]; do
		updateScreenCurrentAction '[ Step 0   ] Waiting the files caching command to finish...'
		sleep 0.5
	done

	updateScreenCurrentAction '[ Step 0   ] Initialize remote filesystem...'

	declare pathHWDD="$PATH_TMP/$hostBackuped"
	declare pathHWDR="$PATH_TMP/MEMORY/$hostBackuped"
	declare pathHWDS="$PATH_STATIC_WORKING_DIRECTORY/$hostBackuped"

	setBackupedHostConfiguration || continue

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	mkdir -p "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped"
	[[ "$(ls -A "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped")" == '' ]] &&
		sshfs ${hostSource}:"${startingPoint}" "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped" -o follow_symlinks -o ro -o cache=yes -o cache_stat_timeout=120 -o cache_dir_timeout=120 -o kernel_cache -o ssh_command='ssh -c chacha20-poly1305@openssh.com -o Compression=no'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	posFilename="$(getCSI_CursorMove Position 10 1 )"

	getCSI_CursorMove Position 2 1
	getCSI_ScreenMove Insert 8

	getCSI_CursorMove Position 3 1
	printf "${S_BOWHI}   %-22s${S_BOLRE}   %-22s${S_BORED}   %-22s${S_BOYEL}   %-22s${S_BOLBL}   %-22s${S_BOGRE}   %-22s${S_BOCYA}   %-22s${S_BOBLA}   %-22s${S_BOMAG}   %-22s${S_BOYEL}   %-22s${S_R_AL}\n" 'Total' 'Excluded' 'Removed' 'Updated' 'Added' 'Up to date' 'Skipped' '#' 'To archive' 'To check'

	echoStat 0 0 "$POS_TOTAL_1" "$S_NOWHI"
	echoStat 0 0 "$POS_EXCUDED_1" "$S_NOLRE"
	echoStat 0 0 "$POS_REMOVED_1" "$S_NORED"
	echoStat 0 0 "$POS_UPDATED_1" "$S_NOYEL"
	echoStat 0 0 "$POS_ADDED_1" "$S_NOLBL"
	echoStat 0 0 "$POS_UPTODATE_1" "$S_NOGRE"
	echoStat 0 0 "$POS_SKIPPED_1" "$S_NOCYA"
	echoStat 0 0 "$POS_ARCHIVED_1" "$S_NOMAG"
	echoStat 0 0 "$POS_CHECKED_1" "$S_NOYEL"

################################################################################################################################################################
##                                                                                                                                                            ##
##      Build the files list (Step 1)                                                                                                                         ##
##                                                                                                                                                            ##
################################################################################################################################################################

	if checkSectionStatus 'Step_1' $hostBackuped; then

#==============================================================================================================================================================#
#       Make some initialization                                                                                                                               #
#==============================================================================================================================================================#

		updateScreenCurrentAction '[ Step 1   ] Make the lists of files...'

		declare -i step1_CountFilesTotal1=0		step1_CountSizeTotal1=0
		declare -i step1_CountFilesTotal2=0		step1_CountSizeTotal2=0
		declare -i step1_CountFilesAdded=0		step1_CountSizeAdded=0			canalAdded
		declare -i step1_CountFilesUpdated1=0	step1_CountSizeUpdated1=0		canalUpdate1
		declare -i step1_CountFilesUpdated2=0	step1_CountSizeUpdated2=0		canalUpdate2
		declare -i step1_CountFilesRemoved=0	step1_CountSizeRemoved=0		canalRemoved
		declare -i step1_CountFilesExcluded=0	step1_CountSizeExcluded=0		canalExcluded
		declare -i step1_CountFilesUptodate=0	step1_CountSizeUptodate=0
		declare -i step1_CountFilesSkipped=0	step1_CountSizeSkipped=0		canalSkipped
		declare -i																canalUpdatedFolders

		declare -i estimatedTotalFiles=${hostEstimatedTotalFiles[hostIndex]}
		declare -i estimatedTotalSize=${hostEstimatedTotalSize[hostIndex]}

		filenameMaxSize=$(( screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))	# TODO add flags

		declare fileMaxSize='--max-size=150MB'
		fileMaxSize='--max-size=500KB'
		fileMaxSize='--max-size=50KB'

		(( isNewWeek == 1 || BRUTAL == 1 )) &&	# TODO : and what about a "soft" brutal mode that don't cancel the size limitation ?
			fileMaxSize=''

		declare -i index subShellCount=5

		declare -i  canalMainInput canalMainOutput
		declare -a  processInputPipe processOutputPipe

		declare     mainPipe="$pathHWDR/Main.fake.pipe"
		declare     rsyncPipe="$pathHWDR/Rsync.pipe"

		mkfifo "$rsyncPipe"

		index=$subShellCount
		while (( --index >= 0 )); do
			processInputPipe[index]="$pathHWDR/Process-I-$index.fake.pipe"
			processOutputPipe[index]="$pathHWDR/Process-O-$index.fake.pipe"
		done

		declare -i skipOutput=0 refreshOutput=1

		declare fileData filename fileSize fileType fileFlags fileAction actionFlags

#==============================================================================================================================================================#
#       Initialize subshell system                                                                                                                             #
#==============================================================================================================================================================#

		exec {canalMainOutput}>"$mainPipe"

		{
			declare -ai canalProcessInputO

			index=$subShellCount
			while (( --index >= 0 )); do
				exec {canalProcessInputO[index]}>> "${processInputPipe[index]}"
			done

			index=0
			rsync -vvirtpoglDmn --files-from="$pathHWDR/Include.items" --exclude-from="$pathHWDR/Exclude.items" \
						$fileMaxSize --delete-during --delete-excluded -M--munge-links --modify-window=5 \
						--out-format="> %i %l %n" ${hostSource}:"${startingPoint}" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/" |
				while read fileData; do
					{
						[[ "${fileData:0:1}" != '>' ]] && {
							if (( ${#fileData} < 17 )) || [[ "${fileData:(-17)}" != ' is over max-size' ]]; then
								errcho "$fileData"
								continue
							fi

							echo "s 0 ${fileData:0:$(( ${#fileData} - 17 ))}"
							continue
						}

						[[ "${fileData:2:1}" == '*' ]] && {
							echo "${fileData:2}"
							continue
						}
					} >&${canalProcessInputO[++index % subShellCount]}

					echo "${fileData:2}"
				done

			pipeReceivedEnd=0
			pipeExpectedEnd=$subShellCount

			declare -i canalRsync
			exec {canalRsync}<>"$rsyncPipe"

			index=$subShellCount
			while (( --index >= 0 )); do
				echo "$LOOP_END_TAG" >&${canalProcessInputO[index]}
				exec {canalProcessInputO[index]}>&-
			done
			while read -t 60 -u ${canalRsync} fileData || checkLoopFail; do
				[[ -z "${fileData:-}" ]] && continue
				checkLoopEnd "$fileData" || { (( $? == 1 )) && break || continue; }

				sleep 0.1
			done

			exec {canalRsync}<&-
			unset canalRsync canalProcessInputO

			echo "$LOOP_END_TAG"

		} >&${canalMainOutput} &

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		{
			index=$subShellCount
			while (( --index >= 0 )); do
				{
					sleep 1

					pipeReceivedEnd=0
					pipeExpectedEnd=1

					declare -i canalProcessOutputI

					exec {canalProcessOutputI}< "${processOutputPipe[index]}"

					while read -t 60 -u ${canalProcessOutputI} fileData || checkLoopFail; do
						[[ -z "${fileData:-}" ]] && { sleep 0.2; continue; }
						checkLoopEnd "$fileData" || { (( $? == 1 )) && break || continue; }

						echo "$fileData"
					done

					exec {canalProcessOutputI}>&-
					unset canalProcessOutputI

					echo "$LOOP_END_TAG"
				} &
			done
		} >&${canalMainOutput}

		exec {canalMainOutput}>&-
		unset canalMainOutput

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		declare -i canalProcessOutputO

		index=$subShellCount
		while (( --index >= 0 )); do

			exec {canalProcessOutputO}>> "${processOutputPipe[index]}"

			{
				pipeReceivedEnd=0
				pipeExpectedEnd=1

				declare removeStatus

				declare -i canal canalProcessInputI

				mkfifo "$pathHWDR/Subshell-$index.pipe"
				exec {canal}<>"$pathHWDR/Subshell-$index.pipe"

				exec {canalProcessInputI}< "${processInputPipe[index]}"

				sleep 2

				while read -t 60 -u ${canalProcessInputI} fileFlags fileSize filename || checkLoopFail; do
					[[ -z "${fileFlags:-}" ]] && { sleep 0.2; continue; }
					checkLoopEnd "$fileFlags" || { (( $? == 1 )) && break || continue; }

					if [[ "${fileFlags:0:1}" == 's' ]]; then

						stat -c "%s" "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped/${filename}" >&${canal}
						read -u ${canal} fileSize

						echo "sf $fileSize ${filename}"
					else
						getIsExcludedV removeStatus "/$filename" "$pathHWDR/Exclude.items"

						stat -c "%s %F" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/${filename}"	>&${canal}
						read -u ${canal} fileSize fileType

						case "$fileType" in
							'regular file'|'regular empty file'|'fifo')
								fileType='f'
								;;
							'directory')
								continue
								;;
							'symbolic link')
								fileType='L'
								;;
							*)
								errcho ':EXIT:' "Type inconnu !! ($fileType)"
								;;
						esac

						echo "${removeStatus}${fileType} $fileSize ${filename}"
					fi
				done

				exec {canal}>&- {canalProcessInputI}>&-
				unset removeStatus canal canalProcessInputI

				rm -f "$pathHWDR/Subshell-$index.pipe"

				declare -i canalRsync

				exec {canalRsync}<>"$rsyncPipe"

				echo "$LOOP_END_TAG" >&${canalRsync}
				echo "$LOOP_END_TAG"

				sleep 0.5

				exec {canalRsync}>&-
				unset canalRsync
			} >&${canalProcessOutputO} &

			exec {canalProcessOutputO}>&-
		done

		unset canalProcessOutputO index

#==============================================================================================================================================================#
#       Build the files list                                                                                                                                   #
#==============================================================================================================================================================#

		exec {canalAdded}>"$pathHWDR/Added.files"
		exec {canalUpdated1}>"$pathHWDR/Updated1.files"
		exec {canalUpdated2}>"$pathHWDR/Updated2.files"
		exec {canalRemoved}>"$pathHWDR/Removed.files"
		exec {canalExcluded}>"$pathHWDR/Excluded.files"
		exec {canalSkipped}>"$pathHWDR/Skipped.files"	# TODO : Add uptodate for brutal mode !
		exec {canalUpdatedFolders}>"$pathHWDR/UpdatedFolders.files"

		pipeReceivedEnd=0
		pipeExpectedEnd=$(( 1 + subShellCount ))

		exec {canalMainInput}<"$mainPipe"

		while read -t 60 -u ${canalMainInput} fileFlags fileSize filename || checkLoopFail; do
			[[ -z "${fileFlags:-}" ]] && continue
			checkLoopEnd "$fileFlags" || { (( $? == 1 )) && break || continue; }

			fileAction="${fileFlags:0:1}"
			fileType="${fileFlags:1:1}"

			case "$fileType" in
				'f'|'S')
					fileType=$TYPE_FILE
					;;
				'd')
					[[ "$fileAction" == '.' ]] && {
						actionFlags="${fileFlags:2:9}         "
						[[ "$actionFlags" != '         ' ]] &&
							echo "$filename" >&${canalUpdatedFolders}
					}

					continue
					;;
				'L')
					fileType=$TYPE_SYMLINK
					;;
				*)
					errcho "$fileFlags $fileSize $filename"
					errcho ':EXIT:' "Type inconnu !! ($fileType)"
					;;
			esac

			((	step1_CountSizeTotal1 += fileSize,
				++step1_CountFilesTotal1,

			refreshOutput )) &&
				echoStatPercent $step1_CountFilesTotal1 $step1_CountSizeTotal1 "$POS_TOTAL_1" "$S_NOWHI" $estimatedTotalFiles $estimatedTotalSize

			case $fileAction in
			'.')
				actionFlags="${fileFlags:2:9}         "
				actionFlags="${actionFlags:0:9}"

				if [[ "$actionFlags" == '         ' ]]; then
					((	step1_CountSizeUptodate += fileSize,
						++step1_CountFilesUptodate,

					refreshOutput )) && {
						echoStat $step1_CountFilesUptodate $(( step1_CountSizeUptodate + step1_CountSizeUpdated2 )) "$POS_UPTODATE_1" "$S_NOGRE"
						echoFilename "/$filename" $fileSize "$A_UP_TO_DATE_G" "$S_NOGRE"
					}
				else
					getUpdateFlagsV 'actionFlags' "$actionFlags"

					((	step1_CountSizeUpdated2 += fileSize,
						++step1_CountFilesUpdated2,
						step1_CountSizeTotal2 += 0,
						++step1_CountFilesTotal2,

					refreshOutput )) && {
						echoStat $(( step1_CountFilesUpdated1 + step1_CountFilesUpdated2 )) $step1_CountSizeUpdated1 "$POS_UPDATED_1" "$S_NOYEL"
						echoStat $step1_CountFilesTotal2 $step1_CountSizeTotal2 "$POS_TOTAL_2" "$S_NOWHI"
						echoFilename "/$filename" $fileSize "$A_UPDATED_Y" "$S_NOYEL"
					}
					echo "$fileSize $filename" >&${canalUpdated2}
				fi
				;;
			's')
				((	step1_CountSizeSkipped += fileSize,
					++step1_CountFilesSkipped,

				refreshOutput )) && {
					echoStat $step1_CountFilesSkipped $step1_CountSizeSkipped "$POS_SKIPPED_1" "$S_NOCYA"
					echoFilename "/$filename" $fileSize "$A_SKIPPED" "$S_NOCYA"
				}

				echo "$fileSize $filename" >&${canalSkipped}
				;;
			'r')
				((	step1_CountSizeRemoved += fileSize,
					++step1_CountFilesRemoved,
					step1_CountSizeTotal2 += fileSize,
					++step1_CountFilesTotal2,

				refreshOutput )) && {
					echoStat $step1_CountFilesRemoved $step1_CountSizeRemoved "$POS_REMOVED_1" "$S_NORED"
					echoStat $(( step1_CountFilesRemoved + step1_CountFilesUpdated1 )) $(( step1_CountSizeRemoved + step1_CountSizeUpdated1 )) "$POS_ARCHIVED_1" "$S_NOMAG"
					echoStat $step1_CountFilesTotal2 $step1_CountSizeTotal2 "$POS_TOTAL_2" "$S_NOWHI"
					echoFilename "/$filename" $fileSize "$A_REMOVED_R" "$S_NORED"
				}

				echo "$fileSize $filename" >&${canalRemoved}
				;;
			'e')
				((	step1_CountSizeExcluded += fileSize,
					++step1_CountFilesExcluded,
					step1_CountSizeTotal2 += fileSize,
					++step1_CountFilesTotal2,

				refreshOutput )) && {
					echoStat $step1_CountFilesExcluded $step1_CountSizeExcluded "$POS_EXCUDED_1" "$S_NOLRE"
					echoStat $step1_CountFilesTotal2 $step1_CountSizeTotal2 "$POS_TOTAL_2" "$S_NOWHI"
					echoFilename "/$filename" $fileSize "$A_EXCLUDED_R" "$S_NOLRE"
				}

				echo "$fileSize $filename" >&${canalExcluded}
				;;
			*)
				actionFlags="${fileFlags:2:9}         "
				actionFlags="${actionFlags:0:9}"

				if [[ "$actionFlags" == '+++++++++' ]]; then
					((	step1_CountSizeAdded += fileSize,
						++step1_CountFilesAdded,
						step1_CountSizeTotal2 += (2 * fileSize),
						step1_CountFilesTotal2 += 2,

					refreshOutput )) && {
						echoStat $step1_CountFilesAdded $step1_CountSizeAdded "$POS_ADDED_1" "$S_NOLBL"
						echoStat $step1_CountFilesTotal2 $step1_CountSizeTotal2 "$POS_TOTAL_2" "$S_NOWHI"
						echoFilename "/$filename" $fileSize "$A_ADDED_B" "$S_NOLBL"
					}

					echo "$fileSize $filename" >&${canalAdded}
				else
					getUpdateFlagsV 'actionFlags' "$actionFlags"

					((	step1_CountSizeUpdated1 += fileSize,
						++step1_CountFilesUpdated1,
						step1_CountSizeTotal2 += (4 * fileSize),
						step1_CountFilesTotal2 += 4,

					refreshOutput )) && {
						echoStat $(( step1_CountFilesUpdated1 + step1_CountFilesUpdated2 )) $step1_CountSizeUpdated1 "$POS_UPDATED_1" "$S_NOYEL"
						echoStat $(( step1_CountFilesRemoved + step1_CountFilesUpdated1 )) $(( step1_CountSizeRemoved + step1_CountSizeUpdated1 )) "$POS_ARCHIVED_1" "$S_NOMAG"
						echoStat $step1_CountFilesTotal2 $step1_CountSizeTotal2 "$POS_TOTAL_2" "$S_NOWHI"
						echoFilename "/$filename" $fileSize "$A_UPDATED_Y" "$S_NOYEL"
					}

					echo "$fileSize $filename" >&${canalUpdated1}
				fi
				;;
			esac

			((	refreshOutput = ++skipOutput % SKIP_INTERVAL == 0 ? 1 : 0,

			lastSecond == SECONDS )) || {
				showMemoryUsage

				refreshOutput=0
				skipOutput=1

				echoStatPercent $step1_CountFilesTotal1 $step1_CountSizeTotal1 "$POS_TOTAL_1" "$S_NOWHI" $estimatedTotalFiles $estimatedTotalSize
				echoStat $step1_CountFilesTotal2 $step1_CountSizeTotal2 "$POS_TOTAL_2" "$S_NOWHI"
				echoStat $step1_CountFilesExcluded $step1_CountSizeExcluded "$POS_EXCUDED_1" "$S_NOLRE"
				echoStat $step1_CountFilesRemoved $step1_CountSizeRemoved "$POS_REMOVED_1" "$S_NORED"
				echoStat $step1_CountFilesAdded $step1_CountSizeAdded "$POS_ADDED_1" "$S_NOLBL"
				echoStat $(( step1_CountFilesUpdated1 + step1_CountFilesUpdated2 )) $step1_CountSizeUpdated1 "$POS_UPDATED_1" "$S_NOYEL"
				echoStat $step1_CountFilesUptodate $(( step1_CountSizeUptodate + step1_CountSizeUpdated2 )) "$POS_UPTODATE_1" "$S_NOGRE"
				echoStat $step1_CountFilesSkipped $step1_CountSizeSkipped "$POS_SKIPPED_1" "$S_NOCYA"
				echoStat $(( step1_CountFilesRemoved + step1_CountFilesUpdated1 )) $(( step1_CountSizeRemoved + step1_CountSizeUpdated1 )) "$POS_ARCHIVED_1" "$S_NOMAG"
			}
		done

#==============================================================================================================================================================#
#       Finalize the step 1                                                                                                                                    #
#==============================================================================================================================================================#

		unset skipOutput refreshOutput fileMaxSize
		unset fileData filename fileType fileFlags fileAction actionFlags fileSize

		echoStatPercent $step1_CountFilesTotal1 $step1_CountSizeTotal1 "$POS_TOTAL_1" "$S_NOWHI" $estimatedTotalFiles $estimatedTotalSize
		echoStat $step1_CountFilesExcluded $step1_CountSizeExcluded "$POS_EXCUDED_1" "$S_NOLRE"
		echoStat $step1_CountFilesRemoved $step1_CountSizeRemoved "$POS_REMOVED_1" "$S_NORED"
		echoStat $step1_CountFilesAdded $step1_CountSizeAdded "$POS_ADDED_1" "$S_NOLBL"
		echoStat $(( step1_CountFilesUpdated1 + step1_CountFilesUpdated2 )) $step1_CountSizeUpdated1 "$POS_UPDATED_1" "$S_NOYEL"
		echoStat $step1_CountFilesUptodate $(( step1_CountSizeUptodate + step1_CountSizeUpdated2 )) "$POS_UPTODATE_1" "$S_NOGRE"
		echoStat $step1_CountFilesSkipped $step1_CountSizeSkipped "$POS_SKIPPED_1" "$S_NOCYA"
		echoStat $(( step1_CountFilesRemoved + step1_CountFilesUpdated1 )) $(( step1_CountSizeRemoved + step1_CountSizeUpdated1 )) "$POS_ARCHIVED_1" "$S_NOMAG"

		exec {canalMainInput}>&-
		exec {canalAdded}>&-
		exec {canalUpdated1}>&-
		exec {canalUpdated2}>&-
		exec {canalRemoved}>&-
		exec {canalExcluded}>&-
		exec {canalSkipped}>&-
		exec {canalUpdatedFolders}>&-

		rm -f "$mainPipe"
		rm -f "$rsyncPipe"

		declare -i index=$subShellCount
		while (( --index >= 0 )); do
			rm -f "${processInputPipe[index]}"
			rm -f "${processOutputPipe[index]}"
		done

		sort -n -k 1 "$pathHWDR/Added.files"    > "$pathHWDS/Added.files";		rm -f "$pathHWDR/Added.files"
		sort -n -k 1 "$pathHWDR/Updated1.files" > "$pathHWDS/Updated1.files";	rm -f "$pathHWDR/Updated1.files"
		sort -n -k 1 "$pathHWDR/Updated2.files" > "$pathHWDS/Updated2.files";	rm -f "$pathHWDR/Updated2.files"
		sort -n -k 1 "$pathHWDR/Removed.files"  > "$pathHWDS/Removed.files";	rm -f "$pathHWDR/Removed.files"
		sort -n -k 1 "$pathHWDR/Excluded.files" > "$pathHWDS/Excluded.files";	rm -f "$pathHWDR/Excluded.files"
		sort -n -k 1 "$pathHWDR/Skipped.files"  > "$pathHWDS/Skipped.files";	rm -f "$pathHWDR/Skipped.files"

		mv -f "$pathHWDR/UpdatedFolders.files" "$pathHWDS/UpdatedFolders.files"

		declare -p	step1_CountFilesTotal1 step1_CountSizeTotal1 step1_CountFilesAdded	step1_CountSizeAdded \
					step1_CountFilesUpdated1 step1_CountSizeUpdated1 step1_CountFilesUpdated2 step1_CountSizeUpdated2 \
					step1_CountFilesRemoved step1_CountSizeRemoved step1_CountFilesExcluded step1_CountSizeExcluded \
					step1_CountFilesUptodate step1_CountSizeUptodate step1_CountFilesSkipped step1_CountSizeSkipped >| "$pathHWDS/$VARIABLES_FOLDER/Step_1.var"

		unset canalAdded canalUpdated1 canalUpdated2 canalRemoved canalExcluded canalSkipped canalUpdatedFolders canalMainInput
		unset mainPipe rsyncPipe subShellCount index processInputPipe processOutputPipe

		unset estimatedTotalFiles estimatedTotalSize

		sleep 2

		makeSectionStatusDoneX 'Step_1' $hostBackuped
	else
		[[ -f "$pathHWDS/$VARIABLES_FOLDER/Step_1.var" ]] ||
			errcho ':EXIT:' 'Something wrong here with a variables files...'

		. "$pathHWDS/$VARIABLES_FOLDER/Step_1.var"
	fi

################################################################################################################################################################
##                                                                                                                                                            ##
##      Preparing the next steps                                                                                                                              ##
##                                                                                                                                                            ##
################################################################################################################################################################

	declare -i stepA_P_CountFilesTotal=0	stepA_R_CountFilesTotal=$step1_CountFilesTotal2
	declare -i stepA_P_CountSizeTotal=0		stepA_R_CountSizeTotal=$step1_CountSizeTotal2

	echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
	echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

	declare -i stepA_T_CountFilesChecked=0
	declare -i stepA_T_CountSizeChecked=0

	echoStat 0 0 "$POS_CHECKED_1" "$S_NOYEL"
	echoStat 0 0 "$POS_CHECKED_2" "$S_NOYEL"

	filenameMaxSize=$(( screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

################################################################################################################################################################
##                                                                                                                                                            ##
##      Puts all excluded files into Trash (Step 2)                                                                                                           ##
##                                                                                                                                                            ##
################################################################################################################################################################

	if checkSectionStatus 'Step_2' $hostBackuped; then

#==============================================================================================================================================================#
#       Make some initialization                                                                                                                               #
#==============================================================================================================================================================#

		updateScreenCurrentAction '[ Step 2   ] Remove all excluded files...'

		declare -i step2_P_CountFilesExcluded=0		step2_R_CountFilesExcluded=$step1_CountFilesExcluded
		declare -i step2_P_CountSizeExcluded=0		step2_R_CountSizeExcluded=$step1_CountSizeExcluded

		echoStatPercent $step2_R_CountFilesExcluded $step2_R_CountSizeExcluded "$POS_EXCUDED_1" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded
		echoStatPercent $step2_P_CountFilesExcluded $step2_P_CountSizeExcluded "$POS_EXCUDED_2" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded

		if checkSectionStatus 'Step_2-Current' $hostBackuped; then
			if (( step1_CountFilesExcluded > 0 )); then

#==============================================================================================================================================================#
#       Trash all excluded files in Current                                                                                                                    #
#==============================================================================================================================================================#

				updateScreenCurrentAction '[ Step 2 A ] Remove all excluded files :' 'Current'

				declare sourceFolder="$PATH_BACKUP_FOLDER/$hostBackuped/Current"
				declare excludedFolder="$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$hostBackuped/Current"

				cp "$pathHWDS/Excluded.files" "$pathHWDR/Excluded.files"

				declare filename fileType
				declare -i fileSize

				while read fileSize filename; do

					((	step2_R_CountSizeExcluded -= fileSize, --step2_R_CountFilesExcluded,
						step2_P_CountSizeExcluded += fileSize, ++step2_P_CountFilesExcluded,

						stepA_R_CountSizeTotal -= fileSize, --stepA_R_CountFilesTotal,
						stepA_P_CountSizeTotal += fileSize, ++stepA_P_CountFilesTotal	))

					getFileTypeV fileType "$sourceFolder/$filename"
					[[ "$fileType" == '   ' ]] && continue

					echoFilename "/$filename" $fileSize "$A_EXCLUDED_R" "$S_NOLRE"

					echoStatPercent $step2_R_CountFilesExcluded $step2_R_CountSizeExcluded "$POS_EXCUDED_1" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded
					echoStatPercent $step2_P_CountFilesExcluded $step2_P_CountSizeExcluded "$POS_EXCUDED_2" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded

					echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
					echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

					clonePathDetails "$sourceFolder" "$excludedFolder" "${filename%/*}"
					# BUG TODO !! Folders flags need to be updated EACH time is the source is not the same... ie even if all folders already exists, they need to be updated
					# between day-2 > day-3 and day-1 > day-2, because even if the path is the same, folders in day-1 has not obviously the same flags than day-2...
					# BUT !! Update it each time for each files is a HUGE waste of time and ressource, so probably this need to collect all path that need to be updated and update them
					# before the files transfert.... The longest TODO ever in this script :))
					mv -f "$sourceFolder/$filename" "$excludedFolder/$filename"

					showMemoryUsage
				done < "$pathHWDR/Excluded.files"

				echoStatPercent $step2_R_CountFilesExcluded $step2_R_CountSizeExcluded "$POS_EXCUDED_1" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded
				echoStatPercent $step2_P_CountFilesExcluded $step2_P_CountSizeExcluded "$POS_EXCUDED_2" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded

				echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal1 $step1_CountSizeTotal1
				echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal1 $step1_CountSizeTotal1

				rm -f "$pathHWDR/Excluded.files"
			fi

			unset filename fileType fileSize
			unset sourceFolder excludedFolder

			makeSectionStatusDoneX 'Step_2-Current' $hostBackuped
		fi

		for periodFolder in ${PERIOD_FOLDERS[@]}; do

#==============================================================================================================================================================#
#       Trash all excluded files in others period                                                                                                              #
#==============================================================================================================================================================#

			updateScreenCurrentAction '[ Step 2 B ] Remove all excluded files :' "$periodFolder"

			if checkSectionStatus "Step_2-$periodFolder" $hostBackuped; then
				declare sourceFolder="$PATH_BACKUP_FOLDER/$hostBackuped/$periodFolder"
				declare excludedFolder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Excluded/$hostBackuped/$periodFolder"

				declare filename fileType filePath
				declare -i canal fileSize

				declare excludedItem searchedItem destinationItem searchedItemType

				while read excludedItem; do
					excludedItem="${excludedItem:1}"

					searchedItem="$sourceFolder/$excludedItem"
					destinationItem="$excludedFolder/$excludedItem"
					getFileTypeV searchedItemType "$sourceFolder/$excludedItem"

					[[ "$searchedItemType" == '   ' ]] && continue

					if [[ "${searchedItemType:0:2}" == 'Ed' ]]; then
						clonePathDetails "$sourceFolder" "$excludedFolder" "$excludedItem"

						while read fileSize filename; do
							filePath="${filename%/*}"

							((	step2_P_CountSizeExcluded += fileSize, ++step2_P_CountFilesExcluded	))

							clonePathDetails "$searchedItem" "$destinationItem" "$filePath"
							mv -f "$searchedItem/$filename" "$destinationItem/$filename"

							echoStatPercent $step2_P_CountFilesExcluded $step2_P_CountSizeExcluded "$POS_EXCUDED_2" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded

							echoFilename "/$filename" $fileSize "$A_EXCLUDED_R" "$S_NOLRE"

							showMemoryUsage
						done < <(find -P "$searchedItem" -type f,l,p,s,b,c -printf '%s %P\n')
					else
						getFileSizeV fileSize "$sourceFolder/$excludedItem"
						filename="$excludedItem"

						((	step2_P_CountSizeExcluded += fileSize, ++step2_P_CountFilesExcluded	))

						clonePathDetails "$sourceFolder" "$excludedFolder" "${excludedItem/*}"
						mv -f "$sourceFolder/$excludedItem" "$excludedFolder/$excludedItem"

						echoStatPercent $step2_P_CountFilesExcluded $step2_P_CountSizeExcluded "$POS_EXCUDED_2" "$S_NOLRE" $step1_CountFilesExcluded $step1_CountSizeExcluded

						echoFilename "/$filename" $fileSize "$A_EXCLUDED_R" "$S_NOLRE"
					fi

					showMemoryUsage
				done < "$pathHWDR/Exclude.items"

				unset canal filename fileType filePath fileSize
				unset excludedItem searchedItem destinationItem searchedItemType
				unset sourceFolder excludedFolder

				makeSectionStatusDoneX "Step_2-$periodFolder" $hostBackuped
			fi
		done

		unset periodFolder
		unset step2_P_CountFilesExcluded step2_R_CountFilesExcluded step2_P_CountSizeExcluded step2_R_CountSizeExcluded
		unset step2_P_PercentFilesExcluded step2_R_PercentFilesExcluded step2_P_PercentSizeExcluded step2_R_PercentSizeExcluded

		makeSectionStatusDoneX 'Step_2' $hostBackuped
	fi

################################################################################################################################################################
##                                                                                                                                                            ##
##      Archive modified or removed files (Step 3)                                                                                                            ##
##                                                                                                                                                            ##
################################################################################################################################################################

	if checkSectionStatus 'Step_3' $hostBackuped; then

#==============================================================================================================================================================#
#       Make some initialization                                                                                                                               #
#==============================================================================================================================================================#

		updateScreenCurrentAction '[ Step 3   ] Archive modified or removed files...'

		declare -i step3_T_CountFilesArchived=$(( step1_CountFilesRemoved + step1_CountFilesUpdated1 ))
		declare -i step3_T_CountSizeArchived=$(( step1_CountSizeRemoved + step1_CountSizeUpdated1 ))

		declare -i step3_P_CountFilesArchived=0		step3_R_CountFilesArchived=$step3_T_CountFilesArchived
		declare -i step3_P_CountSizeArchived=0		step3_R_CountSizeArchived=$step3_T_CountSizeArchived

		echoStatPercent $step3_R_CountFilesArchived $step3_R_CountSizeArchived "$POS_ARCHIVED_1" "$S_NOMAG" $step3_T_CountFilesArchived $step3_T_CountSizeArchived
		echoStatPercent $step3_P_CountFilesArchived $step3_P_CountSizeArchived "$POS_ARCHIVED_2" "$S_NOMAG" $step3_T_CountFilesArchived $step3_T_CountSizeArchived

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		if [[ -f "$pathHWDD/$VARIABLES_FOLDER/$hostBackuped-Step_3.var" ]]; then
			. "$pathHWDD/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"
		else
# 			declare -p PROGRESS_TOTAL_ITEM PROGRESS_TOTAL_SIZE PROGRESS_CURRENT_FILES_ITEM PROGRESS_CURRENT_FILES_SIZE >| "$pathHWDD/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"
			: # TODO
		fi

		declare sourceFolder="$PATH_BACKUP_FOLDER/$hostBackuped/Current"
		declare destinationFolder="$PATH_BACKUP_FOLDER/$hostBackuped/Day-1"
		declare excludedFolder="$PATH_BACKUP_FOLDER/$TRASH_FOLDER/Rotation/$hostBackuped/Day-1"

		if checkSectionStatus 'Step_3-Update' $hostBackuped; then

#==============================================================================================================================================================#
#       Archive modified files                                                                                                                                 #
#==============================================================================================================================================================#

			updateScreenCurrentAction '[ Step 3 A ] Archive modified files...'

			declare -i canalToCheck
			exec {canalToCheck}>"$pathHWDR/ToCheck.files"

			if (( step1_CountFilesUpdated1 > 0 )); then

				((	stepA_T_CountFilesChecked = 0,	stepA_T_CountSizeChecked = 0	)) || :

				cp "$pathHWDS/Updated1.files" "$pathHWDR/Updated1.files"

				declare filename
				declare -i fileSize

				while read fileSize filename; do
					((	step3_R_CountSizeArchived -= fileSize, --step3_R_CountFilesArchived,
						step3_P_CountSizeArchived += fileSize, ++step3_P_CountFilesArchived,

						stepA_R_CountSizeTotal -= fileSize, --stepA_R_CountFilesTotal,
						stepA_P_CountSizeTotal += fileSize, ++stepA_P_CountFilesTotal,

						stepA_T_CountSizeChecked += fileSize,  ++stepA_T_CountFilesChecked	))

					echoStatPercent $step3_R_CountFilesArchived $step3_R_CountSizeArchived "$POS_ARCHIVED_1" "$S_NOMAG" $step3_T_CountFilesArchived $step3_T_CountSizeArchived
					echoStatPercent $step3_P_CountFilesArchived $step3_P_CountSizeArchived "$POS_ARCHIVED_2" "$S_NOMAG" $step3_T_CountFilesArchived $step3_T_CountSizeArchived

					echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
					echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

					echoStat $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked "$POS_CHECKED_1" "$S_NOYEL"

					echoFilename "/$filename" $fileSize "$A_BACKUPED_Y" "$S_NOYEL"

					clonePathDetails "$sourceFolder" "$destinationFolder" "${filename%/*}"
					if [[ -f "$destinationFolder/$filename" ]]; then
						clonePathDetails "$destinationFolder" "$excludedFolder" "${filename%/*}"
						mv -f "$destinationFolder/$filename" "$excludedFolder/$filename"
					fi

					cp -fP --preserve=mode,ownership,timestamps,links --remove-destination "$sourceFolder/$filename" "$destinationFolder/$filename"
					echo "$fileSize $filename" >&${canalToCheck}

					showMemoryUsage
				done < "$pathHWDR/Updated1.files"

				rm -f "$pathHWDR/Updated1.files"

				unset filename fileSize

# 				declare -p PROGRESS_TOTAL_ITEM PROGRESS_TOTAL_SIZE PROGRESS_CURRENT_FILES_ITEM PROGRESS_CURRENT_FILES_SIZE >| "$pathHWDD/$VARIABLES_FOLDER/$hostBackuped-Step_3.var"
			fi

			exec {canalToCheck}>&-
			unset canalToCheck

			makeSectionStatusDoneX 'Step_3-Update' $hostBackuped
		fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		if checkSectionStatus 'Step_3-Remove' $hostBackuped; then

#==============================================================================================================================================================#
#       Archive removed files                                                                                                                                  #
#==============================================================================================================================================================#

			updateScreenCurrentAction '[ Step 3 B ] Archive removed files...'

			declare -i step3_P_CountFilesRemoved=0		step3_R_CountFilesRemoved=$step1_CountFilesRemoved
			declare -i step3_P_CountSizeRemoved=0		step3_R_CountSizeRemoved=$step1_CountSizeRemoved

			echoStatPercent $step3_R_CountFilesRemoved $step3_R_CountSizeRemoved "$POS_REMOVED_1" "$S_NOMAG" $step1_CountFilesRemoved $step1_CountSizeRemoved
			echoStatPercent $step3_P_CountFilesRemoved $step3_P_CountSizeRemoved "$POS_REMOVED_2" "$S_NOMAG" $step1_CountFilesRemoved $step1_CountSizeRemoved

			if (( step1_CountFilesRemoved > 0 )); then
				cp "$pathHWDS/Removed.files" "$pathHWDR/Removed.files"

				declare filename
				declare -i fileSize

				while read fileSize filename; do
					((	step3_R_CountSizeArchived -= fileSize, --step3_R_CountFilesArchived,
						step3_P_CountSizeArchived += fileSize, ++step3_P_CountFilesArchived,

						step3_R_CountSizeRemoved -= fileSize, --step3_R_CountFilesRemoved,
						step3_P_CountSizeRemoved += fileSize, ++step3_P_CountFilesRemoved,

						stepA_R_CountSizeTotal -= fileSize, --stepA_R_CountFilesTotal,
						stepA_P_CountSizeTotal += fileSize, ++stepA_P_CountFilesTotal	))

					echoStatPercent $step3_R_CountFilesArchived $step3_R_CountSizeArchived "$POS_ARCHIVED_1" "$S_NOMAG" $step3_T_CountFilesArchived $step3_T_CountSizeArchived
					echoStatPercent $step3_P_CountFilesArchived $step3_P_CountSizeArchived "$POS_ARCHIVED_2" "$S_NOMAG" $step3_T_CountFilesArchived $step3_T_CountSizeArchived

					echoStatPercent $step3_R_CountFilesRemoved $step3_R_CountSizeRemoved "$POS_REMOVED_1" "$S_NORED" $step1_CountFilesRemoved $step1_CountSizeRemoved
					echoStatPercent $step3_P_CountFilesRemoved $step3_P_CountSizeRemoved "$POS_REMOVED_2" "$S_NORED" $step1_CountFilesRemoved $step1_CountSizeRemoved

					echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
					echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

					echoFilename "/$filename" $fileSize "$A_BACKUPED_Y" "$S_NORED"

					clonePathDetails "$sourceFolder" "$destinationFolder" "${filename%/*}"
					if [[ -f "$destinationFolder/$filename" ]]; then
						clonePathDetails "$destinationFolder" "$excludedFolder" "${filename%/*}"
						mv -f "$destinationFolder/$filename" "$excludedFolder/$filename"
					fi
					mv -f "$sourceFolder/$filename" "$destinationFolder/$filename"

					showMemoryUsage
				done < "$pathHWDR/Removed.files"

				rm -f "$pathHWDR/Removed.files"

				unset filename fileSize
			fi

			unset step3_P_CountFilesRemoved step3_R_CountFilesRemoved step3_P_CountSizeRemoved step3_R_CountSizeRemoved
			unset step3_P_PercentFilesRemoved step3_R_PercentFilesRemoved step3_P_PercentSizeRemoved step3_R_PercentSizeRemoved

			makeSectionStatusDoneX 'Step_3-Remove' $hostBackuped
		fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		unset step3_T_CountFilesArchived step3_T_CountSizeArchived
		unset step3_P_CountFilesArchived step3_R_CountFilesArchived step3_P_CountSizeArchived step3_R_CountSizeArchived
		unset step3_P_PercentFilesArchived step3_R_PercentFilesArchived step3_P_PercentSizeArchived step3_R_PercentSizeArchived

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		if checkSectionStatus 'Step_3-Checksum' $hostBackuped; then

#==============================================================================================================================================================#
#       Check integrity of files copied while the archive process                                                                                              #
#==============================================================================================================================================================#

			updateScreenCurrentAction '[ Step 3 C ] Check new archived files...'

			checkFilesIntegrity "" "$sourceFolder" "$destinationFolder/"

			makeSectionStatusDoneX 'Step_3-Checksum' $hostBackuped
		fi

		makeSectionStatusDoneX 'Step_3' $hostBackuped
	fi

################################################################################################################################################################
##                                                                                                                                                            ##
##      Make the backup for real now (Step 4)                                                                                                                 ##
##                                                                                                                                                            ##
################################################################################################################################################################

	if checkSectionStatus 'Step_4' $hostBackuped; then

#==============================================================================================================================================================#
#       Make some initialization                                                                                                                               #
#==============================================================================================================================================================#

		updateScreenCurrentAction '[ Step 4   ] Make the backup for real now...'

		cat "$pathHWDS/Updated1.files" "$pathHWDS/Updated2.files" "$pathHWDS/Added.files" > "$pathHWDR/ToBackup.files"

		declare -i step4_P_CountFilesAdded=0	step4_R_CountFilesAdded=$step1_CountFilesAdded
		declare -i step4_P_CountSizeAdded=0		step4_R_CountSizeAdded=$step1_CountSizeAdded

		echoStatPercent $step4_R_CountFilesAdded $step4_R_CountSizeAdded "$POS_ADDED_1" "$S_NOLBL" $step1_CountFilesAdded $step1_CountSizeAdded
		echoStatPercent $step4_P_CountFilesAdded $step4_P_CountSizeAdded "$POS_ADDED_2" "$S_NOLBL" $step1_CountFilesAdded $step1_CountSizeAdded

		declare -i step4_T_CountFilesUpdated=$(( step1_CountFilesUpdated1 + step1_CountFilesUpdated2 ))
		declare -i step4_T_CountSizeUpdated=$step1_CountSizeUpdated1

		declare -i step4_P_CountFilesUpdated=0		step4_R_CountFilesUpdated=$step4_T_CountFilesUpdated
		declare -i step4_P_CountSizeUpdated=0		step4_R_CountSizeUpdated=$step4_T_CountSizeUpdated

		echoStatPercent $step4_R_CountFilesUpdated $step4_R_CountSizeUpdated "$POS_UPDATED_1" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated
		echoStatPercent $step4_P_CountFilesUpdated $step4_P_CountSizeUpdated "$POS_UPDATED_2" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated

		filenameMaxSize=$(( screenWidth - $(getCSI_StringLength "$(echoFilename '' 0 "${A_EMPTY_TAG}" '')") ))

		declare -a missing_files=( )

#==============================================================================================================================================================#
#       Backup all files that need it                                                                                                                          #
#==============================================================================================================================================================#

		if checkSectionStatus 'Step_4-Rsync' $hostBackuped; then

			declare -i canalToBackup canalToBackupnow
			declare -i filesCount sizeCount
			declare filename fileSize

			rsync -vvitpoglDm --files-from="$pathHWDS/UpdatedFolders.files" --modify-window=5 -M--munge-links \
							--preallocate --inplace --no-whole-file --block-size=32768 $compressConfig \
							--out-format="> %i %l %n" ${hostSource}:"${startingPoint}" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/" |
			while read fileData fileFlags fileSize filename; do
				[[ "${fileData:0:1}" == '>' ]] || continue
				[[ "${fileFlags:1:1}" == 'd' ]] || continue

				echoFilename "FOLDER : /$filename" $fileSize "$A_UPDATED_Y" "$S_NOYEL"
			done

			exec {canalToBackup}<"$pathHWDR/ToBackup.files"

			while [[ 1 ]]; do
				rm -f "$pathHWDR/ToBackupNow.files"

				exec {canalToBackupnow}>"$pathHWDR/ToBackupNow.files"

				missing_files=( )
				filesCount=0
				sizeCount=0
				while read -u ${canalToBackup} fileSize filename; do
					((	sizeCount += fileSize,
						++filesCount	))
					echo "$filename" >&${canalToBackupnow}

					(( sizeCount > 1000000000 || filesCount > 2000 )) && break
				done

				exec {canalToBackupnow}>&-

				(( filesCount == 0 )) && break

				declare fileData fileFlags sleepTime fileAction actionFlags
				declare -i canal

				sleepTime="$(printf '%1.4f' $(echo "scale=4; $sizeCount * 0.000000001" | bc))"
				(( ${sleepTime%.*} <= 3 )) || sleepTime=3

				while read fileData fileFlags fileSize filename; do
					[[ "${fileData:0:1}" == '>' ]] || {
						errcho "$fileData $fileFlags $fileSize $filename"
						continue
					}
					[[ "${fileFlags:1:1}" != 'd' ]] || continue

					fileAction="${fileFlags:0:1}"
					actionFlags="${fileFlags:2:9}         "
					actionFlags="${actionFlags:0:9}"

					if [[ "$fileAction" == '.' ]]; then
						if [[ "$actionFlags" == '         ' ]]; then
							((	--filesCount,
								--step4_R_CountFilesUpdated, ++step4_P_CountFilesUpdated,
								stepA_R_CountSizeTotal -= 0, --stepA_R_CountFilesTotal,
								stepA_P_CountSizeTotal += 0, ++stepA_P_CountFilesTotal	))

							missing_files+=( "$filename" )

							echoStatPercent $step4_R_CountFilesUpdated $step4_R_CountSizeUpdated "$POS_UPDATED_1" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated
							echoStatPercent $step4_P_CountFilesUpdated $step4_P_CountSizeUpdated "$POS_UPDATED_2" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated

							echoFilename "/$filename" $fileSize "$A_FAILED_R" "$S_NOYEL"
						else
							actionFlags="${actionFlags//./ }"
							getUpdateFlagsV Flags "$actionFlags"	# TODO

							((	--filesCount,
								--step4_R_CountFilesUpdated, ++step4_P_CountFilesUpdated,
								stepA_R_CountSizeTotal -= 0, --stepA_R_CountFilesTotal,
								stepA_P_CountSizeTotal += 0, ++stepA_P_CountFilesTotal	))

							missing_files+=( "$filename" )

							echoStatPercent $step4_R_CountFilesUpdated $step4_R_CountSizeUpdated "$POS_UPDATED_1" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated
							echoStatPercent $step4_P_CountFilesUpdated $step4_P_CountSizeUpdated "$POS_UPDATED_2" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated

							echoFilename "/$filename" $fileSize "$A_UPDATED_Y" "$S_NOYEL"
						fi
					else
						if [[ "${actionFlags:0:9}" == '+++++++++' ]]; then
							((	--filesCount,
								step4_R_CountSizeAdded -= fileSize,   --step4_R_CountFilesAdded,
								step4_P_CountSizeAdded += fileSize,   ++step4_P_CountFilesAdded,

								stepA_T_CountSizeChecked += fileSize, ++stepA_T_CountFilesChecked,

								stepA_R_CountSizeTotal -= fileSize,   --stepA_R_CountFilesTotal,
								stepA_P_CountSizeTotal += fileSize,   ++stepA_P_CountFilesTotal	))

							missing_files+=( "$filename" )

							echo "$fileSize $filename" >> "$pathHWDR/ToCheck.files" # TODO a canal

							echoStatPercent $step4_R_CountFilesAdded $step4_R_CountSizeAdded "$POS_ADDED_1" "$S_NOLBL" $step1_CountFilesAdded $step1_CountSizeAdded
							echoStatPercent $step4_P_CountFilesAdded $step4_P_CountSizeAdded "$POS_ADDED_2" "$S_NOLBL" $step1_CountFilesAdded $step1_CountSizeAdded

							echoFilename "/$filename" $fileSize "$A_ADDED_B" "$S_NOLBL"
						else
							((	--filesCount,
								step4_R_CountSizeUpdated -= fileSize, --step4_R_CountFilesUpdated,
								step4_P_CountSizeUpdated += fileSize, ++step4_P_CountFilesUpdated,

								stepA_T_CountSizeChecked += fileSize, ++stepA_T_CountFilesChecked,

								stepA_R_CountSizeTotal -= fileSize,   --stepA_R_CountFilesTotal,
								stepA_P_CountSizeTotal += fileSize,   ++stepA_P_CountFilesTotal	))

							missing_files+=( "$filename" )

							echo "$fileSize $filename" >> "$pathHWDR/ToCheck.files"

							echoStatPercent $step4_R_CountFilesUpdated $step4_R_CountSizeUpdated "$POS_UPDATED_1" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated
							echoStatPercent $step4_P_CountFilesUpdated $step4_P_CountSizeUpdated "$POS_UPDATED_2" "$S_NOYEL" $step4_T_CountFilesUpdated $step4_T_CountSizeUpdated

							echoFilename "/$filename" $fileSize "$A_UPDATED_Y" "$S_NOYEL"
						fi

						echoStatPercent $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked "$POS_CHECKED_1" "$S_NOYEL" $stepA_T_CountFilesChecked $stepA_T_CountSizeChecked
					fi

					echoStatPercent $stepA_R_CountFilesTotal $stepA_R_CountSizeTotal "$POS_TOTAL_1" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2
					echoStatPercent $stepA_P_CountFilesTotal $stepA_P_CountSizeTotal "$POS_TOTAL_2" "$S_NOWHI" $step1_CountFilesTotal2 $step1_CountSizeTotal2

					showMemoryUsage
				done < <(rsync -vvitpoglDm --files-from="$pathHWDR/ToBackupNow.files" --modify-window=5 -M--munge-links \
							--preallocate --inplace --no-whole-file --block-size=32768 $compressConfig \
							--out-format="> %i %l %n" ${hostSource}:"${startingPoint}" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/")

				(( filesCount > 0 )) && {
					while read filename; do
						for fileData in "${missing_files[@]}"; do
							[[ "$fileData" != "$filename" ]] || {
								fileData=''
								break
							}
						done
						[[ -z "${fileData:-}" ]] || {
							echoFilename "/$filename" 0 "$A_ERROR_BR" "$S_NORED"
							sleep 0.5
# 							echoFilename "  STAT: $(stat --format="%F %g %u %A %s %n" "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped/${filename}")" 0 "$A_EMPTY_TAG" "$S_BOYEL"
						}
					done < "$pathHWDR/ToBackupNow.files"
				}

				sleep $sleepTime
			done

			exec {canalToBackup}<&-

			unset canalToBackup canalToBackupnow filesCount sizeCount
			unset canal fileData filename fileFlags fileAction actionFlags fileSize sleepTime

			makeSectionStatusDoneX 'Step_4-Rsync' $hostBackuped
		fi

#==============================================================================================================================================================#
#       Check integrity of files copied or modified while the backup process                                                                                   #
#==============================================================================================================================================================#

		checkFilesIntegrity "$hostSource" "$startingPoint" "$PATH_BACKUP_FOLDER/$hostBackuped/Current/"

		unset sizeIndex
		unset sizeLimit offsetSize sizeLimitText sleepDuration

		unset step4_P_CountFilesAdded step4_R_CountFilesAdded step4_P_CountSizeAdded step4_R_CountSizeAdded
		unset step4_P_PercentFilesAdded	step4_R_PercentFilesAdded step4_P_PercentSizeAdded step4_R_PercentSizeAdded
		unset step4_T_CountFilesUpdated step4_T_CountSizeUpdated

		unset step4_P_CountFilesUpdated step4_R_CountFilesUpdated step4_P_CountSizeUpdated step4_R_CountSizeUpdated
		unset step4_P_PercentFilesUpdated step4_R_PercentFilesUpdated step4_P_PercentSizeUpdated step4_R_PercentSizeUpdated

		makeSectionStatusDoneX 'Step_4' $hostBackuped
	fi

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	unset pathHWDD pathHWDR pathHWDS
	unset compressConfig hostSource startingPoint destinationPoint

	unset step1_CountFilesTotal1 step1_CountSizeTotal1 step1_CountFilesAdded step1_CountSizeAdded step1_CountFilesUpdated1 step1_CountSizeUpdated1
	unset step1_CountFilesUpdated2 step1_CountSizeUpdated2 step1_CountFilesRemoved step1_CountSizeRemoved step1_CountFilesExcluded step1_CountSizeExcluded
	unset step1_CountFilesUptodate step1_CountSizeUptodate step1_CountFilesSkipped step1_CountSizeSkipped
	unset stepA_P_CountFilesTotal stepA_R_CountFilesTotal stepA_P_CountSizeTotal stepA_R_CountSizeTotal

	unset stepA_T_CountFilesChecked stepA_T_CountSizeChecked

	fusermount -u -z -q "$PATH_HOST_BACKUPED_FOLDER/$hostBackuped" &2> /dev/null

	(( ++hostIndex ))
done

unset hostEstimatedTotalFiles hostEstimatedTotalSize hostIndex

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
# 	showTitle "Remove all empty folders..."

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
# else
# 	showTitle "Remove all empty folders..." "$A_SKIPPED"
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
		for hostFolder in ${HOSTS_LIST[@]}; do
			if [ -d "$PATH_BACKUP_FOLDER/_Trashed_/Excluded/$dateFolder/$hostFolder" ]; then
				countFiles "_Trashed_/Excluded/$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for dateFolder in ${PERIOD_FOLDERS[@]}; do
		for hostFolder in ${HOSTS_LIST[@]}; do
			if [ -d "$PATH_BACKUP_FOLDER/_Trashed_/Rotation/$dateFolder/$hostFolder" ]; then
				countFiles "_Trashed_/Rotation/$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for dateFolder in ${PERIOD_FOLDERS[@]}; do
		for hostFolder in ${HOSTS_LIST[@]}; do
			if [ -d "$PATH_BACKUP_FOLDER/$dateFolder/$hostFolder" ]; then
				countFiles "$dateFolder/$hostFolder" "End"
			fi
		done
	done
	for hostFolder in ${HOSTS_LIST[@]}; do
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

	Next Objectives :	- Add a diffSize beside the fileSize.
						- Add and substract expected fileSize while checkFilesIntegrity and others.
						- Correct the bug with use of clonePathDetails.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 28.08.2019
		Summary : Many fix, update and improvement...

		Details :	- Redesigne the rsync loops to take files sorted by size in one pass.
					- Fix some bug with file type detection.
					- Added the showMemoryUsage function.
					- Fix : Now the rotateFolder function will rotate the current folder.
					- In the section 4, folders are now updated too.
					- Added a check to know if the host is reachable now via ssh connection.
					- Added the setIncludeExcludeFiles function that will now create the "Include.items" and "Exclude.items" files.
					- Added a section to launch a distant `find` on each host to build the host files cache in background.
					- Fix a major bug in the whole code with files descriptor in `while read -u ${canal}` that was never closed...
					- Make better sizes colours.
					- And more...

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	28.08.2019
		Step 4 section
			- Added the missing_files variables to check what files are missed by rsync.
			- Fix : Now show an error for each missed file.
			- Fix : Up to date files are now counted as failed updated files.

		Main source code
			- Make better sizes colours.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	15.08.2019
		Main source code
			- Fix : removed some useless `unset` at the end of main loop.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	14.08.2019
		Rotation process
			- Added more statistics totals.
			- Now the countFiles function keep their results for the step 1 estimated total.

		getPercentageV function
			- Fix : Stop showing negative value (work wrong with decimals).
			- Now truncate value higher than 999 (1234 -> +34).

		Main source code
			- Removed some useless constants.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	13.08.2019
		Main source code
			- Added a section to launch a distant `find` on each host to build the host files cache in background.
			- Fix : While building the cache, the `find` command will take care of the startingPoint variable now.
			- Added the INITIALIZATION_NAME constant.
			- Fix : At the end of the main loop, unset some missing variables.
			- Fix : Now check the screen width at the start of the script.
			- Fix a major bug in the whole code with files descriptor in `while read -u ${canal}` that was never closed...

		Backup Initialization
			- Added a check to wait the `find` command of the host files caching to finish.

		echoFilename function
			- Fix : Now filenameMaxSize has a default value (80).

		rotateFolder function
			- Fix : Added some missing / before filename output.
			- Fix a bug when source variable is "Current".

		rotateFolders function
			- Fix some bug in insert/remove lines management.

		Step 4 section
			- Fix : stop show the sleepTime variable here.
			- Fix : Now maximum files in a chunk is 2000.

		Pre-Backup Initialization
			- Fix : If a backup can be resumed, only the section-Backup-Started.txt file is restored first. Others section files are restored only if
				the user choose to continue the current backup process.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	12.08.2019
		Main source code
			- Added the setIncludeExcludeFiles function that will now create the "Include.items" and "Exclude.items" files.

		setIncludeExcludeFiles function
			- Fix : `sed` will now remove line with commented file (#) even if the sharp have space before it.
			- Now the function can take a optional hostname parameter to override the default one.
			- the function is renamed as setBackupedHostConfiguration.

		setBackupedHostConfiguration function
			- Added a check to know if the host is reachable now via ssh connection.

		Backup Initialization
			- Fix : The variables definition now use some defaults values.
			- The variables definition is moved into the setBackupedHostConfiguration function.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	11.08.2019
		Step 2 section
			- Fix : In others periods, remaining statisics must not be decremented here.

		Step 1 section
			- Fix : calls of getUpdateFlagsV now return result in the actionFlags variable.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	09.08.2019
		Step 4 section
			- Folders are now updated too.

		Step 3 section
			- Fix : Files are archived anyway. The check for a new day need to be elsewhere.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	08.08.2019
		rotateFolder function
			- Fix : Delete trashed content only at a new day.
			- Fix : Now the function can rotate the current folder (ie delete trashed content).

		rotateFolders
			- Fix : Now the function will rotate the current folder.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	05.08.2019
		Main source code
			- Added the showMemoryUsage function.
			- Call the showMemoryUsage function now in all important location.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	04.08.2019
		Main source code
			- Fix missing `unset` of stepA_T_CountFilesChecked and stepA_T_CountSizeChecked variables.
			- Removed some useless use of canal with `while read`.
			- Fix some bug with file type detection. It was easy, the check was just useless now, and are removed xD

		checkFilesIntegrity function
			- Fix some missing -i with `local` declaration.
			- Fix : file_size is now a numeric variable (-i)

		Step 4 section
			- Redesigne the rsync loops to take files sorted by size in one pass.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 04.08.2019
		Summary : Added the checkFilesIntegrity function. Save files details directly into a single file per types.

		Details :	- Added the checkFilesIntegrity function.
					- Save files details directly into a single file per types.
					- Sort all files details per size before moving it in the static working directory.
					- Now the echoStatPercent function directly calculates the percentage.
					- Adding some variables to customize the source host and the mounting point in sshfs ans rsync.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	03.08.2019
		Main source code
			- Added the checkFilesIntegrity function.
			- Removed globals variables : $stepA_P_CountFilesChecked, $stepA_R_CountFilesChecked, $stepA_P_CountSizeChecked and $stepA_R_CountSizeChecked.
				They are now locals variables inside the checkFilesIntegrity function.
			-

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	02.08.2019
		Step 1 section
			- Sort all files details per size before moving it in the static working directory.
			- Fix : Some wrong or missing `unset` variables.
			- Fix : Now remove pipe files from the array variables, not from hardcoded name.

		Step 2 section
			- Fix : Now use a single file as input.

		Step 3 section
			- Fix : Now use a single file as input.

		Step 4 section
			- Fix : Now use a single file as input.
			- Removed some duplicated call to echoStatPercent function just by moving it outside `if`.

		Main source code
			- Removed useless takeWorkingDirectory, backupWorkingDirectory and clearWorkingDirectory function.
			- Now the echoStatPercent function directly calculates the percentage.
			- Update all echoStatPercent function call.
			- Adding the "step" in each updateScreenCurrentAction function call from the main loop.
			- Adding some variables to customize the source host and the mounting point in sshfs ans rsync.
			- Added the echoStatNoPercent function to just hide percentage on screen.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	31.07.2019
		Main source code
			- Removed openFilesListsSpliter and closeFilesListsSpliter functions.

		Step 1 section
			- Fix some missing `unset`variables.
			- Save files details directly into a single file per types.


# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 31.07.2019
		Summary : Redesigne and make huge optimization on the pipe system.

		Details :	- Redesigne and make huge optimization on the pipe system.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	31.07.2019
		Step 1 section
			- Redesigne all pipe system.
			- Make huge optimization on the pipe system.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 30.07.2019
		Summary : `read` now now dispatch directly some values in variables.

		Details :	- `read` now now dispatch directly some values in variables in (probably) every while loop.
					- Try some optimization with the pipe design. (I will continue in a new git branch...)
					- Removed some useless options in the rsync call. (--info=name2,backup,del,copy,skip)
					- Fix : On each `while` loop with `read`, the readed variables will be unset on `read` timeout, and fail on next check. This is fixed now.
					- Fix some bugs and make some improvement.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	30.07.2019
		The whole source code
			- Fix : On each `while` loop with `read`, the readed variables will be unset on `read` timeout, and fail on next check. This is fixed now.

		Step 1 section
			- Try some optimization with the pipe design. (I will continue in a new git branch...)
			- Removed some useless options in the rsync call. (--info=name2,backup,del,copy,skip)

		Step 2 section
			- fileSize and canal variables are now a numeric (-i).
			- `read` now now dispatch directly some values in variables.

		Step 3 section
			- fileSize and canal variables are now a numeric (-i). (except in the check integrity part.)
			- `read` now now dispatch directly some values in variables.
			- Removed some useless options in the rsync call. (--info=name2,backup,del,copy,skip)

		Step 4 section
			- `read` now now dispatch directly some values in variables.
			- Removed some useless options in the rsync call. (--info=name2,backup,del,copy,skip)

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	29.07.2019
		countFiles function
			- The statistics file is now moved in the static working directory at the end of the function.
			- `read` now now dispatch directly some values in variables.
			- file_size is not padded anymore and is now a numeric variable ( -i ).
			- Fix : the variable pos_total is moved up outside of the checkSectionStatus, so it is declared even if the section status already exist.

		rotateFolder function
			- The statistics files are now moved in the static working directory at the end of the function.
			- `read` now now dispatch directly some values in variables.
			- file_size is not padded anymore and is now a numeric variable ( -i ).
			- Fix : Now a better path is output with the filename.
			- Fix : "R"otation or "E"xcluded prefix is now correcly output is the statistics files.
			- Fix : Size of overwrited files are now counted correctly.
			- Little optimisation with the filename output (avoid double if).

		Rotation section
			- Showing the last backup date with padded time and sort form.

		Main loop section
			- Now unmount the backuped host folder at the end.

		Step 1 section
			- The "Removed" subshell now don't resend data if the item is a folder.
			- Fix : the "Removed" and "Skipped" subshell now use dot in the flags details part.
			- Added timeout for all `read` in `while`.
			- Fix : Unset pipe filename variables.
			- Fix : the "Removed" and "Skipped" subshell now don't send the flags details part anymore.

		openFilesListsSpliter function
			- `read` now now dispatch directly some values in variables.
			- file_size is not padded anymore.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	28.07.2019
		countFiles function
			- Add some missing `local` declarations.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 27.07.2019
		Summary : Cleanup all useless comments.

		Details :	- Cleanup all useless comments.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	27.07.2019
		The whole source code
			- Cleanup all useless comments.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 27.07.2019
		Summary : Verify deeply and fix missing `declare` and `unset` variables.

		Details :	- Verify deeply and fix missing `declare` and `unset` variables.
					- Correct some variables case.
					- Work a bit on the "comments art" of source code sections and decorations.
					- Start to redesigne the static working directory management.
					- Most of "position" variables are now constants.
					- Fix some little bugs.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	27.07.2019
		Main Source Code
			- Fix : Recreate the late backup indicator that has unexpedly vanished. (??)
			- Renamed compress_details variable to compressConfig.
			- Most of "position" variables are now constants.
			- Correct some variables case.
			- Verify deeply and fix missing `declare` and `unset` variables.
			- Fix a regressive bug with the regex that dectect folder type in second part of the step 2. (due to the output change of getFileTypeV function)
			- Fix the size variable that should be fileSize.

	26.07.2019
		Main Source Code
			- Fix : In the end of the check files loop of the step 4, fix a buf that output always the same filename.
			- Make a "Script Initialization" section and group inside global constants and variables definitions.
			- Start to redesigne the static working directory management.
			- Add the makeSectionStatusDoneX function that hooks up to the genuine makeSectionStatusDone function.
			- Work a bit on the "comments art" of source code sections and decorations.
			- Fix : Remove the useless from now on rotationStatusSize variable.
			- Verify and fix some missing `unset` variables.
			- Removed the getHostWorkingDirectory function that is not really usefull.
			- Rename variables pathWorkingDirectory -> pathHWDD and pathWorkingDirectoryRAM -> pathHWDR ("H"ost "W"orking "D"irectory "D"isk|"R"am)
			- Added the pathHWDS variable ("H"ost "W"orking "D"irectory "S"tatic)

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	COMMIT - 26.07.2019
		Summary : The up-down screen output transition has progressed. Removed some useless part of the source code.

		Details :	- Removed a lot of useless functions.
					- Redesigned the main rotation files loop. (rotateFolders function)
					- Renamed all statistics variables in steps 1 to 4.
					- Folders are now processed in a different way...
					- Fix some little bugs.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	26.07.2019
		Work a bit more on the up-down screen output transition.
		Fix : Correct a bug on the files check in the step 4, where files that fail all 10 try are not decremented in statistics.
		Rename the statistics variables in others steps than step 1 too.
		Since now the change log format will change a bit with new commit details.

	25.07.2019
		Fix : $hostBackuped don't need to be quoted.
		Fix : ${HOSTS_LIST[@]} don't need to be quoted.
		Add the rotateFolders function to manage the call rotateFolder function loop.
		Work a bit more on the up-down screen output transition.
		Add the "To archive" statistics column, and debug a bit the others columns.
		Rename the statistics variables in the step 1.
		Fix : Normally the lastAction variable is removed everywhere.
		Fix : In the step 1 and others, just ignore all folders output since now.
		Add and manage a list file for folders that need a flags update.

	24.07.2019
		Just finished the big transition of the up-down screen output. Not perfect, but working in most cases.
		Recheck the whole source code because of the deep changing of getFileTypeV function in .script_common.sh.
		Removing the following useless function : getBackupFileName, moveBackupFile, showTitle, makeBaseFolders, getFileSize, formatSize, buildTimer,
				saveVariablesState_Rotation, loadVariablesState_Rotation, initVariablesState_Rotation_Statistics, saveVariablesState_Rotation_Statistics,
				loadVariablesState_Rotation_Statistics, initVariablesState_Step_1_Statistics, saveVariablesState_Step_1_Statistics,
				loadVariablesState_Step_1_Statistics, initVariablesState_Step_2, initVariablesState_Step_2_Statistics, showProgress_CountFiles,
				showProgress_Step_2
		Fix : Remove the few remaining call to showTitle.
		Add the showRotationTitle function.
		Fix some bug and make optimization in rotateFolder function.

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
