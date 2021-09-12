#!/bin/bash

mount_shared_dir_daemon() {

([ -z "${SHARE_ROOT}" ] || [ "${SHARE_ROOT}" == "dep" ]) && exit 0

if [ -n "${SHARED_DIR}" ] && ! [ -d "${SHARED_DIR}" ]
then
    mkdir -p "${SHARED_DIR}"
    if_fails $? "[ERR] Could not create mount \
directory ${SHARED_DIR}"
    export SHARED_ROOT_DIR="${SHARED_DIR}"
else
    if [ -z "${SHARED_DIR}" ]
    then
        export SHARED_ROOT_DIR="/vdi"
        mkdir -p "/vdi"
        if_fails $? "[ERR] Could not create mount \
directory /vdi"
    elif "${INTERACTIVE}"
    then
        local res=""
        logger -s "[WAR] Cleaning up ${SHARED_DIR}. Please confirm:"
        read -p "[WAR] Enter uppercase Y for confirmation: " res
        [ "${res}" != "Y" ] && logger -s "[MSG] Exiting."
        export SHARED_ROOT_DIR="${SHARED_DIR}"
    else
        logger -s "[WAR] Cleaning up ${SHARED_DIR} non-interactively."
        export SHARED_ROOT_DIR="${SHARED_DIR}"
    fi
fi

${LOG[*]} "[MSG] Using mountpoint ${SHARED_ROOT_DIR} with permissions ${SHARE_ROOT}"
mountpoint -q  "${SHARED_ROOT_DIR}" && umount "${SHARED_ROOT_DIR}"
rm -rfd "${SHARED_ROOT_DIR}"
if_fails $? "[ERR] Could not remove ${SHARED_ROOT_DIR}"
mkdir -p "${SHARED_ROOT_DIR}"
if_fails $?  \
         "[ERR] Could not recreate ${SHARED_ROOT_DIR}"
logger -s "[MSG] Mountpoint clean."

mount_vdi "${SHARE_ROOT}"

if "${EXITCODE}"
then
    ${LOG[*]} "[MSG] Virtual machine exit code is: " $(cat "${SHARE_ROOT}/res.log")
    unmount_vdi
fi
}
