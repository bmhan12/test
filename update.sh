#!/bin/bash -l

set -v 

exit_code=0

# Update README header
today_date="$(date +"%Y-%m-%d %H%M")"
curr_date="$(date +"%m-%d-%y_%H%M")"
commit_hash=$(cd .. && git log -1 --format="%h")

> README.md
echo \#\#\# Date and Time of Test: ${today_date} >> README.md
echo \#\#\# Git Commit Hash: ${commit_hash} >> README.md
echo "System | Configuration Status | Build Status | Unit Test Status | Integrated Test Status" >> README.md
echo "--- | --- | --- | --- | ---" >> README.md

# Determine exit codes and update README entry for each system
for system in quartz lassen; do
  
  # Remove previous output files
  git rm -r --cache ${system}*/
  rm -rf ${system}*/

  # Copy over new output files
  cp -R ../${system} .

  # Remove any large files
  (cd ${system} && find . -size +25M -delete)

  # Add files to git
  git add ${system}

  # Determine if each step succeeded or failed
  if find . -name "*${system}*" -a -name "*configure*" -a -name "*SUCCESS*" | grep .; then config_code=0; else config_code=1; fi
  if find . -name "*${system}*" -a -name "*build*" -a -name "*SUCCESS*" | grep .; then build_code=0; else build_code=1; fi
  if find . -name "*${system}*" -a -name "*unit_test*" -a -name "*SUCCESS*" | grep .; then unit_test_code=0; else unit_test_code=1; fi
  if find . -name "*${system}*" -a -name "*integrated_test*" -a -name "*SUCCESS*" | grep .; then integrated_test_code=0; else integrated_test_code=1; fi

  (( exit_code |= config_code | build_code | unit_test_code | integrated_test_code ))

  if [ $config_code -ne 0 ]; then config_status=FAILURE ; else config_status=SUCCESS; fi
  if [ $build_code -ne 0 ]; then build_status=FAILURE ; else build_status=SUCCESS; fi
  if [ $unit_test_code -ne 0 ]; then unit_test_status=FAILURE ; else unit_test_status=SUCCESS; fi
  if [ $integrated_test_code -ne 0 ]; then integrated_test_status=FAILURE; else integrated_test_status=SUCCESS; fi

  config_log=${system}_configure
  build_log=${system}_build
  unit_test_log=${system}_unit_test
  integrated_test_log=${system}_integrated_test

  # Displays success/failure for each step, with last successful commit on failure
  declare -a codes=( $config_code $build_code $unit_test_code $integrated_test_code )
  declare -a statuses=( ${config_log} ${build_log} ${unit_test_log} ${integrated_test_log} )
  declare -a status_messages=( "" "" "" "" )

  for ((i=0;i<4;++i)); do
      last_commit_cmd="awk '/${statuses[i]}/ {print \$2}' last_passed.txt"
      last_commit=$(eval $last_commit_cmd)

      if [ ${codes[i]} -eq 0 ] ; then
        sed -i "/^ *${statuses[i]} / s/${last_commit}/${commit_hash}/" last_passed.txt
      else
        status_messages[i]="($last_commit last passing)" 
      fi
  done

  echo "$system | $config_status ${status_messages[0]} | $build_status ${status_messages[1]} | $unit_test_status ${status_messages[2]} | $integrated_test_status ${status_messages[3]}" >> README.md

done

# Push/Amend rest of changes to github
git add README.md
git add last_passed.txt
git commit -m "Date: ${curr_date} ; Git Commit: ${commit_hash}"
git push

# Cleanup untracked files and test files
git clean -d -f

if [ $exit_code -eq 0 ]; then
    exit 0
else
    exit 1
fi
