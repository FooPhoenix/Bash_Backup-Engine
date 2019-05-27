#!/bin/bash

################################################################################
################################################################################
####                                                                        ####
####     BashColors.sh                                                      ####
####                                                                        ####
################################################################################
################################################################################
#																			   #
#	A script to include inside others scripts to get styles and                #
#	colors variables shortcuts...                                              #
#																			   #
################################################################################
#																	09.04.2019

# shopt -s extglob



#==============================================================================#
#==     Text Styles Constants Definition                                     ==#
#==============================================================================#

# STYLES
TS_BOLD='\e[2m\e[1m'
TS_DARK='\e[2m'
TS_ITALIC='\e[3m'
TS_UNDERLINE='\e[4m'
TS_BLINK='\e[5m'
TS_BARRED='\e[9m'

# RESET
TR_ALL='\e[0m'
TR_BOLD='\e[21m\e[22m'
TR_DARK='\e[22m'
TR_ITALIC='\e[23m'
TR_UNDERLINE='\e[24m'
TR_BLINK='\e[25m'
TR_BARRED='\e[29m'
TR_FCOLOR='\e[39m'
TR_BCOLOR='\e[49m'

# RESETING FOREGROUND
TF_BLACK='\e[0;30m'
TF_RED='\e[0;31m'
TF_GREEN='\e[0;32m'
TF_YELLOW='\e[0;33m'
TF_BLUE='\e[0;34m'
TF_MAGENTA='\e[0;35m'
TF_CYAN='\e[0;36m'
TF_LGRAY='\e[0;37m'
TF_DGRAY='\e[0;90m'
TF_LRED='\e[0;91m'
TF_LGREEN='\e[0;92m'
TF_LYELLOW='\e[0;93m'
TF_LBLUE='\e[0;94m'
TF_LMAGENTA='\e[0;95m'
TF_LCYAN='\e[0;96m'
TF_WHITE='\e[0;97m'

# RESETING BACKGROUND
TB_BLACK='\e[0;40m'
TB_RED='\e[0;41m'
TB_GREEN='\e[0;42m'
TB_YELLOW='\e[0;43m'
TB_BLUE='\e[0;44m'
TB_MAGENTA='\e[0;45m'
TB_CYAN='\e[0;46m'
TB_LGRAY='\e[0;47m'
TB_DGRAY='\e[0;100m'
TB_LRED='\e[0;101m'
TB_LGREEN='\e[0;102m'
TB_LYELLOW='\e[0;103m'
TB_LBLUE='\e[0;104m'
TB_LMAGENTA='\e[0;105m'
TB_LCYAN='\e[0;106m'
TB_WHITE='\e[0;107m'

# FOREGROUND
TF__BLACK='\e[30m'
TF__RED='\e[31m'
TF__GREEN='\e[32m'
TF__YELLOW='\e[33m'
TF__BLUE='\e[34m'
TF__MAGENTA='\e[35m'
TF__CYAN='\e[36m'
TF__LGRAY='\e[37m'
TF__DGRAY='\e[90m'
TF__LRED='\e[91m'
TF__LGREEN='\e[92m'
TF__LYELLOW='\e[93m'
TF__LBLUE='\e[94m'
TF__LMAGENTA='\e[95m'
TF__LCYAN='\e[96m'
TF__WHITE='\e[97m'

# BACKGROUND
TB__BLACK='\e[40m'
TB__RED='\e[41m'
TB__GREEN='\e[42m'
TB__YELLOW='\e[43m'
TB__BLUE='\e[44m'
TB__MAGENTA='\e[45m'
TB__CYAN='\e[46m'
TB__LGRAY='\e[47m'
TB__DGRAY='\e[100m'
TB__LRED='\e[101m'
TB__LGREEN='\e[102m'
TB__LYELLOW='\e[103m'
TB__LBLUE='\e[104m'
TB__LMAGENTA='\e[105m'
TB__LCYAN='\e[106m'
TB__WHITE='\e[107m'

# SPECIAL STYLES
TS__BOLD_WHITE='\e[2m\e[1;97m'

# CURSOR MOVE		# https://shiroyasha.svbtle.com/escape-sequences-a-quick-guide-1     http://tldp.org/HOWTO/Bash-Prompt-HOWTO/x361.html
TM_Up1='\e[1A'
TM_Up2='\e[2A'
TM_Up3='\e[3A'

TM_ScrollUp1='\e[1S'

TM_ClearEndLine='\e[0K'
TM_ClearLine='\e[2K'

TM_ClearBottomScreen='\e[0J'


#==============================================================================#
#==     Text Styles Functions Definition                                     ==#
#==============================================================================#

function TRGB()
{
	local R="$1"
	local G="$2"
	local B="$3"

	local D="$4"

	if [ "$D" == 'B' ]; then
		D='48'
	else
		D='38'
	fi

	local Regex='^[0-5]$'

	if ! [[ "$R" =~ $Regex ]] ; then
		R=5
	fi
	if ! [[ "$G" =~ $Regex ]] ; then
		G=5
	fi
	if ! [[ "$B" =~ $Regex ]] ; then
		B=5
	fi

	local Color=$(( 16 + ((R * 36) + (G * 6) + B) ))

	echo "\e[$D;5;${Color}m"
}

function TGRAY()
{
	local G="$1"

	local D="$2"

	if [ "$D" == 'B' ]; then
		D='48'
	else
		D='38'
	fi

	local Regex='^[0-9]?[0-9]$'

	if ! [[ "$G" =~ $Regex ]]; then
		G='12'
	elif [ "$G" -gt 23 ]; then
		G='23'
	fi

	local Color=$(( 232 + G ))

	echo "\e[$D;5;${Color}m"
}

function T_RemoveColor()
{
	local String

	String="${2//\\e\[+([0-9])*(;+([0-9]))m}"

	if [ "${3}" == '1' ]; then
		eval "${1}=\"${#String}\""
	else
		eval "${1}=\"${String}\""
	fi
}

function T_SHOW_PALETTE()
{
	echo -e $TR_ALL
	for R in {0..5}; do
		for G in {0..5}; do
			echo -e $TR_ALL
			if [ "$G" -lt 3 ]; then
				F='23'
			else
				F='0'
			fi
			for B in {0..5}; do
				echo -en "`TGRAY $F``TRGB $R $G $B B`   `printf '%s-%s-%s' $R $G $B`   "
			done
		done
	done
	echo -e $TR_ALL
	i=0
	for G in {0..23}; do
		if [ "$i" -lt 12 ]; then
			F='23'
		else
			F='0'
		fi
		echo -en "`TGRAY $F``TGRAY $G B`    `printf '%3s' $i`    "
		(( i++ ))
		if [ $(( i % 6 )) -eq 0 ]; then
			echo -e $TR_ALL
		fi
	done
}
