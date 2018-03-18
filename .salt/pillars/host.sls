
packages:
  unzip:
    fromrepo: base,updates
  git:
    fromrepo: base,updates
  rpm-build:
    fromrepo: base,updates
  java-1.6.0-openjdk:
    fromrepo: base,updates
  java-1.6.0-openjdk-devel:
    fromrepo: base,updates
  glassfish-javamail:
    fromrepo: jpackage-generic-free
    requires:
      - pkgrepo: pkgrepo-jpackage-generic-free

jboss:
  version: 5.1.0-30.jpp6
  config:
    JBOSSCONF: default
    JBOSS_IP: 0.0.0.0
  server:
    ssl: false
  applications:
    signserver.ear:
      archive: /opt/signserver/lib/signserver.ear

signserver:
  config:
    SIGNSERVER_NODEID: {{ grains['fqdn'] }}
