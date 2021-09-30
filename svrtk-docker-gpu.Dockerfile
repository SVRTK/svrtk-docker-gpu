### svrtk-docker-gpu Dockerfile
#
#   - Requires Git repo download from: https://github.com/SVRTK/svrtk-docker-gpu
#
#	Tom Roberts (t.roberts@kcl.ac.uk)
#
########################################

# Base image
FROM pytorch/pytorch:1.9.0-cuda11.1-cudnn8-devel

# Set working directory
WORKDIR /home

# Install general libraries
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
	git wget curl unzip pigz dcmtk

# Install libraries required by MIRTK and SVRTK
RUN apt-get install -y \
	build-essential \
	cmake \
	cmake-curses-gui \
	libboost-all-dev \
	libeigen3-dev \
	libtbb-dev \
	libfltk1.3-dev

# Install dcm2niix
RUN git clone -b development --single-branch https://github.com/rordenlab/dcm2niix.git /home/dcm2niix \
	&& cd /home/dcm2niix \
	&& mkdir build && cd build \
	&& cmake .. \
	&& make
	
ENV PATH="$PATH:/home/dcm2niix/build/bin"

# Install MIRTK/SVRTK
COPY /MIRTK /home/MIRTK
RUN mkdir /home/MIRTK/Packages/SVRTK
COPY /SVRTK /home/MIRTK/Packages/SVRTK
RUN mkdir /home/MIRTK/build \
	&& cd /home/MIRTK/build \
	&& cmake -D WITH_TBB="ON" -D MODULE_SVRTK="ON" .. \
	&& make -j
	
ENV PATH="$PATH:/home/MIRTK/build/bin:/home/MIRTK/build/lib/tools"

# Copy Git repo directories
COPY /scripts /home/scripts
COPY /Segmentation_FetalMRI /home/Segmentation_FetalMRI

# Set Executable Permissions
RUN chmod +x /home/scripts/*

# Copy Pre-trained Model Weights
COPY /Segmentation_FetalMRI/trained-models /home/Segmentation_FetalMRI/trained-models

# Copy Reorientation Templates
COPY /Segmentation_FetalMRI/reference-templates /home/Segmentation_FetalMRI/reference-templates

# Pip
RUN python -m pip install -r /home/Segmentation_FetalMRI/requirements.txt
