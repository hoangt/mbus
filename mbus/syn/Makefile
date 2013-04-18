
ULPB_ab = ulpb_node32_ab
ULPB_cd = ulpb_node32_cd
ULPB_ef = ulpb_node32_ef
CTRL = ulpb_ctrl_wrapper

POST_SDF = /afs/eecs.umich.edu/kits/ARM/TSMC_cl018g/mosis_2009q1/sc-x_2004q3v1/aci/sc/primetime/pt_postprocessor.pl

synth:
	make synth_node;
	make synth_ctrl

synth_node:
	dc_shell -f ${ULPB_ab}.tcl |tee ${ULPB_ab}.dc.log
	-perl ${POST_SDF} -s ${ULPB_ab}.pt.sdf -o ${ULPB_ab}.dc.sdf
	dc_shell -f ${ULPB_cd}.tcl |tee ${ULPB_cd}.dc.log
	-perl ${POST_SDF} -s ${ULPB_cd}.pt.sdf -o ${ULPB_cd}.dc.sdf
	dc_shell -f ${ULPB_ef}.tcl |tee ${ULPB_ef}.dc.log
	-perl ${POST_SDF} -s ${ULPB_ef}.pt.sdf -o ${ULPB_ef}.dc.sdf

synth_ctrl:
	dc_shell -f ${CTRL}.tcl |tee ${CTRL}.dc.log
	-perl ${POST_SDF} -s ${CTRL}.pt.sdf -o ${CTRL}.dc.sdf

clean:
	rm -f *.log; rm -f *.rpt; rm -f *.nl.v; rm -f *.sdf; rm -f *.svf; rm -f *.key; rm -rf INCA_libs; rm -rf *.log; rm -rf waves.shm; rm -rf .nclaunch*; rm -rf .simvision*;
	rm -f *.pvl *.syn *.mr *.sdc
	rm -f ../netlist/*.nl.v ../netlist/*.dc.sdf
	rm -rf alib*