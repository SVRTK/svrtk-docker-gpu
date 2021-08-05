
### svrtk-docker-gpu
#
# INSTALLATION INSTRUCTIONS
#
# 1) Download svrtk-docker-gpu package to C: drive
#		i.e.: C:\svrtk-docker-gpu
# 2) Open WSL2 terminal, navigate to directory: 
#		cd /mnt/c/svrtk-docker-gpu
# 3) To build SVRTK Docker GPU container using this Dockerfile:
#		docker build -t svrtk-docker-gpu -f svrtk-docker-gpu.Dockerfile .
# 4) To run SVRTK Docker GPU container:
#		docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu":/home/ svrtk-docker-gpu /home/scripts/docker-recon-brain.sh /home/cnn_test_case
#			OR interactively:
#		docker run --gpus all -it -v "/mnt/c/svrtk-docker-gpu":/home/ svrtk-docker-gpu	
#
#	Tom Roberts (t.roberts@kcl.ac.uk)
#
########################################

# Base image
#  - nb: conda/pip preconfigured
FROM pytorch/pytorch:1.9.0-cuda11.1-cudnn8-devel

# Set working directory
WORKDIR /home

# Install general libraries
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
	git wget curl unzip

# Install libraries required by MIRTK and SVRTK
RUN apt-get install -y \
	build-essential \
	cmake \
	cmake-curses-gui \
	libboost-all-dev \
	libeigen3-dev \
	libtbb-dev \
	libfltk1.3-dev

# TODO: full MIRTK / SVRTK installation from Github, rather than COPY local files?
# Install MIRTK
RUN git clone https://github.com/SVRTK/MIRTK.git /home/MIRTK

# Install SVRTK Package
COPY /MIRTK/Packages/SVRTK /home/MIRTK/Packages/SVRTK ### TODO: change to RUN git clone
RUN mkdir /home/MIRTK/build \
	&& cd /home/MIRTK/build \
	&& cmake -D WITH_TBB="ON" -D MODULE_SVRTK="ON" .. \
	&& make -j

# Update PATH
ENV PATH="$PATH:/home/MIRTK/build/bin:/home/MIRTK/build/lib/tools"

# Copy test files and scripts
COPY /recon /home/recon
COPY /scripts/docker-recon-brain.sh /home/scripts

# Copy Segmentation_FetalMRI code
COPY /Segmentation_FetalMRI /home/Segmentation_FetalMRI

# Pip
RUN python -m pip install -r /home/Segmentation_FetalMRI/requirements.txt

