#!/bin/bash

# Global vars
RED='\033[0;31m'
ORANGE='\033[1;31m'
ORANGEU='\033[1;4;31m'
GREEN='\033[1;32m'
ORANGE='\033[1;31m'
NC='\033[0m'
BOLD='\033[1m'

# Help message
aws_usage="
${ORANGEU}NAME${NC}
      ${BOLD}bam${NC} - DEATH TO THE AWS CONSOLE!!!

${ORANGEU}SYNOPSIS${NC}
        bam [options...] <parameters>

      Use the bam command so you dont have to remember all the stupid aws 
      cli parameters to get basic information about instances and go through all
      the man pages, there is so much. Hopefully this makes your life a little 
      easier.

      All the following searches will add wildcards on either side of the string
      implicitly, for example: ${ORANGE}bam -I *instancename*${NC}

      There is no need to add the wildcard yourself this is already done within
      the application. This was just to show how the search is really done.

${ORANGEU}OPTIONS${NC}
      ${ORANGE}-i, --instance-ip${NC} <instance-name>
          Show the ip addresses of the instance you search for. The private ip
          will be shown by default.

      ${ORANGE}-I, --instance-info${NC} <instance-name> [-l]
          Provide the following information of the instance you have specified:

            o AvailabilityZone
            o PrivateIpAddress
            o InstanceId
            o Name 

          Can also provide the '-l' switch to see shutdown instances, without this
          flag it will just show currently running instances.

      ${ORANGE}-t, --instance-type${NC} <instance-type>
          Optionally provide an instance type to narrow down searches further.
          By default if this option isn't selected it will just search all
          instance types.

      ${ORANGE}-a, --asg-count${NC} <asg-name>
          Get the current instance count of an auto-scaling group.

      ${ORANGE}-A, --asg-info${NC} <asg-name>
          Provide the following information of an auto-scaling group:

            o AvailabilityZone
            o HealthStatus
            o InstanceId
            o State

      ${ORANGE}-b, --s3-size${NC} <bucket-name>
          Retrieve the bucket size of specified bucket name.

      ${ORANGE}-s, --ssh${NC} <instance-name> [-u <username>]
          Provide a list of options that are returned from the instance name
          searched. You then select the number of the instance you would like to
          SSH to.

          Can also provide the -u flag and provide a username, if not wanting to
          use your machines default username.

      ${ORANGE}-S, --scp${NC} <instance-name> -S <filename> [-S <dir>] [-m] [-u <username>]
          Provide a list of options that are returned from the instance name
          searched. You then select the number of the instance you would like to
          to SCP files across to, please note you still need correct permissions
          and SSH keys to authorise correctly. Target will default to your home
          directory on the remote server, so only specify for other directories.

          Can also append the -m flag if wanting to download from remote server
          locally. Without flag appended it will default to uploading a file.

          Can also provide the -u flag and provide a username, if not wanting to
          use your machines default username.

      ${ORANGE}-o, --output${NC} <style>
          Formatting style for output:

            o json (default)
            o text
            o table

      ${ORANGE}-h, --help${NC}
          Display help, duh....can't believe this is even required."

# aws functions - the titles speak for themselves
function get_instance_ips () {
  local instance_name=$1
  local format=$2

  aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*${instance_name}*" "Name=instance-state-code,Values=16" \
  --query "Reservations[*].Instances[*].{Name:Tags[?Key=='Name'] | [0].Value,\
  PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress}" --output ${format}
}

function get_instance_info () {
  local instance_name=$1
  local instance_type=$3
  local format=$2

  aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*${instance_name}*" "Name=instance-state-name,Values=${instance_opt:-running}" \
  "Name=instance-type,Values=${instance_type}" --query "Reservations[*].Instances[*]\
  .{Name:Tags[?Key=='Name'] | [0].Value, InstanceId: InstanceId, PrivateIP: PrivateIpAddress, \
  PublicIp: PublicIpAddress, InstanceType:InstanceType, AZ: Placement.AvailabilityZone}" \
  --output ${format}
}

function get_asg_instance_count () {
  aws autoscaling describe-auto-scaling-groups --query \
  'AutoScalingGroups[].{ASG:AutoScalingGroupName,DES:DesiredCapacity,LC:LaunchConfigurationName}' \
  --output text | { grep $1 || true; } | { grep $2 || true; } | awk '{print $4}'
}

function get_asg_lc_name () {
  aws autoscaling describe-auto-scaling-groups --query \
  'AutoScalingGroups[].{ASG:AutoScalingGroupName,LC:LaunchConfigurationName}' \
  --output text | { grep -i $1 || true; } | awk '{print $4}'
}

function get_asg_image_id () {
  aws autoscaling describe-launch-configurations --launch-configuration-names $1 \
  --query 'LaunchConfigurations[]. ImageId' --output text
}

function get_asg_name () {
  local asg_name=$1

  aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[].\
  {ASG:AutoScalingGroupName}' --output text | grep ${1}
}

function get_asg_info () {
  local asg_name=$1
  local format=$2

  aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name "$(get_asg_name ${1})" \
  --query "AutoScalingGroups[].{AutoScalingGroupName:AutoScalingGroupName,MinSize:MinSize,\
  MaxSize:MaxSize,DesiredCapacity:DesiredCapacity,LaunchConfigurationName:LaunchConfigurationName,\
  Instances:Instances[*].{InstanceId:InstanceId,HealthStatus:HealthStatus,State:LifecycleState,\
  AZ:AvailabilityZone}}" --output ${2}
}

function get_bucket_size () {
  local bucket_name=$1
  local format=$2

  now=$(date +%s)
  aws cloudwatch get-metric-statistics --namespace "AWS/S3" \
  --start-time "$(echo "${now} - 86400" | bc)" --end-time "${now}" \
  --metric-name BucketSizeBytes --period 86400 --statistics Sum --unit Bytes \
  --dimensions Name=BucketName,Value=${bucket_name} Name=StorageType,Value=StandardStorage \
  --output ${format}
}

# get the longest string in array and print out length.
function element_length () {
  local array=$1
  array=($@)

  longest=""
  for element in ${array[@]}; do
    if [ ${#element} -gt ${#longest} ]; then
      longest=${element}
    fi
  done

  echo "${#longest}"
}

# create menu with options to select from
function create_menu () {
  if [ ${#name_array} -eq 0 ]; then
    nothing_returned_message
  else
    # create table
    pretty_title
    pretty_line

    printf "| ${BOLD}%-5s${NC}| ${BOLD}%-${name_len}s${NC} | ${BOLD}%-${ip_len}s${NC} |\n" "No." "Servers" "IP Address"
    pretty_line

    # print out instance information
    for ((i=1; i<=${#name_array[@]}; i++)); do
        printf "| ${BOLD}%-5s${NC}| ${BOLD}%-${name_len}s${NC} | ${BOLD}%-${ip_len}s${NC} |\n" "$i" "${name_array[$i-1]}" "${ip_array[$i-1]}"
    done

    pretty_line
    printf "\n"
  fi
}

function pretty_title () {
  total_len=$((${name_len}+${ip_len}+14))
  first_pos=$(((${total_len}/2)-1))
  last_pos=$(((${total_len}-${first_pos})-1))
  for ((i=1; i<=$((${total_len})); i++)); do printf "-"; done && printf "\n"
  printf "|%$((${first_pos}))s%$((${last_pos}))s\n" "${SSHSCP}" "|"
}

function pretty_line () {
  printf "+"
  for ((i=1; i<=6; i++)); do printf "-"; done && printf "+";
  for ((i=1; i<=$((${name_len}+2)); i++)); do printf "-"; done && printf "+"
  for ((i=1; i<=$((${ip_len}+2)); i++)); do printf "-"; done && printf "+\n"
}

# ssh or scp over to selected servers
function select_ssh_scp () {
  file=$3
  path=$4

  create_menu

  while true; do
    prompt="Enter the No. of the instance you would like to ${SSHSCP} or type 0 or <CTRL+C> to quit: "
    read -rp "${prompt}" num
    valid_result ${num} ${#name_array[@]}
  done

  num=$((num-1)) # subtract number, because element in array starts at 0
  printf "Connecting to...\nHost: ${name_array[num]}\nIP: ${ip_array[num]}\n\n"

  # SSH or SCP mode depending on flag enabled
  if [ "${ssh_mode}" ]; then
    ssh -A "${user}"@"${ip_array[num]}"
  elif [[ "${scp_mode}" && "${scp_opt}" ]]; then
    scp "${user}"@"${ip_array[num]}":"${file}" "${path:-.}"
  else
    scp "${file}" "${user}"@"${ip_array[num]}":"${path:-}"
  fi
}

# validation of user input
function valid_result () {
  local choice=$1
  local max=$2

  if ! [ "${choice}" -eq "${choice}" ] 2>/dev/null || [[ "${choice}" -gt "${max}"\
  || -z "${choice}" || "${choice}" =~ ^[[:space:]]*$ ]]; then
    echo -e "${RED}Please only select from available options!${NC}"
    return 1
  elif [[ "${choice}" -eq 0 ]]; then
    echo -e "Exiting..."
    exit 0
  else
    break
  fi
}

# checks for empty arguments
function empty_args () {
  local arg=$1
  local opt=$2

  [[ -z "${arg}" || "${arg}" =~ ^[[:space:]]*$ || "${arg}" == -* ]] \
  && { empty_message "${opt}" >&2; exit 1; }
}

# error messages
function nothing_returned_message () {
  echo -e "${RED}Search results returned nothing (╯°□°）╯︵ ┻━┻ ${NC}"
  exit 1
}

function empty_message () {
  echo -e "b: option -${1:-$OPTARG} requires parameter, try 'bam --help' for more information"
  exit 1
}

function multi_arg_error () {
  echo -e "bam: invalid option combination, try 'bam --help' for more information"
  exit 1
}

function opts_message () {
  echo -e "bam: option -${OPTARG} does not exist, try 'bam --help' for more information"
  exit 1
}

# setting long opts to short opts
for arg in "$@"; do
  shift
  case "${arg}" in
    "--help")           set -- "$@" "-h" ;;
    "--instance-ip")    set -- "$@" "-i" ;;
    "--instance-info")  set -- "$@" "-I" ;;
    "--instance-type")  set -- "$@" "-t" ;;
    "--instace-mode")   set -- "$@" "-l" ;;
    "--asg-count")      set -- "$@" "-a" ;;
    "--asg-info")       set -- "$@" "-A" ;;
    "--s3-size")        set -- "$@" "-b" ;;
    "--ssh")            set -- "$@" "-s" ;;
    "--scp")            set -- "$@" "-S" ;;
    "--scp-mode")       set -- "$@" "-m" ;;
    "--user")           set -- "$@" "-u" ;;
    "--output")         set -- "$@" "-o" ;;
    *)                  set -- "$@" "${arg}"
  esac
done

# default variables
format="table"
instance_type="*"
user="$(id -un)"
scp_opt=""
instance_opt=""
OPTIND=1

# short opts
optspec=":a:A:b:i:t:I:d:s:S:u:mo:hl"
while getopts "${optspec}" opts; do
  case "${opts}" in
    a)
      asg_count="${OPTARG}"
      empty_args "${OPTARG}" "${opts}"
      ;;
    A)
      asg_info="${OPTARG}"
      empty_args "${OPTARG}" "${opts}"
      ;;
    i)
      ip_search="${OPTARG}"
      empty_args "${OPTARG}" "${opts}"
      ;;
    I)
      instance_search="${OPTARG}"
      empty_args "${OPTARG}" "${opts}"
      ;;
    b)
      bucket_search="${OPTARG}"
      empty_args "${OPTARG}" "${opts}"
      ;;
    s)
      [ "${scp_mode}" ] && multi_arg_error
      ssh_mode="${OPTARG}"
      empty_args "${OPTARG}" "${opts}"
      ;;
    S)
      [ "${ssh_mode}" ] && multi_arg_error
      scp_mode+=("${OPTARG}")
      empty_args "${OPTARG}" "${opts}"
      ;;
    o)
      format="${OPTARG}"
      ;;
    u)
      user="${OPTARG}"
      ;;
    m)
      scp_opt="1"
      ;;
    l)
      instance_opt="stopped"
      ;;
    t)
      instance_type="${OPTARG}"
      ;;
    h)
      echo -e "${aws_usage}"
      exit 0
      ;;
    :)
      empty_message
      ;;
    *)
      opts_message
  esac
done
shift $(expr "${OPTIND}" - 1)

# check script for args and exit if null
if [ "${OPTIND}" -eq 1 ]; then
  echo -e "bam: try 'bam --help' for more information"
  exit 1
fi

# get asg instance count
if [ "${asg_count}" ]; then
  get_asg_instance_count $(get_asg_name $1) $(get_asg_lc_name $1)
fi

# get asg info
if [ "${asg_info}" ]; then
  if [ $(get_asg_info "${asg_info}" "${format}" | wc -l) -le 2 ]; then
    nothing_returned_message
  else
    get_asg_info "${asg_info}" "${format}"
  fi
fi

# get instance ips
if [ "${ip_search}" ]; then
  get_instance_ips "${ip_search}" "${format}"
fi

# get instance info
if [ "${instance_search}" ]; then
  if [ $(get_instance_info "${instance_search}" "${format}" "${instance_type}" | wc -l) -le 2 ]; then
    nothing_returned_message
  else
    get_instance_info "${instance_search}" "${format}" "${instance_type}"
  fi
fi

# get instance info
if [ "${bucket_search}" ]; then
  get_bucket_size "${bucket_search}" "${format}"
fi

# ssh mode
if [ "${ssh_mode}" ]; then
  SSHSCP="SSH"
  ip_array=( $(get_instance_info "${ssh_mode}" "text" "${instance_type}" | sort -n | awk '{print $5}') )
  name_array=( $(get_instance_info "${ssh_mode}" "text" "${instance_type}" | sort -n | awk '{print $4}') )
  ip_len=$(element_length ${ip_array[@]})
  name_len=$(element_length ${name_array[@]})
  select_ssh_scp "${ssh_mode}" "${instance_type}"
fi

# scp mode
if [[ "${#scp_mode[@]}" -ge 2 && "${#scp_mode[@]}" -le 3 ]]; then
  SSHSCP="SCP"
  ip_array=( $(get_instance_info "${scp_mode[0]}" "text" "${instance_type}" | sort -n | awk '{print $5}') )
  name_array=( $(get_instance_info "${scp_mode[0]}" "text" "${instance_type}" | sort -n | awk '{print $4}') )
  ip_len=$(element_length ${ip_array[@]})
  name_len=$(element_length ${name_array[@]})
  select_ssh_scp "${scp_mode[0]}" "${instance_type}" "${scp_mode[1]}" "${scp_mode[2]}"
elif [[ "${#scp_mode[@]}" -lt 2 && "${#scp_mode[@]}" -ge 1 ]]; then
  echo "Must specify hostname search and provide <source> to SCP, try 'bam --help' for more information"
fi
