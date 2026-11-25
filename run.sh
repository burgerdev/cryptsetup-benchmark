#!/bin/sh

set -eu

run() {
  name=$1; shift
  device=$1; shift
  echo "=== $device -- $name ==="
  fio --name="$name" --filename="$device" --direct=1 --ioengine=libaio \
      --time_based --runtime=30 --group_reporting \
      --output-format=normal "$@"
}

run_all() {
  run seq-write "$1"   --rw=write     --bs=1M --iodepth=16 --numjobs=1
  run rand-write "$1"  --rw=randwrite --bs=4k --iodepth=32 --numjobs=4
}

file=$(mktemp)
keyfile=$(mktemp)

cleanup() {
  set +e
  if [ -n "${cryptname:-}" ]; then
    cryptsetup close "$cryptname"
  fi
  if [ -n "${loopdev:-}" ]; then
    losetup -d "$loopdev"
  fi
  rm -f "$file" "$keyfile"
}

trap cleanup EXIT

truncate -s 1G "$file"
loopdev=$(losetup --find --show "$file")

dev="${ACK_DESTROY_THIS_DEVICE:-$loopdev}"
run_all "$dev"

head -c16 /dev/urandom >"$keyfile"
cryptsetup luksFormat --type=luks2 --cipher=aes-xts-plain64 --pbkdf=argon2id --pbkdf-memory=10240 --integrity=hmac-sha256 --integrity-no-wipe --sector-size=4096 --batch-mode --key-file="$keyfile" "$dev"
cryptsetup luksOpen --key-file="$keyfile" "$dev" "fio-bench-$$"
cryptname=fio-bench-$$

run_all "/dev/mapper/$cryptname"

sleep inf
