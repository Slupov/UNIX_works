#!/bin/bash
# Bash Menu Script Example

# ------------ START CONSTANTS ------------

ENTER_USRNAMES_CMD='Enter user names'
CHECK_USERS_ACCOUNTS_EXISTENCE_CMD='Check if stored user has account'
LIST_USERS_ACCOUNTS_FILES_CMD='List stored user files'
EXTRACT_USER_FILES_CMD='Extract user files'
PRINT_USERS_FILES_SIZES_CMD='Print user files sizes'
CHANGE_USERS_OWNERSHIP_CMD='Change user ownership to root'
BLOCK_USER_ACCOUNT_CMD='Block user accounts'
QUIT_CMD='Quit'

WORKING_DIRECTORY='/archive'
USERS_STORAGE_FILENAME='users_storage.txt'

# ------------- END CONSTANTS -------------

#DONE
create_working_dir()
{
    # Creates a working directory in root/archive
    if [ ! -d "$WORKING_DIRECTORY" ]; then
        # Control will enter here if $WORKING_DIRECTORY doesn't exist.
        echo "Creating working directory at $WORKING_DIRECTORY"
        sudo mkdir ${WORKING_DIRECTORY}
    fi

    file="$WORKING_DIRECTORY/$USERS_STORAGE_FILENAME"

    if [ ! -f $file ]; then
        # Control will enter here if $file doesn't exist.
        echo "Creating users storage file at $file"
        sudo touch $file
        echo
    fi
}

#DONE
select_user_from_options()
{
    # Assigns the selected username to the first argument passed
    PS3='Please enter your choice (Press Enter to list options again): '
    file="$WORKING_DIRECTORY/$USERS_STORAGE_FILENAME"
    file_lines=`< $file  wc -l`

    options=(`sudo cat $file`)

    select user in ${options[@]}
    do
        case $user in
            ${options[$REPLY - 1]}) 
                echo "YOU CHOSE $REPLY ->> ${options[$REPLY - 1]}"
                eval "$1='${options[$REPLY - 1]}'"
                break;;

            *) echo "$REPLY  ->>> ${options[$REPLY-1]}";;
        esac
    done
}

#DONE
add_users()
{
    while read -p "Please type in an username to add (or 'q' to exit): " \
    NEW_USER && [[ "$NEW_USER" != q ]] ; do
        if is_user_in_file $NEW_USER
        then
            # code if found
            echo -e 'Error! User already exists in storage file \n'
        else
            # code if not found
            save_user_in_file $NEW_USER
        fi
    done

    echo -e "Quitting entering users ...\n\n"
}

#DONE
is_user_in_file()
{
    file="$WORKING_DIRECTORY/$USERS_STORAGE_FILENAME"
    user="$1"

    return $(`grep -Fxq "$user" $file`)
}

#DONE
save_user_in_file()
{
    file="$WORKING_DIRECTORY/$USERS_STORAGE_FILENAME"
    user="$1"

    echo "Saving user $user..."
    echo $user | sudo tee -a $file
}

#DONE
user_account_exists()
{
    user="$1"

    if getent passwd $1 > /dev/null 2>&1; then
        #yes, the user account exists
        return 0
    else
        #no, the user does not exist
        return 1
    fi
}

block_user_account()
{
    select_user_from_options selected_user

    # To lock a users account use the command usermod -L or passwd -l
    sudo usermod -L $selected_user

    # The commands passwd -l and usermod -L are ineffcient when it comes to disable/lock user
    # accounts. These commands will not disallow authentication by SSH public keys 
    sudo chage -E0 $selected_user
    echo "User account $selected_user has been blocked!"
}

save_file_in_user_folder()
{
    # $1 - filename, $2 - account user name
    
    # Makes symbolic links to files of given user into /root/archive/username

    directory="/archive/$2"

    # Check if destination folder is created
    if [ ! -d "$directory" ] 
    then
        echo "Directory $directory does not exist yet. Creating directory..."
        sudo mkdir $directory
    fi

    # Make the symbolic link out of the filename
    # ln -s /path/to/file /path/to/symlink/basename
    f="$(basename -- $1)"
    sym_link_path="$directory/$f"
    # Check if symbolic link already exists
    if [ ! -f $sym_link_path ] 
    then
        sudo ln -s $1 $sym_link_path
    fi
}

traverse_dir() 
{
    # $1 - directory, $2 - account user name, $3 - bool flag (should save files in
    # /root/archive/$2) $4 - change ownership to root

    # check username account validity
    if ! user_account_exists $2; then
        echo "Error!!! User account for $2 does NOT exist! Will not search directories for files..."
        return  
    fi    

    user_has_files=1

    for file in "$1"/*
    do
        if [ ! -d "${file}" ] ; then
            file_size=$(stat -c%s "$1")
            file_owner=$(stat -c '%U' "$1")

            if [ "$2" == "$file_owner" ]; then
                if [ $3 -eq 0 ]; then
                    save_file_in_user_folder $file $2
                fi

                echo "$file is a file with size: $file_size bytes. (owner $file_owner)"
                user_has_files=0
            fi

            if [ $4 -eq 0 ]; then
                sudo chown root $file
                sudo chgrp root $file
                echo "Changing the owner of $file to root"
            fi

        else
            # echo "entering recursion with"
            traverse_dir "${file}" $2 $3 $4
        fi
    done

    if [ $user_has_files -eq 0 ]; then
        echo "Directory $1 total size report: "
    du -h --max-depth=0 $1
    fi
}


main()
{
    # Set PS3 prompt
    PS3=$'\n''Please enter your choice (Press Enter to list options again): '$'\n'
    options=("${ENTER_USRNAMES_CMD}" "${CHECK_USERS_ACCOUNTS_EXISTENCE_CMD}"\
     "${LIST_USERS_ACCOUNTS_FILES_CMD}" "${EXTRACT_USER_FILES_CMD}"\
     "${PRINT_USERS_FILES_SIZES_CMD}" "${CHANGE_USERS_OWNERSHIP_CMD}"\
     "${BLOCK_USER_ACCOUNT_CMD}" "${QUIT_CMD}")

    create_working_dir

    select opt in "${options[@]}"
    do
        case $opt in
            "${ENTER_USRNAMES_CMD}")
                echo "you chose choice 1\n"
                add_users
                ;;
            "${CHECK_USERS_ACCOUNTS_EXISTENCE_CMD}")
                echo "you chose choice 2"
                select_user_from_options selected_user

                if user_account_exists $selected_user; then
                    echo "User account for $selected_user exists!"
                else
                    echo "User account for $selected_user doest NOT exist!"    
                fi    
                ;;
            "${LIST_USERS_ACCOUNTS_FILES_CMD}")
                select_user_from_options selected_user

                if user_account_exists $selected_user; then
                    echo -n "Enter a directory (!!! absolute path !!!) to traverse and list: "
                    read answer
                    traverse_dir $answer $selected_user 1 1
                else
                    echo "User account for $selected_user doest NOT exist!"    
                fi  
                ;;
            "${EXTRACT_USER_FILES_CMD}")
                select_user_from_options selected_user

                if user_account_exists $selected_user; then
                    echo -n "Enter a directory (!!! absolute path !!!) to traverse and save: "
                    read answer
                    traverse_dir $answer $selected_user 0 1
                else
                    echo "User account for $selected_user doest NOT exist!"    
                fi  
                ;;
            "${PRINT_USERS_FILES_SIZES_CMD}")
                select_user_from_options selected_user

                if user_account_exists $selected_user; then
                    user_dir="/archive/$selected_user"

                    # all files are symbolic links, therefore their owner is root
                    traverse_dir $user_dir root 1 1
                else
                    echo "User account for $selected_user doest NOT exist!"    
                fi  
                ;;
            "${CHANGE_USERS_OWNERSHIP_CMD}")
                select_user_from_options selected_user

                if user_account_exists $selected_user; then
                    user_dir="/archive/$selected_user"

                    # all files are symbolic links, therefore their owner is root
                    # By default, chown follows symbolic links and changes the owner of the file pointed to by the symbolic link
                    traverse_dir $user_dir root 1 0
                else
                    echo "User account for $selected_user does NOT exist!"    
                fi  

                ;;
            "${BLOCK_USER_ACCOUNT_CMD}")
                block_user_account
                ;;
            "${QUIT_CMD}")
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

{
    main
} > solution_script_logs.txt