class dopython::firewall (

  # class arguments
  # ---------------
  # setup defaults

  $port = 8000,

  # end of class arguments
  # ----------------------
  # begin class

) {

  if ($port) {
    @docommon::fireport { "0${port} Python development service":
      protocol => 'tcp',
      port     => $port,
    }
  }

}
