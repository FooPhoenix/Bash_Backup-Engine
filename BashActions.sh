#!/bin/bash

################################################################################
################################################################################
####                                                                        ####
####     .BashActions.sh                                                    ####
####                                                                        ####
################################################################################
################################################################################
#																			   #
#	A script to include inside others scripts to get actions tags              #
#	shortcuts...					                 						   #
#																			   #
################################################################################
#																	09.04.2019

#==============================================================================#
#==     Include bases sub-scripts                                            ==#
#==============================================================================#

if [ "$TF_RED" == '' ]; then
	echo "ERROR: No color available..."
	exit 1
fi



#==============================================================================#
#==     Actions Constants Definition                                         ==#
#==============================================================================#

Actions=(	'OK'			'     OK     '		"${TF_GREEN}"
			'Warning'		'  WARNING   '		"${TF_YELLOW}"
			'Failed'		'   FAILED   '		"${TF_RED}"
			'Empty'			'   EMPTY    '		"${TF_GREEN}"
			'Aborted'		'  ABORTED   '		"${TF_RED}"
			'Error'			'   ERROR    '		"${TF_RED}"
			'Successed'		' SUCCESSED  '		"${TF_GREEN}"
			'Updated'		'  UPDATED   '		"${TF_YELLOW}"
			'Skipped'		'  SKIPPED   '		"${TF_CYAN}"
			'Added'			'   ADDED    '		"${TF_LBLUE}"
			'Copied'		'   COPIED   '		"${TF_GREEN}"
			'Moved'			'   MOVED    '		"${TF_GREEN}"
			'Removed'		'  REMOVED   '		"${TF_RED}"
			'Exclued'		'  EXCLUED   '		"${TF_YELLOW}${TB__RED}"
			'Resended'		'  RESENDED  '		"${TF_YELLOW}"
			'Backuped'		'  BACKUPED  '		"${TF_YELLOW}"
			'UpToDate'		' UP TO DATE '		"${TF_GREEN}")

A_NoAction="              ${TR_ALL}"
A_ActionSpace='              '

index=0
while [ "${Actions[$index]}" != '' ]; do
	eval "A_${Actions[$index]}=\"${TR_ALL}${TF_WHITE}[${Actions[$(( $index + 2))]}${Actions[$(( $index + 1))]}${TR_ALL}${TF_WHITE}]${TR_ALL}\""
	(( index = index + 3 ))
done
