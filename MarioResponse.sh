#!/bin/bash

set -eu -o pipefail

usermessage=$1
roomnr=$2
wd=$(dirname $0)

talkdir=$(cd $wd; pwd)/AI/talk-$roomnr
mkdir -p $talkdir
pgrep -f sampler.lua >/dev/null || \
    (cd $wd/AI; \
     th scripts/sampler.lua lm_lstm_epoch2.01_1.0152.t7_cpu.t7 \
        $talkdir \
        -gpuid -1 \
        -temperature 0.4 >/dev/null &)

msgnr=$(ls $talkdir | wc -l)
((++msgnr))
echo -n $usermessage >> $talkdir/$msgnr
((++msgnr))
while [ ! -e $talkdir/$msgnr ]
do
    sleep 0.1
done

cat $talkdir/$msgnr
