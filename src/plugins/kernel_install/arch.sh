# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() or install_kernel().
#
# Note: We use this script for ArchLinux and Manjaro

# ArchLinux package names
declare -ga required_packages=(
	'rsync'
	'screen'
	'pv'
	'bzip2'
	'lzip'
	'lzop'
	'zstd'
	'xz'
	'rng-tools'
)

# ArchLinux package manager
declare -g package_manager_cmd='yes | pacman -Syu'

# Some distros might require some basic setup before a package installation or
# configure some service before. For some distros based on ArchLinux, we might
# want to clean some folders and also initialize the pacman keyring.
#
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
function distro_pre_setup() {
	local flag="$1"
	local target="$2"
	local cmd_prefix=''

	# LOCAL_TARGET
	if [[ "$target" == 2 ]]; then
		cmd_prefix='sudo -E '
	fi

	cmd="${cmd_prefix}mv /etc/skel/.screenrc /tmp"
	cmd_manager "$flag" "$cmd"

	# As documented at https://wiki.archlinux.org/title/Pacman/Package_signing
	cmd="${cmd_prefix}pacman-key --init"
	cmd_manager "$flag" "$cmd"

	# Initialize keyring
	cmd="${cmd_prefix}pacman-key --populate"
	cmd_manager "$flag" "$cmd"

	# TODO: Let's make the update something configurable
	cmd="yes | ${cmd_prefix}pacman -Syu"
	cmd_manager "$flag" "$cmd"
}

function generate_arch_temporary_root_file_system() {
	local flag="$1"
	local name="$2"
	local target="$3"
	local bootloader_type="$4"
	local path_prefix="$5"
	local prefered_root_file_system="$6"
	local cmd=''
	local sudo_cmd
	# mkinitcpio still the default on ArchLinux
	local root_file_system_tool='mkinitcpio'

	# If the user specify which rootfs they want to use, let's use it then...
	if [[ -n "$prefered_root_file_system" ]]; then
		if command_exists "$prefered_root_file_system"; then
			root_file_system_tool="$prefered_root_file_system"
		else
			printf 'It looks like that "%s" does not exists\n' "$prefered_root_file_system"
			prefered_root_file_system=''
		fi
	fi

	if [[ -z "$prefered_root_file_system" ]]; then
		if ! command_exists 'mkinitcpio'; then
			if ! command_exists 'dracut'; then
				return 22 # EINVAL
			else
				root_file_system_tool='dracut'
			fi
		fi
	fi

	# We do not support initramfs outside grub scope
	[[ "$bootloader_type" != 'GRUB' ]] && return

	[[ "$target" == 'local' ]] && sudo_cmd='sudo -E '

	# Step 2: Make sure that we are generating a consistent modules.dep and map
	cmd="${sudo_cmd}depmod --all ${name}"
	cmd_manager "$flag" "$cmd"

	# Step 3: Generate the initcpio file
	case "$root_file_system_tool" in
	'mkinitcpio')
		cmd="${sudo_cmd}mkinitcpio --generate /boot/initramfs-${name}.img --kernel ${name}"
		cmd_manager "$flag" "$cmd"
		;;
	'dracut')
		cmd='DRACUT_NO_XATTR=1 dracut --force --persistent-policy by-partuuid '
		cmd+="--hostonly /boot/initramfs-${name}.img ${name}"
		cmd_manager "$flag" "$cmd"
		;;
	esac
}
