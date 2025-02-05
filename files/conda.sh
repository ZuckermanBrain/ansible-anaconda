export CONDA_EXE='/usr/local/anaconda/bin/conda'
export _CE_M=''
export _CE_CONDA=''
export CONDA_PYTHON_EXE='/usr/local/anaconda/bin/python'

# Copyright (C) 2012 Anaconda, Inc
# SPDX-License-Identifier: BSD-3-Clause

__add_sys_prefix_to_path() {
    # In dev-mode CONDA_EXE is python.exe and on Windows
    # it is in a different relative location to condabin.
    if [ -n "${_CE_CONDA}" ] && [ -n "${WINDIR+x}" ]; then
        SYSP=$(\dirname "${CONDA_EXE}")
    else
        SYSP=$(\dirname "${CONDA_EXE}")
        SYSP=$(\dirname "${SYSP}")
    fi

    if [ -n "${WINDIR+x}" ]; then
        PATH="${SYSP}/bin:${PATH}"
        PATH="${SYSP}/Scripts:${PATH}"
        PATH="${SYSP}/Library/bin:${PATH}"
        PATH="${SYSP}/Library/usr/bin:${PATH}"
        PATH="${SYSP}/Library/mingw-w64/bin:${PATH}"
        PATH="${SYSP}:${PATH}"
    else
        PATH="${SYSP}/bin:${PATH}"
    fi
    \export PATH
}

__conda_hashr() {
    if [ -n "${ZSH_VERSION:+x}" ]; then
        \rehash
    elif [ -n "${POSH_VERSION:+x}" ]; then
        :  # pass
    else
        \hash -r
    fi
}

__conda_activate() {
    if [ -n "${CONDA_PS1_BACKUP:+x}" ]; then
        # Handle transition from shell activated with conda <= 4.3 to a subsequent activation
        # after conda updated to >= 4.4. See issue #6173.
        PS1="$CONDA_PS1_BACKUP"
        \unset CONDA_PS1_BACKUP
    fi

    \local cmd="$1"
    shift
    \local ask_conda
    CONDA_INTERNAL_OLDPATH="${PATH}"
    __add_sys_prefix_to_path
    ask_conda="$(PS1="$PS1" "$CONDA_EXE" $_CE_M $_CE_CONDA shell.posix "$cmd" "$@")" || \return $?
    rc=$?
    PATH="${CONDA_INTERNAL_OLDPATH}"
    \eval "$ask_conda"
    if [ $rc != 0 ]; then
        \export PATH
    fi
    __conda_hashr
}

__conda_reactivate() {
    \local ask_conda
    CONDA_INTERNAL_OLDPATH="${PATH}"
    __add_sys_prefix_to_path
    ask_conda="$(PS1="$PS1" "$CONDA_EXE" $_CE_M $_CE_CONDA shell.posix reactivate)" || \return $?
    PATH="${CONDA_INTERNAL_OLDPATH}"
    \eval "$ask_conda"
    __conda_hashr
}

__conda_postinstall() {
	if [ ${CONDA_DEFAULT_ENV} != "base" ]; then
		CONDA_USER_EXPORTS=$(dirname ${CONDA_ENVS_DIRS})/exports
		if [ ! -d ${CONDA_USER_EXPORTS} ]; 
		then
			mkdir ${CONDA_USER_EXPORTS}
		fi
		if [ ! -f ~/.gitconfig ]; then
			git config --global user.email "$(whoami)@localhost"
			git config --global user.name "$(whoami)"
		fi
		if [ ! -d ${CONDA_USER_EXPORTS}/.git ] && which git 2>&1 > /dev/null;
		then
			pushd ${CONDA_USER_EXPORTS} > /dev/null
			git init -q
			popd > /dev/null
		fi
		"$CONDA_EXE" env export -n ${CONDA_DEFAULT_ENV} -f ${CONDA_USER_EXPORTS}/${CONDA_DEFAULT_ENV}.yml
		if which git 2>&1 > /dev/null;
		then
			pushd ${CONDA_USER_EXPORTS} > /dev/null
			git add *
			git commit -q -m "${CONDA_DEFAULT_ENV}: ${CONDA_TRANSACTION}"
			popd > /dev/null
		fi
	fi
}

conda() {
    if [ "$#" -lt 1 ]; then
        "$CONDA_EXE" $_CE_M $_CE_CONDA
    else
        \local cmd="$1"
        shift
        case "$cmd" in
            activate|deactivate)
                __conda_activate "$cmd" "$@"
                ;;
            install|update|upgrade|remove|uninstall)
                CONDA_INTERNAL_OLDPATH="${PATH}"
                __add_sys_prefix_to_path
                "$CONDA_EXE" $_CE_M $_CE_CONDA "$cmd" "$@"
                \local t1=$?
                PATH="${CONDA_INTERNAL_OLDPATH}"
                CONDA_TRANSACTION="conda $cmd $@"
                __conda_postinstall
                unset CONDA_TRANSACTION
                if [ $t1 = 0 ]; then
                    __conda_reactivate
                else
                    return $t1
                fi
                ;;
	    # End-users shouldn't be able to undo this custom wrapper
            init)
		echo "conda is already initialized for shell interaction"
                ;;
            *)
                CONDA_INTERNAL_OLDPATH="${PATH}"
                __add_sys_prefix_to_path
                "$CONDA_EXE" $_CE_M $_CE_CONDA "$cmd" "$@"
                \local t1=$?
                PATH="${CONDA_INTERNAL_OLDPATH}"
                return $t1
                ;;
        esac
    fi
}

# Override pip with a bash function to keep track of all pip-based transactions, since conda list --revisions
# doesn't track pip transactions.
pip() {
        if [ ${CONDA_DEFAULT_ENV} != "base" ]; then
                \local cmd="$1"
                shift
                case "$cmd" in
                    install|uninstall)
                        CONDA_TRANSACTION="pip $cmd $@"
                        python -m pip $cmd $@
                        __conda_postinstall
                        unset CONDA_TRANSACTION
                        ;;
                    *)
                        python -m pip $cmd $@
                        ;;
                esac
        else
                echo "pip is not supported for the global conda environment."
                echo "To use pip, please activate one of your own conda environments and then try again."
        fi
}

if [ -z "${CONDA_SHLVL+x}" ]; then
    \export CONDA_SHLVL=0
    # In dev-mode CONDA_EXE is python.exe and on Windows
    # it is in a different relative location to condabin.
    if [ -n "${_CE_CONDA+x}" ] && [ -n "${WINDIR+x}" ]; then
        PATH="$(\dirname "$CONDA_EXE")/condabin${PATH:+":${PATH}"}"
    else
        PATH="$(\dirname "$(\dirname "$CONDA_EXE")")/condabin${PATH:+":${PATH}"}"
    fi
    \export PATH

    # We're not allowing PS1 to be unbound. It must at least be set.
    # However, we're not exporting it, which can cause problems when starting a second shell
    # via a first shell (i.e. starting zsh from bash).
    if [ -z "${PS1+x}" ]; then
        PS1=
    fi
fi

# Ensure that users end up in the base environment
conda activate base
