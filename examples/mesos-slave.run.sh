docker run -d --net=host    \
--name=mesosslave           \ 
--cap-add=SYS_ADMIN         \
-e ENVIRONMENT=production   \
-e PARENT_HOST=$(hostname)  \
-e MESOS_IP=10.10.0.111     \
-e MESOS_MASTER=zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos  \
-e MESOS_REGISTRATION_TIMEOUT=5min    \
-e MESOS_CONTAINERIZERS=docker,mesos  \
-e MESOS_HOSTNAME=10.10.0.111         \
-e MESOS_SANDBOX_DIRECTORY=/data/mesos/sandbox   \
-e MESOS_WORKDIR=/data/mesos/workdir             \
-v /data/mesos/workdir:/data/mesos/workdir:rw    \
-v /data/mesos/sandbox:/data/mesos/sandbox:rw    \
-v /usr/bin/docker:/usr/bin/docker:ro            \
-v /var/run/docker.sock:/var/run/docker.sock:rw  \
-v /sys/:/sys:ro  \
mesos-slave
