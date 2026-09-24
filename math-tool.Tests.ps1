Describe 'Get-Fibonacci' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'math-tool.ps1'
        . $scriptPath -N 0
    }

    It 'returns only <Expected> for N=<N>' -TestCases @(
        @{ N = 0; Expected = 0 }
        @{ N = 1; Expected = 1 }
        @{ N = 5; Expected = 5 }
        @{ N = 10; Expected = 55 }
    ) {
        param($N, $Expected)

        $result = @(Get-Fibonacci -N $N)

        $result | Should -HaveCount 1
        $result[0] | Should -Be $Expected
    }
}

Describe 'Get-Factorial' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'math-tool.ps1'
        . $scriptPath -N 0
    }

    It 'returns only <Expected> for N=<N>' -TestCases @(
        @{ N = 0; Expected = 1 }
        @{ N = 1; Expected = 1 }
        @{ N = 5; Expected = 120 }
    ) {
        param($N, $Expected)

        $result = @(Get-Factorial -N $N)

        $result | Should -HaveCount 1
        $result[0] | Should -Be $Expected
    }
}

Describe 'math-tool CLI' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot 'math-tool.ps1'
    }

    It 'writes the expected result for N=<N>' -TestCases @(
        @{ N = 0; Expected = 'Fibonacci(0) = 0' }
        @{ N = 1; Expected = 'Fibonacci(1) = 1' }
        @{ N = 5; Expected = 'Fibonacci(5) = 5' }
    ) {
        param($N, $Expected)

        $stderrPath = Join-Path $TestDrive "stderr-$N.txt"
        $output = @(& pwsh -NoLogo -NoProfile -File $scriptPath -N $N 2> $stderrPath)
        $stderr = Get-Content -LiteralPath $stderrPath -Raw

        $LASTEXITCODE | Should -Be 0
        $stderr | Should -BeNullOrEmpty
        $output | Should -HaveCount 1
        $output[0].ToString() | Should -Be $Expected
    }

    It 'writes the expected result for explicit fibonacci dispatch N=<N>' -TestCases @(
        @{ N = 0; Expected = 'Fibonacci(0) = 0' }
        @{ N = 1; Expected = 'Fibonacci(1) = 1' }
        @{ N = 5; Expected = 'Fibonacci(5) = 5' }
    ) {
        param($N, $Expected)

        $stderrPath = Join-Path $TestDrive "stderr-fib-$N.txt"
        $output = @(& pwsh -NoLogo -NoProfile -File $scriptPath -N $N -Operation fibonacci 2> $stderrPath)
        $stderr = Get-Content -LiteralPath $stderrPath -Raw

        $LASTEXITCODE | Should -Be 0
        $stderr | Should -BeNullOrEmpty
        $output | Should -HaveCount 1
        $output[0].ToString() | Should -Be $Expected
    }

    It 'writes the expected result for factorial dispatch N=<N>' -TestCases @(
        @{ N = 0; Expected = 'Factorial(0) = 1' }
        @{ N = 1; Expected = 'Factorial(1) = 1' }
        @{ N = 5; Expected = 'Factorial(5) = 120' }
    ) {
        param($N, $Expected)

        $stderrPath = Join-Path $TestDrive "stderr-fact-$N.txt"
        $output = @(& pwsh -NoLogo -NoProfile -File $scriptPath -N $N -Operation factorial 2> $stderrPath)
        $stderr = Get-Content -LiteralPath $stderrPath -Raw

        $LASTEXITCODE | Should -Be 0
        $stderr | Should -BeNullOrEmpty
        $output | Should -HaveCount 1
        $output[0].ToString() | Should -Be $Expected
    }
}
