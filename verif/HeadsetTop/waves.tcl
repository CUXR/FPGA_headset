file mkdir sim/HeadsetTop
database -open waves -shm -into sim/HeadsetTop/waves.shm -default
probe -create tb_HeadsetTop -all -depth all -mem -database waves
run
exit
