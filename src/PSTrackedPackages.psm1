function Get-UPSPackageInfo {
    <#
    .SYNOPSIS
    Returns shipping data for the given UPS tracking number
    
    .DESCRIPTION
    Returns shipping data for the given UPS tracking number
    
    .EXAMPLE
    Get-UPSPackageInfo -TrackingNumber 1Z123456789   
    #>
    [cmdletBinding()]
    param(
        [parameter(Mandatory=$true,Position=0)]
        [Alias('AccessKey')]
        [String]
        $UPSKey,
        
        [parameter(mandatory=$true,position=1)]
        [string[]]
        $TrackingNumber
    )

    process {

        $UPSheaders = @{
            AccessLicenseNumber = "$UPSKey"
            'Content-Type' = 'application/json'
            Accept = 'application/json'
        }      

        $TrackingNumber | ForEach-Object {
            
            $UPSheaders = @{
                AccessLicenseNumber = "$UPSKey"
                'Content-Type' = 'application/json'
                Accept = 'application/json'
            }

            $myUri = "https://wwwcie.ups.com/track/v1/details/" + $($_) + "?en_US"

            $InitialResponse = Invoke-RestMethod -Uri $myUri -Headers $UPSheaders -Method Get

            try{
                [datetime]$Ddate = $InitialResponse.trackResponse.shipment.package.deliverydate.date.SubString(4,2) + "/" +
                                    $InitialResponse.trackResponse.shipment.package.deliverydate.date.SubString(6,2) + "/" +
                                    $InitialResponse.trackResponse.shipment.package.deliverydate.date.SubString(0,4)
            }
            catch{
                $Ddate = "NoDate"
            }
            #Probably a better way to do this that's more clear but it works :>
            [pscustomobject]@{
                
                Provider = 'UPS'
                TrackingNumber = "$($_)"
                CurrentLocation = "$($InitialResponse.trackResponse.shipment.package.activity[0].location.address.city), $($InitialResponse.trackResponse.shipment.package.activity[0].location.address.stateProvince)"
                Status = $InitialResponse.trackResponse.shipment.package.activity[0].status.description
                DeliveryDate = $Ddate
            }

        }

    }
}
function Get-USPSPackageInfo {
    <#
    .SYNOPSIS
    Track a USPS Package
    
    .DESCRIPTION
    Track a USPS Package
    
    .EXAMPLE
    Get-USPSPackageInfo -UserKey ASDF -TrackingNumber 190293853873
    #>

    [cmdletBinding()]
    param(
        [parameter(mandatory=$true,position=0)]
        [Alias('UserKey','UserId')]
        [string]
        $USPSKey,

        [parameter(mandatory=$true,position=1)]
        [string[]]
        $TrackingNumber
    )

    process {

        $TrackingNumber | ForEach-Object {
            $track = $_
            $InitialUSPSURL = "http://production.shippingapis.com/ShippingAPI.dll?API=TrackV2&XML=<TrackRequest USERID='$USPSKey'><TrackID ID='$($track)'></TrackID></TrackRequest>"

            $InitialResponse = invoke-restmethod -method get -uri $InitialUSPSURL
            
            #Had more time to test with USPS so their responses get a bit more tweaking.
            #This is for when a package hasn't been entered into their system yet.
            if ($InitialResponse.trackResponse.TrackInfo.Error){
                 [pscustomobject]@{
                    Carrier = 'USPS'
                    TrackingNumber = "$track"
                    CurrentLocation = "Not Available"
                    Message = "Shipping info not yet provided to carrier"
                    DeliveryDate = "None"
                }

            }

            else{

                $InitialResponse.TrackResponse.TrackInfo.TrackDetail | Foreach-Object {

                    $null = $_ -match '^(?<status>[a-zA-Z\s\,]+(?!([\w\s])))(?:\,\s)(?<date>(\d{2}\/\d{2}\/\d{4})|(\w+\s\d{2}\,\s\d{4}))(?:\,\s)?(?<time>[\d\:]+\s[a-z]{2})?(?:\,\s)?(?<location>[A-Z\s\,\d]+$)?'

                    [pscustomobject]@{
                        Carrier = 'USPS'
                        'Tracking Number' = "$track"
                        Date = "$($matches.Date), $($matches.time)"
                        Location = "$($matches.Location)"
                        Message = "$($matches.status)"
                    }

                }

            }

        }

    }
}