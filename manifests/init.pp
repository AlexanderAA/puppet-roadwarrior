# This class sets up the base RoadWarrior VPN configuration. See the README for
# more information and usage examples.

class roadwarrior (
  $packages_strongswan  = $roadwarrior::params::packages_strongswan,
  $service_strongswan   = $roadwarrior::params::service_strongswan,
  $manage_firewall_v4   = $roadwarrior::params::manage_firewall_v4,
  $manage_firewall_v6   = $roadwarrior::params::manage_firewall_v6,
  $vpn_name             = $roadwarrior::params::vpn_name,
  $vpn_range            = $roadwarrior::params::vpn_range,
  $vpn_route            = $roadwarrior::params::vpn_route,
  $debug_logging        = $roadwarrior::params::debug_logging,
  $cert_dir             = $roadwarrior::params::cert_dir,
  $cert_lifespan        = $roadwarrior::params::cert_lifespan,
) inherits ::roadwarrior::params {


  # Ensure resources is brilliant witchcraft, we can install all the StrongSwan
  # dependencies in a single run and avoid double-definitions if they're already
  # defined elsewhere.
  ensure_resource('package', [$packages_strongswan], {
    'ensure' => 'installed',
    'before' => [ Service[$service_strongswan], File['/etc/ipsec.conf'] ]
  })

  # We need to define the service and make sure it's set to launch at startup.
  service { $service_strongswan:
    ensure => running,
    enable => true,
  }


  # StrongSwan IPSec subsystem configuration. Most of the logic that we
  # need to configure goes here.
  file { '/etc/ipsec.conf':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => template('roadwarrior/ipsec.conf.erb'),
    notify  => Service[$service_strongswan]
  }


  # Charon Configuration File
  # TODO: Adjustments to Charon config for timeouts, etc?


  # Configure firewalling and packet forwarding if appropiate
  if ($manage_firewall_v4 or $manage_firewall_v6) {
    include ::roadwarrior::firewall
  }


  # Generate CA key & cert
  exec { 'generate_ca_key':
    command  => "ipsec pki --gen --type rsa --size 4096 --outform pem > ${cert_dir}/private/strongswanKey.pem",
    creates  => "${cert_dir}/private/strongswanKey.pem",
    path     => '/bin:/sbin:/usr/bin:/usr/sbin',
    requires => File['/etc/ipsec.conf'],
  } ->

  exec { 'generate_ca_cert':
    command => "ipsec pki --self --ca lifetime ${cert_lifespan} --in ${cert_dir}/private/strongswanKey.pem --type rsa --dn \"C=NZ, O=roadwarrior, CN=${vpn_name} CA\" --outform pem > ${cert_dir}/cacerts/strongswanCert.pem",
    creates  => "${cert_dir}/cacerts/strongswanCert.pem",
    path     => '/bin:/sbin:/usr/bin:/usr/sbin',
  } ->

  # Generate VPN host key & cert
  exec { 'generate_host_key':
    command  => "ipsec pki --gen --type rsa --size 2048 --outform pem > ${cert_dir}/private/vpnHostKey.pem",
    creates  => "${cert_dir}/private/vpnHostKey.pem",
    path     => '/bin:/sbin:/usr/bin:/usr/sbin',
  } ->

  exec { 'generate_host_cert':
    command  => "ipsec pki --pub --in ${cert_dir}/private/vpnHostKey.pem --type rsa | ipsec pki --issue --lifetime ${cert_lifespan} --cacert ${cert_dir}/cacerts/strongswanCert.pem --cakey ${cert_dir}/private/strongswanKey.pem --dn \"C=NZ, O=roadwarrior, CN=${vpn_name}\" --san ${vpn_name} --flag serverAuth --flag ikeIntermediate --outform pem > ${cert_dir}/certs/vpnHostCert.pem",
    creates  => "${cert_dir}/certs/vpnHostCert.pem",
    path     => '/bin:/sbin:/usr/bin:/usr/sbin',
  }



}

# vi:smartindent:tabstop=2:shiftwidth=2:expandtab:
