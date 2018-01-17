#!/usr/bin/tcsh

if ($#argv != 1) then
  echo "ERROR: incorrect number of arguments"
  echo "Usage: setup_experiment.csh <number_of_sim_year>"
  exit 1
endif

# get command line arguments
set experiment=RUN_int2lm_ERAI_EUR-44
set numbyear=$argv[1]


set startdate=1979010100

set startyear=`echo $startdate | cut -c1-4`
@ endyear = ${startyear} + ${numbyear}
set enddate=${endyear}010100
@ endyear--

set workdir=/scratch/snx3000/${user}/${experiment}

mkdir -p $workdir
mkdir -p $workdir/caf_files

mkdir -p $workdir/jobs
mkdir -p $workdir/logs


mkdir -p $workdir/output
set yr=$startyear

while (${yr} <= ${endyear})
   mkdir -p ${workdir}/output/${yr}
   mkdir -p ${workdir}/caf_files/${yr}
   @ yr++
end


# copy and create namelist input files
scp /project/pr04/ssilje/RUN_INT2LM/int2lm_extp/extp2_v090_dwdritter_europe_0440.nc $workdir
scp /project/pr04/ssilje/RUN_INT2LM/int2lm_extp/invar_eraint.nc $workdir
scp /project/pr04/ssilje/int2lm/int2lm $workdir/.


set yr=${startyear}
@ nyr = $startyear + 1
set stahr=0
set endhr=`/users/nkroener/scripts/tim_diff/time_diff_gregorian ${startdate} ${nyr}010100`
set year_endhr=`/users/nkroener/scripts/tim_diff/time_diff_gregorian ${yr}010100 ${nyr}010100`
#set dirin="./input/${yr}/"

# loop over all desired years
while ( $yr <= $endyear )
# create INPUT for the current year
cat > ${workdir}/INPUT.${yr} <<EOFEOF
&CONTRL
    ydate_ini='${yr}010100',
    hstart=0.0, hstop=${year_endhr}, hincbound=6.0,
    linitial = .TRUE.,  lboundaries = .TRUE., 
    nprocx = 1, nprocy = 1, nprocio=0,
    lasync_io=.FALSE.,
    itype_calendar = 0,
    lfilter_oro = .FALSE.,
    l_cressman = .FALSE.,
    lbdclim = .TRUE.,  
    yinput_model = 'CM',
    ltime_mean = .TRUE.,
    lmulti_layer_in = .TRUE.,
    lmulti_layer_lm = .TRUE.,
    itype_w_so_rel = 0,
    itype_t_cl = 1, 
    itype_rootdp = 4,
    lprog_qi = .FALSE.,
    lforest = .TRUE.,
    lsso = .TRUE.
    nincwait = 5, nmaxwait = 20, 
    luse_t_skin = .TRUE.,
    itype_albedo = 2,
    itype_aerosol = 2,
    idbg_level=30,
/END
&DATABASE
/END
&GRID_IN
  pcontrol_fi = 30000.,
  ie_in_tot = 512,
  je_in_tot = 256,
  ke_in_tot = 60,
  startlat_in_tot = -89.46282,
  startlon_in_tot = -180.0,
  endlat_in_tot = 89.46282,
  endlon_in_tot = 179.2969,
  pollat_in = 90.0, pollon_in = 180.0,
  ke_soil_in = 3,   
  czml_soil_in = 0.015, 0.1, 0.405, 1.205,
/END
&LMGRID
    ielm_tot = 132,
    jelm_tot = 129,
    kelm_tot = 40,
    pollat = 39.25, pollon = -162.0, 
    dlon = 0.440, dlat = 0.440, 
    startlat_tot = -28.93,
    startlon_tot = -33.93,
    ke_soil_lm = 9,
    czml_soil_lm = 0.005, 0.025, 0.07, 0.16, 0.34, 0.70, 1.42, 2.86, 5.74, 11.5,
    czvw_so_lm = 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75, 0.75,
    irefatm = 2,
    ivctype = 2,
/END
&DATA
  ie_ext = 153, je_ext = 159,
  ylmext_lfn = 'extp2_v090_dwdritter_europe_0440.nc',
  ylmext_cat='./',
  yinext_lfn='invar_eraint.nc',
  yinext_cat='./',
  yin_cat='./caf_files/${yr}/',
  ylm_cat= './output/${yr}/',
  yinput_type = 'analysis',
  ytunit_in = 'd',
  ytunit_out = 'd',
  yinext_form_read = 'ncdf',
  ylmext_form_read = 'ncdf',
  yin_form_read = 'ncdf',
  ylm_form_write = 'ncdf',
  nprocess_ini = 131, nprocess_bd = 132,
/END
&PRICTR
  lchkin=.FALSE., lchkout=.FALSE.,
  igp_tot = 36,
  jgp_tot = 30,
/END
EOFEOF

cat > ${workdir}/jobs/run_int2lm.${yr} <<EOFEOF
#!/bin/csh
#SBATCH --constraint=gpu
#SBATCH --job-name="int2lm_${yr}"
#SBATCH --ntasks=1
#SBATCH --output=job.out
#SBATCH --time=04:00:00
#SBATCH --account=pr04
#SBATCH --output=$workdir/logs/int2lm_log_${yr}.out
#SBATCH --error=$workdir/logs/int2lm_log_${yr}.err

# Set this to avoid segmentation faults
ulimit -s unlimited
ulimit -a

echo "====================================================="
echo "============== JOB OUTPUT BEGINS ===================="
echo "====================================================="

cd ${workdir}
if ( -e YUDEBUG ) then
rm YUDEBUG
endif

if ( -e YUTIMING ) then
rm YUDEBUG
endif

if ( -e OUTPUT ) then
rm OUTPUT
endif

if ( -e INPUT ) then
rm INPUT
endif

cp INPUT.${yr} INPUT

srun -n 1 -u ./int2lm


mv YUDEBUG log/YUDEBUG.${yr}
mv YUTIMING log/YUTIMING.${yr}
mv OUTPUT log/OUTPUT.${yr}

if (${yr} < ${endyear}) then 
 
    sbatch jobs/run_int2lm.${nyr}
 
endif 

echo "====================================================="
echo "============== JOB OUTPUT ENDS ===================="
echo "====================================================="
EOFEOF

cat > ${workdir}/jobs/get_caf.${yr} <<EOFEOF
#!/bin/csh
#SBATCH --constraint=gpu
#SBATCH --account=pr04
#SBATCH --nodes=1
#SBATCH --time=4:00:00
#SBATCH --output=$workdir/logs/getcaf_log_${yr}.out
#SBATCH --error=$workdir/logs/getcaf_log_${yr}.err
#SBATCH --job-name=getdat_${yr}

cd ${workdir}/caf_files/${yr}/work

set month='01 02 03 04 05 06 07 08 09 10 11 12'
foreach f ( \${month} ) 
    if ( ! -f ERAINT_${yr}_\${f}.tar ) then
    gunzip  ERAINT_${yr}_\${f}.tar.gz
    tar xvf ERAINT_${yr}_\${f}.tar
    else
    tar xvf ERAINT_${yr}_\${f}.tar
    endif
end


foreach filename ( *.nc )
  ncks -x -v QI "\$filename" ../"\$filename"
#scp "\$filename" ../"\$filename"
end

rm -r work

cd ${workdir}
if (${yr} < ${endyear}) then 
  sbatch jobs/get_caf_noQI.${nyr}
endif
 
EOFEOF


cat > ${workdir}/jobs/xfer_caf.${yr} <<EOFEOF
#!/bin/csh
#SBATCH --account=pr04
#SBATCH --nodes=1
#SBATCH --partition=xfer
#SBATCH --time=4:00:00
#SBATCH --output=logs/EXAR_xfer.out
#SBATCH --error=logs/xfer.err
#SBATCH --job-name="xfer_${yr}"


cd ${workdir}/caf_files/${yr}

if ( ! -d ${workdir}/caf_files/${yr}/work ) then
 mkdir ${workdir}/caf_files/${yr}/work
endif


cd ${workdir}/caf_files/${yr}/work
rsync -auv /project/pr04/ERAinterim/${yr}/ERAINT_${yr}_* .


cd ${workdir}
if (${yr} < ${endyear}) then 
  sbatch jobs/xfer_caf.${nyr}
endif
 
EOFEOF

  set yr=$nyr
  @ nyr++
    echo $endhr
  set stahr=$endhr
  set endhr=`/users/nkroener/scripts/tim_diff/time_diff_gregorian ${startdate} ${nyr}010100`
 
end



exit 0
