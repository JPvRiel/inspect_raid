# Inspect raid

Bash script that checks linux software raid for the following:

- Any degraded arrays
- Array components with smart errors
- Arrays with mixed SSD and HDD (rotational) components where the HDDs are not set to 'write-mostly' or SSDs are set to write-mostly.

It also helps provide context and understanding about array components dependancy and health using `lsblk` and `smartctl` commands.

While no subsitute for proper mdadm and smartmontools alerting, it helped me investigate/understand array compoistion and configuration mistakes with `writemostly` on a RAID1 that mixed SSD and HDD.

## Usage

Only show warnings

```bash
SHOW_INFO='n' inspect_raid.sh
```

Show array info (default is `SHOW_INFO='y'`)

```bash
inspect_raid.sh
```

## Mixed SSD and HDD arrays and 'write-mostly'

The `writemostly` option can make sense where an HDD is used for redundancy, e.g. in RAID1, next to a single SSD. Since the SSD is typically faster to read, I'd expect that `writemostly` will help avoid having the HDD slow down reads from the array and just leverage the SSD.

## Example info output

Each array gets info output as follows

```text
--------------------------------------------------------------------------------
INFO: # Inspecting virtual block raid device 'md127'

/dev/md127:
        Version : 1.2
  Creation Time : Tue Feb 21 18:01:21 2017
     Raid Level : raid1
     Array Size : 17809408 (16.98 GiB 18.24 GB)
  Used Dev Size : 17809408 (16.98 GiB 18.24 GB)
   Raid Devices : 5
  Total Devices : 5
    Persistence : Superblock is persistent

    Update Time : Sun Nov 11 13:49:46 2018
          State : clean 
 Active Devices : 5
Working Devices : 5
 Failed Devices : 0
  Spare Devices : 0

           Name : biscuit:os_raid1_hybrid  (local to host biscuit)
           UUID : 8602fd17:d885d3ac:c490e8da:8c56cbbf
         Events : 545

    Number   Major   Minor   RaidDevice State
       0       8       19        0      active sync   /dev/sdb3
       6       8       35        1      active sync writemostly   /dev/sdc3
       2       8       51        2      active sync writemostly   /dev/sdd3
       7       8       67        3      active sync writemostly   /dev/sde3
       5       8       83        4      active sync writemostly   /dev/sdf3

INFO: ## Inspecting 5 members for raid device 'md127'

NAME    TYPE  ROTA SCHED RQ-SIZE TRAN     SIZE VENDOR   MODEL            SERIAL
md127   raid1    1           128           17G                           
├─sdf3  part     1 cfq       128           17G                           
│ └─sdf disk     1 cfq       128 sata     3.7T ATA      ST4000VN008-2DR1 ZDH11XD0
├─sde3  part     1 cfq       128           17G                           
│ └─sde disk     1 cfq       128 sata     2.7T ATA      ST3000DM001-1CH1 W1F3LWTP
├─sdd3  part     1 cfq       128           17G                           
│ └─sdd disk     1 cfq       128 sata     2.7T ATA      ST3000DM001-9YN1 S1F0J0T2
├─sdc3  part     1 cfq       128           17G                           
│ └─sdc disk     1 cfq       128 sata     3.7T ATA      ST4000VN008-2DR1 ZGY03PCV
└─sdb3  part     0 cfq       128           17G                           
  └─sdb disk     0 cfq       128 sata   238.5G ATA      SAMSUNG SSD 830  S0XZNEAC602555

INFO: raid member component composition: mixed
INFO: raid member HDD component count: 4/5 (/dev/sdc /dev/sdd /dev/sde /dev/sdf)
INFO: raid member SSD component count: 1/5 (/dev/sdb)
```

And at the end, each array components get smart info output as follows:

```text
--------------------------------------------------------------------------------
INFO: # smart errors and attribute check for raid member device /dev/sdf

smartctl 6.5 2016-01-24 r4214 [x86_64-linux-4.15.0-38-generic] (local build)
Copyright (C) 2002-16, Bruce Allen, Christian Franke, www.smartmontools.org

=== START OF READ SMART DATA SECTION ===
SMART overall-health self-assessment test result: PASSED

SMART Attributes Data Structure revision number: 10
Vendor Specific SMART Attributes with Thresholds:
ID# ATTRIBUTE_NAME          FLAGS    VALUE WORST THRESH FAIL RAW_VALUE
  1 Raw_Read_Error_Rate     POSR--   082   064   044    -    146903898
  3 Spin_Up_Time            PO----   094   093   000    -    0
  4 Start_Stop_Count        -O--CK   100   100   020    -    809
  5 Reallocated_Sector_Ct   PO--CK   100   100   010    -    0
  7 Seek_Error_Rate         POSR--   077   060   045    -    47223702
  9 Power_On_Hours          -O--CK   099   099   000    -    1300 (128 113 0)
 10 Spin_Retry_Count        PO--C-   100   100   097    -    0
 12 Power_Cycle_Count       -O--CK   100   100   020    -    257
184 End-to-End_Error        -O--CK   100   100   099    -    0
187 Reported_Uncorrect      -O--CK   099   099   000    -    1
188 Command_Timeout         -O--CK   100   100   000    -    0
189 High_Fly_Writes         -O-RCK   100   100   000    -    0
190 Airflow_Temperature_Cel -O---K   070   063   040    -    30 (Min/Max 27/30)
191 G-Sense_Error_Rate      -O--CK   100   100   000    -    0
192 Power-Off_Retract_Count -O--CK   100   100   000    -    461
193 Load_Cycle_Count        -O--CK   100   100   000    -    1964
194 Temperature_Celsius     -O---K   030   040   000    -    30 (0 12 0 0 0)
197 Current_Pending_Sector  -O--C-   100   100   000    -    8
198 Offline_Uncorrectable   ----C-   100   100   000    -    8
199 UDMA_CRC_Error_Count    -OSRCK   200   200   000    -    0
240 Head_Flying_Hours       ------   100   253   000    -    893 (136 34 0)
241 Total_LBAs_Written      ------   100   253   000    -    10532036009
242 Total_LBAs_Read         ------   100   253   000    -    9287992634
                            ||||||_ K auto-keep
                            |||||__ C event count
                            ||||___ R error rate
                            |||____ S speed/performance
                            ||_____ O updated online
                            |______ P prefailure warning

SMART Self-test log structure revision number 1
Num  Test_Description    Status                  Remaining  LifeTime(hours)  LBA_of_first_error
# 1  Extended offline    Completed: read failure       90%      1284         -
# 2  Extended offline    Completed: read failure       90%      1283         -
# 3  Extended offline    Completed: read failure       50%      1135         -
# 4  Short offline       Completed without error       00%      1131         -
# 5  Extended offline    Completed: read failure       50%      1119         -
# 6  Extended offline    Completed: read failure       50%      1109         -
# 7  Short offline       Completed without error       00%      1089         -
# 8  Short offline       Completed without error       00%       607         -


WARN: '/dev/sdf' is a member of a raid virtual block device and has one or more SMART errors

Num  Test_Description    Status                  Remaining  LifeTime(hours)  LBA_of_first_error
# 1  Extended offline    Completed: read failure       90%      1284         -
# 2  Extended offline    Completed: read failure       90%      1283         -
# 3  Extended offline    Completed: read failure       50%      1135         -
# 5  Extended offline    Completed: read failure       50%      1119         -
# 6  Extended offline    Completed: read failure       50%      1109         -
```

As per the above, example, while the array appears okay, i.e. not degraded, but one of it's component devices isn't passing extedned offline read tests.

## Bash script learnings

Writing this script helped me learn/impliment:

- Using bash arrays and appending to arrays, e.g. `d_list_all+=("/dev/$d")`
- Using native Bash regex groups to extract substrings into variables (no grep), e.g. `[[ $f =~ .*/dev-(([^/0-9]+)[0-9]?)$ ]]` with `p=${BASH_REMATCH[1]}` and `d=${BASH_REMATCH[2]}` to extract outer and inner groups.
- Using string globbing `*` to simply match substrings anywhere, e.g. `[[ $s == *write_mostly* ]]`
