
# SVRTK Docker
This repository provides a Docker-containerized SVRTK package for performing automated 3D UNet-driven slice-to-volume registration (SVR) reconstruction. The user supplies multi-stack T2-weighted single shot fast spin echo fetal brain scans (acquired on a 1.5T or 3T scanner) NIFTI format, which are automatically reconstructed into a motion-corrected, super-resolution 3D SVR volume.

The container can be run on the CPU, or GPU-acceleration can be used for faster reconstruction times.


## Prerequisites
Minimum hardware requirements:
 - CPU with 6 cores
 - 16 GB RAM
 - For GPU-accelerated reconstruction: Nvidia GPU with 12GB video memory
 - At least 30GB free disk space

Recommended hardware requirements:
- CPU with ≥10 cores
- ≥32GB RAM
- Nvidia GPU with ≥12GB video memory

Required software:
- `Ubuntu or WSL2 (if Windows user)`
	- Tested on WSL2 running Ubuntu 20.04 (other distributions may work, but have not been tested)
	- WSL2 installation instructions: https://docs.microsoft.com/en-us/windows/wsl/install-win10
		- WSL2 requires: Windows 10 version 2004 and higher (Build 19041 and higher) or Windows 11
- `Docker (CE edition)`
	- For WSL2, do **not** use Windows Docker Desktop. Instead, [Nvidia recommends using Docker-CE](https://docs.nvidia.com/cuda/wsl-user-guide/index.html#ch04-sub01-install-docker)

Ensure that you have the following packages installed on your system:
- `git`
- `wget`
&nbsp;

Optional software, for GPU-acceleration:
- `CUDA v11`
	- For Ubuntu: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html
	- For WSL2: https://docs.nvidia.com/cuda/wsl-user-guide/index.html
	- **Important**: for GPU-accelerated reconstruction, you must use either Windows 11, or you may need to use the latest version of Windows available through the Windows Insider Program. Consult the Nvidia CUDA documentation for the latest advice regarding this.





## Installation
Users can either install a pre-built SVRTK Docker image (tag: svrtk-docker-gpu @ https://hub.docker.com/repository/docker/fetalsvrtk/svrtk, ), or build the container from source. In both cases, users should first clone this repository as it creates the folder structure required by the Docker container.

#### Clone the repository from GitHub:
WSL2 users (we recommend installing on the C:\ drive):
```
git clone --recurse-submodules https://github.com/SVRTK/svrtk-docker-gpu.git /mnt/c
```

Ubuntu users (we recommend installing in your user directory):
```
git clone --recurse-submodules https://github.com/SVRTK/svrtk-docker-gpu.git /home/$USER
```
&nbsp;

### Option 1 --- Install using pre-built Docker image
#### 1.1 Download the pre-built Docker image from DockerHub:
```
docker pull fetalsvrtk/svrtk:pride-svr-docker-0.2.0
```
#### 1.2 Test the Docker container is working:

```
docker run -it fetalsvrtk/svrtk:pride-svr-docker-0.2.0
```
Once inside the container, test MIRTK is working by running:

```
mirtk
```

It should output the MIRTK usage instructions.
&nbsp;

### Option 2 --- Build from source
#### 2.1 Enter the svrtk-docker-gpu directory:
For WSL2 users:
```
cd /mnt/c/svrtk-docker-gpu
```
For Ubuntu users:
```
cd /home/$USER/svrtk-docker-gpu
```

#### 2.2 Download the pre-trained neural network weights and brain atlases (nb: download file size >500Mb):
```
wget https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-loc-2-labels/latest.ckpt -P Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels \
	&& wget https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-loc-2-labels-cropped/latest.ckpt -P Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels-cropped \
	&& wget https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-reo-5-labels/latest.ckpt -P Segmentation_FetalMRI/trained-models/checkpoints-brain-reorientation \
	&& wget https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-reo-5-labels-raw-stacks/latest.ckpt -P Segmentation_FetalMRI/trained-models/checkpoints-brain-reorientation-stacks
```

#### 2.3 Build the container using the Dockerfile:

```
docker build -f svrtk-docker-gpu.Dockerfile -t fetalsvrtk/svrtk:pride-svr-docker-0.2.0 .
```

#### 2.4 Test the Docker container is working:

```
docker run -it fetalsvrtk/svrtk:pride-svr-docker-0.2.0
```
Once inside the container, test MIRTK is working by running:

```
mirtk
```

It should output the MIRTK usage instructions.


## Usage

#### Run automated SVR

Copy nifti files (labelled `stack1.nii.gz`, `stack2.nii.gz`, ... `stackN.nii.gz`) into the `svrtk-docker-gpu/recon` folder.

Then:

```
docker run -v "svrtk-docker-gpu/recon":/home/recon fetalsvrtk/svrtk:pride-svr-docker-0.2.0 /home/scripts/docker-recon-brain-auto.bash /home/recon
```

This will output a 3D SVR-reconstructed volume named `SVR-output.nii.gz`.
&nbsp;

##### Optional:
If you have successfully installed CUDA, you can run the GPU-accelerated version with:
```
docker run -it --gpus all -v "svrtk-docker-gpu/recon":/home/recon fetalsvrtk/svrtk:pride-svr-docker-0.2.0 /home/scripts/docker-recon-brain-auto.bash /home/recon
```
