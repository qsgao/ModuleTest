# Test code for module CLI
#! /usr/bin/expect 
package require Expect
#exp_internal 1
set conf(com_port) "/dev/ttyUSB1"
set conf(console_settings) "115200,n,8,1"
set conf(prof_ct) 10
set conf(scan_ct) 20

set mod "none"
set next_scan 0
set next_prof 0
set prompt "-->"
set stats(passed) 0
set stats(failed) 0
set stats(cases_passed) 0
set stats(cases_failed) 0
set pass_cases 0
set fail_cases 0
set count 1
set errmsg1 "unknown"
set timeout 20
set testfile "/home/jasongao/test/cmdlog.txt"
set logfile [open $testfile w]
global timeout
global pass_cases
global fail_cases
global errmsg1
global logfile
global prompt

proc console_start {} {
    global conf
    global spawn_id
    global mod

    send_user "using $conf(com_port) settings $conf(console_settings)\n"
    if [catch {
	    set op "open"
	    set fd [open $conf(com_port) r+]

	    set op "config $conf(console_settings)"
	    fconfigure $fd -mode $conf(console_settings) -handshake none

	    set op "spawn"
	    spawn -open $fd

	    set mod $spawn_id
    }] {
	    error "failed to open $conf(com_port) op $op"
    }
}

proc send_mod {cmd} {
    global mod

    send -i $mod "$cmd\r"
}

proc send_cmd {cmd} {
    global mod
    global spawn_id
    global prompt
    set spawn_id $mod
    send_mod $cmd

    expect {
	    "*$prompt" {
	      send "gets the prompt"
	    } "*id*" {
	      send "get the id" 
	    } "*->*" {
	      send "get the prompt"
	    } timeout {
		    error "timeout"
	    }
    }
    close $myfile
}

proc set_profile {l id} {
    puts "try to set profile $id"
    foreach p $l {
            sleep 2
            send_mod "wifi profile $p"
	if {$id == $p} {
            send_mod "wifi profile enable"
	} else {
            send_mod "wifi profile disable"
	}
    }

    send_mod "wifi disable"
    sleep 2
    send_mod "wifi enable"
    sleep 4
}

proc exct_cmd {cmd rslt} {
    global mod
    global spawn_id
    global prompt
    global pass_cases
    global fail_cases
    global errmsg1
    global logfile
    global count
    set matched ""

    set spawn_id $mod
    send_mod $cmd

    expect {
	    "*$rslt*" {
	      set tmpbuf $expect_out(buffer)
	      set matched [substring $tmpbuf $rslt]
	      incr pass_cases
	      puts $logfile "========Test case $count passed========\n"
	      puts $logfile "Command: $cmd\nOutput results:\n"
	      puts $logfile "$matched\n"
	    } timeout {
	      incr fail_cases
	      puts $logfile "--------Test case $count failed--------\nCommand: $cmd\nOutput results:\n"
	      send_mod $cmd
	      expect * {
		 puts $logfile "$expect_out(buffer)\n"
	      }
	    }
    }

    incr count
}

proc exct_cmd_negative {cmd rslt} {
    global mod
    global spawn_id
    global prompt
    global pass_cases
    global fail_cases
    global errmsg1
    global logfile
    global count
    set matched ""

    set spawn_id $mod
    send_mod $cmd

    expect {
	    "*$rslt*" {
	      set tmpbuf $expect_out(buffer)
	      set matched [substring $tmpbuf $rslt]
	      incr fail_cases
	      puts $logfile "--------Test case $count failed--------\nCommand: $cmd\nOutput results:\n"
	      puts $logfile "$matched\n"
	    } timeout {
	      incr pass_cases
	      puts $logfile "========Test case $count passed========\n"
	      puts $logfile "Command: $cmd\nOutput results:\n"
	      send_mod $cmd
	      expect * {
		 puts $logfile "$expect_out(buffer)\n"
	      }
	    }
    }

    incr count
}

proc substring {orig sub} {
    set start 0
    set end 0
    set str ""
    set sublen [string length $sub]
    set origlen [string length $orig]

    for {set i 0} {$i < $sublen} {incr i} {
        if {[string index $sub $i] == "*"} {
	    if {$start == 0} {
               set start $i
	    }
            set end $i
	}
    }
    if {$end == 0} {
       return $sub
    }
    set wdstart [string range $sub  0 $start-1]
    set wdend [string range $sub $end+1 $sublen-1]
    set start [string first $wdstart $orig]
    set end [string last $wdend $orig]
    if {$start == -1 || $end == -1} {
        return ""
    }
    set len [string length $wdend]
    set end [ expr {$end+$len-1}]
    set str [string range $orig $start $end]
    return $str
}

proc test_alive {} {
    global mod
    global spawn_id
    global prompt

    set spawn_id $mod
    send_mod ""
    expect {
	    "*setup-> " {
		    puts "setup mode"
		    error "not in simulation mode"
	    } "*mfg-> " {
		    puts "mfg mode"
		    set prompt "mfg-> "
		    error "not in simulation mode"
	    } "*sim-> " {
		    puts "simulation mode"
		    set prompt "sim-> "
	    } timeout {
		    puts "timeout"
		    send_mod ""
	    }
    }
}

proc make_scan {ssid bssid sec sig delay} {
    global next_scan

    send_cmd "scan entry $next_scan ssid \"$ssid\" bssid $bssid "
    send_cmd "scan security $sec rssi $sig delay $delay enable"
    incr next_scan
}

proc reset_scan {} {
    global next_scan
    global conf

    send_cmd "sim reset scan"
    set next_scan 0
}

proc make_ap_prof {ssid sec key} {
    send_cmd "wifi profile ap ssid \"$ssid\" \
	    security $sec key \"$key\" profile enable"
}

proc make_prof {ssid sec key} {
    global next_prof

    send_cmd "wifi profile $next_prof ssid \"$ssid\" \
	    security $sec key \"$key\" profile enable"
    incr next_prof
}

proc reset_prof {} {
    global next_prof
    global conf

    send_cmd "sim reset profile"
    set next_prof 0
}

proc reset {} {
    global next_prof
    global next_scan
    global conf

    send_cmd "sim reset"
    set next_prof 0
    set next_scan 0
}

proc wait_run_done {} {
    global stats

    expect {
    -re	"netsim: run complete events \(\[0-9\]*\) passed, \(\[0-9\]*\) failed" {
		    set passed $expect_out(1,string)
		    set failed $expect_out(2,string)
		    incr stats(passed) $passed
		    incr stats(failed) $failed
		    if ($failed) {
			    incr stats(cases_failed)
		    } else {
			    incr stats(cases_passed)
		    }
		    return
	    } timeout {
		    error "netsim timed out"
	    }
    } 
}

lappend cases scan1
proc test_scan1 {} {
    make_scan ex1 00:00:00:00:00:01 WPA2_Personal -10 10
    make_scan ex2 00:00:00:00:00:02 WEP -10 11
    make_scan ex3 00:00:00:00:00:03 WPA2_Personal -11 12
    send_cmd "scan time 100"
    make_prof ex2 WEP ABCDEFabcd
    send_cmd "sim expect wifi scan" 
    send_cmd "sim expect wifi join SSID ex2"
}

lappend cases scan2
proc test_scan2 {} {
    make_ap_prof Ayla-000000000001 WPA2_Personal ABCDEFabcd
    make_prof ex2 WEP ABCDEFabcd
    send_cmd "sim expect wifi scan"
    send_cmd "sim expect wifi start_ap" 
}

lappend cases scan3
proc test_scan3 {} {
    global timeout

    set timeout 100
    make_scan ex1 00:00:00:00:00:01 WPA2_Personal -10 10
    make_scan ex2 00:00:00:00:00:02 WEP -10 11
    make_scan ex3 00:00:00:00:00:03 WPA2_Personal -11 12
    make_scan ex2 00:00:00:00:00:04 WEP -9 14
    send_cmd "scan time 100"
    make_prof ex1 none ""
    make_prof ex2 WEP ABCDEFabcd
    make_prof ex3 none "wpa key 123"
    make_ap_prof Ayla-000000000001 WPA2_Personal ABCDEFabcd
    #
    # expects should be in expected order of occurrence
    #
    send_cmd "sim expect wifi scan" 
    send_cmd "sim expect wifi join SSID ex2"
    send_cmd "sim expect wifi join SSID ex3"
    send_cmd "sim expect wifi start_ap"
}

proc test_run_raw {case} {
    send_user "\n\nSetting up for $case\n"
    send_cmd "wifi disable"
    reset
    eval test_$case
    send_cmd "sim run --event_stop 40000"
    send_cmd "wifi enable"
    wait_run_done
}

proc test_run {case} {
    global stats

    if [catch { test_run_raw $case } rc errinfo ] {
	    incr stats(failed)
	    incr stats(cases_failed)
	    send_user "\nFAIL: case $case failed - $rc\n"
	    set err_info [dict get $errinfo -errorinfo]
	    send_user "\nFAIL: $err_info\n"
    }
    send_cmd "wifi disable"
}

set ShowCmd {"show id" "show test_status" "show"  "show wifi" "show spi" "show version" "show oem"}
set ShowRslt {"id: model*ser*mac*680001b" "test_status:*complete*7358" "usage*support*test_status" "Wi-Fi*pro*scan*AP" "SPI*rx*tx*retry" "bc*ID*c6d+ sim" "oem*oem_model:"}
set WiFiProCmd {"wifi profile 0" "wifi profile 1" "wifi profile 2" "wifi profile 3" "wifi profile 4" "wifi profile 5" "wifi profile 6" "wifi profile 7" "wifi profile 8" "wifi profile 9" "wifi profile ap" "wifi profile enable" "wifi profile disable" "wifi profile AP" "wifi profile -1" "wifi profile 10" "wifi profile a"}
set WiFiProRslt {"-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "invalid value" "invalid value" "invalid value" "invalid value"}
set WiFiSecCmd { "wifi security WEP" "wifi security WPA2_Personal" "wifi security WPA" "wifi security none" "wifi security null" "wifi security 1" "wifi security" "wifi security NONE"}
set WiFiSecRslt { "-->" "-->" "-->" "-->" "invalid value"  "invalid value"  "usage*ssid*profile*enable" "invalid value"}
set SecuritySet {"wifi profile 0" "wifi security WPA2_Personal" "wifi ssid Ayla" "wifi key ayla123" "wifi profile enable" "wifi profile 2" "wifi ssid Ayla-test2" "wifi security WEP" "wifi profile enable"}
set SecurityRslt {"-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->"}
set WiFiAntCmd {"wifi ant 0" "wifi ant 1" "wifi ant 3" "wifi ant -1" "wifi ant 4" "wifi ant 2"}
set WiFiAntRslt {"-->" "-->" "-->" "invalid value" "invalid value" "invalid value"}
set WiFiSsidCmd {"wifi ssid ayla" "wifi ssid 123" "wifi ssid a" "wifi ssid 0" "wifi ssid" "wifi ssid -1" "wifi ssid abcdefghijklmnopqrstuvwxyz123456" "wifi ssid '"  "wifi ssid abcdefghijklmnopqrstuvwxyz1234567"}
set WiFiSsidRslt {"-->" "-->" "-->" "-->" "invalid value" "-->" "-->"  "-->" "-->"}
set ProfileSet { "wifi profile 2" "wifi ssid Ayla-test2" "wifi profile enable" "show wifi" "wifi profile 0" "wifi ssid hello" "wifi profile enable" "show wifi"  "wifi profile 8" "wifi ssid \"quotesid\" " "wifi profile enable" }
set ProfileRslt { "-->" "-->" "-->" "Wi-Fi*profiles*2*Ayla-test2*AP"  "-->" "-->" "-->" "Wi-Fi*profiles*0*hello*AP" "-->" "-->" "-->" }
set WiFiAntSetCmd {"wifi ant 0" "wifi disable" "wifi enable" "rssi" "wifi ant 1" "wifi disable" "wifi enable" "rssi" "wifi ant 3" "wifi disable" "wifi enable" "rssi"}
set WiFiAntSetRslt {"-->" "-->" "-->" "wifi*txant 0" "-->" "-->" "-->" "wifi*txant 1" "-->" "-->" "-->" "wifi*txant 3"}
set WiFiKeyCmd {"wifi key abc" "wifi key 123" "wifi key ab012@" "wifi key -1" "wifi key 0" "wifi key a" "wifi key abcdefghijkl&-mnopqrst#$" "wifi key abcdefghijklmnopqrstuvwxyz1234abcdefghijklmnopqrstuvwxyz1234" "wifi key ~" "wifi key abcdefghijklmnopqrstuvwxyz1234abcdefghijklmnopqrstuvwxyz12345"}
set WiFiKeyRslt {"-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "-->" "invalid value"}

#
# Main program
#
puts $logfile "           Test Results for module CLI\n"
console_start
sleep 5
puts $logfile "**************************************************"
puts $logfile "*         Test suite for 'reset' command         *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "reset" "mod: bc init done"
sleep 4

puts $logfile "**************************************************"
puts $logfile "*          Test suite for 'run' command          *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "run flup" "<>"
send_mod "reset"
sleep 4
send_mod ""
exct_cmd "run mod" "mod:*bc*init*done"
sleep 2

puts $logfile "**************************************************"
puts $logfile "*          Test suite for 'id' command           *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "id serial AC000W000000261" "not*mfg*mode"

puts $logfile "**************************************************"
puts $logfile "*       Test suite for 'mfg_mode' command        *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "mfg_mode disable" "not*mfg*mode"

puts $logfile "**************************************************"
puts $logfile "*      Test suite for 'setup_mode' command       *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "setup_mode disable" "not*setup*mode"

puts $logfile "**************************************************"
puts $logfile "*         Test suite for 'show' command          *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
foreach c $ShowCmd r $ShowRslt {
    exct_cmd $c $r
}

puts $logfile "**************************************************"
puts $logfile "*         Test suite for 'save' command          *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "wifi save_on_ap_connect 0" "-->"
exct_cmd "wifi save_on_ap_connect 1" "-->"
exct_cmd "wifi save_on_ap_connect -1" "invalid*value"
exct_cmd "wifi save_on_ap_connect 2" "invalid*value"
exct_cmd "wifi save_on_ap_connect c" "invalid*value"
exct_cmd "wifi save_on_server_connect 0" "-->"
exct_cmd "wifi save_on_server_connect 1" "-->"
exct_cmd "wifi save_on_server_connect -1" "invalid*value"
exct_cmd "wifi save_on_server_connect 2" "invalid*value"
exct_cmd "wifi save_on_server_connect a" "invalid*value"

puts $logfile "**************************************************"
puts $logfile "*     Test suite for 'wifi profile' command      *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
foreach c $WiFiProCmd r $WiFiProRslt {
    exct_cmd $c $r
}

puts $logfile "**************************************************"
puts $logfile "*      Test suite for 'wifi ssid' command        *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
foreach c $WiFiSsidCmd r $WiFiSsidRslt {
    exct_cmd $c $r
}

puts $logfile "**************************************************"
puts $logfile "*     Test suite for 'wifi mac_addr' command     *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
exct_cmd "wifi mac_addr 60e95680001c" "-->"
exct_cmd "wifi mac_addr 60:e9:56:80:00:1c" "-->"
exct_cmd "wifi mac_addr 60h95680001c" "invalid*value"
exct_cmd "wifi mac_addr 60E95680001c" "invalid*value"
exct_cmd "wifi mac_addr 60e956" "invalid*value"
exct_cmd "wifi mac_addr " "usage*suppo*enable"
exct_cmd "wifi mac_addr 60e95680001c2" "invalid*value"
exct_cmd "wifi mac_addr 60e9568000#c" "invalid*value"
exct_cmd "wifi mac_addr 0" "invalid*value"

puts $logfile "**************************************************"
puts $logfile "*     Test suite for 'wifi Security' command     *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
foreach c $WiFiSecCmd r $WiFiSecRslt {
    exct_cmd $c $r
}

puts $logfile "**************************************************"
puts $logfile "*       Test suite for 'wifi ant' command        *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
foreach c $WiFiAntCmd r $WiFiAntRslt {
    exct_cmd $c $r
}

puts $logfile "**************************************************"
puts $logfile "*       Test suite for 'wifi key' command        *"
puts $logfile "*               (single command)                 *"
puts $logfile "**************************************************"
foreach c $WiFiKeyCmd r $WiFiKeyRslt {
    exct_cmd $c $r
}

puts $logfile "**************************************************"
puts $logfile "*    Test suite to create/update wifi profile    *"
puts $logfile "**************************************************"
foreach c $ProfileSet r $ProfileRslt {
    exct_cmd $c $r
}
exct_cmd "show wifi" "Wi-Fi*profil*Index*8*quotes*scan*AP"

puts $logfile "**************************************************"
puts $logfile "*   Test suite to set wifi Security for profile  *"
puts $logfile "**************************************************"
puts $logfile "Pre-test execution: disable and enable wifi"
set prolist {"ap" "0" "2" "5"}
set_profile $prolist "5"
send_mod "wifi disable"
sleep 2
send_mod "wifi enable"
sleep 4
foreach c $SecuritySet r $SecurityRslt {
    exct_cmd $c $r
}
puts $logfile "Pre-test execution: disable and enable wifi"
send_mod "wifi disable"
sleep 2
send_mod "wifi enable"
sleep 6
exct_cmd "show wifi" "Wi-Fi*idle*scan*AP"
exct_cmd "wifi profile 0" "-->"
exct_cmd "wifi key @ayla123" "-->"
exct_cmd "wifi profile enable" "-->"
puts $logfile "Pre-test execution: disable and enable wifi"
send_mod "wifi disable"
sleep 2
send_mod "wifi enable"
sleep 6
exct_cmd "show wifi" "Wi-Fi*associating*SSID*Ayla*AP"
exct_cmd "wifi profile 0" "-->"
exct_cmd "wifi key notvalid" "-->"
exct_cmd "wifi profile enable" "-->"
exct_cmd "wifi profile 2" "-->"
exct_cmd "wifi security none" "-->"
exct_cmd "wifi profile enable" "-->"
puts $logfile "Pre-test execution: disable and enable wifi"
send_mod "wifi disable"
sleep 2
send_mod "wifi enable"
sleep 6
exct_cmd "show wifi" "Wi-Fi*associ*SSID*Ayla-test2*AP"


puts $logfile "**************************************************"
puts $logfile "*    Test suite to set wifi antenna at STA mode  *"
puts $logfile "**************************************************"
foreach c $WiFiAntSetCmd r $WiFiAntSetRslt {
    exct_cmd $c $r
    sleep 5
}

puts $logfile "**************************************************"
puts $logfile "*        Test suite for module in AP mode         *"
puts $logfile "**************************************************"
exct_cmd "wifi profile 0" "-->"
exct_cmd "wifi ssid hello" "-->"
exct_cmd "wifi profile enable" "-->"
exct_cmd "wifi profile 2" "-->"
exct_cmd "wifi profile disable" "-->"
send_mod "wifi enable 1"
sleep 2
send_mod "wifi commit"
sleep 8
exct_cmd "show wifi" "Wi-Fi*AP*mode*AP"
sleep 8
exct_cmd "show wifi" "Wi-Fi*AP*mode*AP"

set count [expr {$count -1}]
puts $logfile "**************************************************"
puts $logfile "*                  Summary                       *"
puts $logfile "**************************************************"
puts $logfile "\nTotal test cases finished: $count\n"
puts $logfile "Test cases passed: $pass_cases\n"
puts $logfile "Test cases failed: $fail_cases\n"
close $logfile
puts "\n$pass_cases test cases passed\n"
puts "\n$fail_cases test cases failed\n"




