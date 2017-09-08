#!/bin/bash

set -eu

# setup traceback on error and exit
_showed_traceback=f

function traceback() {
  # Hide the traceback() call.
  local -i start=$(( ${1:-0} + 1 ))
  local -i end=${#BASH_SOURCE[@]}
  local -i i=0
  local -i j=0

  echo "Traceback (last called is first):" 1>&2
  for ((i=${start}; i<${end}; i++)); do
    j=$(( $i - 1 ))
    local function="${FUNCNAME[$i]}"
    local file="${BASH_SOURCE[$i]}"
    local line="${BASH_LINENO[$j]}"
    echo "     ${function}() in ${file}:${line}" 1>&2
  done
}

function on_error() {
  local _ec="$?"
  local _cmd="${BASH_COMMAND:-unknown}"
  traceback 1
  _showed_traceback=t
  echo "The command ${_cmd} exited with exit code ${_ec}." 1>&2
}
trap on_error ERR

function on_exit() {
  local _ec="$?"
  if [[ $_ec != 0 && "${_showed_traceback}" != t ]]; then
    traceback 1
  fi
}
trap on_exit EXIT

# Global vars
RED='\033[0;31m'
ORANGE='\033[1;31m'
ORANGEU='\033[1;4;31m'
ORANGE='\033[1;31m'
NC='\033[0m'
BOLD='\033[1m'
ssh_default="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# Help message
aws_usage="
${ORANGEU}NAME${NC}
      ${BOLD}bam${NC} - DEATH TO THE AWS CONSOLE!!!

${ORANGEU}SYNOPSIS${NC}
        bam [options...] <parameters>

      Use the bam command so you dont have to remember all the complex aws
      cli parameters and switches. Also has a built in ssh and scp function.

      All of the searches are done as wild card searches, so please search like the below to
      get better search results, for example: ${ORANGE}bam --instance-info \"instance*name\"${NC}

${ORANGEU}OPTIONS${NC}
      ${ORANGE}-I, --instance-info${NC} <instance-name> [--instance-type <instance-type>] [--instance-state <state>]
          Provide the following information of the instance you have specified:

            o AvailabilityZone
            o PrivateIpAddress
            o PublicIpAddress
            o InstanceId
            o Name 

          Optionally provide an instance type with ${ORANGE}--instance-type${NC} to narrow
          down searches further. By default if this option isn't selected it will
          just search all instance types.

          Can provide the state of the instance with ${ORANGE}--instance-state${NC} if you
          would like to search for particular instances states.
          Available options are:

            o pending
            o running
            o shutting-down
            o terminated
            o stopped
            o stopping
            o * (to search all instance states)

      ${ORANGE}-s, --ssh${NC} <instance-name> [--username <username>] [--ssh-command <command>] [--ssh-params <parameters>]
          Provide a list of options that are returned from the instance name
          searched. You then select the number of the instance you would like to
          SSH to.

          Can also provide the ${ORANGE}--username${NC} flag and provide a username, if not
          wanting to use your machines default username.

          The ${ORANGE}--ssh-command${NC} flag with a parameter can also be provided to send a
          command to the remote machine.

          ${ORANGE}--ssh-params${NC} can be added for any custom ssh options you
          would like to parse in as well. By default this is set to nothing.

      ${ORANGE}-U, --scp-upload${NC} <instance-name> <filename> [--scp-dir <dir>] [--username <username>]
          Provide a list of options that are returned from the instance name
          searched. You then select the number of the instance you would like to
          to upload files to, please note you still need correct permissions
          and SSH keys to authorise correctly.

          Can also provide the ${ORANGE}--username${NC} flag and provide a username, if not
          wanting to use your machines default username.

      ${ORANGE}-D, --scp-download${NC} <instance-name> <filename> [--scp-dir <dir>] [--username <username>]
          Provide a list of options that are returned from the instance name
          searched. You then select the number of the instance you would like to
          to download files from, please note you still need correct permissions
          and SSH keys to authorise correctly.

          Can also provide the ${ORANGE}--username${NC} flag and provide a username, if not
          wanting to use your machines default username.

      ${ORANGE}-r, --region${NC} <region>
          Setting a manual region to overwrite your ${HOME}/.bam.conf region list.

      ${ORANGE}-o, --output${NC} <style>
          Formatting style for output:

            o json (default)
            o text
            o table

      ${ORANGE}-h, --help${NC}
          Display help."

# aws functions - the titles speak for themselves
function get_instance_info () {
  local instance_name=$1
  local instance_type=$3
  local format=$2
  local region=$4

  aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*${instance_name}*" "Name=instance-state-name,Values=${instance_state}" \
  "Name=instance-type,Values=${instance_type}" --query "Reservations[*].Instances[*]\
  .{Name:Tags[?Key=='Name'] | [0].Value, InstanceId: InstanceId, PrivateIP: PrivateIpAddress, \
  PublicIp: PublicIpAddress, InstanceType:InstanceType, AZ: Placement.AvailabilityZone}" \
  --output "${format}" --region "${region}"
}

# get the longest string in array and print out length
function element_length () {
  local array=$1
  array=($@)

  longest=""
  for element in "${array[@]}"; do
    if [ "${#element}" -gt "${#longest}" ]; then
      longest=${element}
    fi
  done

  echo "${#longest}"
}

# create menu with options to select from
function create_menu () {
  # create table
  pretty_title
  pretty_line
  printf "| ${BOLD}%-5s${NC}| ${BOLD}%-${name_len}s${NC} | ${BOLD}%-${ip_len}s${NC} | ${BOLD}%-${az_len}s${NC} |\n" "No." "Instances" "IP Address" "AZ"
  pretty_line

  # print out instance information
  for ((i=1; i<=${#instance_names[@]}; i++)); do
      printf "| ${BOLD}%-5s${NC}| ${BOLD}%-${name_len}s${NC} | ${BOLD}%-${ip_len}s${NC} | ${BOLD}%-${az_len}s${NC} |\n" "$i" "${instance_names[$i-1]}" "${ips[$i-1]}" "${availability_zone[$i-1]}"
  done
  pretty_line
  printf "\n"
}

function pretty_title () {
  total_len=$((${name_len}+${ip_len}+${az_len}+17))
  first_pos=$(((${total_len}/2)-1))
  last_pos=$(((${total_len}-${first_pos})-1))
  for ((i=1; i<=$((${total_len})); i++)); do printf "-"; done && printf "\n"
  printf "|%$((${first_pos}))s%$((${last_pos}))s\n" "${SSHSCP}" "|"
}

function pretty_line () {
  printf "+"
  for ((i=1; i<=6; i++)); do printf "-"; done && printf "+";
  for ((i=1; i<=$((${name_len}+2)); i++)); do printf "-"; done && printf "+"
  for ((i=1; i<=$((${ip_len}+2)); i++)); do printf "-"; done && printf "+"
  for ((i=1; i<=$((${az_len}+2)); i++)); do printf "-"; done && printf "+\n"
}

function are_you_sure () {
  while true; do
    prompt="Are you sure you want to ${SSHSCP} <yes/no>? "
    read -rp "${prompt}" input
    if [[ ! "${input}" =~ ^(yes|no)$ ]]; then
      echo -e "${RED}Please only type 'yes' or 'no'${NC}"
    else
      clear
      break
    fi
  done
}

function select_ssh () {
  create_menu

  while true; do
    prompt="Enter one of the following valid options:
o No. - To SSH on a single instance
o all - To send SSH command on all listed instances
o 0 or 'quit' - To quit

Enter one of the valid options: "
    read -rp "${prompt}" num
    valid_result "${num}" "${#instance_names[@]}"
  done

  # set index and loop count
  set +u
  index=$((num-1))
  loop_count="${#num[@]}"
  set -u

  are_you_sure

  if [[ "${input}" == "yes" ]]; then
    # if all is selected, index and loop count need to be re-evaluated
    if [[ "${num}" == "all" && "${ssh_command}" ]]; then
      index=0
      loop_count=${#ips[@]}
    fi

    echo -e "\n"
    for ((i=0; i<=${loop_count}-1; i++)) do
      echo -e "+-----------------------------------+"
      printf "|    %-35s    |\n" "Connecting to $(echo -e ${BOLD})${ips[$index+i]}$(echo -e ${NC})"
      echo -e "+-----------------------------------+\n"
      (set +e -x;ssh ${ssh_default} ${ssh_params:-} "${user}"@"${ips[$index+i]}" "${ssh_command:-}")
      echo -e "\n"
    done

    # exit cleanly
    exit 0

  elif [[ "${input}" == "no" ]]; then
    echo -e "Exiting..."
    exit 0
  fi
}

function select_scp () {
  local file=$1
  local path_dir=$2

  create_menu

  while true; do
    prompt="Enter one of the following valid options:
o No. - To SCP file on a single instance
o all - To SCP files to all listed instances
o 0 or 'quit' - To quit

Enter one of the valid options: "
    read -rp "${prompt}" num
    valid_result "${num}" "${#instance_names[@]}"
  done

  # set index and loop count
  set +u
  index=$((num-1))
  loop_count="${#num[@]}"
  set -u

  are_you_sure

  if [[ "${input}" == "yes" ]]; then
    # if all is selected, index and loop count need to be re-evaluated
    if [[ "${num}" == "all" ]]; then
      index=0
      loop_count=${#ips[@]}
    fi

    for ((i=0; i<=${loop_count}-1; i++)) do
      source=${file}
      target=${user}@${ips[$index+i]}:${path_dir:-}

      if [ "${scp_download}" ]; then
        source=${user}@${ips[$index+i]}:${file}
        target=${path_dir:-.}
      fi

      echo -e "+-----------------------------------+"
      printf "|    %-35s    |\n" "Connecting to $(echo -e ${BOLD})${ips[$index+i]}$(echo -e ${NC})"
      echo -e "+-----------------------------------+\n"
      (set +e -x; scp ${ssh_default} "${source}" "${target}")
      echo -e "\n"
    done

    # exit cleanly
    exit 0

  elif [[ "${input}" == "no" ]]; then
    echo -e "Exiting..."
    exit 0
  fi
}

# validation of user input
function valid_result () {
  local choice=$1
  local max=$2

  if [ "${choice}" -eq 0 ] 2>/dev/null || [ "${choice}" == "quit" ]; then
    echo -e "Exiting..."
    exit 0
  elif ! [ "${ssh_command}" ] && [[ "${ssh_mode}" && "${choice}" == "all" ]]; then
    echo -e "${RED}You cannot select 'all' without an accompanied --ssh-command${NC}\n"
    return 0
  elif [[ "${choice}" == "all" ]]; then
    break
  elif ! [ "${choice}" -eq "${choice}" ] 2>/dev/null || \
      [[ "${choice}" -gt "${max}"|| -z "${choice}" || "${choice}" =~ ^[[:space:]]*$ ]]; then
    echo -e "${RED}Please only select from available options!${NC}\n"
    return 0
  else
    break
  fi
}

# checks for empty arguments on short and long opts
function short_empty_args () {
  local arg=$1
  local opt=$2

  set +e
  [[ -z "${arg}" || "${arg}" =~ ^[[:space:]]*$ || "${arg}" == -* ]] \
  && { short_empty_message "${opt}" >&2; exit 1; }
  set -e
}

function long_empty_args () {
  local arg=$1
  local opt=$2

  set +e
  [[ "${arg}" =~ ^[[:space:]]*$ || "${arg}" == --* ]] \
  && { long_empty_message "${opt}" >&2; exit 1; }
  set -e
}

# error messages
function nothing_returned_message () {
  echo -e "${RED}bam: Search results returned nothing (╯°□°）╯︵ ┻━┻ ${NC}"
  exit 1
}

function short_empty_message () {
  echo -e "bam: option -${1:-$OPTARG} requires parameter, try 'bam --help' for more information"
  exit 1
}

function long_empty_message () {
  echo -e "bam: option --${!OPTIND:-$OPTARG} requires parameter, try 'bam --help' for more information"
  exit 1
}

function invalid_opts_error () {
  echo -e "bam: invalid option combination, try 'bam --help' for more information"
  exit 1
}

function short_opts_message () {
  echo -e "bam: option -${OPTARG} does not exist, try 'bam --help' for more information"
  exit 1
}

function long_opts_message () {
  echo -e "bam: option --${OPTARG} does not exist, try 'bam --help' for more information"
  exit 1
}

# check for empty args
if [[ $# -eq 0 || $@ == "--" ]]; then
  echo -e "bam: no options specified, try 'bam --help' for more information"
  exit 1
fi

# default variables
format="table"
region=""
region_list=($(<${HOME}/.bam.conf))
instance_type="*"
user="$(id -un)"
instance_state="running"
OPTIND=1
scp_download=""
scp_upload=""
ssh_check=""
instance_search=""
ssh_mode=""
ssh_command=""
scp_mode=""
scp_instance=""
scp_dir=""

# long opts and short opts (hacked around getopts to get more verbose messages)
optspec=":r:t:I:d:s:D:d:U:c:u:o:hlp:-:"
while getopts "${optspec}" opts; do
  case "${opts}" in
    # long opts
    -)
      case "${OPTARG}" in
          instance-info)
            instance_search="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${instance_search}" "${opts}"
            ;;
          ssh)
            [[ "${scp_download}" || "${scp_upload}" ]] && invalid_opts_error
            ssh_check="1"
            ssh_mode="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${ssh_mode}" "${opts}"
            ;;
          ssh-params)
            ssh_params="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${ssh_params}" "${opts}"
            ;;
          scp-upload)
            [[ "${ssh_check}" || "${scp_download}" ]] && invalid_opts_error
            scp_upload="1"
            scp_instance=$2
            scp_file=$3
            OPTIND=$(($OPTIND+1))
            long_empty_args "${scp_instance}" "${opts}"
            shift
            ;;
          scp-download)
            [[ "${ssh_check}" || "${scp_upload}" ]] && invalid_opts_error
            scp_download="1"
            scp_instance=$2
            scp_file=$3
            OPTIND=$(($OPTIND+1))
            long_empty_args "${scp_instance}" "${opts}"
            shift
            ;;
          scp-dir)
            [ "${ssh_check}" ] && invalid_opts_error
            scp_dir="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${scp_dir}" "${opts}"
            ;;
          ssh-command)
            ssh_command="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${ssh_command}" "${opts}"
            ;;
          region)
            unset region_list
            region_list="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            ;;
          output)
            format="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            ;;
          username)
            user="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            ;;
          instance-state)
            instance_state="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${instance_state}" "${opts}"
            ;;
          instance-type)
            instance_type="${!OPTIND}"
            OPTIND=$(($OPTIND+1))
            long_empty_args "${instance_type}" "${opts}"
            ;;
          help)
            echo -e "${aws_usage}"
            exit 0
            ;;
          :)
            long_empty_message
            ;;
          *)
            long_opts_message
            ;;
      esac;;
    # short opts
    I)
      instance_search="${OPTARG}"
      short_empty_args "${OPTARG}" "${opts}"
      ;;
    s)
      [[ "${scp_download}" || "${scp_upload}" ]] && invalid_opts_error
      ssh_check="1"
      ssh_mode="${OPTARG}"
      short_empty_args "${OPTARG}" "${opts}"
      ;;
    p)
      ssh_params="${OPTARG}"
      short_empty_args "${ssh_params}" "${opts}"
      ;;
    U)
      [[ "${ssh_check}" || "${scp_download}" ]] && invalid_opts_error
      scp_upload="1"
      scp_instance=$2
      scp_file=$3
      short_empty_args "${scp_instance}" "${opts}"
      shift
      ;;
    D)
      [[ "${ssh_check}" || "${scp_upload}" ]] && invalid_opts_error
      scp_download="1"
      scp_instance=$2
      scp_file=$3
      short_empty_args "${scp_instance}" "${opts}"
      shift
      ;;
    d)
      [ "${ssh_check}" ] && invalid_opts_error
      scp_dir="${OPTARG}"
      short_empty_args "${scp_dir}" "${opts}"
      ;;
    c)
      ssh_command="${OPTARG}"
      short_empty_args "${OPTARG}" "${opts}"
      ;;
    o)
      format="${OPTARG}"
      ;;
    r)
      unset region_list
      region_list="${OPTARG}"
      ;;
    u)
      user="${OPTARG}"
      ;;
    l)
      instance_state="${OPTARG}"
      short_empty_args "${OPTARG}" "${opts}"
      ;;
    t)
      instance_type="${OPTARG}"
      short_empty_args "${OPTARG}" "${opts}"
      ;;
    h)
      echo -e "${aws_usage}"
      exit 0
      ;;
    :)
      short_empty_message
      ;;
    *)
      short_opts_message
  esac
done
shift $(expr "${OPTIND}" - 1)

# catch all for any empty options
if [ "${OPTIND}" -eq 1 ]; then
  echo -e "bam: no options specified, try 'bam --help' for more information"
  exit 1
fi

# check if no region has been set
set +u
if [ -z "${region_list}" ]; then
  no_region
fi
set -u

# get instance info
if [ "${instance_search}" ]; then
  echo -e "\n"
  for region in "${region_list[@]}"; do
    echo -e "${BOLD}Results for ${ORANGE}${region}${NC} ${BOLD}below:${NC}\n"
    get_instance_info "${instance_search}" "${format}" "${instance_type}" "${region}"
    echo -e "\n"
  done
  exit 0
fi

# get instance data
if [[ "${ssh_mode}" || "${scp_instance}" ]]; then
  for region in "${region_list[@]}"; do
    instance_info+=($(get_instance_info "${ssh_mode:-${scp_instance}}" "text" "${instance_type}" "${region}" | sort -k4 | tr '\t' '|' | tr ' ' '_'))
  done

  if [ -z "${instance_info}" ]; then
    nothing_returned_message
  fi

  # store elements into an array
  ips=($(echo "${instance_info[@]}" | tr ' ' '\n' | cut -d '|' -f 5))
  instance_names=($(echo "${instance_info[@]}" | tr ' ' '\n' | cut -d '|' -f 4))
  availability_zone=($(echo "${instance_info[@]}" | tr ' ' '\n' | cut -d '|' -f 1))

  ip_len=$(element_length ${ips[@]})
  name_len=$(element_length ${instance_names[@]})
  az_len=$(element_length ${availability_zone[@]})
  az_len=$((az_len+1))
fi

# ssh mode
if [[ "${ssh_mode}" ]]; then
  SSHSCP="SSH"
  select_ssh
fi

# scp mode
if [[ "${scp_instance}" && "${scp_file}" ]]; then
  SSHSCP="SCP"
  select_scp "${scp_file}" "${scp_dir}"
elif [[ -z "${scp_instance}" || -z "${scp_file}" ]]; then
  echo -e "Must specify hostname search and provide <source> to SCP, try 'bam --help' for more information"
  exit 1
fi
