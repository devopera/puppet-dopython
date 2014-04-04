class dopython::dev (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',  
  $port = 8000,
  
  $firewall = true,

  # end of class arguments
  # ----------------------
  # begin class

) {

  # open firewall ports
  if ($firewall) {
    class { 'dopython::firewall' :
      port => $port, 
    }
  }

}