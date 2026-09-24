[CmdletBinding()]
param(
    [ValidateRange(0, [int]::MaxValue)]
    [int]$N
)

function Get-Fibonacci {
    [OutputType([bigint])]
    param(
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

if ($MyInvocation.InvocationName -ne '.') {
    $result = Get-Fibonacci -N $N
    Write-Output "Fibonacci($N) = $result"
}
