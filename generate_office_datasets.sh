#!/bin/bash

# ./generate_office_datasets.sh /datasets/replica_origin /workspaces/src/Replica-Dataset/datasets /datasets/replica_small /datasets/replica_small

# Check if exactly 4 arguments are provided
if [ "$#" -ne 4 ]; then
  echo "Error: You must provide exactly 4 arguments."
  echo "Usage: ./generate_office_datasets.sh <traj_base_dir> <replica_data_dir> <images_dest_dir> <config_dest_dir>"
  exit 1
fi

# Define width and height
width=800
height=600
focal_lengths=(300 350 400 450 500 550 600 650 700 750 800 850)
# focal_lengths=(300)

traj_base_dir=$1
replica_data_dir=$2
images_dest_dir=$3
config_dest_dir=$4


# focal_changes="(100,400)(1500,300)(1800,400)"
focal_changes="-1"
calib_post_str=""
selfcalib_frame_id="-1"
selfcalib_gt_fx="-1"

# Loop through office directories from office0 to office4
for ((i = 2; i <= 2; i++)); do
  # Iterate over each focal length
  for focal_length in "${focal_lengths[@]}"; do
    echo "Processing office${i} with focal length ${focal_length}"

    # Navigate to the ReplicaSDK build directory
    if ! cd /workspaces/src/Replica-Dataset/build/ReplicaSDK; then
      echo "Failed to change directory to ReplicaSDK"
      continue # Skip to next iteration of the office loop
    fi

    office_data_dir="${replica_data_dir}/office_${i}"

    traj_file="${traj_base_dir}/office${i}/traj.txt"
    mesh_file="${office_data_dir}/mesh.ply"
    textures="${office_data_dir}/textures"
    sur_file="${office_data_dir}/glass.sur"
    
    # Run the ReplicaRendererCustom application
    ./ReplicaRendererCustom $width $height $focal_length ${focal_changes} ${traj_file} ${mesh_file} ${textures} ${sur_file}
    # Create results directory, incorporating width, height, and focal length in the folder name
    dataset_path="${images_dest_dir}/office${i}_${width}x${height}_f${focal_length}${calib_post_str}"
    result_path="${dataset_path}/results"
    mkdir -p "${result_path}"
    mv *.jpg "${result_path}"
    mv *.png "${result_path}"
    # mv intrinsics.txt "${dataset_path}/"
    cp ${traj_file} "${dataset_path}/traj.txt"

    inherit_from="/workspaces/src/MonoGS_dev/configs/mono/replica_small/base_config.yaml"
    fx=${focal_length}
    fy=${focal_length}

    yaml_file_path="${config_dest_dir}/office${i}_${width}x${height}_f${focal_length}${calib_post_str}.yaml"

    cd /workspaces/src/Replica-Dataset
    if [ "${selfcalib_frame_id}" == "-1" ]; then
      python gen_slam_config.py --inherit_from ${inherit_from} --dataset_path ${dataset_path} --width ${width} --height ${height} --fx ${fx} --fy ${fy} --yaml_file_path ${yaml_file_path}
    else
      python gen_slam_config.py --inherit_from ${inherit_from} --dataset_path ${dataset_path} --width ${width} --height ${height} --fx ${fx} --fy ${fy} --yaml_file_path ${yaml_file_path} --selfcalib_frame_id ${selfcalib_frame_id} --selfcalib_gt_fx ${selfcalib_gt_fx}
    fi

    echo "Completed processing for office${i} with focal length ${focal_length} ${calib_post_str}"

  done
done
