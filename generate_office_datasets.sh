#!/bin/bash
base_dir="/datasets/replica_origin"

# Define width and height
width=800
height=600
focal_lengths=(300 350 400 450 500 550 600 650 700 750 800 850)
# focal_lengths=(300)
# focal_changes="(100,400)(1500,300)(1800,400)"
focal_changes="-1"

# Loop through office directories from office0 to office4
for ((i = 0; i <= 4; i++)); do
  # Iterate over each focal length
  for focal_length in "${focal_lengths[@]}"; do
    echo "Processing office${i} with focal length ${focal_length}"

    # Navigate to the ReplicaSDK build directory
    if ! cd /workspaces/src/Replica-Dataset/build/ReplicaSDK; then
      echo "Failed to change directory to ReplicaSDK"
      continue  # Skip to next iteration of the office loop
    fi

    # Run the ReplicaRendererCustom application
    ./ReplicaRendererCustom $width $height $focal_length ${focal_changes} ${base_dir}/office${i}/traj.txt ../../datasets/office_${i}/mesh.ply ../../datasets/office_${i}/textures ../../datasets/office_${i}/glass.sur
    # Create results directory, incorporating width, height, and focal length in the folder name
    dataset_path="/datasets/replica_small/office${i}_${width}x${height}_f${focal_length}"
    result_path="${dataset_path}/results"
    mkdir -p "${result_path}"
    mv *.jpg "${result_path}"
    mv *.png "${result_path}"
    mv intrinsics.txt "/datasets/replica_small/office${i}_${width}${height}_${focal_length}/"
    cp "${base_dir}/office${i}/traj.txt" "${dataset_path}/traj.txt"

    inherit_from="/workspaces/src/MonoGS_dev/configs/mono/replica_small/base_config.yaml"
    fx=${focal_length}
    fy=${focal_length}
    selfcalib_frame_id="-1"
    selfcalib_gt_fx="-1"

    yaml_file_path="${dataset_path}/office${i}_${width}x${height}_f${focal_length}.yaml"
    cd /workspaces/src/Replica-Dataset
    python gen_slam_config.py --inherit_from ${inherit_from} --dataset_path ${dataset_path} --width ${width} --height ${height} --fx ${fx} --fy ${fy} --selfcalib_frame_id ${selfcalib_frame_id} --selfcalib_gt_fx ${selfcalib_gt_fx} --yaml_file_path ${yaml_file_path}

    echo "Completed processing for office${i} with focal length ${focal_length}"
  done
done
