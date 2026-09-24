[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateRange(0, [int]::MaxValue)]
    [int]$N,

    [Parameter()]
    [ValidateSet('fibonacci', 'factorial')]
    [string]$Operation = 'fibonacci'
)

function Get-Fibonacci {
    [OutputType([bigint])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$N
    )

    [bigint]$current = 0
    [bigint]$next = 1

    for ($index = 0; $index -lt $N; $index++) {
        [bigint]$following = $current + $next
        $current = $next
        $next = $following
    }

    return $current
}

function Get-Factorial {
    [OutputType([bigint])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$N
    )

    [bigint]$result = 1

    for ($index = 2; $index -le $N; $index++) {
        $result *= $index
    }

    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    switch ($Operation) {
        'factorial' {
            $result = Get-Factorial -N $N
            Write-Output "Factorial($N) = $result"
        }
        'fibonacci' {
            $result = Get-Fibonacci -N $N
            Write-Output "Fibonacci($N) = $result"
        }
    }
}
