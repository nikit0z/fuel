$internal_virtual_ip = '10.0.126.253'
$public_virtual_ip = '10.0.215.253'
$master_hostname = 'fuel-01'
$swift_master = $master_hostname
$controller_public_addresses = {'fuel-01' => '10.0.215.3','fuel-02' => '10.0.215.4','fuel-03' => '10.0.215.5'}
$controller_internal_addresses = {'fuel-01' => '10.0.126.3','fuel-02' => '10.0.126.4','fuel-03' => '10.0.126.5'}
$swift_proxies = $controller_internal_addresses 
$floating_range = '10.0.215.128/27'
$fixed_range = '10.0.198.128/27'
$controller_hostnames = ['fuel-01', 'fuel-02', 'fuel-03']
$public_interface = 'eth2'
$internal_interface = 'eth0'
$internal_address = $ipaddress_eth0
$private_interface = 'eth1'
$multi_host = true
$network_manager = 'nova.network.manager.FlatDHCPManager'
$verbose = true
$auto_assign_floating_ip = false
$mysql_root_password     = 'nova'
$admin_email             = 'openstack@openstack.org'
$admin_password          = 'nova'
$keystone_db_password    = 'nova'
$keystone_admin_token    = 'nova'
$glance_db_password      = 'nova'
$glance_user_password    = 'nova'
$nova_db_password        = 'nova'
$nova_user_password      = 'nova'
$rabbit_password         = 'nova'
$rabbit_user             = 'nova'
$swift_user_password  = 'swift_pass'
# swift specific configurations
$swift_shared_secret  = 'changeme'
$swift_local_net_ip   = $ipaddress_eth0
$swift_proxy_address = '10.0.126.253'
$controller_node_public = $internal_virtual_ip 
$glance_backend         = 'swift'
$manage_volumes         = true 
$nv_physical_volume     = ['/dev/sdz', '/dev/sdy', '/dev/sdx'] 
$quantum                = false
$cinder                 = true
$openstack_version = {
  'keystone'   => 'latest',
  'glance'     => 'latest',
  'horizon'    => 'latest',
  'nova'       => 'latest',
  'novncproxy' => 'latest',
  'cinder' => latest,
}

Exec { logoutput => true }
stage {'openstack-custom-repo': before => Stage['main']}
include openstack::mirantis_repos

class compact_controller {
  class { 'openstack::controller_ha': 
      controller_public_addresses => $controller_public_addresses,
      public_interface        => $public_interface,
      internal_interface      => $internal_interface,
      private_interface       => $private_interface,
      internal_virtual_ip     => $internal_virtual_ip,
      public_virtual_ip       => $public_virtual_ip,
      controller_internal_addresses => $controller_internal_addresses,
      master_hostname         => $master_hostname,
      floating_range          => $floating_range,
      fixed_range             => $fixed_range,
      multi_host              => $multi_host,
      network_manager         => $network_manager,
      verbose                 => $verbose,
      auto_assign_floating_ip => $auto_assign_floating_ip,
      mysql_root_password     => $mysql_root_password,
      admin_email             => $admin_email,
      admin_password          => $admin_password,
      keystone_db_password    => $keystone_db_password,
      keystone_admin_token    => $keystone_admin_token,
      glance_db_password      => $glance_db_password,
      glance_user_password    => $glance_user_password,
      nova_db_password        => $nova_db_password,
      nova_user_password      => $nova_user_password,
      rabbit_password         => $rabbit_password,
      rabbit_user             => $rabbit_user,
      rabbit_nodes            => $controller_hostnames,
      memcached_servers       => $controller_hostnames,
      export_resources        => false,
      glance_backend          => $glance_backend,
      swift_proxies           => $swift_proxies,
      quantum                 => $quantum,
      cinder                  => $cinder,
      manage_volumes          => $manage_volumes,
      nv_physical_volume      => $nv_physical_volume,
 
      }
      class { 'swift::keystone::auth':
             password => $swift_user_password,
             public_address  => $public_virtual_ip,
             internal_address  => $internal_virtual_ip,
             admin_address  => $internal_virtual_ip,
      }

}


node /fuel-01/ {
  class { compact_controller: }
  $swift_zone = 1
  class { openstack::swift::storage-node: swift_zone => $swift_zone }
  class { openstack::swift::proxy: swift_proxies => $swift_proxies, swift_master => $swift_master, controller_node_address =>  $internal_virtual_ip }
}


node /fuel-02/ {
  class { compact_controller: }
  $swift_zone = 2
  class { openstack::swift::storage-node: swift_zone => $swift_zone }
  class { openstack::swift::proxy: swift_proxies => $swift_proxies, swift_master => $swift_master, controller_node_address =>  $internal_virtual_ip }
}


node /fuel-03/ {
  class { compact_controller: }
  $swift_zone = 3
  class { openstack::swift::storage-node: swift_zone => $swift_zone }
  class { openstack::swift::proxy: swift_proxies => $swift_proxies, swift_master => $swift_master, controller_node_address =>  $internal_virtual_ip }
}


node /fuel-0[45]/ {
    class { 'openstack::compute':
      public_interface   => $public_interface,
      private_interface  => $private_interface,
      internal_address   => $internal_address,
      libvirt_type       => 'qemu',
      fixed_range        => $fixed_range,
      network_manager    => $network_manager,
      multi_host         => $multi_host,
      sql_connection     => "mysql://nova:${nova_db_password}@${internal_virtual_ip}/nova",
      rabbit_nodes       => $controller_hostnames,
      rabbit_password    => $rabbit_password,
      rabbit_user        => $rabbit_user,
      glance_api_servers => "${internal_virtual_ip}:9292",
      vncproxy_host      => $public_virtual_ip,
      verbose            => $verbose,
      vnc_enabled        => true,
      manage_volumes     => false,
      nova_user_password	=> $nova_user_password,
      cache_server_ip         => $controller_hostnames,
      service_endpoint	=> $internal_virtual_ip,
      cinder                  => $cinder,
      ssh_private_key    => 'puppet:///ssh_keys/openstack',
      ssh_public_key     => 'puppet:///ssh_keys/openstack.pub',
 
    }
}



