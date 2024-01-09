#!/bin/bash
# bash script for executing and measuring the r-script or psql queries
# - creates a dir 'measures' in the same dir as this script
# - creates some files in this dir:
# - .json: contains measurements collected from docker stats
# - .log: contains output of the rscript or query responses
# - .pdf: contains plots for memory and cpu usage
# - uses R and package jsonlite (and graphics, installed bydefault) for graph rendering

ROOTDIR=/c/Users/Konstii/Desktop/STUDIUM/23WS/FPA_DB
RSCRIPTEXE="/c/Program Files/R/R-4.3.2/bin/x64/RScript.exe"
RSCRIPT=$ROOTDIR/forschungspraktikum/forecast.R

# uncomment one of the two lines below
#EXEC="docker exec fpa_db_psql bash -c \"psql -U postgres -d postgres -a -f /database/exec.sql\""
EXEC="\"$RSCRIPTEXE\" \"$RSCRIPT\""

# ----
PLOTSCRIPT=$ROOTDIR/plot.R
MEASUREDIR=$ROOTDIR/measures
DATENOW=$(date +"y%y_mo%m_d%d_h%H_m%M_s%S")
MEASUREFILE=$MEASUREDIR/$DATENOW.json
LOGFILE=$MEASUREDIR/$DATENOW.log
X=\"x\" # cant get r to work with timestamps and nanoseconds fml
Y=\"y\"
TS=\"ts\"
# create measure dir if it not exists
if [ ! -d "$MEASUREDIR" ]; then
    mkdir "$MEASUREDIR"
fi

LASTLINE=0
# fct for adding current docker stats to measurefile
addStats(){
    CSTATS=$(docker stats fpa_db_psql --no-stream --format "{{ json . }}")
    CDATE=$(date +"%y:%m:%d %H:%M:%S.%N")
    CDATE=\"$CDATE\"
    CTS=$(date +%s%N) 
    CTS=\"$CTS\"
    L="{$X:$CDATE, $Y:$CSTATS, $TS:$CTS}"
    if [ ! $LASTLINE -eq 1 ]; then
        L="$L,"
    fi
    echo "$L" >> "$MEASUREFILE"
}
RECORDING=1
# fct for stopping the recording
stopstream() {
    if [ $RECORDING -eq 1 ]; then
        kill "$SPID" # send termination signal to stream process
        wait "$SPID" # wait for stream to be closed
        RECORDING=0
    fi
}
echo "start recording"
echo "[" > "$MEASUREFILE"
# startdate and docker state
addStats
# start record in sep process, make sure that this process handles the bg process well
trap stopstream EXIT
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
# plot it
echo "start drawing"
EXEC="\"$RSCRIPTEXE\" \"$PLOTSCRIPT\" \"$MEASUREFILE\""
eval "$EXEC >> $LOGFILE"
echo "plot drawn"