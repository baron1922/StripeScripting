param(
    [string]$Name = 'Joe Scharf'
    ,[string]$Email = 'joe.scharf@mater.org.au'
    ,[string]$Bank = 'Joes Bank'
    ,[string]$BSB = '110000'
    ,[string]$Account = '000123456'
    ,[decimal]$Amount = 123.00
    ,[string]$ApiKey='sk_test_JRmXuQMjdgIRwXVnMBHcKiaY00JR4hdqLr'
)

$description = "mfas-2381 One off transactions for Sarah Glenville"

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
    $materProxy = "http://fpproxybp.mater.org.au:8080"

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

function Stripe-Create-Customer {
    param(
        [string] $Name
        ,[string] $Email
        ,[string] $ApiKey
    )
    $body = @{
        name = $Name
        email = $Email
        description = $description
    }

    $result = Invoke-Stripe -Method POST -Query "customers" -FormData $body -ApiKey $ApiKey

    $content = $result.Content
    $json = $content | ConvertFrom-Json
    return $json
}

function Stripe-Create-PaymentMethod {
    param(
    [Parameter(Mandatory)][string]$Name
    ,[Parameter(Mandatory)][string]$Email
    ,[Parameter(Mandatory)][string]$Bank
    ,[Parameter(Mandatory)][string]$BSB
    ,[Parameter(Mandatory)][string]$Account
    ,[Parameter(Mandatory)][string]$ApiKey
    )
    $body = @{
        type = "au_becs_debit"
        "billing_details[name]" = $Name
        "billing_details[email]" = $Email

        "au_becs_debit[bsb_number]" = $BSB
        "au_becs_debit[account_number]" = $Account

        "metadata[bank]" = $Bank
        "metadata[description]" = $description
    }

    $result = Invoke-Stripe -Method POST -Query "payment_methods" -FormData $body -ApiKey $ApiKey

    $content = $result.Content
    $json = $content | ConvertFrom-Json
    return $json
}

function Stripe-Create-SetupIntent {
    param(
    [Parameter(Mandatory)][string]$CustomerId 
    ,[Parameter(Mandatory)][string]$PaymentMethodId 
    ,[Parameter(Mandatory)][string]$ApiKey
    )
    $body = @{
        customer = $CustomerId
        payment_method = $PaymentMethodId
        "payment_method_types[]" = "au_becs_debit"
        "mandate_data[customer_acceptance][type]" = "offline"
        confirm = "true"
        "metadata[description]" = $description
    }

    $result = Invoke-Stripe -Method POST -Query "setup_intents" -FormData $body -ApiKey $ApiKey

    $content = $result.Content
    $json = $content | ConvertFrom-Json
    return $json
}

function Stripe-Create-PaymentIntent {
    param(
    [Parameter(Mandatory)][string]$CustomerId 
    ,[Parameter(Mandatory)][string]$PaymentMethodId 
    ,[Parameter(Mandatory)][decimal]$Amount
    ,[Parameter(Mandatory)][string]$ApiKey
    )
    $body = @{
        customer = $CustomerId
        payment_method = $PaymentMethodId
        amount = [int]($Amount*100)
        currency = "AUD"
        "payment_method_types[]" = "au_becs_debit"
        confirm = "true"
        "metadata[description]" = $description
    }

    $result = Invoke-Stripe -Method POST -Query "payment_intents" -FormData $body -ApiKey $ApiKey

    $content = $result.Content
    $json = $content | ConvertFrom-Json
    return $json
}

function Charge-DirectDebit {
    param(
    [Parameter(Mandatory)][string]$Name
    ,[Parameter(Mandatory)][string]$Email
    ,[Parameter(Mandatory)][string]$Bank
    ,[Parameter(Mandatory)][string]$BSB
    ,[Parameter(Mandatory)][string]$Account
    ,[Parameter(Mandatory)][decimal]$Amount
    ,[Parameter(Mandatory)][string]$ApiKey
    )
    process {
        $customer                     = Stripe-Create-Customer -Name $Name -Email $Email -ApiKey $ApiKey
        $customerId                   = $customer.id
        Write-Output "customerId      : $customerId"

        $paymentMethod                = Stripe-Create-PaymentMethod -Name $Name -Email $Email -Bank $Bank -BSB $BSB -Account $Account -ApiKey $ApiKey
        $paymentMethodId              = $paymentMethod.id
        Write-Output "paymentMethodId : $paymentMethodId"

        $setupIntent                  = Stripe-Create-SetupIntent -CustomerId $customerId -PaymentMethodId $paymentMethodId -ApiKey $ApiKey
        $setupIntentId                = $setupIntent.id
        Write-Output "setupIntentId   : $setupIntentId"

        $paymentIntent                = Stripe-Create-PaymentIntent -CustomerId $customerId -PaymentMethodId $paymentMethodId -Amount $Amount -ApiKey $ApiKey
        $paymentIntentId              = $paymentIntent.id
        Write-Output "paymentIntentId : $paymentIntentId"

        Write-Output "Charge to       : $Name $paymentIntentId"
    }
}

Charge-DirectDebit -Name $Name -Email $Email -Bank $Bank -BSB $BSB -Account $Account -Amount $Amount -ApiKey $ApiKey
