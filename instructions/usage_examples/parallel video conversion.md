# Parallel video conversion
In this example we assume we need to convert a bunch of video files to the same "format" or parameters.

Let's create in `/storage/shared/video_conversion` location 4 folders:
```
cd /storage/shared
mkdir ./video_conversion
cd ./video_conversion
mkdir input output assigned processed
```
Where:
- `input`: a folder to put all files we want to convert
- `output`: a folder, where all conversion results will be placed
- `assigned` : a folder, where we will move all files, which already been assigned.
  Thus, same files will be not assigned again for tasks if running scripts is run multiple times
- `processed` : a folder, were we will move all sources video files if conversion process finished succesfuly

Now, move all files you want to convert to folder `/storage/shared/video_conversion/input`

# Usual way of conversion with using of only one computer

This example only demonstrates, how conversion can be with a traditional way without SLURM and cluster

Create a script `convert_all_inputs.sh` in `/storage/shares/video_conversion`:
```
#!/bin/bash

# Specify the list of extension of video files to look for
declare -a video_extensions=(mkv webm avi mp4 mov)

# Letting script know where
input_folder="input"
output_folder="output"

current_folder=$(dirname $(realpath ${0}))

input_folder="$current_folder"/"$input_folder"
output_folder="$current_folder"/"$output_folder"

h265=(-c:v libx265 -crf 28 -c:a libopus)

# assemble the filter for search video files in inputs folder
filter='.*\.('$( IFS='|'; echo "${video_extensions[*]}")')'

# loop through the all files, which satisfy the filter
find "$input_folder" -type f -regextype posix-extended -regex "$filter" | while read -d $'\n' file
do
    echo -e "Found video file :\n\t$file"
    filename=$(basename "$file")
    # defining name for output file and its location
    output_file="$output_folder"/"${filename%.*}"'.mkv'
    # running the conversion
    ffmpeg -i "$file" "${h265[@]}" -y "$output_file"
done;
```
**NB! :** Run as `bash convert_all_inputs.sh` only, not as `sh ...`. The `sh` has no syntax for arrays, it will raise the `Syntax error: "(" unexpected` error.

**NB! :** This may work long, since it is ran directly on shred drive. May be faster if copy to local machine, process there and move to a shared location

# Script to run as parallel conversion with direct access to shared folder

This method can be sufficient if assembled network has no issued with bandwidth and storage access.
In such case each node will directly process files on shared storage.

Create a file `\storage\shared\video_conversion\slurm_conversion_shared.sh` with content:

```
#!/bin/bash

declare -a video_extensions=(mkv webm avi mp4)

current_folder=$(dirname $(realpath ${0}))

input_folder="input"
output_folder="output"
assigned_folder="assigned"
processed_folder="processed"
scripts_folder="scripts"

h265=(-c:v libx265 -crf 28 -c:a libopus)

input_folder="$current_folder"/"$input_folder"
output_folder="$current_folder"/"$output_folder"
assigned_folder="$current_folder"/"$assigned_folder"
processed_folder="$current_folder"/"$processed_folder"
scripts_folder="$current_folder"/"$scripts_folder"

mkdir -p "$scripts_folder"
mkdir -p "$output_folder"
mkdir -p "$assigned_folder"
mkdir -p "$processed_folder"

filter='.*\.('$( IFS='|'; echo "${video_extensions[*]}")')'

find "$input_folder" -type f -regextype posix-extended -regex "$filter" | while read -d $'\n' file
do
      echo "$file"
      filename=$(basename "$file")

      output_file="$output_folder"/"${filename%.*}"'.mkv'
      task_file="$scripts_folder"/"${filename%.*}"'.sh'
      assigned_file="$assigned_folder"/"$filename"
      processed_file="$processed_folder"/"$filename"

      mv "$file" "$assigned_file"

# Creating the SLURM task job file
cat <<EOF> "$task_file"
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
srun ffmpeg -i "$assigned_file" ${h265[@]} -y "$output_file"
srun mv "$assigned_file" "$processed_file"
EOF
      sbatch "$task_file"
done;
```

**NB! :** alternatively, can omit `sbatch "$task_file"` line in order to create tasks only. Run later with `sbatch ./scripts/*.sh`

# Script to run in parallel with copying to local storage

If network bandwidth of shared storage access speed is the issue, it would be more reasonable to:
- copy the assigned file to a local computer (assigned node)
- process the file on the node
- move processed result back to a shared storage

Create a file `\storage\shared\video_conversion\slurm_conversion_local.sh` with content:
```
input_folder="input"
output_folder="output"
assigned_folder="assigned"
processed_folder="processed"
scripts_folder="scripts"
logs_folder="logs"

# Various conversion parameters
h265=(-c:v libx265 -crf 28 -c:a libopus)

# Converstion folder names into locations
input_folder="$current_folder"/"$input_folder"
output_folder="$current_folder"/"$output_folder"
assigned_folder="$current_folder"/"$assigned_folder"
processed_folder="$current_folder"/"$processed_folder"
scripts_folder="$current_folder"/"$scripts_folder"
logs_folder="$current_folder"/"$logs_folder"

#  Printing folders infos
echo -e "This folder will be searched for new files:\n\t $input_folder"
echo -e "Files with already assigned tasks will be moved to folder:\n\t$assigned_folder"
echo -e "Conversion results will be created in folder:\n\t$output_folder"
echo -e "Source files wil be moved after processed to folder:\n\t$processed_folder"
echo -e "SLURM task files will be created in folder:\n\t$scripts_folder"

filter='.*\.('$( IFS='|'; echo "${video_extensions[*]}")')'

# Searching for files
echo "Assigning jobs"

find "$input_folder" -type f -regextype posix-extended -regex "$filter" | while read -d $'\n' file
do
        echo -e "Found file:\n\t$file\n"
        echo "Creating processing variables for it:"
        filename=$(basename "$file")
        task_file="$scripts_folder"/"${filename%.*}"'.sh'
        assigned_file="$assigned_folder"/"$filename"        
        output_file="$output_folder"/"${filename%.*}"'.mkv'

        # Note, dont use here '~/' declaration. It will not work
        local_storage="/home/scientist"
        local_file="$local_storage"/"$filename"
        # Don't use stuff like:
        # temp_file="$local_file"'_tmp'
        # it will result in error due to ffmpeg itself
        # Use these instead:
        temp_file="$local_storage"/"$filename%.*"'_tmp.mkv'

        mv "$file" "$assigned_folder"

# Creating the slurm task job file
cat <<EOF> "$task_file"
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --exclusive
#SBATCH --output="$logs_folder"/slurm-%j.log
srun cp "$assigned_file" "$local_file"
srun ffmpeg -i "$local_file" ${h265[@]} -y "$temp_file"
srun mv "$temp_file" "$output_file"
srun mv "$assigned_file" "$processed_folder"
srun rm  "$local_file"
EOF
        sbatch "$task_file"
done;
```

**NB! :** file can be also created without `srun` in lines

## Looking to progress status:
- `squeue`: to see the whole queue of assigned jobs
- `sinfo -Nel` : to see the current status of all nodes
- `scancel --partition=kyiv` : cancel all jobs, currently running on this partition (all running, not all assigned!)

## A bit of tweaking

If you want to store in script several setting, just make a bunch  of arrays. As example:
```
h265=(-c:v libx265 -crf 28 -c:a libopus)
h264=(-c:v libx264 -preset veryslow -crf 22 -c:a aac)
```
Than, in the loop (or before it), select the settings you need and copy it to different array:
```
video_parameters=("${h264[@]}")
```
And, in the task job use:
```
srun ffmpeg -i "$local_file" ${video_parameters[@]} -y "$temp_file"
```
