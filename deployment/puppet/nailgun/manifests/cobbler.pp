class nailgun::cobbler(
  $cobbler_user = "cobbler",
  $cobbler_password = "cobbler",

  $centos_repos,
  $gem_source,

  $ks_system_timezone         = "Etc/UTC",

  # default password is 'r00tme'
  $ks_encrypted_root_password = "\$6\$tCD3X7ji\$1urw6qEMDkVxOkD33b4TpQAjRiCeDZx0jmgMhDYhfB9KuGfqO9OcMaKyUxnGGWslEDQ4HxTw7vcAMP85NxQe61",

  ){

  anchor { "nailgun-cobbler-begin": }
  anchor { "nailgun-cobbler-end": }

  Anchor<| title == "nailgun-cobbler-begin" |> ->
  Class["::cobbler"] ->
  Anchor<| title == "nailgun-cobbler-end" |>

  $half_of_network = ipcalc_network_count_addresses($ipaddress, $netmask) / 2

  class { "::cobbler":
    server              => $ipaddress,

    domain_name         => $domain,
    name_server         => $ipaddress,
    next_server         => $ipaddress,

    dhcp_start_address  => ipcalc_network_nth_address($ipaddress, $netmask, "first"),
    dhcp_end_address    => ipcalc_network_nth_address($ipaddress, $netmask, $half_of_network),
    dhcp_netmask        => $netmask,
    dhcp_gateway        => $ipaddress,
    dhcp_interface      => 'eth0',

    cobbler_user        => $cobbler_user,
    cobbler_password    => $cobbler_password,

    pxetimeout          => '50'
  }

  # ADDING send2syslog.py SCRIPT AND CORRESPONDING SNIPPET

  file { "/var/www/cobbler/aux/send2syslog.py":
    ensure => '/bin/send2syslog.py',
    require => Class["::cobbler::server"],
  }

  file { "/etc/cobbler/power/fence_ssh.template":
    content => template("nailgun/cobbler/fence_ssh.template.erb"),
    owner => 'root',
    group => 'root',
    mode => 0644,
    require => Class["::cobbler::server"],
  }

  file { "/usr/sbin/fence_ssh":
    content => template("nailgun/cobbler/fence_ssh.erb"),
    owner => 'root',
    group => 'root',
    mode => 0755,
    require => Class["::cobbler::server"],
  }


  # THIS VARIABLE IS NEEDED FOR TEMPLATING centos-x86_64.ks
  $ks_repo = $centos_repos

  file { "/var/lib/cobbler/kickstarts/centos-x86_64.ks":
    content => template("cobbler/kickstart/centos.ks.erb"),
    owner => root,
    group => root,
    mode => 0644,
    require => Class["::cobbler::server"],
  } ->

  cobbler_distro { "centos-x86_64":
    kernel => "${repo_root}/centos/fuelweb/x86_64/isolinux/vmlinuz",
    initrd => "${repo_root}/centos/fuelweb/x86_64/isolinux/initrd.img",
    arch => "x86_64",
    breed => "redhat",
    osversion => "rhel6",
    ksmeta => "tree=http://@@server@@:8080/centos/fuelweb/x86_64/",
    require => Class["::cobbler::server"],
  }

  cobbler_profile { "centos-x86_64":
    kickstart => "/var/lib/cobbler/kickstarts/centos-x86_64.ks",
    kopts => "biosdevname=0",
    distro => "centos-x86_64",
    ksmeta => "",
    menu => true,
    require => Cobbler_distro["centos-x86_64"],
  }

  cobbler_distro { "bootstrap":
    kernel => "${repo_root}/bootstrap/linux",
    initrd => "${repo_root}/bootstrap/initramfs.img",
    arch => "x86_64",
    breed => "redhat",
    osversion => "rhel6",
    ksmeta => "",
    require => Class["::cobbler::server"],
  }

  cobbler_profile { "bootstrap":
    distro => "bootstrap",
    menu => true,
    kickstart => "",
    kopts => "biosdevname=0 url=http://${ipaddress}:8000/api",
    ksmeta => "",
    require => Cobbler_distro["bootstrap"],
  }

  class { cobbler::checksum_bootpc: }

  exec { "cobbler_system_add_default":
    command => "cobbler system add --name=default \
    --profile=bootstrap --netboot-enabled=True",
    onlyif => "test -z `cobbler system find --name=default`",
    require => Cobbler_profile["bootstrap"],
  }

  exec { "cobbler_system_edit_default":
    command => "cobbler system edit --name=default \
    --profile=bootstrap --netboot-enabled=True",
    onlyif => "test ! -z `cobbler system find --name=default`",
    require => Cobbler_profile["bootstrap"],
  }

  exec { "nailgun_cobbler_sync":
    command => "cobbler sync",
    refreshonly => true,
  }

  Exec["cobbler_system_add_default"] ~> Exec["nailgun_cobbler_sync"]
  Exec["cobbler_system_edit_default"] ~> Exec["nailgun_cobbler_sync"]

  #FIXME: do we really need this NAT rules ?
  #  class { 'cobbler::nat': nat_range => \"$dhcp_start_address/$dhcp_netmask\" }

  #  Package<| title == "cman" |>
  # Package<| title == "fence-agents"|>
}

