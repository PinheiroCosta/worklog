#!/usr/bin/bash 
CONFIG_DIR=/home/romulo/Repos/worklog/conf/worklog.conf

usage(){
	# Show how to use the program
	echo "$0 usage:" 
	echo "$0 -p PROJECT_NAME -s STATUS [-d LOG_DIR] event_message"
	echo -e "\tSTATUS: start, pause, resume, end"
	exit 1;
}

create_log_file(){
	# create the log file inside the choosen directory
	mkdir -pv "${LOG_DIR%\/*}"
	touch "$LOG_DIR"
}

get_last_log_event(){
	# get last status event and timestamp of the given project
	grep "$PROJECT" "$LOG_DIR" | \
		grep "$1" | \
		tail -1 | \
		cut -d " " -f 1-2
}

is_recent(){
	# Check if the first argument is most recent than the second argument
	if [[ "$1" -lt "$2" ]]; then
		echo 1;
	else
		echo 0;
	fi
}

check_status(){
	# check if given project status has already been proccessed
	if [ ! -f "$LOG_DIR" ]; then
		# if file does not exists, then
		create_log_file
	fi

	last_record=$(grep "$PROJECT" "$LOG_DIR")
	
	last_start=$(get_last_log_event "START")
	last_start=$(date -d "$last_start" +%s)

	last_end=$(get_last_log_event "END")
	last_end=$(date -d "$last_end" +%s)

	last_pause=$(get_last_log_event "PAUSE")
	last_pause=$(date -d "$last_pause" +%s)

	last_resume=$(get_last_log_event "RESUME")
	last_resume=$(date -d "$last_resume" +%s)
	
	if [ ! -z "$last_record" ];then
		# check if each status occurred before it's counter part
		has_started_after_a_end=$(is_recent "$last_end" "$last_start")
		has_ended_after_a_start=$(is_recent "$last_start" "$last_end")
		has_paused_after_a_resume=$(is_recent "$last_resume" "$last_pause")

		case "$STATUS" in
			START) # User chooses to start a project
				if [ "$has_started_after_a_end" == 1 ]; then
					echo "Project [$PROJECT] already is marked as [$STATUS]"
					exit 1
				fi
				;;
			END) # User chooses to end a project
				if [ "$has_paused_after_a_resume" == 1 ]; then
					echo "Project [$PROJECT] is PAUSED. RESUME before END"
					exit 1
				fi

				if [ "$has_ended_after_a_start" == "1" ]; then
					echo "Project [$PROJECT] is marked as [$STATUS] already "
					exit 1
				fi
				;;
			PAUSE) # User chooses to Pause a project
				if [ "$has_paused_after_a_resume" == "1" ]; then
					echo "Project [$PROJECT] is marked as [$STATUS] already"
					exit 1
				fi
				;;
			RESUME) # User chooses to Resume a project
				if [ "$has_paused_after_a_resume"  == "0"  ]; then
					echo "Project [$PROJECT] is marked as [$STATUS] already "
					exit 1
				fi
				;;
			esac

	elif [ "$STATUS" != "START" ]; then
		echo "Can't mark status [$STATUS] because the log is empty"
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
				if [[ "${OPTARG,,}" != "start" ]] &&
					[[ "${OPTARG,,}" != "end" ]] &&
					[[ "${OPTARG,,}" != "resume" ]] &&
					[[ "${OPTARG,,}" != "pause" ]]; then
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
	shift "$((OPTIND-1))"				

	EVENT_MESSAGE="$*"							

	savelog "$EVENT_MESSAGE"					
}

main "$@"
