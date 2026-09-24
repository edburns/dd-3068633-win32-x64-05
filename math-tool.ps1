[CmdletBinding()]
param(
    [ValidateRange(0, [int]::MaxValue)]
    [int]$N
)

function Get-Fibonacci {
    [OutputType([long])]
    param(
        [ValidateRange(0, [int]::MaxValue)]
        [int]$N
    )

    [long]$current = 0
    [long]$next = 1

    for ($index = 0; $index -lt $N; $index++) {
        [long]$following = $current + $next
        $current = $next
        $next = $following
    }

    return $current
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Get-Fibonacci -N $N
    Write-Output "Fibonacci($N) = $result"
}
