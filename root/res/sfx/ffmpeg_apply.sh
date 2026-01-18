set -e

file_list=()
for file in *; do
    file_list+=($file)
done

for file in "${file_list[@]}"; do
    if [[ $file == *.wav ]]; then
        ffmpeg -i $file $* tmp.wav
        mv tmp.wav $file
    fi
done