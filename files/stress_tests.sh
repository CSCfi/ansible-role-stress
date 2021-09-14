#!/bin/bash
trap 'clean_up_exit' SIGINT SIGTERM SIGQUIT ERR EXIT

APP_NAME=$(basename "${0}" .sh)

function clean_up_exit() {
  if [ "$(mount | grep -e "^/dev/mapper/${ssd_volume_group}-stress ")" != "" ]; then
    message "Unmounting ${ssd_tests_folder} after trap triggered..."
    umount "${ssd_tests_folder}"
  fi
  if [ -n "${ssd_volume_group}" ]; then
    if [ -e "/dev/mapper/${ssd_volume_group}-stress" ]; then
      message "Removing Logical Volume '/dev/mapper/${ssd_volume_group}-stress' after trap triggered..."
      lvremove "/dev/mapper/${ssd_volume_group}-stress" --force
    fi
  fi
}

function usage() {
  echo "${APP_NAME} \
    [--help|-h|-?] \
    [--stress-ng-duration|-t 'Streess-NG test duration'] \
    [--fio-test-duration|-e 'FIO test duration'] \
    [--hdd-bytes|-d 'Bytes per HDD worker'] \
    [--vm-bytes|-b 'Bytes per VM worker'] \
    [--cpu|-c 'CPU workers'] \
    [--vm|-v 'VM workers'] \
    [--hdd-path|-w 'HDD workers'] \
    [--no-ssd-test|-n] \
    [--ssd-block-size|-k 'Size of the blocks for SSD tests' \
    [--ssd-workers|-o 'Number of workers in SSD tests'
    [--ssd-tests-folder|-f 'Folder to mount and place temporary files.'
    [--ssd-volume-group|-g 'Logical Group where the SSD tests are running. Check that it contained in SSD disks.' \
    [--log-file|-l 'Logs filename']"
}

function check_ssd() {
  # Check if all the disks are SSD (not rotational)
  result=0
  while read -r DISK
  do
    test -e "${DISK}/queue/rotational" && result=$((result + $(cat "${DISK}/queue/rotational")))
  done <<< "$(find /sys/block/ -maxdepth 1)"
  return "${result}"
}

function need_fio_test() {
  # If there is no volume group called vg_instances don't run fio test
  if /usr/sbin/vgdisplay vg_instances; then
    message "There is a volume group called vg_instances"
  else
    message "There is NOT a volume group called vg_instances. Not running FIO test"
    return 1
  fi

  # Check if there are SSD disks behind a RAID controller
  if [ -e /opt/MegaRAID/MegaCli/MegaCli64 ]; then
    message "MegaRAID CLI is installed"
    if [ "$(/opt/MegaRAID/MegaCli/MegaCli64 -PDList -aALL | grep -i solid)" != "" ]; then
      message "MegaRAID CLI reports SSD disks"
      return 0
    fi
  fi

  # Check if disks are SSD (not rotational) according to the kernel
  if check_ssd; then
    message "Kernel reports SSD disks"
    return 0
  fi

  return 1
}
function message() {
  text="${1}"
  if [ "${text}" != "" ]; then
    current_date="$(date +'%Y-%m-%d.%H.%M.%S%z')"
    if [ -n "${log_file}" ]; then
      echo "${current_date} ${text}" >> "${log_file}"
    fi
    echo "${current_date} ${text}"
    logger -t "${APP_NAME}" "${text}"
  fi
}

function run_and_log() {
  temp_log_file=$(mktemp /tmp/tmp.log.XXXXX)
  message "Running: $*"
  # shellcheck disable=SC2048,SC2086
  eval $* >> "${temp_log_file}" 2>&1
  return_code="$?"
  message "Returned code: ${return_code}"
  while read -r log_line
  do
    message "${log_line}"
  done <<< "$(cat "${temp_log_file}")"
  return "${return_code}"
}

log_file="${HOME}/${APP_NAME}_$(date +'%Y-%m-%d.%H.%M.%S%z').log"
vm_method='all'
cpu_method='all'
ssd_block_size="4M"
ssd_workers=64
ssd_tests_folder="/media/stress_test"
ssd_volume_group="vg_instances"
check_ssd=0

need_fio_test && check_ssd=1

while [ $# -gt 0 ]
do
  case "$1" in
    "--help"|"-h"|"-?"|"/?")
      shift
      usage
      exit 0
      ;;
    "--stress-ng-duration"|"-t")
      shift
      stress_ng_duration="${1}"
      shift
      ;;
    "--hdd-bytes"|"-d")
      shift
      bytes_per_hdd_worker="${1}"
      shift
      ;;
    "--vm-bytes"|"-b")
      shift
      bytes_per_vm_worker="${1}"
      shift
      ;;
    "--cpu-method"|"-u")
      shift
      cpu_method="${1}"
      shift
      ;;
    "--cpu"|"-c")
      shift
      cpu_workers="${1}"
      shift
      ;;
    "--vm"|"-v")
      shift
      vm_workers="${1}"
      shift
      ;;
    "--vm-method"|"-m")
      shift
      vm_method="${1}"
      shift
      ;;
    "--hdd"|"-w")
      shift
      hdd_workers="${1}"
      shift
      ;;
    "--log-file"|"-l")
      shift
      log_file="${1}"
      shift
      ;;
    "--no-ssd-test"|"-n")
      shift
      message "Not doing a test in SSD disks"
      check_ssd=0
      ;;
    "--ssd-tests-folder"|"-f")
      shift
      ssd_tests_folder="${1}"
      if [ "${check_ssd}" == "1" ]; then
        if [ ! -d "${ssd_tests_folder}" ]; then
          message "Error! The SSD tests folder is not a directory."
          exit 1
        fi
        if [ ! -w "${ssd_tests_folder}" ]; then
          message "Error! The SSD tests folder is not writable."
          exit 2
        fi
      fi
      shift
      ;;
    "--ssd-volume-group"|"-g")
      shift
      ssd_volume_group="${1}"
      if [ "${check_ssd}" == "1" ]; then
        if [ "$(lvdisplay vg_instances | grep 'LV Name' | awk '{print($3)}' | grep 'instance_pool')" != "instance_pool" ]; then
          message "Error! The Volume Group '${ssd_volume_group}' does NOT exists or does NOT contain a Logical Volume called 'instance_pool'."
          exit 3
        fi
      fi
      shift
      ;;
    "--ssd-workers"|"-o")
      shift
      ssd_workers="${1}"
      shift
      ;;
    "--ssd-block-size"|"-s")
      shift
      ssd_block_size="${1}"
      shift
      ;;
    '--fio-test-duration'|'-e')
      shift
      fio_stress_ng_duration="${1}"
      shift
      ;;
    *)
      message "Warning! Ignoring unknwon parameter '${1}'"
      shift
      ;;
  esac
done

# If all disks are SSD, then run the FIO tests
if [ "${check_ssd}" == "1" ]; then
  message "Will do a FIO test in the SSD disks."
  # Set the space used by workers by using 75% of the total Volume Group
  vg_size=$(( $(/usr/sbin/vgdisplay -c vg_instances| awk 'BEGIN {FS=":"} {print($12)}') ))
  ssd_volume_size="$((vg_size * 75 / 100))"
  ssd_size="$(( ( ssd_volume_size * 1000 * 75 / 100) / (ssd_workers)))"

  message "Creating Logical Volume 'stress' in Volume Group '${ssd_volume_group}' using ${ssd_volume_size} Kbytes..."
  run_and_log lvcreate -V "${ssd_volume_size}K" \
    --thin \
    -n stress \
    "${ssd_volume_group}/instance_pool"
  
  message "Creating XFS filesystem in Logical Volume '/dev/mapper/${ssd_volume_group}-stress'..."
  run_and_log mkfs.xfs "/dev/mapper/${ssd_volume_group}-stress"

  message "Creating folder '${ssd_tests_folder}'..."
  run_and_log mkdir -p "${ssd_tests_folder}"
  
  message "Mounting Logical Volume '/dev/mapper/${ssd_volume_group}-stress' in folder '${ssd_tests_folder}'..."
  run_and_log mount "/dev/mapper/${ssd_volume_group}-stress" "${ssd_tests_folder}"
  
  message "Running FIO stress test ..."
  run_and_log \
    fio --directory="${ssd_tests_folder}" \
    --randrepeat=0 \
    --size="${ssd_size}" \
    --bs="${ssd_block_size}" \
    --direct=1 \
    --numjobs="${ssd_workers}" \
    --name=fiowrite \
    --rw=write \
    --group_reporting \
    --output=/tmp/fiowrite.out \
    --runtime="${fio_stress_ng_duration}" \
    --time_based
  return_code=${?}
  if [ "${return_code}" == "0" ]; then
    message "FIO finished without errors."
  else
    message "Error ${return_code} running FIO. See output after this message."
  fi
  run_and_log cat /tmp/fiowrite.out
  
  message "Unmounting Logical Volume '/dev/mapper/${ssd_volume_group}-stress' in folder '${ssd_tests_folder}'..."
  run_and_log umount "${ssd_tests_folder}"

  message "Removing Logical Volume 'stress' in Volume Group '${ssd_volume_group}'..."
  run_and_log lvremove "/dev/mapper/${ssd_volume_group}-stress" --force
fi

message "Running stress-ng..."
temp_log_file=$(mktemp /tmp/tmp.XXXXXXX.log)
run_and_log stress-ng \
    --timeout "${stress_ng_duration}" \
    --hdd-bytes "${bytes_per_hdd_worker}" \
    --vm-bytes "${bytes_per_vm_worker}" \
    --vm-method "${vm_method}" \
    --cpu-method "${cpu_method}" \
    --cpu "${cpu_workers}" \
    --vm "${vm_workers}" \
    --hdd "${hdd_workers}" \
    --log-file "${temp_log_file}"
run_and_log cat "${temp_log_file}"
sleep 2