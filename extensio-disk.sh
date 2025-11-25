#!/bin/bash
set -euo pipefail

DEFAULT_DEVICE="/dev/sda"
DEFAULT_PART_NUM=3
DEFAULT_LV="/dev/mapper/ubuntu--vg-ubuntu--lv"

usage() {
	cat <<EOF
Usage: $0 [options]

Options:
	-d, --device DEVICE        Base device (default: ${DEFAULT_DEVICE})
	-n, --part-num N           Partition number (default: ${DEFAULT_PART_NUM})
	-p, --partition PATH       Full partition path (overrides device+part-num)
	-l, --lv LV_PATH           Logical Volume path (default: ${DEFAULT_LV})
			--trace                Enable command trace (set -x)
	-h, --help                 Show this help

Examples:
	$0 -d /dev/sda -n 3 -l /dev/mapper/ubuntu--vg-ubuntu--lv
	$0 --partition /dev/sdb2 --trace
EOF
}

DEVICE="${DEFAULT_DEVICE}"
PART_NUM="${DEFAULT_PART_NUM}"
PARTITION_PATH=""
LV_PATH="${DEFAULT_LV}"
TRACE=0

while [[ $# -gt 0 ]]; do
	case "$1" in
		-d|--device)
			DEVICE="$2"; shift 2;;
		-n|--part-num)
			PART_NUM="$2"; shift 2;;
		-p|--partition)
			PARTITION_PATH="$2"; shift 2;;
		-l|--lv)
			LV_PATH="$2"; shift 2;;
		--trace)
			TRACE=1; shift;;
		-h|--help)
			usage; exit 0;;
		*)
			echo "Unknown option: $1" >&2; usage; exit 1;;
	esac
done

if [[ -z "${PARTITION_PATH}" ]]; then
	# If device ends with a digit (e.g. /dev/nvme0n1) use 'p' before number
	if [[ "${DEVICE}" =~ [0-9]$ ]]; then
		PARTITION_PATH="${DEVICE}p${PART_NUM}"
	else
		PARTITION_PATH="${DEVICE}${PART_NUM}"
	fi
fi

if [[ "${TRACE}" -eq 1 ]]; then
	set -x
fi

echo "Ampliando partición: device='${DEVICE}' part_num='${PART_NUM}' partition='${PARTITION_PATH}' lv='${LV_PATH}'"

growpart "${DEVICE}" "${PART_NUM}"
echo "Partición ampliada." 
lsblk

echo "Redimensionando el PV: ${PARTITION_PATH}"
pvresize "${PARTITION_PATH}"
echo "PV redimensionado."

echo "Ampliando el LV: ${LV_PATH}"
lvextend -l +100%FREE "${LV_PATH}"
echo "LV ampliado."

echo "Redimensionando el sistema de archivos en: ${LV_PATH}"
resize2fs "${LV_PATH}"
echo "Sistema de archivos redimensionado."

echo "Proceso completado. Verifique el nuevo tamaño con 'df -h'."