[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repository = 'edburns/dd-3068633-win32-x64-05'
$parentIssue = 5
$logDirectory = 'C:\Users\edburns\workareas\dd-3068633-win32-x64-05-shepherd-control\5-math-control-remove-before-merge\prompts\shepherd-task-20-20260924-1702'
$bodyDirectory = Join-Path $logDirectory 'issue-bodies'
$ledgerPath = Join-Path $logDirectory 'creation-ledger.json'
$resultPath = Join-Path $logDirectory 'stage-20-result.json'
$preCreationPath = Join-Path $logDirectory 'pre-creation-children.json'
$finalChildrenPath = Join-Path $logDirectory 'final-children.json'
$draftValidator = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\validate-stage20-drafts.ps1'
$bodyVerifier = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\verify-github-issue-body.ps1'
$childLinkVerifier = 'C:\Users\edburns\.copilot\plugins\shepherd-task\scripts\verify-stage20-child-links.ps1'

$tasks = @(
    [pscustomobject]@{
        Subsection = '1. Implement Fibonacci with unit and isolated CLI coverage'
        Title = '1. Implement Fibonacci with unit and isolated CLI coverage'
        BodyFile = Join-Path $bodyDirectory '01-1-implement-fibonacci-body.md'
    },
    [pscustomobject]@{
        Subsection = '2. Add factorial and operation dispatch'
        Title = '2. Add factorial and operation dispatch'
        BodyFile = Join-Path $bodyDirectory '02-2-add-factorial-dispatch-body.md'
    }
)

function Write-AtomicText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText(
            $temporaryPath,
            $Content,
            [Text.UTF8Encoding]::new($false)
        )
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-JsonAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowNull()][object]$Value,
        [int]$Depth = 10
    )

    $json = ConvertTo-Json -InputObject $Value -Depth $Depth
    Write-AtomicText -Path $Path -Content ($json + [Environment]::NewLine)
}

function Read-CreationLedger {
    $parsed = [IO.File]::ReadAllText($ledgerPath) |
        ConvertFrom-Json -NoEnumerate
    if ($parsed -isnot [System.Array]) {
        throw 'Creation ledger JSON root must be an array.'
    }

    $ledger = [object[]]$parsed
    if (@($ledger | Where-Object { $_ -is [System.Array] }).Count -ne 0) {
        throw 'Creation ledger must not contain nested array entries.'
    }
    return $ledger
}

function Write-CreationLedger {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Ledger)

    $json = ConvertTo-Json -InputObject ([object[]]$Ledger) -Depth 10
    Write-AtomicText -Path $ledgerPath -Content ($json + [Environment]::NewLine)
}

function Update-LedgerFlag {
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][ValidateSet('body_verified', 'linked')][string]$Field,
        [Parameter(Mandatory)][bool]$Value
    )

    $ledger = @(Read-CreationLedger)
    $entry = $ledger | Where-Object { $_.number -eq $Number }
    if (@($entry).Count -ne 1) {
        throw "Expected one ledger entry for issue #$Number."
    }
    $entry.$Field = $Value
    Write-CreationLedger -Ledger ([object[]]$ledger)
}

function Get-NormalizedChildren {
    $childrenOutput = & gh api "repos/$repository/issues/$parentIssue/sub_issues" --paginate --slurp 2>&1
    $childrenExitCode = $LASTEXITCODE
    if ($childrenExitCode -ne 0) {
        throw "Unable to query parent children: $($childrenOutput | Out-String)"
    }

    $normalizedOutput = ($childrenOutput | Out-String) |
        & jq 'if length == 0 then [] elif all(.[]; type == "array") then add else . end'
    $jqExitCode = $LASTEXITCODE
    if ($jqExitCode -ne 0) {
        throw "Unable to normalize parent children: $($normalizedOutput | Out-String)"
    }

    $normalizedJson = ($normalizedOutput | Out-String).Trim()
    $parsed = $normalizedJson | ConvertFrom-Json -NoEnumerate
    if ($parsed -isnot [System.Array]) {
        throw 'Normalized parent children JSON root must be an array.'
    }
    return [pscustomobject]@{
        Json = $normalizedJson
        Children = [object[]]$parsed
    }
}

function Write-Result {
    param(
        [Parameter(Mandatory)][ValidateSet('in_progress', 'complete', 'failed')][string]$Status,
        [AllowNull()][object]$OperationError
    )

    $result = [ordered]@{
        schemaVersion = 1
        status = $Status
        ledgerFile = 'creation-ledger.json'
        operationError = $OperationError
    }
    Write-JsonAtomic -Path $resultPath -Value $result
}

function Reconcile-Failure {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)][string]$ErrorMessage
    )

    $reconciliationError = $null
    try {
        $serverState = Get-NormalizedChildren
        $linkedIds = @($serverState.Children | ForEach-Object { [Int64]$_.id })
        $ledger = @(Read-CreationLedger)
        foreach ($entry in $ledger) {
            $entry.linked = $linkedIds -contains [Int64]$entry.id
        }
        Write-CreationLedger -Ledger ([object[]]$ledger)
    }
    catch {
        $reconciliationError = $_.Exception.Message
    }

    $operationError = [ordered]@{
        operation = $Operation
        error = $ErrorMessage
        reconciliationError = $reconciliationError
    }
    Write-Result -Status failed -OperationError $operationError

    $ledger = @(Read-CreationLedger)
    [pscustomobject]@{
        Status = 'failed'
        OperationError = $operationError
        Ledger = $ledger
        CleanupCommands = @(
            $ledger | ForEach-Object {
                "gh issue delete $($_.number) --repo `"$repository`" --yes"
            }
        )
        AutomaticRollback = $false
    } | ConvertTo-Json -Depth 10
}

try {
    & $draftValidator `
        -BodyDirectory $bodyDirectory `
        -ExpectedCount 2 `
        -LessonPropagation off | Out-Null

    if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
        throw 'Creation ledger already exists; refusing to treat this as a resumable operation.'
    }
    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        throw 'Stage result already exists; refusing to treat this as a resumable operation.'
    }

    Write-CreationLedger -Ledger ([object[]]@())
    Write-Result -Status in_progress -OperationError $null
}
catch {
    throw "Pre-creation validation or initialization failed: $($_.Exception.Message)"
}

$currentOperation = 'create first issue'
try {
    foreach ($task in $tasks) {
        $currentOperation = "create issue for $($task.Subsection)"
        $createOutput = & gh api "repos/$repository/issues" `
            -X POST `
            -f "title=$($task.Title)" `
            -F "body=@$($task.BodyFile)" `
            --jq '{id,number,node_id,html_url,title}' 2>&1
        $createExitCode = $LASTEXITCODE
        if ($createExitCode -ne 0) {
            throw "Issue creation failed: $($createOutput | Out-String)"
        }
        $createdIssue = ($createOutput | Out-String) | ConvertFrom-Json

        $ledger = @(Read-CreationLedger)
        $ledger += [pscustomobject][ordered]@{
            implementationSubsection = $task.Subsection
            bodyFile = "issue-bodies/$([IO.Path]::GetFileName($task.BodyFile))"
            id = [Int64]$createdIssue.id
            number = [int]$createdIssue.number
            title = [string]$createdIssue.title
            url = [string]$createdIssue.html_url
            body_verified = $false
            linked = $false
        }
        Write-CreationLedger -Ledger ([object[]]$ledger)

        $currentOperation = "verify initial body for issue #$($createdIssue.number)"
        try {
            $observedIssue = & $bodyVerifier `
                -Repository $repository `
                -IssueNumber $createdIssue.number `
                -ExpectedBodyPath $task.BodyFile `
                -MaxAttempts 6 `
                -DelaySeconds 5 `
                -DiagnosticPath (
                    Join-Path $logDirectory "issue-$($createdIssue.number)-body-verification-failure.json"
                )
        }
        catch {
            throw "Issue body verification failed for issue #$($createdIssue.number): $($_.Exception.Message)"
        }
        Update-LedgerFlag -Number $createdIssue.number -Field body_verified -Value $true

        $currentOperation = "link issue #$($createdIssue.number) to parent #$parentIssue"
        $linked = $false
        $lastLinkError = ''
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $linkInput = "{`"sub_issue_id`": $($createdIssue.id)}"
            $linkOutput = $linkInput |
                & gh api "repos/$repository/issues/$parentIssue/sub_issues" -X POST --input - 2>&1
            $linkExitCode = $LASTEXITCODE
            if ($linkExitCode -eq 0) {
                $linked = $true
                break
            }
            $lastLinkError = ($linkOutput | Out-String).Trim()
            if ($attempt -lt 3) {
                Start-Sleep -Seconds 2
            }
        }
        if (-not $linked) {
            throw "Linking failed after 3 attempts: $lastLinkError"
        }
        Update-LedgerFlag -Number $createdIssue.number -Field linked -Value $true
    }

    $currentOperation = 'capture and verify final child linkage'
    $finalState = Get-NormalizedChildren
    Write-AtomicText -Path $finalChildrenPath -Content ($finalState.Json + [Environment]::NewLine)
    & $childLinkVerifier `
        -PreCreationChildrenPath $preCreationPath `
        -FinalChildrenPath $finalChildrenPath `
        -CreationLedgerPath $ledgerPath | Out-Null

    $ledger = @(Read-CreationLedger)
    foreach ($entry in $ledger) {
        $currentOperation = "verify final postconditions for issue #$($entry.number)"
        $bodyPath = Join-Path $logDirectory $entry.bodyFile
        try {
            $observedIssue = & $bodyVerifier `
                -Repository $repository `
                -IssueNumber $entry.number `
                -ExpectedBodyPath $bodyPath `
                -MaxAttempts 6 `
                -DelaySeconds 5 `
                -DiagnosticPath (
                    Join-Path $logDirectory "issue-$($entry.number)-body-verification-failure.json"
                )
        }
        catch {
            throw "Final body verification failed for issue #$($entry.number): $($_.Exception.Message)"
        }
        if ($observedIssue.state -cne 'open') {
            throw "Issue #$($entry.number) is not open."
        }
        if (@($observedIssue.assignees).Count -ne 0) {
            throw "Issue #$($entry.number) unexpectedly has assignees."
        }
    }

    Write-Result -Status complete -OperationError $null
    [pscustomobject]@{
        Status = 'complete'
        IssueType = $null
        Ledger = @(Read-CreationLedger)
    } | ConvertTo-Json -Depth 10
}
catch {
    Reconcile-Failure -Operation $currentOperation -ErrorMessage $_.Exception.Message
    exit 1
}
