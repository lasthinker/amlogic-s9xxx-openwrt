#!/usr/bin/perl

use strict;
our %irq_map;
our %cpu_map;
our %min_cpu_map;
our %uniq_eth_cpu_map;
our $all_cpu_mask = 0;

# Whether the rpscpu mask should exclude the core occupied by eth0 (0: No 1: Yes)
our $rpscpu_exclude_eth0_core=1;
# Whether the rpscpu mask should exclude the core occupied by eth1 (0: No 1: Yes)
our $rpscpu_exclude_eth1_core=1;

&read_config();
&read_irq_data();
&update_smp_affinity();
&enable_eth_rps_rfs();
exit(0);

############################## sub functions #########################
# Read /etc/balance_irq configuration file
sub read_config {
    my $cpu_count = &get_cpu_count();
    my $fh;
    my $config_file;
    if(-f "/etc/balance_irq") {
        $config_file = "/etc/balance_irq";
    } elsif(-f "/etc/config/balance_irq") {
        $config_file = "/etc/config/balance_irq";
    } else {
	exit(0);
    }

    open $fh, "<", $config_file or die $!;
    while(<$fh>) {
        chomp;
        my($name, $value) = split;
        my @cpus = split(',', $value);
        # ARMV8 The current maximum number of CPU cores is 8 cores
        my $min_cpu = 9;

        foreach my $cpu (@cpus) {
            if($cpu > $cpu_count) {
                $cpu = $cpu_count;        
            } elsif($cpu < 1) {
                $cpu = 1;
            }
            if($min_cpu > $cpu) {
                $min_cpu = $cpu;
            }
        } # foreach

        $cpu_map{$name} = \@cpus;
        $min_cpu_map{$name} = $min_cpu;
    } # while 
    close $fh;
}

# Calculate the number of cpu cores
sub get_cpu_count {
    my $fh;
    open $fh, "<", "/proc/cpuinfo" or die $!;
    my $count=0;
    while(<$fh>) {
        chomp;
        my @ary = split;
        if($ary[0] eq "processor") {
            $count++;
            $all_cpu_mask += 1<<($count-1);
        }
    }
    close $fh;
    return $count;
}

sub read_irq_data {
    my $fh;
    open $fh, "<", "/proc/interrupts" or die $!;
    while(<$fh>) {
        chomp;
        my @raw = split;
        my $irq = $raw[0];
        $irq =~ s/://;
        my $name = $raw[-1];

        if(exists $cpu_map{$name}) {
            $irq_map{$name} = $irq;
            if($name =~ m/\Aeth[0-9]\Z/) {
		# Native ethX 
                $uniq_eth_cpu_map{$name} = 1 << ($min_cpu_map{$name} - 1);
            } elsif($name =~ m/\Axhci-hcd:usb[1-9]\Z/) { # usb extend eth1
		# USB external network card: equivalent to eth1
                $uniq_eth_cpu_map{eth1} =  1 << ($min_cpu_map{$name} - 1);
            }
        }
    }
    close $fh;
}

sub update_smp_affinity {
    for my $key (sort keys %irq_map) {
        my $fh;
        my $irq = $irq_map{$key};
        my $cpus_ref = $cpu_map{$key};
        my $mask = 0;
        foreach my $cpu (@$cpus_ref) {
            $mask += 1 << ($cpu-1);
        }
        my $smp_affinity = sprintf("%0x", $mask);
        open $fh, ">", "/proc/irq/$irq/smp_affinity" or die $!;
        print "irq name:$key, irq:$irq, affinity: $smp_affinity\n";
        print $fh "$smp_affinity\n";
        close $fh;
    }
}

sub tunning_eth_ring {
    my ($eth, $target_rx_ring, $target_tx_ring) = @_;
    my $buf = `/usr/sbin/ethtool -g ${eth} 2>/dev/null`;
    if($buf) {
        $buf =~ s/\r|\n/\t/g;
        if( $buf =~ m/.+?Pre-set maximums:\s+RX:\s+(\d+).+?TX:\s+(\d+).+?Current hardware settings:\s+RX:\s+(\d+).+?TX:\s+(\d+)/) {
            my $max_rx_ring  = $1;
            my $max_tx_ring  = $2;
            my $cur_rx_ring  = $3;
            my $cur_tx_ring  = $4;

            if( ($max_rx_ring > 0) && ($target_rx_ring>0) && ($max_rx_ring > $target_rx_ring) && ($cur_rx_ring != $target_rx_ring) ) {
                system "/usr/sbin/ethtool -G ${eth} rx ${target_rx_ring} >/dev/null 2>&1";
                print "Set the rx ring of ${eth} to ${target_rx_ring}\n";
            }
            if( ($max_tx_ring > 0) && ($target_tx_ring>0) && ($max_tx_ring > $target_tx_ring) && ($cur_tx_ring != $target_tx_ring) ) {
                system "/usr/sbin/ethtool -G ${eth} tx ${target_tx_ring} >/dev/null 2>&1";
                print "Set the tx ring of ${eth} to ${target_tx_ring}\n";
            }
        }
    } 
}

sub enable_eth_rps_rfs {
    my $rps_sock_flow_entries = 0;
    for my $eth ("eth0","eth1") {
        if(-d "/sys/class/net/${eth}/queues/rx-0") {
            my $value = 32768;
            $rps_sock_flow_entries += $value;
            my $eth_cpu_mask_hex;
	    my $cpu_mask = $all_cpu_mask;
            if($rpscpu_exclude_eth0_core == 1) {
	        $cpu_mask -= $uniq_eth_cpu_map{eth0}; 
	    }
            if($rpscpu_exclude_eth1_core == 1) {
	        $cpu_mask -= $uniq_eth_cpu_map{eth1}; 
	    }
	    
            $eth_cpu_mask_hex = sprintf("%0x", $cpu_mask);
            print "Set the rps cpu mask of $eth to 0x$eth_cpu_mask_hex\n";
            open my $fh, ">", "/sys/class/net/${eth}/queues/rx-0/rps_cpus" or die;
            print $fh $eth_cpu_mask_hex;
            close $fh;

            open $fh, ">", "/sys/class/net/${eth}/queues/rx-0/rps_flow_cnt" or die;
            print $fh $value;
            close $fh;

            open my $fh, ">", "/sys/class/net/${eth}/queues/tx-0/xps_cpus" or die;
            print $fh $eth_cpu_mask_hex;
            close $fh;

            # USB external network card: eth1 (RTL8153), the best rx_ring measured in the range of 100-500, the default value is 100, after more than 500, the load of multiple CPUs will be unbalanced
            &tunning_eth_ring($eth, 192, 0) if ($eth ne "eth0");
        }
    }
    open my $fh, ">", "/proc/sys/net/core/rps_sock_flow_entries" or die;
    print $fh $rps_sock_flow_entries;
    close $fh;
}
