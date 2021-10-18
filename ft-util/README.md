# ft-util
Library of Scripts for Futur-Tech Devs

## Install

    cd <your_repo>

    mkdir ft-util && cd ft-util && wget https://raw.githubusercontent.com/Futur-Tech/ft-util/main/deploy_ft_util && chmod +x deploy_ft_util && ./deploy_ft_util

You can edit which script you need by editing deploy_ft_util

## Update script

    ./deploy_ft_util

# Scripts Description
## ft_util_bak-cleaner

This script will delete .BAK file older than 7 days.

> Script dependency:
> - ft_util_log

## ft_util_conf-update

Config File Updater Script

Note: comments on the same lines of a variable set in a target conf will be kept inside the target file

> Script dependency:
> - ft_util_log
> - ft_util_bak-cleaner

## ft_util_file-deploy

File deployement... todo: readme

Option **NO-BACKUP** can be specified to avoid creating a backup

> Script dependency:
> - ft_util_log
> - ft_util_bak-cleaner

## ft_util_inc_var

Basic vars used accross Futur-Tech scripts. Also declare log.

> Script dependency:
> - ft_util_log

## ft_util_log

Logging script

- the $LOG_DEBUG should be declared in the script which use ft_util_log in order to log debug message

- the $LOG_FILE can also contains several path separated with space

## ft_util_pkg

This script for 2 purposes:

1. check if a packet is installed
1. install packet needed if not installed

### Exemples
    ft-util/ft_util_pkg "pkg1"
    # (Return 0 if pkg1 is installed)

    ft-util/ft_util_pkg -c
    # Run apt update

    ft-util/ft_util_pkg -i "pkg1" "pkg2" "pkg3" "pkg4"
    # Install "pkg1" "pkg2" "pkg3" "pkg4".
    # Return number of packet not installed.

    ft-util/ft_util_pkg -c -i "pkg1" "pkg2" "pkg3" "pkg4"
    # Same than the previous exemple but with apt update before.

> Script dependency:
> - ft_util_log


## ft_util_sshauth

Will compile the authorized_keys files from files in authorized_keys.d/
If authorized_keys.d/ doesnt exist, the script will create it and exit

    ft-util/ft_util_sshauth "<user>" "<usergroup>"

Note: if usergroup=user then you can omit it.

> Script dependency:
> - ft_util_log

*Credit: https://rumkin.medium.com/how-to-organize-ssh-keys-access-7b822db312a8*

## ft_util_sshkey

Will generate ssh key for user and apply proper permission to .ssh folder.

    ft-util/ft_util_sshkey "user" "usergroup"

Note: if usergroup=user then you can omit it.

> Script dependency:
> - ft_util_log
