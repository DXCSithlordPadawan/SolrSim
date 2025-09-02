Application configuration completed
 ✓ Configured Application
 - Building and Starting Services...Testing Docker Compose installation...
Using /usr/local/bin/docker-compose
Docker Compose command: /usr/local/bin/docker-compose
Docker Compose version v2.39.2
Building application (this may take a few minutes)...
WARN[0000] /opt/deployment/docker-compose.yml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion 
[+] Building 0.1s (2/2) FINISHED                                                                                           
 => [internal] load local bake definitions                                                                            0.0s
 => => reading from stdin 549B                                                                                        0.0s
 => [internal] load build definition from Dockerfile                                                                  0.0s
 => => transferring dockerfile: 669B                                                                                  0.0s
failed to solve: failed to read dockerfile: failed to mount /var/lib/docker/tmp/buildkit-mount808444603: [{Type:bind Source:/var/lib/docker/vfs/dir/zufod0yrfmcfl8fenaca1ual7 Target: Options:[rbind ro]}]: permission denied

Build failed, checking for issues...
Docker version 28.3.3, build 980b856
Client: Docker Engine - Community
 Version:    28.3.3
 Context:    default
 Debug Mode: false
 Plugins:
  buildx: Docker Buildx (Docker Inc.)
    Version:  v0.26.1
    Path:     /usr/libexec/docker/cli-plugins/docker-buildx
  compose: Docker Compose (Docker Inc.)
    Version:  v2.39.1
    Path:     /usr/libexec/docker/cli-plugins/docker-compose

Server:
 Containers: 0
  Running: 0
  Paused: 0
  Stopped: 0
 Images: 0
 Server Version: 28.3.3
 Storage Driver: vfs
 Logging Driver: json-file
 Cgroup Driver: systemd
 Cgroup Version: 2
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local splunk syslog
 CDI spec directories:
  /etc/cdi
  /var/run/cdi
 Swarm: inactive
 Runtimes: io.containerd.runc.v2 runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 05044ec0a9a75232cad458027ca83437aae3f4da
 runc version: v1.2.5-0-g59923ef
 init version: de40ad0
 Security Options:
  apparmor
  seccomp
   Profile: builtin
  cgroupns
 Kernel Version: 6.14.8-2-pve
 Operating System: Ubuntu 22.04.5 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 2
 Total Memory: 4GiB
 Name: threat-analysis
 ID: 71a67ad9-40cf-4c3d-b177-68446e406397
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Experimental: false
 Insecure Registries:
  ::1/128
  127.0.0.0/8
 Live Restore Enabled: false

 ✗ Failed to start services
