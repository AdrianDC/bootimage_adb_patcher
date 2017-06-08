#!/sbin/sh

# find_boot_image logic by Chainfire, improved to support Sony 8960 Kernel and MTK /dev/bootimg
for PARTITION in kern-a KERN-A android_boot ANDROID_BOOT Kernel kernel KERNEL boot BOOT lnx LNX bootimg; do
  BOOTIMAGE=$(readlink /dev/block/by-name/$PARTITION || readlink /dev/block/platform/*/by-name/$PARTITION || \
              readlink /dev/block/platform/*/*/by-name/$PARTITION || readlink /dev/$PARTITION);
  if [ ! -z "${BOOTIMAGE}" ]; then
    break;
  fi;
done;

# Bootimage not found
if [ ! -e "${BOOTIMAGE}" ]; then
  return 1;
fi;

# Extract the bootimage
rm -rf /tmp/bootimage;
mkdir -p /tmp/bootimage;
cd /tmp/bootimage/;
chmod 777 /tmp/bbootimg;
/tmp/bbootimg -x ${BOOTIMAGE};
if [ $? -ne 0 ]; then
  return 1;
fi;

# Unpack the ramdisk
mkdir ./ramdisk;
cd ./ramdisk/;
rm -f ../initrd.cpio;
rm -f ../initrd.cpio.gz;
cp ../initrd.img ../initrd.cpio.gz;
gzip -d ../initrd.cpio.gz;
cpio -i -F ../initrd.cpio;
rm -f ../initrd.cpio;
rm -f ../initrd.img;

# Patch the ramdisk
if grep -q 'ro.secure=' ./default.prop; then
  sed -i 's/ro.secure=.*/ro.secure=1/' ./default.prop;
else
  echo '# Bootimage ADB Secure: Added ro.secure' >> ./default.prop;
  echo 'ro.secure=1' >> ./default.prop;
fi;
if grep -q 'ro.adb.secure=' ./default.prop; then
  sed -i 's/ro.adb.secure=.*/ro.adb.secure=1/' ./default.prop;
else
  echo '# Bootimage ADB Secure: Added ro.adb.secure' >> ./default.prop;
  echo 'ro.adb.secure=1' >> ./default.prop;
fi;
if grep -q 'persist.sys.usb.config=' ./default.prop; then
  sed -i 's/persist.sys.usb.config=.*/persist.sys.usb.config=none/' ./default.prop;
else
  echo '# Bootimage ADB Secure: Added persist.sys.usb.config' >> ./default.prop;
  echo 'persist.sys.usb.config=none' >> ./default.prop;
fi;

# Repack the ramdisk
rm -f ../initrd.cpio;
rm -f ../initrd.cpio.gz;
find . | cpio -o -H newc -F ../initrd.cpio;
gzip -9 ../initrd.cpio;
mv ../initrd.cpio.gz ../initrd.img;
cd ../;
rm -rf ./ramdisk;
if [ ! -f ./initrd.img ]; then
  return 1;
fi;

# Inject the ramdisk
/tmp/bbootimg -u ${BOOTIMAGE} -r ./initrd.img;
if [ $? -ne 0 ]; then
  return 1;
fi;

# Result
return 0;

