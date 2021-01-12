<#
Chris Warwick, @cjwarwickps, August 2012.  Updates August 2013.
chrisjwarwick.wordpress.com
https://gallery.technet.microsoft.com/scriptcenter/Get-Network-NTP-Time-with-07b216ca

Get Datetime from NTP server.

This sends an NTP time packet to the specified NTP server and reads back the response.
The NTP time packet from the server is decoded and returned.

Note: this uses NTP (rfc-1305: http://www.faqs.org/rfcs/rfc1305.html) on UDP 123.  Because the
function makes a single call to a single server this is strictly a SNTP client (rfc-2030).  
Although the SNTP protocol data is similar (and can be identical) and the clients and servers
are often unable to distinguish the difference.  Where SNTP differs is that is does not 
accumulate historical data (to enable statistical averaging) and does not retain a session
between client and server.

An alternative to NTP or SNTP is to use Daytime (rfc-867) on TCP port 13 - although this is an 
old protocol and is not supported by all NTP servers.  This function will be more accurate than 
Daytime (since it takes network delays into account) but the result is only ever based on a 
single sample.  Depending on the source server and network conditions the actual returned time 
may not be as accurate as required.

See comments at the end of the script for an extract of the SNTP rfc.


Script Operation, Detail:

Construct an NTP request packet
Record the current local time; This is time t1, the 'Originate Timestamp'
Send the NTP request packet to the selected server
Read the server response 
Record the current local time after reception.  This is time t4.

The received packet now contains:
  t1 - Originate Timestamp (the time the request packet was sent from the client)
  t2 - Receive Timestamp (the time the request packet arrived at the server)
  t3 - Transmit Timestamp (the time the response packet left the server)
(Note that we don't send the originate timestamp (t1) so this will be 0 in the response)

Calculate clock offset and delay:

Estimated Clock Offset 
This is the difference between the server clock and the local clock taking into account
the network latency.  If both server and client clocks have the same absolute time 
then the clock difference minus the network latency will be 0.

Assuming symetric send/receive delays, the average of the out and return times will 
equal the offset.

   Offset = (OutTime+ReturnTime)/2

   Offset = ((t2 - t1) + (t3 - t4))/2      

Adding the offset to the local clock will give the correct time.


Round Trip Delay (= the time actually spent on the network)
This is the total transaction time (between t1..t4) minus the server 'thinking 
time' (between t2..t3)

   Delay = (t4 - t1) - (t3 - t2)

This value is useful for NTP servers because the most accurate offsets will be obtained from
responses with lower network delays.  When considering the single response obtained by this
script the Delay value is only useful as an indicator of the likely quality of the result

#>


#Requires -Version 3

Set-StrictMode -Version 3

Function Get-NtpTime {

<#
.Synopsis
   Gets (Simple) Network Time Protocol time (SNTP/NTP, rfc-1305, rfc-2030) from a specified server
.DESCRIPTION
   This function connects to an NTP server on UDP port 123 and retrieves the current NTP time.
   Selected components of the returned time information are decoded and returned in a PSObject.
.PARAMETER Server
   The NTP Server to contact.  Uses pool.ntp.org by default.
.PARAMETER MaxOffset
   The maximum acceptable offset between the local clock and the NTP Server, in milliseconds.
   The script will throw an exception if the time difference exceeds this value (on the assumption
   that the returned time may be incorrect).  Default = 10000 (10s).
.PARAMETER NoDns
   (Switch) If specified do not attempt to resolve Version 3 Secondary Server ReferenceIdentifiers.
.EXAMPLE
   Get-NtpTime uk.pool.ntp.org
   Gets time from the specified server.
.EXAMPLE
   Get-NtpTime | fl *
   Get time from default server (pool.ntp.org) and displays all output object attributes.
.OUTPUTS
   A PSObject containing decoded values from the NTP server.  Pipe to fl * to see all attributes.
.FUNCTIONALITY
   Gets NTP time from a specified server.
#>

    [CmdletBinding()]
    [OutputType()]
    Param (
        [String]$Server = 'pool.ntp.org',
        [Int]$MaxOffset = 10000,     # (Milliseconds) Throw exception if network time offset is larger
        [Switch]$NoDns               # Do not attempt to lookup V3 secondary-server referenceIdentifier
    )


    # NTP Times are all UTC and are relative to midnight on 1/1/1900
    $StartOfEpoch=New-Object DateTime(1900,1,1,0,0,0,[DateTimeKind]::Utc)   


    Function OffsetToLocal($Offset) {
    # Convert milliseconds since midnight on 1/1/1900 to local time
        $StartOfEpoch.AddMilliseconds($Offset).ToLocalTime()
    }


    # Construct a 48-byte client NTP time packet to send to the specified server
    # (Request Header: [00=No Leap Warning; 011=Version 3; 011=Client Mode]; 00011011 = 0x1B)

    [Byte[]]$NtpData = ,0 * 48
    $NtpData[0] = 0x1B    # NTP Request header in first byte


    $Socket = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork,
                                            [Net.Sockets.SocketType]::Dgram,
                                            [Net.Sockets.ProtocolType]::Udp)
    $Socket.SendTimeOut = 2000  # ms
    $Socket.ReceiveTimeOut = 2000   # ms

    Try {
        $Socket.Connect($Server,123)
    }
    Catch {
        Write-Error "Failed to connect to server $Server"
        Throw 
    }


# NTP Transaction -------------------------------------------------------

        $t1 = Get-Date    # t1, Start time of transaction... 
    
        Try {
            [Void]$Socket.Send($NtpData)
            [Void]$Socket.Receive($NtpData)  
        }
        Catch {
            Write-Error "Failed to communicate with server $Server"
            Throw
        }

        $t4 = Get-Date    # End of NTP transaction time

# End of NTP Transaction ------------------------------------------------

    $Socket.Shutdown("Both") 
    $Socket.Close()

# We now have an NTP response packet in $NtpData to decode.  Start with the LI flag
# as this is used to indicate errors as well as leap-second information

    # Check the Leap Indicator (LI) flag for an alarm condition - extract the flag
    # from the first byte in the packet by masking and shifting 

    $LI = ($NtpData[0] -band 0xC0) -shr 6    # Leap Second indicator
    If ($LI -eq 3) {
        Throw 'Alarm condition from server (clock not synchronized)'
    } 

    # Decode the 64-bit NTP times

    # The NTP time is the number of seconds since 1/1/1900 and is split into an 
    # integer part (top 32 bits) and a fractional part, multipled by 2^32, in the 
    # bottom 32 bits.

    # Convert Integer and Fractional parts of the (64-bit) t3 NTP time from the byte array
    $IntPart = [BitConverter]::ToUInt32($NtpData[43..40],0)
    $FracPart = [BitConverter]::ToUInt32($NtpData[47..44],0)

    # Convert to Millseconds (convert fractional part by dividing value by 2^32)
    $t3ms = $IntPart * 1000 + ($FracPart * 1000 / 0x100000000)

    # Perform the same calculations for t2 (in bytes [32..39]) 
    $IntPart = [BitConverter]::ToUInt32($NtpData[35..32],0)
    $FracPart = [BitConverter]::ToUInt32($NtpData[39..36],0)
    $t2ms = $IntPart * 1000 + ($FracPart * 1000 / 0x100000000)

    # Calculate values for t1 and t4 as milliseconds since 1/1/1900 (NTP format)
    $t1ms = ([TimeZoneInfo]::ConvertTimeToUtc($t1) - $StartOfEpoch).TotalMilliseconds
    $t4ms = ([TimeZoneInfo]::ConvertTimeToUtc($t4) - $StartOfEpoch).TotalMilliseconds
 
    # Calculate the NTP Offset and Delay values
    $Offset = (($t2ms - $t1ms) + ($t3ms-$t4ms))/2
    $Delay = ($t4ms - $t1ms) - ($t3ms - $t2ms)

    # Make sure the result looks sane...
    If ([Math]::Abs($Offset) -gt $MaxOffset) {
        # Network server time is too different from local time
        Throw "Network time offset exceeds maximum ($($MaxOffset)ms)"
    }

    # Decode other useful parts of the received NTP time packet

    # We already have the Leap Indicator (LI) flag.  Now extract the remaining data
    # flags (NTP Version, Server Mode) from the first byte by masking and shifting (dividing)

    $LI_text = Switch ($LI) {
        0    {'no warning'}
        1    {'last minute has 61 seconds'}
        2    {'last minute has 59 seconds'}
        3    {'alarm condition (clock not synchronized)'}
    }

    $VN = ($NtpData[0] -band 0x38) -shr 3    # Server version number

    $Mode = ($NtpData[0] -band 0x07)     # Server mode (probably 'server')
    $Mode_text = Switch ($Mode) {
        0    {'reserved'}
        1    {'symmetric active'}
        2    {'symmetric passive'}
        3    {'client'}
        4    {'server'}
        5    {'broadcast'}
        6    {'reserved for NTP control message'}
        7    {'reserved for private use'}
    }

    # Other NTP information (Stratum, PollInterval, Precision)

    $Stratum = [UInt16]$NtpData[1]   # Actually [UInt8] but we don't have one of those...
    $Stratum_text = Switch ($Stratum) {
        0                            {'unspecified or unavailable'}
        1                            {'primary reference (e.g., radio clock)'}
        {$_ -ge 2 -and $_ -le 15}    {'secondary reference (via NTP or SNTP)'}
        {$_ -ge 16}                  {'reserved'}
    }

    $PollInterval = $NtpData[2]              # Poll interval - to neareast power of 2
    $PollIntervalSeconds = [Math]::Pow(2, $PollInterval)

    $PrecisionBits = $NtpData[3]      # Precision in seconds to nearest power of 2
    # ...this is a signed 8-bit int
    If ($PrecisionBits -band 0x80) {    # ? negative (top bit set)
        [Int]$Precision = $PrecisionBits -bor 0xFFFFFFE0    # Sign extend
    } else {
        # ..this is unlikely - indicates a precision of less than 1 second
        [Int]$Precision = $PrecisionBits   # top bit clear - just use positive value
    }
    $PrecisionSeconds = [Math]::Pow(2, $Precision)
    

<# Reference Identifier, notes: 

   This is a 32-bit bitstring identifying the particular reference source. 
   
   In the case of NTP Version 3 or Version 4 stratum-0 (unspecified) or 
   stratum-1 (primary) servers, this is a four-character ASCII string, 
   left justified and zero padded to 32 bits. NTP primary (stratum 1) 
   servers should set this field to a code identifying the external reference 
   source according to the following list. If the external reference is one 
   of those listed, the associated code should be used. Codes for sources not
   listed can be contrived as appropriate.

      Code     External Reference Source
      ----------------------------------------------------------------
      LOCL     uncalibrated local clock used as a primary reference for
               a subnet without external means of synchronization
      PPS      atomic clock or other pulse-per-second source
               individually calibrated to national standards
      DCF      Mainflingen (Germany) Radio 77.5 kHz
      MSF      Rugby (UK) Radio 60 kHz
      GPS      Global Positioning Service
   
   In NTP Version 3 secondary servers, this is the 32-bit IPv4 address of the 
   reference source. 
   
   In NTP Version 4 secondary servers, this is the low order 32 bits of the 
   latest transmit timestamp of the reference source. 

#>

    # Determine the format of the ReferenceIdentifier field and decode
    
    If ($Stratum -le 1) {
        # Response from Primary Server.  RefId is ASCII string describing source
        $ReferenceIdentifier = [String]([Char[]]$NtpData[12..15] -join '')
    }
    Else {

        # Response from Secondary Server; determine server version and decode

        Switch ($VN) {
            3       {
                        # Version 3 Secondary Server, RefId = IPv4 address of reference source
                        $ReferenceIdentifier = $NtpData[12..15] -join '.'

                        If (-Not $NoDns) {
                            If ($DnsLookup =  Resolve-DnsName $ReferenceIdentifier -QuickTimeout -ErrorAction SilentlyContinue) {
                                $ReferenceIdentifier = "$ReferenceIdentifier <$($DnsLookup.NameHost)>"
                            }
                        }
                        Break
                    }

            4       {
                        # Version 4 Secondary Server, RefId = low-order 32-bits of  
                        # latest transmit time of reference source
                        $ReferenceIdentifier = [BitConverter]::ToUInt32($NtpData[15..12],0) * 1000 / 0x100000000
                        Break
                    }

            Default {
                        # Unhandled NTP version...
                        $ReferenceIdentifier = $Null
                    }
        }
    }


    # Calculate Root Delay and Root Dispersion values
    
    $RootDelay = [BitConverter]::ToInt32($NtpData[7..4],0) / 0x10000
    $RootDispersion = [BitConverter]::ToUInt32($NtpData[11..8],0) / 0x10000


    # Finally, create output object and return

    $NtpTimeObj = [PSCustomObject]@{
        NtpServer = $Server
        NtpTime = OffsetToLocal($t4ms + $Offset)
        Offset = $Offset
        OffsetSeconds = [Math]::Round($Offset/1000, 3)
        Delay = $Delay
        t1ms = $t1ms
        t2ms = $t2ms
        t3ms = $t3ms
        t4ms = $t4ms
        t1 = OffsetToLocal($t1ms)
        t2 = OffsetToLocal($t2ms)
        t3 = OffsetToLocal($t3ms)
        t4 = OffsetToLocal($t4ms)
        LI = $LI
        LI_text = $LI_text
        NtpVersionNumber = $VN
        Mode = $Mode
        Mode_text = $Mode_text
        Stratum = $Stratum
        Stratum_text = $Stratum_text
        PollIntervalRaw = $PollInterval
        PollInterval = New-Object TimeSpan(0,0,$PollIntervalSeconds)
        Precision = $Precision
        PrecisionSeconds = $PrecisionSeconds
        ReferenceIdentifier = $ReferenceIdentifier
        RootDelay = $RootDelay
        RootDispersion = $RootDispersion
        Raw = $NtpData   # The undecoded bytes returned from the NTP server
    }

    # Set the default display properties for the returned object
    [String[]]$DefaultProperties =  'NtpServer', 'NtpTime', 'OffsetSeconds', 'NtpVersionNumber', 
                                    'Mode_text', 'Stratum', 'ReferenceIdentifier'

    # Create the PSStandardMembers.DefaultDisplayPropertySet member
    $ddps = New-Object Management.Automation.PSPropertySet('DefaultDisplayPropertySet', $DefaultProperties)

    # Attach default display property set and output object
    $PSStandardMembers = [Management.Automation.PSMemberInfo[]]$ddps 
    $NtpTimeObj | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value $PSStandardMembers -PassThru
}



<#

From rfc-2030
~~~~~~~~~~~~~

48-byte NTP time packet format

                                 1                   2                   3
   BitOffset 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
Bytes       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    0-3     |LI | VN  |Mode |    Stratum    |     Poll      |   Precision   |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    4-7     |                          Root Delay                           |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    8-11    |                       Root Dispersion                         |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    12-15   |                     Reference Identifier                      |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    16-23   |                                                               |
            |                   Reference Timestamp (64)                    |
            |                                                               |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    24-31   |                                                               |
            |                   Originate Timestamp (64)                    |
            |                                                               |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    32-39   |                                                               |
            |                    Receive Timestamp (64)                     |
            |                                                               |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
    40-47   |                                                               |
            |                    Transmit Timestamp (64)                    |
            |                                                               |
            +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+


   Leap Indicator (LI): This is a two-bit code warning of an impending
   leap second to be inserted/deleted in the last minute of the current
   day, with bit 0 and bit 1, respectively, coded as follows:

      LI       Value     Meaning
      -------------------------------------------------------
      00       0         no warning
      01       1         last minute has 61 seconds
      10       2         last minute has 59 seconds)
      11       3         alarm condition (clock not synchronized)

   Version Number (VN): This is a three-bit integer indicating the
   NTP/SNTP version number. The version number is 3 for Version 3 (IPv4
   only) and 4 for Version 4 (IPv4, IPv6 and OSI). If necessary to
   distinguish between IPv4, IPv6 and OSI, the encapsulating context
   must be inspected.

   Mode: This is a three-bit integer indicating the mode, with values
   defined as follows:

      Mode     Meaning
      ------------------------------------
      0        reserved
      1        symmetric active
      2        symmetric passive
      3        client
      4        server
      5        broadcast
      6        reserved for NTP control message
      7        reserved for private use

   In unicast and anycast modes, the client sets this field to 3
   (client) in the request and the server sets it to 4 (server) in the
   reply. In multicast mode, the server sets this field to 5
   (broadcast).

   Stratum: This is a eight-bit unsigned integer indicating the stratum
   level of the local clock, with values defined as follows:

      Stratum  Meaning
      ----------------------------------------------
      0        unspecified or unavailable
      1        primary reference (e.g., radio clock)
      2-15     secondary reference (via NTP or SNTP)
      16-255   reserved

   Poll Interval: This is an eight-bit signed integer indicating the
   maximum interval between successive messages, in seconds to the
   nearest power of two. The values that can appear in this field
   presently range from 4 (16 s) to 14 (16284 s); however, most
   applications use only the sub-range 6 (64 s) to 10 (1024 s).

   Precision: This is an eight-bit signed integer indicating the
   precision of the local clock, in seconds to the nearest power of two.
   The values that normally appear in this field range from -6 for
   mains-frequency clocks to -20 for microsecond clocks found in some
   workstations.

   Root Delay: This is a 32-bit signed fixed-point number indicating the
   total roundtrip delay to the primary reference source, in seconds
   with fraction point between bits 15 and 16. Note that this variable
   can take on both positive and negative values, depending on the
   relative time and frequency offsets. The values that normally appear
   in this field range from negative values of a few milliseconds to
   positive values of several hundred milliseconds.

   Root Dispersion: This is a 32-bit unsigned fixed-point number
   indicating the nominal error relative to the primary reference
   source, in seconds with fraction point between bits 15 and 16. The
   values that normally appear in this field range from 0 to several
   hundred milliseconds.

   Reference Identifier: This is a 32-bit bitstring identifying the
   particular reference source. In the case of NTP Version 3 or Version
   4 stratum-0 (unspecified) or stratum-1 (primary) servers, this is a
   four-character ASCII string, left justified and zero padded to 32
   bits. In NTP Version 3 secondary servers, this is the 32-bit IPv4
   address of the reference source. In NTP Version 4 secondary servers,
   this is the low order 32 bits of the latest transmit timestamp of the
   reference source. NTP primary (stratum 1) servers should set this
   field to a code identifying the external reference source according
   to the following list. If the external reference is one of those
   listed, the associated code should be used. Codes for sources not
   listed can be contrived as appropriate.

      Code     External Reference Source
      ----------------------------------------------------------------
      LOCL     uncalibrated local clock used as a primary reference for
               a subnet without external means of synchronization
      PPS      atomic clock or other pulse-per-second source
               individually calibrated to national standards
      ACTS     NIST dialup modem service
      USNO     USNO modem service
      PTB      PTB (Germany) modem service
      TDF      Allouis (France) Radio 164 kHz
      DCF      Mainflingen (Germany) Radio 77.5 kHz
      MSF      Rugby (UK) Radio 60 kHz
      WWV      Ft. Collins (US) Radio 2.5, 5, 10, 15, 20 MHz
      WWVB     Boulder (US) Radio 60 kHz
      WWVH     Kaui Hawaii (US) Radio 2.5, 5, 10, 15 MHz
      CHU      Ottawa (Canada) Radio 3330, 7335, 14670 kHz
      LORC     LORAN-C radionavigation system
      OMEG     OMEGA radionavigation system
      GPS      Global Positioning Service
      GOES     Geostationary Orbit Environment Satellite

   Reference Timestamp: This is the time at which the local clock was
   last set or corrected, in 64-bit timestamp format.

   Originate Timestamp: This is the time at which the request departed
   the client for the server, in 64-bit timestamp format.

   Receive Timestamp: This is the time at which the request arrived at
   the server, in 64-bit timestamp format.

   Transmit Timestamp: This is the time at which the reply departed the
   server for the client, in 64-bit timestamp format.

#>