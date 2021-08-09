
# svrtk-docker-gpu
Automated 3D UNet-driven SVR with Docker containerization 

## Installation

### Prerequisites

Minimum hardware requirements:
 - CPU with 6-8 cores
 - Nvidia GPU with 12GB video memory
 - 32 GB RAM

Required software:
- `Ubuntu or WSL2`
	- WSL2 installation instructions: https://docs.microsoft.com/en-us/windows/wsl/install-win10
	- **Important**: you <u>**must**</u> use the latest version of Windows available through the Windows Insider Program
- `CUDA v11`
	- For Ubuntu: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html
	- For WSL2: https://docs.nvidia.com/cuda/wsl-user-guide/index.html
- `Docker`
	- For WSL2: do not use Windows Docker Desktop. Instead, [Nvidia recommends using Docker-CE](https://docs.nvidia.com/cuda/wsl-user-guide/index.html#ch04-sub01-install-docker)


### Deployment on Ubuntu / WSL2

Ensure that you have the following packages installed on your system:

- `git`
- `wget`
- `docker` --- For WSL2 users there are special requirements

#### 1. Clone the repository from GitHub:

```
$ git clone https://github.com/ImperialCollegeLondon/WebMRRecon.git
$ cd svrtk-docker-gpu-dev
```

#### 2. Download the pre-trained neural network weights (nb: download file size >500Mb):

```
$ wget https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-loc-2-labels/latest.ckpt -P Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels \
	&& wget https://gin.g-node.org/SVRTK/fetal_mri_network_weights/raw/master/checkpoints-brain-loc-2-labels-cropped/latest.ckpt -P Segmentation_FetalMRI/trained-models/checkpoints-brain-loc-labels-cropped
```

#### 3. Build the container using the Dockerfile:

```
$ docker build -f svrtk-docker-gpu.Dockerfile -t svrtk-docker-gpu .
```

#### 4. Test the Docker container is running:

```
$ docker run -it svrtk-docker-gpu
```
Once inside the container, test MIRTK is working by running:

```
mirtk
```

It should output the MIRTK usage instructions.