#!/usr/bin/bash

CONFIG_DIR=/home/romulo/Repos/worklog/conf/worklog.conf

usage(){
	echo "$0 usage:" 
	echo "$0 -p PROJECT_NAME -s STATUS [-d LOG_DIR] event_message"
	echo -e "\tSTATUS: start, pause, resume, end"
	exit 1;
}

create_log_file(){
	mkdir -pv "${LOG_DIR%\/*}"
	touch "$LOG_DIR"
}

check_status(){
	# check if given project status is already has been proccessed

	if [ ! -f "$LOG_DIR" ]; then
		# if file does not exists, then
		create_log_file
	fi

	last_record=$(grep "$PROJECT" "$LOG_DIR")
	
	# get last START event and timestamp of the given project
	last_start=$(grep "$PROJECT" "$LOG_DIR" | grep "START" | tail -1 | cut -d " " -f 1-2)
	last_start=$(date -d "$last_start" +%s)

	# get last END event and timestamp of the given project
	last_end=$(grep "$PROJECT" "$LOG_DIR" | grep "END" | tail -1 | cut -d " " -f 1-2) 
	last_end=$(date -d "$last_end" +%s)

	# get last PAUSE event and timestamp of the given project
	last_pause=$(grep "$PROJECT" "$LOG_DIR" | grep "PAUSE" | tail -1 | cut -d " " -f 1-2)
	last_pause=$(date -d "$last_pause" +%s)

	# get last RESUME event and timestamp of the given project
	last_resume=$(grep "$PROJECT" "$LOG_DIR" | grep "RESUME" | tail -1 | cut -d " " -f 1-2)
	last_resume=$(date -d "$last_resume" +%s)
	now=$(date +%s)
	
	if [ ! -z "$last_record" ];then
		# check if each status occurred before it's counter part

		has_started_after_a_pause=$([ "$last_pause" -lt "$last_start" ] && echo 1 || echo 0)
		has_started_after_a_end=$([ "$last_end" -lt "$last_start" ] && echo 1 || echo 0)
		has_ended_after_a_start=$([ "$last_start" -lt "$last_end" ] && echo 1 || echo 0)
		has_paused_after_a_resume=$([ "$last_resume" -lt "$last_pause" ] && echo 1 || echo 0)

		if [ "$STATUS" == "START" ]; then
			if [ "$has_started_after_a_end" == 1 ]; then
				echo "The project [$PROJECT] already is marked as [$STATUS]"
				exit 1
			fi
		fi

		if [ "$STATUS" == "END" ]; then
			if [ "$has_paused_after_a_resume" == 1 ]; then
				echo "The project [$PROJECT] is PAUSED please RESUME before END"
				exit 1
			fi

			if [ "$has_ended_after_a_start" == "1" ]; then
				echo "The project [$PROJECT] already is marked as [$STATUS]"
				exit 1
			fi
		fi

		if [ "$STATUS" == "PAUSE" ]; then
			if [ "$has_paused_after_a_resume" == "1" ]; then
				echo "This project [$PROJECT] already is marked as [$STATUS]"
				exit 1
			fi
		fi

		if [ "$STATUS" == "RESUME" ]; then
			if [ "$has_paused_after_a_resume"  == "0"  ]; then
				echo "This project Status for [$PROJECT] already is marked as [$STATUS]"
				exit 1
			fi
		fi
		
	elif [ "$STATUS" != "START" ]; then
		echo "there is no way to mark status [$STATUS] because the log is empty"
		exit 1
	fi
}

log_config(){
	LOG_FORMAT=${LOG_FORMAT/\%time/$TIME}
	LOG_FORMAT=${LOG_FORMAT/\%project/$PROJECT}
	LOG_FORMAT=${LOG_FORMAT/\%event/$EVENT_MESSAGE}
	LOG_FORMAT=${LOG_FORMAT/\%status/$STATUS}
}

savelog(){
	EVENT_MESSAGE="$1"

	# get current time
	TIME="$(date +"$DATE_FORMAT")"

	# remove double quotes before saving
	TIME=$(sane_conf_string "$TIME")
	TIME=${TIME##\"}
	TIME=${TIME%%\"}
	
	log_config

	# save log in file directory
	echo "$LOG_FORMAT" >> "$LOG_DIR"
	
}

sane_conf_string(){
	string="$1"

	without_equal_sign="${string##= }"
	without_left_quotemark="${without_equal_sign##\"}"
	without_right_quotemark="${without_left_quotemark%%\"}"
	sanitized="$without_right_quotemark"

	echo "$sanitized"
}

read_config_file(){
	while read -r conf value
	do
		if [ "$conf" == "LOG_DIR" ]; then
			LOG_DIR=$(sane_conf_string "$value")
		fi

		if [ "$conf" == "DATE_FORMAT" ]; then
			DATE_FORMAT=$(sane_conf_string "$value")
		fi
	
		if [ "$conf" == "LOG_FORMAT" ]; then
			LOG_FORMAT=$(sane_conf_string "$value")
		fi

	done < "$CONFIG_DIR"
}

read_user_options(){
	while getopts "d:p:s:h" OPTION; do
		case $OPTION in
			p)	# Specify project name
				PROJECT="${OPTARG}"
				;;
			d)	# Specify directory where the log will be saved
				LOG_DIR="${OPTARG}"
				;;
			s)	# Specify status of the project [start,end,pause]
				if [[ "$OPTARG" != "start" ]] &&
					[[ "$OPTARG" != "end" ]] &&
					[[ "$OPTARG" != "resume" ]] &&
					[[ "$OPTARG" != "pause" ]]; then
					echo "invalid status passed as argument -s $OPTARG"
					exit 1;
				fi;
				STATUS="${OPTARG^^}"
				;;
			h | *)	# Display help
				usage
				exit 0
				;;
		esac
	done
}

main(){
	read_config_file
	read_user_options "$@"
	check_status

	# remove user options from final event message
	# necessary due the scope of getopts in 'read_user_options' function
	shift "$(($OPTIND-1))"				

	EVENT_MESSAGE="$*"							

	savelog "$EVENT_MESSAGE"					
}

main "$@"
