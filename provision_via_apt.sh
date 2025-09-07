#!/bin/bash

set -euo pipefail

tools=("libsdl3-dev")

install_apt_packages_of_executables() {
	local packages=()
	for command in "$@"; do
		if ! command -v "$command" >/dev/null 2>&1; then
			packages+=("$command")
		fi
	done
	if [[ ${#packages[@]} -gt 0 ]]; then
		package_list="${packages[@]}"
		echo "Installing missing APT packages: $package_list ..."
		sudo apt install "${packages[@]}"
	fi
}

install_apt_packages_of_executables "${tools[@]}"

popd > /dev/null
