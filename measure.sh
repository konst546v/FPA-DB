#!/bin/bash
# bash script for executing and measuring the r-script or psql queries
# - creates a dir 'measures' in the same dir as this script
# - creates some files in this dir:
# - <date>.json: contains measurements collected from docker stats
# - <date>.log: contains output of the rscript or query responses
# - <date>_CPU.pdf: plot for memory usage of one run at the given date
# - <date>_Mem.pdf: vice versa
# - mean_<sdate>-<edate>_cpu.pdf: contains all cpu-plots and the resulting mean plot of all from startdate sdate and end date edate
# - mean_<sdate>-<edate>_cpu.pdf: vice versa for mem

# - uses R and package jsonlite and ggplot2 (and graphics, installed bydefault) for graph rendering

RUNS=5
ROOTDIR=.
RSCRIPTEXE=Rscript
RSCRIPT=$ROOTDIR/forschungspraktikum/forecast.R

# uncomment one of the two lines below
EXEC="docker exec fpa_db_psql bash -c \"psql -U postgres -d postgres -a -f /database/exec.sql\""
#EXEC="\"$RSCRIPTEXE\" \"$RSCRIPT\""

# ---- 
PLOTSCRIPT=$ROOTDIR/plot.R
AGGSCRIPT=$ROOTDIR/agg.R
MEASUREDIR=$ROOTDIR/measures

# create measure dir if it not exists
if [ ! -d "$MEASUREDIR" ]; then
    mkdir "$MEASUREDIR"
fi
X=\"x\" # cant get r to work with timestamps and nanoseconds fml
Y=\"y\"
TS=\"ts\"

# fct for adding current docker stats to measurefile
addStats(){
    CSTATS=$(docker stats fpa_db_psql --no-stream --format "{{ json . }}")
    CDATE=$(date +"%y:%m:%d %H:%M:%S.%N")
    CDATE=\"$CDATE\"
    CTS=$(date +%s%N)
    CTS=$((CTS-START)) # otherwise to big number
    CTS=\"$CTS\"
    L="{$X:$CDATE, $Y:$CSTATS, $TS:$CTS}"
    if [ ! $LASTLINE -eq 1 ]; then
        L="$L,"
    fi
    echo "$L" >> "$MEASUREFILE"
}
# fct for stopping the recording
stopstream() {
    if [ $RECORDING -eq 1 ]; then
        kill "$SPID" # send termination signal to stream process
        wait "$SPID" # wait for stream to be closed
        RECORDING=0
    fi
}
trap stopstream EXIT

echo "start runs"
for i in $(seq 1 $RUNS)
do

echo "run $i"
DATENOW=$(date +"y%y_mo%m_d%d_h%H_m%M_s%S")
MEASUREFILE=$MEASUREDIR/$DATENOW.json
LOGFILE=$MEASUREDIR/$DATENOW.log
START=$(date +%s%N) #s is absolute
LASTLINE=0
RECORDING=1
echo "start recording"
echo "[" > "$MEASUREFILE"
# startdate and docker state
addStats
# start record in sep process
while true; do
# retrieving stats takes some time
addStats
done & SPID=$!

# start rscript or psql in curr process
eval "$EXEC > $LOGFILE"
# stop if done
stopstream
echo "stop recording"
# enddate and docker state
LASTLINE=1
addStats
echo "]">> "$MEASUREFILE"
# plot it (its optional but lines are nicer than numbers)
echo "start drawing"
SEXEC="\"$RSCRIPTEXE\" \"$PLOTSCRIPT\" \"$MEASUREFILE\""
eval "$SEXEC >> $LOGFILE"
echo "plot drawn"
# add measurefile
FILES="$FILES \"$MEASUREFILE\""
done
# aggregagate
echo "runs done"
echo "start aggregating"
EXEC="\"$RSCRIPTEXE\" \"$AGGSCRIPT\" $FILES"
eval "$EXEC"
echo "done aggregating"
