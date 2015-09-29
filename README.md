# - Mesos Slave -


An Ubuntu based Mesos Slave container, packaged with Logstash-Forwarder and managed by Supervisord. All parameters are controlled through environment variables, with some settings auto-configured based on the environment.

##### Version Information:

* **Container Release:** 1.1.0
* **Mesos:** 0.24.1
* **Docker:** 1.8.2-0~trusty

**Services Include:**
* **[Mesos Slave](#mesos-slave)** - Primary process that offers resources of the host to the Mesos Master(s) for scheduling and running of tasks.
* **[Logstash-Forwarder](#logstash-forwarder)** - A lightweight log collector and shipper for use with [Logstash](https://www.elastic.co/products/logstash).
* **[Redpill](#redpill)** - A bash script and healthcheck for supervisord managed services. It is capable of running cleanup scripts that should be executed upon container termination.

---
---

### Index

* [Usage](#usage)
 * [Example Run Command](#example-run-command)
* [Modification and Anatomy of the Project](#modification-and-anatomy-of-the-project)
* [Important Environment Variables](#important-environment-variables)
* [Service Configuration](#service-configuration)
 * [Mesos](#mesos)
 * [Logstash-Forwarder](#logstash-forwarder)
 * [Redpill](#redpill)
* [Troubleshooting](#troubleshooting)

---
---

### Usage

All mesos commands should be passed via environment variables (please see the [example run command](#example-run-command) below). For Mesos documentation, please see the configuration docs associated with the release here: [mesos@4ce5475](https://github.com/apache/mesos/blob/4ce5475346a0abb7ef4b7ffc9836c5836d7c7a66/docs/configuration.md)

In a local **proof of concept** environment, the only variable that **MUST** be definied is `MESOS_MASTER`.

However, that will leave the slave with a fraction of it's functionality. To run in a useful fashion, the following should be set, `ENVIRONMENT`, `MESOS_MASTER`, `MESOS_WORK_DIR`, and `MESOS_DOCKER_SANDBOX_DIRECTORY`.

* `ENVIRONMENT` - when set to `production` or `development` it will enable all services including: `mesos-master`, `logstash-forwarder`, and `redpill`.

* `MESOS_MASTER`- Informs the slave how to connect or discover the Mesos Masters. Please see the Mesos docs for the available options.

* `MESOS_WORK_DIR` - Path to the directory in which framework directories are placed.

* `MESOS_DOCKER_SANDBOX_DIRECTORY` - Path to directory used to map the sandbox to Docker containers.

In addition to the above, there are several things to note for full compatibility when operating a mesos slave in a container with docker as a supported containerizer.
 * The container should be run with `host` networking.
 * The container requires several volumes to be mounted. For compatibility purposes these should be the same location as it is on the host.
  * `/usr/bin/docker:/usr/bin/docker:ro`
  * `/var/run/docker.sock:/var/run/docker.sock:rw`
  * `/sys:/sys:ro`
  * The directory used for `MESOS_WORK_DIR` as `rw`
  * The directory used for `MESOS_DOCKER_SANDBOX_DIRECTORY` as `rw`



##### Marathon Framework and Private Registry Access
Configuring private registry access is dependant on several factors. For documentation, please visit the [Marathon Framework site directly](https://mesosphere.github.io/marathon/docs/native-docker-private-registry.html).

In either case, if you intend on baking the credentials into the image. This would be the image to do it.

---

### Example Run Command
```
docker run -d --net=host --cap-add=SYS_ADMIN \
-e ENVIRONMENT=production \
-e PARENT_HOST=$(hostname) \
-e MESOS_IP=10.10.0.111 \
-e MESOS_MASTER=zk://10.10.0.11:2181,10.10.0.12:2181,10.10.0.13:2181/mesos \
-e MESOS_REGISTRATION_TIMEOUT=5min \
-e MESOS_HOSTNAME=10.10.0.111 \
-e MESOS_DOCKER_SANDBOX_DIRECTORY=/data/mesos/sandbox \
-e MESOS_WORKDIR=/data/mesos/workdir \
-v /data/mesos/workdir:/data/mesos/workdir:rw \
-v /data/mesos/sandbox:/data/mesos/sandbox:rw \
-v /sys:/sys:ro \
-v /usr/bin/docker:/usr/bin/docker:ro \
-v /var/run/docker.sock:/var/run/docker.sock:rw \
mesos-slave

```

---
---

### Modification and Anatomy of the Project

**File Structure**
The directory `skel` in the project root maps to the root of the filesystem once the container is built. Files and folders placed there will map to their corrisponding location within the container. 

**Init**
The init script (`./init.sh`) found at the root of the directory is the entry process for the container. It's role is to simply set specific environment variables and modify any subsiquently required configuration files.

**Supervisord**
All supervisord configs can be found in `/etc/supervisor/conf.d/`. Services by default will redirect their stdout to `/dev/fd/1` and stderr to `/dev/fd/2` allowing for service's console output to be displayed. Most applications can log to both stdout and their respecively specified log file. 

In some cases (such as with zookeeper), it is possible to specify different logging levels and formats for each location.

**Logstash-Forwarder**
The Logstash-Forwarder binary and default configuration file can be found in `/skel/opt/logstash-forwarder`. It is ideal to bake the Logstash Server certificate into the base container at this location. If the certificate is called `logstash-forwarder.crt`, the default supplied Logstash-Forwarder config should not need to be modified, and the server setting may be passed through the `SERICE_LOGSTASH_FORWARDER_ADDRESS` environment variable.

In practice, the supplied Logstash-Forwarder config should be used as an example to produce one tailored to each deployment.

---
---

### Important Environment Variables

#### Defaults

| **Variable**                      | **Default**                                 |
|-----------------------------------|---------------------------------------------|
| `ENVIRONMENT_INIT`                |                                             |
| `APP_NAME`                        | `mesos-slave`                               |
| `ENVIRONMENT`                     | `local`                                     |
| `PARENT_HOST`                     | `unknown`                                   |
| `MESOS_LOG_DIR`                   | `/var/log/mesos`                            |
| `MESOS_WORK_DIR`                  |                                             |
| `SERVICE_LOGSTASH_FORWARDER`      |                                             |
| `SERVICE_LOGSTASH_FORWARDER_CONF` | `/opt/logstash-forwarder/mesos-slave.conf`  |
| `SERVICE_REDPILL`                 |                                             |
| `SERVICE_REDPILL_MONITOR`         | `mesos`                                     |

##### Description

* `ENVIRONMENT_INIT` - If set, and the file path is valid. This will be sourced and executed before **ANYTHING** else. Useful if supplying an environment file or need to query a service such as consul to populate other variables.

* `APP_NAME` - A brief description of the container. If Logstash-Forwarder is enabled, this will populate the `app_name` field in the Logstash-Forwarder configuration file.

* `ENVIRONMENT` - Sets defaults for several other variables based on the current running environment. Please see the [environment](#environment) section for further information. If logstash-forwarder is enabled, this value will populate the `environment` field in the logstash-forwarder configuration file.

* `PARENT_HOST` - The name of the parent host. If Logstash-Forwarder is enabled, this will populate the `parent_host` field in the Logstash-Forwarder configuration file.

* `MESOS_LOG_DIR` - The path to the directiory in which Mesos stores it's logs.

* `MESOS_WORK_DIR` - Path to the directory in which framework directories are placed.

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section below.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor.


---

**Environment**

* `local` (default)

| **Variable**                 | **Default**                |
|------------------------------|----------------------------|
| `MESOS_HOSTNAME`             | `<first ip bound to eth0>` |
| `SERVICE_LOGSTASH_FORWARDER` | `disabled`                 |
| `SERVICE_REDPILL`            | `enabled`                  |
| `MESOS_WORK_DIR`             | `/var/lib/mesos`           |


* `prod`|`production`|`dev`|`development`

| **Variable**                 | **Default** |
|------------------------------|-------------|
| `SERVICE_LOGSTASH_FORWARDER` | `enabled`   |
| `SERVICE_REDPILL`            | `enabled`   |


* `debug`

| **Variable**                 | **Default** |
|------------------------------|-------------|
| `SERVICE_LOGSTASH_FORWARDER` | `disabled`  |
| `SERVICE_REDPILL`            | `disabled`  |

---
---

### Service Configurations

#### Mesos-Slave

As stated in the [Usage](#usage) section, Mesos-slave configuration information can be found in the github docs releated to the Mesos Release: [mesos@4ce5475](https://github.com/apache/mesos/blob/4ce5475346a0abb7ef4b7ffc9836c5836d7c7a66/docs/configuration.md).

The actual mesos start command is passed to supervisor via the `SERVICE_MESOS_CMD` environment variable, and defaults to `mesos-slave`.

#### Mesos-Slave Environment Variables

##### Defaults

| **Variable**           | **Default**        |
|------------------------|--------------------|
| `MESOS_CONTAINERIZERS` | `docker,mesos`     |
| `MESOS_LOG_DIR`        | `/var/log/mesos`   |
| `MESOS_WORK_DIR`       |                    |
| `SERVICE_MESOS_CMD`    | `mesos-slave`      |

##### Description

* `MESOS_CONTAINERIZES` - Comma seperated list of containerizers for use with Mesos. Priority is assigned in the order in which they're passed.

* `MESOS_LOG_DIR` - The path to the directiory in which Mesos stores it's logs.

* `MESOS_WORK_DIR` - Path to the directory in which framework directories are placed.

* `SERVICE_MESOS_CMD` -  The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Comma


---

### Logstash-Forwarder

Logstash-Forwarder is a lightweight application that collects and forwards logs to a logstash server endpoint for further processing. For more information see the [Logstash-Forwarder](https://github.com/elastic/logstash-forwarder) project.


#### Logstash-Forwarder Environment Variables

##### Defaults

| **Variable**                         | **Default**                                                                            |
|--------------------------------------|----------------------------------------------------------------------------------------|
| `SERVICE_LOGSTASH_FORWARDER`         |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CONF`    | `/opt/logstash-forwarder/mesos-slave.conf`                                              |
| `SERVICE_LOGSTASH_FORWARDER_ADDRESS` |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CERT`    |                                                                                        |
| `SERVICE_LOGSTASH_FORWARDER_CMD`     | `/opt/logstash-forwarder/logstash-fowarder -cofig="${SERVICE_LOGSTASH_FOWARDER_CONF}"` |


##### Description

* `SERVICE_LOGSTASH_FORWARDER` - Enables or disables the Logstash-Forwarder service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_LOGSTASH_FORWARDER_CONF` - The path to the logstash-forwarder configuration.

* `SERVICE_LOGSTASH_FORWARDER_ADDRESS` - The address of the Logstash server.

* `SERVICE_LOGSTASH_FORWARDER_CERT` - The path to the Logstash-Forwarder server certificate.

* `SERVICE_LOGSTASH_FORWARDER_CMD` - The command that is passed to supervisor. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.

---


### Redpill

Redpill is a small script that performs status checks on services managed through supervisor. In the event of a failed service (FATAL) Redpill optionally runs a cleanup script and then terminates the parent supervisor process.

#### Redpill Environment Variables

##### Defaults

| **Variable**               | **Default** |
|----------------------------|-------------|
| `SERVICE_REDPILL`          |             |
| `SERVICE_REDPILL_MONITOR`  | `mesos`     |
| `SERVICE_REDPILL_INTERVAL` |             |
| `SERVICE_REDPILL_CLEANUP`  |             |
| `SERVICE_REDPILL_CMD`      |             |


##### Description

* `SERVICE_REDPILL` - Enables or disables the Redpill service. Set automatically depending on the `ENVIRONMENT`. See the Environment section.  (**Options:** `enabled` or `disabled`)

* `SERVICE_REDPILL_MONITOR` - The name of the supervisord service(s) that the Redpill service check script should monitor. 

* `SERVICE_REDPILL_INTERVAL` - The interval in which Redpill polls supervisor for status checks. (Default for the script is 30 seconds)

* `SERVICE_REDPILL_CLEANUP` - The path to the script that will be executed upon container termination.

* `SERVICE_REDPILL_CMD` - The command that is passed to supervisor. It is dynamically built from the other redpill variables. If overriding, must be an escaped python string expression. Please see the [Supervisord Command Documentation](http://supervisord.org/configuration.html#program-x-section-settings) for further information.


##### Redpill Script Help Text

```
root@c90c98ae31e1:/# /opt/scripts/redpill.sh --help
Redpill - Supervisor status monitor. Terminates the supervisor process if any specified service enters a FATAL state.

-c | --cleanup    Optional path to cleanup script that should be executed upon exit.
-h | --help       This help text.
-i | --inerval    Optional interval at which the service check is performed in seconds. (Default: 30)
-s | --service    A comma delimited list of the supervisor service names that should be monitored.
```
---
---

### Troubleshooting

In the event of an issue, the `ENVIRONMENT` variable can be set to `debug`.  This will stop the container from shipping logs and prevent it from terminating if one of the services enters a failed state.

For mesos itself, the `MESOS_LOGGING_LEVEL` variable can be set to `INFO` or `WARNING` to further diagnose the problem.
