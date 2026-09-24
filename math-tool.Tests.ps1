$scriptPath = Join-Path $PSScriptRoot 'math-tool.ps1'
. $scriptPath -N 0

Describe 'Get-Fibonacci' {
    It 'returns only <Expected> for N=<N>' -TestCases @(
        @{ N = 0; Expected = 0 }
        @{ N = 1; Expected = 1 }
        @{ N = 5; Expected = 5 }
    ) {
        param($N, $Expected)

        $result = @(Get-Fibonacci -N $N)

        $result | Should -HaveCount 1
        $result[0] | Should -Be $Expected
    }
}

Describe 'math-tool CLI' {
    It 'writes the expected result for N=<N>' -TestCases @(
        @{ N = 0; Expected = 'Fibonacci(0) = 0' }
        @{ N = 1; Expected = 'Fibonacci(1) = 1' }
        @{ N = 5; Expected = 'Fibonacci(5) = 5' }
    ) {
        param($N, $Expected)

        $output = @(& pwsh -NoLogo -NoProfile -File $scriptPath -N $N 2>&1)

        $LASTEXITCODE | Should -Be 0
        $output | Should -HaveCount 1
        $output[0].ToString() | Should -Be $Expected
    }
}
