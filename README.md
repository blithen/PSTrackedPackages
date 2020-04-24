# PSTrackedPackages
Simple set of cmdlets for reading from the USPS/UPS API's and getting tracking info.
You will need to sign up for both API services, they're both free. You'll feed the keys in to the Get-TrackedPackages cmdlet. I recommend storing them in your environment variables so you can do something like `Get-TrackedPackageInfo $env:UPSKey $env:USPSKey`
