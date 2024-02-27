if [ -z "$1" ]; then
    echo "Please pass in the roborio zip"
    exit
fi

DIR=$(pwd)
echo "Getting kernel..."
$DIR/get_linux.sh
echo "Extracting zip..."
$DIR/create_rootfs.sh $1
