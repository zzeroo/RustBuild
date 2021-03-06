#!/usr/bin/env bash

# This is the script that installs the required dependencies and runs the final setups on the system

set -x
set -e

: ${OPENSSL_DIR:=/build/openssl}
: ${OPENSSL_SRC:=$OPENSSL_DIR/openssl_src}

# Determine the fastest host to use for updating
apt-get install --allow-unauthenticated -qq netselect-apt
netselect-apt
NEW_HOST=$(cat sources.list | grep deb | head -n 1 | sed 's/deb http:\/\///' | sed 's/\/debian\/ stable.*//')
rm sources.list

# Replace the old host in the soruces lists with the new ideal host
SOURCE_FILES=/etc/apt/sources.list.d/*.list
echo "Source Files: $SOURCE_FILES"
for f in $SOURCE_FILES
do
  echo "Updating: $f"
  UPDATED=$(cat $f | sed "s/ftp.us.debian.org/$NEW_HOST/")
  echo "$UPDATED" > $f
done

apt-get update
apt-get install --allow-unauthenticated -qq openssl zlib1g-dev git curl python ccache clang gcc g++ cmake file build-essential pkg-config

# Configure the correct alternatives on the system to ensure we're using clang and clang++ 
# where we should instead of gcc and g++
#update-alternatives --install /usr/bin/gcc gcc /usr/bin/clang 50 --slave /usr/bin/g++ g++ /usr/bin/clang++

cd ~
# Set the container tag if it wasn't properly inherited
if [ -z $CONTAINER_TAG ]; then
  if [ -f CONTAINER_TAG ]; then
    CONTAINER_TAG=$(cat CONTAINER_TAG)
  fi
fi

# Print a file with system info
echo "$(uname -a)" > SYSTEM_INFO
echo "$(dpkg -l | grep libc6)" >> SYSTEM_INFO
echo "$(ldd --version | head -n 1)" >> SYSTEM_INFO
echo "$(ld --version | head -n 1)" >> SYSTEM_INFO
echo "$(gcc --version | head -n 1)" >> SYSTEM_INFO
echo "$(g++ --version | head -n 1)" >> SYSTEM_INFO
echo "$(clang --version | tr '\\n' '|' | head -n 1)" >> SYSTEM_INFO
echo "$(clang++ --version | tr '\\n' '|' | head -n 1)" >> SYSTEM_INFO
echo "$(ccache --version | head -n 1)" >> SYSTEM_INFO

# Run the dropbox uploader configuration script
bash dropbox_uploader.sh

# Make sure our tag directory exists
bash dropbox_uploader.sh mkdir ${CONTAINER_TAG}

# Build OpenSSL with the required information for use in building cargo
cd $OPENSSL_SRC
./config -fPIC shared --prefix=$OPENSSL_DIR/dist
make
make install
