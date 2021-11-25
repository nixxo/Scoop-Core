# Usage: scoop depends [<OPTIONS>] [<APP>]
# Summary: List dependencies for application(s).
#
# Options:
#   -h, --help                      Show help for this command.
#   -a, --arch <32bit|64bit|arm64>  Use the specified architecture, if the application's manifest supports it.
#   -s, --skip-installed          Do not list dependencies, which are already installed

@(
    @('core', 'Test-ScoopDebugEnabled'),
    @('getopt', 'Resolve-GetOpt'),
    @('help', 'scoop_help'),
    @('Helpers', 'New-IssuePrompt'),
    @('Dependencies', 'Resolve-DependsProperty')
) | ForEach-Object {
    if (!([bool] (Get-Command $_[1] -ErrorAction 'Ignore'))) {
        Write-Verbose "Import of lib '$($_[0])' initiated from '$PSCommandPath'"
        . (Join-Path $PSScriptRoot "..\lib\$($_[0]).ps1")
    }
}

$ExitCode = 0
$Problems = 0
$Options, $Applications, $_err = Resolve-GetOpt $args 'a:s' 'arch=', 'skip-installed'
$SkipInstalled = $Options.s -or $Options.'skip-installed'

if ($_err) { Stop-ScoopExecution -Message "scoop depends: $_err" -ExitCode 2 }
if (!$Applications) { Stop-ScoopExecution -Message 'Parameter <APP> missing' -Usage (my_usage) }

$Architecture = Resolve-ArchitectureParameter -Architecture $Options.a, $Options.arch

$res = Resolve-MultipleApplicationDependency -Applications $Applications -Architecture $Architecture -IncludeInstalled:(!$SkipInstalled)
if ($res.failed.Count -gt 0) {
    $Problems = $res.failed.Count
}
$new = $res.applications | Where-Object -Property 'Dependency' -EQ -Value $true

$message = 'No dependencies required'
if ($new.Count -gt 0) {
    $message = @()
    foreach ($r in $new) {
        $message += if ($r.Url) { $r.Url } else { $r.ApplicationName }
    }
    $message = $message -join "`r`n"
}

Write-UserMessage -Message $message -Output
if ($Problems -gt 0) {
    $ExitCode = 10 + $Problems
}

exit $ExitCode
