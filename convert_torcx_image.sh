#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 TORCXTAR SYSEXTNAME"
  echo "The script will unpack the Torcx tar ball and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "The conversion is done on best effort, and only the TORCX_BINDIR (/usr/bin), TORCX_UNPACKDIR (/), and TORCX_IMAGEDIR ('') env vars in the systemd units get replaced."
  exit 1
fi

TORCXTAR="$1"
SYSEXTNAME="$2"

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
tar -xf "${TORCXTAR}" -C "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"/.torcx
mkdir -p "${SYSEXTNAME}"/usr
if [ -e "${SYSEXTNAME}"/bin ]; then
  mv "${SYSEXTNAME}"/bin "${SYSEXTNAME}"/usr/
fi
if [ -e "${SYSEXTNAME}"/lib ]; then
  mv "${SYSEXTNAME}"/lib "${SYSEXTNAME}"/usr/
fi
for FILE in "${SYSEXTNAME}"/usr/lib/systemd/system/*.service "${SYSEXTNAME}"/usr/lib/systemd/system/*.socket; do
  if [ -e "${FILE}" ]; then
    sed -i \
      -e 's,EnvironmentFile=/run/metadata/torcx,,g' -e 's,Environment=TORCX_IMAGEDIR=.*,,g' \
      -e "s,\[Service\],\[Service\]\nEnvironment=TORCX_BINDIR=/usr/bin\nEnvironment=TORCX_UNPACKDIR=/\nEnvironment=TORCX_IMAGEDIR=,g" \
      -e 's,After=torcx.target,,g' -e 's,Requires=torcx.target,,g' "${FILE}"
  fi
done
mkdir -p "${SYSEXTNAME}/usr/lib/extension-release.d"
{ echo "ID=flatcar" ; echo "SYSEXT_LEVEL=1.0" ; } > "${SYSEXTNAME}/usr/lib/extension-release.d/extension-release.${SYSEXTNAME}"
rm -f "${SYSEXTNAME}".raw
mksquashfs "${SYSEXTNAME}" "${SYSEXTNAME}".raw -all-root
rm -rf "${SYSEXTNAME}"
echo "Created ${SYSEXTNAME}.raw"
