#!/bin/bash
set -e

submission=$(mktemp -d --suffix=.submission)
workdir=$(mktemp -d --suffix=.workdir)

cleanup() {
    rm -rf "$submission"
    rm -rf "$workdir"
}
trap 'cleanup' EXIT

cp -av prog.c remarks.md try.sh ${submission}
cp -av Makefile.ioccc ${submission}/Makefile
mkdir -p ${submission}/roms
cp -av roms/Pi.gb roms/Test.gb roms/Oxo3d.gb roms/GBChess.gb ${submission}/roms

mkiocccentry -i answers.txt $workdir $submission

tar=$(basename ${workdir}/submit*.txz)
mkdir -p submissions
mv -iv ${workdir}/${tar} submissions

echo "=== Submission ==="
tar -tf submissions/${tar}
echo "=================="
echo "Now in submissions/${tar}"


