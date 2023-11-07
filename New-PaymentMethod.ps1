# New-PaymentMethod.ps1
param(
    [ValidateScript({ 
        if ($_.Exists) {
            $true
        } else {
            throw "File '$_' does not exist." 
        }
    })]
    [System.IO.FileInfo]$LiteralPath = "C:\Users\joe\repos\StripeScripting\mydata.csv",
    [string]$ApiKey="rk_test_51O6pkmCq8XnAqe14IYtA4zkwQecGAo0I4ljQRyICGsunvqNblnqywTd3oUm6DaLIjlHMWEAVFwjcnpa4KI5RE6Qw00m3Trc55v"
)
function Invoke-Stripe() {
    param(
        [ValidateSet('GET','POST')]$Method='GET',
        [string]$ApiKey,
        [string]$Query='',
        [hashtable]$Headers=@{}
        ,[hashtable]$FormData=@{}
    )

    $uri = "https://api.stripe.com/v1/$Query"
    $authorization = @{Authorization="Bearer $ApiKey"}

    # Stripe required Tls12. Set protocol before we invoke the network service.
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

    $SaveProgressPreference=$ProgressPreference
    $ProgressPreference="SilentlyContinue"

    $response = $null
    try {
        if ($Method -eq 'POST') {
            $contentTypeHeader = @{ "Content-Type" = "application/x-wwww-form-urlencoded" }
            $response = Invoke-WebRequest -Method POST -Uri $uri -Headers ($authorization + $Headers) -Body ($FormData)
        }
        else {
            $response = Invoke-WebRequest -Method GET -Uri $uri -Headers ($authorization + $Headers)
        }
    }
    catch {
        Write-Error $_
        $response = $_
    }
    $ProgressPreference = $SaveProgressPreference
    return $response
}
function New-Customer {
    param (
        [ValidateScript({
            if (-not($_.PSObject.Properties.name -contains "Name")) { throw "Data.Name property is missing" }
            if (-not($_.PSObject.Properties.name -contains "Email")) { throw "Data.Email property is missing" }
            $true
        })]
        [PSCustomObject]$Data,
        [string]$ApiKey
    )
    $body = @{
        name = $Data.Name
        email = $Data.Email
    }

    $result = Invoke-Stripe -Method POST -Query "customers" -FormData $body -ApiKey $ApiKey

    $content = $result.Content
    $json = $content | ConvertFrom-Json
    return $json
}
function New-PaymentMethod {
    param (
        [PSCustomObject]$Data,
        [string]$ApiKey
    )
    $customer = New-Customer -Data $Data -ApiKey $ApiKey
    $data | Add-Member -NotePropertyName CustomerId -NotePropertyValue $customer.id
    $data
}
function main{
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$LiteralPath,
        [Parameter(Mandatory)][string]$ApiKey
    )
    Import-Csv -LiteralPath $LiteralPath |
    ForEach-Object {
        New-PaymentMethod -Data $_ -ApiKey $ApiKey
    } | ConvertTo-Csv
    
}

main -LiteralPath $LiteralPath -ApiKey $ApiKey