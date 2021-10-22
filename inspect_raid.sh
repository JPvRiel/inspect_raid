#!/usr/bin/env bash

# env switches (too lazy to parse parameters)
show_info=${SHOW_INFO:='n'}

# Term colour escape codes
T_DEFAULT='\e[0m'
T_RED_BOLD='\e[1;31m'
T_YELLOW_BOLD='\e[1;33m'
T_BLUE='\e[0;34m'

function report_info() {
  echo -e "${T_BLUE}INFO:${T_DEFAULT} $*"
}

function report_warning() {
  echo -e "${T_YELLOW_BOLD}WARN:${T_DEFAULT} $*" >&2
}

function report_error(){
  echo -e "${T_RED_BOLD}ERROR:${T_DEFAULT} $*" >&2
}

# Inspect RAID and member devices
d_list_all=()
vd_list=()
for vd in /sys/devices/virtual/block/md*/md; do
  if [[ $show_info == 'y' ]]; then
    echo
  fi
  if [[ $vd =~ ^/sys/devices/virtual/block/(md[0-9]+)/md$ ]]; then
    md="${BASH_REMATCH[1]}"
    vd_list+=("/dev/$md")
    if [[ $show_info == 'y' ]]; then
      echo "--------------------------------------------------------------------------------"
      report_info "# Inspecting virtual block raid device '$md'"
      echo
      sudo mdadm --detail "/dev/$md"
    fi
    if [[ -e "$vd/degraded" && $(cat "$vd/degraded") -gt 0 ]]; then
      echo
      report_warning "'$md' is degraded"
    fi
    d_list=()
    p_list=()
    d_list_rotational=()
    d_list_nonrotational=()
    p_list_writemostly=()
    d_list_composition='unkown'
    d_list_n_rotational=0
    for f in "$vd"/dev-*; do
      if [[ $f =~ .*/dev-(([^/0-9]+)[0-9]?)$ ]]; then
        # 1st match is the outer regex group (device + partition number)
        p=${BASH_REMATCH[1]}
        p_list+=("/dev/$p")
        # 2nd match is the inner regex group (just device)
        d=${BASH_REMATCH[2]}
        d_list+=("/dev/$d")
        # append new devices to overall device list
        if ! [[ ${d_list_all[@]} == *dev/$d* ]]; then
          d_list_all+=("/dev/$d")
        fi
        r=$(cat "/sys/block/$d/queue/rotational")
        if [[ $r != 0 ]]; then 
          d_list_rotational+=("/dev/$d")
        else
          d_list_nonrotational+=("/dev/$d")
        fi
        s=$(cat "$f/state")
        if [[ $s == *write_mostly* ]]; then
          p_list_writemostly+=("/dev/$p")
        fi
      fi
    done
    d_list_n=${#d_list[@]}
    p_list_n=${#p_list[@]}
    d_list_n_rotational=${#d_list_rotational[@]}
    d_list_n_nonrotational=${#d_list_nonrotational[@]}
    # show devices
    if [[ $show_info == 'y' ]]; then
      echo
      report_info "## Inspecting $p_list_n members for raid device '$md'"
      echo
      lsblk -s -o NAME,TYPE,ROTA,SCHED,RQ-SIZE,TRAN,SIZE,VENDOR,MODEL,SERIAL "/dev/$md"
    fi
    # compare SSD vs HDD composition
    d_list_n_rotational_ratio=$(bc -l <<< "$d_list_n_rotational / $d_list_n")
    case $d_list_n_rotational_ratio in
      0)
        d_list_composition='ssd'
      ;;
      1.0*)
        d_list_composition='hdd'
      ;;
      .*)
        d_list_composition='mixed'
      ;;
    esac
    #echo "d_list_n=$d_list_n, d_list_n_rotational=$d_list_n_rotational, d_list_n_rotational_ratio=$d_list_n_rotational_ratio, d_list_composition=$d_list_composition"
    if [[ $show_info == 'y' ]]; then
      echo
      report_info "raid member component composition: $d_list_composition"
    fi
    # If array is has both SSD and HDD devices, warn when HDD devices are not writemostly
    if [[ "$d_list_composition" == 'mixed' ]]; then
      if [[ $show_info == 'y' ]]; then
        report_info "raid member HDD component count: $d_list_n_rotational/$p_list_n (${d_list_rotational[*]})"
        report_info "raid member SSD component count: $d_list_n_nonrotational/$p_list_n (${d_list_nonrotational[*]})"
      fi
      # HDD not writemostly?
      for d in "${d_list_rotational[@]}"; do
        if ! [[ ${p_list_writemostly[@]} == *$d* ]]; then
          echo
          report_warning "'$d' HDD (rotational) IS NOT set to writemoslty"
          echo "'$d' is used by '$md' which mixes SSD and HDD"
          echo "HDD devices: ${d_list_rotational[*]}"
          echo "devices/partitions set to writemostly were: ${p_list_writemostly[*]}"
        fi
      done
      # SSD writemostly?
      for d in "${d_list_nonrotational[@]}"; do
        if [[ ${p_list_writemostly[@]} == *$d* ]]; then
          echo
          report_warning "'$d' SSD (non rotational) IS set to writemoslty"
          echo "'$d' is used by '$md' which mixes SSD and HDD"
          echo "SSD devices: ${d_list_nonrotational[*]}"
          echo "devices/partitions set to writemostly were: ${p_list_writemostly[*]}"
        fi
      done
    fi
  else
    echo
    report_error "'$vd' did not match expected regex"
  fi
done

# look for smart errors
echo
for d in "${d_list_all[@]}"; do
  if [[ $show_info == 'y' ]]; then
    echo "--------------------------------------------------------------------------------"
    report_info "# smart errors and attribute check for raid member device $d"
    echo
    sudo smartctl --health --attributes --log=selftest --format=brief "$d"
  fi
  if ! sudo smartctl --health --attributes --log=selftest --quietmode=silent "$d"; then
      echo
      report_warning "'$d' is a member of a raid virtual block device and has one or more SMART errors"
      echo
      sudo smartctl --health --attributes --log=selftest --quietmode=errorsonly --format=brief "$d"
  fi
done

exit

# set writemostly for devices that are rotational (assumes root)
#for f in /sys/block/md127/md/dev-sd{c,d,e,f}3/state; do
    #echo echo writemostly > "$f"
#done
# remove writemostly for SSD
#echo echo -writemostly > /sys/block/md127/md/dev-sdb3/state