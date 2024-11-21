#!/bin/bash
base_dir="/datasets/replica_origin"

# Define width and height
width=800
height=600
focal_lengths=(300 350 400 450 500 550 600 650 700 750 800 850)
# focal_lengths=(500)
# focal_changes="(100,400)(200,300)(300,400)"
focal_changes="-1"

# Loop through office directories from office0 to office4
for ((i = 0; i <= 0; i++)); do
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
    result_path="/datasets/replica_small/office${i}_${width}${height}_${focal_length}/results"
    mkdir -p "${result_path}"
    mv *.jpg "${result_path}"
    mv *.png "${result_path}"
    mv intrinsics.txt "/datasets/replica_small/office${i}_${width}${height}_${focal_length}/"
    cp "${base_dir}/office${i}/traj.txt" "/datasets/replica_small/office${i}_${width}${height}_${focal_length}/traj.txt"

    echo "Completed processing for office${i} with focal length ${focal_length}"
  done
done
