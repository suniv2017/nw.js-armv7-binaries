#!/bin/sh

sudo apt-get update -qq
sudo apt-get upgrade -qq
sudo apt-get install git curl -qq

git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
export PATH=$PATH:"$(pwd)"/depot_tools

mkdir -p "$(pwd)"/nwjs
export NWJS="$(pwd)"/nwjs
cd $NWJS

# get default branch of NW.js
export DEFAULT_BRANCH="$(curl https://api.github.com/repos/nwjs/nw.js | grep -Po '(?<="default_branch": ")[^"]*')"

gclient config --name=src https://github.com/nwjs/chromium.src.git@origin/"${DEFAULT_BRANCH}"

export MAGIC="        \"src/third_party/WebKit/LayoutTests\": None,\n        \"src/chrome_frame/tools/test/reference_build/chrome\": None,\n        \"src/chrome_frame/tools/test/reference_build/chrome_win\": None,\n        \"src/chrome/tools/test/reference_build/chrome\": None,\n        \"src/chrome/tools/test/reference_build/chrome_linux\": None,\n        \"src/chrome/tools/test/reference_build/chrome_mac\": None,\n        \"src/chrome/tools/test/reference_build/chrome_win\": None,"

awk -v values="${MAGIC}" '/custom_deps/ { print; print values; next }1' .gclient | cat > .gclient.temp
mv .gclient.temp .gclient

# clone some stuff
mkdir -p $NWJS/src/content/nw
mkdir -p $NWJS/src/third_party/node
mkdir -p $NWJS/src/v8
git clone https://github.com/nwjs/nw.js $NWJS/src/content/nw
git clone https://github.com/nwjs/node $NWJS/src/third_party/node
git clone https://github.com/nwjs/v8 $NWJS/src/v8
cd $NWJS/src/content/nw
git checkout "${DEFAULT_BRANCH}"
cd $NWJS/src/third_party/node
git checkout "${DEFAULT_BRANCH}"
cd $NWJS/src/v8
git checkout "${DEFAULT_BRANCH}"
cd $NWJS

cd $NWJS/src
export GYP_CROSSCOMPILE="1"
export GYP_DEFINES="target_arch=arm arm_float_abi=hard nwjs_sdk=1 disable_nacl=0 buildtype=Official"
export GN_ARGS="is_debug=false is_component_ffmpeg=true enable_nacl=true is_official_build=true target_cpu=\"arm\" ffmpeg_branding=\"Chrome\""

export GYP_CHROMIUM_NO_ACTION=1
gclient sync --reset --with_branch_heads

cd $NWJS/src
./build/install-build-deps.sh --arm --no-prompt
./build/linux/sysroot_scripts/install-sysroot.py --arch=arm

# TODO Get and apply patches from @jtg-gg

gn gen out_gn_arm/nw --args="$GN_ARGS"
export GYP_CHROMIUM_NO_ACTION=0
python build/gyp_chromium -Goutput_dir=out_gn_arm third_party/node/node.gyp

# Build
ninja -C out_gn_arm/nw nwjs
ninja -C out_gn_arm/nw v8_libplatform
ninja -C out_gn_arm/Release node
ninja -C out_gn_arm/nw copy_node
ninja -C out_gn_arm/nw dist