{% import "java/macros.lib.sls" as java %}
{% import "jboss/macros.lib.sls" as jboss %}

{% set data = salt['pillar.get']('signserver', {}) %}
{% set version = salt['pillar.get']('signserver:version', none) %}
{% set config = salt['pillar.get']('signserver:config', {}) %}
{% set workers = salt['pillar.get']('signserver:workers', {}) %}

{# TODO: Add pkg state #}

{% if salt['match.pillar']('roles:signserver-client') %}
signserver-client:
{# { pkgs.hold_fixup('signserver-client', version) }#}
  pkg.installed:
    {% if version != None %}
    - version: {{ version }}
    {% endif %}
    - fromrepo: netway-extras
    - require:
      - pkgrepo: pkgrepo-netway-extras
{% endif %}

{% if salt['match.pillar']('roles:signserver-server') %}

signserver-server:
{# { pkgs.hold_fixup('signserver-server', version) }#}
  pkg.installed:
    {% if version != None %}
    - version: {{ version }}
    {% endif %}
    - fromrepo: netway-extras
    - require:
      - pkgrepo: pkgrepo-netway-extras
      - pkg: jbossas

{{ jboss.deploy_template('signserver-ds.xml',
    {
       'source': 'salt://signserver/files/signserver-ds.xml',
       'requires': [{
         'pkg': 'signserver-server'
       }]
    })
}}

{{ jboss.deploy_link('signserver.ear',
    {
       'archive': '/opt/signserver/lib/signserver.ear',
       'requires': [{
         'pkg': 'signserver-server'
       }]
    })
}}

/etc/sysconfig/signserver:
  file.managed:
    - source: salt://signserver/files/sysconfig
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: signserver-server

{% for script in [ 'signserver', 'signclient' ] %}
/opt/signserver/bin/{{ script }}:
  file.replace:
    - pattern: '^# Check that JAVA_HOME is set'
    - repl: '[ -f /etc/sysconfig/signserver ]&& . /etc/sysconfig/signserver'
    - require:
      - pkg: signserver-server
      - file: /etc/sysconfig/signserver

{% endfor %}

/opt/signserver/conf:
  file.directory:
    - user: root
    - group: root
    - mode: 640
    - clean: True
    - exclude_pat: 'E@(jboss)'
    - require:
      - pkg: signserver-server

/opt/signserver/conf/log4j.properties:
  file.managed:
    - source: salt://signserver/files/log4j.properties
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: signserver-server
    - require_in:
      - file: /opt/signserver/conf

/opt/signserver/conf/jboss/jndi.properties:
  file.managed:
    - source: salt://signserver/files/jndi.properties
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: signserver-server
    - require_in:
      - file: /opt/signserver/conf

{% for id, data in workers.iteritems() %}
{# TODO: Validate id as integer > 0 #}
{%  set config = {} -%}
{%  set workername = data.NAME|default(id) -%}
{%  set filepath = '/opt/signserver/conf/%s.properties'|format(workername) -%}
{%  set extra = {
      'user': 'root',
      'group': 'root',
      'mode': 640,
      'require': [{ 'pkg': 'signserver-server' }],
      'require_in': [{ 'file': '/opt/signserver/conf' }] }
-%}
{%  for key, value in data|default({})|dictsort -%}
{%    if key.startswith('_') -%}
{%      do config.update({ (('GLOB.WORKER%d.%s'|format(id, key|replace('_', '', 1))).encode('ascii')): value }) -%}
{%    else -%}
{%      do config.update({ (('WORKER%d.%s'|format(id, key|upper)).encode('ascii')): value }) -%}
{%    endif -%}
{%  endfor -%}
{{  java.properties(filepath, config, extra) }}

'signserver::worker::{{ workername }}':
  cmd.wait:
    - name: |
        /opt/signserver/bin/signserver setproperties /opt/signserver/conf/{{ workername }}.properties
        /opt/signserver/bin/signserver reload {{ id }}
    - watch:
      - file: {{ filepath }}
{% endfor %}

{% if config|length > 0 %}
{% set extra = { 
     'require_in': [{ 
      'service': 'jbossas'
     }] 
   } 
%}
{{ java.properties('/etc/signserver/signserver.conf', config, extra) }}
{% endif %}

{% endif %}
