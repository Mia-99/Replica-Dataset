#!/bin/bash
# usage:
# ./generate_office_datasets.sh /workspaces/src/Replica-Dataset/datasets /datasets/replica_small /datasets/replica_origin .

# Check arguments
if [ "$#" -le 1 ]; then
  echo "Error: Only $# arguments provided, at least 2 expected."
  echo "Usage: ./generate_office_datasets.sh <replica_data_dir> <images_dest_dir> <traj_base_dir>[optional] <config_dest_dir>[optional]"
  exit 1
fi

# Define width and height
width=800
height=600
# focal_lengths=(300 350 400 450 500 550 600 650 700 750 800 850)
focal_lengths=(400)

replica_data_dir=$1
images_dest_dir=$2


focal_change_id=(100 200 300 400 500)
focal_change_fx=(250 200 500 600 800)
# focal_change_id=()
# focal_change_fx=()

# Loop through office directories from office0 to office4
for ((i = 0; i <= 0; i++)); do
  # Iterate over each focal length
  for focal_length in "${focal_lengths[@]}"; do
    echo "Processing office${i} with focal length ${focal_length}"

    calib_post_str=""
    selfcalib_frame_id=""
    selfcalib_gt_fx=""
    focal_changes=""

    cur_f=${focal_length}
    arraylength=${#focal_change_id[@]}
    echo "Times of focal length changes: ${arraylength}"
    for (( jj=0; jj<${arraylength}; jj++ )); do
      idx=${focal_change_id[jj]}
      new_f=${focal_change_fx[jj]}
      
      a="${idx}u"
      if (( new_f < cur_f )); then
        a="${idx}d"
      fi
      calib_post_str="${calib_post_str}${a}"

      if (( jj == 0 )); then
        selfcalib_frame_id="${idx}"
        selfcalib_gt_fx="${new_f}"
        focal_changes="(${idx}, ${new_f})"
      else
        selfcalib_frame_id="${selfcalib_frame_id}, ${idx}"
        selfcalib_gt_fx="${selfcalib_gt_fx}, ${new_f}"
        focal_changes="${focal_changes}(${idx}, ${new_f})"
      fi

      cur_f=${new_f}   
    done

    if [ "${calib_post_str}" != "" ]; then
      calib_post_str="_calib${calib_post_str}"
    fi
    echo "calib_post_str     =${calib_post_str}"
    echo "selfcalib_frame_id =${selfcalib_frame_id}"
    echo "selfcalib_gt_fx    =${selfcalib_gt_fx}"
    echo "focal_changes      =${focal_changes}"
    # Navigate to the ReplicaSDK build directory
    # if ! cd /workspaces/src/Replica-Dataset/build/ReplicaSDK; then
    #   echo "Failed to change directory to ReplicaSDK"
    #   continue # Skip to next iteration of the office loop
    # fi

    office_data_dir="${replica_data_dir}/office_${i}"

    mesh_file="${office_data_dir}/mesh.ply"
    textures="${office_data_dir}/textures"
    sur_file="${office_data_dir}/glass.sur"    
    traj_file="${office_data_dir}/traj.txt"

    if [ "$#" -eq 3 ] || [ "$#" -eq 4 ]; then
      traj_base_dir=$3
      traj_file="${traj_base_dir}/office${i}/traj.txt"
      echo "traj_file=${traj_file}"
    fi
    if [ ! -f ${traj_file} ]; then
      echo "Error: Trajectory file not found!"
      echo "Usage: ./generate_office_datasets.sh <replica_data_dir> <images_dest_dir> <traj_base_dir>[optional] <config_dest_dir>[optional]"
      exit 1
    fi

    # Run the ReplicaRendererCustom application
    ./build/ReplicaSDK/ReplicaRendererCustom $width $height $focal_length "${focal_changes}" ${traj_file} ${mesh_file} ${textures} ${sur_file}
    # Create results directory, incorporating width, height, and focal length in the folder name
    dataset_path="${images_dest_dir}/office${i}_${width}x${height}_f${focal_length}${calib_post_str}"
    result_path="${dataset_path}/results"
    mkdir -p "${result_path}"
    mv *.jpg "${result_path}"
    mv *.png "${result_path}"
    cp ${traj_file} "${dataset_path}/traj.txt"

    inherit_from="configs/mono/replica_small/base_config.yaml"
    fx=${focal_length}
    fy=${focal_length}

    yaml_file_path="${dataset_path}/office${i}_${width}x${height}_f${focal_length}${calib_post_str}.yaml"
    echo "yaml_file_path    =${yaml_file_path}"
    cd /workspaces/src/Replica-Dataset
    if [ "${selfcalib_frame_id}" == "-1" ]; then
      python gen_slam_config.py --inherit_from "${inherit_from}" --dataset_path "${dataset_path}" --width ${width} --height ${height} --fx ${fx} --fy ${fy} --yaml_file_path "${yaml_file_path}"
    else
      python gen_slam_config.py --inherit_from "${inherit_from}" --dataset_path "${dataset_path}" --width ${width} --height ${height} --fx ${fx} --fy ${fy} --yaml_file_path "${yaml_file_path}" --selfcalib_frame_id "${selfcalib_frame_id}" --selfcalib_gt_fx "${selfcalib_gt_fx}"
    fi

    if [ "$#" -eq 4 ]; then
      config_dest_dir=$4
      cp ${yaml_file_path} ${config_dest_dir}
    fi

    echo "Completed processing for office${i} with focal length ${focal_length} with calibration str ${calib_post_str}"

  done
done
