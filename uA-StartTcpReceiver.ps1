<#
.SYNOPSIS
Starts a TCP listener and captures incoming data to a file until a timeout is reached or a specific string is found.

.DESCRIPTION
This script starts a TCP listener on a specified port and captures incoming data to a file until a specific string is found or a timeout is reached. It uses `Start-Transcript` for logging.

.PARAMETER Port
The port number to listen on. Default is 19500.

.PARAMETER TimeoutMinutes
The timeout period in minutes. Set to 0 to disable the timeout. Default is 1 minute.

.PARAMETER SearchString
The specific string to look for in incoming data. Leave empty to disable this check.

.PARAMETER Output
The path to the output file where received data will be written. Default is uA-Data.txt in the script directory.

.PARAMETER LogPath
The path to the log file. Default is $PSCommandPath.txt. This is the full script path with .txt extension.

.PARAMETER EnableLogging
Switch to either enable or disable logging using Start-Transcript. Default is off.

.EXAMPLE
uA-StartTcpReceiver -Port 19501 -TimeoutMinutes 10 -EnableLogging

.EXAMPLE
uA-StartTcpReceiver -TimeoutMinutes 0 -SearchString "sourcetype=uberAgent:Application:Errors" -EnableLogging

.LINK
https://github.com/vastlimits/uberAgentSupport-Scripts
uberagent.com
#>

param (
   [int]$Port = 19500,
   [int]$TimeoutMinutes = 1,
   [string]$SearchString = "",
   [string]$Output = "$PSScriptRoot\uA-Data.txt",
   [string]$LogPath = "$PSCommandPath.txt",
   [switch]$EnableLogging
)

function Start-TcpReceiver {
   param (
      [int]$Port,
      [int]$TimeoutMinutes,
      [string]$SearchString,
      [string]$Output,
      [string]$LogPath,
      [switch]$EnableLogging
   )

   # Initialize logging and variables
   if ($EnableLogging) {
      Start-Transcript -Path $LogPath -Append
   }
   
   $TimeoutReached = $false
   $TcpListener = $null

   try {
   # Check if the listener is already running
      if ($TcpListener -eq $null) {
         $IPEndPoint = New-Object System.Net.IPEndPoint([IPAddress]::Any, $Port)
         $TcpListener = New-Object System.Net.Sockets.TcpListener $IPEndPoint
      }

      # Attempt to start the listener, handling exceptions if the port is already in use
      try {
		 Write-Host "Starting TCP listener on Port $Port."
         $TcpListener.Start()
      }
      catch {
         Write-Host "Error starting listener: $_"
         return
      }

      while (-not $TimeoutReached) {
         if ($TcpListener.Pending()) {
			
            $StartTime = Get-Date

			$AcceptTcpClient = $TcpListener.AcceptTcpClient()
            $GetStream = $AcceptTcpClient.GetStream()
            $StreamReader = New-Object System.IO.StreamReader $GetStream
            $FileStream = [System.IO.StreamWriter]::new($Output)

			Write-Host "Timeout (minutes): $TimeoutMinutes"
            Write-Host "Search string: $SearchString"

            while ($true) {
               $ReadLine = $StreamReader.ReadLine()
               $FileStream.WriteLine($ReadLine)

               # Check for specific string match (if not disabled)
               if ($SearchString -ne "" -and $ReadLine -match $SearchString) {
                  Write-Host "String '$SearchString' found. Exiting."
                  $TimeoutReached = $true
                  break
               }

               # Check for timeout (if not disabled)
               if ($TimeoutMinutes -gt 0) {
                  $ElapsedMinutes = (Get-Date).Subtract($StartTime).TotalMinutes
                  if ($ElapsedMinutes -ge $TimeoutMinutes) {
                     Write-Host "Timeout reached ($TimeoutMinutes minutes). Exiting."
                     $TimeoutReached = $true
                     break
                  }
               }
            }

            # Dispose of resources
            $FileStream.Close()
            $StreamReader.Dispose()
            $GetStream.Dispose()
            $AcceptTcpClient.Close()
         }
      }
    }
   catch {
      Write-Host "An error occurred: $_"
   }
   finally {
      # Stop listening and logging
      if ($TcpListener -ne $null) {
         $TcpListener.Stop()
      }
      if ($EnableLogging) {
         Stop-Transcript
      }
   }
}

Start-TcpReceiver -Port $Port -TimeoutMinutes $TimeoutMinutes -SearchString $SearchString -Output $Output -LogPath $LogPath -EnableLogging:$EnableLogging
