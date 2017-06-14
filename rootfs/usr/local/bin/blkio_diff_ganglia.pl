#!/usr/bin/perl
#

if( $#ARGV < 0 ){
  print "$#ARGV\n";
  die("Usage: blkio_diff.pl <sleeptime> \n");
  }


use Proc::PID::File;
# creates blkio_diff.pl.pid in /var/tmp
die "Already running!" if Proc::PID::File->running(dir=>"/var/run/nagios/");



### can't use this, API seems to have changed
#use Ganglia::Gmetric::PP;
#my $gmetric = Ganglia::Gmetric::PP->new(host => '10.0.0.94', port => 8649);
#my $gmetric = Ganglia::Gmetric::PP->new(host => '10.0.0.94', port => 9999);

my %stats, %old_stats;
my $sleeptime=$ARGV[0];


sub get_stats(){
   undef %tmpstats;

   my %tmpstats, $disk, $atype, $bytes;
   #open ( CGROUPFILE, "/sys/fs/cgroup/blkio/blkio.io_service_bytes_recursive" ); 
   open ( CGROUPFILE, "/sys/fs/cgroup/blkio/blkio.throttle.io_service_bytes" ); 
   while(<CGROUPFILE>){
   /^[0-9]/ || next; # omit the grand "Total" line
     ($disk, $atype, $bytes)=split;
     # we want the sum over all disks
     $tmpstats{$atype}+=$bytes;
     }
   close (CGROUPFILE);
   return %tmpstats;
}


%stats=get_stats();
%old_stats=%stats;

$stats{"Total"}  or die "No disks found"; # exit on any diskless nodes


while(true){

 sleep($sleeptime);

 %stats=get_stats();
 my $bytesprosec;

 foreach  $key (keys %stats) {

 #  print "$key: ";
 #  print $stats{$key}-$old_stats{$key};
 #  print "\n";
 ##  use constant {
 ##  GANGLIA_SLOPE_BOTH              => 3, # can be anything
 ##  GANGLIA_VALUE_UNSIGNED_INT      => 'uint32'
 ##};
 #
  #$gmetric->send($type, $name, $value, $units, $slope, $tmax, $dmax);
  #$gmetric->send(GANGLIA_VALUE_UNSIGNED_INT, "Diskstats-$key", $stats{$key}-$old_stats{$key} , "bytes/$sleeptime s", GANGLIA_SLOPE_BOTH  , $sleeptime , 0);
 #  $gmetric->send("$hostname"."Diskstats-$key\0".GANGLIA_VALUE_UNSIGNED_INT, "Diskstats-$key", $stats{$key}-$old_stats{$key} , "bytes/$sleeptime s", GANGLIA_SLOPE_BOTH  , 300 , 0);
 #  print "GANGLIA_VALUE_UNSIGNED_INT, Diskstats-$key, ".($stats{$key}-$old_stats{$key})." , bytes/$sleeptime s, GANGLIA_SLOPE_BOTH  , 300 , 0\n";  
 #
  $bytesprosec=int(($stats{$key}-$old_stats{$key})/$sleeptime);
   #print "$key: $bytesprosec (int(($stats{$key}-$old_stats{$key})/$sleeptime)\n";

   system("/bin/gmetric","--name=Diskstats-$key","--value=".$bytesprosec, "--type=uint32", "--tmax=$sleeptime", "--group=disk");

  }

%old_stats=%stats;

}
