KW_LIB_DIR='src'
. "${KW_LIB_DIR}/lib/kw_include.sh" --source-only
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gA options_values

function profiler_main() {
	local list_of_csv_filepaths

	parse_profiler_options "$@"
	if [[ "$?" != 0 ]]; then
		complain "Invalid option: ${options_values['ERROR']}"
		profiler_help
		return 22 # EINVAL
	fi

	list_of_csv_filepaths=$(find "${options_values['TARGET_DIRECTORY']}" -name '*.csv')

	if [[ -n "${options_values['FULL']}" ]]; then
		declare -ga full_profile
		process_csv_files "$list_of_csv_filepaths" 'full'
		display_full_profile
	fi

	if [[ -n "${options_values['SUMMARY']}" ]]; then
		declare -gA summary
		declare -ga functions_stack
		process_csv_files "$list_of_csv_filepaths" 'summary'
		display_summary
	fi
}

# This function processes a set of CSV files and sets data representing a type of
# execution profile. It assumes that the CSV files were generated by kw tracing
# and follow the filename pattern `<thread_number>.csv`, in which the lower the
# number, the earlier the thread was created (number 0 is the main thread).
#
# @list_of_csv_filepaths: String containing all CSV filepaths separated by newline
# @type_of_profile: String defining type of profile to be processed
function process_csv_files() {
	local list_of_csv_filepaths="$1"
	local type_of_profile="$2"
	local timestamp_difference
	local target_function
	local current_summary
	local timestamp_field
	local last_timestamp
	local function_field
	local thread_number
	local action_field
	local indentation
	local stack_index

	type_of_profile="${type_of_profile:-'full'}"

	while IFS= read -r csv_filepath; do
		thread_number=$(basename "$csv_filepath" | sed -e 's/\.csv//')
		stack_index=-1

		while IFS=$'\n' read -r line; do
			action_field=$(printf '%s' "$line" | cut --delimiter=',' -f1)
			function_field=$(printf '%s' "$line" | cut --delimiter=',' -f2)
			timestamp_field=$(printf '%s' "$line" | cut --delimiter=',' -f3)

			if [[ "$type_of_profile" == 'full' && -n "$last_timestamp" ]]; then
				timestamp_difference="$((timestamp_field - last_timestamp))"
				full_profile["$thread_number"]+="${indentation}$(bc <<<"scale=3; ${timestamp_difference} / (10^6)") milliseconds"$'\n'
			elif [[ "$type_of_profile" == 'summary' && "$stack_index" != -1 ]]; then
				timestamp_difference="$((timestamp_field - last_timestamp))"
				target_function="${functions_stack["$stack_index"]}"
				current_summary="${summary["$target_function"]}"
				summary["$target_function"]="$((current_summary + timestamp_difference))"
			fi

			if [[ "$action_field" == 'entry' ]]; then
				case "$type_of_profile" in
				'full')
					full_profile["$thread_number"]+="${indentation}--> ${function_field}"$'\n'
					indentation+='  '
					;;
				'summary')
					functions_stack["$((++stack_index))"]="$function_field"
					;;
				esac
			elif [[ "$action_field" == 'return' ]]; then
				case "$type_of_profile" in
				'full')
					indentation="${indentation::-2}"
					full_profile["$thread_number"]+="${indentation}<-- ${function_field}"$'\n'
					;;
				'summary')
					((stack_index--))
					;;
				esac
			else
				case "$type_of_profile" in
				'full')
					full_profile["$thread_number"]+='<'
					for i in $(seq 1 "${#indentation}"); do
						full_profile["$thread_number"]+='-'
					done
					full_profile["$thread_number"]+=" ${function_field}"$'\n'
					;;
				'summary')
					stack_index=-1
					;;
				esac
			fi

			last_timestamp="$timestamp_field"
		done <"$csv_filepath"

		last_timestamp=''
		indentation=''
	done <<<"$list_of_csv_filepaths"
}

# This function outputs the full execution profile processed in
# `process_csv_files` to the standard output.
#
# Return:
# Outputs each thread execution profile in order of creation.
function display_full_profile() {
	local max_thread_number

	max_thread_number="${#full_profile[@]}"
	((max_thread_number--))

	for thread_number in $(seq 0 "$max_thread_number"); do
		printf 'Thread nr. %s\n###############\n%s\n' "$thread_number" "${full_profile["$thread_number"]}"
	done
}

# This function outputs the summary profile of the execution processed in
# `process_csv_files` to the standard output.
#
# Return:
# Outputs the summary profile of the execution.
function display_summary() {
	for function_name in "${!summary[@]}"; do
		printf '%s,%s\n' "$function_name" "${summary["$function_name"]}"
	done
}

function parse_profiler_options() {
	local long_options='full,summary,help'
	local short_options='h'

	options="$(kw_parse "$short_options" "$long_options" "$@")"

	if [[ "$?" != 0 ]]; then
		options_values['ERROR']="$(kw_parse_get_errors 'kw update' "$short_options" \
			"$long_options" "$@")"
		return 22 # EINVAL
	fi

	# Default options values
	options_values['FULL']=''
	options_values['SUMMARY']=''
	options_values['TARGET_DIRECTORY']=''

	eval "set -- $options"

	while [[ "$#" -gt 0 ]]; do
		case "$1" in
		--full)
			options_values['FULL']=1
			shift
			;;
		--summary)
			options_values['SUMMARY']=1
			shift
			;;
		--help | -h)
			profiler_help
			exit
			;;
		--)
			shift
			;;
		*)
			if [[ ! -d "$1" ]]; then
				options_values['ERROR']="Invalid directory path: $1"
				return 2 # ENOENT
			fi
			options_values['TARGET_DIRECTORY']="$1"
			shift
			;;
		esac
	done

	if [[ -z "${options_values['FULL']}" && -z "${options_values['SUMMARY']}" ]]; then
		options_values['ERROR']='kw profiler needs a "--full" or "--summary" option'
		return 22 # EINVAL
	fi

	if [[ -z "${options_values['TARGET_DIRECTORY']}" ]]; then
		options_values['ERROR']='kw profiler needs path to tracing dir as parameter'
		return 22 # EINVAL
	fi
}

function profiler_help() {
	printf '%s\n' 'profiler.sh: Tool for profiling of kw executions' \
		'  ./scripts/profiler.sh --full <tracing_dir> - Output full profile of execution flow' \
		'  ./scripts/profiler.sh --summary <tracing_dir> - Output summary of time spent in each function'
}

profiler_main "$@"
