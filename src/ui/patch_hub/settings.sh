include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# Screen that shows all types of settings available.
function show_settings_screen() {
	local lore_config_path="${PWD}/.kw/lore.config"
	local -a menu_list_string_array
	local ret

	if [[ ! -f "${lore_config_path}" ]]; then
		lore_config_path="${KW_ETC_DIR}/lore.config"
	fi

	menu_list_string_array=(
		'Register/Unregister Mailing Lists'
		'Save Patches To'
		'Edit Kernel Tree Path'
		'Edit Kernel Tree Target Branch'
		'Edit Patchsets Per Page'
	)
	create_menu_options 'Settings' '' 'menu_list_string_array' '' '' 'Return'
	ret="$?"

	case "$ret" in
	0) # OK
		case "$menu_return_string" in
		0) # Register/Unregister Mailing Lists
			screen_sequence['SHOW_SCREEN']='lore_mailing_lists'
			;;
		1) # Save Patches To
			change_save_patches_to_setting "$lore_config_path"
			screen_sequence['SHOW_SCREEN']='settings'
			;;
		2) # Kernel Tree Path
			change_kernel_tree_path_setting "$lore_config_path"
			screen_sequence['SHOW_SCREEN']='settings'
			;;
		3) # Kernel Tree Target Branch
			change_kernel_tree_branch_setting "$lore_config_path"
			screen_sequence['SHOW_SCREEN']='settings'
			;;
		4) # Patchsets Per Page
			change_patchsets_per_page_setting "$lore_config_path"
			screen_sequence['SHOW_SCREEN']='settings'
			;;
		esac
		;;

	1) # Exit
		handle_exit "$ret"
		;;

	3) # Return
		screen_sequence['SHOW_SCREEN']='dashboard'
		;;
	esac
}

# TODO: Document and test this function
function change_save_patches_to_setting() {
	local lore_config_path="$1"
	local new_value
	local output

	create_directory_selection_screen "${lore_config['save_patches_to']}" 'Select directory where patches will be downloaded'

	case "$?" in
	0) # OK
		new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
		if [[ ! -d "$new_value" ]]; then
			create_message_box 'Error' "${new_value}: No such directory."
		else
			output=$(save_new_lore_config 'save_patches_to' "$new_value" "$lore_config_path")
			if [[ "$?" != 0 ]]; then
				create_message_box 'Error' "Failed to save new value ${new_value} in ${lore_config_path}:"$'\n'"$output"
			fi
			# As we altered the settings, we need to reload lore.config
			load_lore_config
		fi
		;;

	1) # Cancel
		;;

	2) # Help
		create_help_screen 'directory_selection'
		if [[ "$?" != 0 ]]; then
			create_message_box 'Error' 'Cannot create help screen'
		fi
		;;
	esac
}

# TODO: Document and test this function
function change_kernel_tree_path_setting() {
	local lore_config_path="$1"
	local new_value

	create_directory_selection_screen "${lore_config['kernel_tree_path']}" 'Select Linux kernel source tree'

	case "$?" in
	0) # OK
		new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
		if ! is_kernel_root "$new_value"; then
			create_message_box 'Error' "${new_value}: Not a Linux kernel source tree."
		else
			new_value=$(realpath "$new_value")
			save_new_lore_config 'kernel_tree_path' "$new_value" "$lore_config_path"
			# As we changed the kernel tree, we need to reset the target branch and
			# reload lore.config
			save_new_lore_config 'kernel_tree_branch' '' "$lore_config_path"
			load_lore_config
		fi
		;;

	1) # Cancel
		;;

	2) # Help
		create_help_screen 'directory_selection'
		if [[ "$?" != 0 ]]; then
			create_message_box 'Error' 'Cannot create help screen'
		fi
		;;
	esac
}

# TODO: Document and test this function
function change_kernel_tree_branch_setting() {
	local lore_config_path="$1"
	local new_value
	local message_box
	declare -A branches
	local -a check_statuses
	local index=0

	if [[ -z "${lore_config['kernel_tree_path']}" ]]; then
		create_message_box 'Error' 'You need to set "Kernel Tree Path" first.'
	else
		get_git_repository_branches "${lore_config['kernel_tree_path']}" 'branches'
		index=0
		for branch in "${!branches[@]}"; do
			[[ "${lore_config['kernel_tree_branch']}" == "$branch" ]] && check_statuses["$index"]=1
			((index++))
		done

		message_box='Select the target branch of the Linux kernel tree.'$'\n'
		message_box+='When applying patches, this branch will be used as base.'
		create_choice_list_screen 'Kernel Tree Target Branch' "$message_box" 'branches' 'check_statuses'

		case "$?" in
		0) # OK
			new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
			save_new_lore_config 'kernel_tree_branch' "$new_value" "$lore_config_path"

			# As we altered the settings, we need to reload lore.config
			load_lore_config
			;;

		1) # Cancel
			;;
		esac
	fi
}

# This function handles the action of changing the 'patchsets_per_page' setting of lore.
function change_patchsets_per_page_setting() {
	local lore_config_path="$1"
	local message_box
	local new_value
	local -a choices
	local -a check_statuses
	local index=0

	choices=(
		'10 patchsets'
		'30 patchsets'
		'60 patchsets'
	)
	index=0
	for choice in "${choices[@]}"; do
		choice=$(printf '%s' "$choice" | cut --delimiter=' ' -f1)
		[[ "${lore_config['patchsets_per_page']}" == "$choice" ]] && check_statuses["$index"]=1
		((index++))
	done

	message_box='Select the number of patchsets that you want to be displayed when listing patchsets.'$'\n'
	message_box+='Keep in mind that patch-hub fetches patchsets based on this value, so greater values '
	message_box+='may result in slower loading times.'
	create_choice_list_screen 'Patchsets Per Page' "$message_box" 'choices' 'check_statuses'

	case "$?" in
	0) # OK
		new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//' | cut --delimiter=' ' -f1)
		save_new_lore_config 'patchsets_per_page' "$new_value" "$lore_config_path"

		# As we altered the settings, we need to reload lore.config
		load_lore_config
		;;

	1) # Cancel
		;;
	esac
}
