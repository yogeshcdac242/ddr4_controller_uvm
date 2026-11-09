# Cadence Xcelium Makefile for DDR4 Memory Controller UVM Testbench

# Enforce Xcelium 22.03 paths so cshrc_cadence doesn't force 15.20 engines internally
export PATH := /home/tools/cadence/XCELIUM2203/tools.lnx86/bin:/home/tools/cadence/XCELIUM2203/tools.lnx86/inca/bin:/home/tools/cadence/VMANAGER2203/tools.lnx86/vmgr/bin:$(PATH)
export XCELIUMHOME := /home/tools/cadence/XCELIUM2203
export CDS_INST_DIR := /home/tools/cadence/XCELIUM2203
export IUSHOME :=

XRUN = xrun
IMC = imc

# Directories
PROJECT_DIR = ..
TB_DIR = .

# Compilation Options
XRUN_OPTS = -uvm \
            -sv \
            -64bit \
            -timescale 1ns/1ps \
            +access+rwc \
            -licqueue \
            +incdir+$(PROJECT_DIR) \
            +incdir+$(TB_DIR)

# Coverage Options
COV_OPTS = -coverage all \
           -covoverwrite

# Sources
RTL_SRCS = $(PROJECT_DIR)/C2MInterface.sv \
           $(PROJECT_DIR)/DDR4Interface.sv \
           $(PROJECT_DIR)/Timer.sv \
           $(PROJECT_DIR)/ShiftReg.sv \
           $(PROJECT_DIR)/Read_data_comm.sv \
           $(PROJECT_DIR)/Receive_command.sv \
           $(PROJECT_DIR)/CalcMax.sv \
           $(PROJECT_DIR)/ReadWrite.sv \
           $(PROJECT_DIR)/Controller_FSM.sv \
           $(PROJECT_DIR)/Scheduler.sv \
           $(PROJECT_DIR)/Memory.sv \
           $(PROJECT_DIR)/MemoryController.sv

TB_SRCS = $(TB_DIR)/ddr4_pkg.sv \
          $(TB_DIR)/tb_top.sv

# Targets
.PHONY: all clean sim_init sim_write_read sim_refresh sim_random sim_stress cov html_cov

all: clean sim_init sim_write_read sim_refresh sim_random sim_stress cov

# Target for Link Initialization & MRS Test
sim_init:
	rm -rf xcelium.d
	$(XRUN) $(XRUN_OPTS) $(COV_OPTS) -covtest init_test \
	    $(RTL_SRCS) $(TB_SRCS) \
	    +UVM_TESTNAME=ddr4_init_test \
	    -l sim_init.log

# Target for Read/Write Traffic Test
sim_write_read:
	$(XRUN) $(XRUN_OPTS) $(COV_OPTS) -covtest write_read_test \
	    $(RTL_SRCS) $(TB_SRCS) \
	    +UVM_TESTNAME=ddr4_write_read_test \
	    -l sim_write_read.log

# Target for Refresh Management & Bank Interleaving Test
sim_refresh:
	$(XRUN) $(XRUN_OPTS) $(COV_OPTS) -covtest refresh_test \
	    $(RTL_SRCS) $(TB_SRCS) \
	    +UVM_TESTNAME=ddr4_refresh_test \
	    -l sim_refresh.log

# Target for Random Traffic Test
sim_random:
	$(XRUN) $(XRUN_OPTS) $(COV_OPTS) -covtest random_test \
	    $(RTL_SRCS) $(TB_SRCS) \
	    +UVM_TESTNAME=ddr4_random_traffic_test \
	    -l sim_random.log

# Target for Stress Test (Zero-delay flooding)
sim_stress:
	$(XRUN) $(XRUN_OPTS) $(COV_OPTS) -covtest stress_test \
	    $(RTL_SRCS) $(TB_SRCS) \
	    +UVM_TESTNAME=ddr4_stress_test \
	    -l sim_stress.log

# Generate Text Coverage Report
cov:
	@echo "Generating coverage text report..."
	$(IMC) -execcmd 'merge cov_work/scope/init_test cov_work/scope/write_read_test cov_work/scope/refresh_test cov_work/scope/random_test cov_work/scope/stress_test -out merged_cov; load -run merged_cov; report -summary -out coverage_summary.txt; exit'
	@cat coverage_summary.txt

# Generate HTML Coverage Report
html_cov:
	@echo "Generating HTML coverage report..."
	$(IMC) -execcmd 'load -run merged_cov; report -html -out $(shell pwd)/coverage_html; exit'
	@echo "Done! View coverage_html/index.html in a browser."

clean:
	rm -rf xcelium.d cov_work xrun.history xrun.log xrun.key
	rm -rf sim_*.log coverage_summary.txt coverage_html
