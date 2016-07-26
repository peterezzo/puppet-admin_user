# admin_user class builds the common admin user for the domain
# right now ONLY supports ONE user (at least cleanly)
# authentication can be by password or by ssh only, or both
class admin_user (
  $remove_default_users = true,
  $username = false,
  $password = false,
  $ssh_key = false,
  $ssh_key_type = false,
  $user_shell = '/bin/bash',
  $user_managehome = true,
  $user_builtins = [ 'centos', 'ubuntu' ]
) {

  if $username == false {
    fail("${module_name} called without username set")
  }

  # only support RHEL-clones and Ubuntu LTS at the moment
  case $::osfamily {
    'Debian': {
      # wtf ubuntu why so many?
      $user_groups = [ 'adm', 'sudo', 'dialout', 'cdrom', 'floppy', 'audio', 'dip', 'video', 'plugdev', 'netdev' ]
    }
    'RedHat': {
      $user_groups = [ 'adm', 'wheel', 'systemd-journal' ]
    }
    default: {
      fail("The ${module_name} module is not supported on an ${::osfamily} based system.")
    }
  }

  # if password is not provided use no password (cloud instances, public github repo, etc)
  if $password {
    $user_password = $password
    $sudoer = 'ALL'
  } else {
    $user_password = '*'
    $sudoer = 'NOPASSWD:ALL'
  }

  user { $username:
    ensure     => 'present',
    name       => $username,
    managehome => $user_managehome,
    groups     => $user_groups,
    shell      => $user_shell,
    password   => $user_password,
  }

  # add a sudoers file just in case someone broke wheel
  file { "/etc/sudoers.d/${username}":
    ensure  => 'present',
    content => "${username} ALL=(ALL) ${sudoer}\n",
    mode    => '0440',
    require => User[$username],
  }

  # drop a public key in if we have one defined
  if $ssh_key and $ssh_key_type {
    ssh_authorized_key { $username:
      user    => $username,
      type    => $ssh_key_type,
      key     => $ssh_key,
      require => User[$username],
    }
  }

  # remove cloud or temporary setup users
  if $remove_default_users {
    user { $user_builtins:
      ensure     => 'absent',
      managehome => $user_managehome,
    }
  }
}
