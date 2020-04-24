<#
    .SYNOPSIS
        Add a tracking number and info to the root csv
    .EXAMPLE
        Add-TrackedPackage <TrackingNum> "USPS" "Toilet Paper"
#>
function Add-TrackedPackage{
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$true)]
        [string]
        $TrackingNumber,
        [Parameter(Mandatory=$true)]
        [string][ValidateSet( "USPS", "UPS")]
        $InProvider,
        [Parameter(Mandatory=$true)]
        [string]
        $FriendlyName
    )

    $TrackedPackagedCSVFilepath = (split-path $profile) + "\trackedpackages.csv"
    
    if (!(Test-Path ($TrackedPackagedCSVFilepath))){
        new-item -type file $TrackedPackagedCSVFilepath
        set-content $TrackedPackagedCSVFilepath "trackingnum,provider,friendlyname`n`"$trackingnumber`",`"$InProvider`",`"$FriendlyName`""
        return
    }
    
    [PSCustomObject]@{trackingnum="$TrackingNumber";provider="$InProvider";friendlyname = "$FriendlyName"} | export-csv -append $TrackedPackagedCSVFilepath
}
<#
    .SYNOPSIS
        Delete a tracking number and info from the root csv
    .EXAMPLE
        Remove-TrackedPackage <TrackingNum>
#>
function Remove-TrackedPackage{
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$true)]
        [string]
        $TrackingNumber
    )

    $TrackedPackagedCSVFilepath = (split-path $profile) + "\trackedpackages.csv"

    $a = import-csv $TrackedPackagedCSVFilepath
    
    $a = $a | where-object trackingnum -ne "$TrackingNumber"

    $a| export-csv $TrackedPackagedCSVFilepath

}
<#
    .SYNOPSIS
        Gets and returns information regarding the tracking numbers in the root csv
    .EXAMPLE
        Get-TrackedPackageInfo $env:UPSKey $env:USPSKey
#>
function Get-TrackedPackageInfo {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$true)]
        [string]
        $UPSKey,
        [Parameter(Mandatory=$true)]
        [string]
        $USPSKey
    )

    $InitialUSPSURL = "http://production.shippingapis.com/ShippingAPI.dll?API=TrackV2&XML=<TrackRequest USERID='$USPSKey'><TrackID ID='REPLACENUM'></TrackID></TrackRequest>"

    $UPSheaders = @{
        AccessLicenseNumber = "$UPSKey"
        'Content-Type' = 'application/json'
        Accept = 'application/json'
    }
    $ReturnResponse = @()
    $TrackedPackagedCSVFilepath = (split-path $profile) + "\trackedpackages.csv"

    $CSVObj = import-csv $TrackedPackagedCSVFilepath

    foreach ($Num in $CSVObj){
        if ($Num.Provider -eq "ups"){
            #the string wouldn't format properly if i had it like "https://onlinetools.ups.com/track/v1/details/$trackingNumber?en_US"
            #so I concatentated like this, but I'm still not sure why it wouldn't work????
            #default parameter for invoke-restmethod -verbose will have a lot more information if this fails.
            $myUri = "https://onlinetools.ups.com/track/v1/details/" + $Num.trackingnum + "?en_US"

            $InitialResponse = invoke-restmethod $myUri -Headers $UPSheaders -Method get
            #Convert UPS datetime into normal date time.
            try{
                [datetime]$Ddate = $InitialResponse.trackResponse.shipment.package.deliverydate.date.SubString(4,2) + "/" +
                                    $InitialResponse.trackResponse.shipment.package.deliverydate.date.SubString(6,2) + "/" +
                                    $InitialResponse.trackResponse.shipment.package.deliverydate.date.SubString(0,4)
            }
            catch{
                $Ddate = "NoDate"
            }
            #Probably a better way to do this that's more clear but it works :>
            [pscustomobject]$ReturnResponse += [pscustomobject]@{
                Name = $Num.friendlyname
                Provider = $Num.Provider
                TrackingNumber = $Num.trackingnum
                CurrentLocation = "$($InitialResponse.trackResponse.shipment.package.activity[0].location.address.city), $($InitialResponse.trackResponse.shipment.package.activity[0].location.address.stateProvince)"
                Status = $InitialResponse.trackResponse.shipment.package.activity[0].status.description
                DeliveryDate = $Ddate
                RootResponse = $InitialResponse
            }
        }
        elseif ($Num.Provider -eq "usps"){
            #Replacing the TrackID in the intitial url to our current enumerator.
            $RunURL = $InitialUSPSURL -replace 'REPLACENUM',$Num.trackingnum
            
            $InitialResponse = invoke-restmethod -method get -uri $runurl
            
            #Had more time to test with USPS so their responses get a bit more tweaking.
            #This is for when a package hasn't been entered into their system yet.
            if ($InitialResponse.trackResponse.TrackInfo.Error){
                [pscustomobject]$ReturnResponse += [pscustomobject]@{
                    Name = $Num.friendlyname
                    Provider = $Num.Provider
                    TrackingNumber = $Num.trackingnum
                    CurrentLocation = "The Void"
                    Status = $InitialResponse.trackResponse.TrackInfo.Error.Description
                    DeliveryDate = "None"
                    RootResponse = $InitialResponse
                }
            }
            elseif ($InitialResponse.TrackResponse.TrackInfo.TrackSummary -match "A shipping label has been prepared|This does not indicate receipt by"){
                $InitialResponse.TrackResponse.TrackInfo.TrackSummary -match 'in\s(.*?)\.' | out-null
                
                [pscustomobject]$ReturnResponse += [pscustomobject]@{
                    Name = $Num.friendlyname
                    Provider = $Num.Provider
                    TrackingNumber = $Num.trackingnum
                    CurrentLocation = $Matches[1]
                    Status = $InitialResponse.TrackResponse.TrackInfo.TrackSummary
                    DeliveryDate = "None"
                    RootResponse = $InitialResponse
                }
            }
            elseif($InitialResponse.TrackResponse.TrackInfo.TrackSummary -match "Your item arrived at our (.*?) origin facility"){
                [pscustomobject]$ReturnResponse += [pscustomobject]@{
                    Name = $Num.friendlyname
                    Provider = $Num.Provider
                    TrackingNumber = $Num.trackingnum
                    CurrentLocation = $Matches[1]
                    Status = $InitialResponse.TrackResponse.TrackInfo.TrackSummary
                    DeliveryDate = "None"
                    RootResponse = $InitialResponse
                }
            }
            elseif($InitialResponse.TrackResponse.TrackInfo.TrackSummary -match "Your item departed our USPS facility in (.*?) on April 23, 2020 at 4:28 am."){
                [pscustomobject]$ReturnResponse += [pscustomobject]@{
                    Name = $Num.friendlyname
                    Provider = $Num.Provider
                    TrackingNumber = $Num.trackingnum
                    CurrentLocation = $Matches[1]
                    Status = $InitialResponse.TrackResponse.TrackInfo.TrackSummary
                    DeliveryDate = "None"
                    RootResponse = $InitialResponse
                }
            }
            else{
                $InitialResponse.TrackResponse.TrackInfo.TrackDetail[0] -match ",\s(.*)$"| out-null
                [pscustomobject]$ReturnResponse += [pscustomobject]@{
                    Name = $Num.friendlyname
                    Provider = $Num.Provider
                    TrackingNumber = $Num.trackingnum
                    CurrentLocation = $Matches[1]
                    Status = $InitialResponse.TrackResponse.TrackInfo.TrackSummary
                    DeliveryDate = "None"
                    RootResponse = $InitialResponse
                }
            }
        }

    }
    
    return $ReturnResponse
}
