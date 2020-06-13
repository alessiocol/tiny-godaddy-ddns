# Tiny DDNS updater for GoDaddy
Dynamic DNS updater for domains registered at [GoDaddy](https://uk.godaddy.com/).
Keep your DNS record aligned with your public IP address by having a configurable cron job running inside a Docker container.
Easy to use also with Kubernetes.

The Docker image is based on [alpine](https://hub.docker.com/_/alpine) resulting in a overall size of less than 7 MB.

## Who needs this tool?
Anyone who:
- has a domain registered at GoDaddy
- wants to ensure their domain points to their public IP address
- does not have a static IP address from their Internet provider
- wants a simple and clean way to update the DNS records with Docker and Kubernetes

## Requirements
- Valid GoDaddy developer API for production environment. To obtain them refer to the dedicated [section](#Obtaining-GoDaddy-developer-credentials).
- Possibility to use Docker or Kubernetes
- 7 MB storage for storing the image

## Using with Docker
Environment variables (default in parenthesese):
```
FREQUENCY(15)   # frequency in minutes of the cron job. This variable is defined inside `Dockerfile`.
DOMAIN()        # domain name you want to update, e.g., "example.com"
TYPE(A)         # record type, e.g., "A"
NAME(@)         # name of the record to update, e.g., "@"
TTL(1800)       # time to live in seconds of the DNS record, e.g., "1800"
PORT(1)         # required port, e.g., "1"
WEIGHT(1)       # required weight, e.g., "1"
KEY()           # KEY for accessing GoDaddy developer API
SECRET()        # SECRET associated to the above KEY
```
Frequency can vary from 1 to 59 minutes, as per [standard crontab syntax](https://crontab.guru/#*/15_*_*_*_*).

### Building the image
#### Host architecture
```
docker build -t tiny-godaddy-ddns .
```
#### Multi architecture
The image supports `linux/amd64`, `linux/arm/v6`, `linux/arm/v7`, `linux/arm64`, `linux/386`, `linux/ppc64le`, `linux/s390x`.
Take a look at
```
build-multiarch.sh
```
and adjust it as needed.

### Start a container
Check every `10` min that the DNS record `@` of `example.com` is aligned with the current public IP address: 
```
docker run \
    --env KEY="GoDaddy Key" \
    --env SECRET="GoDaddy Secret"\
    --env DOMAIN="example.com"\
    --env FREQUENCY=10\
    tiny-godaddy-ddns
```
Set additional environment variables if you want to override defaults.

#### Sample output
Success:
```
$ docker run \
    --env KEY="correct key" \
    --env SECRET="correct secret" \
    --env DOMAIN="example.com" \
    --env FREQUENCY=10 
    tiny-godaddy-ddns
Cron frequency: 10 min
crond[8]: crond (busybox 1.31.1) started, log level 1
crond[8]: user:root entry:*/10 * * * * run-parts "/etc/periodic/custom"
[..]
crond[8]: child running /bin/ash
crond[7]: USER root pid   8 cmd run-parts "/etc/periodic/custom"
OK
```
Failure:
```
$ docker run \
    --env KEY="wrong key" \
    --env SECRET="wrong secret" \
    --env DOMAIN="example.com" \
    --env FREQUENCY=10 \
    tiny-godaddy-ddns
Cron frequency: 10 min
crond[8]: crond (busybox 1.31.1) started, log level 1
crond[8]: user:root entry:*/10 * * * * run-parts "/etc/periodic/custom"
[..]
]crond[8]: child running /bin/ash
crond[7]: USER root pid   8 cmd run-parts "/etc/periodic/custom"
{"code":"UNABLE_TO_AUTHENTICATE","message":"Unauthorized : Could not authenticate API key/secret"}
FAILURE! IP has NOT been updated.
run-parts: /etc/periodic/custom/run_me_no_root: exit status 1
```
### Terminate the container
The container reacts to the default `SIGTERM` signal and exists gracefully without extra actions needed.

## Using with Kubernetes
For a working Kubernetes [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) have a look at [alessiocol/k8-scripts/ddns-update](https://github.com/alessiocol/k8-scripts/blob/master/ddns-update).

## Security
Although `crond` runs with `root` priviledges, `update-ip.sh` is executed in user space. This is enforced at Docker build time by encapsulating the script into a wrapper that calls `su -s /bin/sh local -c update-ip.sh`.

Moreover, the script exits automatically if it recognizes priviledged execution.

## Error management
In case of errors (wrong credentials, lack of connection, timeout, ..) `update-ip.sh` will print the corresponding error message on `stdout` and return code `1`. However, the cron job will keep running and it is the responsibility of the operator to monitor the behaviour of the service by inspecting the logs.

## Obtaining GoDaddy developer credentials
Steps:
- Go to https://developer.godaddy.com/getstarted and create a developer account.
- Get valid **production** credentials (a KEY and a SECRET) to access the API from https://developer.godaddy.com/keys. Do not select testing (ote), otherwise changes are not exposed.
- Use the credentials as described above.
