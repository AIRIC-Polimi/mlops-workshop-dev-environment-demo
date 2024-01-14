# How to use

* Navigate to the aws-ec2-finetuning directory (`cd infrastructure/aws-ec2-finetuning` in Linux)
* Initialize terraform by running `terraform init`
* launch the EC2 instance with `terraform apply` (if you need to provide custom variables - such as an AWS profile different from `default` - you can do it with the `-var "NAME=VALUE"` option, for instance `terraform apply -var "aws_profile=myprofilename"`)
* wait for terraform to complete, and then for the EC2 user data script to install everything (e.g., docker, git); it may take a few minutes
* update you ssh config file (located in `~/.ssh/config` in Linux) with the following configuration (substitute `EC2_INSTANCE_IP_TERRAFORM_OUTPUT` with the actual output from terraform and `PATH_TO_THIS_FOLDER` with the absolute path of the folder containing this README):

```
Host ec2-gpu
   HostName EC2_INSTANCE_IP_TERRAFORM_OUTPUT
   User ec2-user   
   IdentityFile PATH_TO_THIS_FOLDER/ssh_private_key.pem
   ForwardAgent yes
```

Alternatively, you can use the interactive prompt from the VSCode Remote-SSH extension to configure the new host, by launching the command `Remote-SSH: Connect to Host...` and then `add new host`.

* start the ssh-agent and add you github ssh key (in Linux, `eval "$(ssh-agent -s)" && ssh-add ~/.ssh/SSH_KEY_NAME`
* connect via ssh to the EC2 instance (e.g., `ssh ec2-gpu` if you configured the ssh config file following the example) to check that everything is ok
  * you can check that Docker is running by runnning `docker run --rm hello-world`
  * you can check that the Nvidia drivers and Nvidia Docker have been correctly installed and are working by runnning `docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi`
  * you can check that tensorflow within Docker is able to access the GPU by runnning `docker run -it --rm --gpus all tensorflow/tensorflow:2.13.0-gpu python -c 'import tensorflow as tf; print(tf.config.list_physical_devices("GPU"))'` (the expected output, ignoring warnings, is a non-empty array like `[PhysicalDevice(name='/physical_device:GPU:0', device_type='GPU')]`)
* clone this repo from github (`git clone git@github.com:AIRIC-Polimi/mlops-workshop-dev-environment-demo.git`)
* open VSCode locally, and then use the Remote-SSH extension to connect to the EC2 instance (`Remote-SSH: Connect to Host...`, and then select the name of the host you previously configured, e.g. `ec2-gpu`)
* uncomment the `runArgs` in `.devcontainer/devcontainer.json` to enable mounting GPU devices (unfortunately there's no support as of now to do this automatically)
* open the repo folder and then hit `Reopen in container` when prompted
* wait for the docker image to be built (it should take a few minutes)
* once you are inside the devcontainer, create a new `.aws/credentials` file and fill it with the same AWS credentials you use in the local devcontainer
* pull all data with DVC (`dvc pull`)
* now you should be able to launch any finetuning pipeline

To shut down the ec2 instance follow the following instructions:
* exit from VSCode
* run the command `terraform destroy -var "aws_profile=MYPROFILE"`
